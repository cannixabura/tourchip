import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../translate.dart';
import '../ui/avatar.dart';
import '../ui/night.dart';
import 'join.dart';

/// 同團互相看得到：同意分享、氣泡、私訊、封鎖、檢舉

// ---------- 同意分享 ----------

/// 第一次在團裡：說明「同團的人互相看得到」，勾選「已滿 18 歲或已取得家長／監護人同意」才開始分享。
/// 回傳 true 表示同意並開始分享。
Future<bool> askShareConsent(BuildContext context) async {
  var agreed = false, busy = false;
  final ok = await showPanel<bool>(context, (ctx, setS) {
    Widget line(IconData i, String t) => Padding(
          padding: const EdgeInsets.only(top: Night.space2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, color: Night.auroraBlue, size: 20),
            const SizedBox(width: Night.space3),
            Expanded(child: Text(t, style: Night.body)),
          ]),
        );
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tx('和團員互相看得到', 'See each other on the map'), style: Night.title, textAlign: TextAlign.center),
      const SizedBox(height: Night.space2),
      line(Icons.people_alt_outlined, tx('同一團的人（含領隊）會在 3D 地圖上看到你的大頭貼和位置，你也看得到他們。', 'Everyone in your group, including leaders, sees your photo and location on the 3D map, and you see theirs.')),
      line(Icons.lock_outline, tx('只在 App 開著時更新；不在團裡的人看不到。退團或團解散，位置就刪除。', 'Updated only while the app is open. People outside the group never see it. Deleted when you leave or the group ends.')),
      line(Icons.chat_bubble_outline, tx('可以發氣泡、長按地圖上的人傳訊息。', 'Post a bubble, or long-press someone on the map to message them.')),
      line(Icons.toggle_off_outlined, tx('隨時可以在設定關掉分享。', 'Turn sharing off any time in Settings.')),
      const SizedBox(height: Night.space4),
      InkWell(
        borderRadius: BorderRadius.circular(Night.radiusSm),
        onTap: () => setS(() => agreed = !agreed),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Night.space2),
          child: Row(children: [
            Checkbox(value: agreed, onChanged: (v) => setS(() => agreed = v == true), activeColor: Night.deepViolet),
            Expanded(child: Text(tx('我已滿 18 歲，或已取得家長／監護人同意', "I'm 18 or older, or my parent/guardian agrees"), style: const TextStyle(color: Night.ink, fontSize: 15))),
          ]),
        ),
      ),
      const SizedBox(height: Night.space3),
      NightButton(busy ? tx('處理中…', 'One moment…') : tx('開始分享', 'Start sharing'), onPressed: !agreed || busy ? null : () async {
        setS(() => busy = true);
        final r = await TourService.setShare(true, consent: true);
        if (!ctx.mounted) return;
        if (r['success'] == true) {
          Navigator.pop(ctx, true);
        } else {
          setS(() => busy = false);
          showGlassToast(ctx, tourError('${r['code']}'), danger: true);
        }
      }),
      const SizedBox(height: Night.space2),
      NightButton(tx('先不要', 'Not now'), kind: NightButtonKind.text, onPressed: busy ? null : () => Navigator.pop(ctx, false)),
    ]);
  });
  return ok == true;
}

/// 進團時問一次（按過「先不要」的團不再主動問）
Future<void> maybeAskConsent(BuildContext context, TourGroup g) async {
  if (g.shareConsent) return;
  final key = 'consent_asked_${g.code}';
  try {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(key) == true) return;
    await p.setBool(key, true);
  } catch (_) {}
  if (context.mounted) await askShareConsent(context);
}

/// 要用到同意才能用的功能（氣泡、私訊）之前
Future<bool> ensureConsent(BuildContext context) async {
  final g = TourService.current.value;
  if (g == null) return false;
  if (g.shareConsent) return true;
  return askShareConsent(context);
}

// ---------- 氣泡 ----------

