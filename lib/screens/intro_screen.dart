import 'package:flutter/material.dart';
import '../l10n.dart';
import '../ui/night.dart';

/// 開場導覽：和城市低語一樣，每次打開 App 都先看一次，右上角可以「略過」。
/// 10 張滿版插圖（不含文字，各語言共用），標題與說明疊在下方。
class IntroScreen extends StatefulWidget {
  final VoidCallback onDone;
  const IntroScreen({super.key, required this.onDone});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _controller = PageController();
  int _page = 0;

  List<(String, String)> get _pages => [
        (tx('一道光，把大家找回來', 'One beam of light brings everyone back'),
            tx('領隊在地圖上放下集合點，每個人的手機都會出現光柱、時間、距離和方向。', 'Your leader drops a meeting point, and everyone sees a light beam, the time, distance and direction.')),
        (tx('領隊一按，全團都收到', 'One tap, the whole group knows'),
            tx('拖曳地圖選好集合點就發出；鎖屏、專注模式也會響，沒按收到的人會再提醒。', 'Drag the map to pick a spot and send. It rings even on lock screen or Focus, and repeats until people reply.')),
        (tx('掃一下就入團', 'Scan once to join'),
            tx('用 App 掃領隊的 QR code 就加入，不用帳號、不用加好友，團員永遠免費。', 'Scan your leader\'s QR code with the app. No account, no friend requests, always free for members.')),
        (tx('點名，一秒就好', 'Roll call in a second'),
            tx('到了按「我到了」；誰還沒到、誰需要幫忙，領隊一眼就知道。', 'Tap "I\'m here". Your leader sees at a glance who\'s missing and who needs help.')),
        (tx('迷路了也不怕', 'Lost? Don\'t worry'),
            tx('按「我迷路了」，領隊的地圖上會出現你的位置，跟著光回到大家身邊。', 'Tap "I\'m lost" and your location appears on your leader\'s map. Follow the light back to the group.')),
        (tx('同團的人，在地圖上互相看得到', 'See your group on the map'),
            tx('同意分享後才會出現在地圖上，設定裡隨時可以關；沒入團的人看不到任何人。', 'You appear only after you agree, and can turn it off anytime. People outside the group see no one.')),
        (tx('一顆氣泡，說說現在的心情', 'A bubble for how you feel'),
            tx('每人一顆 20 字的氣泡；長按地圖上的人就能傳私訊，也可以封鎖和檢舉。', 'Everyone gets a 20-character bubble. Long-press someone on the map to message them; block and report are built in.')),
        (tx('分車分組，各自集合', 'Split into buses and teams'),
            tx('1 號車、2 號車分開集合，只會叫到你那一組。', 'Bus 1 and bus 2 gather separately. You only get calls for your own team.')),
        (tx('跨國行程，時間不會錯', 'Across time zones, always on time'),
            tx('集合時間一律用集合點的當地時間，台北飛東京也不用自己換算。', 'Meeting times always use the meeting point\'s local time, so Taipei to Tokyo needs no math.')),
        (tx('謝謝這幾天一起同行', 'Thanks for traveling together'),
            tx('行程結束自動解散，位置、氣泡和訊息都會一起刪除。', 'The group ends on its own after the trip, and locations, bubbles and messages are deleted.')),
      ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => widget.onDone();

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final last = _page == pages.length - 1;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Night.night900,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: pages.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/intro_${(i + 1).toString().padLeft(2, '0')}.webp',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, _, _) => const ColoredBox(color: Night.night800),
                ),
                // 下方漸層，讓文字在亮的畫面上也看得清楚
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.45, 0.72, 1],
                      colors: [Color(0x00000000), Color(0xB3070B1F), Color(0xF2070B1F)],
                    ),
                  ),
                ),
                Positioned(
                  left: 28,
                  right: 28,
                  bottom: pad.bottom + 110,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(pages[i].$1,
                          textAlign: TextAlign.center,
                          style: Night.title.copyWith(fontSize: 24, fontWeight: FontWeight.w600, shadows: const [Shadow(blurRadius: 12, color: Colors.black54)])),
                      const SizedBox(height: 14),
                      Text(pages[i].$2,
                          textAlign: TextAlign.center,
                          style: Night.body.copyWith(color: Night.ink.withValues(alpha: 0.82), fontSize: 16, shadows: const [Shadow(blurRadius: 8, color: Colors.black54)])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!last)
            Positioned(
              top: pad.top + 8,
              right: 12,
              child: TextButton(
                onPressed: _finish,
                style: TextButton.styleFrom(backgroundColor: Colors.black26, shape: const StadiumBorder()),
                child: Text(tx('略過', 'Skip'), style: Night.label.copyWith(color: Night.ink)),
              ),
            ),
          Positioned(
            left: 24,
            right: 16,
            bottom: pad.bottom + 32,
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    children: List.generate(
                      pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        height: 6,
                        width: _page == i ? 20 : 6,
                        decoration: BoxDecoration(
                          gradient: _page == i ? Night.brightGradient : null,
                          color: _page == i ? null : Night.ink.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                last
                    ? NightButton(tx('開始使用', 'Get started'), onPressed: _finish)
                    : IconButton(
                        onPressed: () => _controller.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.ease),
                        tooltip: tx('下一頁', 'Next'),
                        icon: const Icon(Icons.arrow_forward_ios, color: Night.ink),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
