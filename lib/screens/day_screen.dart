import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/nav.dart';
import '../tour/service.dart';
import '../tour/zones.dart';
import '../translate.dart';
import '../ui/night.dart';
import 'itinerary_screen.dart';

/// 每日資訊卡：團主、共同團主以「天」為單位寫好當天的說明（餐食、注意事項…）、今晚的飯店、攻略連結；
/// 團員在行程表點那一天就看得到。攻略只放連結，點了用瀏覽器打開，App 不放景點圖文。

String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// 行程表裡某一天的資訊卡（沒有內容時，團員看不到這一塊；團主看到「寫這一天的資訊」）
class DaySection extends StatelessWidget {
  final TourGroup g;
  final DateTime day;
  const DaySection({super.key, required this.g, required this.day});

  @override
  Widget build(BuildContext context) {
    final card = g.dayCard(ymd(day));
    if (card == null) {
      if (!g.isStaff) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: Night.space3),
        child: NightButton(tx('寫這一天的資訊（說明、飯店、攻略連結）', 'Add info for this day'), kind: NightButtonKind.ghost, icon: Icons.edit_note,
            onPressed: () => _edit(context)),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: Night.space3),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Night.night700, borderRadius: BorderRadius.circular(Night.radiusMd), border: Border.all(color: Night.glassLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.wb_sunny_outlined, color: g.tint, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(tx('今天的資訊', 'About this day'), style: const TextStyle(color: Night.ink, fontSize: 15, fontWeight: FontWeight.w600))),
          if (g.isStaff)
            TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () => _edit(context), child: Text(tx('編輯', 'Edit')),
            ),
        ]),
        if (card.note.isNotEmpty) ...[
          const SizedBox(height: 6),
          TranslatableText(card.note, style: Night.body.copyWith(color: Night.ink)),
        ],
        if (card.hotel != null) ...[
          const SizedBox(height: Night.space3),
          HotelTile(hotel: card.hotel!, tint: g.tint),
        ],
        if (card.links.isNotEmpty) ...[
          const SizedBox(height: Night.space3),
          Text(tx('攻略連結', 'Guides'), style: Night.caption.copyWith(color: Night.inkMuted)),
          for (final l in card.links)
            InkWell(
              onTap: () => openLink(context, l.url),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  const Icon(Icons.link, color: Night.auroraBlue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.title, style: const TextStyle(color: Night.auroraBlue, fontSize: 15)),
                    Text(Uri.tryParse(l.url)?.host ?? '', style: Night.caption),
                  ])),
                  const Icon(Icons.open_in_new, color: Night.inkFaint, size: 16),
                ]),
              ),
            ),
        ],
      ]),
    );
  }

  void _edit(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DayEditor(group: g, day: day)));
}

/// 飯店：名稱、當地地址、電話、導航、給司機看
class HotelTile extends StatelessWidget {
  final TourHotel hotel;
  final Color tint;
  const HotelTile({super.key, required this.hotel, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Night.night600, borderRadius: BorderRadius.circular(Night.radiusMd)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.hotel_outlined, color: tint, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(hotel.name.isEmpty ? tx('今晚的飯店', "Tonight's hotel") : hotel.name, style: const TextStyle(color: Night.ink, fontSize: 15, fontWeight: FontWeight.w600))),
        ]),
        if (hotel.addr.isNotEmpty) ...[
          const SizedBox(height: 4),
          SelectableText(hotel.addr, style: Night.body.copyWith(color: Night.ink)),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Chip(tx('給司機看', 'Show driver'), Icons.local_taxi_outlined, () => showDriverCard(context, hotel)),
          if (hotel.hasCoord) _Chip(tx('帶我走過去', 'Walk there'), Icons.directions_walk, () => walkTo(context, hotel.lat!, hotel.lng!, label: hotel.name)),
          if (hotel.phone.isNotEmpty) _Chip(hotel.phone, Icons.call_outlined, () => callPhone(context, hotel.phone)),
        ]),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _Chip(this.label, this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(icon, size: 16, color: Night.ink),
        label: Text(label),
        onPressed: onTap,
        backgroundColor: Night.night700,
        side: const BorderSide(color: Night.glassLine),
        labelStyle: const TextStyle(color: Night.ink, fontSize: 13),
      );
}

