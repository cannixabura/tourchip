import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n.dart';
import 'model.dart';
import 'profile.dart';

/// 旅行團的伺服器（geo-service/tourgroup_api.js，Cloud Function tourGroup）。
/// 與城市低語共用同一個 Firebase 專案與後端；Redis 用 tgroup* 開頭，城市低語的低語團不受影響。
const _url = String.fromEnvironment('TOUR_URL', defaultValue: 'https://asia-southeast1-mood-whisper-f7de9.cloudfunctions.net/tourGroup');

/// 入團連結、團購券連結（Firebase Hosting 的 tourchip 網站）
const linkHost = 'tourchip.web.app';

class TourService {
  TourService._();
  static final current = ValueNotifier<TourGroup?>(null);
  /// 第一次從伺服器拿到狀態之前是 false（首頁先顯示讀取中，避免閃一下首頁）
  static final loaded = ValueNotifier<bool>(false);
  /// 前景收到集合呼叫：要跳出的全螢幕卡片（main.dart 監聽）
  static final incomingCall = ValueNotifier<TourCall?>(null);
  /// 前景收到點名
  static final incomingRoll = ValueNotifier<String?>(null);
  static Timer? _poll;
  /// 點了私訊通知：要打開和誰的對話（main.dart 監聽）
  static final openChat = ValueNotifier<String?>(null);
  static StreamSubscription<Position>? _posSub;
  static DateTime _posSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  static Position? _posSent;
  static Timer? _posBeat;

