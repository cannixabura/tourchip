import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, AppLifecycleState;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../demo.dart';
import '../l10n.dart';
import 'cast.dart';
import 'live_countdown.dart';
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
  /// 剛解散的團（3 天內、還有領隊沒送花）：首頁問一次要不要送花
  static final ended = ValueNotifier<EndedGroup?>(null);
  /// 收到最後一天的送花提醒：打開送花面板（main.dart 監聽）
  static final askThanks = ValueNotifier<bool>(false);
  /// 第一次從伺服器拿到狀態之前是 false（首頁先顯示讀取中，避免閃一下首頁）
  static final loaded = ValueNotifier<bool>(false);
  /// 前景收到集合呼叫：要跳出的全螢幕卡片（main.dart 監聽）
  static final incomingCall = ValueNotifier<TourCall?>(null);
  /// 前景收到點名
  static final incomingRoll = ValueNotifier<String?>(null);
  static Timer? _poll;
  /// 點了私訊通知：要打開和誰的對話（main.dart 監聽）
  static final openChat = ValueNotifier<String?>(null);
  /// 點了投票、揪伴的通知：打開「投票・揪伴」（main.dart 監聽）
  static final openTogether = ValueNotifier<bool>(false);
  /// 到點自動點到了：顯示一句提示（main.dart 監聽）
  static final arrivedNow = ValueNotifier<bool>(false);
  static String? _arriveSent;
  static DateTime _arriveRetry = DateTime.fromMillisecondsSinceEpoch(0);
  /// 位置的唯一來源：Android 的 geolocator 同時只能有一個位置串流（第一個開的設定說了算），
  /// 所以地圖、集合卡、艾婭景點都從 positions 聽；團裡要背景更新時（_bgWanted）換成前景服務的設定，
  /// Android 才會開常駐通知、到背景繼續更新。
  static final _hub = StreamController<Position>.broadcast(onListen: _syncPlat, onCancel: () => scheduleMicrotask(_syncPlat));
  static Stream<Position> get positions => _hub.stream;
  static StreamSubscription<Position>? _plat;
  static bool _platBg = false, _bgWanted = false;
  static bool get _tracking => _plat != null && _platBg;

  static void _syncPlat() {
    final want = _bgWanted || _hub.hasListener;
    if (_plat != null && (!want || _platBg != _bgWanted)) {
      _plat!.cancel();
      _plat = null;
    }
    // 只有「使用 App 時」權限：背景沒辦法開始，等回到前景（resume）再開
    if (!want || _plat != null || !_fg) return;
    _platBg = _bgWanted;
    _plat = Geolocator.getPositionStream(
      locationSettings: _bgWanted ? _locSettings() : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((p) {
      _hub.add(p);
      if (_platBg) _onFix(p);
    }, onError: (_) {
      // 權限被關掉或定位服務關閉：停掉，回到前景再重開
      _plat?.cancel();
      _plat = null;
    });
  }
  static Position? _lastFix;
  static Timer? _bgTick;
  static DateTime _posSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  static Position? _posSent;

  /// App 的 build 號：伺服器用來判斷這支手機有沒有新功能（例如送花提醒只發給有送花功能的版本）
  static String? _build;
  static Future<String> _appBuild() async {
    if (_build != null) return _build!;
    try { _build = (await PackageInfo.fromPlatform()).buildNumber; } catch (_) { _build = ''; }
    return _build!;
  }

  static Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> body = const {}]) async {
    // 商店截圖模式（只在 debug 版）：團的狀態用範例資料，其他動作都不送
    if (Demo.on) {
      // 截圖：艾婭匯入的範例結果
      if (action == 'ai_import') return {'success': true, 'import': Demo.cfg?['import'] ?? const {}};
      if (action != 'status') return {'success': true};
      final d = Demo.status();
      _apply(d['group']);
      ProfileStore.apply(d['profile']);
      loaded.value = true;
      return d;
    }
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final build = await _appBuild();
      final r = await http
          .post(Uri.parse(_url),
              headers: {'Content-Type': 'application/json', 'Accept-Language': langTag, if (token != null) 'Authorization': 'Bearer $token', if (build.isNotEmpty) 'X-App-Build': build},
              body: jsonEncode({'action': action, ...body}))
          .timeout(const Duration(seconds: 20));
      final data = jsonDecode(r.body);
      if (data is! Map<String, dynamic>) return _failed(action);
      if (data.containsKey('group')) {
        _apply(data['group']);
        ended.value = data['group'] == null && data['ended'] is Map ? EndedGroup.fromJson(data['ended']) : null;
      }
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
    // 團員：這次集合剛被自動點到
    if (after != null && !after.isStaff && after.call != null && after.call!.here && before?.call?.id == after.call!.id && before?.call?.here == false) {
      arrivedNow.value = true;
    }
    _syncLoc(after);
    LiveCountdown.sync(after);
    TourCast.sync(after);
    _schedulePoll();
  }

  /// 位置：在團裡、開著分享（或團員集合前 30 分鐘起要自動點名）時取得位置。
  /// 在 App 打開時開始，App 到背景也繼續（iOS 狀態列藍色指示、Android 常駐通知），脫隊預警與到點自動點名才有用。
  /// 只用「使用 App 時」權限：背景沒辦法「開始」取得位置，所以都在前景時開始；退團、解散、關分享就停。
  static Future<void> _syncLoc(TourGroup? g) async {
    final share = g != null && g.shareOn;
    if (!share && !_needArrive(g)) {
      _stopLoc();
      return;
    }
    if (_tracking || !_fg) return;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.whileInUse && perm != LocationPermission.always) return;
    } catch (_) {
      return;
    }
    if (_tracking) return;
    _bgWanted = true;
    _syncPlat();
    // 先送一次目前位置：沒在移動時位置串流可能很久才有第一筆，團員會一直看不到你
    if (share) {
      Geolocator.getCurrentPosition(locationSettings: const LocationSettings(timeLimit: Duration(seconds: 10))).then((p) {
        if (!_tracking || _posSent != null) return;
        _lastFix = p;
        _sendPos(p);
      }).catchError((_) {});
    }
  }

  static LocationSettings _locSettings() {
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: false, // 停下來就不再更新的話，之後走動也收不到
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: tx('旅行團進行中', 'Tour in progress'),
          notificationText: tx('背景也會更新位置：脫隊提醒、到點自動點名', 'Updating your location for stray alerts and auto check-in'),
          notificationChannelName: tx('團進行中的位置', 'Location during the tour'),
          notificationIcon: const AndroidResource(name: 'ic_stat_flag'),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
  }

  static void _onFix(Position p) {
    _lastFix = p;
    if (_needArrive(current.value)) _checkArrive(p);
    if (current.value?.shareOn != true) return;
    // 前景：最多 15 秒一次，走超過 30 公尺提早送；背景：最多 60 秒一次，走超過 40 公尺提早送（省電、省流量）
    final since = DateTime.now().difference(_posSentAt).inSeconds;
    final moved = _posSent == null ? 1e9 : Geolocator.distanceBetween(_posSent!.latitude, _posSent!.longitude, p.latitude, p.longitude);
    final fg = _fg;
    if (since < (fg ? 15 : 60) && !(moved > (fg ? 30 : 40) && since >= (fg ? 5 : 15))) return;
    _sendPos(p);
  }

  static void _sendPos(Position p) {
    _posSentAt = DateTime.now();
    _posSent = p;
    call('pos', {'lat': p.latitude, 'lng': p.longitude});
  }

  static void _stopLoc() {
    _bgWanted = false;
    _syncPlat();
    _posSent = null;
    _lastFix = null;
    _bgTick?.cancel();
    _bgTick = null;
  }

  static bool get _fg => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  /// 到點自動點名：團員有集合、集合前 30 分鐘起看自己的位置（背景也看）；
  /// 走進集合點 30 公尺內（加上 GPS 誤差，最多 25 公尺）就告訴伺服器「到了」。不存位置、不必開分享，也不會為此跳出權限詢問。
  static bool _needArrive(TourGroup? g) {
    final c = g?.call;
    return g != null && !g.isStaff && c != null && !c.here && _arriveSent != c.id &&
        DateTime.now().millisecondsSinceEpoch >= c.at - 30 * 60000 && !Demo.on;
  }

  static Future<void> _checkArrive(Position p) async {
    final c = current.value?.call;
    if (c == null || c.here || _arriveSent == c.id || DateTime.now().isBefore(_arriveRetry)) return;
    final d = Geolocator.distanceBetween(p.latitude, p.longitude, c.lat, c.lng);
    if (d > 30 + p.accuracy.clamp(0, 25)) return;
    _arriveSent = c.id;
    final r = await call('arrive', {'callId': c.id, 'lat': p.latitude, 'lng': p.longitude});
    if (r['success'] == true) {
      _syncLoc(current.value); // 沒開分享的話就停止取得位置
    } else if (r['code'] != 'ended' && r['code'] != 'not_target' && r['code'] != 'bad_request') {
      // 伺服器覺得還太遠或連不上：20 秒後再試
      _arriveSent = null;
      _arriveRetry = DateTime.now().add(const Duration(seconds: 20));
    }
  }

  /// 我會晚到：晚 3／5／10 分鐘，原因 toilet／pay／way（可以不選）
  static Future<Map<String, dynamic>> sendLate(String callId, int mins, String why) =>
      call('late', {'callId': callId, 'mins': mins, if (why.isNotEmpty) 'why': why});

  /// 分享位置的開關；第一次打開要帶 consent（已滿 18 歲或家長／監護人同意）
  static Future<Map<String, dynamic>> setShare(bool on, {bool consent = false}) async {
    final r = await call('share', {'on': on, if (consent) 'consent': true});
    if (on && r['success'] == true) _posSentAt = DateTime.fromMillisecondsSinceEpoch(0);
    return r;
  }

  /// 在團裡時定期更新：有集合或點名時 10 秒一次，平常 15 秒（同團的人在地圖上移動）；
  /// App 在背景時改由 _bgTick 每分鐘一次
  static void _schedulePoll() {
    _poll?.cancel();
    final g = current.value;
    if (g == null || !_fg) return;
    _poll = Timer(Duration(seconds: g.call != null || g.rollId != null ? 10 : 15), refresh);
  }

  static Future<void> refresh() => call('status');

  /// 回到前景
  static Future<void> resume() {
    _bgTick?.cancel();
    _bgTick = null;
    _syncPlat(); // 地圖等在背景時沒辦法開始的位置串流
    return refresh();
  }

  /// App 到背景：還在取得位置的話，每分鐘看一次團的狀態（新的集合、解散），
  /// 沒走動也再送一次最後的位置，伺服器才知道你還在那裡（脫隊預警只看 2 分鐘內的位置）
  static void pause() {
    _poll?.cancel();
    _bgTick?.cancel();
    _bgTick = null;
    if (!_tracking) return;
    _bgTick = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (_fg) return;
      await refresh();
      final p = _lastFix;
      if (p != null && _tracking && current.value?.shareOn == true &&
          DateTime.now().difference(_posSentAt).inSeconds >= 50) {
        _sendPos(p);
      }
    });
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
      'cast_busy' => tx('另一位領隊正在廣播，等他結束再開。', 'Another leader is on air. Wait until they finish.'),
      'cast_unavailable' => tx('講解廣播暫時無法使用，請稍後再試。', 'Live talk is not available right now. Try again later.'),
      'mic_denied' => tx('沒有麥克風權限：請到手機的設定打開旅行團的麥克風。', 'No microphone access. Turn on the microphone for TourChip in your phone settings.'),
      'in_group' => tx('你已經在另一個團裡了，先退出那一團再加入。', 'You are already in another group. Leave it first.'),
      'full' => tx('這個團已滿 20 人。請領隊買人數券或使用團購券。', 'This group is full (20). Ask your leader to upgrade.'),
      'days' => tx('天數要在 1～30 天之間，而且結束日不能已經過去。', 'Trip length must be 1–30 days and end in the future.'),
      'start' => tx('出發日要在今天到 90 天後之間。', 'The start date must be within the next 90 days.'),
      'max_days' => tx('這一團已經是最長的 30 天了。', 'This group already has the maximum 30 days.'),
      'url' => tx('連結要是 http 或 https 開頭的網址。', 'Links must start with http or https.'),
      'paid_full' => tx('這個團已滿 100 人。', 'This group is full (100).'),
      'qr' => tx('這個 QR code 已經換新，請向領隊要新的。', 'This QR code was replaced. Ask your leader for the new one.'),
      'invite' => tx('邀請碼不對，或領隊已經換新了。請再確認一次。', 'That invite code is wrong or was replaced. Please check it.'),
      'not_yet' => tx('最後一天才能送花喔。', 'You can send flowers from the last day.'),
      'already' => tx('你已經送過花了，謝謝你！', 'You already sent a flower. Thank you!'),
      'ai' => tx('艾婭現在沒辦法整理，請稍後再試。', 'AIYA can\'t read it right now. Try again later.'),
      'ai_limit' => tx('這一團的艾婭匯入次數用完了。', 'No AIYA imports left for this group.'),
      'ai_empty' => tx('請貼上行程或分房表的文字。', 'Paste the itinerary or rooming list text.'),
      'ai_long' => tx('文字太長了，請分成幾段匯入。', 'The text is too long. Import it in parts.'),
      'invite_rate' => tx('輸錯太多次了，請一小時後再試，或改用掃 QR code 入團。', 'Too many wrong tries. Try again in an hour, or scan the QR code.'),
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
      'closed' => tx('這個投票已經結束了。', 'This poll is closed.'),
      'voucher_not_found' => tx('找不到這張團購券。', 'Voucher not found.'),
      'voucher_used' => tx('這張團購券已經用過了。', 'This voucher was already used.'),
      'voucher_expired' => tx('這張團購券已經過期。', 'This voucher has expired.'),
      'already_paid' => tx('這一團已經升級過了。', 'This group is already upgraded.'),
      'used' => tx('這筆購買已經用過了。', 'This purchase was already used.'),
      'not_sharing' => tx('你目前沒有分享位置。', 'Location sharing is off.'),
      'need_consent' => tx('要先同意分享，才能發氣泡、傳訊息或揪伴。', 'Please agree to sharing first.'),
      'too_fast' => tx('傳得太快了，休息一下再傳。', 'Slow down a little.'),
      _ => tx('連線不穩，請稍後再試。', 'Connection problem. Please try again.'),
    };

