import 'package:flutter/material.dart';

import '../l10n.dart';
import '../map/tour_map.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../tour/zones.dart';
import '../ui/night.dart';
import 'group_screen.dart';
import 'roll_call_screen.dart';

/// 發出集合：拖曳地圖把光柱放到集合點，選幾分鐘後、寫一行說明、選通知誰。設計稿：發出集合
/// 從行程表點「發出這次集合」時，會帶入那個集合點的說明、座標與時區。
class GatherScreen extends StatefulWidget {
  final TourStop? stop;
  const GatherScreen({super.key, this.stop});
  @override
  State<GatherScreen> createState() => _GatherScreenState();
}

class _GatherScreenState extends State<GatherScreen> {
  final _map = GlobalKey<TourMapState>();
  late final _place = TextEditingController(text: widget.stop?.place ?? '');
  int _minutes = 15;
  int? _sub;
  late String _tz = widget.stop?.tz.isNotEmpty == true ? widget.stop!.tz : deviceTz;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.stop?.sub;
    // 行程表的集合點在未來：預設集合時間就是那個時間（3 小時內）
    final s = widget.stop;
    if (s != null) {
      final m = ((s.at - DateTime.now().millisecondsSinceEpoch) / 60000).round();
      if (m > 0 && m <= 180) _minutes = m;
    }
  }

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final center = _map.currentState?.center;
    if (center == null) return;
    setState(() => _busy = true);
    final r = await TourService.call('call', {
      'at': DateTime.now().millisecondsSinceEpoch + _minutes * 60000,
      'tz': _tz, 'place': _place.text, 'lat': center.latitude, 'lng': center.longitude, 'sub': _sub,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['success'] == true) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RollCallScreen(showCall: true)));
    } else {
      showGlassToast(context, tourError('${r['code']}'), danger: true, icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = TourService.current.value;
    if (g == null) return const SizedBox.shrink();
    final at = DateTime.now().millisecondsSinceEpoch + _minutes * 60000;
    Widget chip(int m, String label) => ChoiceChip(
          label: Text(label), selected: _minutes == m, onSelected: (_) => setState(() => _minutes = m),
          selectedColor: Night.deepViolet, backgroundColor: Night.night600, labelStyle: TextStyle(color: _minutes == m ? Night.onDeep : Night.ink),
        );
    return Scaffold(
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: TourMap(key: _map, group: g, picking: true, onReady: (c) {
              final s = widget.stop;
              if (s?.lat != null) _map.currentState?.flyTo(s!.lat!, s.lng!);
            })),
            Positioned(
              left: Night.space4, top: MediaQuery.of(context).padding.top + Night.space2,
              child: CircleAvatar(backgroundColor: Night.glassFill, child: IconButton(tooltip: tx('關閉', 'Close'), icon: const Icon(Icons.close, color: Night.ink), onPressed: () => Navigator.pop(context))),
            ),
            Positioned(
              left: 0, right: 0, bottom: Night.space3,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Night.glassFill, borderRadius: BorderRadius.circular(99), border: Border.all(color: g.tint)),
                child: Text(tx('拖曳地圖，把光柱放到集合點', 'Drag the map to place the pillar'), style: Night.caption.copyWith(color: Night.ink)),
              )),
            ),
          ]),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(Night.space4, 18, Night.space4, MediaQuery.of(context).padding.bottom + Night.space4),
          decoration: const BoxDecoration(color: Night.night700, borderRadius: BorderRadius.vertical(top: Radius.circular(Night.radiusLg)), boxShadow: [Night.glowViolet]),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tx('發出集合', 'Gather the group'), style: Night.title),
            const SizedBox(height: Night.space3),
            Text(tx('幾分鐘後集合', 'Gather in'), style: Night.caption.copyWith(color: Night.inkMuted)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              chip(0, tx('現在', 'Now')),
              for (final m in [10, 15, 30, 60]) chip(m, tx('$m 分', '$m min')),
              if (![0, 10, 15, 30, 60].contains(_minutes)) chip(_minutes, tx('$_minutes 分', '$_minutes min')),
            ]),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final z = await pickZone(context, _tz);
                if (z != null) setState(() => _tz = z);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(tx('${hm(at, _tz)} 集合，${zoneChip(at, _tz)}（點一下換時區）', 'At ${hm(at, _tz)}, ${zoneChip(at, _tz)} (tap to change)'), style: Night.caption),
              ),
            ),
            const SizedBox(height: Night.space3),
            TextField(controller: _place, maxLength: 30, style: const TextStyle(color: Night.ink), decoration: InputDecoration(labelText: tx('集合點說明（30 字內）', 'Meeting point (up to 30)'), hintText: tx('例如：捷運西門站 6 號出口', 'e.g. Exit 6, Ximen Station'))),
            if (g.subs.isNotEmpty) SubPicker(g: g, value: _sub, onChanged: (v) => setState(() => _sub = v)),
            const SizedBox(height: Night.space3),
            Text(tx('團員手機會響專屬提示音，穿透專注模式。沒按「收到」的人每分鐘再提醒一次，最多 3 次。', 'Members get a distinct alert that breaks through Focus. Reminders every minute, up to 3 times.'), style: Night.caption),
            const SizedBox(height: Night.space3),
            NightButton(tx('發出集合呼叫', 'Send gather call'), icon: Icons.campaign_outlined, onPressed: _busy ? null : _send),
          ]),
        ),
      ]),
    );
  }
}

/// 選時區：常用城市＋手機目前的時區
Future<String?> pickZone(BuildContext context, String current) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final zones = [if (!commonZones.any((z) => z.$1 == deviceTz)) deviceTz, for (final z in commonZones) z.$1];
  return showModalBottomSheet<String>(
    context: context, backgroundColor: Night.night700, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Night.radiusLg))),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.all(Night.space4), child: Text(tx('集合點的當地時間', 'Local time at the meeting point'), style: Night.title)),
          for (final z in zones)
            ListTile(
              title: Text(zoneName(z), style: const TextStyle(color: Night.ink)),
              subtitle: Text('${utcLabel(now, z)} · ${hm(now, z)}', style: Night.caption),
              trailing: z == current ? const Icon(Icons.check, color: Night.auroraViolet) : (z == deviceTz ? Text(tx('這支手機', 'This phone'), style: Night.caption) : null),
              onTap: () => Navigator.pop(ctx, z),
            ),
        ]),
      ),
    ),
  );
}