  static Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> body = const {}]) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final r = await http
          .post(Uri.parse(_url),
              headers: {'Content-Type': 'application/json', 'Accept-Language': langTag, if (token != null) 'Authorization': 'Bearer $token'},
              body: jsonEncode({'action': action, ...body}))
          .timeout(const Duration(seconds: 20));
      final data = jsonDecode(r.body);
      if (data is! Map<String, dynamic>) return _failed(action);
      if (data.containsKey('group')) _apply(data['group']);
      if (action == 'status' && data.containsKey('profile')) ProfileStore.apply(data['profile']);
      if (action == 'status') loaded.value = true;
      return data;
    } catch (_) {
      return _failed(action);
    }
  }

  /// 連不上：第一次讀取也要結束等待（顯示首頁或上次的狀態），稍後再試
  static Map<String, dynamic> _failed(String action) {
    if (action == 'status') {
      loaded.value = true;
      _poll?.cancel();
      _poll = Timer(const Duration(seconds: 15), refresh);
    }
    return {'success': false, 'code': 'busy'};
  }

  static void _apply(Object? g) {
    final before = current.value;
    current.value = g is Map<String, dynamic> ? TourGroup.fromJson(g) : null;
    loaded.value = true;
    final after = current.value;
    // 團員：新的集合呼叫還沒按收到 → 跳出卡片
    if (after != null && !after.isStaff && after.call != null && after.call!.mine != 'ack' && before?.call?.id != after.call!.id) {
      incomingCall.value = after.call;
    }
    // 團員：新的點名還沒回答 → 跳出點名卡片
    if (after != null && !after.isStaff && after.rollId != null && after.rollMine == null && before?.rollId != after.rollId) {
      incomingRoll.value = after.rollId;
    }
    after != null && after.shareOn ? _startPos() : _stopPos();
    _schedulePoll();
  }

  /// 同團互相看得到：App 開著、在團裡、開著分享時才回報位置（最多 15 秒一次；走超過 30 公尺會提早送）
  static void _startPos() {
    if (_posSub != null) return;
    // 先送一次目前位置：沒在移動時位置串流可能很久才有第一筆，團員會一直看不到你
    Geolocator.getCurrentPosition(locationSettings: const LocationSettings(timeLimit: Duration(seconds: 10))).then((p) {
      if (_posSub == null || _posSent != null) return;
      _posSentAt = DateTime.now();
      _posSent = p;
      call('pos', {'lat': p.latitude, 'lng': p.longitude});
    }).catchError((_) {});
    _posSub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)).listen((p) {
      final since = DateTime.now().difference(_posSentAt).inSeconds;
      final moved = _posSent == null ? 1e9 : Geolocator.distanceBetween(_posSent!.latitude, _posSent!.longitude, p.latitude, p.longitude);
      if (since < 15 && !(moved > 30 && since >= 5)) return;
      _posSentAt = DateTime.now();
      _posSent = p;
      call('pos', {'lat': p.latitude, 'lng': p.longitude});
    }, onError: (_) {});
    // 站著不動時位置串流不會再有新的一筆（distanceFilter 10 公尺），伺服器 10 分鐘沒收到就不再顯示這個人：
    // 每 2 分鐘補送一次目前位置
    _posBeat = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_posSub == null || DateTime.now().difference(_posSentAt).inSeconds < 100) return;
      Geolocator.getCurrentPosition(locationSettings: const LocationSettings(timeLimit: Duration(seconds: 10))).then((p) {
        if (_posSub == null) return;
        _posSentAt = DateTime.now();
        _posSent = p;
        call('pos', {'lat': p.latitude, 'lng': p.longitude});
      }).catchError((_) {});
    });
  }

  static void _stopPos() {
    _posBeat?.cancel();
    _posBeat = null;
    _posSub?.cancel();
    _posSub = null;
    _posSent = null;
  }

  /// 分享位置的開關；第一次打開要帶 consent（已滿 18 歲或家長／監護人同意）
  static Future<Map<String, dynamic>> setShare(bool on, {bool consent = false}) async {
    final r = await call('share', {'on': on, if (consent) 'consent': true});
    if (on && r['success'] == true) _posSentAt = DateTime.fromMillisecondsSinceEpoch(0);
    return r;
  }

  /// 在團裡時定期更新：有集合或點名時 10 秒一次，平常 15 秒（同團的人在地圖上移動）；App 在背景時暫停
  static void _schedulePoll() {
    _poll?.cancel();
    final g = current.value;
    if (g == null) return;
    _poll = Timer(Duration(seconds: g.call != null || g.rollId != null ? 10 : 15), refresh);
  }

  static Future<void> refresh() => call('status');
  static void pause() {
    _poll?.cancel();
    _stopPos(); // App 到背景就不再回報位置
  }

  /// 收到推播（前景）：重新整理；集合呼叫與點名會由 _apply 跳出卡片
  static void onPush(Map<String, dynamic> data) {
    if ('${data['type']}'.startsWith('tgroup_')) refresh();
  }

  /// Android：集合呼叫的專屬通知頻道（高優先、專屬音效、震動「短 短 長」）。推播的 channelId 是 group_call
  static Future<void> createAndroidChannel() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(AndroidNotificationChannel(
            'group_call', tx('集合與點名', 'Gather and roll call'),
            description: tx('領隊發出集合、點名時的提醒', 'Alerts when your tour leader calls the group together'),
            importance: Importance.high,
            sound: const RawResourceAndroidNotificationSound('group_call'),
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 150, 100, 150, 100, 600]),
          ));
    } catch (_) {}
  }
}

/// 掃到或點到的連結：入團（/g/<團代碼>?v=<版本>）或團購券（/v/<券號>）
sealed class TourLink {}

class JoinLink extends TourLink {
  final String code;
  final int version;
  JoinLink(this.code, this.version);
}

class VoucherLink extends TourLink {
  final String code;
  VoucherLink(this.code);
}

TourLink? parseTourLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.pathSegments.length < 2) return null;
  if (uri.host.isNotEmpty && uri.host != linkHost) return null;
  final kind = uri.pathSegments.first, code = uri.pathSegments[1].toUpperCase();
  if (kind == 'g' && RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code)) {
    return JoinLink(code, int.tryParse(uri.queryParameters['v'] ?? '') ?? 1);
  }
  if (kind == 'v' && RegExp(r'^[A-HJ-NP-Z2-9]{10}$').hasMatch(code)) return VoucherLink(code);
  return null;
}