// ---------- 人數券、天數券與團購券 ----------
// 人數券 tour_pass_7d（NT$290）：這一團升到 100 人，到解散為止
// 天數券 tour_days_7d（NT$290）：這一團多 7 天（出發日起免費 3 天，最長 30 天）
// 兩種都是消耗型商品；買來用在目前帶的團，或做成團購券發給領隊

/// 購買的用途：用在目前帶的團（group），或買成團購券發給領隊（voucher）
enum PassPurpose { group, voucher }

class PassStore {
  PassStore._();
  static const people = 'tour_pass_7d';
  static const days = 'tour_days_7d';
  static const _purposeKey = 'pass_purpose';
  static final details = ValueNotifier<Map<String, ProductDetails>>(const {});
  static final busy = ValueNotifier<bool>(false);
  static final notice = ValueNotifier<String?>(null);
  static final vouchers = ValueNotifier<List<TourVoucher>>(const []);
  static StreamSubscription<List<PurchaseDetails>>? _sub;

  /// 價格一律用商店給的（依使用者的商店地區顯示幣別）；還沒載入就顯示「—」，不寫死
  static String priceOf(String product) => details.value[product]?.price ?? '—';

  static void init() {
    _sub ??= InAppPurchase.instance.purchaseStream.listen(_onPurchases, onError: (_) => busy.value = false);
  }

