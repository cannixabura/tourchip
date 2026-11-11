import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:aiya/aiya.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import '../map/tour_map.dart';
import '../ui/night.dart';
import 'aiya_store.dart';

const _site = 'https://tourchip.web.app';

/// 打開艾婭（首頁、團的畫面右上角）
/// 不透明的頁面：淡入結束後，底下的 3D 地圖就停止繪製；聊天期間地圖的羅盤、傾斜、定位也暫停（省電、不發燙）。
/// 回報給同團的位置（TourService）不暫停，團員和領隊照樣看得到你。
Future<void> openAiya(BuildContext context) async {
  TourMapState.paused.value = true;
  try {
    await Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) => const AiyaScreen(),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
    ));
  } finally {
    TourMapState.paused.value = false;
  }
}

/// 右上角的艾婭按鈕（金色小光點）
class AiyaButton extends StatelessWidget {
  const AiyaButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tx('艾婭 AI 小助理', 'AIYA, AI assistant'),
        // 去背的艾婭頭像（頭冠到肩膀，下緣淡出），不加圓框，半透明
        icon: const Opacity(
          opacity: 0.45,
          child: Image(image: AssetImage('assets/images/aiya_avatar.png'), width: 38, height: 38, fit: BoxFit.contain),
        ),
        onPressed: () => openAiya(context),
      );
}

class _LiveLine {
  final _Msg msg;
  String target = '';
  int shown = 0;
  bool done = false;
  String expression = 'smile';
  _LiveLine(this.msg);

  void finish(String reply, String expr) {
    final full = reply.characters.toList();
    if (!reply.startsWith(msg.text)) {
      shown = shown < full.length ? shown : full.length;
      msg.text = full.take(shown).join();
    }
    target = reply;
    expression = expr;
    done = true;
  }
}

class _Msg {
  final bool mine;
  String text;
  final bool system; // 提示（不是艾婭說的，不能檢舉）
  _Msg(this.text, {this.mine = false, this.system = false});
}

class AiyaScreen extends StatefulWidget {
  const AiyaScreen({super.key});
  @override
  State<AiyaScreen> createState() => _AiyaScreenState();
}

class _AiyaScreenState extends State<AiyaScreen> with SingleTickerProviderStateMixin {
  final _anim = AiyaAnimator();
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero, _due = Duration.zero;
  AiyaHolo? _holo;
  ui.Image? _sprite;
  AiyaHoloBuffers? _buf;
  final _video = AiyaVideo();
  final _rnd = Random();

