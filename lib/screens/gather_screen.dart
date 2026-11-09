import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../map/tour_map.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../tour/zones.dart';
import '../ui/night.dart';
import 'group_screen.dart';
import 'roll_call_screen.dart';

/// 發出集合：拖曳地圖把旗子放到集合點，選幾分鐘後、寫一行說明、選通知誰。設計稿：發出集合
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
  /// 自訂分鐘數（1～720）：有輸入時，上面的「現在、10、15、30、60 分」都不選
  final _custom = TextEditingController();
  final _cardKey = GlobalKey();
  double _cardH = 0;
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
      if (m > 0 && m <= 180) {
        _minutes = m;
        if (![10, 15, 30, 60].contains(m)) _custom.text = '$m';
      }
    }
  }

  int? get _customMin => int.tryParse(_custom.text);
  bool get _customBad => _custom.text.isNotEmpty && (_customMin == null || _customMin! < 1 || _customMin! > 720);

  /// 量浮動卡片的高度：地圖往上延伸同樣的高度，地圖中央（旗子的位置）就落在卡片上方看得到的地方
  void _measure() {
    final h = (_cardKey.currentContext?.findRenderObject() as RenderBox?)?.size.height ?? 0;
    if ((h - _cardH).abs() > 1 && mounted) setState(() => _cardH = h);
  }

  @override
  void dispose() {
    _place.dispose();
    _custom.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final center = _map.currentState?.center;
    if (center == null || _customBad) return;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final at = DateTime.now().millisecondsSinceEpoch + _minutes * 60000;
    final customOn = _custom.text.isNotEmpty;
    Widget chip(int m, String label) => ChoiceChip(
          label: Text(label), selected: !customOn && _minutes == m,
          onSelected: (_) => setState(() {
            _minutes = m;
            _custom.clear();
            FocusScope.of(context).unfocus();
          }),
          selectedColor: Night.deepViolet, backgroundColor: Night.night600, labelStyle: TextStyle(color: !customOn && _minutes == m ? Night.onDeep : Night.ink),
        );
    final pad = MediaQuery.of(context).padding;
    // 卡片底下留空間給地圖出處標示（TourMap 畫在畫面最底下）
    final bottomGap = (pad.bottom < 12 ? 12.0 : pad.bottom) + 6;
    final card = Container(
      key: _cardKey,
      padding: const EdgeInsets.fromLTRB(Night.space4, Night.space2, Night.space2, Night.space4),
      decoration: BoxDecoration(
        color: Night.night700, borderRadius: BorderRadius.circular(Night.radiusLg),
        border: Border.all(color: Night.glassLine), boxShadow: const [Night.glowViolet],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(tx('發出集合', 'Gather the group'), style: Night.title)),
          IconButton(tooltip: tx('關閉', 'Close'), icon: const Icon(Icons.close, color: Night.ink), onPressed: () => Navigator.pop(context)),
        ]),
        Padding(
          padding: const EdgeInsets.only(right: Night.space2),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tx('幾分鐘後集合', 'Gather in'), style: Night.caption.copyWith(color: Night.inkMuted)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              chip(0, tx('現在', 'Now')),
              for (final m in [10, 15, 30, 60]) chip(m, tx('$m 分', '$m min')),
              SizedBox(
                width: 104,
                child: TextField(
                  controller: _custom,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                  textAlign: TextAlign.center,
                  style: TextStyle(color: customOn ? Night.onDeep : Night.ink, fontSize: 15),
                  onChanged: (v) => setState(() {
                    final m = int.tryParse(v);
                    if (m != null && m >= 1 && m <= 720) _minutes = m;
                  }),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: tx('自訂', 'Custom'),
                    suffixText: tx('分', 'min'),
                    suffixStyle: TextStyle(color: customOn ? Night.onDeep : Night.inkMuted),
                    filled: true,
                    fillColor: customOn && !_customBad ? Night.deepViolet : Night.night600,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _customBad ? Night.danger : Night.glassLine)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _customBad ? Night.danger : Night.auroraViolet, width: 1.5)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            if (_customBad)
              Text(tx('請輸入 1～720 分鐘', 'Enter 1 to 720 minutes'), style: Night.caption.copyWith(color: Night.danger))
            else
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
            NightButton(tx('發出集合呼叫', 'Send gather call'), icon: Icons.campaign_outlined, onPressed: _busy || _customBad ? null : _send),
          ]),
        ),
      ]),
    );
    return Scaffold(
      backgroundColor: Night.night900,
      body: Stack(children: [
        // 地圖往上延伸卡片的高度：地圖中央＝卡片上方可見區域的中央
        Positioned(
          // 可見區域：狀態列下方到提示文字上方（提示＋間距約 40）
          left: 0, right: 0, bottom: 0, top: pad.top - (_cardH + bottomGap + 40),
          child: TourMap(key: _map, group: g, picking: true, onReady: (c) {
            final s = widget.stop;
            if (s?.lat != null) _map.currentState?.flyTo(s!.lat!, s.lng!);
          }),
        ),
        Positioned(
          left: Night.space4, right: Night.space4, bottom: bottomGap, top: pad.top + Night.space2,
          child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Night.glassFill, borderRadius: BorderRadius.circular(99), border: Border.all(color: g.tint)),
              child: Text(tx('拖曳地圖，把旗子放到集合點', 'Drag the map to place the flag'), style: Night.caption.copyWith(color: Night.ink)),
            )),
            const SizedBox(height: Night.space2),
            Flexible(child: SingleChildScrollView(child: card)),
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