/// 伺服器錯誤代碼 → 給人看的話
String tourError(String code) => switch (code) {
      'in_group' => tx('你已經在另一個團裡了，先退出那一團再加入。', 'You are already in another group. Leave it first.'),
      'full' => tx('這個團已滿 20 人。請領隊升級 7 天方案或使用團購券。', 'This group is full (20). Ask your leader to upgrade.'),
      'paid_full' => tx('這個團已滿 100 人。', 'This group is full (100).'),
      'qr' => tx('這個 QR code 已經換新，請向領隊要新的。', 'This QR code was replaced. Ask your leader for the new one.'),
      'ended' || 'not_found' || 'no_group' => tx('這個團已經結束了。', 'This group has ended.'),
      'filtered' => tx('內容有不適合的字，請換個說法。', 'Please rephrase that.'),
      'host' => tx('團主要先交棒或解散，才能離開。', 'Hand over or end the group before leaving.'),
      'not_host' => tx('只有團主可以這麼做。', 'Only the leader can do that.'),
      'cohost_full' => tx('共同團主最多 2 位。', 'Up to 2 co-leaders.'),
      'name' => tx('請輸入團名。', 'Please enter a group name.'),
      'time' => tx('時間不在行程內。', 'That time is outside the trip.'),
      'place' => tx('請填寫集合點。', 'Please add a meeting point.'),
      'tz' => tx('時區不正確。', 'Invalid time zone.'),
      'empty' => tx('請輸入內容。', 'Please write something.'),
      'too_many' => tx('數量已達上限。', 'Limit reached.'),
      'voucher_not_found' => tx('找不到這張團購券。', 'Voucher not found.'),
      'voucher_used' => tx('這張團購券已經用過了。', 'This voucher was already used.'),
      'voucher_expired' => tx('這張團購券已經過期。', 'This voucher has expired.'),
      'already_paid' => tx('這一團已經升級過了。', 'This group is already upgraded.'),
      'used' => tx('這筆購買已經用過了。', 'This purchase was already used.'),
      'not_sharing' => tx('你目前沒有分享位置。', 'Location sharing is off.'),
      'need_consent' => tx('要先同意分享，才能發氣泡或傳訊息。', 'Please agree to sharing first.'),
      'too_fast' => tx('傳得太快了，休息一下再傳。', 'Slow down a little.'),
      _ => tx('連線不穩，請稍後再試。', 'Connection problem. Please try again.'),
    };

// ---------- 7 天方案與團購券（同一個消耗型商品 tour_pass_7d） ----------

/// 購買的用途：用在目前帶的團（group），或買成團購券發給領隊（voucher）
enum PassPurpose { group, voucher }

class PassStore {
  PassStore._();
  static const product = 'tour_pass_7d';
  static const _purposeKey = 'pass_purpose';
  static final details = ValueNotifier<ProductDetails?>(null);
  static final busy = ValueNotifier<bool>(false);
  static final notice = ValueNotifier<String?>(null);
  static final vouchers = ValueNotifier<List<TourVoucher>>(const []);
  static StreamSubscription<List<PurchaseDetails>>? _sub;

  static void init() {
    _sub ??= InAppPurchase.instance.purchaseStream.listen(_onPurchases, onError: (_) => busy.value = false);
  }

  static Future<void> load() async {
    try {
      if (!await InAppPurchase.instance.isAvailable()) return;
      final r = await InAppPurchase.instance.queryProductDetails({product});
      if (r.productDetails.isNotEmpty) details.value = r.productDetails.first;
    } catch (_) {}
  }

