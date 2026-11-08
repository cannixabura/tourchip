import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../map/tour_map.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../tour/zones.dart';
import '../translate.dart';
import '../ui/night.dart';
import 'call_overlay.dart';
import 'gather_screen.dart';
import 'itinerary_screen.dart';
import 'join.dart';
import 'members_screen.dart';
import 'pass_screen.dart';
import 'qr_screen.dart';
import 'roll_call_screen.dart';
import 'settings_screen.dart';
import 'social.dart';

/// 在團裡的主畫面：3D 夜光地圖＋集合點光柱，下方是操作面板。
/// 團主、共同團主看到集合、點名、公告、行程；團員看到集合卡片、團旗、我迷路了。設計稿：領隊 3D 地圖
class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});
  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _map = GlobalKey<TourMapState>();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // 倒數計時每秒更新
    _tick = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
    // 第一次進團：問要不要和團員互相看得到（按過「先不要」就不再主動問）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final g = TourService.current.value;
      if (g != null && mounted) maybeAskConsent(context, g);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TourGroup?>(
      valueListenable: TourService.current,
      builder: (context, g, _) {
        if (g == null) return const SizedBox.shrink();
        return Scaffold(
          body: Stack(children: [
            Positioned.fill(child: TourMap(key: _map, group: g, onPersonLongPress: (p) => openChat(context, p.uid), onPersonTap: (p) => showPerson(context, p))),
            Positioned(left: Night.space4, right: Night.space4, top: MediaQuery.of(context).padding.top + Night.space2, child: _TopBar(g: g)),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // 左邊：我的氣泡；右下角：設定（大頭貼、暱稱、語言、分享位置、說明…）
                Padding(
                  padding: const EdgeInsets.fromLTRB(Night.space4, 0, Night.space4, Night.space3),
                  child: Row(children: [
                    Flexible(child: _BubbleChip(g: g)),
                    const Spacer(),
                    const SettingsButton(),
                  ]),
                ),
                g.isStaff ? _StaffPanel(g: g, map: _map) : _MemberPanel(g: g, map: _map),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

/// 「第 2 天 · 京都」
String dayLabel(TourGroup g) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final today = localAt(now, g.tz);
  final parts = g.startDate.split('-').map(int.tryParse).toList();
  if (parts.length != 3 || parts.contains(null)) return '';
  final start = DateTime(parts[0]!, parts[1]!, parts[2]!);
  final day = DateTime(today.year, today.month, today.day).difference(start).inDays + 1;
  final next = g.stops.where((s) => s.at >= now - 3600000).firstOrNull;
  final place = next == null ? '' : ' · ${zoneName(next.tz).split('・').first}';
  return '${tx('第 $day 天', 'Day $day')}$place';
}

class _TopBar extends StatelessWidget {
  final TourGroup g;
  const _TopBar({required this.g});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(color: Night.glassFill, borderRadius: BorderRadius.circular(999), border: Border.all(color: Night.glassLine), boxShadow: const [Night.lift]),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: g.tint, shape: BoxShape.circle, boxShadow: [BoxShadow(color: g.tint, blurRadius: 8)])),
        const SizedBox(width: 10),
        Expanded(child: Text(g.name, style: const TextStyle(color: Night.ink, fontSize: 15, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        Text(dayLabel(g), style: Night.caption.copyWith(color: Night.inkMuted)),
        if (g.isStaff)
          IconButton(
            tooltip: tx('入團 QR code', 'Join QR code'),
            icon: const Icon(Icons.qr_code_2, color: Night.ink),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScreen())),
          ),
        ValueListenableBuilder<int>(
          valueListenable: unreadMsgs,
          builder: (context, n, _) => IconButton(
            tooltip: tx('訊息', 'Messages'),
            icon: Badge(isLabelVisible: n > 0, label: Text('$n'), backgroundColor: Night.knockPink, child: const Icon(Icons.chat_bubble_outline, color: Night.ink)),
            onPressed: () => showInbox(context),
          ),
        ),
        IconButton(tooltip: tx('更多', 'More'), icon: const Icon(Icons.more_vert, color: Night.ink), onPressed: () => _menu(context, g)),
      ]),
    );
  }

  void _menu(BuildContext context, TourGroup g) {
    showPanel(context, (ctx, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(g.name, style: Night.title, textAlign: TextAlign.center),
      const SizedBox(height: Night.space2),
      Text(
        [
          if (g.myNo != null && !g.isStaff) tx('你是 ${g.myNo} 號', 'You are No. ${g.myNo}'),
          if (g.mySub != null && !g.isStaff) g.subName(g.mySub),
          tx('${g.count} 人', '${g.count} people'),
          tx('團主 ${g.hostName.isEmpty ? '' : g.hostName}', 'Leader ${g.hostName}'),
        ].join(' · '),
        style: Night.caption, textAlign: TextAlign.center,
      ),
      const SizedBox(height: Night.space4),
      if (g.isStaff) ...[
        NightButton(tx('團員名單', 'Members'), kind: NightButtonKind.ghost, icon: Icons.people_outline, onPressed: () {
          Navigator.pop(ctx);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MembersScreen()));
        }),
        const SizedBox(height: Night.space2),
      ],
      if (g.isHost) ...[
        NightButton(g.paid ? tx('7 天方案（已升級）', '7-day pass (active)') : tx('升級到 100 人', 'Upgrade to 100 people'), kind: NightButtonKind.ghost, icon: Icons.workspace_premium_outlined, onPressed: () {
          Navigator.pop(ctx);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PassScreen()));
        }),
        const SizedBox(height: Night.space2),
        NightButton(tx('解散這一團', 'End this group'), kind: NightButtonKind.danger, icon: Icons.logout, onPressed: () async {
          Navigator.pop(ctx);
          final ok = await confirmSheet(context, tx('解散後名單、點名紀錄、行程表都會刪除，所有團員都會收到通知。', 'Ending deletes the list, roll calls and itinerary. Everyone will be notified.'), action: tx('解散', 'End group'), danger: true);
          if (ok == true) await TourService.call('dissolve');
        }),
      ] else
        NightButton(tx('退出這一團', 'Leave this group'), kind: NightButtonKind.danger, icon: Icons.logout, onPressed: () async {
          Navigator.pop(ctx);
          final ok = await confirmSheet(context, tx('退出後就收不到集合與點名了。', 'You will stop receiving gather calls.'), action: tx('退出', 'Leave'), danger: true);
          if (ok != true) return;
          final r = await TourService.call('leave');
          if (r['success'] != true && context.mounted) showGlassToast(context, tourError('${r['code']}'), danger: true);
        }),
    ]));
  }
}

