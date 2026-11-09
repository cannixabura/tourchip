import 'package:flutter/material.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/nav.dart';
import '../tour/service.dart';
import '../tour/zones.dart';
import '../translate.dart';
import '../ui/night.dart';
import 'day_screen.dart';

/// 團體資訊：我坐的車、今晚的飯店、緊急聯絡（領隊、旅行社、當地報警與救護）、我的資料。
/// 團主、共同團主可以編輯車輛與緊急聯絡；飯店在每日資訊卡裡設定。
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  /// 今天（團的時區）；出發前看第一天
  static DateTime today(TourGroup g) {
    final t = localAt(DateTime.now().millisecondsSinceEpoch, g.tz);
    final d = DateTime(t.year, t.month, t.day);
    final s = g.startDate.split('-').map(int.tryParse).toList();
    if (s.length == 3 && !s.contains(null)) {
      final start = DateTime(s[0]!, s[1]!, s[2]!);
      if (d.isBefore(start)) return start;
    }
    return d;
  }

  /// 現在人在哪個國家：進行中的集合、下一個集合點、開團的時區
  static String hereTz(TourGroup g) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (g.call != null) return g.call!.tz;
    final past = g.stops.where((s) => s.at <= now).lastOrNull;
    final next = g.stops.where((s) => s.at > now).firstOrNull;
    return (past ?? next)?.tz ?? g.tz;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TourGroup?>(
      valueListenable: TourService.current,
      builder: (context, g, _) {
        if (g == null) return const SizedBox.shrink();
        final day = today(g);
        final hotel = g.dayCard(ymd(day))?.hotel;
        final buses = g.myBuses;
        final em = g.emergency;
        final local = emergencyFor(hereTz(g));
        Widget section(String title, IconData icon, List<Widget> children, {VoidCallback? onEdit}) => Container(
              margin: const EdgeInsets.only(bottom: Night.space3),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Night.night700, borderRadius: BorderRadius.circular(Night.radiusMd), border: Border.all(color: Night.glassLine)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(icon, color: g.tint, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(color: Night.ink, fontSize: 15, fontWeight: FontWeight.w600))),
                  if (onEdit != null)
                    TextButton(style: TextButton.styleFrom(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap), onPressed: onEdit, child: Text(tx('編輯', 'Edit'))),
                ]),
                const SizedBox(height: 6),
                ...children,
              ]),
            );
        void editInfo() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InfoEditor(group: g)));
        return Scaffold(
          appBar: AppBar(backgroundColor: Night.night900, foregroundColor: Night.ink, title: Text(tx('團體資訊', 'Group info'), style: Night.title)),
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(Night.space4), children: [
              // ---- 車輛 ----
              section(tx('車輛', 'Bus'), Icons.directions_bus_outlined, [
                if (buses.isEmpty)
                  Text(g.isStaff ? tx('還沒填車輛資訊', 'No bus info yet') : tx('領隊還沒填車輛資訊', 'No bus info yet'), style: Night.body)
                else
                  for (final b in buses) _BusRow(g: g, b: b),
              ], onEdit: g.isStaff ? editInfo : null),

              // ---- 今晚的飯店 ----
              section(tx('${day.month}/${day.day} 的飯店', 'Hotel on ${day.month}/${day.day}'), Icons.hotel_outlined, [
                if (hotel == null)
                  Text(g.isStaff ? tx('在行程表的每日資訊裡設定飯店', 'Set hotels in the day info on the itinerary') : tx('領隊還沒填飯店', 'No hotel yet'), style: Night.body)
                else
                  HotelTile(hotel: hotel, tint: g.tint),
              ]),

              // ---- 緊急聯絡 ----
              section(tx('緊急聯絡', 'Emergency'), Icons.health_and_safety_outlined, [
                if (em.phone.isNotEmpty) _PhoneRow(tx('領隊', 'Leader'), em.phone),
                if (em.agency.isNotEmpty || em.agencyPhone.isNotEmpty) _PhoneRow(em.agency.isEmpty ? tx('旅行社', 'Travel agency') : em.agency, em.agencyPhone, sub: tx('24 小時緊急電話', '24-hour line')),
                if (em.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: TranslatableText(em.note, style: Night.body.copyWith(color: Night.ink))),
                if (local != null) ...[
                  if (!em.isEmpty) const Divider(color: Night.glassLine, height: 20),
                  Text(tx('${local.country}當地', 'In ${local.country}'), style: Night.caption.copyWith(color: Night.inkMuted)),
                  if (local.police == local.ambulance)
                    _PhoneRow(tx('報警、救護、消防', 'Police, ambulance, fire'), local.police)
                  else ...[
                    _PhoneRow(tx('報警', 'Police'), local.police),
                    _PhoneRow(tx('救護車', 'Ambulance'), local.ambulance),
                  ],
                  if (local.extra != null) _PhoneRow(local.extraLabel ?? '', local.extra!),
                ] else if (em.isEmpty)
                  Text(tx('領隊還沒填緊急聯絡', 'No emergency contacts yet'), style: Night.body),
              ], onEdit: g.isStaff ? editInfo : null),

              // ---- 我的資料（團員自己填，只給團主與共同團主） ----
              if (!g.isStaff)
                section(tx('我的資料', 'My details'), Icons.badge_outlined, [
                  Text(tx('飲食禁忌、健康狀況、緊急聯絡人。只有團主和共同團主看得到，退團或解散就刪除。', 'Diet, health and an emergency contact. Only the leaders can see it; deleted when you leave or the group ends.'), style: Night.caption),
                  const SizedBox(height: 8),
                  if (g.myData != null && !g.myData!.isEmpty) ...[
                    if (g.myData!.diet.isNotEmpty) Text(tx('飲食：${g.myData!.diet}', 'Diet: ${g.myData!.diet}'), style: Night.body.copyWith(color: Night.ink)),
                    if (g.myData!.health.isNotEmpty) Text(tx('健康：${g.myData!.health}', 'Health: ${g.myData!.health}'), style: Night.body.copyWith(color: Night.ink)),
                    if (g.myData!.contact.isNotEmpty)
                      Text(tx('緊急聯絡人：${g.myData!.contact}', 'Emergency contact: ${g.myData!.contact}'), style: Night.body.copyWith(color: Night.ink)),
                    const SizedBox(height: 8),
                  ],
                  NightButton(g.myData == null ? tx('填寫我的資料', 'Add my details') : tx('修改我的資料', 'Edit my details'), kind: NightButtonKind.ghost, icon: Icons.edit_outlined,
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemberDataEditor(data: g.myData)))),
                ]),
            ]),
          ),
        );
      },
    );
  }
}

