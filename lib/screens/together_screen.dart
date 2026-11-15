import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../translate.dart';
import '../ui/avatar.dart';
import '../ui/night.dart';
import 'group_screen.dart' show SubPicker;
import 'join.dart';
import 'social.dart';

/// 投票・揪伴：團主與共同團主發起投票（自費行程意願、晚餐 A/B…），團員投票、看統計；
/// 所有人（同意分享後）可以揪伴「誰要一起去…」，別人按「我也去」，12 小時後自動消失。
class TogetherScreen extends StatelessWidget {
  const TogetherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TourGroup?>(
      valueListenable: TourService.current,
      builder: (context, g, _) {
        if (g == null) return const SizedBox.shrink();
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Night.night900, foregroundColor: Night.ink,
            title: Text(tx('投票・揪伴', 'Polls · Meetups'), style: Night.title),
          ),
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(Night.space4, Night.space2, Night.space4, Night.space6), children: [
              _Header(
                tx('投票', 'Polls'),
                action: g.isStaff ? tx('發起投票', 'New poll') : null,
                onAction: () => showNewPoll(context, g),
              ),
              if (g.polls.isEmpty)
                _Empty(g.isStaff
                    ? tx('問大家自費行程要不要參加、晚餐吃 A 還是 B，團員按一下就好，你直接看統計。', 'Ask about optional tours or dinner choices. Members tap once; you see the tally.')
                    : tx('領隊發起投票時會出現在這裡。', 'Polls from your leader show up here.'))
              else
                for (final p in g.polls) _PollCard(key: ValueKey('${p.id}${p.mine}${p.closed}'), g: g, p: p),
              const SizedBox(height: Night.space6),
              _Header(tx('揪伴', 'Meetups'), action: tx('揪大家', 'Start one'), onAction: () => showNewJio(context)),
              _Empty(tx('自由活動想找人一起逛街、吃宵夜？發出後同團的人會收到通知，12 小時後自動消失。', 'Looking for company during free time? Your group gets notified. It disappears after 12 hours.')),
              for (final j in g.jios) _JioCard(g: g, j: j),
            ]),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback onAction;
  const _Header(this.title, {required this.action, required this.onAction});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Night.space2),
      child: Row(children: [
        Expanded(child: Text(title, style: Night.title)),
        if (action != null) TextButton.icon(onPressed: onAction, icon: const Icon(Icons.add, size: 18), label: Text(action!)),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: Night.space3), child: Text(text, style: Night.caption));
}

String _ago(int at) {
  final m = max(0, (DateTime.now().millisecondsSinceEpoch - at) ~/ 60000);
  if (m == 0) return tx('剛剛', 'just now');
  if (m < 60) return tx('$m 分鐘前', '${m}m ago');
  final hrs = m ~/ 60;
  return tx('$hrs 小時前', '${hrs}h ago');
}

// ---------- 投票 ----------