/// 發一個氣泡（最多 20 字），同團的人在地圖上看得到；清空就收起來
Future<void> editBubble(BuildContext context) async {
  if (!await ensureConsent(context) || !context.mounted) return;
  final g = TourService.current.value;
  final ctl = TextEditingController(text: g?.myBubble ?? '');
  var busy = false;
  await showPanel<void>(context, (ctx, setS) {
    Future<void> send(String text) async {
      setS(() => busy = true);
      final r = await TourService.call('bubble', {'text': text});
      if (!ctx.mounted) return;
      setS(() => busy = false);
      if (r['success'] == true) {
        Navigator.pop(ctx);
      } else {
        showGlassToast(ctx, tourError('${r['code']}'), danger: true);
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tx('發一個氣泡', 'Post a bubble'), style: Night.title, textAlign: TextAlign.center),
      const SizedBox(height: Night.space2),
      Text(tx('同團的人會在地圖上你的大頭貼上方看到。', 'Your group sees it above your photo on the map.'), style: Night.caption, textAlign: TextAlign.center),
      const SizedBox(height: Night.space4),
      TextField(
        controller: ctl, maxLength: 20, autofocus: true,
        style: const TextStyle(color: Night.ink, fontSize: 17),
        decoration: InputDecoration(hintText: tx('例如：在找廁所、買到珍奶了', 'e.g. Looking for a restroom')),
        onSubmitted: busy ? null : (t) => send(t),
      ),
      const SizedBox(height: Night.space3),
      Row(children: [
        if ((g?.myBubble ?? '').isNotEmpty) ...[
          Expanded(child: NightButton(tx('收起氣泡', 'Remove'), kind: NightButtonKind.ghost, onPressed: busy ? null : () => send(''))),
          const SizedBox(width: Night.space3),
        ],
        Expanded(child: NightButton(tx('發出', 'Post'), onPressed: busy ? null : () => send(ctl.text))),
      ]),
    ]);
  });
}

// ---------- 點地圖上的人 ----------

/// 點一下地圖上的人：大頭貼、團號、氣泡（可以翻譯），下面「傳訊息」
Future<void> showPerson(BuildContext context, TourPerson p) async {
  final me = p.uid == FirebaseAuth.instance.currentUser?.uid;
  final g = TourService.current.value;
  await showPanel<void>(context, (ctx, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Avatar(p.avatar, size: 64)),
        const SizedBox(height: Night.space2),
        Text(g?.whoLabel(p.uid) ?? p.name, style: Night.title, textAlign: TextAlign.center),
        if (p.bubble.isNotEmpty) ...[
          const SizedBox(height: Night.space3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Night.night600, borderRadius: BorderRadius.circular(16)),
            child: TranslatableText(p.bubble, textAlign: TextAlign.center, style: const TextStyle(color: Night.ink, fontSize: 17, height: 1.4)),
          ),
        ],
        const SizedBox(height: Night.space4),
        if (me)
          NightButton(tx('發一個氣泡', 'Post a bubble'), icon: Icons.chat_bubble_outline, onPressed: () { Navigator.pop(ctx); editBubble(context); })
        else
          NightButton(tx('傳訊息', 'Send a message'), icon: Icons.send, onPressed: () { Navigator.pop(ctx); openChat(context, p.uid); }),
      ]));
}

/// 聊天上方：對方的氣泡
class _BubbleLine extends StatelessWidget {
  final String text;
  const _BubbleLine(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Night.space2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.chat_bubble, size: 16, color: Night.auroraViolet)),
          const SizedBox(width: Night.space2),
          Expanded(child: TranslatableText(text, compact: true, style: Night.body.copyWith(color: Night.ink))),
        ]),
      );
}

// ---------- 私訊 ----------

/// 和某個人的對話：上面是最近的訊息，下面輸入；底下可以封鎖、檢舉
Future<void> openChat(BuildContext context, String uid) async {
  if (!await ensureConsent(context) || !context.mounted) return;
  await markSeen();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Night.space4),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
            child: SolidCard(padding: const EdgeInsets.all(Night.space4), child: _Chat(uid: uid)),
          ),
        ),
      ),
    ),
  );
  await markSeen();
}

