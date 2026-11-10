import 'package:flutter/material.dart';

import '../aiya/aiya_screen.dart';
import '../l10n.dart';
import '../map/tour_map.dart';
import '../tour/profile.dart';
import '../ui/avatar.dart';
import '../ui/night.dart';
import 'create_screen.dart';
import 'join.dart';
import 'settings_screen.dart';

/// 首頁（不在任何團裡時）：和城市低語一樣先是 3D 夜光地圖（進場鏡頭從城市高空俯衝下來，
/// 之後跟著手機的羅盤與傾斜轉動、兩指縮放），鏡頭到位後下方才出現「開一個團」「掃碼入團」。
/// 最下面是自己的大頭貼與暱稱，右下角是設定。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    // 進場鏡頭 2.6 秒，快結束時面板滑上來
    Future.delayed(const Duration(milliseconds: 2200), () { if (mounted) setState(() => _shown = true); });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: TourMap(intro: true, bottomInset: 200 + bottom)),
        // 左上角：App 名稱
        Positioned(
          left: Night.space4, top: MediaQuery.of(context).padding.top + Night.space2,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: Night.glassFill, borderRadius: BorderRadius.circular(999), border: Border.all(color: Night.glassLine)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Night.auroraViolet, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Night.auroraViolet, blurRadius: 8)])),
                const SizedBox(width: 10),
                Text(tx('旅行團 · 掃一下入團，集合時每個人都收得到', 'TourChip · Scan to join, everyone hears the call'), style: const TextStyle(color: Night.inkMuted, fontSize: 14)),
              ]),
            ),
          ),
        ),
        Positioned(
          left: Night.space4, right: Night.space4, bottom: bottom + Night.space3,
          child: AnimatedSlide(
            offset: _shown ? Offset.zero : const Offset(0, 0.4),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _shown ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              child: IgnorePointer(
                ignoring: !_shown,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(
                      child: NightButton(tx('開一個團', 'Start a group'), icon: Icons.flag_outlined, expand: true,
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateScreen()))),
                    ),
                    const SizedBox(width: Night.space3),
                    Expanded(
                      child: _SolidGhost(child: NightButton(tx('掃碼入團', 'Scan to join'), icon: Icons.qr_code_scanner, kind: NightButtonKind.ghost, expand: true, onPressed: () => scanAndOpen(context))),
                    ),
                  ]),
                  const SizedBox(height: Night.space3),
                  const _ProfileBar(),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// 線框按鈕疊在地圖上時加一層底色，字才看得清楚
class _SolidGhost extends StatelessWidget {
  final Widget child;
  const _SolidGhost({required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(decoration: BoxDecoration(color: Night.glassFill, borderRadius: BorderRadius.circular(999)), child: child);
}

/// 最下面一條：自己的大頭貼、暱稱（點了編輯），右邊是設定
class _ProfileBar extends StatelessWidget {
  const _ProfileBar();
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MyProfile>(
      valueListenable: ProfileStore.me,
      builder: (context, p, _) => Container(
        height: 72,
        padding: const EdgeInsets.only(left: 10, right: 10),
        decoration: BoxDecoration(color: Night.glassFill, borderRadius: BorderRadius.circular(999), border: Border.all(color: Night.glassLine), boxShadow: const [Night.lift]),
        child: Row(children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => editProfile(context),
              child: Row(children: [
                Avatar(p.avatar, size: 52),
                const SizedBox(width: Night.space3),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name.isEmpty ? tx('設定你的暱稱', 'Set your nickname') : p.name,
                        style: const TextStyle(color: Night.ink, fontSize: 17, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    ShaderMask(
                      shaderCallback: (r) => Night.brightGradient.createShader(r),
                      blendMode: BlendMode.srcIn,
                      child: Text(tx('20 人以內免費 · 團員永遠免費', 'Free up to 20 · Always free for members'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          const AiyaButton(),
          IconButton(
            tooltip: tx('設定', 'Settings'),
            iconSize: 28,
            icon: const Icon(Icons.tune, color: Night.ink),
            onPressed: () => showSettings(context),
          ),
        ]),
      ),
    );
  }
}
