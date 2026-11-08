import 'package:flutter/material.dart';

import '../l10n.dart';
import '../ui/night.dart';
import 'create_screen.dart';
import 'join.dart';
import 'pass_screen.dart';

/// 首頁（不在任何團裡時）：開一個團、掃碼入團；旅行社可以在這裡買團購券。設計稿：首頁
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget step(String n, String text) => Padding(
          padding: const EdgeInsets.only(top: Night.space2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 24, height: 24, alignment: Alignment.center,
              decoration: const BoxDecoration(color: Night.night600, shape: BoxShape.circle),
              child: Text(n, style: const TextStyle(color: Night.ink, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: Night.space3),
            Expanded(child: Text(text, style: Night.body)),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(Night.space4, 48, Night.space4, Night.space6), children: [
          ShaderMask(
            shaderCallback: (r) => Night.brightGradient.createShader(r),
            blendMode: BlendMode.srcIn,
            child: Text(tx('旅行團', 'TourChip'), style: const TextStyle(fontSize: 40, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white)),
          ),
          const SizedBox(height: Night.space2),
          Text(tx('掃一下入團，集合時每個人都收得到。', 'Scan to join. Everyone hears the gather call.'), style: Night.body),
          const SizedBox(height: Night.space8),
          NightButton(tx('開一個團', 'Start a group'), icon: Icons.flag_outlined, expand: true,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateScreen()))),
          const SizedBox(height: Night.space3),
          NightButton(tx('掃碼入團', 'Scan to join'), icon: Icons.qr_code_scanner, kind: NightButtonKind.ghost, expand: true, onPressed: () => scanAndOpen(context)),
          const SizedBox(height: Night.space8),
          GlassCard(
            padding: const EdgeInsets.all(Night.space4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tx('怎麼開始', 'How it works'), style: Night.caption),
              step('1', tx('領隊開團，出示 QR code', 'The leader starts a group and shows a QR code')),
              step('2', tx('團員掃碼入團，不用加好友、不用留電話', 'Members scan to join. No friends list, no phone numbers')),
              step('3', tx('行程結束，團自動解散，名單全部刪除', 'When the trip ends, the group and its list are deleted')),
            ]),
          ),
          const SizedBox(height: Night.space6),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PassScreen())),
              style: TextButton.styleFrom(foregroundColor: Night.inkMuted),
              child: Text(tx('旅行社：購買團購券', 'Agencies: buy vouchers')),
            ),
          ),
          const SizedBox(height: Night.space2),
          Text(tx('20 人以內免費 · 團員永遠免費', 'Free up to 20 people · Always free for members'), style: Night.caption.copyWith(color: Night.inkMuted), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