class _PollCard extends StatefulWidget {
  final TourGroup g;
  final TourPoll p;
  const _PollCard({super.key, required this.g, required this.p});
  @override
  State<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<_PollCard> {
  late Set<int> _sel = {...?widget.p.mine};
  bool _busy = false;
  bool _editing = false;

  Future<void> _vote(List<int> choice) async {
    setState(() => _busy = true);
    final r = await TourService.call('vote', {'id': widget.p.id, 'choice': choice});
    if (!mounted) return;
    setState(() { _busy = false; _editing = false; });
    if (r['success'] != true) showGlassToast(context, tourError('${r['code']}'), danger: true);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g, p = widget.p;
    final canVote = !g.isStaff && !p.closed && (p.mine == null || _editing);
    final showResult = g.isStaff || p.closed || (p.mine != null && !_editing);
    final most = p.counts.isEmpty ? 0 : p.counts.reduce(max);
    return Container(
      margin: const EdgeInsets.only(bottom: Night.space3),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: Night.night700, borderRadius: BorderRadius.circular(Night.radiusMd),
        border: Border.all(color: !g.isStaff && !p.closed && p.mine == null ? g.tint : Colors.transparent),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TranslatableText(p.q, style: Night.body.copyWith(color: Night.ink, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text([
                _ago(p.at),
                if (p.sub != null) g.subName(p.sub),
                if (p.multi) tx('可複選', 'Multiple choice'),
                if (p.closed) tx('已結束', 'Closed'),
              ].join(' · '), style: Night.caption),
            ]),
          ),
          if (g.isStaff)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, color: Night.inkMuted),
              color: Night.night700,
              onSelected: (v) async {
                if (v == 'delete') {
                  final ok = await confirmSheet(context, tx('刪除這個投票和所有人的選擇？', 'Delete this poll and all answers?'), action: tx('刪除', 'Delete'), danger: true);
                  if (ok != true) return;
                }
                final r = await TourService.call(v == 'delete' ? 'poll_delete' : 'poll_close', {'id': p.id, if (v == 'open') 'open': true});
                if (r['success'] != true && context.mounted) showGlassToast(context, tourError('${r['code']}'), danger: true);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: p.closed ? 'open' : 'close', child: Text(p.closed ? tx('重新開放', 'Reopen') : tx('結束投票', 'Close poll'), style: const TextStyle(color: Night.ink))),
                PopupMenuItem(value: 'delete', child: Text(tx('刪除', 'Delete'), style: const TextStyle(color: Night.danger))),
              ],
            )
          else
            const SizedBox(width: 8),
        ]),
        const SizedBox(height: Night.space2),
        for (var i = 0; i < p.opts.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 6),
            child: canVote
                ? _OptionChoice(
                    text: p.opts[i], multi: p.multi, selected: _sel.contains(i), tint: g.tint,
                    onTap: _busy
                        ? null
                        : () {
                            if (p.multi) {
                              setState(() => _sel.contains(i) ? _sel.remove(i) : _sel.add(i));
                            } else {
                              setState(() => _sel = {i});
                              _vote([i]);
                            }
                          },
                  )
                : _OptionResult(
                    text: p.opts[i], count: p.count(i), voters: p.voters, mine: p.mine?.contains(i) ?? false, top: most > 0 && p.count(i) == most, tint: g.tint,
                    onTap: g.isStaff && i < p.who.length && p.who[i].isNotEmpty ? () => _showWho(context, g, p, i) : null,
                  ),
          ),
        if (canVote && p.multi)
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 4),
            child: NightButton(tx('送出', 'Submit'), onPressed: _busy || _sel.isEmpty ? null : () => _vote(_sel.toList()..sort())),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 8, top: 2),
          child: Row(children: [
            Expanded(
              child: Text(
                g.isStaff
                    ? tx('${p.voters}／${p.total} 人已投', '${p.voters}/${p.total} voted') + (p.who.any((w) => w.isNotEmpty) ? tx('，點選項看是誰', ' · tap an option to see who') : '')
                    : showResult
                        ? tx('${p.voters} 人已投', '${p.voters} voted')
                        : tx('選好就送出，結果投完才看得到', 'Vote to see the results'),
                style: Night.caption,
              ),
            ),
            if (showResult && !g.isStaff && !p.closed && p.mine != null)
              TextButton(onPressed: () => setState(() { _editing = true; _sel = {...?p.mine}; }), child: Text(tx('改選', 'Change'))),
          ]),
        ),
      ]),
    );
  }
}

class _OptionChoice extends StatelessWidget {
  final String text;
  final bool multi, selected;
  final Color tint;
  final VoidCallback? onTap;
  const _OptionChoice({required this.text, required this.multi, required this.selected, required this.tint, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? tint.withValues(alpha: 0.18) : Night.night600,
      borderRadius: BorderRadius.circular(Night.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Night.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(children: [
            Icon(
              multi ? (selected ? Icons.check_box : Icons.check_box_outline_blank) : (selected ? Icons.radio_button_checked : Icons.radio_button_off),
              color: selected ? tint : Night.inkMuted, size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: TranslatableText(text, compact: true, style: const TextStyle(color: Night.ink, fontSize: 15))),
          ]),
        ),
      ),
    );
  }
}

