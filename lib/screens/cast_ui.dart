import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../tour/cast.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../ui/night.dart';
import 'group_screen.dart' show SubPicker;
import 'join.dart' show showPanel;

/// 頂部的講解廣播圖示
/// - 團員：有廣播時才出現（耳機）。按一下開始聽，再按一下關掉；正在聽時亮起來並有光圈。
/// - 團主、共同團主：一直在（麥克風）。沒有廣播時按一下開始；自己在講時按一下打開結束面板；別人在講時跟團員一樣可以聽。
class CastButton extends StatefulWidget {
  final TourGroup g;
  const CastButton({super.key, required this.g});
  @override
  State<CastButton> createState() => _CastButtonState();
}

class _CastButtonState extends State<CastButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final c = g.cast;
    if (c == null && !g.isStaff) return const SizedBox.shrink();
    return ValueListenableBuilder<CastState>(
      valueListenable: TourCast.state,
      builder: (context, s, _) {
        final speaking = c != null && c.mine;
        final listening = c != null && !c.mine && s.mode == CastMode.listening;
        final active = speaking || listening;
        final color = speaking ? Night.danger : Night.auroraBlue;
        final icon = c == null
            ? Icons.mic_none
            : speaking
                ? (s.micOn ? Icons.mic : Icons.mic_off)
                : (listening ? Icons.headphones : Icons.headphones_outlined);
        final tip = c == null
            ? tx('開始講解廣播', 'Start a live talk')
            : speaking
                ? tx('講解廣播中', 'Live talk on air')
                : (listening ? tx('不聽了', 'Stop listening') : tx('聽講解廣播', 'Listen to the live talk'));
        return IconButton(
          tooltip: tip,
          onPressed: () {
            if (c == null) {
              showCastStart(context, g);
            } else if (speaking) {
              showCastControls(context, g);
            } else {
              TourCast.listen(!listening);
            }
          },
          icon: SizedBox(
            width: 28,
            height: 28,
            child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              if (active)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => Container(
                    width: 22 + 12 * _pulse.value,
                    height: 22 + 12 * _pulse.value,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.7 * (1 - _pulse.value)), width: 2)),
                  ),
                ),
              Icon(icon, color: active ? color : Night.ink, size: 24),
              // 有廣播但還沒聽：右上角紅點提醒
              if (c != null && !active)
                Positioned(
                  right: -1,
                  top: -1,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: Night.danger,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Night.danger.withValues(alpha: 0.8 * (1 - _pulse.value)), blurRadius: 6, spreadRadius: 2 * _pulse.value)],
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }
}

/// 頂部下方的廣播列：正在聽或正在講時出現
/// 聽：「正在聽 阿導 講解」、擴音切換、關掉；講：「廣播中 · 3 人在聽 · 05:12」、靜音、結束
class CastBar extends StatefulWidget {
  final TourGroup g;
  const CastBar({super.key, required this.g});
  @override
  State<CastBar> createState() => _CastBarState();
}

class _CastBarState extends State<CastBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted && TourCast.state.value.on) setState(() {}); });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.g.cast;
    if (c == null) return const SizedBox.shrink();
    return ValueListenableBuilder<CastState>(
      valueListenable: TourCast.state,
      builder: (context, s, _) {
        if (!s.on || s.castId != c.id) return const SizedBox.shrink();
        final speaking = s.mode == CastMode.speaking;
        final secs = ((DateTime.now().millisecondsSinceEpoch - c.at) / 1000).floor().clamp(0, 99999);
        final clock = '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
        final who = c.byName.isEmpty ? tx('領隊', 'Leader') : c.byName;
        final String title;
        if (s.connecting || (!s.connected && s.error == null)) {
          title = tx('連線中…', 'Connecting…');
        } else if (!s.connected) {
          title = tx('連不上，正在重試…', 'Reconnecting…');
        } else if (speaking) {
          title = s.micOn
              ? tx('廣播中 · ${s.listeners} 人在聽 · $clock', 'On air · ${s.listeners} listening · $clock')
              : tx('已靜音 · ${s.listeners} 人在聽', 'Muted · ${s.listeners} listening');
        } else {
          title = tx('正在聽 $who 講解', 'Listening to $who');
        }
        return Container(
          margin: const EdgeInsets.only(bottom: Night.space2),
          padding: const EdgeInsets.only(left: 14, right: 4),
          height: 46,
          decoration: BoxDecoration(
            color: Night.mapGlassPanel,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: (speaking ? Night.danger : Night.auroraBlue).withValues(alpha: 0.6)),
          ),
          child: Row(children: [
            Icon(speaking ? Icons.mic : Icons.headphones, size: 18, color: speaking ? Night.danger : Night.auroraBlue),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(color: Night.ink, fontSize: 14), overflow: TextOverflow.ellipsis)),
            if (speaking)
              IconButton(
                tooltip: s.micOn ? tx('靜音', 'Mute') : tx('取消靜音', 'Unmute'),
                icon: Icon(s.micOn ? Icons.mic : Icons.mic_off, color: Night.ink, size: 20),
                onPressed: () => TourCast.setMic(!s.micOn),
              )
            else
              ValueListenableBuilder<bool>(
                valueListenable: TourCast.speaker,
                builder: (context, on, _) => IconButton(
                  tooltip: on ? tx('擴音：開（沒接耳機時用喇叭）', 'Speaker: on (when no earphones)') : tx('擴音：關（用聽筒）', 'Speaker: off (earpiece)'),
                  icon: Icon(on ? Icons.volume_up : Icons.phone_in_talk_outlined, color: Night.ink, size: 20),
                  onPressed: () {
                    TourCast.setSpeaker(!on);
                    showGlassToast(context, !on ? tx('擴音開：沒接耳機時用手機喇叭', 'Speaker on: phone speaker when no earphones') : tx('擴音關：沒接耳機時用聽筒', 'Speaker off: earpiece when no earphones'));
                  },
                ),
              ),
            IconButton(
              tooltip: speaking ? tx('結束廣播', 'End live talk') : tx('不聽了', 'Stop listening'),
              icon: Icon(speaking ? Icons.stop_circle_outlined : Icons.close, color: speaking ? Night.danger : Night.inkMuted, size: 22),
              onPressed: () => speaking ? showCastControls(context, widget.g) : TourCast.listen(false),
            ),
          ]),
        );
      },
    );
  }
}