  final _msgs = <_Msg>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  String? _sessionId;
  DateTime? _endsAt;
  int _turnsLeft = 0;
  int _freeLeft = 0, _credits = 0;
  bool _sending = false, _ended = false, _opening = true;
  bool _voiceConsented = false;
  int _callSecondsLeft = 0;
  Timer? _clock, _typer;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((now) {
      // 影片每秒 24 格：畫面也每秒畫 24 張，不跟著 120Hz 螢幕一直重畫（省電、不發燙）。
      // 用排定的時間對齊：60Hz 螢幕會 33／50 毫秒交錯，平均仍是每秒 24 張
      if (now < _due - const Duration(milliseconds: 4)) return;
      final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.06);
      _last = now;
      _due += const Duration(microseconds: 41667);
      if (_due < now) _due = now; // 落後太多（例如剛從背景回來）就從現在重新算
      _anim.update(dt);
      _frame.value++;
    })..start();
    _video.onEnd = (_) => _video.play('idle', _anim.time, loop: true);
    AiyaStore.notice.addListener(_onNotice);
    AiyaStore.credits.addListener(_onCredits);
    AiyaStore.friendExp.addListener(_onFriend);
    AiyaStore.callBought.addListener(_onCallBought);
    aiyaPhone.aiyaSpeaking.addListener(_onVoice);
    aiyaPhone.state.addListener(_onCallState);
    aiyaPhone.onEnded = _onCallEnded;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _anim.reduceMotion = MediaQuery.of(context).disableAnimations;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _video.dispose();
    _clock?.cancel();
    _typer?.cancel();
    AiyaStore.notice.removeListener(_onNotice);
    AiyaStore.credits.removeListener(_onCredits);
    AiyaStore.friendExp.removeListener(_onFriend);
    AiyaStore.callBought.removeListener(_onCallBought);
    aiyaPhone.aiyaSpeaking.removeListener(_onVoice);
    aiyaPhone.state.removeListener(_onCallState);
    aiyaPhone.onEnded = null;
    if (aiyaPhone.state.value != AiyaCallState.idle) unawaited(aiyaPhone.hangUp());
    _input.dispose();
    _scroll.dispose();
    _frame.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([AiyaHolo.load(), aiyaDotSprite(), _video.preload(['idle', 'hello', 'think'])]);
    if (!mounted) return;
    await _video.play('idle', _anim.time, loop: true);
    unawaited(_video.preload(aiyaExprClip.values.toSet().union(aiyaTalkClips.toSet())));
    setState(() {
      _holo = results[0] as AiyaHolo;
      _sprite = results[1] as ui.Image;
      _buf = AiyaHoloBuffers(_holo!.faceCount, _holo!.count - _holo!.faceCount);
    });
    final status = await aiyaCall('status');
    if (!mounted) return;
    _applyStatus(status);
    if (status['consented'] != true) {
      final agreed = await askAiyaConsent(context);
      if (!mounted) return;
      if (!agreed) { Navigator.of(context).pop(); return; }
      await aiyaCall('consent');
    }
    // 有通話時間就直接接通語音；沒有就先給買通話時間的選項（也可以先用文字聊）
    final choice = _callSecondsLeft >= 30 ? 'call' : await _showCallPacks(entry: true);
    if (!mounted) return;
    if (choice == 'call') {
      setState(() => _opening = false);
      _anim.formTarget = 1;
      await _startCall();
      if (mounted && aiyaPhone.state.value == AiyaCallState.idle && _sessionId == null) await _open();
      return;
    }
    await _open();
  }

  void _applyStatus(Map<String, dynamic> s) {
    AiyaStore.applyStatus(s);
    if (s['freeLeft'] is num) _freeLeft = (s['freeLeft'] as num).toInt();
    if (s['credits'] is num) _credits = (s['credits'] as num).toInt();
    if (s['callSecondsLeft'] is num) _callSecondsLeft = (s['callSecondsLeft'] as num).toInt();
    if (s['voiceConsented'] is bool) _voiceConsented = s['voiceConsented'] as bool;
    final session = s['session'];
    if (session is Map) {
      _sessionId = '${session['id']}';
      _turnsLeft = (session['turnsLeft'] as num?)?.toInt() ?? 0;
      _endsAt = DateTime.now().add(Duration(milliseconds: (session['remainingMs'] as num?)?.toInt() ?? 0));
    }
    if (mounted) setState(() {});
  }

  Future<void> _open({bool greet = true}) async {
    setState(() => _opening = true);
    final r = await aiyaCall('open');
    if (!mounted) return;
    _applyStatus(r);
    setState(() => _opening = false);
    if (r['success'] != true) {
      final code = '${r['code']}';
      if (code == 'no_quota') { _showPacks(); return; }
      _system(switch (code) {
        'resting' => tx('艾婭今天累了，明天再來找她吧。', 'AIYA is resting today. See you tomorrow.'),
        'daily_max' => tx('今天聊了很多了，明天再來找艾婭吧。', 'You\'ve talked a lot today. Come back tomorrow.'),
        _ => _busyText(),
      });
      return;
    }
    _ended = false;
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _anim.knock();
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    _anim.formTarget = 1;
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    if (greet && (r['resumed'] != true || _msgs.isEmpty)) {
      _speak(tx('嗨，我是艾婭，這趟旅程的 AI 小助理。行程、集合時間、當地的事，都可以問我。', 'Hi, I\'m AIYA, your AI travel helper. Ask me about the itinerary, meeting times or anything local.'), 'smile', talkClip: 'hello');
    }
  }

  String _busyText() => tx('艾婭剛剛恍神了一下，可以再說一次嗎？', 'AIYA drifted off for a second. Could you say that again?');
  String _callFailed() => tx('沒有接通，請稍後再試。', 'Couldn\'t connect. Please try again later.');

  void _tick() {
    if (!mounted) return;
    if (_endsAt == null) {
      if (aiyaPhone.state.value == AiyaCallState.live) setState(() {});
      return;
    }
    setState(() {});
    if (!_ended && aiyaPhone.state.value == AiyaCallState.idle && DateTime.now().isAfter(_endsAt!)) _finish();
  }

  Future<void> _finish() async {
    if (_ended) return;
    _ended = true;
    _clock?.cancel();
    _speak(tx('時間到了，我先回到光裡。旅途中有需要再叫我喔。', 'Time\'s up. I\'ll head back into the light. Call me any time on the trip.'), 'smile');
    unawaited(aiyaCall('close'));
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) setState(() => _anim.formTarget = 0);
  }

  void _onVoice() {
    if (!mounted || aiyaPhone.state.value != AiyaCallState.live) return;
    _video.play(aiyaPhone.aiyaSpeaking.value ? aiyaTalkClips[_rnd.nextInt(aiyaTalkClips.length)] : 'idle', _anim.time, loop: true);
  }

  void _onCallState() {
    if (mounted) setState(() {});
  }

  void _onCallEnded(String reason) {
    if (!mounted) return;
    final line = aiyaPhone.aiyaLine.value.trim();
    if (line.isNotEmpty) setState(() => _msgs.add(_Msg(line)));
    _video.play('idle', _anim.time, loop: true);
    aiyaCall('status').then((st) {
      if (!mounted) return;
      _applyStatus(st);
      final outOfTime = reason == 'time_up' && _callSecondsLeft < 30;
      _system(outOfTime
          ? tx('通話時間用完了', 'You\'re out of call time')
          : switch (reason) {
              'time_up' => tx('這通已經聊了很久，休息一下再打給艾婭吧', 'That was a long call. Take a break and call AIYA again'),
              'idle' => tx('一段時間沒有人說話，通話已結束', 'No one spoke for a while, so the call ended'),
              _ => tx('通話已結束', 'Call ended'),
            });
      if (outOfTime) _showCallPacks();
    });
  }

  void _onCallBought() {
    if (!mounted) return;
    aiyaCall('status').then((st) async {
      if (!mounted) return;
      _applyStatus(st);
      Navigator.of(context).popUntil((r) => r.settings.name != 'aiyaCallPacks');
      if (_callSecondsLeft >= 30 && aiyaPhone.state.value == AiyaCallState.idle) await _startCall();
    });
  }

  Widget _sheet(Widget child, {bool scroll = false}) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Night.space4),
          child: GlassCard(child: scroll ? SingleChildScrollView(child: child) : child),
        ),
      );

  Widget get _spinner => const Padding(
      padding: EdgeInsets.all(Night.space2), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))));

  /// 買通話時間：時間包＋艾婭之友；entry=true 時多一個「先用文字聊」。回傳 'text' 或 null
  Future<String?> _showCallPacks({bool entry = false}) {
    AiyaStore.load();
    return showModalBottomSheet<String>(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true, routeSettings: const RouteSettings(name: 'aiyaCallPacks'),
      builder: (ctx) => _sheet(AnimatedBuilder(
        animation: Listenable.merge([AiyaStore.details, AiyaStore.busy, AiyaStore.friendExp]),
        builder: (context, _) {
          final busy = AiyaStore.busy.value;
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.graphic_eq_rounded, color: Color(0xFF4C7DFF), size: 32),
            const SizedBox(height: Night.space3),
            Text(tx('和艾婭語音通話', 'Voice call with AIYA'), style: Night.title, textAlign: TextAlign.center),
            const SizedBox(height: Night.space3),
            Text(tx('用說的問艾婭，就像打電話一樣，走路、拿行李時也方便。買通話時間就能打，艾婭之友每月還送 60 分鐘。',
                'Talk to AIYA out loud, like a phone call, handy while walking or carrying bags. Buy call time to start; AIYA Friends get 60 free minutes every month.'), style: Night.body),
            const SizedBox(height: Night.space4),
            for (final e in AiyaStore.callProducts.entries) ...[
              NightButton(
                '${tx('${e.value} 分鐘', '${e.value} minutes')}  ·  ${AiyaStore.priceOf(e.key)}',
                kind: e.value == 60 ? NightButtonKind.primary : NightButtonKind.ghost,
                icon: Icons.graphic_eq_rounded,
                onPressed: busy ? null : () => AiyaStore.buy(e.key),
              ),
              const SizedBox(height: Night.space2),
            ],
            if (!AiyaStore.isFriend) ...[
              NightButton(tx('成為艾婭之友（每月 60 分鐘）', 'Become an AIYA Friend (60 min a month)'), kind: NightButtonKind.warm, icon: Icons.auto_awesome,
                  onPressed: () { Navigator.pop(ctx); _showFriend(); }),
              const SizedBox(height: Night.space2),
            ],
            if (entry) ...[
              NightButton(tx('先用文字聊', 'Chat by text for now'), kind: NightButtonKind.text, onPressed: () => Navigator.pop(ctx, 'text')),
              const SizedBox(height: Night.space2),
            ],
            if (busy) _spinner,
            Text(tx('通話時間不會過期，依實際通話秒數扣除。消耗型商品無法恢復購買。', 'Call time never expires and is used by the second. Consumable purchases can\'t be restored.'),
                style: Night.caption, textAlign: TextAlign.center),
          ]);
        },
      )),
    );
  }

  /// 本機試聽聲音用：--dart-define=AIYA_VOICE=cedar
  static const _voicePick = String.fromEnvironment('AIYA_VOICE');

  /// 打給艾婭：第一次先說明聲音會即時送到 OpenAI，同意後才接通
  Future<void> _startCall() async {
    if (aiyaPhone.state.value == AiyaCallState.live) { await aiyaPhone.hangUp(); return; }
    if (aiyaPhone.state.value != AiyaCallState.idle) return;
    if (_callSecondsLeft < 30) { await _showCallPacks(); return; }
    if (!_voiceConsented) {
      final agreed = await askAiyaVoiceConsent(context);
      if (!mounted || !agreed) return;
      final r = await aiyaCall('voiceConsent');
      if (!mounted || r['success'] != true) { _system(_callFailed()); return; }
      _voiceConsented = true;
    }
    FocusScope.of(context).unfocus();
    _typer?.cancel();
    _anim.setExpr('smile');
    final code = await aiyaPhone.start(voice: _voicePick.isEmpty ? null : _voicePick);
    if (!mounted) return;
    if (code == null) {
      _clock ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      setState(() {});
      return;
    }
    switch (code) {
      case 'no_minutes' || 'friend_only': _callSecondsLeft = 0; await _showCallPacks();
      case 'voice_consent': _voiceConsented = false; _system(_callFailed());
      case 'call_daily_max': _system(tx('今天的通話次數用完了，明天再打給艾婭吧', 'You\'ve used today\'s calls. Call AIYA again tomorrow'));
      case 'call_month_max': _system(tx('這個月的通話次數用完了', 'You\'ve used this month\'s calls'));
      case 'call_resting': _system(tx('艾婭的語音線路今天太忙了，晚點再試', 'AIYA\'s voice line is too busy today. Try again later'));
      case 'mic_denied': _system(tx('要允許使用麥克風才能和艾婭通話，可以到手機的「設定」打開', 'Allow the microphone to call AIYA. You can turn it on in your phone\'s Settings'));
      default: _system(_callFailed());
    }
  }

  String _callLeft() {
    final end = aiyaPhone.endsAt;
    if (end == null) return '';
    final sec = max(0, end.difference(DateTime.now()).inSeconds);
    return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
  }

  String _callLive() => tx('通話中 ${_callLeft()}', 'On call ${_callLeft()}');

  Future<void> _close() async {
    if (aiyaPhone.state.value != AiyaCallState.idle) unawaited(aiyaPhone.hangUp());
    if (!_ended && _sessionId != null) unawaited(aiyaCall('close'));
    _anim.formTarget = 0;
    _clock?.cancel();
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.of(context).pop();
  }

  void _system(String text) {
    setState(() => _msgs.add(_Msg(text, system: true)));
    _scrollDown();
  }

  _LiveLine _startLive() {
    _typer?.cancel();
    _video.play(aiyaTalkClips[_rnd.nextInt(aiyaTalkClips.length)], _anim.time);
    final line = _LiveLine(_Msg(''));
    setState(() => _msgs.add(line.msg));
    _typer = Timer.periodic(const Duration(milliseconds: 90), (t) {
      if (!mounted) { t.cancel(); return; }
      final chars = line.target.characters.toList();
      if (line.shown >= chars.length) {
        if (line.done) {
          t.cancel();
          _anim.setExpr(line.expression);
          final after = aiyaExprClip[line.expression] ?? 'idle';
          _video.play(after, _anim.time, loop: after == 'idle');
        }
        return;
      }
      _anim.speakChar(chars[line.shown]);
      setState(() => line.msg.text += chars[line.shown]);
      line.shown++;
      _scrollDown();
    });
    return line;
  }

  void _speak(String text, String expression, {String? talkClip}) {
    _typer?.cancel();
    _anim.setExpr(expression);
    _video.play(talkClip ?? aiyaTalkClips[_rnd.nextInt(aiyaTalkClips.length)], _anim.time);
    final after = aiyaExprClip[expression] ?? 'idle';
    final msg = _Msg('');
    setState(() => _msgs.add(msg));
    final chars = text.characters.toList();
    var i = 0;
    _typer = Timer.periodic(const Duration(milliseconds: 90), (t) {
      if (!mounted) { t.cancel(); return; }
      if (i >= chars.length) {
        t.cancel();
        if (talkClip == null) _video.play(after, _anim.time, loop: after == 'idle');
        return;
      }
      _anim.speakChar(chars[i]);
      setState(() => msg.text += chars[i]);
      i++;
      _scrollDown();
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || _ended) return;
    if (_sessionId == null) {
      await _open(greet: false);
      if (!mounted || _sessionId == null) return;
    }
    _input.clear();
    setState(() { _msgs.add(_Msg(text, mine: true)); _sending = true; });
    _scrollDown();
    _anim.setExpr('think');
    _video.play('think', _anim.time, loop: true);
    _LiveLine? live;
    var r = <String, dynamic>{'success': false, 'code': 'busy'};
    await for (final e in aiyaApi.say({'sessionId': _sessionId, 'text': text})) {
      if (!mounted) return;
      if (e['t'] == 'delta') {
        live ??= _startLive();
        live.target = '${e['text']}';
      } else {
        r = e;
      }
    }
    if (!mounted) return;
    setState(() => _sending = false);
    final session = r['session'];
    if (session is Map) _turnsLeft = (session['turnsLeft'] as num?)?.toInt() ?? _turnsLeft;
    if (r['success'] != true && live != null) {
      _typer?.cancel();
      setState(() => _msgs.remove(live!.msg));
    }
    if (r['success'] == true) {
      if (live != null) {
        live.finish('${r['reply']}', '${r['expression']}');
      } else {
        _speak('${r['reply']}', '${r['expression']}');
      }
      if (_turnsLeft <= 0) Future.delayed(const Duration(seconds: 6), _finish);
      return;
    }
    _anim.setExpr('calm');
    if (r['code'] == 'filtered' || r['code'] == 'ended') _video.play('idle', _anim.time, loop: true);
    switch ('${r['code']}') {
      case 'filtered': _system(tx('這句有不能傳的字或聯絡方式，換個說法試試。', 'That has words or contact details that aren\'t allowed. Try another way.'));
      case 'refused': _speak(tx('這個我不太方便聊，換個話題好嗎？', 'I can\'t really talk about that. How about something else?'), 'worry');
      case 'ended': _ended = true; _system(tx('這次的聊天已經結束。', 'This chat has ended.'));
      default: _speak(_busyText(), 'shy');
    }
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });

  void _onNotice() {
    final n = AiyaStore.notice.value;
    if (n == null || !mounted) return;
    AiyaStore.notice.value = null;
    showGlassToast(context, n, icon: Icons.auto_awesome);
  }

  void _onCredits() {
    final c = AiyaStore.credits.value;
    if (c == null || !mounted) return;
    final had = _credits;
    setState(() => _credits = c);
    if (c > had && _sessionId == null && !_opening) {
      Navigator.of(context).popUntil((r) => r.settings.name != 'aiyaPacks');
      _open();
    }
  }

  Future<void> _onFriend() async {
    if (!mounted) return;
    setState(() {});
    if (!AiyaStore.isFriend) return;
    _applyStatus(await aiyaCall('status'));
    if (!mounted) return;
    if (_sessionId == null && !_opening) {
      Navigator.of(context).popUntil((r) => r.settings.name != 'aiyaPacks' && r.settings.name != 'aiyaFriend');
      _open();
    }
  }

  /// 文字聊天的時光包；browse=true 是自己從「＋ 時光包」打開
  void _showPacks({bool browse = false}) {
    AiyaStore.load();
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true, routeSettings: const RouteSettings(name: 'aiyaPacks'),
      builder: (ctx) => _sheet(AnimatedBuilder(
        animation: Listenable.merge([AiyaStore.details, AiyaStore.busy, AiyaStore.friendExp]),
        builder: (context, _) {
          final busy = AiyaStore.busy.value;
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(browse ? tx('艾婭時光包', 'AIYA time packs') : tx('今天的免費聊天用完了', 'You\'ve used today\'s free chats'), style: Night.title, textAlign: TextAlign.center),
            const SizedBox(height: Night.space3),
            Text(tx('每天有 3 次免費文字聊天，隔天重新計算。想多聊幾次，可以買時光包，每次最多 10 分鐘。',
                'You get 3 free text chats a day, reset daily. For more, get a time pack. Each chat lasts up to 10 minutes.'), style: Night.body),
            const SizedBox(height: Night.space4),
            if (!AiyaStore.isFriend) ...[
              NightButton(tx('成為艾婭之友', 'Become an AIYA Friend'), kind: NightButtonKind.warm, icon: Icons.auto_awesome, onPressed: () { Navigator.pop(ctx); _showFriend(); }),
              const SizedBox(height: Night.space2),
            ],
            // 通話時間包隨時買得到（不必等通話時間用完；審查也找得到）
            NightButton(tx('和艾婭語音通話', 'Voice call with AIYA'), kind: NightButtonKind.ghost, icon: Icons.graphic_eq_rounded, onPressed: () { Navigator.pop(ctx); _showCallPacks(); }),
            const SizedBox(height: Night.space2),
            for (final e in AiyaStore.products.entries) ...[
              NightButton(
                '${tx('${e.value} 次聊天', '${e.value} chats')}  ·  ${AiyaStore.priceOf(e.key)}',
                kind: e.value == 20 ? NightButtonKind.primary : NightButtonKind.ghost,
                icon: Icons.hourglass_bottom,
                onPressed: busy ? null : () => AiyaStore.buy(e.key),
              ),
              const SizedBox(height: Night.space2),
            ],
            if (busy) _spinner,
            Text(tx('時光包綁定這支手機的帳號，刪除 App 後無法恢復。', 'Time packs belong to this phone\'s account and can\'t be restored if you delete the app.'),
                style: Night.caption, textAlign: TextAlign.center),
          ]);
        },
      )),
    );
  }

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}/${d.month}/${d.day}';
  }

  /// 艾婭之友（自動續訂月費）：價格、期間、自動續訂說明、條款與隱私權連結、恢復購買、管理訂閱
  void _showFriend() {
    AiyaStore.load();
    Widget perk(String text) => Padding(
          padding: const EdgeInsets.only(bottom: Night.space2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.auto_awesome, size: 16, color: Color(0xFFFFC861))),
            const SizedBox(width: Night.space2),
            Expanded(child: Text(text, style: Night.body)),
          ]),
        );
    Widget link(String text, VoidCallback? onTap) => TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: Night.inkMuted, minimumSize: const Size(44, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
          child: Text(text, style: const TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
        );
    void web(Uri u) => launchUrl(u, mode: LaunchMode.inAppBrowserView);
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true, routeSettings: const RouteSettings(name: 'aiyaFriend'),
      builder: (ctx) => _sheet(scroll: true, AnimatedBuilder(
        animation: Listenable.merge([AiyaStore.details, AiyaStore.busy, AiyaStore.friendExp]),
        builder: (context, _) {
          final product = AiyaStore.details.value[AiyaStore.friendProduct];
          final busy = AiyaStore.busy.value;
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tx('艾婭之友', 'AIYA Friend'), style: Night.title, textAlign: TextAlign.center),
            const SizedBox(height: Night.space1),
            Text(tx('自動續訂的月費方案', 'Auto-renewing monthly plan'), style: Night.caption, textAlign: TextAlign.center),
            const SizedBox(height: Night.space4),
            perk(tx('每月送 60 分鐘跟艾婭語音通話', '60 minutes of voice calls with AIYA every month')),
            perk(tx('每天 20 次文字聊天（免費是 3 次）', '20 text chats a day (3 when free)')),
            perk(tx('每次聊 20 分鐘或 40 則', 'Each chat lasts 20 minutes or 40 messages')),
            perk(tx('艾婭身邊多一圈星光（只有你看得到）', 'A circle of starlight around AIYA (only you see it)')),
            const SizedBox(height: Night.space2),
            if (AiyaStore.isFriend)
              Text(tx('艾婭之友到 ${_date(AiyaStore.friendExp.value!)}', 'AIYA Friend until ${_date(AiyaStore.friendExp.value!)}'),
                  style: const TextStyle(color: Color(0xFFFFC861), fontSize: 15), textAlign: TextAlign.center)
            else ...[
              Text(tx('${AiyaStore.priceOf(AiyaStore.friendProduct)} / 月', '${AiyaStore.priceOf(AiyaStore.friendProduct)} / month'),
                  style: const TextStyle(color: Night.ink, fontSize: 20, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
              const SizedBox(height: Night.space3),
              NightButton(tx('訂閱艾婭之友', 'Subscribe'), kind: NightButtonKind.warm, icon: Icons.auto_awesome, onPressed: busy || product == null ? null : AiyaStore.buyFriend),
            ],
            if (busy) _spinner,
            const SizedBox(height: Night.space3),
            Text(tx('訂閱期間為 1 個月，到期時會自動續訂並扣款，除非在到期前至少 24 小時關閉自動續訂。付款由 Apple 或 Google 帳戶處理，可以隨時到帳戶的訂閱設定管理或取消。每月贈送的通話時間當月有效、不累積。',
                'The subscription lasts 1 month and renews automatically with payment unless auto-renew is turned off at least 24 hours before the end of the period. Payment is handled by your Apple or Google account; manage or cancel any time in your account\'s subscription settings. Monthly call minutes don\'t roll over.'),
                style: Night.caption.copyWith(fontSize: 11)),
            const SizedBox(height: Night.space2),
            Wrap(alignment: WrapAlignment.center, children: [
              link(tx('使用條款', 'Terms of Use'), () => web(Uri.parse('$_site/terms'))),
              link(tx('隱私權政策', 'Privacy Policy'), () => web(Uri.parse('$_site/privacy'))),
              link(tx('恢復購買', 'Restore'), busy ? null : AiyaStore.restore),
              link(tx('管理訂閱', 'Manage subscription'), () => launchUrl(AiyaStore.manageUrl, mode: LaunchMode.externalApplication)),
            ]),
          ]);
        },
      )),
    );
  }

  void _report(_Msg m) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => _sheet(NightButton(tx('檢舉這句回覆', 'Report this reply'), kind: NightButtonKind.danger, icon: Icons.flag_outlined, onPressed: () async {
        Navigator.pop(ctx);
        await aiyaCall('report', {'reply': m.text, 'reason': 'user'});
        if (mounted) showGlassToast(context, tx('已收到檢舉，謝謝你。', 'Thanks, we got your report.'), icon: Icons.flag_outlined);
      })),
    );
  }

  String _timeLeft() {
    if (_endsAt == null) return '';
    final s = _endsAt!.difference(DateTime.now()).inSeconds.clamp(0, 3600);
    return tx('剩 ${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}', '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')} left');
  }

  Widget _chip(String text, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0x66FFC861))),
          child: Text(text, style: const TextStyle(color: Color(0xFFFFC861), fontSize: 12)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final keyboard = mq.viewInsets.bottom;
    final stageTop = mq.padding.top + 56;
    final stageH = (size.height - keyboard) * 0.48 - stageTop + mq.padding.top;
    final stage = Rect.fromLTWH(0, stageTop, size.width, stageH.clamp(160.0, size.height));
    final call = aiyaPhone.state.value;
    final inCall = call != AiyaCallState.idle;

    return Scaffold(
      backgroundColor: const Color(0xFF070B1F),
      resizeToAvoidBottomInset: false,
      body: Stack(children: [
        Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -0.45), radius: 0.8, colors: [const Color(0x33FFC861), const Color(0x228E2DE2), Night.night900.withValues(alpha: 0)]))))),
        if (_holo != null && _sprite != null)
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: (d) => _anim.pointer = Offset((d.localPosition.dx / size.width * 2 - 1).clamp(-1.0, 1.0), -((d.localPosition.dy - stage.center.dy) / stage.height * 2).clamp(-1.0, 1.0)),
              onPanEnd: (_) => _anim.pointer = Offset.zero,
              // 獨立圖層：光柱重畫時，聊天訊息、輸入列不用跟著重畫
              child: RepaintBoundary(child: CustomPaint(painter: AiyaHoloPainter(_holo!, _anim, _video, _sprite!, stage: stage, repaint: _frame, buf: _buf!))),
            ),
          ),
        // 艾婭之友：艾婭身邊一圈閃爍的星光（只有自己看得到）
        if (_holo != null)
          Positioned.fill(child: IgnorePointer(child: RepaintBoundary(child: ValueListenableBuilder(
            valueListenable: AiyaStore.friendExp,
            builder: (context, _, _) => AiyaStore.isFriend ? CustomPaint(painter: _StarlightPainter(stage: stage, repaint: _frame, clock: () => _anim.time)) : const SizedBox.shrink(),
          )))),
        // 上方：名稱、AI 標示、剩餘時間、結束
        Positioned(
          left: 0, right: 0, top: mq.padding.top + 8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Night.space4),
            child: Row(children: [
              Text(tx('艾婭', 'AIYA'), style: const TextStyle(color: Night.ink, fontSize: 20, fontWeight: FontWeight.w500, letterSpacing: 2)),
              const SizedBox(width: Night.space2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: Night.glassLine)),
                child: const Text('AI', style: TextStyle(color: Night.auroraBlue, fontSize: 11, letterSpacing: 1.5)),
              ),
              const SizedBox(width: Night.space2),
              Flexible(child: Text(call == AiyaCallState.live ? _callLive() : _timeLeft(), style: Night.caption, overflow: TextOverflow.ellipsis)),
              const Spacer(),
              TextButton(onPressed: _close, child: Text(tx('結束', 'Close'), style: const TextStyle(color: Night.inkMuted))),
            ]),
          ),
        ),
        // 下方：對話與輸入
        Positioned(
          left: 0, right: 0, bottom: keyboard,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Night.space4, 0, Night.space4, Night.space3),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: (size.height - keyboard) * 0.34),
                  // 上面還有被捲走的對話時，頂部淡出，不會在艾婭下方切出一條硬邊；捲到最上面就不淡
                  child: AnimatedBuilder(
                    animation: _scroll,
                    builder: (context, list) {
                      final fade = _scroll.hasClients ? _scroll.position.pixels.clamp(0.0, 56.0) : 0.0;
                      return ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (r) => LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
                          stops: [0, r.height > 0 ? (fade / r.height).clamp(0.0, 1.0) : 0],
                        ).createShader(r),
                        child: list,
                      );
                    },
                    child: ListView.builder(controller: _scroll, shrinkWrap: true, itemCount: _msgs.length, itemBuilder: (context, i) => _bubble(_msgs[i])),
                  ),
                ),
                const SizedBox(height: Night.space2),
                if (call == AiyaCallState.live)
                  ValueListenableBuilder<String>(
                    valueListenable: aiyaPhone.aiyaLine,
                    builder: (context, line, _) => line.trim().isEmpty
                        ? const SizedBox.shrink()
                        : Padding(padding: const EdgeInsets.only(bottom: Night.space2), child: _bubble(_Msg(line.trim()))),
                  ),
                Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: Night.space2, runSpacing: Night.space1, children: [
                  Text(
                    [
                      if (AiyaStore.isFriend) tx('艾婭之友 · 今天還有 $_freeLeft 次', 'Friend · $_freeLeft left today') else if (_freeLeft > 0) tx('今天免費 $_freeLeft 次', '$_freeLeft free today'),
                      if (_credits > 0) tx('時光包 $_credits 次', '$_credits in packs'),
                      if (_callSecondsLeft >= 60 && !inCall) tx('通話 ${_callSecondsLeft ~/ 60} 分鐘', '${_callSecondsLeft ~/ 60} min of calls'),
                    ].join('  ·  '),
                    style: Night.caption, textAlign: TextAlign.center,
                  ),
                  _chip(tx('＋ 時光包', '+ Time packs'), () => _showPacks(browse: true)),
                  _chip(tx('＋ 通話時間', '+ Call time'), _showCallPacks),
                ]),
                const SizedBox(height: Night.space2),
                // 輸入列：沒打字時右邊是藍色語音鍵；通話中變成「靜音」＋「✕ 結束通話」
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_ended && !_opening && !inCall,
                      maxLength: 200,
                      minLines: 1, maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Night.ink),
                      decoration: InputDecoration(
                        hintText: inCall ? _callLive() : tx('問艾婭行程、集合或當地的事…', 'Ask AIYA about the trip…'),
                        hintStyle: const TextStyle(color: Night.inkFaint), counterText: '',
                        filled: true, fillColor: Night.night700,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Night.radiusMd), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: Night.space2),
                  if (inCall) ...[
                    ValueListenableBuilder<bool>(
                      valueListenable: aiyaPhone.muted,
                      builder: (context, muted, _) => IconButton.outlined(
                        tooltip: muted ? tx('取消靜音', 'Unmute') : tx('靜音', 'Mute'),
                        onPressed: call == AiyaCallState.live ? () => aiyaPhone.setMuted(!muted) : null,
                        style: IconButton.styleFrom(side: const BorderSide(color: Night.glassLine)),
                        icon: Icon(muted ? Icons.mic_off_rounded : Icons.mic_none_rounded, color: muted ? Night.danger : Night.ink),
                      ),
                    ),
                    const SizedBox(width: Night.space2),
                    IconButton.filled(
                      tooltip: tx('結束通話', 'Hang up'),
                      onPressed: call == AiyaCallState.live ? () => aiyaPhone.hangUp() : null,
                      style: IconButton.styleFrom(backgroundColor: Night.ink, minimumSize: const Size(48, 48)),
                      icon: call == AiyaCallState.connecting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Night.night900))
                          : const Icon(Icons.close_rounded, color: Night.night900),
                    ),
                  ] else if (_input.text.trim().isEmpty && !_sending)
                    IconButton.filled(
                      tooltip: tx('和艾婭語音通話', 'Voice call with AIYA'),
                      onPressed: _opening ? null : _startCall,
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFF4C7DFF), minimumSize: const Size(56, 44)),
                      icon: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
                    )
                  else
                    IconButton.filled(
                      tooltip: tx('傳送', 'Send'),
                      onPressed: _sending || _ended ? null : _send,
                      style: IconButton.styleFrom(backgroundColor: Night.deepViolet),
                      icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_upward, color: Colors.white),
                    ),
                ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _bubble(_Msg m) {
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: m.mine ? Night.deepViolet.withValues(alpha: 0.85) : (m.system ? Colors.transparent : Night.glassFill),
        borderRadius: BorderRadius.circular(Night.radiusMd),
        border: m.mine || m.system ? null : Border.all(color: const Color(0x66FFC861)),
      ),
      child: Text(m.text, style: TextStyle(color: m.system ? Night.inkMuted : Night.ink, fontSize: 15, height: 1.45)),
    );
    return Align(
      alignment: m.system ? Alignment.center : (m.mine ? Alignment.centerRight : Alignment.centerLeft),
      child: m.mine || m.system ? bubble : GestureDetector(onLongPress: () => _report(m), child: bubble),
    );
  }
}