/// 給計程車司機看的飯店卡：白底大字（當地語言的名稱與地址）
void showDriverCard(BuildContext context, TourHotel h) {
  Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (ctx) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Text(tx('請載我到這裡', 'Please take me here'), style: const TextStyle(color: Colors.black54, fontSize: 18)),
            const SizedBox(height: 16),
            if (h.name.isNotEmpty) Text(h.name, style: const TextStyle(color: Colors.black, fontSize: 34, fontWeight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 16),
            if (h.addr.isNotEmpty) Text(h.addr, style: const TextStyle(color: Colors.black, fontSize: 26, height: 1.4)),
            if (h.phone.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('☎ ${h.phone}', style: const TextStyle(color: Colors.black87, fontSize: 24)),
            ],
          ]),
        ),
      )));
}

/// 編輯某一天的資訊卡：說明、今晚的飯店、攻略連結（最多 10 個）
class DayEditor extends StatefulWidget {
  final TourGroup group;
  final DateTime day;
  const DayEditor({super.key, required this.group, required this.day});
  @override
  State<DayEditor> createState() => _DayEditorState();
}

class _LinkRow {
  final title = TextEditingController();
  final url = TextEditingController();
  void dispose() { title.dispose(); url.dispose(); }
}

class _DayEditorState extends State<DayEditor> {
  late final DayCard? _card = widget.group.dayCard(ymd(widget.day));
  late final _note = TextEditingController(text: _card?.note ?? '');
  late final _hName = TextEditingController(text: _card?.hotel?.name ?? '');
  late final _hAddr = TextEditingController(text: _card?.hotel?.addr ?? '');
  late final _hPhone = TextEditingController(text: _card?.hotel?.phone ?? '');
  late double? _lat = _card?.hotel?.lat, _lng = _card?.hotel?.lng;
  final List<_LinkRow> _links = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final l in _card?.links ?? const <GuideLink>[]) {
      _links.add(_LinkRow()..title.text = l.title..url.text = l.url);
    }
  }

  @override
  void dispose() {
    for (final c in [_note, _hName, _hAddr, _hPhone]) {
      c.dispose();
    }
    for (final l in _links) {
      l.dispose();
    }
    super.dispose();
  }

  /// 沿用前面最近一天的飯店（連住好幾晚）
  TourHotel? get _prevHotel {
    final cards = widget.group.dayCards.where((c) => c.hotel != null && c.date.compareTo(ymd(widget.day)) < 0).toList();
    return cards.isEmpty ? null : cards.last.hotel;
  }

  Future<void> _paste(TextEditingController c) async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => c.text = d!.text!.trim());
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final r = await TourService.call('day_set', {
      'date': ymd(widget.day),
      'note': _note.text,
      'hotel': {'name': _hName.text, 'addr': _hAddr.text, 'phone': _hPhone.text, 'lat': _lat, 'lng': _lng},
      'links': [
        for (final l in _links)
          if (l.url.text.trim().isNotEmpty) {'title': l.title.text, 'url': l.url.text.trim()}
      ],
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['success'] == true) {
      Navigator.pop(context, true);
      showGlassToast(context, tx('這一天的資訊已更新', 'Day info updated'), icon: Icons.event_note_outlined);
    } else {
      showGlassToast(context, tourError('${r['code']}'), danger: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final d = widget.day;
    final prev = _prevHotel;
    Widget label(String s) => Padding(padding: const EdgeInsets.only(top: Night.space4, bottom: Night.space2), child: Text(s, style: Night.caption.copyWith(color: Night.inkMuted)));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Night.night900, foregroundColor: Night.ink,
        title: Text(tx('${d.month}/${d.day} 的資訊', 'Info for ${d.month}/${d.day}'), style: Night.title),
        actions: [
          if (_card != null)
            IconButton(tooltip: tx('刪除', 'Delete'), icon: const Icon(Icons.delete_outline, color: Night.danger), onPressed: () async {
              final r = await TourService.call('day_set', {'date': ymd(d), 'note': ''});
              if (r['success'] == true && context.mounted) Navigator.pop(context, true);
            }),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(Night.space4), children: [
          label(tx('今天的說明（餐食、注意事項、穿著…）', 'Notes for the day (meals, reminders…)')),
          TextField(
            controller: _note, maxLength: 1000, minLines: 4, maxLines: 12, style: const TextStyle(color: Night.ink),
            decoration: InputDecoration(hintText: tx('例如：早餐 7:00 一樓餐廳；午餐自理；今天走路多，請穿好走的鞋', 'e.g. Breakfast 7:00 on 1F; lunch on your own; wear good shoes'), hintMaxLines: 3),
          ),
          Text(tx('團員可以點一下翻譯成自己的語言。', 'Members can tap to translate it.'), style: Night.caption),

          label(tx('今晚的飯店', "Tonight's hotel")),
          if (prev != null && _hName.text.isEmpty && _hAddr.text.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: Text(tx('沿用前一晚：${prev.name}', 'Same as before: ${prev.name}')),
                onPressed: () => setState(() {
                  _hName.text = prev.name; _hAddr.text = prev.addr; _hPhone.text = prev.phone; _lat = prev.lat; _lng = prev.lng;
                }),
              ),
            ),
          TextField(controller: _hName, maxLength: 40, style: const TextStyle(color: Night.ink), decoration: InputDecoration(labelText: tx('飯店名稱（當地語言）', 'Hotel name (local language)'))),
          TextField(controller: _hAddr, maxLength: 200, minLines: 1, maxLines: 3, style: const TextStyle(color: Night.ink),
              decoration: InputDecoration(labelText: tx('地址（當地語言，給司機看）', 'Address (local language, for drivers)'))),
          TextField(controller: _hPhone, maxLength: 25, keyboardType: TextInputType.phone, style: const TextStyle(color: Night.ink), decoration: InputDecoration(labelText: tx('電話', 'Phone'))),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tx('在地圖上的位置（導航用，可以不選）', 'Location on map (for directions, optional)'), style: Night.caption.copyWith(color: Night.inkMuted)),
            subtitle: Text(_lat == null ? tx('還沒選', 'Not set') : '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}', style: const TextStyle(color: Night.ink)),
            trailing: const Icon(Icons.chevron_right, color: Night.inkFaint),
            onTap: () async {
              final p = await Navigator.of(context).push<LatLng>(MaterialPageRoute(builder: (_) => PickPointScreen(group: g, start: _lat == null ? null : LatLng(_lat!, _lng!))));
              if (p != null) setState(() { _lat = p.latitude; _lng = p.longitude; });
            },
          ),

          label(tx('攻略連結（最多 10 個；團員點了用瀏覽器打開）', 'Guide links (up to 10; open in the browser)')),
          for (var i = 0; i < _links.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: Night.space2),
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
              decoration: BoxDecoration(color: Night.night700, borderRadius: BorderRadius.circular(Night.radiusMd)),
              child: Column(children: [
                Row(children: [
                  Expanded(child: TextField(controller: _links[i].title, maxLength: 40, style: const TextStyle(color: Night.ink),
                      decoration: InputDecoration(labelText: tx('標題', 'Title'), hintText: tx('例如：清水寺怎麼逛', 'e.g. Kiyomizu-dera guide'), counterText: ''))),
                  IconButton(tooltip: tx('刪除', 'Delete'), icon: const Icon(Icons.close, color: Night.inkMuted), onPressed: () => setState(() => _links.removeAt(i).dispose())),
                ]),
                Row(children: [
                  Expanded(child: TextField(controller: _links[i].url, keyboardType: TextInputType.url, autocorrect: false, style: const TextStyle(color: Night.ink),
                      decoration: const InputDecoration(labelText: 'https://'))),
                  IconButton(tooltip: tx('貼上', 'Paste'), icon: const Icon(Icons.content_paste, color: Night.inkMuted), onPressed: () => _paste(_links[i].url)),
                ]),
              ]),
            ),
          if (_links.length < 10)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(icon: const Icon(Icons.add_link), label: Text(tx('新增連結', 'Add link')), onPressed: () => setState(() => _links.add(_LinkRow()))),
            ),
          const SizedBox(height: Night.space6),
          NightButton(tx('儲存', 'Save'), expand: true, onPressed: _busy ? null : _save),
        ]),
      ),
    );
  }
}
