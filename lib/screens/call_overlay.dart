import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/nav.dart';
import '../tour/service.dart';
import '../tour/zones.dart';
import '../translate.dart';
import '../ui/night.dart';
import 'join.dart';

/// 團員的集合卡片：當地時間、倒數、距離與方向、「收到」。設計稿：團員收到集合
/// 距離和方向用自己的位置和指南針在手機上算，不會傳給任何人。
class CallCard extends StatefulWidget {
  final TourGroup g;
  final TourCall call;
  final bool big;
  const CallCard({super.key, required this.g, required this.call, this.big = false});
  @override
  State<CallCard> createState() => _CallCardState();
}

class _CallCardState extends State<CallCard> {
  Timer? _tick;
  Position? _pos;
  double? _heading;
  StreamSubscription<Position>? _sub;
  StreamSubscription<CompassEvent>? _compass;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
    ensureLocation().then((ok) {
      if (!ok || !mounted) return;
      _sub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5))
          .listen((p) { if (mounted) setState(() => _pos = p); }, onError: (_) {});
    });
    _compass = FlutterCompass.events?.listen((e) { if (mounted && e.heading != null) setState(() => _heading = e.heading); });
    if (widget.call.mine == null) TourService.call('seen', {'callId': widget.call.id});
  }

  @override
  void dispose() {
    _tick?.cancel();
    _sub?.cancel();
    _compass?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.call;
    final pos = _pos;
    final dist = pos == null ? null : Geolocator.distanceBetween(pos.latitude, pos.longitude, c.lat, c.lng);
    final bearing = pos == null ? null : Geolocator.bearingBetween(pos.latitude, pos.longitude, c.lat, c.lng);
    final acked = (TourService.current.value?.call?.mine ?? c.mine) == 'ack';
    final left = Duration(milliseconds: max(0, c.at - DateTime.now().millisecondsSinceEpoch));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 時區放在標題同一行，面板裡的卡片才不會太高
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(tx('${hm(c.at, c.tz)} 集合', 'Gather at ${hm(c.at, c.tz)}'), style: Night.title.copyWith(fontSize: widget.big ? 22 : 20)),
        const SizedBox(width: Night.space2),
        Flexible(child: Text(tx('${zoneName(c.tz).split('・').first}時間', '${zoneName(c.tz).split(' / ').first} time'), style: Night.caption, overflow: TextOverflow.ellipsis)),
      ]),
      // 集合點名稱是領隊打的字：可以點一下翻譯
      if (c.place.isNotEmpty) TranslatableText(c.place, compact: true, style: Night.body.copyWith(color: Night.ink)),
      SizedBox(height: widget.big ? Night.space3 : Night.space2),
      Row(children: [
        Expanded(
          child: Text(left.inSeconds > 0 ? '${left.inMinutes}:${two(left.inSeconds % 60)}' : tx('現在', 'Now'),
              style: TextStyle(color: Night.ink, fontSize: widget.big ? 48 : 30, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        if (dist != null && bearing != null) ...[
          Semantics(
            label: tx('集合點的方向', 'Direction to the meeting point'),
            child: Container(
              width: widget.big ? 52 : 42, height: widget.big ? 52 : 42, decoration: const BoxDecoration(color: Night.night600, shape: BoxShape.circle),
              child: Transform.rotate(angle: (bearing - (_heading ?? pos?.heading ?? 0)) * pi / 180, child: Icon(Icons.navigation, color: widget.g.tint, size: widget.big ? 28 : 24)),
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dist < 1000 ? '${dist.round()} m' : '${(dist / 1000).toStringAsFixed(1)} km', style: const TextStyle(color: Night.ink, fontSize: 20, fontWeight: FontWeight.w600)),
            Text(tx('步行約 ${max(1, (dist / 80).round())} 分鐘', 'about ${max(1, (dist / 80).round())} min walk'), style: Night.caption),
          ]),
        ],
      ]),
      SizedBox(height: widget.big ? Night.space4 : Night.space2),
      // 用 Apple／Google 地圖步行導航到集合點
      Align(
        alignment: Alignment.center,
        child: TextButton.icon(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          icon: const Icon(Icons.directions_walk, size: 18, color: Night.auroraBlue),
          label: Text(tx('用地圖帶我走過去', 'Walk me there with Maps'), style: const TextStyle(color: Night.auroraBlue)),
          onPressed: () => walkTo(context, c.lat, c.lng, label: c.place),
        ),
      ),
      SizedBox(height: widget.big ? Night.space2 : 4),
      acked
          ? Text(tx('已收到，領隊看得到', 'Got it. Your leader can see that.'), style: const TextStyle(color: Night.moodCalm, fontSize: 15), textAlign: TextAlign.center)
          : NightButton(tx('收到', 'Got it'), icon: Icons.check, onPressed: () {
              HapticFeedback.heavyImpact();
              TourService.call('ack', {'callId': c.id});
            }),
      // 隱私說明只放在全螢幕卡片，面板裡省下一行
      if (widget.big) ...[
        const SizedBox(height: Night.space2),
        Text(tx('距離和方向在你的手機上計算，不會傳給任何人', 'Distance and direction are worked out on your phone and never sent'), style: Night.caption, textAlign: TextAlign.center),
      ],
    ]);
  }
}

