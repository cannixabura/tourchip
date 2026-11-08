import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../l10n.dart';
import '../map/tour_map.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../tour/zones.dart';
import '../ui/night.dart';
import 'gather_screen.dart';
import 'join.dart';

/// 行程表：每天的集合時間與集合點，一律用集合點的當地時間。設計稿：行程表
/// 團主、共同團主可以新增、修改、刪除；時間快到時一鍵「發出這次集合」。
/// 最後一個集合點的時區決定這一團幾點解散（結束日 23:59 當地時間）。
class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});
  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  int? _day;

  /// 行程的每一天（開團時的時區）
  List<DateTime> _days(TourGroup g) {
    DateTime? p(String s) {
      final x = s.split('-').map(int.tryParse).toList();
      return x.length == 3 && !x.contains(null) ? DateTime(x[0]!, x[1]!, x[2]!) : null;
    }
    final a = p(g.startDate), b = p(g.endDate);
    if (a == null || b == null) return [];
    return [for (var d = a; !d.isAfter(b); d = DateTime(d.year, d.month, d.day + 1)) d];
  }

  bool _sameDay(TourStop s, DateTime d) {
    final t = localAt(s.at, s.tz);
    return t.year == d.year && t.month == d.month && t.day == d.day;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TourGroup?>(
      valueListenable: TourService.current,
      builder: (context, g, _) {
        if (g == null) return const SizedBox.shrink();
        final days = _days(g);
        final now = DateTime.now().millisecondsSinceEpoch;
        final todayIdx = days.indexWhere((d) { final t = localAt(now, g.tz); return d.year == t.year && d.month == t.month && d.day == t.day; });
        final day = (_day ?? (todayIdx >= 0 ? todayIdx : 0)).clamp(0, days.isEmpty ? 0 : days.length - 1);
        final stops = days.isEmpty ? <TourStop>[] : g.stops.where((s) => _sameDay(s, days[day])).toList();
        final next = g.stops.where((s) => s.at >= now - 10 * 60000).firstOrNull;
        final crossZone = stops.map((s) => s.tz).toSet().length > 1;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Night.night900, foregroundColor: Night.ink,
            title: Text(tx('行程表', 'Itinerary'), style: Night.title),
            actions: [if (g.isStaff) TextButton(onPressed: () => _edit(context, g, days.isEmpty ? null : days[day]), child: Text(tx('新增集合點', 'Add stop')))],
          ),
          body: SafeArea(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                height: 68,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Night.space4, vertical: 8),
                  itemCount: days.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final sel = i == day;
                    return InkWell(
                      borderRadius: BorderRadius.circular(Night.radiusMd),
                      onTap: () => setState(() => _day = i),
                      child: Container(
                        width: 64,
                        decoration: BoxDecoration(gradient: sel ? Night.deepGradient : null, color: sel ? null : Night.night700, borderRadius: BorderRadius.circular(Night.radiusMd)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(tx('第 ${i + 1} 天', 'Day ${i + 1}'), style: TextStyle(color: sel ? Night.onDeep : Night.inkMuted, fontSize: 12)),
                          Text('${days[i].month}/${days[i].day}', style: TextStyle(color: sel ? Night.onDeep : Night.ink, fontSize: 14, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(Night.space4, 4, Night.space4, Night.space3),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Night.night700, borderRadius: BorderRadius.circular(Night.radiusMd)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.schedule, color: Night.inkMuted, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    crossZone
                        ? tx('這一天跨時區。每個集合時間都是當地時間，團員不用自己換算。', 'This day crosses time zones. Every time is local to its meeting point.')
                        : tx('每個集合時間都是集合點的當地時間。', 'Every time is local to its meeting point.'),
                    style: Night.caption.copyWith(color: Night.inkMuted),
                  )),
                ]),
              ),
              Expanded(
                child: stops.isEmpty
                    ? Center(child: Text(g.isStaff ? tx('這一天還沒有集合點', 'No stops on this day yet') : tx('這一天沒有安排集合', 'No meeting points this day'), style: Night.body))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: Night.space4),
                        itemCount: stops.length,
                        itemBuilder: (_, i) => _StopRow(g: g, s: stops[i], isNext: next?.id == stops[i].id, last: i == stops.length - 1, onEdit: () => _edit(context, g, null, stops[i])),
                      ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, TourGroup g, DateTime? day, [TourStop? s]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => StopEditor(group: g, day: day, stop: s)));
    if (saved == true && context.mounted) showGlassToast(context, tx('行程表已更新', 'Itinerary updated'), icon: Icons.event_note_outlined);
  }
}

