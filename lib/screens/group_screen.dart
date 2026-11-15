import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../aiya/aiya_screen.dart';
import '../aiya/aiya_spots.dart';
import '../l10n.dart';
import '../map/tour_map.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../tour/zones.dart';
import '../translate.dart';
import '../ui/night.dart';
import 'call_overlay.dart';
import 'cast_ui.dart';
import 'gather_screen.dart';
import 'info_screen.dart';
import 'itinerary_screen.dart';
import 'join.dart';
import 'members_screen.dart';
import 'pass_screen.dart';
import 'qr_screen.dart';
import 'roll_call_screen.dart';
import 'settings_screen.dart';
import 'memory_card.dart';
import 'social.dart';
import 'together_screen.dart';

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
            Positioned.fill(child: TourMap(key: _map, group: g, onPersonLongPress: (p) => openChat(context, p.uid), onPersonTap: (p) => showPerson(context, p), onFlagTap: () => showCallInfo(context))),
            Positioned(left: Night.space4, right: Night.space4, top: MediaQuery.of(context).padding.top + Night.space2, child: _TopBar(g: g)),
            // 靠近行程表上的景點：艾婭問要不要聽介紹
            Positioned(
              left: Night.space4, right: Night.space4, top: MediaQuery.of(context).padding.top + Night.space2 + 52 + Night.space2,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // 正在聽或正在講講解廣播
                CastBar(g: g),
                AiyaSpotPrompt(g: g),
              ]),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // 左邊：我的氣泡；右下角：設定（大頭貼、暱稱、語言、分享位置、說明…）
                Padding(
                  padding: const EdgeInsets.fromLTRB(Night.space4, 0, Night.space4, Night.space3),
                  // 不能用 Spacer：它和 Flexible 各分一半寬度，氣泡用不完的空間會留在齒輪右邊
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Flexible(child: _BubbleChip(g: g)),
                    const SizedBox(width: Night.space3),
                    const SettingsButton(fill: Night.mapGlass),
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
  // 出發前：顯示出發日
  if (day <= 0) return tx('${start.month}/${start.day} 出發', 'Starts ${start.month}/${start.day}');
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
      decoration: BoxDecoration(color: Night.mapGlass, borderRadius: BorderRadius.circular(999), border: Border.all(color: Night.glassLine)),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: g.tint, shape: BoxShape.circle, boxShadow: [BoxShadow(color: g.tint, blurRadius: 8)])),
        const SizedBox(width: 10),
        // 團員的團號放在團名後面（原本在面板第一行，移出來讓面板矮一點）
        Expanded(
          flex: 2,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: g.name),
              if (!g.isStaff && g.myNo != null) TextSpan(text: '  ${tx('${g.myNo} 號', 'No. ${g.myNo}')}', style: const TextStyle(color: Night.inkMuted, fontSize: 13, fontWeight: FontWeight.w400)),
            ]),
            style: const TextStyle(color: Night.ink, fontSize: 15, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 「第 2 天 · 東京／京都／大阪」在小螢幕、長字語言會太長：最多佔一部分寬度，放不下就省略
        Flexible(child: Text(dayLabel(g), style: Night.caption.copyWith(color: Night.inkMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (g.isStaff)
          IconButton(
            tooltip: tx('入團 QR code', 'Join QR code'),
            icon: const Icon(Icons.qr_code_2, color: Night.ink),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScreen())),
          ),
        // 講解廣播：團員有廣播才出現（耳機，按一下開／關）；團主與共同團主一直在（麥克風）
        CastButton(g: g),
        const AiyaButton(),
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
      NightButton(tx('旅程回憶卡', 'Trip memory card'), kind: NightButtonKind.ghost, icon: Icons.auto_awesome_outlined, onPressed: () {
        Navigator.pop(ctx);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemoryCardScreen(memory: TripMemory.of(g))));
      }),
      const SizedBox(height: Night.space2),
      if (g.isStaff) ...[
        NightButton(tx('團員名單', 'Members'), kind: NightButtonKind.ghost, icon: Icons.people_outline, onPressed: () {
          Navigator.pop(ctx);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MembersScreen()));
        }),
        const SizedBox(height: Night.space2),
      ],
      if (g.isHost) ...[
        NightButton(tx('人數券、天數券', 'Passes'), kind: NightButtonKind.ghost, icon: Icons.workspace_premium_outlined, onPressed: () {
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

/// 面板收起來了沒（整個 App 共用；新的集合、點名、投票來了會自動打開）
final panelFolded = ValueNotifier<bool>(false);

class _Panel extends StatefulWidget {
  final List<Widget> children;
  /// 收起來時只顯示這一行
  final Widget mini;
  /// 這個字串變了（新的集合、點名、要投的票…）就自動打開
  final String openKey;
  const _Panel({required this.children, required this.mini, required this.openKey});
  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  @override
  void didUpdateWidget(_Panel old) {
    super.didUpdateWidget(old);
    if (old.openKey != widget.openKey && widget.openKey.isNotEmpty) panelFolded.value = false;
  }

  @override
  Widget build(BuildContext context) {
    // 浮在地圖上的完整卡片：四邊都看得到；底下留空間給地圖出處標示（TourMap 畫在畫面最底下）
    final pb = MediaQuery.of(context).padding.bottom;
    return ValueListenableBuilder<bool>(
      valueListenable: panelFolded,
      builder: (context, folded, _) => GestureDetector(
        // 往下滑收起來、往上滑打開（讓出 3D 地圖）
        onVerticalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v > 150) panelFolded.value = true;
          if (v < -150) panelFolded.value = false;
        },
        child: Container(
          margin: EdgeInsets.fromLTRB(Night.space4, 0, Night.space4, (pb < 12 ? 12.0 : pb) + 6),
          padding: EdgeInsets.fromLTRB(Night.space4, 0, Night.space4, folded ? Night.space2 : Night.space3),
          decoration: BoxDecoration(
            color: Night.mapGlassPanel,
            borderRadius: BorderRadius.circular(Night.radiusLg),
            border: Border.all(color: Night.glassLine),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // 把手：點一下收起來／打開
            Semantics(
              button: true,
              label: folded ? tx('打開面板', 'Expand panel') : tx('收起面板', 'Collapse panel'),
              child: InkWell(
                onTap: () => panelFolded.value = !folded,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 26,
                  child: Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Night.inkFaint, borderRadius: BorderRadius.circular(2)))),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.bottomCenter,
              child: folded
                  ? InkWell(onTap: () => panelFolded.value = false, child: widget.mini)
                  : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.children),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 收起來時的一行：左邊摘要，右邊可以放一個按鈕
Widget _miniRow(String text, {Color? color, Widget? trailing}) => SizedBox(
      height: 40,
      child: Row(children: [
        Expanded(child: Text(text, style: TextStyle(color: color ?? Night.ink, fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ?trailing,
        const Icon(Icons.expand_less, color: Night.inkMuted, size: 22),
      ]),
    );

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
        color: Night.mapGlassTile,
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
      // 有人到集合點（自動點到）之後改看「已到」
      big = roll
          ? tx('到了 ${g.here}／${g.rollTotal}', 'Here ${g.here}/${g.rollTotal}')
          : g.arrived > 0
              ? tx('已到 ${g.arrived}／${g.callTotal}', 'Here ${g.arrived}/${g.callTotal}')
              : tx('收到 ${g.acked}／${g.callTotal}', 'Got it ${g.acked}/${g.callTotal}');
      progress = roll
          ? (g.rollTotal == 0 ? 0 : g.here / g.rollTotal)
          : (g.callTotal == 0 ? 0 : (g.arrived > 0 ? g.arrived : g.acked) / g.callTotal);
      clock = countdown(call.at);
    } else if (roll) {
      head = tx('點名中', 'Roll call');
      big = tx('到了 ${g.here}／${g.rollTotal}', 'Here ${g.here}/${g.rollTotal}');
      progress = g.rollTotal == 0 ? 0 : g.here / g.rollTotal;
    } else {
      head = '${tx('${g.count} 人', '${g.count} people')} · ${g.paid ? tx('上限 100 人', 'up to 100') : tx('20 人以內免費', 'free up to 20')}';
      big = tx('目前沒有集合', 'No gather call');
    }
    final miniText = [big, ?clock, if (g.lost.isNotEmpty) tx('${g.lost.length} 人迷路', '${g.lost.length} lost')].join(' · ');
    return _Panel(
      openKey: [call?.id ?? '', g.rollId ?? '', g.lost.length, g.far.length, g.help].join('|'),
      mini: _miniRow(miniText, color: g.lost.isNotEmpty ? Night.danger : null),
      children: [
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
      // 脫隊預警：大家跟著領隊走時，有人落後太遠
      if (g.far.isNotEmpty) ...[
        const SizedBox(height: Night.space3),
        for (final f in g.far.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () {
                  final p = g.people.where((x) => x.uid == f.uid).firstOrNull;
                  if (p != null) map.currentState?.flyTo(p.lat, p.lng);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0xFFFF9F45))),
                  child: Row(children: [
                    const Icon(Icons.directions_walk, color: Color(0xFFFF9F45), size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(tx('${f.no} 號 ${f.label} 落後約 ${f.d} 公尺 · ${_ago(f.since)}', 'No. ${f.no} is ${f.d} m behind · ${_ago(f.since)}'),
                        style: const TextStyle(color: Color(0xFFFF9F45), fontSize: 13), overflow: TextOverflow.ellipsis)),
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
        const SizedBox(width: 8),
        _ActionTile(tx('資訊', 'Info'), Icons.info_outline, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InfoScreen()))),
      ]),
      const SizedBox(height: Night.space1),
      Center(child: TextButton.icon(
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TogetherScreen())),
        icon: const Icon(Icons.how_to_vote_outlined, size: 18), label: Text(togetherLabel(g)),
      )),
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
    final roll = g.rollId != null && g.rollMine == null;
    final poll = g.pollsToVote.firstOrNull;
    // 收起來時的一行：集合倒數與集合點，或點名、投票、下一個集合
    final String mini;
    if (call != null) {
      mini = [countdown(call.at), tx('${hm(call.at, call.tz)} 集合', 'Gather at ${hm(call.at, call.tz)}'), if (call.place.isNotEmpty) call.place].join(' · ');
    } else if (roll) {
      mini = tx('領隊在點名', 'Roll call');
    } else if (next != null) {
      mini = tx('下一個集合：${md(next.at, next.tz)} ${hm(next.at, next.tz)} ${next.place}', 'Next: ${md(next.at, next.tz)} ${hm(next.at, next.tz)} ${next.place}');
    } else {
      mini = tx('目前沒有集合', 'No gather call right now');
    }
    return _Panel(
      // 新的集合、點名、要投的票來了：自動打開（「收到」「我到了」要按得到）
      openKey: [call?.id ?? '', if (roll) g.rollId, poll?.id ?? ''].join('|'),
      mini: _miniRow(mini, trailing: TextButton(
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: Night.danger),
        onPressed: () => askLost(context, g),
        child: Text(g.lostSent ? tx('已通知領隊', 'Leader notified') : tx('我迷路了', 'I\'m lost')),
      )),
      children: [
      if (call != null)
        CallCard(g: g, call: call)
      else ...[
        if (roll) ...[
          Text(tx('領隊在點名', 'Roll call'), style: Night.title.copyWith(color: g.tint)),
          const SizedBox(height: Night.space3),
          RollButtons(g: g),
        ] else if (poll != null)
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TogetherScreen())),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.how_to_vote_outlined, color: g.tint, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(tx('領隊想問你：${poll.q}', 'Your leader asks: ${poll.q}'), style: Night.body.copyWith(color: Night.ink), maxLines: 2, overflow: TextOverflow.ellipsis)),
              Icon(Icons.chevron_right, color: g.tint, size: 20),
            ]),
          )
        else if (ann != null)
          InkWell(
            onTap: () => showAnnouncements(context, g),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.campaign_outlined, color: g.tint, size: 20),
              const SizedBox(width: 8),
              Expanded(child: TranslatableText(ann.text, compact: true, style: Night.body.copyWith(color: Night.ink), maxLines: 2)),
            ]),
          )
        else
          Text(tx('目前沒有集合', 'No gather call right now'), style: Night.title),
        if (next != null) ...[
          const SizedBox(height: Night.space2),
          Text(tx('下一個集合：${md(next.at, next.tz)} ${hm(next.at, next.tz)} ${next.place}', 'Next: ${md(next.at, next.tz)} ${hm(next.at, next.tz)} ${next.place}'),
              style: Night.caption.copyWith(color: Night.inkMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ],
      SizedBox(height: call != null ? Night.space2 : Night.space3),
      Row(children: [
        Expanded(child: NightButton(tx('舉起團旗', 'Raise flag'), kind: NightButtonKind.ghost, onPressed: () => showFlag(context, g))),
        const SizedBox(width: 8),
        Expanded(child: NightButton(g.lostSent ? tx('已通知領隊', 'Leader notified') : tx('我迷路了', 'I\'m lost'), kind: NightButtonKind.danger, onPressed: () => askLost(context, g))),
      ]),
      const SizedBox(height: Night.space2),
      // 其他頁面：排成一行，放不下就左右滑（原本兩行）
      _LinkStrip(items: [
        (Icons.event_note_outlined, tx('行程表', 'Itinerary'), () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ItineraryScreen()))),
        (Icons.campaign_outlined, g.announcements.isEmpty ? tx('公告', 'Notices') : tx('公告 ${g.announcements.length}', 'Notices ${g.announcements.length}'), () => showAnnouncements(context, g)),
        (Icons.directions_bus_outlined, tx('車輛・飯店・緊急', 'Bus · Hotel · SOS'), () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InfoScreen()))),
        (Icons.how_to_vote_outlined, togetherLabel(g), () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TogetherScreen()))),
        // 最後一天：旅程回憶卡
        if (g.thanksOpen) (Icons.auto_awesome_outlined, tx('旅程回憶卡', 'Memory card'), () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemoryCardScreen(memory: TripMemory.of(g))))),
      ]),
    ]);
  }
}

/// 一行小按鈕（圖示＋字），放不下就左右滑；右邊淡出提示還有
class _LinkStrip extends StatelessWidget {
  final List<(IconData, String, VoidCallback)> items;
  const _LinkStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(colors: [Colors.white, Colors.white, Colors.transparent], stops: [0, 0.9, 1]).createShader(r),
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final (icon, label, onTap) = items[i];
            return Material(
              color: Night.mapGlassTile,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 16, color: Night.auroraBlue),
                    const SizedBox(width: 5),
                    Text(label, style: const TextStyle(color: Night.ink, fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
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
      color: Night.mapGlass,
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