/// 點名的三個大按鈕：我到了、還要 5 分鐘、需要幫忙
class RollButtons extends StatelessWidget {
  final TourGroup g;
  const RollButtons({super.key, required this.g});
  @override
  Widget build(BuildContext context) {
    Widget b(String answer, String label, IconData icon, Color color) => Expanded(
          child: Material(
            color: g.rollMine == answer ? color.withValues(alpha: 0.25) : Night.night600,
            borderRadius: BorderRadius.circular(Night.radiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(Night.radiusMd),
              onTap: () {
                HapticFeedback.heavyImpact();
                TourService.call('answer', {'rollId': g.rollId, 'answer': answer});
              },
              child: SizedBox(height: 84, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(color: Night.ink, fontSize: 14, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              ])),
            ),
          ),
        );
    return Row(children: [
      b('here', tx('我到了', 'I\'m here'), Icons.check_circle_outline, Night.moodCalm),
      const SizedBox(width: 8),
      b('5min', tx('還要 5 分鐘', '5 more min'), Icons.timer_outlined, const Color(0xFFFFD166)),
      const SizedBox(width: 8),
      b('help', tx('需要幫忙', 'Need help'), Icons.sos, Night.danger),
    ]);
  }
}

/// 前景收到集合呼叫：全螢幕卡片＋震動「短 短 長」＋專屬音效；按「收到」後自動關閉
Future<void> showCallOverlay(BuildContext context, TourCall call) async {
  final g = TourService.current.value;
  if (g == null) return;
  await buzz();
  if (!context.mounted) return;
  var closing = false;
  await showDialog(
    context: context, barrierColor: g.tint.withValues(alpha: 0.35),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(Night.space4),
      child: SolidCard(child: ValueListenableBuilder<TourGroup?>(
        valueListenable: TourService.current,
        builder: (ctx, cur, _) {
          if (!closing && (cur?.call?.mine == 'ack' || cur == null || cur.call == null)) {
            closing = true;
            Future.delayed(const Duration(milliseconds: 600), () { if (ctx.mounted && Navigator.canPop(ctx)) Navigator.pop(ctx); });
          }
          final now = cur ?? g;
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: now.tint, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(tx('${now.name} · 你是 ${now.myNo ?? '-'} 號', '${now.name} · No. ${now.myNo ?? '-'}'), style: Night.caption.copyWith(color: Night.inkMuted))),
            ]),
            const SizedBox(height: Night.space3),
            CallCard(g: now, call: now.call ?? call, big: true),
          ]);
        },
      )),
    ),
  );
}

/// 前景收到點名：全螢幕卡片＋震動，三個大按鈕；回答後自動關閉
Future<void> showRollOverlay(BuildContext context, String rollId) async {
  final g = TourService.current.value;
  if (g == null) return;
  await buzz();
  if (!context.mounted) return;
  var closing = false;
  await showDialog(
    context: context, barrierColor: g.tint.withValues(alpha: 0.35),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(Night.space4),
      child: SolidCard(child: ValueListenableBuilder<TourGroup?>(
        valueListenable: TourService.current,
        builder: (ctx, cur, _) {
          final now = cur ?? g;
          if (!closing && (now.rollId != rollId || now.rollMine != null)) {
            closing = true;
            Future.delayed(const Duration(milliseconds: 400), () { if (ctx.mounted && Navigator.canPop(ctx)) Navigator.pop(ctx); });
          }
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(now.name, style: Night.caption, textAlign: TextAlign.center),
            const SizedBox(height: Night.space2),
            Text(tx('點名：你到了嗎？', 'Roll call: are you here?'), style: Night.title.copyWith(color: now.tint, fontSize: 22), textAlign: TextAlign.center),
            const SizedBox(height: Night.space4),
            RollButtons(g: now),
          ]);
        },
      )),
    ),
  );
}

// ---------- 光之團旗、我迷路了 ----------

