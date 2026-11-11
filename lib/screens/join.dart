import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n.dart';
import '../tour/service.dart';
import '../ui/night.dart';

/// 打開入團連結或團購券連結（掃 QR code、點分享連結都走這裡）
Future<void> openTourLink(BuildContext context, TourLink link) async {
  switch (link) {
    case JoinLink(:final code, :final version):
      final r = await TourService.call('join', {'code': code, 'v': version});
      if (context.mounted) _showJoinResult(context, r);
    case VoucherLink(:final code):
      final g = TourService.current.value;
      if (g == null || !g.isHost) {
        showGlassToast(context, tx('團購券要由團主在開團後掃描使用。', 'The group leader scans the voucher after creating a group.'), icon: Icons.info_outline);
        return;
      }
      final ok = await confirmSheet(context, tx('把這張團購券用在「${g.name}」？人數券會讓這一團最多 100 人，天數券會讓這一團多 7 天。', 'Use this voucher on "${g.name}"? A group-size pass allows 100 people; a day pass adds 7 days.'), action: tx('使用團購券', 'Use voucher'));
      if (ok != true) return;
      final r = await TourService.call('redeem', {'voucher': code});
      if (!context.mounted) return;
      final done = r['kind'] == 'days' ? tx('這一團多了 7 天。', 'Added 7 days to this group.') : tx('這一團已升級，最多 100 人。', 'Upgraded. Up to 100 people.');
      showGlassToast(context, r['success'] == true ? done : tourError('${r['code']}'),
          danger: r['success'] != true, icon: r['success'] == true ? Icons.workspace_premium_outlined : Icons.error_outline);
  }
}

void _showJoinResult(BuildContext context, Map r) {
  if (r['success'] == true) {
    final g = TourService.current.value;
    showGlassToast(context, tx('已加入「${g?.name ?? ''}」，你是 ${g?.myNo ?? 0} 號', 'Joined "${g?.name ?? ''}". You are No. ${g?.myNo ?? 0}'), icon: Icons.flag_outlined);
  } else {
    showGlassToast(context, tourError('${r['code']}'), danger: true, icon: Icons.error_outline);
  }
}

/// 邀請碼顯示成「1234 5678」
String formatInvite(String inv) => inv.length == 8 ? '${inv.substring(0, 4)} ${inv.substring(4)}' : inv;

/// 已經裝好 App：輸入領隊給的 8 位數邀請碼入團
Future<void> enterInviteAndJoin(BuildContext context) async {
  final ctl = TextEditingController();
  var busy = false;
  String? error;
  final joined = await showPanel<Map>(context, (ctx, setS) {
    Future<void> submit() async {
      final inv = ctl.text.replaceAll(RegExp(r'\D'), '');
      if (inv.length != 8 || busy) {
        setS(() => error = tx('邀請碼是 8 位數字', 'The invite code has 8 digits'));
        return;
      }
      setS(() { busy = true; error = null; });
      final r = await TourService.call('join', {'invite': inv});
      if (!ctx.mounted) return;
      if (r['success'] == true) {
        Navigator.pop(ctx, r);
      } else {
        setS(() { busy = false; error = tourError('${r['code']}'); });
      }
    }

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(tx('輸入邀請碼', 'Enter invite code'), closeTooltip: tx('關閉', 'Close')),
      const SizedBox(height: Night.space2),
      Text(tx('向領隊要 8 位數的邀請碼，入團 QR code 下面就有。', 'Ask your leader for the 8-digit code. It\'s under the join QR code.'), style: Night.body, textAlign: TextAlign.center),
      const SizedBox(height: Night.space4),
      TextField(
        controller: ctl,
        autofocus: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
        style: const TextStyle(color: Night.ink, fontSize: 30, letterSpacing: 8, fontFeatures: [FontFeature.tabularFigures()]),
        decoration: InputDecoration(hintText: '00000000', hintStyle: TextStyle(color: Night.inkMuted.withValues(alpha: 0.35)), errorText: error, errorMaxLines: 3),
        onChanged: (_) { if (error != null) setS(() => error = null); },
        onSubmitted: (_) => submit(),
      ),
      const SizedBox(height: Night.space4),
      NightButton(busy ? tx('加入中…', 'Joining…') : tx('入團', 'Join'), icon: Icons.flag_outlined, onPressed: busy ? null : submit),
    ]);
  });
  ctl.dispose();
  if (joined != null && context.mounted) _showJoinResult(context, joined);
}

/// App 內掃 QR code：入團或團購券
Future<void> scanAndOpen(BuildContext context) async {
  final raw = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScanScreen()));
  if (raw == null || !context.mounted) return;
  final link = parseTourLink(raw);
  if (link == null) {
    showGlassToast(context, tx('這不是旅行團的 QR code。', 'This is not a TourChip QR code.'), danger: true, icon: Icons.qr_code_2);
    return;
  }
  await openTourLink(context, link);
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Night.ink, title: Text(tx('掃描 QR code', 'Scan QR code'))),
      body: Stack(children: [
        MobileScanner(onDetect: (capture) {
          if (_done) return;
          final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
          if (raw == null) return;
          _done = true;
          Navigator.of(context).pop(raw);
        }),
        Center(
          child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Night.radiusLg), border: Border.all(color: Night.auroraViolet, width: 3)),
          ),
        ),
        Positioned(
          left: 24, right: 24, bottom: 48,
          child: Text(tx('對準領隊手機上的 QR code，或旅行社發的團購券', 'Point at the leader\'s QR code, or a voucher from your agency'),
              textAlign: TextAlign.center, style: Night.body.copyWith(color: Night.ink)),
        ),
      ]),
    );
  }
}

/// 確認面板：回傳 true 表示按下確認
Future<bool?> confirmSheet(BuildContext context, String text, {required String action, bool danger = false}) {
  return showModalBottomSheet<bool>(
    context: context, backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Night.space4),
        child: SolidCard(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(text, style: Night.body.copyWith(color: Night.ink), textAlign: TextAlign.center),
          const SizedBox(height: Night.space4),
          NightButton(action, kind: danger ? NightButtonKind.danger : NightButtonKind.primary, onPressed: () => Navigator.pop(ctx, true)),
          const SizedBox(height: Night.space2),
          NightButton(tx('取消', 'Cancel'), kind: NightButtonKind.text, onPressed: () => Navigator.pop(ctx, false)),
        ])),
      ),
    ),
  );
}

/// 實心底的玻璃卡：面板疊在地圖上，後面的字不能透出來
class SolidCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SolidCard({super.key, required this.child, this.padding = const EdgeInsets.all(Night.space6)});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: Night.night900, borderRadius: BorderRadius.circular(Night.radiusLg)),
        child: GlassCard(padding: padding, child: child),
      );
}

/// 底部面板的外框：SafeArea、鍵盤推高、實心卡片
Future<T?> showPanel<T>(BuildContext context, Widget Function(BuildContext ctx, StateSetter setS) build) {
  return showModalBottomSheet<T>(
    context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(child: Padding(padding: const EdgeInsets.all(Night.space4), child: SolidCard(child: build(ctx, setS)))),
    )),
  );
}
