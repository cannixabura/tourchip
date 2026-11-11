import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../tour/zones.dart';
import '../ui/night.dart';

/// 艾婭匯入：貼上旅行社給的行程或分房表 → 艾婭整理成每日資訊（飯店、Wi-Fi、早餐）、集合點、分房
/// → 領隊勾選後才存。領隊免費，每團最多 5 次。
class AiImportScreen extends StatefulWidget {
  final TourGroup group;
  const AiImportScreen({super.key, required this.group});
  @override
  State<AiImportScreen> createState() => _AiImportScreenState();
}

class _Day { final DayCard card; bool on = true; _Day(this.card); }
class _Stop { final int at; final String tz, place; bool on = true; _Stop(this.at, this.tz, this.place); }
class _Room { final String name, room, group; String? uid; _Room(this.name, this.room, this.group, this.uid); }

class _AiImportScreenState extends State<AiImportScreen> {
  final _text = TextEditingController();
  bool _busy = false;
  List<_Day>? _days;
  List<_Stop> _stops = [];
  List<_Room> _rooms = [];

  TourGroup get g => TourService.current.value ?? widget.group;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// 可以分房的人：團主、共同團主、團員
  List<(String, String)> get _people => [
        for (final s in g.staff) (s.uid, s.name.isNotEmpty ? s.name : tx('${s.no} 號', 'No. ${s.no}')),
        for (final m in g.members) (m.uid, m.label.isNotEmpty ? tx('${m.no} 號 ${m.label}', 'No. ${m.no} ${m.label}') : tx('${m.no} 號', 'No. ${m.no}')),
      ];

  /// 分房表的名字對到團員：備註或暱稱有包含（或被包含）就自動對上
  String? _match(String name) {
    final n = name.replaceAll(' ', '').toLowerCase();
    if (n.isEmpty) return null;
    bool hit(String s) {
      final t = s.replaceAll(' ', '').toLowerCase();
      return t.isNotEmpty && (t.contains(n) || n.contains(t));
    }
    for (final s in g.staff) {
      if (hit(s.name)) return s.uid;
    }
    for (final m in g.members) {
      if (hit(m.note) || hit(m.name)) return m.uid;
    }
    return null;
  }