class _StopRow extends StatelessWidget {
  final TourGroup g;
  final TourStop s;
  final bool isNext, last;
  final VoidCallback onEdit;
  const _StopRow({required this.g, required this.s, required this.isNext, required this.last, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final past = s.at < now - 10 * 60000;
    final canSend = g.isStaff && isNext && s.at - now <= 3 * 3600000;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 14, child: Column(children: [
          const SizedBox(height: 6),
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isNext ? g.tint : (past ? Night.night600 : Colors.transparent),
              border: past || isNext ? null : Border.all(color: Night.inkMuted, width: 2),
              boxShadow: isNext ? [BoxShadow(color: g.tint, blurRadius: 10)] : null,
            ),
          ),
          if (!last) Expanded(child: Container(width: 2, color: Night.night600)),
        ])),
        const SizedBox(width: 14),
        Expanded(
          child: InkWell(
            onLongPress: g.isStaff ? onEdit : null,
            onTap: g.isStaff ? onEdit : null,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(hm(s.at, s.tz), style: const TextStyle(color: Night.ink, fontSize: 22, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Night.night600, borderRadius: BorderRadius.circular(99)),
                    child: Text(zoneChip(s.at, s.tz), style: const TextStyle(color: Night.ink, fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(s.place, style: const TextStyle(color: Night.ink, fontSize: 15)),
                if (s.sub != null) Text(g.subName(s.sub), style: Night.caption.copyWith(color: Night.inkMuted)),
                if (canSend) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: NightButton(tx('發出這次集合', 'Send this gather call'), icon: Icons.campaign_outlined,
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GatherScreen(stop: s)))),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// 新增或修改一個集合點：日期、當地時間、時區、說明、地點（可以不選）、分組
class StopEditor extends StatefulWidget {
  final TourGroup group;
  final DateTime? day;
  final TourStop? stop;
  const StopEditor({super.key, required this.group, this.day, this.stop});
  @override
  State<StopEditor> createState() => _StopEditorState();
}

class _StopEditorState extends State<StopEditor> {
  late final _place = TextEditingController(text: widget.stop?.place ?? '');
  late String _tz;
  late DateTime _date;
  late TimeOfDay _time;
  double? _lat, _lng;
  int? _sub;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = widget.stop, g = widget.group;
    _tz = s?.tz ?? (g.stops.isNotEmpty ? g.stops.last.tz : deviceTz);
    if (s != null) {
      final t = localAt(s.at, s.tz);
      _date = DateTime(t.year, t.month, t.day);
      _time = TimeOfDay(hour: t.hour, minute: t.minute);
      _lat = s.lat; _lng = s.lng; _sub = s.sub;
    } else {
      _date = widget.day ?? DateTime.now();
      _time = const TimeOfDay(hour: 9, minute: 0);
    }
  }

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final at = msAt(_tz, _date.year, _date.month, _date.day, _time.hour, _time.minute);
    final r = await TourService.call('stop_add', {
      if (widget.stop != null) 'id': widget.stop!.id,
      'at': at, 'tz': _tz, 'place': _place.text, 'lat': _lat, 'lng': _lng, 'sub': _sub,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['success'] == true) {
      Navigator.pop(context, true);
    } else {
      showGlassToast(context, tourError('${r['code']}'), danger: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final at = msAt(_tz, _date.year, _date.month, _date.day, _time.hour, _time.minute);
    Widget field(String label, String value, VoidCallback onTap) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: Night.caption.copyWith(color: Night.inkMuted)),
          subtitle: Text(value, style: const TextStyle(color: Night.ink, fontSize: 16)),
          trailing: const Icon(Icons.chevron_right, color: Night.inkFaint),
          onTap: onTap,
        );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Night.night900, foregroundColor: Night.ink,
        title: Text(widget.stop == null ? tx('新增集合點', 'Add stop') : tx('修改集合點', 'Edit stop'), style: Night.title),
        actions: [
          if (widget.stop != null)
            IconButton(tooltip: tx('刪除', 'Delete'), icon: const Icon(Icons.delete_outline, color: Night.danger), onPressed: () async {
              final ok = await confirmSheet(context, tx('刪除這個集合點？', 'Delete this stop?'), action: tx('刪除', 'Delete'), danger: true);
              if (ok != true) return;
              await TourService.call('stop_remove', {'id': widget.stop!.id});
              if (context.mounted) Navigator.pop(context, true);
            }),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(Night.space4), children: [
          TextField(controller: _place, maxLength: 30, autofocus: widget.stop == null, style: const TextStyle(color: Night.ink),
              decoration: InputDecoration(labelText: tx('集合點（30 字內）', 'Meeting point (up to 30)'), hintText: tx('例如：關西機場 第一航廈 南出口', 'e.g. KIX Terminal 1 South Exit'))),
          field(tx('日期', 'Date'), '${_date.month}/${_date.day}', () async {
            // 只能選行程內的日期（開團前一天到結束日）
            final days = widget.group.startDate.split('-').map(int.tryParse).toList();
            final ends = widget.group.endDate.split('-').map(int.tryParse).toList();
            final first = days.contains(null) || days.length != 3 ? DateTime.now() : DateTime(days[0]!, days[1]!, days[2]! - 1);
            final last = ends.contains(null) || ends.length != 3 ? DateTime.now().add(const Duration(days: 7)) : DateTime(ends[0]!, ends[1]!, ends[2]!);
            final init = _date.isBefore(first) ? first : (_date.isAfter(last) ? last : _date);
            final d = await showDatePicker(context: context, initialDate: init, firstDate: first, lastDate: last);
            if (d != null) setState(() => _date = d);
          }),
          field(tx('當地時間', 'Local time'), '${two(_time.hour)}:${two(_time.minute)}', () async {
            final t = await showTimePicker(context: context, initialTime: _time);
            if (t != null) setState(() => _time = t);
          }),
          field(tx('集合點在哪個時區', 'Time zone'), zoneChip(at, _tz), () async {
            final z = await pickZone(context, _tz);
            if (z != null) setState(() => _tz = z);
          }),
          field(tx('在地圖上的位置（可以不選）', 'Location on map (optional)'), _lat == null ? tx('還沒選', 'Not set') : '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}', () async {
            final p = await Navigator.of(context).push<LatLng>(MaterialPageRoute(builder: (_) => PickPointScreen(group: g, start: _lat == null ? null : LatLng(_lat!, _lng!))));
            if (p != null) setState(() { _lat = p.latitude; _lng = p.longitude; });
          }),
          if (g.subs.isNotEmpty) ...[
            const SizedBox(height: Night.space2),
            Text(tx('哪一組', 'Which sub-group'), style: Night.caption.copyWith(color: Night.inkMuted)),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: Text(tx('全團', 'Everyone')), selected: _sub == null, onSelected: (_) => setState(() => _sub = null)),
              for (var i = 0; i < g.subs.length; i++) ChoiceChip(label: Text(g.subs[i]), selected: _sub == i, onSelected: (_) => setState(() => _sub = i)),
            ]),
          ],
          const SizedBox(height: Night.space6),
          NightButton(tx('儲存', 'Save'), expand: true, onPressed: _busy ? null : _save),
        ]),
      ),
    );
  }
}

/// 在 3D 地圖上選一個點（拖曳地圖，光柱在中央）
class PickPointScreen extends StatefulWidget {
  final TourGroup group;
  final LatLng? start;
  const PickPointScreen({super.key, required this.group, this.start});
  @override
  State<PickPointScreen> createState() => _PickPointScreenState();
}

class _PickPointScreenState extends State<PickPointScreen> {
  final _map = GlobalKey<TourMapState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Night.night900, foregroundColor: Night.ink, title: Text(tx('拖曳地圖選集合點', 'Drag to place the point'), style: Night.title)),
      body: TourMap(key: _map, group: widget.group, picking: true, center: widget.start),
      // 按鈕要包在 mainAxisSize.min 的 Column 裡：直接放進 bottomNavigationBar 會被撐滿整個畫面，把地圖擠成零高度
      bottomNavigationBar: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.all(Night.space4),
            child: NightButton(tx('用這個位置', 'Use this spot'), expand: true, onPressed: () {
              final c = _map.currentState?.center;
              if (c != null) Navigator.pop(context, c);
            }),
          ),
        ]),
      ),
    );
  }
}