  static Future<void> loadVouchers() async {
    final r = await TourService.call('vouchers');
    if (r['success'] == true) vouchers.value = [for (final v in (r['vouchers'] as List? ?? const [])) TourVoucher.fromJson(v)];
  }

  static Future<void> buy(PassPurpose purpose) async {
    final p = details.value;
    if (p == null) { notice.value = tx('現在無法購買，請稍後再試。', 'Purchases are unavailable right now.'); return; }
    busy.value = true;
    // 記住這次購買的用途：交易可能在 App 重開後才完成
    try { (await SharedPreferences.getInstance()).setString(_purposeKey, purpose.name); } catch (_) {}
    try {
      final started = await InAppPurchase.instance.buyConsumable(purchaseParam: PurchaseParam(productDetails: p), autoConsume: true);
      if (!started) busy.value = false;
    } catch (_) {
      busy.value = false;
      notice.value = tx('購買沒有完成，請稍後再試。', 'The purchase did not go through.');
    }
  }

  static Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list.where((p) => p.productID == product)) {
      switch (p.status) {
        case PurchaseStatus.pending:
          busy.value = true;
        case PurchaseStatus.canceled || PurchaseStatus.error:
          busy.value = false;
          if (p.status == PurchaseStatus.error) notice.value = tx('購買沒有完成，請稍後再試。', 'The purchase did not go through.');
          if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          String purpose = PassPurpose.group.name;
          try { purpose = (await SharedPreferences.getInstance()).getString(_purposeKey) ?? purpose; } catch (_) {}
          // 不在團裡（例如旅行社的人）買的一定是團購券
          if (TourService.current.value == null) purpose = PassPurpose.voucher.name;
          final purchase = Platform.isIOS
              ? {'platform': 'apple', 'productId': p.productID, 'data': p.verificationData.serverVerificationData}
              : {'platform': 'google', 'productId': p.productID, 'token': p.verificationData.serverVerificationData};
          final data = await TourService.call(purpose == PassPurpose.voucher.name ? 'buy_voucher' : 'verify', {'purchase': purchase});
          busy.value = false;
          final code = '${data['code'] ?? ''}';
          // 成功、或這筆已經用過（不必再試）才結束交易；連不上時留著，下次啟動再送
          if (data['success'] == true || code == 'used' || code == 'unknown_product' || code == 'revoked' || code == 'wrong_app') {
            if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
          }
          if (data['vouchers'] is List) vouchers.value = [for (final v in data['vouchers']) TourVoucher.fromJson(v)];
          notice.value = data['success'] == true
              ? (purpose == PassPurpose.voucher.name ? tx('團購券已經準備好，可以發給領隊了。', 'Your voucher is ready to share.') : tx('這一團已升級，最多 100 人。', 'Upgraded. Up to 100 people.'))
              : tourError(code);
      }
    }
  }
}

// ---------- 定位權限 ----------

/// 需要位置時才問（地圖、集合卡片的距離方向、我迷路了）。拒絕也能用，只是看不到距離。
Future<bool> ensureLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  } catch (_) {
    return false;
  }
}

// ---------- 提醒音效與震動 ----------

final _alertPlayer = AudioPlayer();

/// App 開著時推播不會響：自己播一次專屬音效
Future<void> alertSound() async {
  try {
    await _alertPlayer.stop();
    await _alertPlayer.play(AssetSource('audio/group_call.wav'), volume: 1.0);
  } catch (_) {}
}

/// 震動「短 短 長」＋專屬音效：集合、點名、迷路、需要幫忙共用
Future<void> buzz() async {
  alertSound();
  HapticFeedback.heavyImpact();
  await Future.delayed(const Duration(milliseconds: 250));
  HapticFeedback.heavyImpact();
  await Future.delayed(const Duration(milliseconds: 250));
  HapticFeedback.heavyImpact();
  await Future.delayed(const Duration(milliseconds: 120));
  HapticFeedback.vibrate();
}