/// 光之團旗：整個螢幕變成團色並閃爍，中間是團號（團主、共同團主顯示「領隊」）。
/// 舉起手機讓彼此在人群裡找到你；不需要定位，也不送任何資料。
Future<void> showFlag(BuildContext context, TourGroup g) {
  return Navigator.of(context).push(PageRouteBuilder(opaque: true, pageBuilder: (_, _, _) => _FlagPage(g: g)));
}

class _FlagPage extends StatefulWidget {
  final TourGroup g;
  const _FlagPage({required this.g});
  @override
  State<_FlagPage> createState() => _FlagPageState();
}

class _FlagPageState extends State<_FlagPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final label = g.isStaff ? tx('領隊', 'Leader') : '${g.myNo ?? ''}';
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          color: Color.lerp(g.tint, Colors.white, _c.value * 0.35),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(color: Night.night900, fontSize: g.isStaff ? 96 : 160, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
            Text(g.name, style: const TextStyle(color: Night.night900, fontSize: 22, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
            const SizedBox(height: 40),
            Text(tx('點一下關閉', 'Tap to close'), style: TextStyle(color: Night.night900.withValues(alpha: 0.7), fontSize: 14, decoration: TextDecoration.none)),
          ]),
        ),
      ),
    );
  }
}

/// 我迷路了：說明會傳一次位置給領隊，按下才送出（不會持續追蹤，30 分鐘後自動刪除）
Future<void> askLost(BuildContext context, TourGroup g) async {
  if (g.lostSent) {
    final ok = await confirmSheet(context, tx('已經通知領隊了。找到團了嗎？', 'Your leader was notified. Found the group?'), action: tx('找到團了', 'Found the group'));
    if (ok == true) await TourService.call('found');
    return;
  }
  final ok = await confirmSheet(
    context,
    tx('把你現在的位置傳一次給領隊，領隊會在地圖上看到你在哪裡。只傳這一次，30 分鐘後自動刪除。', 'Send your current location to your leader once. It is deleted after 30 minutes.'),
    action: tx('傳送位置給領隊', 'Send my location'),
    danger: true,
  );
  if (ok != true || !context.mounted) return;
  Position? pos;
  if (await ensureLocation()) {
    try {
      pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)));
    } catch (_) {
      try { pos = await Geolocator.getLastKnownPosition(); } catch (_) {}
    }
  }
  if (!context.mounted) return;
  if (pos == null) {
    showGlassToast(context, tx('抓不到你的位置，請打開定位後再試。', 'Could not get your location. Turn on location and try again.'), danger: true, icon: Icons.location_off_outlined);
    return;
  }
  final r = await TourService.call('lost', {'lat': pos.latitude, 'lng': pos.longitude});
  if (!context.mounted) return;
  showGlassToast(context, r['success'] == true ? tx('已通知領隊，請待在原地。', 'Your leader was notified. Please stay where you are.') : tourError('${r['code']}'),
      danger: r['success'] != true, icon: Icons.location_on_outlined);
}

/// 團主、共同團主：有團員迷路或需要幫忙 → 音效＋震動＋全螢幕提醒
Future<void> showLeaderAlert(BuildContext context, {required bool lost}) async {
  await buzz();
  if (!context.mounted) return;
  await TourService.refresh();
  if (!context.mounted) return;
  final g = TourService.current.value;
  await showDialog(
    context: context, barrierColor: Night.danger.withValues(alpha: 0.3),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(Night.space4),
      child: SolidCard(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Icon(lost ? Icons.location_on : Icons.sos, color: Night.danger, size: 40),
        const SizedBox(height: Night.space3),
        Text(
          lost
              ? tx('${g?.lost.firstOrNull?.no ?? '?'} 號迷路了', 'No. ${g?.lost.firstOrNull?.no ?? '?'} is lost')
              : tx('${g?.rollRoster.where((m) => m.state == 'help').map((m) => m.no).join('、')} 號需要幫忙', 'No. ${g?.rollRoster.where((m) => m.state == 'help').map((m) => m.no).join(', ')} needs help'),
          style: Night.title, textAlign: TextAlign.center,
        ),
        const SizedBox(height: Night.space2),
        Text(lost ? tx('他的位置已經出現在地圖上的紅色圓點。', 'Their location is the red dot on the map.') : tx('打開點名名單看看是誰。', 'Open the roll call to see who.'), style: Night.body, textAlign: TextAlign.center),
        const SizedBox(height: Night.space4),
        NightButton(tx('知道了', 'OK'), onPressed: () => Navigator.pop(ctx)),
      ])),
    ),
  );
}