class _Chat extends StatefulWidget {
  final String uid;
  const _Chat({required this.uid});
  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final _ctl = TextEditingController();
  bool _busy = false;

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final r = await TourService.call('msg', {'to': widget.uid, 'text': text});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['success'] == true) {
      _ctl.clear();
    } else {
      showGlassToast(context, tourError('${r['code']}'), danger: true);
    }
  }

  Future<void> _more(TourGroup g) async {
    final blocked = g.blocked.contains(widget.uid);
    await showPanel<void>(context, (ctx, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(g.whoLabel(widget.uid), style: Night.title, textAlign: TextAlign.center),
      const SizedBox(height: Night.space4),
      NightButton(blocked ? tx('解除封鎖', 'Unblock') : tx('封鎖', 'Block'), kind: NightButtonKind.ghost, icon: Icons.block, onPressed: () async {
        Navigator.pop(ctx);
        final r = await TourService.call('block', {'uid': widget.uid, 'on': !blocked});
        if (mounted) showGlassToast(context, r['success'] == true ? (blocked ? tx('已解除封鎖', 'Unblocked') : tx('已封鎖，你不會再收到他的訊息與氣泡', "Blocked. You won't see their messages or bubble.")) : tourError('${r['code']}'), icon: Icons.block);
      }),
      const SizedBox(height: Night.space2),
      NightButton(tx('檢舉', 'Report'), kind: NightButtonKind.danger, icon: Icons.flag_outlined, onPressed: () async {
        Navigator.pop(ctx);
        final r = await TourService.call('report', {'uid': widget.uid, 'reason': 'chat'});
        if (mounted) showGlassToast(context, r['success'] == true ? tx('已收到檢舉，我們會盡快處理', "Thanks. We'll review it soon.") : tourError('${r['code']}'), icon: Icons.flag_outlined);
      }),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TourGroup?>(
      valueListenable: TourService.current,
      builder: (context, g, _) {
        if (g == null) return const SizedBox.shrink();
        final who = g.names[widget.uid];
        final msgs = g.messages.where((m) => m.other == widget.uid).toList();
        final gone = who == null;
        final bubble = g.people.where((p) => p.uid == widget.uid).firstOrNull?.bubble ?? '';
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Avatar(who?.avatar ?? '', size: 40),
            const SizedBox(width: Night.space3),
            Expanded(child: Text(g.whoLabel(widget.uid), style: Night.title.copyWith(fontSize: 18), overflow: TextOverflow.ellipsis)),
            if (!gone) IconButton(tooltip: tx('封鎖或檢舉', 'Block or report'), icon: const Icon(Icons.more_horiz, color: Night.inkMuted), onPressed: () => _more(g)),
            IconButton(tooltip: tx('關閉', 'Close'), icon: const Icon(Icons.close, color: Night.inkMuted), onPressed: () => Navigator.pop(context)),
          ]),
          if (bubble.isNotEmpty) _BubbleLine(bubble),
          const SizedBox(height: Night.space2),
          Flexible(
            child: msgs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: Night.space6),
                    child: Text(tx('還沒有訊息。打個招呼吧！', 'No messages yet. Say hi!'), style: Night.caption, textAlign: TextAlign.center),
                  )
                : ListView(
                    shrinkWrap: true, reverse: true,
                    children: [
                      for (final m in msgs.reversed)
                        Align(
                          alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            constraints: const BoxConstraints(maxWidth: 260),
                            decoration: BoxDecoration(
                              gradient: m.mine ? Night.deepGradient : null,
                              color: m.mine ? null : Night.night600,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              m.mine
                                  ? Text(m.text, style: const TextStyle(color: Night.ink, fontSize: 15, height: 1.4))
                                  : TranslatableText(m.text, compact: true, style: const TextStyle(color: Night.ink, fontSize: 15, height: 1.4)),
                              const SizedBox(height: 2),
                              Text(_hm(m.at), style: const TextStyle(color: Color(0xB3F3F0FF), fontSize: 10)),
                            ]),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: Night.space3),
          if (gone)
            Text(tx('這個人已經不在團裡了。', 'This person is no longer in the group.'), style: Night.caption, textAlign: TextAlign.center)
          else
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctl, maxLength: 200, minLines: 1, maxLines: 4,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(color: Night.ink, fontSize: 16),
                  decoration: InputDecoration(hintText: tx('傳訊息…', 'Message…'), counterText: ''),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: Night.space2),
              IconButton.filled(
                onPressed: _busy ? null : _send,
                style: IconButton.styleFrom(backgroundColor: Night.deepViolet),
                icon: const Icon(Icons.send, color: Colors.white),
              ),
            ]),
        ]);
      },
    );
  }
}