class _BusRow extends StatelessWidget {
  final TourGroup g;
  final TourBus b;
  const _BusRow({required this.g, required this.b});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (g.subs.isNotEmpty) Text(b.sub == null ? tx('全團', 'Everyone') : g.subName(b.sub), style: Night.caption.copyWith(color: Night.inkMuted)),
        if (b.plate.isNotEmpty) Text(b.plate, style: const TextStyle(color: Night.ink, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 1)),
        if (b.desc.isNotEmpty) Text(b.desc, style: Night.body.copyWith(color: Night.ink)),
        if (b.driver.isNotEmpty || b.phone.isNotEmpty) _PhoneRow(b.driver.isEmpty ? tx('司機', 'Driver') : tx('司機 ${b.driver}', 'Driver ${b.driver}'), b.phone),
        if (b.note.isNotEmpty) TranslatableText(b.note, compact: true, style: Night.caption.copyWith(color: Night.inkMuted)),
      ]),
    );
  }
}

class _PhoneRow extends StatelessWidget {
  final String label, phone;
  final String? sub;
  const _PhoneRow(this.label, this.phone, {this.sub});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: phone.isEmpty ? null : () => callPhone(context, phone),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Night.body.copyWith(color: Night.ink)),
            if (sub != null) Text(sub!, style: Night.caption),
          ])),
          if (phone.isNotEmpty) ...[
            Text(phone, style: const TextStyle(color: Night.ink, fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            const Icon(Icons.call, color: Night.moodCalm, size: 20),
          ],
        ]),
      ),
    );
  }
}

