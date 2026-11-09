import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../tour/zones.dart';
import '../ui/night.dart';
import 'join.dart';

/// 人數券、天數券與團購券。設計稿：7 天方案與團購券
///   團主：買人數券（這一團升到 100 人）、天數券（這一團多 7 天），或掃旅行社給的團購券
///   旅行社：買人數券或天數券的團購券，每張是一個 QR code，發給要帶團的領隊
/// 兩種都是消耗型商品（tour_pass_7d、tour_days_7d，各 NT$290）。
class PassScreen extends StatefulWidget {
  const PassScreen({super.key});
  @override
  State<PassScreen> createState() => _PassScreenState();
}

class _PassScreenState extends State<PassScreen> {
  @override
  void initState() {
    super.initState();
    PassStore.load();
    PassStore.loadVouchers();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TourGroup?>(
      valueListenable: TourService.current,
      builder: (context, g, _) => ValueListenableBuilder<bool>(
        valueListenable: PassStore.busy,
        builder: (context, busy, _) => ValueListenableBuilder<Map<String, ProductDetails>>(
          valueListenable: PassStore.details,
          builder: (context, _, _) {
            final people = PassStore.priceOf(PassStore.people);
            final days = PassStore.priceOf(PassStore.days);
            Widget card({required String title, required String price, required List<String> lines, required String button, required VoidCallback? onBuy, bool glow = false}) =>
                GlassCard(glow: glow, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(title, style: Night.title)),
                    Text(price, style: const TextStyle(color: Night.ink, fontSize: 22, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: Night.space3),
                  for (final line in lines) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(line, style: Night.body)),
                  const SizedBox(height: Night.space3),
                  NightButton(button, kind: glow ? NightButtonKind.primary : NightButtonKind.ghost, onPressed: onBuy),
                ]));
            return Scaffold(
              appBar: AppBar(
                backgroundColor: Night.night900, foregroundColor: Night.ink,
                title: Text(g != null && g.isHost && !g.paid && g.count >= 20 ? tx('團已滿 20 人', 'Group is full (20)') : tx('人數券、天數券', 'Passes'), style: Night.title),
              ),
              body: SafeArea(
                child: ListView(padding: const EdgeInsets.all(Night.space4), children: [
                  if (g != null && g.isHost) ...[
                    Text(
                        g.paid
                            ? tx('「${g.name}」：最多 100 人，目前開通 ${g.allowedDays} 天', '"${g.name}": up to 100 people, ${g.allowedDays} days active')
                            : tx('「${g.name}」：20 人以內免費，目前開通 ${g.allowedDays} 天', '"${g.name}": free up to 20 people, ${g.allowedDays} days active'),
                        style: Night.body),
                    const SizedBox(height: Night.space4),
                    // ---- 人數券 ----
                    if (g.paid)
                      GlassCard(child: Row(children: [
                        const Icon(Icons.workspace_premium_outlined, color: Night.cityAmber),
                        const SizedBox(width: 12),
                        Expanded(child: Text(tx('已用人數券，最多 100 人。', 'Group-size pass active. Up to 100 people.'), style: Night.body.copyWith(color: Night.ink))),
                      ]))
                    else
                      card(
                        title: tx('人數券', 'Group-size pass'), price: people, glow: g.count >= 20,
                        lines: [
                          tx('人數上限提高到 100 人', 'Up to 100 people'),
                          tx('只用在「${g.name}」這一團，到解散為止', 'For "${g.name}" until it ends'),
                          tx('團員永遠免費', 'Always free for members'),
                        ],
                        button: tx('購買人數券', 'Buy group-size pass'),
                        onBuy: busy ? null : () => PassStore.buy(PassStore.people, PassPurpose.group),
                      ),
                    const SizedBox(height: Night.space4),
                    // ---- 天數券 ----
                    if (g.allowedDays >= 30)
                      GlassCard(child: Row(children: [
                        const Icon(Icons.event_available_outlined, color: Night.cityAmber),
                        const SizedBox(width: 12),
                        Expanded(child: Text(tx('已經是最長的 30 天。', 'Already at the 30-day maximum.'), style: Night.body.copyWith(color: Night.ink))),
                      ]))
                    else
                      card(
                        title: tx('天數券', 'Day pass'), price: days, glow: g.daysNeeded > 0 && g.count < 20,
                        lines: [
                          tx('這一團多 7 天（可以買好幾張，最長 30 天）', '+7 days for this group (stack up to 30 days)'),
                          g.daysNeeded > 0
                              ? tx('行程 ${g.days} 天，還要 ${g.daysNeeded} 張', 'Trip is ${g.days} days: ${g.daysNeeded} more needed')
                              : tx('出發日起前 3 天免費', 'The first 3 days are free'),
                          tx('天數在行程表右上角「出發日與天數」設定', 'Set the trip length from the itinerary'),
                        ],
                        button: tx('購買天數券', 'Buy day pass'),
                        onBuy: busy ? null : () => PassStore.buy(PassStore.days, PassPurpose.group),
                      ),
                    const SizedBox(height: Night.space2),
                    Text(tx('一次購買，不會自動續費。', 'One-time purchases, no renewal.'), style: Night.caption, textAlign: TextAlign.center),
                    const SizedBox(height: Night.space4),
                    GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(tx('有旅行社給的團購券', 'Have a voucher from your agency?'), style: const TextStyle(color: Night.ink, fontSize: 15, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(tx('掃描券上的 QR code，人數券或天數券直接用在這一團，不用另外付款。', 'Scan its QR code to apply it to this group at no cost.'), style: Night.caption.copyWith(color: Night.inkMuted)),
                      const SizedBox(height: Night.space3),
                      NightButton(tx('掃描團購券', 'Scan voucher'), kind: NightButtonKind.ghost, icon: Icons.qr_code_scanner, onPressed: () => scanAndOpen(context)),
                    ])),
                    const SizedBox(height: Night.space6),
                  ],
                  _VoucherSection(people: people, days: days, busy: busy),
                  const SizedBox(height: Night.space4),
                  Text(tx('提早解散不退費，退款依 App Store／Google Play 的流程辦理。', 'No refunds for ending early. Refunds follow App Store / Google Play policies.'), style: Night.caption, textAlign: TextAlign.center),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VoucherSection extends StatelessWidget {
  final String people, days;
  final bool busy;
  const _VoucherSection({required this.people, required this.days, required this.busy});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TourVoucher>>(
      valueListenable: PassStore.vouchers,
      builder: (context, list, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tx('旅行社團購券', 'Agency vouchers'), style: const TextStyle(color: Night.ink, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(tx('人數券 $people、天數券 $days。買到的券會變成 QR code，發給要帶團的領隊，領隊開團後掃描就能使用。可以看到哪些券已經用掉。', 'Group-size $people, day pass $days. Each voucher is a QR code for a leader to scan after starting a group.'),
              style: Night.caption.copyWith(color: Night.inkMuted)),
          const SizedBox(height: Night.space3),
          Row(children: [
            Expanded(child: NightButton(tx('人數券', 'Group-size'), kind: NightButtonKind.ghost, icon: Icons.groups_outlined, onPressed: busy ? null : () => PassStore.buy(PassStore.people, PassPurpose.voucher))),
            const SizedBox(width: 8),
            Expanded(child: NightButton(tx('天數券', 'Day pass'), kind: NightButtonKind.ghost, icon: Icons.event_outlined, onPressed: busy ? null : () => PassStore.buy(PassStore.days, PassPurpose.voucher))),
          ]),
        ])),
        if (list.isNotEmpty) ...[
          const SizedBox(height: Night.space4),
          Text(tx('我買的團購券（${list.where((v) => !v.used).length} 張可用）', 'My vouchers (${list.where((v) => !v.used).length} unused)'), style: Night.caption),
          const SizedBox(height: Night.space2),
          for (final v in list)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(v.used ? Icons.check_circle_outline : (v.isDays ? Icons.event_outlined : Icons.groups_outlined), color: v.used ? Night.inkFaint : Night.cityAmber),
              title: Text(v.code, style: TextStyle(color: v.used ? Night.inkFaint : Night.ink, letterSpacing: 2)),
              subtitle: Text('${v.isDays ? tx('天數券', 'Day pass') : tx('人數券', 'Group-size')} · ${v.used ? tx('已使用', 'Used') : tx('${md(v.createdAt, deviceTz)} 購買', 'Bought ${md(v.createdAt, deviceTz)}')}', style: Night.caption),
              trailing: v.used ? null : const Icon(Icons.qr_code_2, color: Night.ink),
              onTap: v.used ? null : () => _showVoucher(context, v),
            ),
        ],
      ]),
    );
  }

  void _showVoucher(BuildContext context, TourVoucher v) {
    showPanel(context, (ctx, _) => Column(mainAxisSize: MainAxisSize.min, children: [
      Text(v.isDays ? tx('天數券團購券（多 7 天）', 'Day-pass voucher (+7 days)') : tx('人數券團購券（100 人）', 'Group-size voucher (100 people)'), style: Night.title, textAlign: TextAlign.center),
      const SizedBox(height: Night.space2),
      Text(tx('請領隊開團後，在「人數券、天數券」裡掃描', 'The leader scans this after starting a group'), style: Night.caption, textAlign: TextAlign.center),
      const SizedBox(height: Night.space3),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Night.radiusMd)),
        child: QrImageView(data: v.link, size: 220, backgroundColor: Colors.white),
      ),
      const SizedBox(height: Night.space2),
      SelectableText(v.code, style: const TextStyle(color: Night.ink, fontSize: 20, letterSpacing: 3)),
      const SizedBox(height: Night.space3),
      NightButton(tx('分享給領隊', 'Share with a leader'), icon: Icons.ios_share,
          onPressed: () => SharePlus.instance.share(ShareParams(text: (v.isDays
              ? tx('旅行團天數券團購券：開團後在「人數券、天數券」掃描或點這個連結 ${v.link}', 'TourChip day-pass voucher: ${v.link}')
              : tx('旅行團人數券團購券：開團後在「人數券、天數券」掃描或點這個連結 ${v.link}', 'TourChip group-size voucher: ${v.link}'))))),
    ]));
  }
}
