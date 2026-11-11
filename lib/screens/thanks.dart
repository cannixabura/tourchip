import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../ui/avatar.dart';
import '../ui/night.dart';
import 'join.dart';

/// 送花給領隊：最後一天起到解散後 3 天，團員可以送一朵花給團主或共同團主，附一句話（只有正面，沒有評分）
Future<void> showThankSheet(BuildContext context, {required String groupName, required List<TourStaff> staff}) async {
  if (staff.isEmpty) return;
  var pick = staff.first;
  final ctl = TextEditingController();
  var busy = false;
  String? error;
  final sent = await showPanel<bool>(context, (ctx, setS) {
    Future<void> send() async {
      if (busy) return;
      setS(() { busy = true; error = null; });
      final r = await TourService.call('thank', {'to': pick.uid, 'text': ctl.text.trim()});
      if (!ctx.mounted) return;
      if (r['success'] == true || r['code'] == 'already') {
        Navigator.pop(ctx, true);
      } else {
        setS(() { busy = false; error = tourError('${r['code']}'); });
      }
    }

    String nameOf(TourStaff s) => s.name.isNotEmpty ? s.name : (s.role == 'host' ? tx('團主', 'Leader') : tx('共同團主', 'Co-leader'));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(tx('送一朵花 🌸', 'Send a flower 🌸'), closeTooltip: tx('關閉', 'Close')),
      Text(tx('謝謝「$groupName」的領隊。對方只會看到花和你寫的話，不會知道是誰送的。', 'Thank the leader of "$groupName". They see the flower and your words, not who sent it.'),
          style: Night.caption, textAlign: TextAlign.center),
      const SizedBox(height: Night.space3),
      if (staff.length > 1)
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          for (final s in staff)
            ChoiceChip(
              selected: s.uid == pick.uid,
              onSelected: (_) => setS(() => pick = s),
              avatar: s.avatar.isNotEmpty ? Avatar(s.avatar, size: 24) : null,
              label: Text(nameOf(s)),
            ),
        ])
      else
        Center(child: Text(nameOf(pick), style: Night.title)),
      const SizedBox(height: Night.space3),
      TextField(
        controller: ctl,
        maxLength: 60,
        minLines: 1,
        maxLines: 3,
        style: const TextStyle(color: Night.ink),
        decoration: InputDecoration(hintText: tx('想說的話（可以不寫）', 'A few words (optional)'), errorText: error),
      ),
      const SizedBox(height: Night.space2),
      NightButton(busy ? tx('送出中…', 'Sending…') : tx('送出', 'Send'), icon: Icons.local_florist_outlined, onPressed: busy ? null : send),
    ]);
  });
  ctl.dispose();
  if (sent == true && context.mounted) showGlassToast(context, tx('花送出了，謝謝你！', 'Flower sent. Thank you!'), icon: Icons.local_florist_outlined);
}

/// 在團裡：還沒送過的領隊
Future<void> thankFromGroup(BuildContext context, TourGroup g) async {
  final me = FirebaseAuth.instance.currentUser?.uid ?? '';
  final staff = g.thankable(me);
  if (staff.isEmpty) {
    showGlassToast(context, tx('你已經送過花了，謝謝你！', 'You already sent flowers. Thank you!'), icon: Icons.local_florist_outlined);
    return;
  }
  await showThankSheet(context, groupName: g.name, staff: staff);
}

/// 首頁：剛解散的團，問一次要不要送花
class EndedThanksCard extends StatelessWidget {
  final EndedGroup ended;
  const EndedThanksCard({super.key, required this.ended});
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(children: [
        const Text('🌸', style: TextStyle(fontSize: 26)),
        const SizedBox(width: 12),
        Expanded(child: Text(tx('「${ended.name}」已經結束了。想謝謝領隊嗎？', '"${ended.name}" has ended. Want to thank your leader?'), style: Night.body.copyWith(color: Night.ink))),
        TextButton(
          onPressed: () async {
            await showThankSheet(context, groupName: ended.name, staff: ended.unsent);
            await TourService.refresh();
          },
          child: Text(tx('送花', 'Send')),
        ),
      ]),
    );
  }
}

/// 領隊的名片與收到的感謝：預設只有自己看；可以開公開名片網頁，挑要公開哪幾則
class LeaderCardScreen extends StatefulWidget {
  const LeaderCardScreen({super.key});
  @override
  State<LeaderCardScreen> createState() => _LeaderCardScreenState();
}

class _LeaderCardScreenState extends State<LeaderCardScreen> {
  LeaderCard? _card;
  bool _busy = false;
  final _intro = TextEditingController();

