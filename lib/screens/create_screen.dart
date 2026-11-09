import 'package:flutter/material.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../tour/zones.dart';
import '../ui/night.dart';

/// 開團設定：團名、團色、行程天數、分組。共同團主在開團後從名單邀請。設計稿：開團設定
class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});
  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _name = TextEditingController();
  String _color = 'violet';
  int _days = 1;
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
    final r = await TourService.call('create', {'name': _name.text, 'color': _color, 'days': _days, 'tz': deviceTz, 'subs': _subs});
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
    final now = DateTime.now();
    final end = now.add(Duration(days: _days - 1));
    String d(DateTime t) => '${t.month}/${t.day}';
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
              label(tx('行程天數（最長 7 天）', 'Trip length (up to 7 days)')),
              Row(children: [
                Expanded(child: Slider(value: _days.toDouble(), min: 1, max: 7, divisions: 6, activeColor: tourColor(_color), onChanged: (v) => setState(() => _days = v.round()))),
                SizedBox(width: 120, child: Text(_days == 1 ? tx('今天 ${d(now)}', 'Today ${d(now)}') : '${d(now)} – ${d(end)}', style: const TextStyle(color: Night.ink), textAlign: TextAlign.end)),
              ]),
              Text(tx('結束日 23:59 自動解散，以最後一個集合點的當地時間為準。', 'Ends at 23:59 on the last day, local time at the last meeting point.'), style: Night.caption),
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
              Text(tx('20 人以內免費。超過時再買 7 天方案或使用團購券。', 'Free up to 20. Upgrade later with a 7-day pass or a voucher.'), style: Night.caption.copyWith(color: Night.inkMuted), textAlign: TextAlign.center),
              const SizedBox(height: Night.space3),
              NightButton(tx('開團，產生 QR code', 'Create and show QR code'), expand: true, onPressed: _busy ? null : _create),
            ]),
          ),
        ]),
      ),
    );
  }
}