/// 開始講解廣播：可以只講給某一組
Future<void> showCastStart(BuildContext context, TourGroup g) async {
  int? sub;
  var busy = false;
  await showPanel(context, (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.mic, color: Night.danger),
          const SizedBox(width: Night.space2),
          Expanded(child: Text(tx('講解廣播', 'Live talk'), style: Night.title.copyWith(fontSize: 20))),
        ]),
        const SizedBox(height: Night.space2),
        Text(
          tx('對著手機講，團員用自己的耳機、藍牙耳機或手機喇叭即時聽，取代導覽耳機。團員會收到通知，按頂部的耳機圖示就能聽。最長 2 小時，不錄音。',
              'Talk into your phone and your group listens live with their own earphones, Bluetooth or phone speaker, instead of tour headsets. Members get a notification and tap the headphone icon at the top to listen. Up to 2 hours; nothing is recorded.'),
          style: Night.body,
        ),
        if (g.subs.isNotEmpty) ...[
          const SizedBox(height: Night.space3),
          SubPicker(g: g, value: sub, onChanged: (v) => setS(() => sub = v)),
        ],
        const SizedBox(height: Night.space4),
        NightButton(
          busy ? tx('開始中…', 'Starting…') : tx('開始廣播', 'Go live'),
          icon: Icons.mic,
          expand: true,
          onPressed: busy
              ? null
              : () async {
                  setS(() => busy = true);
                  final err = await TourCast.start(sub: sub);
                  if (!ctx.mounted) return;
                  if (err != null) {
                    setS(() => busy = false);
                    showGlassToast(ctx, tourError(err), danger: true);
                    return;
                  }
                  Navigator.of(ctx).pop();
                },
        ),
      ]));
}

/// 自己在講：靜音、結束
Future<void> showCastControls(BuildContext context, TourGroup g) async {
  await showPanel(context, (ctx, setS) => ValueListenableBuilder<CastState>(
        valueListenable: TourCast.state,
        builder: (ctx, s, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tx('講解廣播中', 'Live talk on air'), style: Night.title.copyWith(fontSize: 20)),
          const SizedBox(height: Night.space2),
          Text(
            s.connected ? tx('${s.listeners} 人正在聽。', '${s.listeners} listening.') : tx('正在連線…', 'Connecting…'),
            style: Night.body,
          ),
          if (s.error == 'mic_denied') ...[
            const SizedBox(height: Night.space2),
            Text(tourError('mic_denied'), style: Night.caption.copyWith(color: Night.danger)),
          ],
          const SizedBox(height: Night.space4),
          NightButton(
            s.micOn ? tx('暫時靜音', 'Mute for now') : tx('取消靜音', 'Unmute'),
            icon: s.micOn ? Icons.mic_off : Icons.mic,
            kind: NightButtonKind.ghost,
            expand: true,
            onPressed: () => TourCast.setMic(!s.micOn),
          ),
          const SizedBox(height: Night.space2),
          NightButton(
            tx('結束廣播', 'End live talk'),
            icon: Icons.stop_circle_outlined,
            expand: true,
            onPressed: () async {
              await TourCast.stop();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ]),
      ));
}
