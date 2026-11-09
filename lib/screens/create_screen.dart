import 'package:flutter/material.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../tour/zones.dart';
import '../ui/night.dart';
import 'join.dart';

/// 開團設定：團名、團色、出發日、行程天數、分組。共同團主在開團後從名單邀請。設計稿：開團設定
class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});
  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _name = TextEditingController();
  String _color = 'violet';
  int _days = 1;
  DateTime _start = DateTime.now();
  final List<String> _subs = [];
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _addSub() async {
    final ctl = TextEditingController(text: tx('${_subs.length + 1} 號車', 'Bus ${_subs.length + 1}'));
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Night.night700,
        title: Text(tx('新增分組', 'Add a sub-group'), style: Night.title),
        content: TextField(controller: ctl, maxLength: 10, autofocus: true, style: const TextStyle(color: Night.ink)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('取消', 'Cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: Text(tx('新增', 'Add'))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && !_subs.contains(name) && _subs.length < 6) setState(() => _subs.add(name));
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    final r = await TourService.call('create', {'name': _name.text, 'color': _color, 'days': _days, 'start': _ymd(_start), 'tz': deviceTz, 'subs': _subs});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['success'] == true) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      showGlassToast(context, tourError('${r['code']}'), danger: true, icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget label(String s) => Padding(padding: const EdgeInsets.only(bottom: Night.space2), child: Text(s, style: Night.caption.copyWith(color: Night.inkMuted)));
    return Scaffold(
      appBar: AppBar(backgroundColor: Night.night900, foregroundColor: Night.ink, title: Text(tx('開一個團', 'Start a group'), style: Night.title)),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(Night.space4), children: [
              label(tx('團名（20 字內）', 'Group name (up to 20)')),
              TextField(controller: _name, maxLength: 20, style: const TextStyle(color: Night.ink, fontSize: 15), decoration: InputDecoration(hintText: tx('例如：京都秋楓五日', 'e.g. Kyoto Autumn 5 Days'))),
              const SizedBox(height: Night.space3),
              label(tx('團色', 'Group color')),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final e in tourColors.entries)
                  Semantics(
                    button: true, selected: _color == e.key, label: e.key,
                    child: GestureDetector(
                      onTap: () => setState(() => _color = e.key),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: e.value, shape: BoxShape.circle, border: Border.all(color: _color == e.key ? Night.ink : Colors.transparent, width: 3)),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: Night.space2),
              Text(tx('集合點的旗子、團旗都用這個顏色。同一個景點有別的團時，選不一樣的顏色比較好認。', 'The meeting-point flag and group flag use this color.'), style: Night.caption),
              const SizedBox(height: Night.space6),
              TripFields(
                start: _start, days: _days, tint: tourColor(_color),
                onStart: (d) => setState(() => _start = d),
                onDays: (n) => setState(() => _days = n),
              ),
              const SizedBox(height: Night.space6),
              label(tx('分組（可以不分）', 'Sub-groups (optional)')),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in _subs)
                  InputChip(label: Text(s), onDeleted: () => setState(() => _subs.remove(s)), backgroundColor: Night.night600, labelStyle: const TextStyle(color: Night.ink)),
                if (_subs.length < 6)
                  ActionChip(label: Text(tx('新增分組', 'Add sub-group')), onPressed: _addSub, backgroundColor: Night.night700, labelStyle: const TextStyle(color: Night.inkMuted)),
              ]),
              const SizedBox(height: Night.space2),
              Text(tx('例如 1 號車、2 號車。集合、點名、公告可以只發給其中一組。', 'e.g. Bus 1, Bus 2. Gather, roll call and notices can go to one sub-group.'), style: Night.caption),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Night.space4, Night.space2, Night.space4, Night.space4),
            child: Column(children: [
              Text(tx('20 人、3 天以內免費。人數或天數超過時，再買人數券、天數券或使用團購券。', 'Free for up to 20 people and 3 days. Buy passes or use vouchers for more.'), style: Night.caption.copyWith(color: Night.inkMuted), textAlign: TextAlign.center),
              const SizedBox(height: Night.space3),
              NightButton(tx('開團，產生 QR code', 'Create and show QR code'), expand: true, onPressed: _busy ? null : _create),
            ]),
          ),
        ]),
      ),
    );
  }
}

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime? _parse(String s) {
  final x = s.split('-').map(int.tryParse).toList();
  return x.length == 3 && !x.contains(null) ? DateTime(x[0]!, x[1]!, x[2]!) : null;
}