Widget _consentSheet(BuildContext ctx, {required IconData icon, required String title, required String body, required String agree}) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Night.space4),
        child: GlassCard(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Icon(icon, color: const Color(0xFFFFC861), size: 32),
              const SizedBox(height: Night.space3),
              Text(title, style: Night.title, textAlign: TextAlign.center),
              const SizedBox(height: Night.space3),
              Text(body, style: Night.body),
              const SizedBox(height: Night.space2),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => launchUrl(Uri.parse('$_site/privacy'), mode: LaunchMode.inAppBrowserView),
                  style: TextButton.styleFrom(foregroundColor: Night.inkMuted, padding: EdgeInsets.zero),
                  child: Text(tx('隱私權政策', 'Privacy Policy'), style: const TextStyle(fontSize: 13, decoration: TextDecoration.underline)),
                ),
              ),
              const SizedBox(height: Night.space2),
              NightButton(agree, onPressed: () => Navigator.pop(ctx, true)),
              const SizedBox(height: Night.space2),
              NightButton(tx('先不要', 'Not now'), kind: NightButtonKind.text, onPressed: () => Navigator.pop(ctx, false)),
            ]),
          ),
        ),
      ),
    );

/// AI 資料同意：第一次和艾婭聊天前（文字送到 Anthropic）
Future<bool> askAiyaConsent(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context, isDismissible: false, enableDrag: false, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (ctx) => _consentSheet(ctx,
        icon: Icons.auto_awesome,
        title: tx('和艾婭聊天之前', 'Before you talk with AIYA'),
        body: tx('艾婭是 AI，由 Anthropic 的 Claude 提供。你傳給艾婭的文字，以及團主公布的行程與集合資訊（不含任何人的位置），會送到 Anthropic（美國）處理，不會附上你的身分或暱稱；對話結束就刪除。艾婭的回覆可能出錯，集合時間、地點請以領隊說的為準，也不構成專業建議。',
            'AIYA is an AI powered by Anthropic\'s Claude. What you send to AIYA, plus the itinerary and meeting info your leader shared (never anyone\'s location), is processed by Anthropic (USA) without your identity or nickname, and deleted when the chat ends. AIYA can make mistakes: always follow your leader for meeting times and places. AIYA doesn\'t give professional advice.'),
        agree: tx('同意並開始', 'Agree and start')),
  );
  return ok == true;
}

