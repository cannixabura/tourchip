import 'dart:async';
import 'dart:io';

import 'package:aiya/aiya.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../l10n.dart';
import '../tour/service.dart';
import '../tour/zones.dart';

const _aiyaUrl = String.fromEnvironment('AIYA_URL', defaultValue: AiyaApi.defaultUrl);

/// 團主公布的行程與集合資訊，給艾婭當背景（不送任何人的位置），最多 800 字（伺服器也會再截）
String tourContext() {
  final g = TourService.current.value;
  if (g == null) return '';
  final b = StringBuffer()
    ..writeln('Group: ${g.name}')
    ..writeln('Dates: ${g.startDate} – ${g.endDate} (${g.days} days), group time zone ${g.tz}');
  if (g.role.isNotEmpty) b.writeln('My role: ${g.role}${g.myNo != null ? ', no. ${g.myNo}' : ''}${g.mySub != null ? ', ${g.subName(g.mySub)}' : ''}');
  final c = g.call;
  if (c != null) b.writeln('Current meeting call: ${c.place} at ${md(c.at, c.tz)} ${hm(c.at, c.tz)} local time (${zoneChip(c.at, c.tz)})${c.sub != null ? ' for ${g.subName(c.sub)}' : ''}');
  final now = DateTime.now().millisecondsSinceEpoch;
  final stops = [...g.stops]..sort((a, b) => a.at.compareTo(b.at));
  final upcoming = stops.where((s) => s.at >= now - 3600 * 1000).take(8);
  if (upcoming.isNotEmpty) {
    b.writeln('Itinerary (local times):');
    for (final s in upcoming) {
      b.writeln('- ${md(s.at, s.tz)} ${hm(s.at, s.tz)} ${s.place} (${zoneName(s.tz)})${s.sub != null ? ' [${g.subName(s.sub)}]' : ''}');
    }
  }
  for (final d in g.dayCards.take(3)) {
    final hotel = d.hotel?.name ?? '';
    if (d.note.isEmpty && hotel.isEmpty) continue;
    b.writeln('Day ${d.date}: ${d.note}${hotel.isNotEmpty ? ' Hotel: $hotel' : ''}');
  }
  for (final a in g.announcements.take(3)) {
    b.writeln('Notice: ${a.text}');
  }
  final s = b.toString().trim();
  return s.length > 800 ? s.substring(0, 800) : s;
}

/// 旅行團的艾婭 API（共用套件 package:aiya，app: 'tour'）
final aiyaApi = AiyaApi(
  app: 'tour',
  language: () => langTag,
  url: _aiyaUrl,
  extra: () => {'tourContext': tourContext(), 'tzOffsetMin': DateTime.now().timeZoneOffset.inMinutes},
);

/// 艾婭語音通話（OpenAI GPT-Live）
final aiyaPhone = AiyaCall(aiyaApi);

/// 呼叫伺服器的艾婭 API：每次都帶目前的團資訊與時區；連不上時回 {success: false, code: 'busy'}
Future<Map<String, dynamic>> aiyaCall(String action, [Map<String, dynamic> body = const {}]) =>
    aiyaApi.call(action, {...?aiyaApi.extra?.call(), ...body});

/// 艾婭的內購：文字時光包、通話時間包（消耗型）、艾婭之友（自動續訂月費，每月送 60 分鐘通話）。
/// 和團的人數券／天數券共用同一個購買串流，各自只處理自己的商品。價格一律用商店給的。
class AiyaStore {
  AiyaStore._();

  /// 文字聊天時光包：商品代號 → 次數
  static const products = {'tour_aiya_time_5': 5, 'tour_aiya_time_20': 20};
  /// 語音通話時間包：商品代號 → 分鐘
  static const callProducts = {'tour_aiya_call_30': 30, 'tour_aiya_call_60': 60, 'tour_aiya_call_180': 180};
  static const friendProduct = 'tour_aiya_friend_monthly';
  static bool _isMine(String id) => products.containsKey(id) || callProducts.containsKey(id) || id == friendProduct;

  static final details = ValueNotifier<Map<String, ProductDetails>>(const {});
  static final busy = ValueNotifier<bool>(false);
  static final notice = ValueNotifier<String?>(null);
  static final credits = ValueNotifier<int?>(null);
  /// 剩下的通話秒數（艾婭之友當月贈送＋買的時間包）
  static final callSeconds = ValueNotifier<int?>(null);
  /// 剛買到通話時間：畫面收到後直接接通
  static final callBought = ValueNotifier<int>(0);
  /// 艾婭之友到期時間；0 = 不是
  static final friendExp = ValueNotifier<int?>(null);
  static bool get isFriend => (friendExp.value ?? 0) > DateTime.now().millisecondsSinceEpoch;
  static bool _restoring = false;
  static StreamSubscription<List<PurchaseDetails>>? _sub;

  /// 價格一律用商店給的；還沒載入就顯示「—」
  static String priceOf(String id) => details.value[id]?.price ?? '—';

  static Uri get manageUrl => Platform.isIOS
      ? Uri.parse('https://apps.apple.com/account/subscriptions')
      : Uri.parse('https://play.google.com/store/account/subscriptions?sku=$friendProduct&package=com.softchip.tourchip');

  static void applyStatus(Map<String, dynamic> s) {
    if (s['friendExp'] is num) friendExp.value = (s['friendExp'] as num).toInt();
    if (s['callSecondsLeft'] is num) callSeconds.value = (s['callSecondsLeft'] as num).toInt();
    if (s['credits'] is num) credits.value = (s['credits'] as num).toInt();
  }