/// 團主、共同團主編輯車輛（全團一台或每組一台）與緊急聯絡
class InfoEditor extends StatefulWidget {
  final TourGroup group;
  const InfoEditor({super.key, required this.group});
  @override
  State<InfoEditor> createState() => _InfoEditorState();
}

class _BusForm {
  final int? sub;
  final plate = TextEditingController(), desc = TextEditingController(), driver = TextEditingController(), phone = TextEditingController(), note = TextEditingController();
  _BusForm(this.sub, TourBus? b) {
    plate.text = b?.plate ?? ''; desc.text = b?.desc ?? ''; driver.text = b?.driver ?? ''; phone.text = b?.phone ?? ''; note.text = b?.note ?? '';
  }
  List<TextEditingController> get all => [plate, desc, driver, phone, note];
  Map<String, dynamic> toJson() => {'sub': sub, 'plate': plate.text, 'desc': desc.text, 'driver': driver.text, 'phone': phone.text, 'note': note.text};
}

class _InfoEditorState extends State<InfoEditor> {
  late final List<_BusForm> _buses;
  late final _phone = TextEditingController(text: widget.group.emergency.phone);
  late final _agency = TextEditingController(text: widget.group.emergency.agency);
  late final _agencyPhone = TextEditingController(text: widget.group.emergency.agencyPhone);
  late final _note = TextEditingController(text: widget.group.emergency.note);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    TourBus? find(int? sub) => g.buses.where((b) => b.sub == sub).firstOrNull;
    // 有分組：每組一台（也可以只填「全團」那一台）；沒分組：全團一台
    _buses = [_BusForm(null, find(null)), for (var i = 0; i < g.subs.length; i++) _BusForm(i, find(i))];
  }

  @override
  void dispose() {
    for (final b in _buses) {
      for (final c in b.all) {
        c.dispose();
      }
    }
    for (final c in [_phone, _agency, _agencyPhone, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final r = await TourService.call('info_set', {
      'buses': [for (final b in _buses) b.toJson()],
      'emergency': {'phone': _phone.text, 'agency': _agency.text, 'agencyPhone': _agencyPhone.text, 'note': _note.text},
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['success'] == true) {
      Navigator.pop(context, true);
      showGlassToast(context, tx('團體資訊已更新', 'Group info updated'), icon: Icons.info_outline);
    } else {
      showGlassToast(context, tourError('${r['code']}'), danger: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    Widget label(String s) => Padding(padding: const EdgeInsets.only(top: Night.space4, bottom: Night.space2), child: Text(s, style: Night.caption.copyWith(color: Night.inkMuted)));
    Widget field(TextEditingController c, String l, int max, {TextInputType? kb}) =>
        TextField(controller: c, maxLength: max, keyboardType: kb, style: const TextStyle(color: Night.ink), decoration: InputDecoration(labelText: l, counterText: ''));
    return Scaffold(
      appBar: AppBar(backgroundColor: Night.night900, foregroundColor: Night.ink, title: Text(tx('編輯團體資訊', 'Edit group info'), style: Night.title)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(Night.space4), children: [
          for (final b in _buses) ...[
            label(b.sub == null ? (g.subs.isEmpty ? tx('車輛', 'Bus') : tx('全團的車（每組不同車就填下面）', 'Bus for everyone (or fill in each sub-group below)')) : tx('${g.subName(b.sub)}的車', 'Bus for ${g.subName(b.sub)}')),
            field(b.plate, tx('車牌', 'Plate number'), 15),
            field(b.desc, tx('車色、車型（例如：白色大巴）', 'Color and type (e.g. white coach)'), 20),
            Row(children: [
              Expanded(child: field(b.driver, tx('司機稱呼', 'Driver name'), 20)),
              const SizedBox(width: 12),
              Expanded(child: field(b.phone, tx('司機電話', 'Driver phone'), 25, kb: TextInputType.phone)),
            ]),
            field(b.note, tx('備註（例如：停在 B2 出口）', 'Note (e.g. parked at exit B2)'), 40),
          ],
          label(tx('緊急聯絡', 'Emergency contacts')),
          field(_phone, tx('領隊電話', 'Leader phone'), 25, kb: TextInputType.phone),
          field(_agency, tx('旅行社名稱', 'Travel agency'), 30),
          field(_agencyPhone, tx('旅行社 24 小時電話', 'Agency 24-hour phone'), 25, kb: TextInputType.phone),
          TextField(controller: _note, maxLength: 200, minLines: 2, maxLines: 5, style: const TextStyle(color: Night.ink),
              decoration: InputDecoration(labelText: tx('其他（例如：駐日代表處電話、保險公司）', 'Other (e.g. embassy, insurance)'))),
          Text(tx('當地的報警、救護電話會依集合點的國家自動顯示。', 'Local police and ambulance numbers are shown automatically.'), style: Night.caption),
          const SizedBox(height: Night.space6),
          NightButton(tx('儲存', 'Save'), expand: true, onPressed: _busy ? null : _save),
        ]),
      ),
    );
  }
}

/// 團員自己填的資料（飲食、健康、緊急聯絡人）；只有團主與共同團主看得到
class MemberDataEditor extends StatefulWidget {
  final MemberData? data;
  const MemberDataEditor({super.key, this.data});
  @override
  State<MemberDataEditor> createState() => _MemberDataEditorState();
}

class _MemberDataEditorState extends State<MemberDataEditor> {
  late final _diet = TextEditingController(text: widget.data?.diet ?? '');
  late final _health = TextEditingController(text: widget.data?.health ?? '');
  late final _contact = TextEditingController(text: widget.data?.contact ?? '');
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_diet, _health, _contact]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save({bool clear = false}) async {
    setState(() => _busy = true);
    final r = await TourService.call('mdata', clear
        ? const {}
        : {'diet': _diet.text, 'health': _health.text, 'contact': _contact.text});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['success'] == true) {
      Navigator.pop(context, true);
      showGlassToast(context, clear ? tx('已刪除我的資料', 'Your details were deleted') : tx('已儲存，只有領隊看得到', 'Saved. Only your leaders can see it.'), icon: Icons.lock_outline);
    } else {
      showGlassToast(context, tourError('${r['code']}'), danger: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController c, String l, int max, {String? hint, TextInputType? kb, int lines = 1}) => TextField(
        controller: c, maxLength: max, keyboardType: kb, minLines: 1, maxLines: lines, style: const TextStyle(color: Night.ink),
        decoration: InputDecoration(labelText: l, hintText: hint));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Night.night900, foregroundColor: Night.ink,
        title: Text(tx('我的資料', 'My details'), style: Night.title),
        actions: [
          if (widget.data != null)
            IconButton(tooltip: tx('刪除', 'Delete'), icon: const Icon(Icons.delete_outline, color: Night.danger), onPressed: _busy ? null : () => _save(clear: true)),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(Night.space4), children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Night.night700, borderRadius: BorderRadius.circular(Night.radiusMd)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lock_outline, color: Night.inkMuted, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                tx('全部都可以不填。只有團主和共同團主看得到，用來安排餐食和處理緊急狀況；你退團或這一團解散時就刪除。',
                    'Everything is optional. Only your leaders can see it, for meals and emergencies. Deleted when you leave or the group ends.'),
                style: Night.caption.copyWith(color: Night.inkMuted),
              )),
            ]),
          ),
          const SizedBox(height: Night.space3),
          field(_diet, tx('飲食禁忌', 'Diet'), 60, hint: tx('例如：素食、不吃牛、海鮮過敏', 'e.g. vegetarian, no beef')),
          field(_health, tx('健康狀況（過敏、慢性病、常用藥）', 'Health (allergies, conditions, medicine)'), 150, lines: 4),
          field(_contact, tx('緊急聯絡人', 'Emergency contact'), 20, hint: tx('例如：媽媽 王小明', 'e.g. Mom')),
          const SizedBox(height: Night.space6),
          NightButton(tx('儲存', 'Save'), expand: true, onPressed: _busy ? null : () => _save()),
        ]),
      ),
    );
  }
}