  @override
  void initState() {
    super.initState();
    _run('my_card');
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _run(String action, [Map<String, dynamic> body = const {}]) async {
    setState(() => _busy = true);
    final r = await TourService.call(action, body);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r['success'] == true) {
        _card = LeaderCard.fromJson(r);
        if (action == 'my_card' || action == 'card_set') _intro.text = _card!.intro;
      }
    });
    if (r['success'] != true) showGlassToast(context, tourError('${r['code']}'), danger: true);
  }

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}/${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final c = _card;
    return Scaffold(
      appBar: AppBar(backgroundColor: Night.night900, foregroundColor: Night.ink, title: Text(tx('我的名片與感謝', 'My card and thanks'), style: Night.title)),
      body: SafeArea(
        child: c == null
            ? const Center(child: CircularProgressIndicator(color: Night.auroraViolet))
            : ListView(padding: const EdgeInsets.all(Night.space4), children: [
                Center(child: Text('🌸 ${c.flowers}', style: const TextStyle(color: Night.ink, fontSize: 40, fontWeight: FontWeight.w700))),
                Center(child: Text(tx('團員送你的花', 'Flowers from your members'), style: Night.caption)),
                const SizedBox(height: Night.space4),
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: c.pub,
                      onChanged: _busy ? null : (v) => _run('card_set', {'pub': v}),
                      title: Text(tx('公開名片網頁', 'Public card page'), style: const TextStyle(color: Night.ink)),
                      subtitle: Text(tx('給旅行社或客人看：你的暱稱、一句介紹、花的數量、你挑選公開的感謝。不會顯示是誰送的。', 'For agencies or guests: your nickname, a short intro, flower count and the thanks you choose. Senders stay anonymous.'), style: Night.caption),
                    ),
                    TextField(
                      controller: _intro,
                      maxLength: 80,
                      style: const TextStyle(color: Night.ink),
                      decoration: InputDecoration(labelText: tx('一句介紹', 'Short intro'), hintText: tx('例如：帶團 10 年，日本、韓國線', 'e.g. 10 years leading tours in Japan and Korea')),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: _busy ? null : () => _run('card_set', {'intro': _intro.text}), child: Text(tx('儲存介紹', 'Save intro'))),
                    ),
                    if (c.pub && c.link != null) ...[
                      SelectableText(c.link!, style: const TextStyle(color: Night.auroraViolet)),
                      const SizedBox(height: Night.space2),
                      Row(children: [
                        Expanded(child: NightButton(tx('複製網址', 'Copy link'), kind: NightButtonKind.ghost, onPressed: () {
                          Clipboard.setData(ClipboardData(text: c.link!));
                          showGlassToast(context, tx('已複製', 'Copied'), icon: Icons.copy_outlined);
                        })),
                        const SizedBox(width: 8),
                        Expanded(child: NightButton(tx('分享', 'Share'), onPressed: () => SharePlus.instance.share(ShareParams(text: c.link!)))),
                      ]),
                    ],
                  ]),
                ),
                const SizedBox(height: Night.space4),
                Text(tx('收到的感謝', 'Thanks received'), style: Night.caption),
                const SizedBox(height: Night.space2),
                if (c.thanks.isEmpty)
                  Text(tx('還沒有。帶團最後一天，團員會收到提醒，可以送你一朵花。', 'None yet. On the last day of a trip, members are reminded they can send you a flower.'), style: Night.body),
                for (final t in c.thanks)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                    decoration: BoxDecoration(color: Night.night700, borderRadius: BorderRadius.circular(Night.radiusMd)),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.text.isEmpty ? '🌸' : '🌸 ${t.text}', style: Night.body.copyWith(color: Night.ink)),
                        const SizedBox(height: 2),
                        Text('${t.group} · ${_date(t.at)}', style: Night.caption),
                      ])),
                      if (t.text.isNotEmpty)
                        Column(children: [
                          Switch(value: t.pub, onChanged: _busy ? null : (v) => _run('thank_pub', {'id': t.id, 'pub': v})),
                          Text(tx('公開', 'Public'), style: Night.caption),
                        ]),
                      IconButton(
                        tooltip: tx('刪除', 'Delete'),
                        icon: const Icon(Icons.delete_outline, color: Night.inkFaint),
                        onPressed: _busy ? null : () async {
                          final ok = await confirmSheet(context, tx('刪除這則感謝？', 'Delete this thank-you?'), action: tx('刪除', 'Delete'), danger: true);
                          if (ok == true) await _run('thank_delete', {'id': t.id});
                        },
                      ),
                    ]),
                  ),
              ]),
      ),
    );
  }
}