String countdown(int at) {
  final left = Duration(milliseconds: max(0, at - DateTime.now().millisecondsSinceEpoch));
  if (left.inSeconds <= 0) return tx('現在', 'Now');
  return '${left.inMinutes}:${two(left.inSeconds % 60)}';
}

class _Panel extends StatelessWidget {
  final List<Widget> children;
  const _Panel({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(Night.space4, 18, Night.space4, max(MediaQuery.of(context).padding.bottom, Night.space4) + 4),
      decoration: BoxDecoration(
        color: Night.night700.withValues(alpha: 0.94),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Night.radiusLg)),
        border: const Border(top: BorderSide(color: Night.glassLine)),
        boxShadow: const [Night.lift],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;
  const _ActionTile(this.label, this.icon, this.onTap, {this.highlight = false});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Night.night600,
        borderRadius: BorderRadius.circular(Night.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(Night.radiusMd),
          onTap: onTap,
          child: Container(
            height: 64,
            decoration: highlight ? BoxDecoration(borderRadius: BorderRadius.circular(Night.radiusMd), border: Border.all(color: Night.danger)) : null,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: Night.ink, size: 20),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Night.ink, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 團主、共同團主的面板：集合狀態、四個操作、迷路的團員
class _StaffPanel extends StatelessWidget {
  final TourGroup g;
  final GlobalKey<TourMapState> map;
  const _StaffPanel({required this.g, required this.map});

  @override
  Widget build(BuildContext context) {
    final call = g.call;
    final roll = g.rollId != null;
    final String head;
    final String big;
    double? progress;
    String? clock;
    if (call != null) {
      head = '${hm(call.at, call.tz)} ${tx('集合', 'gather')} · ${zoneName(call.tz).split('・').first}${call.sub != null ? ' · ${g.subName(call.sub)}' : ''}';
      big = roll ? tx('到了 ${g.here}／${g.rollTotal}', 'Here ${g.here}/${g.rollTotal}') : tx('收到 ${g.acked}／${g.callTotal}', 'Got it ${g.acked}/${g.callTotal}');
      progress = roll ? (g.rollTotal == 0 ? 0 : g.here / g.rollTotal) : (g.callTotal == 0 ? 0 : g.acked / g.callTotal);
      clock = countdown(call.at);
    } else if (roll) {
      head = tx('點名中', 'Roll call');
      big = tx('到了 ${g.here}／${g.rollTotal}', 'Here ${g.here}/${g.rollTotal}');
      progress = g.rollTotal == 0 ? 0 : g.here / g.rollTotal;
    } else {
      head = '${tx('${g.count} 人', '${g.count} people')} · ${g.paid ? tx('上限 100 人', 'up to 100') : tx('20 人以內免費', 'free up to 20')}';
      big = tx('目前沒有集合', 'No gather call');
    }
    return _Panel(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(head, style: Night.caption.copyWith(color: Night.inkMuted)),
            const SizedBox(height: 2),
            Text(big, style: Night.title),
          ]),
        ),
        if (clock != null) Text(clock, style: const TextStyle(color: Night.ink, fontSize: 22, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
      ]),
      if (progress != null) ...[
        const SizedBox(height: Night.space3),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Night.night600, valueColor: AlwaysStoppedAnimation(g.tint)),
        ),
      ],
      if (g.lost.isNotEmpty) ...[
        const SizedBox(height: Night.space3),
        for (final l in g.lost.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => map.currentState?.flyTo(l.lat, l.lng),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: Night.danger)),
                  child: Row(children: [
                    const Icon(Icons.location_on, color: Night.danger, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(tx('${l.no} 號 ${l.note.isNotEmpty ? l.note : l.name} 迷路了 · ${_ago(l.at)}', 'No. ${l.no} is lost · ${_ago(l.at)}'), style: const TextStyle(color: Night.danger, fontSize: 13), overflow: TextOverflow.ellipsis)),
                    TextButton(onPressed: () => TourService.call('found', {'uid': l.uid}), child: Text(tx('找到了', 'Found'))),
                  ]),
                ),
              ),
            ),
          ),
      ],
      const SizedBox(height: Night.space3),
      Row(children: [
        _ActionTile(tx('集合', 'Gather'), Icons.campaign_outlined, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GatherScreen()))),
        const SizedBox(width: 8),
        _ActionTile(tx('點名', 'Roll call'), Icons.checklist, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RollCallScreen())), highlight: g.help > 0),
        const SizedBox(width: 8),
        _ActionTile(tx('公告', 'Notice'), Icons.announcement_outlined, () => showAnnounceSheet(context, g)),
        const SizedBox(width: 8),
        _ActionTile(tx('行程', 'Itinerary'), Icons.event_note_outlined, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ItineraryScreen()))),
      ]),
      const SizedBox(height: Night.space3),
      Text(tx('同意分享的團員會出現在地圖上；長按大頭貼可以傳訊息。按「我迷路了」的人會另外以紅點標出。', 'Members who share appear on the map. Long-press a photo to message them. Anyone who taps "I\'m lost" also shows as a red dot.'), style: Night.caption),
    ]);
  }
}

