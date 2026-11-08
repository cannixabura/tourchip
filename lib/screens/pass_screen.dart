import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/service.dart';
import '../tour/zones.dart';
import '../ui/night.dart';
import 'join.dart';

/// 7 天方案與團購券。設計稿：7 天方案與團購券
///   團主：買 7 天方案升級目前這一團（最多 100 人），或掃旅行社給的團購券
///   旅行社：一次買多張團購券，每張是一個 QR code，發給要帶團的領隊
/// 兩者是同一個消耗型商品 tour_pass_7d（NT$290），差別只在用途。
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
        builder: (context, busy, _) {
          final price = PassStore.details.value?.price ?? 'NT\$290';
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Night.night900, foregroundColor: Night.ink,
              title: Text(g != null && g.isHost && !g.paid && g.count >= 20 ? tx('團已滿 20 人', 'Group is full (20)') : tx('7 天方案與團購券', 'Passes and vouchers'), style: Night.title),
            ),
            body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(Night.space4), children: [
                if (g != null && g.isHost) ...[
                  if (g.paid)
                    GlassCard(child: Row(children: [
                      const Icon(Icons.workspace_premium_outlined, color: Night.cityAmber),
                      const SizedBox(width: 12),
                      Expanded(child: Text(tx('「${g.name}」已升級，最多 100 人。', '"${g.name}" is upgraded. Up to 100 people.'), style: Night.body.copyWith(color: Night.ink))),
                    ]))
                  else ...[
                    Text(tx('升級這一團後，最多可以有 100 人。', 'Upgrade this group to allow up to 100 people.'), style: Night.body),
                    const SizedBox(height: Night.space4),
                    GlassCard(glow: true, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: Text(tx('7 天方案', '7-day pass'), style: Night.title)),
                        Text(price, style: const TextStyle(color: Night.ink, fontSize: 22, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: Night.space3),
                      for (final line in [
                        tx('人數上限提高到 100 人', 'Up to 100 people'),
                        tx('只用在「${g.name}」這一團，到解散為止', 'For "${g.name}" until it ends'),
                        tx('一次購買，不會自動續費', 'One-time purchase, no renewal'),
                        tx('團員永遠免費', 'Always free for members'),
                      ]) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(line, style: Night.body)),
                      const SizedBox(height: Night.space3),
                      NightButton(tx('購買 7 天方案', 'Buy 7-day pass'), onPressed: busy ? null : () => PassStore.buy(PassPurpose.group)),
                    ])),
                    const SizedBox(height: Night.space4),
                    GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(tx('有旅行社給的團購券', 'Have a voucher from your agency?'), style: const TextStyle(color: Night.ink, fontSize: 15, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(tx('掃描券上的 QR code，這一團直接升級，不用另外付款。', 'Scan its QR code to upgrade this group at no cost.'), style: Night.caption.copyWith(color: Night.inkMuted)),
                      const SizedBox(height: Night.space3),
                      NightButton(tx('掃描團購券', 'Scan voucher'), kind: NightButtonKind.ghost, icon: Icons.qr_code_scanner, onPressed: () => scanAndOpen(context)),
                    ])),
                    const SizedBox(height: Night.space6),
                  ],
                ],
                _VoucherSection(price: price, busy: busy),
                const SizedBox(height: Night.space4),
                Text(tx('提早解散不退費，退款依 App Store／Google Play 的流程辦理。', 'No refunds for ending early. Refunds follow App Store / Google Play policies.'), style: Night.caption, textAlign: TextAlign.center),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _VoucherSection extends StatelessWidget {
  final String price;
  final bool busy;
  const _VoucherSection({required this.price, required this.busy});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TourVoucher>>(
      valueListenable: PassStore.vouchers,
      builder: (context, list, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tx('旅行社團購券', 'Agency vouchers'), style: const TextStyle(color: Night.ink, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(tx('每張 $price。買到的券會變成 QR code，發給要帶團的領隊，領隊開團後掃描就能升級。可以看到哪些券已經用掉。', '$price each. Each voucher is a QR code for a leader to scan after starting a group.'),
              style: Night.caption.copyWith(color: Night.inkMuted)),
          const SizedBox(height: Night.space3),
          NightButton(tx('購買一張團購券', 'Buy a voucher'), kind: NightButtonKind.ghost, onPressed: busy ? null : () => PassStore.buy(PassPurpose.voucher)),
        ])),
        if (list.isNotEmpty) ...[
          const SizedBox(height: Night.space4),
          Text(tx('我買的團購券（${list.where((v) => !v.used).length} 張可用）', 'My vouchers (${list.where((v) => !v.used).length} unused)'), style: Night.caption),
          const SizedBox(height: Night.space2),
          for (final v in list)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(v.used ? Icons.check_circle_outline : Icons.confirmation_number_outlined, color: v.used ? Night.inkFaint : Night.cityAmber),
              title: Text(v.code, style: TextStyle(color: v.used ? Night.inkFaint : Night.ink, letterSpacing: 2)),
              subtitle: Text(v.used ? tx('已使用', 'Used') : tx('${md(v.createdAt, deviceTz)} 購買', 'Bought ${md(v.createdAt, deviceTz)}'), style: Night.caption),
              trailing: v.used ? null : const Icon(Icons.qr_code_2, color: Night.ink),
              onTap: v.used ? null : () => _showVoucher(context, v),
            ),
        ],
      ]),
    );
  }

  void _showVoucher(BuildContext context, TourVoucher v) {
    showPanel(context, (ctx, _) => Column(mainAxisSize: MainAxisSize.min, children: [
      Text(tx('團購券', 'Voucher'), style: Night.title),
      const SizedBox(height: Night.space2),
      Text(tx('請領隊開團後，在「升級」裡掃描', 'The leader scans this after starting a group'), style: Night.caption, textAlign: TextAlign.center),
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
          onPressed: () => SharePlus.instance.share(ShareParams(text: tx('旅行團團購券：開團後在「升級」掃描或點這個連結 ${v.link}', 'TourChip voucher: ${v.link}')))),
    ]));
  }
}