/// 出發日（今天到 90 天後）與天數（1～30；超過 3 天要天數券）
class TripFields extends StatelessWidget {
  final DateTime start;
  final int days;
  final Color tint;
  final ValueChanged<DateTime> onStart;
  final ValueChanged<int> onDays;
  const TripFields({super.key, required this.start, required this.days, required this.tint, required this.onStart, required this.onDays});

  static const freeDays = 3, perPass = 7, maxDays = 30;
  static int passesFor(int days) => days <= freeDays ? 0 : ((days - freeDays) / perPass).ceil();

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    final end = DateTime(start.year, start.month, start.day + days - 1);
    String d(DateTime t) => '${t.month}/${t.day}';
    final isToday = start.year == t0.year && start.month == t0.month && start.day == t0.day;
    final passes = passesFor(days);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tx('出發日', 'Start date'), style: Night.caption.copyWith(color: Night.inkMuted)),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(isToday ? tx('今天 ${d(start)}', 'Today ${d(start)}') : '${start.year}/${d(start)}', style: const TextStyle(color: Night.ink, fontSize: 16)),
        subtitle: Text(tx('可以先開團讓團員入團，最遠選 90 天後', 'Set up early so members can join; up to 90 days ahead'), style: Night.caption),
        trailing: const Icon(Icons.calendar_month_outlined, color: Night.inkMuted),
        onTap: () async {
          final p = await showDatePicker(context: context, initialDate: start.isBefore(t0) ? t0 : start, firstDate: t0, lastDate: t0.add(const Duration(days: 90)));
          if (p != null) onStart(p);
        },
      ),
      const SizedBox(height: Night.space2),
      Text(tx('行程天數', 'Trip length'), style: Night.caption.copyWith(color: Night.inkMuted)),
      Row(children: [
        Expanded(child: Slider(value: days.toDouble(), min: 1, max: maxDays.toDouble(), divisions: maxDays - 1, activeColor: tint, onChanged: (v) => onDays(v.round()))),
        SizedBox(width: 120, child: Text(days == 1 ? tx('1 天 ${d(start)}', '1 day ${d(start)}') : tx('$days 天 ${d(start)}–${d(end)}', '$days days ${d(start)}–${d(end)}'), style: const TextStyle(color: Night.ink), textAlign: TextAlign.end)),
      ]),
      Text(
        passes == 0
            ? tx('3 天以內免費。結束日 23:59 自動解散，以最後一個集合點的當地時間為準。', 'Free up to 3 days. Ends at 23:59 on the last day, local time at the last meeting point.')
            : tx('前 3 天免費，之後要 $passes 張天數券（每張多 7 天）。還沒買之前，這一團會在第 3 天結束。', 'First 3 days free; needs $passes day pass(es) (7 days each). Until then the group ends on day 3.'),
        style: Night.caption.copyWith(color: passes == 0 ? Night.inkFaint : Night.cityAmber),
      ),
    ]);
  }
}

/// 團主改出發日或天數（行程表右上角）
Future<void> editTrip(BuildContext context, TourGroup g) async {
  var start = _parse(g.startDate) ?? DateTime.now();
  var days = g.days;
  final today = DateTime.now();
  final started = !start.isAfter(DateTime(today.year, today.month, today.day));
  await showPanel(context, (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(tx('出發日與天數', 'Dates'), closeTooltip: tx('關閉', 'Close')),
        const SizedBox(height: Night.space2),
        if (started)
          Text(tx('已經出發，只能改天數。', 'The trip has started; only the length can change.'), style: Night.caption)
        else
          const SizedBox.shrink(),
        TripFields(
          start: start, days: days, tint: g.tint,
          onStart: (d) { if (!started) setS(() => start = d); },
          onDays: (n) => setS(() => days = n),
        ),
        const SizedBox(height: Night.space2),
        Text(tx('目前開通 ${g.allowedDays} 天', '${g.allowedDays} days active'), style: Night.caption),
        const SizedBox(height: Night.space4),
        NightButton(tx('儲存', 'Save'), onPressed: () async {
          final r = await TourService.call('trip', {if (!started) 'start': _ymd(start), 'days': days});
          if (!ctx.mounted) return;
          if (r['success'] == true) {
            Navigator.pop(ctx);
          } else {
            showGlassToast(ctx, tourError('${r['code']}'), danger: true);
          }
        }),
      ]));
}