String _ago(int at) {
  final m = max(0, (DateTime.now().millisecondsSinceEpoch - at) ~/ 60000);
  return m == 0 ? tx('剛剛', 'just now') : tx('$m 分鐘前', '${m}m ago');
}

/// 團員的面板：集合卡片（或最新公告、下一個集合點）、團旗、我迷路了
class _MemberPanel extends StatelessWidget {
  final TourGroup g;
  final GlobalKey<TourMapState> map;
  const _MemberPanel({required this.g, required this.map});

  @override
  Widget build(BuildContext context) {
    final call = g.call;
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = g.stops.where((s) => s.at >= now).firstOrNull;
    final ann = g.announcements.firstOrNull;
    return _Panel(children: [
      Text([tx('你是 ${g.myNo ?? '-'} 號', 'You are No. ${g.myNo ?? '-'}'), if (g.mySub != null) g.subName(g.mySub)].join(' · '), style: Night.caption.copyWith(color: Night.inkMuted)),
      const SizedBox(height: Night.space2),
      if (call != null)
        CallCard(g: g, call: call)
      else ...[
        if (g.rollId != null && g.rollMine == null) ...[
          Text(tx('領隊在點名', 'Roll call'), style: Night.title.copyWith(color: g.tint)),
          const SizedBox(height: Night.space3),
          RollButtons(g: g),
        ] else if (ann != null)
          InkWell(
            onTap: () => showAnnouncements(context, g),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.campaign_outlined, color: g.tint, size: 20),
              const SizedBox(width: 8),
              Expanded(child: TranslatableText(ann.text, compact: true, style: Night.body.copyWith(color: Night.ink), maxLines: 3)),
            ]),
          )
        else
          Text(tx('目前沒有集合', 'No gather call right now'), style: Night.title),
        if (next != null) ...[
          const SizedBox(height: Night.space3),
          Text(tx('下一個集合：${md(next.at, next.tz)} ${hm(next.at, next.tz)} ${next.place}', 'Next: ${md(next.at, next.tz)} ${hm(next.at, next.tz)} ${next.place}'), style: Night.caption.copyWith(color: Night.inkMuted)),
        ],
      ],
      const SizedBox(height: Night.space4),
      Row(children: [
        Expanded(child: NightButton(tx('舉起團旗', 'Raise flag'), kind: NightButtonKind.ghost, onPressed: () => showFlag(context, g))),
        const SizedBox(width: 8),
        Expanded(child: NightButton(g.lostSent ? tx('已通知領隊', 'Leader notified') : tx('我迷路了', 'I\'m lost'), kind: NightButtonKind.danger, onPressed: () => askLost(context, g))),
      ]),
      const SizedBox(height: Night.space2),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ItineraryScreen())), child: Text(tx('行程表', 'Itinerary'))),
        TextButton(onPressed: () => showAnnouncements(context, g), child: Text(tx('公告（${g.announcements.length}）', 'Notices (${g.announcements.length})'))),
      ]),
    ]);
  }
}