  static Future<void> load() async {
    try {
      if (!await InAppPurchase.instance.isAvailable()) return;
      final r = await InAppPurchase.instance.queryProductDetails({people, days});
      // 合併，不覆蓋：某次只回來一種時，已經載到的另一種保留
      details.value = {...details.value, for (final p in r.productDetails) p.id: p};
    } catch (_) {}
  }

  static Future<void> loadVouchers() async {
    final r = await TourService.call('vouchers');
    if (r['success'] == true) vouchers.value = [for (final v in (r['vouchers'] as List? ?? const [])) TourVoucher.fromJson(v)];
  }

  static Future<void> buy(String product, PassPurpose purpose) async {
    var p = details.value[product];
    if (p == null) { await load(); p = details.value[product]; }
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
    for (final p in list.where((p) => p.productID == people || p.productID == days)) {
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
          // max_days：已經 30 天了，這張天數券改做成團購券留著用（不讓錢白花）
          if (code == 'max_days' && purpose != PassPurpose.voucher.name) {
            final v = await TourService.call('buy_voucher', {'purchase': purchase});
            if (v['success'] == true) {
              if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
              if (v['vouchers'] is List) vouchers.value = [for (final x in v['vouchers']) TourVoucher.fromJson(x)];
              notice.value = tx('這一團已經是 30 天，這張天數券先存成團購券，可以用在下一團。', 'This group is already 30 days. The pass was saved as a voucher.');
              continue;
            }
          }
          if (data['success'] == true || code == 'used' || code == 'unknown_product' || code == 'revoked' || code == 'wrong_app') {
            if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
          }
          if (data['vouchers'] is List) vouchers.value = [for (final v in data['vouchers']) TourVoucher.fromJson(v)];
          final isDays = p.productID == days;
          notice.value = data['success'] == true
              ? (purpose == PassPurpose.voucher.name
                  ? tx('團購券已經準備好，可以發給領隊了。', 'Your voucher is ready to share.')
                  : isDays
                      ? tx('這一團多了 7 天。', 'Added 7 days to this group.')
                      : tx('這一團已升級，最多 100 人。', 'Upgraded. Up to 100 people.'))
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
