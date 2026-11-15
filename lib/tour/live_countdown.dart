import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../demo.dart';
import '../l10n.dart';
import 'model.dart';
import 'zones.dart';

/// 鎖定畫面的集合倒數：iOS 即時動態（Live Activity，ios/TourLive）、Android 常駐通知（倒數計時）。
/// 有集合就顯示「14:30 集合 · 地點」和倒數；自動點到、集合結束或取消就收起來。
/// 倒數由系統自己跑，不必一直更新；距離和方向要用到位置，所以不放在鎖定畫面。
class LiveCountdown {
  LiveCountdown._();
  static const _ios = MethodChannel('tourchip/live');
  static const _androidId = 7301;
  static String? _shown, _trying;
  /// 這次啟動還沒清過：上次留下的即時動態（App 被關掉時集合已經結束）要收起來
  static bool _swept = false;
  static bool _androidReady = false;
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> sync(TourGroup? g) async {
    // 截圖模式不顯示；demo.json 寫 "live": true 時才顯示（測試鎖定畫面用）
    if (Demo.on && Demo.cfg?['live'] != true) return;
    final c = g?.call;
    if (g == null || c == null || c.here) return end();
    final key = '${c.id}|${c.at}|${c.place}|$langTag';
    if (_shown == key || _trying == key) return;
    // iOS 只能在前景開始即時動態；在背景收到的集合，等回到前景（resume 會再同步）再顯示
    if (Platform.isIOS && WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    _trying = key;
    final title = tx('${hm(c.at, c.tz)} 集合', 'Gather at ${hm(c.at, c.tz)}');
    final place = c.place.isNotEmpty ? c.place : tx('打開 App 看集合點', 'Open the app to see where');
    try {
      if (Platform.isIOS) {
        final ok = await _ios.invokeMethod<bool>('start', {
          'id': c.id, 'group': g.name, 'title': title, 'place': place, 'at': c.at,
          'color': g.tint.toARGB32() & 0xFFFFFF, 'now': tx('現在集合', 'Gather now'),
        });
        if (ok == true) _shown = key;
      } else if (Platform.isAndroid) {
        await _initAndroid();
        final left = c.at + 30 * 60000 - DateTime.now().millisecondsSinceEpoch;
        await _plugin.show(
          id: _androidId,
          title: '$title · ${g.name}',
          body: place,
          notificationDetails: NotificationDetails(android: AndroidNotificationDetails(
            'gather_live', tx('集合倒數', 'Gather countdown'),
            channelDescription: tx('鎖定畫面上的集合時間與倒數', 'Meeting time and countdown on the lock screen'),
            importance: Importance.low, priority: Priority.low, icon: 'ic_stat_flag', color: g.tint,
            ongoing: true, autoCancel: false, onlyAlertOnce: true, playSound: false, enableVibration: false,
            showWhen: true, when: c.at, usesChronometer: true, chronometerCountDown: true,
            timeoutAfter: left > 0 ? left : null, category: AndroidNotificationCategory.status,
            visibility: NotificationVisibility.public,
          )),
        );
        _shown = key;
      }
    } catch (_) {
    } finally {
      _trying = null;
    }
  }

  static Future<void> end() async {
    if (_shown == null && _swept) return;
    _shown = null;
    _swept = true;
    try {
      if (Platform.isIOS) {
        await _ios.invokeMethod('end');
      } else if (Platform.isAndroid) {
        await _initAndroid();
        await _plugin.cancel(id: _androidId);
      }
    } catch (_) {}
  }

  static Future<void> _initAndroid() async {
    if (_androidReady) return;
    await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_flag')));
    _androidReady = true;
  }
}