// ---------- 公告 ----------

Future<void> showAnnounceSheet(BuildContext context, TourGroup g) {
  final ctl = TextEditingController();
  int? sub;
  var busy = false;
  return showPanel(context, (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(tx('發公告', 'Post a notice'), style: Night.title, textAlign: TextAlign.center),
    const SizedBox(height: Night.space2),
    Text(tx('公告會置頂在團員的畫面，也會用推播送達。團員可以點一下翻譯成自己的語言。', 'Notices are pinned and pushed to members. Members can tap to translate them.'), style: Night.caption, textAlign: TextAlign.center),
    const SizedBox(height: Night.space3),
    TextField(controller: ctl, maxLength: 200, maxLines: 4, minLines: 2, autofocus: true, style: const TextStyle(color: Night.ink), decoration: InputDecoration(hintText: tx('例如：18:30 在飯店大廳集合，遊覽車 3 號車', 'e.g. Meet in the hotel lobby at 18:30'))),
    if (g.subs.isNotEmpty) SubPicker(g: g, value: sub, onChanged: (v) => setS(() => sub = v)),
    const SizedBox(height: Night.space3),
    NightButton(tx('發出公告', 'Post notice'), icon: Icons.send, onPressed: busy ? null : () async {
      setS(() => busy = true);
      final r = await TourService.call('announce', {'text': ctl.text, 'sub': sub});
      if (!ctx.mounted) return;
      setS(() => busy = false);
      if (r['success'] == true) { Navigator.pop(ctx); } else { showGlassToast(ctx, tourError('${r['code']}'), danger: true); }
    }),
    if (g.announcements.isNotEmpty) ...[
      const SizedBox(height: Night.space2),
      NightButton(tx('看之前的公告', 'Earlier notices'), kind: NightButtonKind.text, onPressed: () { Navigator.pop(ctx); showAnnouncements(context, g); }),
    ],
  ]));
}