String _hm(int at) {
  final t = DateTime.fromMillisecondsSinceEpoch(at);
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ---------- 訊息列表與未讀 ----------

const _seenKey = 'msgs_seen_at';
final unreadMsgs = ValueNotifier<int>(0);
int _seenAt = 0;

Future<void> initUnread() async {
  try { _seenAt = (await SharedPreferences.getInstance()).getInt(_seenKey) ?? 0; } catch (_) {}
  TourService.current.addListener(_recount);
  _recount();
}

void _recount() {
  final g = TourService.current.value;
  unreadMsgs.value = g == null ? 0 : g.messages.where((m) => !m.mine && m.at > _seenAt).length;
}

Future<void> markSeen() async {
  final g = TourService.current.value;
  final last = g == null || g.messages.isEmpty ? 0 : g.messages.map((m) => m.at).reduce((a, b) => a > b ? a : b);
  if (last <= _seenAt) return;
  _seenAt = last;
  _recount();
  try { await (await SharedPreferences.getInstance()).setInt(_seenKey, last); } catch (_) {}
}

/// 訊息：和每個人的最新一則；也可以從團員名單找人傳
Future<void> showInbox(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Night.space4),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: SolidCard(
            padding: const EdgeInsets.all(Night.space4),
            child: ValueListenableBuilder<TourGroup?>(
              valueListenable: TourService.current,
              builder: (ctx, g, _) {
                if (g == null) return const SizedBox.shrink();
                final last = <String, TourMsg>{};
                for (final m in g.messages) {
                  last[m.other] = m;
                }
                final threads = last.values.toList()..sort((a, b) => b.at.compareTo(a.at));
                final others = g.names.keys.where((u) => !last.containsKey(u) && u != FirebaseAuth.instance.currentUser?.uid).toList()
                  ..sort((a, b) => (g.names[a]!.no).compareTo(g.names[b]!.no));
                Widget row(String uid, String sub, {bool unread = false}) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Avatar(g.names[uid]?.avatar ?? '', size: 40),
                      title: Text(g.whoLabel(uid), style: TextStyle(color: Night.ink, fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
                      subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Night.caption.copyWith(color: unread ? Night.ink : Night.inkMuted)),
                      trailing: unread ? const CircleAvatar(radius: 5, backgroundColor: Night.knockPink) : null,
                      onTap: () => openChat(ctx, uid),
                    );
                return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SheetTitle(tx('訊息', 'Messages'), closeTooltip: tx('關閉', 'Close')),
                  Flexible(
                    child: ListView(shrinkWrap: true, children: [
                      for (final m in threads) row(m.other, m.mine ? tx('你：${m.text}', 'You: ${m.text}') : m.text, unread: !m.mine && m.at > _seenAt),
                      if (others.isNotEmpty) ...[
                        Padding(padding: const EdgeInsets.only(top: Night.space4, bottom: Night.space1), child: Text(tx('團裡的其他人', 'Others in the group'), style: Night.caption)),
                        for (final u in others) row(u, tx('傳訊息', 'Send a message')),
                      ],
                    ]),
                  ),
                ]);
              },
            ),
          ),
        ),
      ),
    ),
  );
  await markSeen();
}