  static void init() {
    _sub ??= InAppPurchase.instance.purchaseStream.listen(_onPurchases, onError: (_) => busy.value = false);
  }

  static Future<void> load() async {
    try {
      if (!await InAppPurchase.instance.isAvailable()) return;
      final r = await InAppPurchase.instance.queryProductDetails({...products.keys, ...callProducts.keys, friendProduct});
      details.value = {...details.value, for (final p in r.productDetails) p.id: p};
    } catch (_) {}
  }

  static String _unavailable() => tx('現在無法購買，請稍後再試。', 'Purchases are unavailable right now.');
  static String _failed() => tx('購買沒有完成，請稍後再試。', 'The purchase did not go through.');

  static Future<ProductDetails?> _product(String id) async {
    var p = details.value[id];
    if (p == null) { await load(); p = details.value[id]; }
    if (p == null) notice.value = _unavailable();
    return p;
  }

  /// 時光包、通話時間包（消耗型）
  static Future<void> buy(String id) async {
    final p = await _product(id);
    if (p == null) return;
    busy.value = true;
    try {
      final started = await InAppPurchase.instance.buyConsumable(purchaseParam: PurchaseParam(productDetails: p), autoConsume: true);
      if (!started) busy.value = false;
    } catch (_) {
      busy.value = false;
      notice.value = _failed();
    }
  }

  /// 訂閱艾婭之友（自動續訂）
  static Future<void> buyFriend() async {
    final p = await _product(friendProduct);
    if (p == null) return;
    busy.value = true;
    try {
      final started = await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
      if (!started) busy.value = false;
    } catch (_) {
      busy.value = false;
      notice.value = _failed();
    }
  }

  /// 恢復購買：找回艾婭之友訂閱（時間包是消耗型，不能恢復）
  static Future<void> restore() async {
    _restoring = true;
    busy.value = true;
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {
      notice.value = _failed();
    }
    Future.delayed(const Duration(seconds: 5), () async {
      if (!_restoring) return;
      _restoring = false;
      applyStatus(await aiyaCall('status'));
      busy.value = false;
      notice.value = isFriend ? _restoredText() : tx('這個帳戶沒有找到艾婭之友的訂閱。', 'No AIYA Friend subscription was found.');
    });
  }

  static String _restoredText() => tx('已恢復艾婭之友。', 'AIYA Friend restored.');

  static Future<void> _onPurchases(List<PurchaseDetails> list) async {
    final mine = [for (final p in list) if (_isMine(p.productID)) p];
    if (mine.isEmpty) return;
    final toVerify = <PurchaseDetails>[];
    for (final p in mine) {
      switch (p.status) {
        case PurchaseStatus.pending:
          busy.value = true;
        case PurchaseStatus.canceled || PurchaseStatus.error:
          busy.value = false;
          if (p.status == PurchaseStatus.error) notice.value = _failed();
          if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          toVerify.add(p);
      }
    }
    if (toVerify.isEmpty) return;
    final data = await aiyaCall('verify', {
      'purchases': [
        for (final p in toVerify)
          Platform.isIOS
              ? {'platform': 'apple', 'productId': p.productID, 'data': p.verificationData.serverVerificationData}
              : {'platform': 'google', 'productId': p.productID, 'token': p.verificationData.serverVerificationData},
      ],
    });
    busy.value = false;
    final wasRestoring = _restoring;
    _restoring = false;
    if (data['success'] != true) { notice.value = _failed(); return; } // 交易留著，下次啟動再送
    final wasFriend = isFriend;
    applyStatus(data);
    var added = 0, minutes = 0;
    var friendNew = false, friendElsewhere = false;
    final results = (data['results'] as List? ?? const []).whereType<Map>().toList();
    for (var i = 0; i < toVerify.length; i++) {
      final p = toVerify[i];
      final result = i < results.length ? '${results[i]['result']}' : '';
      // 加過了（或這筆屬於別的帳號）才結束交易；驗證失敗時留著
      if (result != 'granted' && result != 'already' && result != 'owned_elsewhere') continue;
      if (p.productID == friendProduct) {
        if (result == 'granted' && p.status == PurchaseStatus.purchased) friendNew = true;
        if (result == 'owned_elsewhere') friendElsewhere = true;
      } else if (result == 'granted' && callProducts.containsKey(p.productID)) {
        minutes += callProducts[p.productID]!;
      } else if (result == 'granted') {
        added += products[p.productID] ?? 0;
      }
      if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
    }
    // 自動續訂、啟動時補送的交易不打擾使用者
    if (friendElsewhere) {
      notice.value = tx('這個訂閱已經用在另一個旅行團帳號。', 'This subscription belongs to another TourChip account.');
    } else if (friendNew || (wasRestoring && isFriend) || (!wasFriend && isFriend)) {
      notice.value = wasRestoring ? _restoredText() : tx('歡迎成為艾婭之友！每個月有 60 分鐘可以和艾婭通話。', 'Welcome, AIYA Friend! You get 60 minutes of calls every month.');
    } else if (minutes > 0) {
      notice.value = tx('多了 $minutes 分鐘通話時間。', 'Added $minutes minutes of call time.');
      callBought.value++;
    } else if (added > 0) {
      notice.value = tx('多了 $added 次聊天。', 'Added $added chats.');
    } else if (wasRestoring) {
      notice.value = tx('這個帳戶沒有找到艾婭之友的訂閱。', 'No AIYA Friend subscription was found.');
    }
  }
}