Future<void> showAnnouncements(BuildContext context, TourGroup g) {
  return showPanel(context, (ctx, _) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(tx('公告', 'Notices'), closeTooltip: tx('關閉', 'Close')),
      const SizedBox(height: Night.space2),
      if (g.announcements.isEmpty) Text(tx('還沒有公告', 'No notices yet'), style: Night.body, textAlign: TextAlign.center),
      Flexible(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: g.announcements.length,
          separatorBuilder: (_, _) => const Divider(color: Night.night600),
          itemBuilder: (_, i) {
            final a = g.announcements[i];
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text([md(a.at, deviceTz), hm(a.at, deviceTz), if (a.sub != null) g.subName(a.sub)].join(' '), style: Night.caption),
              const SizedBox(height: 4),
              TranslatableText(a.text, style: Night.body.copyWith(color: Night.ink)),
            ]);
          },
        ),
      ),
    ]),
  ));
}

/// 選擇對象：全團或某一組
class SubPicker extends StatelessWidget {
  final TourGroup g;
  final int? value;
  final ValueChanged<int?> onChanged;
  const SubPicker({super.key, required this.g, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Night.space2),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        ChoiceChip(
          label: Text(tx('全團', 'Everyone')), selected: value == null, onSelected: (_) => onChanged(null),
          selectedColor: Night.ink, labelStyle: TextStyle(color: value == null ? Night.night900 : Night.ink), backgroundColor: Night.night600,
        ),
        for (var i = 0; i < g.subs.length; i++)
          ChoiceChip(
            label: Text(g.subs[i]), selected: value == i, onSelected: (_) => onChanged(i),
            selectedColor: Night.ink, labelStyle: TextStyle(color: value == i ? Night.night900 : Night.ink), backgroundColor: Night.night600,
          ),
      ]),
    );
  }
}

/// 我的氣泡：沒發過顯示「發一個氣泡」，發過顯示內容；點了編輯
class _BubbleChip extends StatelessWidget {
  final TourGroup g;
  const _BubbleChip({required this.g});
  @override
  Widget build(BuildContext context) {
    final has = g.myBubble.isNotEmpty;
    return Material(
      color: Night.glassFill,
      shape: StadiumBorder(side: BorderSide(color: has ? Night.auroraViolet : Night.glassLine)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => editBubble(context),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(has ? Icons.chat_bubble : Icons.add_comment_outlined, color: has ? Night.auroraViolet : Night.inkMuted, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(has ? g.myBubble : tx('發一個氣泡', 'Post a bubble'),
                style: TextStyle(color: has ? Night.ink : Night.inkMuted, fontSize: 15), overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
  }
}
