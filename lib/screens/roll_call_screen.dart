import 'package:flutter/material.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../tour/zones.dart';
import '../ui/night.dart';
import 'group_screen.dart';

/// 集合狀態與點名（團主、共同團主）。設計稿：點名
///   集合：收到／打開了沒回／沒反應
///   點名：需要幫忙 → 沒回 → 還要 5 分鐘 → 到了；沒回的人可以單獨呼叫
class RollCallScreen extends StatefulWidget {
  /// 剛發出集合時先看集合狀態
  final bool showCall;
  const RollCallScreen({super.key, this.showCall = false});
  @override
  State<RollCallScreen> createState() => _RollCallScreenState();
}

class _RollCallScreenState extends State<RollCallScreen> {
  late bool _callTab = widget.showCall;
  int? _sub;
  bool _busy = false;

  Future<void> _do(String action, [Map<String, dynamic> body = const {}]) async {
    setState(() => _busy = true);
    final r = await TourService.call(action, body);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['success'] != true) showGlassToast(context, tourError('${r['code']}'), danger: true);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TourGroup?>(
      valueListenable: TourService.current,
      builder: (context, g, _) {
        if (g == null) return const SizedBox.shrink();
        final callTab = _callTab && g.call != null;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Night.night900, foregroundColor: Night.ink,
            title: Text(callTab ? tx('集合狀態', 'Gather status') : tx('點名', 'Roll call'), style: Night.title),
            actions: [
              if (g.call != null)
                TextButton(onPressed: () => setState(() => _callTab = !_callTab), child: Text(callTab ? tx('看點名', 'Roll call') : tx('看集合', 'Gather'))),
            ],
          ),
          body: SafeArea(child: callTab ? _callView(g) : _rollView(g)),
        );
      },
    );
  }

  Widget _summary(String label, int n, int total, List<(String, Color, double)> bars, String legend) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Night.space4, Night.space2, Night.space4, Night.space3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(label, style: Night.body),
          const SizedBox(width: 8),
          Text('$n', style: const TextStyle(color: Night.ink, fontSize: 40, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
          Text('／$total', style: const TextStyle(color: Night.inkFaint, fontSize: 22, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: Night.space2),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(height: 8, child: Row(children: [
            for (final b in bars) if (b.$3 > 0) Expanded(flex: (b.$3 * 1000).round(), child: Container(color: b.$2)),
            if (bars.fold<double>(0, (s, b) => s + b.$3) < 0.999)
              Expanded(flex: (1000 - bars.fold<double>(0, (s, b) => s + b.$3) * 1000).round().clamp(1, 1000), child: Container(color: Night.night600)),
          ])),
        ),
        const SizedBox(height: Night.space2),
        Text(legend, style: Night.caption.copyWith(color: Night.inkMuted)),
      ]),
    );
  }

  Widget _row(TourGroup g, TourMember m, {required String status, required Color color, bool urgent = false, bool canPing = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Night.night700, borderRadius: BorderRadius.circular(Night.radiusMd), border: urgent ? Border.all(color: Night.danger) : null),
      child: Row(children: [
        Container(width: 36, height: 36, alignment: Alignment.center, decoration: const BoxDecoration(color: Night.night600, shape: BoxShape.circle),
            child: Text('${m.no}', style: const TextStyle(color: Night.ink, fontWeight: FontWeight.w600))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text([if (m.label.isNotEmpty) m.label, if (m.sub != null) g.subName(m.sub)].join(' · ').ifEmpty(tx('${m.no} 號', 'No. ${m.no}')), style: const TextStyle(color: Night.ink, fontSize: 15)),
          Text(status, style: Night.caption.copyWith(color: color)),
        ])),
        if (canPing)
          OutlinedButton(
            onPressed: _busy ? null : () => _do('ping', {'uid': m.uid}),
            style: OutlinedButton.styleFrom(foregroundColor: Night.ink, side: const BorderSide(color: Night.glassLine), shape: const StadiumBorder()),
            child: Text(tx('單獨呼叫', 'Ping')),
          ),
      ]),
    );
  }

  Widget _callView(TourGroup g) {
    final c = g.call!;
    final seen = g.callRoster.where((m) => m.state == 'seen').length;
    final none = g.callRoster.where((m) => m.state == 'none').length;
    final t = g.callTotal == 0 ? 1 : g.callTotal;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Night.space4),
        child: Text('${hm(c.at, c.tz)} · ${zoneChip(c.at, c.tz)} · ${c.place}${c.sub != null ? ' · ${g.subName(c.sub)}' : ''}', style: Night.caption.copyWith(color: Night.inkMuted)),
      ),
      _summary(tx('收到', 'Got it'), g.acked, g.callTotal, [(tx('收到', 'ok'), Night.moodCalm, g.acked / t), ('', const Color(0xFFFFD166), seen / t)],
          tx('收到 ${g.acked} · 打開了沒回 $seen · 沒反應 $none · 倒數 ${countdown(c.at)}', 'Got it ${g.acked} · Seen $seen · No response $none · ${countdown(c.at)}')),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: Night.space4), children: [
        for (final m in g.callRoster)
          _row(g, m,
              status: switch (m.state) { 'ack' => tx('收到', 'Got it'), 'seen' => tx('打開了，還沒回', 'Seen, no reply'), _ => tx('沒反應', 'No response') },
              color: switch (m.state) { 'ack' => Night.moodCalm, 'seen' => const Color(0xFFFFD166), _ => Night.inkMuted },
              canPing: m.state != 'ack'),
      ])),
      Padding(
        padding: const EdgeInsets.all(Night.space4),
        child: Row(children: [
          Expanded(child: NightButton(tx('開始點名', 'Start roll call'), kind: NightButtonKind.ghost, onPressed: _busy ? null : () async {
            await _do('rollcall', {'sub': c.sub});
            if (mounted) setState(() => _callTab = false);
          })),
          const SizedBox(width: 8),
          Expanded(child: NightButton(tx('結束集合', 'End gather'), onPressed: _busy ? null : () async {
            await _do('call_done');
            if (mounted) Navigator.pop(context);
          })),
        ]),
      ),
    ]);
  }

  Widget _rollView(TourGroup g) {
    if (g.rollId == null) {
      return Padding(
        padding: const EdgeInsets.all(Night.space4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tx('團員會收到點名提醒，回答「我到了」、「還要 5 分鐘」或「需要幫忙」。', 'Members answer "I\'m here", "5 more min" or "Need help".'), style: Night.body),
          if (g.subs.isNotEmpty) SubPicker(g: g, value: _sub, onChanged: (v) => setState(() => _sub = v)),
          const Spacer(),
          NightButton(tx('開始點名', 'Start roll call'), icon: Icons.checklist, onPressed: _busy ? null : () => _do('rollcall', {'sub': _sub})),
        ]),
      );
    }
    final t = g.rollTotal == 0 ? 1 : g.rollTotal;
    final none = g.rollRoster.where((m) => m.state == 'none').length;
    return Column(children: [
      _summary(tx('到了', 'Here'), g.here, g.rollTotal,
          [('', Night.moodCalm, g.here / t), ('', const Color(0xFFFFD166), g.late / t), ('', Night.danger, g.help / t)],
          tx('到了 ${g.here} · 還要 5 分鐘 ${g.late} · 需要幫忙 ${g.help} · 沒回應 $none', 'Here ${g.here} · 5 min ${g.late} · Help ${g.help} · No answer $none')),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: Night.space4), children: [
        for (final m in g.rollRoster)
          _row(g, m,
              status: switch (m.state) { 'here' => tx('到了', 'Here'), '5min' => tx('還要 5 分鐘', '5 more min'), 'help' => tx('需要幫忙', 'Needs help'), _ => tx('沒回應', 'No answer') },
              color: switch (m.state) { 'here' => Night.moodCalm, '5min' => const Color(0xFFFFD166), 'help' => Night.danger, _ => Night.inkMuted },
              urgent: m.state == 'help',
              canPing: m.state == 'none'),
      ])),
      Padding(
        padding: const EdgeInsets.all(Night.space4),
        child: NightButton(tx('人齊了，結束點名', 'Everyone\'s here'), expand: true, onPressed: _busy ? null : () async {
          await _do('roll_done');
          if (g.call != null) await _do('call_done');
          if (mounted) Navigator.pop(context);
        }),
      ),
    ]);
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
