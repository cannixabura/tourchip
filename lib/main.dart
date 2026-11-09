import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'l10n.dart';
import 'screens/call_overlay.dart';
import 'screens/group_screen.dart';
import 'screens/home_screen.dart';
import 'screens/join.dart';
import 'screens/social.dart';
import 'tour/profile.dart';
import 'tour/service.dart';
import 'tour/zones.dart';
import 'ui/night.dart';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 伺服器的無聲推播：App 還在（在背景）就回一聲，地圖上才不會變灰
  if (message.data['type'] == 'tgroup_ping') await TourService.call('pong');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  await initZones();
  await initLang();
  await ProfileStore.init();
  // 不需要帳號：和城市低語一樣用匿名登入；這支 App 的身分和城市低語各自獨立，彼此不相認
  try {
    if (FirebaseAuth.instance.currentUser == null) await FirebaseAuth.instance.signInAnonymously();
  } catch (_) {}
  PassStore.init();
  initUnread();
  runApp(const TourChipApp());
}

class TourChipApp extends StatelessWidget {
  const TourChipApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 設定裡換語言：系統元件（日期、按鈕）跟著換；畫面上的 tx() 由 setLang 整個重畫
    return ValueListenableBuilder<String>(valueListenable: appLang, builder: (context, lang, _) => MaterialApp(
      title: tx('旅行團', 'TourChip'),
      locale: appLocale,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: appLocales,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Night.night900,
        colorScheme: const ColorScheme.dark(primary: Night.auroraViolet, secondary: Night.auroraBlue, surface: Night.night700, error: Night.danger),
        fontFamilyFallback: const ['PingFang TC', 'Noto Sans TC'],
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Night.night700,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Night.radiusSm), borderSide: const BorderSide(color: Night.glassLine)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Night.radiusSm), borderSide: const BorderSide(color: Night.glassLine)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Night.radiusSm), borderSide: const BorderSide(color: Night.auroraViolet, width: 2)),
          labelStyle: Night.caption, hintStyle: Night.caption, counterStyle: Night.caption,
        ),
      ),
      home: const RootGate(),
    ));
  }
}

/// 第一層：讀取中 → 不在團裡顯示首頁，在團裡顯示團的地圖。
/// 也負責推播、入團連結、前景收到集合／點名時的全螢幕卡片。
class RootGate extends StatefulWidget {
  const RootGate({super.key});
  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> with WidgetsBindingObserver {
  StreamSubscription<Uri>? _linkSub;
  bool _overlayOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TourService.refresh();
    TourService.createAndroidChannel();
    TourService.incomingCall.addListener(_onIncomingCall);
    TourService.incomingRoll.addListener(_onIncomingRoll);
    TourService.openChat.addListener(_onOpenChat);
    PassStore.notice.addListener(_onPassNotice);
    PassStore.load();
    _initPush();
    _listenLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TourService.incomingCall.removeListener(_onIncomingCall);
    TourService.incomingRoll.removeListener(_onIncomingRoll);
    TourService.openChat.removeListener(_onOpenChat);
    PassStore.notice.removeListener(_onPassNotice);
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) TourService.refresh();
    if (state == AppLifecycleState.paused) TourService.pause();
  }

  Future<void> _initPush() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
    // 前景時不顯示系統通知，改由 App 自己跳卡片或提示條
    await messaging.setForegroundNotificationPresentationOptions(alert: false, badge: false, sound: false);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    try {
      if (Platform.isIOS) {
        for (var i = 0; i < 15 && await messaging.getAPNSToken() == null; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      final token = await messaging.getToken();
      // 推播權杖存在城市低語同一個 Realtime Database 的 tokens/{uid}（伺服器推播都從這裡找）
      if (token != null) await FirebaseDatabase.instance.ref('tokens/$uid').set(token);
      messaging.onTokenRefresh.listen((t) => FirebaseDatabase.instance.ref('tokens/$uid').set(t));
    } catch (_) {}
    // 點了通知打開 App：私訊直接打開那個人的對話
    void opened(RemoteMessage m) {
      TourService.onPush(m.data);
      if ('${m.data['type']}' == 'tgroup_msg' && '${m.data['from'] ?? ''}'.isNotEmpty) TourService.openChat.value = '${m.data['from']}';
    }
    FirebaseMessaging.onMessageOpenedApp.listen(opened);
    FirebaseMessaging.instance.getInitialMessage().then((m) { if (m != null) opened(m); });
    FirebaseMessaging.onMessage.listen((m) {
      final type = '${m.data['type']}';
      TourService.onPush(m.data);
      if (type == 'tgroup_call' || type == 'tgroup_roll') return; // 由 _apply 跳出全螢幕卡片
      if ((type == 'tgroup_lost' || type == 'tgroup_help') && mounted && !_overlayOpen) {
        _overlayOpen = true;
        showLeaderAlert(context, lost: type == 'tgroup_lost').whenComplete(() => _overlayOpen = false);
        return;
      }
      if (m.notification != null && mounted) {
        showGlassToast(context, '${m.notification!.title ?? ''}  ${m.notification!.body ?? ''}', icon: Icons.campaign_outlined);
      }
    });
  }

  /// QR code、分享連結：https://tourchip.web.app/g/<團代碼>?v=<版本>、/v/<團購券>
  void _listenLinks() {
    final links = AppLinks();
    void handle(Uri? uri) {
      final link = uri == null ? null : parseTourLink(uri.toString());
      if (link == null || !mounted) return;
      openTourLink(context, link);
    }
    links.getInitialLink().then(handle).catchError((_) {});
    _linkSub = links.uriLinkStream.listen(handle, onError: (_) {});
  }

  void _onIncomingCall() {
    final call = TourService.incomingCall.value;
    if (call == null || !mounted || _overlayOpen) return;
    TourService.incomingCall.value = null;
    _overlayOpen = true;
    showCallOverlay(context, call).whenComplete(() => _overlayOpen = false);
  }

  void _onIncomingRoll() {
    final rollId = TourService.incomingRoll.value;
    if (rollId == null || !mounted || _overlayOpen) return;
    TourService.incomingRoll.value = null;
    _overlayOpen = true;
    showRollOverlay(context, rollId).whenComplete(() => _overlayOpen = false);
  }

  /// 等團的資料讀進來再打開對話（從通知冷啟動時還沒讀完）
  Future<void> _onOpenChat() async {
    final uid = TourService.openChat.value;
    if (uid == null || !mounted) return;
    for (var i = 0; i < 20 && TourService.current.value == null; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    TourService.openChat.value = null;
    if (!mounted || TourService.current.value == null) return;
    await openChat(context, uid);
  }

  void _onPassNotice() {
    final msg = PassStore.notice.value;
    if (msg == null || !mounted) return;
    PassStore.notice.value = null;
    showGlassToast(context, msg, icon: Icons.workspace_premium_outlined);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TourService.loaded,
      builder: (context, loaded, _) => ValueListenableBuilder(
        valueListenable: TourService.current,
        builder: (context, g, _) {
          if (!loaded) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Night.auroraViolet)));
          return g == null ? const HomeScreen() : GroupScreen(key: ValueKey(g.code));
        },
      ),
    );
  }
}