  Future<void> _ask() async {
    final text = _text.text.trim();
    if (text.length < 10) {
      showGlassToast(context, tourError('ai_empty'), danger: true);
      return;
    }
    setState(() => _busy = true);
    final r = await TourService.call('ai_import', {'text': text});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['success'] != true) {
      showGlassToast(context, tourError('${r['code']}'), danger: true);
      return;
    }
    final imp = (r['import'] as Map?) ?? const {};
    setState(() {
      _days = [for (final d in (imp['days'] as List? ?? const [])) _Day(DayCard.fromJson(d as Map))];
      _stops = [for (final s in (imp['stops'] as List? ?? const [])) _Stop((s['at'] as num).toInt(), '${s['tz']}', '${s['place']}')];
      _rooms = [for (final x in (imp['rooms'] as List? ?? const [])) _Room('${x['name']}', '${x['room']}', '${x['group']}', _match('${x['name']}'))];
    });
    if (_days!.isEmpty && _stops.isEmpty && _rooms.isEmpty) showGlassToast(context, tx('艾婭沒有找到行程或分房資料，換一段文字試試。', 'AIYA found no itinerary or rooming data. Try different text.'), icon: Icons.info_outline);
  }

  /// 分組名稱對到這一團的分組（例如「1 號車」）；對不到就不改分組
  int? _subOf(String group) {
    final x = group.replaceAll(' ', '');
    if (x.isEmpty) return null;
    for (var i = 0; i < g.subs.length; i++) {
      final s = g.subs[i].replaceAll(' ', '');
      if (s == x || s.contains(x) || x.contains(s)) return i;
    }
    return null;
  }

  Future<void> _apply() async {
    setState(() => _busy = true);
    var fails = 0;
    for (final d in (_days ?? const <_Day>[]).where((d) => d.on)) {
      // 和原本的每日資訊合併：說明接在後面、飯店用新的（沒有才用舊的）、攻略連結保留
      final old = g.dayCard(d.card.date);
      final note = [if (old != null && old.note.isNotEmpty) old.note, if (d.card.note.isNotEmpty && d.card.note != old?.note) d.card.note].join('\n');
      final hotel = d.card.hotel != null && d.card.hotel!.name.isNotEmpty ? d.card.hotel : old?.hotel;
      final r = await TourService.call('day_set', {
        'date': d.card.date,
        'note': note,
        'hotel': hotel?.toJson(),
        'links': [for (final l in old?.links ?? const <GuideLink>[]) l.toJson()],
      });
      if (r['success'] != true) fails++;
    }
    for (final s in _stops.where((s) => s.on)) {
      final r = await TourService.call('stop_add', {'at': s.at, 'tz': s.tz, 'place': s.place});
      if (r['success'] != true) fails++;
    }
    final rows = [
      for (final x in _rooms)
        if (x.uid != null) {'uid': x.uid, if (x.room.isNotEmpty) 'room': x.room, if (_subOf(x.group) != null && !g.staff.any((s) => s.uid == x.uid)) 'sub': _subOf(x.group)}
    ];
    if (rows.isNotEmpty) {
      final r = await TourService.call('rooms', {'list': rows});
      if (r['success'] != true) fails++;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.pop(context);
    showGlassToast(context, fails == 0 ? tx('已經存好了', 'Saved') : tx('存好了，有 $fails 項沒存成功，請再檢查一次。', 'Saved, but $fails items failed. Please check.'),
        danger: fails > 0, icon: Icons.auto_awesome);
  }

  String _dayLabel(String date) {
    final p = date.split('-');
    return p.length == 3 ? '${int.parse(p[1])}/${int.parse(p[2])}' : date;
  }

  @override
  Widget build(BuildContext context) {
    final preview = _days != null;
    Widget head(String t) => Padding(padding: const EdgeInsets.fromLTRB(0, Night.space4, 0, Night.space2), child: Text(t, style: Night.caption.copyWith(color: Night.inkMuted)));
    return Scaffold(
      appBar: AppBar(backgroundColor: Night.night900, foregroundColor: Night.ink, title: Text(tx('艾婭匯入', 'Import with AIYA'), style: Night.title)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(Night.space4), children: [
          if (!preview) ...[
            Text(tx('貼上旅行社給的行程表或分房表，艾婭會整理出每天的飯店（Wi-Fi、早餐）、集合時間地點和房號。存之前你可以先檢查、取消不要的。',
                'Paste the itinerary or rooming list from the agency. AIYA extracts each day\'s hotel (Wi-Fi, breakfast), meeting times and places, and room numbers. You can review everything before saving.'), style: Night.body),
            const SizedBox(height: Night.space2),
            Text(tx('這一團還可以用 ${g.aiLeft} 次。艾婭是 AI，可能會出錯，請檢查後再存。', '${g.aiLeft} imports left for this group. AIYA is AI and can make mistakes, so check before saving.'), style: Night.caption),
            const SizedBox(height: Night.space3),
            TextField(
              controller: _text,
              minLines: 8,
              maxLines: 16,
              maxLength: 6000,
              style: const TextStyle(color: Night.ink, fontSize: 14),
              decoration: InputDecoration(
                hintText: tx('例如：\n第一天 07:30 桃園機場第二航廈集合…\n住宿：札幌 JR Inn（早餐 6:30–9:30）\n分房：王小明 1203、李美華 1205', 'e.g.\nDay 1 07:30 meet at Taoyuan Airport T2…\nHotel: JR Inn Sapporo (breakfast 6:30–9:30)\nRooms: Wang 1203, Lee 1205'),
                hintStyle: TextStyle(color: Night.inkMuted.withValues(alpha: 0.5)),
                border: const OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.content_paste, size: 18),
                label: Text(tx('貼上', 'Paste')),
                onPressed: () async {
                  final d = await Clipboard.getData(Clipboard.kTextPlain);
                  if (d?.text != null) setState(() => _text.text = d!.text!);
                },
              ),
            ),
            const SizedBox(height: Night.space2),
            NightButton(_busy ? tx('艾婭整理中…', 'AIYA is reading…') : tx('請艾婭整理', 'Ask AIYA'), icon: Icons.auto_awesome, onPressed: _busy || g.aiLeft <= 0 ? null : _ask),
          ] else ...[
            Text(tx('勾選要存的項目。集合點會加進行程表，每日資訊會和原本的合併。', 'Check what to save. Stops are added to the itinerary; day info is merged with what you have.'), style: Night.caption),
            if (_days!.isNotEmpty) head(tx('每日資訊', 'Day info')),
            for (final d in _days!)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: d.on,
                onChanged: (v) => setState(() => d.on = v ?? false),
                title: Text('${_dayLabel(d.card.date)}  ${d.card.hotel?.name ?? ''}', style: const TextStyle(color: Night.ink)),
                subtitle: Text([
                  if (d.card.hotel?.breakfast.isNotEmpty == true) tx('早餐 ${d.card.hotel!.breakfast}', 'Breakfast ${d.card.hotel!.breakfast}'),
                  if (d.card.hotel?.wifi.isNotEmpty == true) 'Wi-Fi ${d.card.hotel!.wifi}',
                  if (d.card.note.isNotEmpty) d.card.note,
                ].join(' · '), style: Night.caption, maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            if (_stops.isNotEmpty) head(tx('集合點', 'Stops')),
            for (final s in _stops)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: s.on,
                onChanged: (v) => setState(() => s.on = v ?? false),
                title: Text(s.place, style: const TextStyle(color: Night.ink)),
                subtitle: Text('${md(s.at, s.tz)} ${hm(s.at, s.tz)} · ${zoneChip(s.at, s.tz)}', style: Night.caption),
              ),
            if (_rooms.isNotEmpty) ...[
              head(tx('分房（對到團員才會存；對不到的請自己選）', 'Rooms (saved only when matched to a member; pick if unmatched)')),
              for (final x in _rooms)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(child: Text([x.name, if (x.room.isNotEmpty) tx('${x.room} 房', 'Rm ${x.room}'), if (x.group.isNotEmpty) x.group].join(' · '), style: const TextStyle(color: Night.ink))),
                    DropdownButton<String?>(
                      value: x.uid,
                      dropdownColor: Night.night700,
                      hint: Text(tx('選團員', 'Pick member'), style: Night.caption),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text(tx('不套用', 'Skip'), style: Night.caption)),
                        for (final p in _people) DropdownMenuItem<String?>(value: p.$1, child: Text(p.$2, style: const TextStyle(color: Night.ink))),
                      ],
                      onChanged: (v) => setState(() => x.uid = v),
                    ),
                  ]),
                ),
            ],
            const SizedBox(height: Night.space4),
            Row(children: [
              Expanded(child: NightButton(tx('重新貼', 'Start over'), kind: NightButtonKind.ghost, onPressed: _busy ? null : () => setState(() => _days = null))),
              const SizedBox(width: 8),
              Expanded(child: NightButton(_busy ? tx('儲存中…', 'Saving…') : tx('存起來', 'Save'), onPressed: _busy ? null : _apply)),
            ]),
          ],
        ]),
      ),
    );
  }
}
