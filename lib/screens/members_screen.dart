import 'package:flutter/material.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../ui/avatar.dart';
import '../ui/night.dart';
import 'join.dart';

/// 團員名單（團主、共同團主）：備註、分組、設為共同團主、交棒、移除。
/// 備註只有團主與共同團主看得到。
class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TourGroup?>(
      valueListenable: TourService.current,
      builder: (context, g, _) {
        if (g == null) return const SizedBox.shrink();
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Night.night900, foregroundColor: Night.ink,
            title: Text(tx('團員名單 · ${g.count} 人', 'Members · ${g.count}'), style: Night.title),
            actions: [if (g.isStaff) TextButton(onPressed: () => _editSubs(context, g), child: Text(tx('分組', 'Sub-groups')))],
          ),
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(Night.space4), children: [
              Text(tx('領隊', 'Leaders'), style: Night.caption),
              const SizedBox(height: Night.space2),
              for (final s in g.staff)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: s.avatar.isNotEmpty ? Avatar(s.avatar, size: 40, ring: g.tint) : CircleAvatar(backgroundColor: g.tint.withValues(alpha: 0.3), child: Icon(s.role == 'host' ? Icons.flag : Icons.flag_outlined, color: Night.ink, size: 18)),
                  title: Text(s.name.isEmpty ? (s.role == 'host' ? tx('團主', 'Leader') : tx('共同團主', 'Co-leader')) : s.name, style: const TextStyle(color: Night.ink)),
                  subtitle: Text(s.role == 'host' ? tx('團主', 'Leader') : tx('共同團主', 'Co-leader'), style: Night.caption),
                  trailing: g.isHost && s.role == 'cohost'
                      ? TextButton(onPressed: () => TourService.call('cohost_remove', {'uid': s.uid}), child: Text(tx('改回團員', 'Make member')))
                      : null,
                ),
              const SizedBox(height: Night.space4),
              Text(tx('團員', 'Members'), style: Night.caption),
              const SizedBox(height: Night.space2),
              if (g.members.isEmpty) Text(tx('還沒有人入團。請團員掃描入團 QR code。', 'No one has joined yet. Ask members to scan the QR code.'), style: Night.body),
              for (final m in g.members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _NoAvatar(m.no, m.avatar),
                  title: Text(m.label.isEmpty ? tx('${m.no} 號', 'No. ${m.no}') : m.label, style: const TextStyle(color: Night.ink)),
                  subtitle: Text(m.sub == null ? tx('未分組', 'No sub-group') : g.subName(m.sub), style: Night.caption),
                  trailing: const Icon(Icons.chevron_right, color: Night.inkFaint),
                  onTap: () => _memberMenu(context, g, m),
                ),
            ]),
          ),
        );
      },
    );
  }

  void _memberMenu(BuildContext context, TourGroup g, TourMember m) {
    showPanel(context, (ctx, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tx('${m.no} 號 ${m.label}', 'No. ${m.no} ${m.label}'), style: Night.title, textAlign: TextAlign.center),
      const SizedBox(height: Night.space4),
      NightButton(tx('寫備註（例如姓名、房號）', 'Add a note (name, room)'), kind: NightButtonKind.ghost, icon: Icons.edit_outlined, onPressed: () { Navigator.pop(ctx); _editNote(context, m); }),
      if (g.subs.isNotEmpty) ...[
        const SizedBox(height: Night.space2),
        NightButton(tx('換分組', 'Change sub-group'), kind: NightButtonKind.ghost, icon: Icons.directions_bus_outlined, onPressed: () { Navigator.pop(ctx); _assign(context, g, m); }),
      ],
      if (g.isHost) ...[
        const SizedBox(height: Night.space2),
        NightButton(tx('設為共同團主（導遊、副領隊）', 'Make co-leader (guide)'), kind: NightButtonKind.ghost, icon: Icons.flag_outlined, onPressed: () async {
          Navigator.pop(ctx);
          final r = await TourService.call('cohost_add', {'uid': m.uid});
          if (r['success'] != true && context.mounted) showGlassToast(context, tourError('${r['code']}'), danger: true);
        }),
        const SizedBox(height: Night.space2),
        NightButton(tx('交棒：讓他當團主', 'Hand over leadership'), kind: NightButtonKind.ghost, icon: Icons.swap_horiz, onPressed: () async {
          Navigator.pop(ctx);
          final ok = await confirmSheet(context, tx('把團主交給 ${m.no} 號？你會變成共同團主。', 'Make No. ${m.no} the leader? You become a co-leader.'), action: tx('交棒', 'Hand over'));
          if (ok == true) await TourService.call('handoff', {'uid': m.uid});
        }),
      ],
      const SizedBox(height: Night.space2),
      NightButton(tx('移出這一團', 'Remove from group'), kind: NightButtonKind.danger, icon: Icons.person_remove_outlined, onPressed: () async {
        Navigator.pop(ctx);
        final ok = await confirmSheet(context, tx('把 ${m.no} 號移出這一團？', 'Remove No. ${m.no}?'), action: tx('移出', 'Remove'), danger: true);
        if (ok == true) await TourService.call('kick', {'uid': m.uid});
      }),
    ]));
  }

  void _editNote(BuildContext context, TourMember m) {
    final ctl = TextEditingController(text: m.note);
    showPanel(context, (ctx, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tx('備註', 'Note'), style: Night.title, textAlign: TextAlign.center),
      Text(tx('只有團主與共同團主看得到', 'Only leaders can see this'), style: Night.caption, textAlign: TextAlign.center),
      const SizedBox(height: Night.space3),
      TextField(controller: ctl, maxLength: 20, autofocus: true, style: const TextStyle(color: Night.ink), decoration: InputDecoration(hintText: tx('例如：王小明 302 房', 'e.g. Wang, room 302'))),
      NightButton(tx('儲存', 'Save'), onPressed: () async {
        final r = await TourService.call('note', {'uid': m.uid, 'note': ctl.text});
        if (!ctx.mounted) return;
        if (r['success'] == true) { Navigator.pop(ctx); } else { showGlassToast(ctx, tourError('${r['code']}'), danger: true); }
      }),
    ]));
  }

  void _assign(BuildContext context, TourGroup g, TourMember m) {
    showPanel(context, (ctx, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tx('${m.no} 號的分組', 'Sub-group for No. ${m.no}'), style: Night.title, textAlign: TextAlign.center),
      const SizedBox(height: Night.space3),
      for (var i = -1; i < g.subs.length; i++)
        ListTile(
          title: Text(i < 0 ? tx('未分組', 'None') : g.subs[i], style: const TextStyle(color: Night.ink)),
          trailing: (m.sub ?? -1) == i ? const Icon(Icons.check, color: Night.auroraViolet) : null,
          onTap: () { Navigator.pop(ctx); TourService.call('assign', {'uid': m.uid, 'sub': i < 0 ? null : i}); },
        ),
    ]));
  }

  void _editSubs(BuildContext context, TourGroup g) {
    final ctls = [for (final s in g.subs) TextEditingController(text: s)];
    showPanel(context, (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tx('分組', 'Sub-groups'), style: Night.title, textAlign: TextAlign.center),
      Text(tx('最多 6 組。刪掉一組時，那組的人會變成未分組。', 'Up to 6. Removing one moves its members to "none".'), style: Night.caption, textAlign: TextAlign.center),
      const SizedBox(height: Night.space3),
      for (var i = 0; i < ctls.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: TextField(controller: ctls[i], maxLength: 10, style: const TextStyle(color: Night.ink))),
            IconButton(tooltip: tx('刪除', 'Remove'), icon: const Icon(Icons.close, color: Night.inkMuted), onPressed: () => setS(() => ctls.removeAt(i))),
          ]),
        ),
      if (ctls.length < 6)
        NightButton(tx('新增分組', 'Add sub-group'), kind: NightButtonKind.text, icon: Icons.add, onPressed: () => setS(() => ctls.add(TextEditingController(text: tx('${ctls.length + 1} 號車', 'Bus ${ctls.length + 1}'))))),
      const SizedBox(height: Night.space2),
      NightButton(tx('儲存', 'Save'), onPressed: () async {
        final r = await TourService.call('subs', {'subs': [for (final c in ctls) c.text]});
        if (!ctx.mounted) return;
        if (r['success'] == true) { Navigator.pop(ctx); } else { showGlassToast(ctx, tourError('${r['code']}'), danger: true); }
      }),
    ]));
  }
}

/// 團員：有大頭貼就顯示照片，右下角疊團號；沒有就只顯示團號
class _NoAvatar extends StatelessWidget {
  final int no;
  final String url;
  const _NoAvatar(this.no, this.url);
  @override
  Widget build(BuildContext context) {
    final badge = Text('$no', style: const TextStyle(color: Night.ink, fontWeight: FontWeight.w600));
    if (url.isEmpty) return CircleAvatar(backgroundColor: Night.night600, child: badge);
    return SizedBox(width: 44, height: 44, child: Stack(clipBehavior: Clip.none, children: [
      Avatar(url, size: 40, ring: Night.night600),
      Positioned(right: -4, bottom: -4, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: Night.night600, borderRadius: BorderRadius.circular(99), border: Border.all(color: Night.night900, width: 1.5)),
        child: Text('$no', style: const TextStyle(color: Night.ink, fontSize: 11, fontWeight: FontWeight.w600)),
      )),
    ]));
  }
}