class _OptionResult extends StatelessWidget {
  final String text;
  final int count, voters;
  final bool mine, top;
  final Color tint;
  final VoidCallback? onTap;
  const _OptionResult({required this.text, required this.count, required this.voters, required this.mine, required this.top, required this.tint, this.onTap});
  @override
  Widget build(BuildContext context) {
    final f = voters == 0 ? 0.0 : count / voters;
    return InkWell(
      borderRadius: BorderRadius.circular(Night.radiusSm),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Night.radiusSm),
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(color: Night.night600)),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft, widthFactor: f,
              child: ColoredBox(color: (top ? tint : Night.inkFaint).withValues(alpha: top ? 0.45 : 0.25)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              if (mine) ...[Icon(Icons.check_circle, size: 18, color: tint), const SizedBox(width: 8)],
              Expanded(child: TranslatableText(text, compact: true, style: TextStyle(color: Night.ink, fontSize: 15, fontWeight: top ? FontWeight.w600 : FontWeight.w400))),
              Text(tx('$count 票', '$count'), style: const TextStyle(color: Night.ink, fontSize: 14, fontWeight: FontWeight.w600)),
              if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: Night.inkMuted),
            ]),
          ),
        ]),
      ),
    );
  }
}

void _showWho(BuildContext context, TourGroup g, TourPoll p, int i) {
  final names = p.who[i].map(g.whoLabel).toList();
  showPanel<void>(context, (ctx, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(p.opts[i], closeTooltip: tx('關閉', 'Close')),
        const SizedBox(height: Night.space2),
        Text(tx('${names.length} 人', '${names.length} people'), style: Night.caption, textAlign: TextAlign.center),
        const SizedBox(height: Night.space3),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
          child: SingleChildScrollView(
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final n in names) Chip(label: Text(n, style: const TextStyle(color: Night.ink)), backgroundColor: Night.night600, side: BorderSide.none),
            ]),
          ),
        ),
      ]));
}

/// 發起投票：問題、2–6 個選項、可不可以複選、全團或某一組
Future<void> showNewPoll(BuildContext context, TourGroup g) {
  final q = TextEditingController();
  final opts = [TextEditingController(), TextEditingController()];
  var multi = false;
  int? sub;
  var busy = false;
  return showPanel<void>(context, (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(tx('發起投票', 'New poll'), closeTooltip: tx('關閉', 'Close')),
        const SizedBox(height: Night.space2),
        TextField(controller: q, maxLength: 60, autofocus: true, style: const TextStyle(color: Night.ink),
            decoration: InputDecoration(hintText: tx('例如：明天要不要參加嵐山自費行程（¥3000）？', 'e.g. Join the optional Arashiyama tour tomorrow (¥3000)?'))),
        for (var i = 0; i < opts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: TextField(
              controller: opts[i], maxLength: 30, style: const TextStyle(color: Night.ink),
              decoration: InputDecoration(
                hintText: i == 0 ? tx('選項 1，例如：要', 'Option 1, e.g. Yes') : i == 1 ? tx('選項 2，例如：不要', 'Option 2, e.g. No') : tx('選項 ${i + 1}', 'Option ${i + 1}'),
                counterText: '',
                suffixIcon: opts.length > 2 ? IconButton(icon: const Icon(Icons.close, size: 18, color: Night.inkMuted), onPressed: () => setS(() => opts.removeAt(i))) : null,
              ),
            ),
          ),
        if (opts.length < 6)
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setS(() => opts.add(TextEditingController())), icon: const Icon(Icons.add, size: 18), label: Text(tx('加一個選項', 'Add option')))),
        SwitchListTile(
          contentPadding: EdgeInsets.zero, value: multi, onChanged: (v) => setS(() => multi = v),
          title: Text(tx('可以複選', 'Allow multiple choices'), style: const TextStyle(color: Night.ink)),
        ),
        if (g.subs.isNotEmpty) SubPicker(g: g, value: sub, onChanged: (v) => setS(() => sub = v)),
        const SizedBox(height: Night.space3),
        Text(tx('團員會收到通知。你看得到每個人選了什麼，團員只看到票數。', 'Members get notified. You see who chose what; members only see the totals.'), style: Night.caption, textAlign: TextAlign.center),
        const SizedBox(height: Night.space3),
        NightButton(tx('發出投票', 'Send poll'), icon: Icons.send, onPressed: busy ? null : () async {
          setS(() => busy = true);
          final r = await TourService.call('poll_new', {'q': q.text, 'opts': [for (final o in opts) o.text], 'multi': multi, 'sub': sub});
          if (!ctx.mounted) return;
          setS(() => busy = false);
          if (r['success'] == true) {
            Navigator.pop(ctx);
          } else {
            showGlassToast(ctx, r['code'] == 'bad_request' ? tx('請填 2 到 6 個不一樣的選項。', 'Add 2–6 different options.') : tourError('${r['code']}'), danger: true);
          }
        }),
      ]));
}