/// 語音通話同意：第一次打給艾婭前（聲音即時送到 OpenAI）
Future<bool> askAiyaVoiceConsent(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (ctx) => _consentSheet(ctx,
        icon: Icons.call_rounded,
        title: tx('和艾婭語音通話', 'Voice call with AIYA'),
        body: tx('語音通話時，你的聲音會即時送到 OpenAI（美國）由 AI 處理並回應，團主公布的行程與集合資訊也會一起送去（不含任何人的位置），不會附上你的身分或暱稱；我們不錄音，也不保存通話內容。艾婭是 AI，回覆可能出錯，不構成專業建議。',
            'During a voice call, your voice is sent live to OpenAI (USA), whose AI processes it and replies, along with the itinerary and meeting info your leader shared (never anyone\'s location). It doesn\'t include your identity or nickname, and we don\'t record or keep the call. AIYA is an AI; replies may be wrong and are not professional advice.'),
        agree: tx('同意並通話', 'Agree and call')),
  );
  return ok == true;
}

/// 艾婭之友的「星光」：艾婭四周金色星光輪流閃爍、慢慢往上飄
class _StarlightPainter extends CustomPainter {
  final Rect stage;
  final double Function() clock;
  _StarlightPainter({required this.stage, required Listenable repaint, required this.clock}) : super(repaint: repaint);

