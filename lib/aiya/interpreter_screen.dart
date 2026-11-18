import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:aiya/aiya.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n.dart';
import '../screens/help_card.dart' show localLangFor;
import '../screens/info_screen.dart';
import '../tour/service.dart';
import '../tour/zones.dart' show deviceTz;
import '../translate.dart';
import '../ui/night.dart';
import 'aiya_screen.dart' show askInterpretConsent;
import 'aiya_store.dart';

/// 口譯：團員和當地人（店員、司機）面對面，各說各的語言。
/// 手機平放在桌上：下半是自己、上半倒過來給對方看。
///
/// 兩種做法：
/// - 免費：手機內建的語音辨識（Apple／Google）＋手機上的翻譯（Apple 翻譯／ML Kit）＋手機內建語音念出來。
///   各自按自己那半邊的麥克風，說完停一下就翻譯。旅行團的伺服器收不到聲音，也不存。
/// - 高品質 AI：沿用艾婭語音通話的線路（OpenAI GPT-Live），伺服器把指示換成「只翻譯、不聊天」。
///   雙方直接說，不用按；依秒數扣艾婭的通話時間（tour_aiya_call_*、艾婭之友每月 60 分鐘）。
///   誰說的：看原文是哪一種語言。我們不錄音、不存內容。
Future<void> openInterpreter(BuildContext context, {required Future<void> Function() buyCallTime}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => InterpreterScreen(buyCallTime: buyCallTime)));

/// 口譯可以選的語言：App 的 12 種＋常見旅遊地（伺服器 aiya.js 的 INTERPRET_LANGS 要一致）
const interpLangs = [...supportedLangs, 'fr', 'de', 'it', 'ru', 'tr', 'ar', 'nl'];

const interpLangNames = {
  ...langNames,
  'fr': 'Français', 'de': 'Deutsch', 'it': 'Italiano', 'ru': 'Русский', 'tr': 'Türkçe', 'ar': 'العربية', 'nl': 'Nederlands',
};

/// 語音辨識、朗讀用的地區代碼（依序試）
const _locales = {
  'zh-Hant': ['zh-TW', 'zh-HK', 'yue-HK'], 'zh-Hans': ['zh-CN', 'zh-SG'], 'en': ['en-US', 'en-GB', 'en-AU'],
  'ja': ['ja-JP'], 'ko': ['ko-KR'], 'ms': ['ms-MY'], 'id': ['id-ID'], 'vi': ['vi-VN'], 'th': ['th-TH'],
  'pt': ['pt-BR', 'pt-PT'], 'es': ['es-ES', 'es-MX', 'es-US'], 'hi': ['hi-IN'],
  'fr': ['fr-FR', 'fr-CA'], 'de': ['de-DE', 'de-AT', 'de-CH'], 'it': ['it-IT'], 'ru': ['ru-RU'], 'tr': ['tr-TR'],
  'ar': ['ar-SA', 'ar-AE', 'ar-EG'], 'nl': ['nl-NL', 'nl-BE'],
};

/// 對方預設說什麼：依現在所在地（集合點、行程表的時區；沒入團就看手機的時區）
String interpLangFor(String tz) {
  if (const ['Europe/Paris', 'Europe/Monaco', 'Europe/Brussels', 'Europe/Luxembourg'].contains(tz)) return 'fr';
  if (const ['Europe/Berlin', 'Europe/Vienna', 'Europe/Zurich'].contains(tz)) return 'de';
  if (const ['Europe/Rome', 'Europe/Vatican', 'Europe/San_Marino', 'Europe/Malta'].contains(tz)) return 'it';
  if (const ['Europe/Moscow', 'Europe/Minsk'].contains(tz)) return 'ru';
  if (tz == 'Europe/Istanbul' || tz == 'Asia/Istanbul') return 'tr';
  if (tz == 'Europe/Amsterdam') return 'nl';
  if (const ['Asia/Dubai', 'Asia/Riyadh', 'Asia/Qatar', 'Asia/Kuwait', 'Asia/Bahrain', 'Asia/Muscat', 'Asia/Amman', 'Africa/Cairo', 'Africa/Casablanca'].contains(tz)) return 'ar';
  return localLangFor(tz);
}