// ---------- 揪伴 ----------

class _JioCard extends StatelessWidget {
  final TourGroup g;
  final TourJio j;
  const _JioCard({required this.g, required this.j});

  @override
  Widget build(BuildContext context) {
    final who = g.names[j.by];
    final me = FirebaseAuth.instance.currentUser?.uid;
    final going = [...j.going.where((u) => u == me), ...j.going.where((u) => u != me)].map((u) {
      if (u == me) return tx('你', 'You');
      final w = g.names[u];
      if (w != null && w.name.isNotEmpty) return w.name;
      final no = w?.no ?? '?';
      return tx('$no 號', 'No. $no');
    }).toList();
    final shown = going.take(3).join(tx('、', ', '));
    final names = j.count > min(3, going.length) ? tx('$shown 等 ${j.count} 人', '$shown and others (${j.count})') : shown;
    return Container(
      margin: const EdgeInsets.only(bottom: Night.space3),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(color: Night.night700, borderRadius: BorderRadius.circular(Night.radiusMd)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Avatar(who?.avatar ?? '', size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${g.whoLabel(j.by)} · ${_ago(j.at)}', style: Night.caption, overflow: TextOverflow.ellipsis),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Night.inkMuted),
            color: Night.night700,
            onSelected: (v) => _more(context, v),
            itemBuilder: (_) => [
              if (j.mine || g.isStaff) PopupMenuItem(value: 'delete', child: Text(tx('刪除', 'Delete'), style: const TextStyle(color: Night.danger))),
              if (!j.mine) ...[
                PopupMenuItem(value: 'report', child: Text(tx('檢舉', 'Report'), style: const TextStyle(color: Night.ink))),
                PopupMenuItem(value: 'block', child: Text(tx('封鎖', 'Block'), style: const TextStyle(color: Night.ink))),
              ],
            ],
          ),
        ]),
        const SizedBox(height: Night.space2),
        Padding(padding: const EdgeInsets.only(right: 8), child: TranslatableText(j.text, style: const TextStyle(color: Night.ink, fontSize: 17, height: 1.4))),
        const SizedBox(height: Night.space2),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(children: [
            Expanded(
              child: Text(
                j.count == 0
                    ? tx('還沒有人', 'No one yet')
                    : going.isEmpty
                        ? tx('${j.count} 人也要去', '${j.count} going')
                        : tx('$names 也要去', '$names going'),
                style: Night.caption.copyWith(color: j.count > 0 ? g.tint : Night.inkFaint),
              ),
            ),
            if (!j.mine)
              j.joined
                  ? TextButton(onPressed: () => _join(context, false), child: Text(tx('不去了', 'Not going')))
                  : FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: g.tint, foregroundColor: Night.night900, visualDensity: VisualDensity.compact),
                      onPressed: () => _join(context, true), icon: const Icon(Icons.front_hand_outlined, size: 18), label: Text(tx('我也去', "I'm in")),
                    ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _join(BuildContext context, bool on) async {
    if (!await ensureConsent(context) || !context.mounted) return;
    final r = await TourService.call('jio_join', {'id': j.id, 'on': on});
    if (r['success'] != true && context.mounted) showGlassToast(context, tourError('${r['code']}'), danger: true);
  }

  Future<void> _more(BuildContext context, String v) async {
    if (v == 'delete') {
      final r = await TourService.call('jio_delete', {'id': j.id});
      if (r['success'] != true && context.mounted) showGlassToast(context, tourError('${r['code']}'), danger: true);
    } else if (v == 'report') {
      final r = await TourService.call('report', {'uid': j.by, 'reason': 'jio: ${j.text}'});
      if (context.mounted) showGlassToast(context, r['success'] == true ? tx('已收到檢舉，我們會盡快處理', 'Report received. We will review it.') : tourError('${r['code']}'), icon: Icons.flag_outlined);
    } else if (v == 'block') {
      final ok = await confirmSheet(context, tx('封鎖後你看不到他的揪伴、氣泡和訊息，他不會知道。', "You won't see their meetups, bubble or messages. They won't be told."), action: tx('封鎖', 'Block'), danger: true);
      if (ok != true) return;
      final r = await TourService.call('block', {'uid': j.by, 'on': true});
      if (context.mounted) showGlassToast(context, r['success'] == true ? tx('已封鎖', 'Blocked') : tourError('${r['code']}'), icon: Icons.block);
    }
  }
}

/// 揪大家：最多 40 字；要先同意（已滿 18 歲或家長／監護人同意）
Future<void> showNewJio(BuildContext context) async {
  if (!await ensureConsent(context) || !context.mounted) return;
  final ctl = TextEditingController();
  var busy = false;
  await showPanel<void>(context, (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(tx('揪大家', 'Start a meetup'), closeTooltip: tx('關閉', 'Close')),
        const SizedBox(height: Night.space2),
        Text(tx('同團的人會收到通知，按「我也去」你就知道誰要來。12 小時後自動消失。', 'Your group gets notified. You will see who taps "I\'m in". It disappears after 12 hours.'), style: Night.caption, textAlign: TextAlign.center),
        const SizedBox(height: Night.space3),
        TextField(controller: ctl, maxLength: 40, autofocus: true, minLines: 1, maxLines: 2, style: const TextStyle(color: Night.ink, fontSize: 17),
            decoration: InputDecoration(hintText: tx('例如：誰要一起去逛唐吉訶德？19:00 大廳見', 'e.g. Anyone up for Don Quijote? Lobby at 19:00'))),
        const SizedBox(height: Night.space3),
        NightButton(tx('發出', 'Post'), icon: Icons.campaign_outlined, onPressed: busy ? null : () async {
          setS(() => busy = true);
          final r = await TourService.call('jio_new', {'text': ctl.text});
          if (!ctx.mounted) return;
          setS(() => busy = false);
          if (r['success'] == true) {
            Navigator.pop(ctx);
          } else {
            showGlassToast(ctx, r['code'] == 'too_many' ? tx('你同時最多揪 3 個，先刪掉一個吧。', 'You can have up to 3 at a time. Delete one first.') : tourError('${r['code']}'), danger: true);
          }
        }),
      ]));
}

/// 面板上的入口文字：投票・揪伴（有沒投的投票、新的揪伴時顯示數字）
String togetherLabel(TourGroup g) {
  final n = g.pollsToVote.length + g.jios.where((j) => !j.mine && !j.joined).length;
  return n > 0 ? tx('投票・揪伴（$n）', 'Polls · Meetups ($n)') : tx('投票・揪伴', 'Polls · Meetups');
}

