import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../ui/night.dart';
import 'join.dart';
import 'pass_screen.dart';

/// 入團 QR code：團員用旅行團 App 或手機相機掃描就能入團。設計稿：團的 QR code
class QrScreen extends StatefulWidget {
  const QrScreen({super.key});
  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // 給大家掃的時候螢幕不要暗掉
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TourGroup?>(
      valueListenable: TourService.current,
      builder: (context, g, _) {
        if (g == null || g.qr == null) {
          return Scaffold(appBar: AppBar(backgroundColor: Night.night900, foregroundColor: Night.ink), body: Center(child: Text(tx('只有領隊看得到入團 QR code', 'Only leaders can see the join QR code'), style: Night.body)));
        }
        final daysLeft = ((g.endsAt - DateTime.now().millisecondsSinceEpoch) / 86400000).ceil();
        Widget stat(String n, String label) => Expanded(child: Column(children: [
              Text(n, style: const TextStyle(color: Night.ink, fontSize: 22, fontWeight: FontWeight.w600)),
              Text(label, style: Night.caption.copyWith(color: Night.inkMuted)),
            ]));
        return Scaffold(
          appBar: AppBar(backgroundColor: Night.night900, foregroundColor: Night.ink, title: Text(tx('入團 QR code', 'Join QR code'), style: Night.title)),
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(Night.space4), children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: g.tint, shape: BoxShape.circle, boxShadow: [BoxShadow(color: g.tint, blurRadius: 10)])),
                const SizedBox(width: 8),
                Flexible(child: Text(g.name, style: Night.title, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: Night.space4),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Night.radiusLg), boxShadow: [BoxShadow(color: g.tint, spreadRadius: 3), BoxShadow(color: g.tint.withValues(alpha: 0.55), blurRadius: 32)]),
                  child: QrImageView(data: g.qr!, size: 240, backgroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: Night.space3),
              if (g.invite != null) ...[
                Center(child: Text(tx('邀請碼', 'Invite code'), style: Night.caption.copyWith(color: Night.inkMuted))),
                Center(child: SelectableText(formatInvite(g.invite!), style: const TextStyle(color: Night.ink, fontSize: 30, letterSpacing: 4, fontWeight: FontWeight.w600))),
              ] else
                Center(child: SelectableText(g.code, style: const TextStyle(color: Night.ink, fontSize: 22, letterSpacing: 4))),
              const SizedBox(height: Night.space2),
              Text(tx('團員用手機相機或旅行團 App 掃描就能入團；已經裝好 App 的人，也可以按「輸入邀請碼入團」輸入上面的數字。', 'Members scan with the camera or TourChip to join. If they already have the app, they can tap "Join with invite code" and enter the number above.'), style: Night.body, textAlign: TextAlign.center),
              const SizedBox(height: Night.space4),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(children: [
                  stat('${g.count}', tx('已入團', 'joined')),
                  stat('${g.limit}', tx('上限', 'limit')),
                  stat(tx('$daysLeft 天', '$daysLeft d'), tx('剩餘', 'left')),
                ]),
              ),
              if (!g.paid && g.isHost) ...[
                const SizedBox(height: Night.space3),
                NightButton(tx('升級到 100 人', 'Upgrade to 100 people'), kind: NightButtonKind.text, icon: Icons.workspace_premium_outlined,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PassScreen()))),
              ],
              const SizedBox(height: Night.space4),
              Row(children: [
                Expanded(child: NightButton(tx('換新 QR code', 'New QR code'), kind: NightButtonKind.ghost, onPressed: () async {
                  final ok = await confirmSheet(context, tx('換新後，舊的 QR code、連結和邀請碼立刻失效。已經入團的人不受影響。', 'The old QR code, link and invite code stop working. Members who joined stay in.'), action: tx('換新', 'Replace'));
                  if (ok == true) await TourService.call('rotate_qr');
                })),
                const SizedBox(width: 12),
                Expanded(child: NightButton(tx('分享入團連結', 'Share link'), onPressed: () => SharePlus.instance.share(ShareParams(
                  text: g.invite == null
                      ? tx('加入「${g.name}」：先安裝「旅行團」App，再點這個連結 ${g.qr}', 'Join "${g.name}" on TourChip: ${g.qr}')
                      : tx('加入「${g.name}」：點這個連結 ${g.qr}\n還沒裝「旅行團」App 會先帶你去下載，裝好打開就會入團；也可以在 App 裡按「輸入邀請碼入團」，輸入 ${formatInvite(g.invite!)}', 'Join "${g.name}" on TourChip: ${g.qr}\nNo app yet? The link takes you to download it, and you\'ll join when you open it. Or tap "Join with invite code" in the app and enter ${formatInvite(g.invite!)}'),
                )))),
              ]),
            ]),
          ),
        );
      },
    );
  }
}