class _Turn {
  /// true＝自己說的、false＝對方說的、null＝還不知道（高品質 AI 剛開始翻）
  bool? mine;
  String original;
  String translated = '';
  _Turn({this.mine, this.original = ''});
}

enum _Mode { free, premium }

class InterpreterScreen extends StatefulWidget {
  final Future<void> Function() buyCallTime;
  const InterpreterScreen({super.key, required this.buyCallTime});
  @override
  State<InterpreterScreen> createState() => _InterpreterScreenState();
}

class _InterpreterScreenState extends State<InterpreterScreen> {
  static const _kMe = 'interp_me', _kMode = 'interp_mode', _kPremiumOk = 'interp_premium_ok';
  static String _kOther(String tz) => 'interp_other:$tz';

  String _me = lang, _other = 'en';
  String _tz = deviceTz;
  _Mode _mode = _Mode.free;
  final _turns = <_Turn>[];

  // 免費：手機內建
  final _stt = SpeechToText();
  final _tts = FlutterTts();
  bool _sttReady = false;
  List<String>? _sttLocales;
  bool? _listeningMine; // 正在聽哪一邊；null＝沒在聽
  String _partial = '';
  bool _finalized = false;
  bool _working = false; // 翻譯中
  double _level = 0;

  // 高品質 AI：艾婭的通話線路
  final _call = AiyaCall(aiyaApi);
  String _inBuf = '';
  _Turn? _liveTurn;
  bool _outStarted = false;
  bool _resolving = false;
  Timer? _clock;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _call.state.addListener(_onCallState);
    _call.onEvent = _onLiveEvent;
    _call.onEnded = _onLiveEnded;
    _tts.setCompletionHandler(() {});
    _init();
  }

  Future<void> _init() async {
    final g = TourService.current.value;
    _tz = g != null ? InfoScreen.hereTz(g) : deviceTz;
    final p = await SharedPreferences.getInstance();
    final me = p.getString(_kMe);
    _me = me != null && interpLangs.contains(me) ? me : lang;
    final other = p.getString(_kOther(_tz));
    var def = interpLangFor(_tz);
    if (def == _me || ChatTranslator.sameBase(def, _me)) def = _me == 'en' ? 'zh-Hant' : 'en';
    _other = other != null && interpLangs.contains(other) && other != _me ? other : def;
    _mode = p.getString(_kMode) == 'premium' ? _Mode.premium : _Mode.free;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _clock?.cancel();
    _call.state.removeListener(_onCallState);
    _call.onEvent = null;
    _call.onEnded = null;
    if (_call.state.value != AiyaCallState.idle) unawaited(_call.hangUp());
    unawaited(_stt.cancel());
    unawaited(_tts.stop());
    super.dispose();
  }

  void _toast(String text, {bool danger = false}) {
    if (mounted) showGlassToast(context, text, icon: danger ? Icons.error_outline : Icons.translate_rounded, danger: danger);
  }

  bool get _live => _call.state.value == AiyaCallState.live;
  bool get _callBusy => _call.state.value != AiyaCallState.idle;

  // ───────────────────────── 免費：手機內建 ─────────────────────────

  Future<String?> _sttLocale(String l) async {
    _sttLocales ??= [for (final x in await _stt.locales()) x.localeId.replaceAll('_', '-')];
    final have = _sttLocales!;
    String? find(bool Function(String) ok) => have.where(ok).firstOrNull;
    for (final want in _locales[l] ?? [l]) {
      final hit = find((x) => x.toLowerCase() == want.toLowerCase());
      if (hit != null) return hit;
    }
    final base = l.split('-').first;
    if (base == 'zh') {
      final hant = l == 'zh-Hant';
      return find((x) => x.startsWith('zh') && (hant ? RegExp('TW|HK|Hant').hasMatch(x) : RegExp('CN|SG|Hans').hasMatch(x)));
    }
    return find((x) => x.split('-').first == base);
  }

  Future<void> _tapMic(bool mine) async {
    HapticFeedback.selectionClick();
    if (_mode == _Mode.premium) {
      if (_live && mine) {
        await _call.hangUp();
      } else if (!_callBusy) {
        await _startPremium();
      }
      return;
    }
    if (_working) return;
    if (_listeningMine != null) {
      final same = _listeningMine == mine;
      await _stt.stop(); // 停下來就翻譯目前聽到的
      if (same) return;
    }
    await _tts.stop();
    if (!_sttReady) {
      _sttReady = await _stt.initialize(onStatus: _onSttStatus, onError: (e) {
        if (!mounted) return;
        if (e.errorMsg == 'error_no_match' || e.errorMsg == 'error_speech_timeout') {
          setState(() { _listeningMine = null; _partial = ''; });
        }
      });
      if (!_sttReady) {
        _toast(tx('要允許麥克風和語音辨識才能口譯，可以到手機的「設定」打開', 'Allow the microphone and speech recognition to interpret. You can turn them on in Settings'), danger: true);
        return;
      }
    }
    final l = mine ? _me : _other;
    final locale = await _sttLocale(l);
    if (locale == null) {
      _toast(tx('這支手機不能聽寫${interpLangNames[l]}，可以改用「高品質 AI」', 'This phone can\'t recognize ${interpLangNames[l]}. Try Premium AI'), danger: true);
      return;
    }
    setState(() { _listeningMine = mine; _partial = ''; _finalized = false; _level = 0; });
    try {
      await _stt.listen(
        onResult: (r) => _onSttResult(r, mine),
        onSoundLevelChange: (v) { if (mounted) setState(() => _level = v); },
        listenOptions: SpeechListenOptions(
          localeId: locale, partialResults: true, cancelOnError: true, listenMode: ListenMode.dictation, autoPunctuation: true,
          pauseFor: const Duration(seconds: 2), listenFor: const Duration(seconds: 40),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _listeningMine = null);
      _toast(tx('麥克風沒有反應，請再試一次', 'The microphone didn\'t start. Please try again'), danger: true);
    }
  }

  void _onSttResult(SpeechRecognitionResult r, bool mine) {
    if (!mounted || _finalized) return;
    setState(() => _partial = r.recognizedWords);
    if (r.finalResult) _finish(mine);
  }

  void _onSttStatus(String s) {
    if (!mounted) return;
    if ((s == 'done' || s == 'notListening') && _listeningMine != null && !_finalized) {
      // 停止時沒收到最後結果：用目前聽到的
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _listeningMine != null && !_finalized) _finish(_listeningMine!);
      });
    }
  }

  Future<void> _finish(bool mine) async {
    if (_finalized) return;
    _finalized = true;
    final text = _partial.trim();
    setState(() { _listeningMine = null; _partial = ''; _level = 0; });
    if (text.isEmpty) return;
    final from = mine ? _me : _other, to = mine ? _other : _me;
    final turn = _Turn(mine: mine, original: text);
    setState(() { _turns.add(turn); _working = true; });
    final out = await ChatTranslator.translatePair(context, text, from, to);
    if (!mounted) return;
    setState(() {
      _working = false;
      if (out == null) {
        _turns.remove(turn); // 翻不了：不要留下一句對方看不懂的
      } else {
        turn.translated = out;
      }
    });
    if (out == null) {
      _toast(tx('手機上沒辦法翻譯${interpLangNames[from]} → ${interpLangNames[to]}，可以改用「高品質 AI」', 'Your phone can\'t translate ${interpLangNames[from]} → ${interpLangNames[to]}. Try Premium AI'), danger: true);
      return;
    }
    await _say(out, to);
  }

  Future<void> _say(String text, String l) async {
    try {
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playAndRecord, [
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      ], IosTextToSpeechAudioMode.voicePrompt);
      String? locale;
      for (final x in _locales[l] ?? [l]) {
        if (await _tts.isLanguageAvailable(x) == true) { locale = x; break; }
      }
      await _tts.setLanguage(locale ?? (_locales[l]?.first ?? l));
      await _tts.setSpeechRate(Platform.isIOS ? 0.5 : 0.9);
      await _tts.speak(text);
    } catch (_) {}
  }

  // ───────────────────────── 高品質 AI ─────────────────────────

  Future<void> _startPremium() async {
    if (_starting || _callBusy) return;
    setState(() => _starting = true);
    try {
      var st = await aiyaCall('status');
      if (!mounted) return;
      AiyaStore.applyStatus(st);
      int secs() => (st['callSecondsLeft'] as num?)?.toInt() ?? 0;
      if (secs() < 30) {
        await widget.buyCallTime();
        if (!mounted) return;
        st = await aiyaCall('status');
        if (!mounted || secs() < 30) return;
      }
      final p = await SharedPreferences.getInstance();
      if (p.getBool(_kPremiumOk) != true) {
        if (!mounted || !await askInterpretConsent(context)) return;
        await p.setBool(_kPremiumOk, true);
      }
      if (st['voiceConsented'] != true) {
        final r = await aiyaCall('voiceConsent');
        if (r['success'] != true) { _toast(tx('沒有接通，請稍後再試。', 'Couldn\'t connect. Please try again later.'), danger: true); return; }
      }
      // 伺服器一個人同時只能有一通：艾婭的通話先掛掉
      if (aiyaPhone.state.value != AiyaCallState.idle) await aiyaPhone.hangUp();
      await _stt.cancel();
      await _tts.stop();
      _inBuf = '';
      _liveTurn = null;
      _outStarted = false;
      final code = await _call.start(body: {'mode': 'interpret', 'langA': _me, 'langB': _other});
      if (!mounted) return;
      if (code == null) {
        _clock ??= Timer.periodic(const Duration(seconds: 1), (_) { if (mounted && _live) setState(() {}); });
        return;
      }
      switch (code) {
        case 'no_minutes' || 'friend_only': await widget.buyCallTime();
        case 'mic_denied': _toast(tx('要允許使用麥克風才能口譯，可以到手機的「設定」打開', 'Allow the microphone to interpret. You can turn it on in Settings'), danger: true);
        case 'call_resting': _toast(tx('艾婭的語音線路今天太忙了，晚點再試', 'AIYA\'s voice line is too busy today. Try again later'), danger: true);
        default: _toast(tx('沒有接通，請稍後再試。', 'Couldn\'t connect. Please try again later.'), danger: true);
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _onCallState() {
    if (mounted) setState(() {});
  }

  void _onLiveEnded(String reason) {
    _clock?.cancel();
    _clock = null;
    if (!mounted) return;
    setState(() {});
    aiyaCall('status').then(AiyaStore.applyStatus);
    _toast(switch (reason) {
      'time_up' => tx('通話時間用完了，口譯已結束', 'Out of call time. Interpreting ended'),
      'idle' => tx('一段時間沒有人說話，口譯已結束', 'No one spoke for a while, so interpreting ended'),
      'hangup' => tx('口譯已結束', 'Interpreting ended'),
      _ => tx('連線中斷，口譯已結束', 'Connection lost. Interpreting ended'),
    });
  }

  void _onLiveEvent(Map<String, dynamic> e) {
    if (!mounted) return;
    final type = '${e['type']}';
    final delta = '${e['delta'] ?? ''}';
    if (type == 'session.input_transcript.delta') {
      if (_outStarted) {
        // 上一句翻完了，這是新的一句
        _inBuf = '';
        _liveTurn = null;
        _outStarted = false;
      }
      _inBuf += delta;
      _liveTurn?.original = _inBuf;
      setState(() {});
    } else if (type == 'session.output_transcript.delta') {
      if (_liveTurn == null) {
        _liveTurn = _Turn(original: _inBuf);
        _turns.add(_liveTurn!);
      }
      _outStarted = true;
      _liveTurn!.translated += delta;
      _liveTurn!.original = _inBuf;
      setState(() {});
      unawaited(_resolve(_liveTurn!));
    }
  }

  /// 這一句是誰說的：先看原文的語言，看不出來再看譯文；都不行就跟上一句相反
  Future<void> _resolve(_Turn t) async {
    if (t.mine != null || _resolving) return;
    _resolving = true;
    try {
      bool? side;
      if (t.original.trim().length >= 2) {
        final d = await ChatTranslator.detect(t.original);
        if (d != null) {
          if (ChatTranslator.sameBase(d, _me) && !ChatTranslator.sameBase(d, _other)) side = true;
          if (ChatTranslator.sameBase(d, _other) && !ChatTranslator.sameBase(d, _me)) side = false;
        }
      }
      if (side == null && t.translated.trim().length >= 6) {
        final d = await ChatTranslator.detect(t.translated);
        if (d != null) {
          if (ChatTranslator.sameBase(d, _other) && !ChatTranslator.sameBase(d, _me)) side = true;
          if (ChatTranslator.sameBase(d, _me) && !ChatTranslator.sameBase(d, _other)) side = false;
        }
      }
      if (side == null && t.translated.trim().length >= 24) {
        final i = _turns.indexOf(t);
        final prev = i > 0 ? _turns[i - 1].mine : null;
        side = prev == null ? true : !prev;
      }
      if (side != null && mounted) setState(() => t.mine = side);
    } finally {
      _resolving = false;
    }
  }

  String _timeLeft() {
    final end = _call.endsAt;
    if (end == null) return '';
    final s = max(0, end.difference(DateTime.now()).inSeconds);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ───────────────────────── 設定 ─────────────────────────

  Future<void> _setMode(_Mode m) async {
    if (m == _mode) return;
    await _stt.cancel();
    await _tts.stop();
    if (_callBusy) await _call.hangUp();
    setState(() { _mode = m; _listeningMine = null; _partial = ''; });
    (await SharedPreferences.getInstance()).setString(_kMode, m == _Mode.premium ? 'premium' : 'free');
  }

  Future<void> _pickLang(bool mine) async {
    final current = mine ? _me : _other;
    final picked = await showModalBottomSheet<String>(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Night.space4),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            child: GlassCard(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(mine ? tx('我說的語言', 'My language') : tx('對方說的語言', 'Their language'), style: Night.title, textAlign: TextAlign.center),
                const SizedBox(height: Night.space3),
                Flexible(
                  child: ListView(shrinkWrap: true, children: [
                    for (final l in interpLangs)
                      ListTile(
                        dense: true,
                        title: Text(interpLangNames[l]!, style: TextStyle(color: l == current ? Night.auroraBlue : Night.ink, fontSize: 16)),
                        trailing: l == current ? const Icon(Icons.check, color: Night.auroraBlue) : null,
                        onTap: () => Navigator.pop(ctx, l),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    if (picked == null || picked == current || !mounted) return;
    await _stt.cancel();
    final wasLive = _callBusy;
    if (wasLive) await _call.hangUp();
    final p = await SharedPreferences.getInstance();
    setState(() {
      if (mine) {
        if (picked == _other) _other = _me;
        _me = picked;
      } else {
        if (picked == _me) _me = _other;
        _other = picked;
      }
      _listeningMine = null;
    });
    await p.setString(_kMe, _me);
    await p.setString(_kOther(_tz), _other);
    if (wasLive) _toast(tx('語言改了，請再按一次開始', 'Language changed. Tap start again'));
  }

  // ───────────────────────── 畫面 ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Night.night900,
      body: SafeArea(
        child: Column(children: [
          Expanded(child: RotatedBox(quarterTurns: 2, child: _half(false))),
          _centerBar(),
          Expanded(child: _half(true)),
        ]),
      ),
    );
  }

  Widget _centerBar() {
    Widget seg(String label, _Mode m, IconData icon) {
      final on = _mode == m;
      return GestureDetector(
        onTap: () => _setMode(m),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: on ? Night.night600 : Colors.transparent,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: on ? Night.ink : Night.inkFaint),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: on ? Night.ink : Night.inkFaint, fontSize: 13, fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Night.space2, vertical: 6),
      decoration: const BoxDecoration(
        color: Night.night800,
        border: Border.symmetric(horizontal: BorderSide(color: Night.glassLine, width: 0.5)),
      ),
      child: Row(children: [
        IconButton(
          tooltip: tx('結束口譯', 'Close interpreter'),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded, color: Night.inkMuted),
        ),
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: Night.glassLine)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                seg(tx('免費', 'Free'), _Mode.free, Icons.phone_iphone_rounded),
                seg(tx('高品質 AI', 'Premium AI'), _Mode.premium, Icons.auto_awesome),
              ]),
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: _live
              ? Text(_timeLeft(), style: const TextStyle(color: Night.auroraBlue, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]), textAlign: TextAlign.center)
              : IconButton(tooltip: tx('說明', 'About'), onPressed: _about, icon: const Icon(Icons.info_outline_rounded, color: Night.inkFaint, size: 20)),
        ),
      ]),
    );
  }

  void _about() {
    showModalBottomSheet<void>(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Night.space4),
          child: GlassCard(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.translate_rounded, color: Color(0xFFFFC861), size: 32),
              const SizedBox(height: Night.space3),
              Text(tx('艾婭口譯', 'AIYA interpreter'), style: Night.title, textAlign: TextAlign.center),
              const SizedBox(height: Night.space3),
              Text(tx('手機平放在桌上，你看下半、對方看上半（已經倒過來）。',
                  'Lay the phone flat between you: you read the bottom half, the other person reads the top half (it\'s upside down for them).'), style: Night.body),
              const SizedBox(height: Night.space3),
              Text(tx('免費：按自己那半邊的麥克風說話，說完停一下就會翻譯並念出來。語音辨識與翻譯由手機系統（Apple／Google）處理，旅行團收不到也不存你的聲音。',
                  'Free: tap the mic on your half, speak, then pause. It translates and reads it aloud. Speech recognition and translation are done by your phone\'s system (Apple/Google); TourChip never receives or keeps your voice.'), style: Night.body),
              const SizedBox(height: Night.space3),
              Text(tx('高品質 AI：雙方直接說，不用按。聲音即時送到 OpenAI 翻譯，依秒數扣艾婭的通話時間，我們不錄音。',
                  'Premium AI: both of you just talk, no buttons. Voices are sent live to OpenAI for translation and call time is used by the second. We don\'t record anything.'), style: Night.body),
              const SizedBox(height: Night.space3),
              Text(tx('翻譯可能出錯，金額、藥物、過敏等重要的事請再確認。', 'Translations can be wrong: double-check prices, medicine, allergies and other important things.'), style: Night.caption),
              const SizedBox(height: Night.space4),
              NightButton(tx('知道了', 'Got it'), onPressed: () => Navigator.pop(ctx)),
            ]),
          ),
        ),
      ),
    );
  }

  /// 半邊畫面：mine＝自己（下半），否則是對方（上半，倒過來）
  Widget _half(bool mine) {
    final l = mine ? _me : _other, otherL = mine ? _other : _me;
    final listening = _listeningMine == mine;
    final premium = _mode == _Mode.premium;

    String hint;
    if (premium) {
      hint = _live
          ? mine ? tx('直接說話，艾婭會翻譯・按 ■ 結束', 'Just speak. AIYA will translate · Tap ■ to end') : txIn(l, '直接說話，艾婭會翻譯', 'Just speak. AIYA will translate')
          : _call.state.value == AiyaCallState.connecting || _starting
              ? txIn(l, '連線中…', 'Connecting…')
              : mine ? tx('按麥克風開始高品質 AI 口譯', 'Tap the mic to start Premium AI') : txIn(l, '請稍候', 'One moment, please');
    } else {
      hint = listening ? txIn(l, '請說…說完停一下', 'Speak… then pause') : txIn(l, '按麥克風說話', 'Tap the mic and speak');
    }

    // 最新的一句在最靠近麥克風的地方（清單倒過來排）
    final items = _turns.reversed.where((x) => x.mine != null || premium).toList();
    return Container(
      color: mine ? Night.night900 : const Color(0xFF0B1030),
      padding: const EdgeInsets.fromLTRB(Night.space4, Night.space3, Night.space4, Night.space3),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => _pickLang(mine),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: Night.glassLine)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(interpLangNames[l]!, style: const TextStyle(color: Night.ink, fontSize: 14)),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more_rounded, color: Night.inkMuted, size: 18),
              ]),
            ),
          ),
          const Spacer(),
          if (!mine) Text(txIn(l, 'AI 口譯', 'AI interpreter'), style: Night.caption),
        ]),
        Expanded(
          child: items.isEmpty && !listening
              ? Center(child: Text(mine ? tx('說一句話，對方會聽到翻譯', 'Say something and they\'ll hear the translation') : txIn(l, '你好！我用手機翻譯，請對著手機說話', 'Hello! I\'m using a translator app. Please speak to the phone'),
                  style: TextStyle(color: mine ? Night.inkFaint : Night.inkMuted, fontSize: mine ? 15 : 19, height: 1.5), textAlign: TextAlign.center))
              : ListView(reverse: true, padding: const EdgeInsets.symmetric(vertical: Night.space3), children: [
                  if (listening && _partial.isNotEmpty) _bubble(_partial, '', fromHere: true, faint: true),
                  for (final x in items.take(8)) _turnBubble(x, mine, l, otherL),
                ]),
        ),
        _micButton(mine, listening),
        const SizedBox(height: Night.space2),
        Text(hint, style: Night.caption, textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _turnBubble(_Turn x, bool readerMine, String l, String otherL) {
    // 這一半的讀者看自己的語言：自己說的看原文、對方說的看譯文
    final fromHere = x.mine == null ? !readerMine : x.mine == readerMine;
    final big = fromHere ? x.original : x.translated;
    final small = fromHere ? x.translated : x.original;
    final pending = !fromHere && big.isEmpty;
    return _bubble(pending ? '…' : big, small, fromHere: fromHere);
  }

  Widget _bubble(String big, String small, {required bool fromHere, bool faint = false}) {
    return Align(
      alignment: fromHere ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromHere ? Night.night700 : const Color(0xFF1E2A66),
          borderRadius: BorderRadius.circular(Night.radiusMd),
          border: Border.all(color: fromHere ? Night.glassLine : const Color(0x664FC3F7)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(big, style: TextStyle(color: faint ? Night.inkMuted : Night.ink, fontSize: fromHere ? 17 : 22, height: 1.4, fontWeight: fromHere ? FontWeight.w400 : FontWeight.w500)),
          if (small.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(small, style: const TextStyle(color: Night.inkFaint, fontSize: 13, height: 1.35)),
          ],
        ]),
      ),
    );
  }

  Widget _micButton(bool mine, bool listening) {
    final premium = _mode == _Mode.premium;
    final connecting = premium && (_starting || _call.state.value == AiyaCallState.connecting);
    final busy = !premium && _working && !listening;
    final active = listening || (premium && _live);
    final pulse = listening ? (1 + (_level.clamp(-2, 10) + 2) / 12 * 0.25) : 1.0;
    final enabled = premium ? (mine && !_callBusy && !_starting) || _live : !_working;
    final ml = mine ? _me : _other;
    return Semantics(
      button: true,
      label: listening ? txIn(ml, '停止', 'Stop') : txIn(ml, '說話', 'Speak'),
      child: GestureDetector(
        onTap: enabled && !(premium && _live && !mine) ? () => _tapMic(mine) : null,
        child: AnimatedScale(
          scale: pulse,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 76, height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: active ? const LinearGradient(colors: [Color(0xFFFF5F8A), Color(0xFFB44CFF)]) : (enabled ? Night.deepGradient : null),
              color: enabled || active ? null : Night.night700,
              boxShadow: active ? const [BoxShadow(color: Color(0x80FF5F8A), blurRadius: 24)] : const [Night.glowViolet],
            ),
            child: connecting || busy
                ? const Padding(padding: EdgeInsets.all(26), child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Icon(
                    premium && _live ? (mine ? Icons.stop_rounded : Icons.graphic_eq_rounded) : listening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: enabled || active ? Colors.white : Night.inkFaint, size: 34,
                  ),
          ),
        ),
      ),
    );
  }
}