  static double _h(int i) {
    final x = sin(i * 91.7 + 13.3) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock();
    final c = stage.center;
    final rx = stage.width * 0.36, ry = stage.height * 0.46;
    const gold = Color(0xFFFFD98A);
    for (var i = 0; i < 36; i++) {
      final a = _h(i) * 2 * pi;
      final rad = 0.55 + 0.45 * _h(i + 50);
      final drift = ((t * (0.02 + 0.02 * _h(i + 9)) + _h(i + 70)) % 1.0);
      final p = c + Offset(cos(a) * rx * rad, sin(a) * ry * rad - drift * stage.height * 0.12);
      final tw = 0.5 + 0.5 * sin(t * (1.5 + 2 * _h(i + 20)) + i);
      final alpha = tw * tw * sin(drift * pi);
      if (alpha < 0.03) continue;
      final r = 1.0 + 1.6 * _h(i + 33);
      canvas.drawCircle(p, r * 2.4, Paint()..color = gold.withValues(alpha: 0.18 * alpha));
      canvas.drawCircle(p, r, Paint()..color = Colors.white.withValues(alpha: 0.9 * alpha));
      if (i % 6 == 0) {
        final len = r * 5 * tw;
        final paint = Paint()..color = gold.withValues(alpha: 0.7 * alpha)..strokeWidth = 0.8..strokeCap = StrokeCap.round;
        canvas.drawLine(p - Offset(len, 0), p + Offset(len, 0), paint);
        canvas.drawLine(p - Offset(0, len), p + Offset(0, len), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarlightPainter old) => old.stage != stage;
}
