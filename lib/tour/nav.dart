import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import '../ui/night.dart';

/// 導航、攻略連結、撥電話、各國緊急電話。

/// 「帶我走過去」：iPhone 讓團員選 Apple 地圖或 Google 地圖；Android 直接開 Google 地圖。都用步行。
Future<void> walkTo(BuildContext context, double lat, double lng, {String label = ''}) async {
  final dest = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
  final web = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=walking');
  if (!Platform.isIOS) {
    if (!await _open(web) && context.mounted) _failed(context);
    return;
  }
  final apple = Uri.parse('https://maps.apple.com/?daddr=$dest&dirflg=w${label.isEmpty ? '' : '&q=${Uri.encodeComponent(label)}'}');
  final gApp = Uri.parse('comgooglemaps://?daddr=$dest&directionsmode=walking');
  final choice = await showModalBottomSheet<String>(
    context: context, backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Night.space4),
        child: DecoratedBox(
          decoration: BoxDecoration(color: Night.night900, borderRadius: BorderRadius.circular(Night.radiusLg)),
          child: GlassCard(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tx('用哪個地圖帶你走過去？', 'Which map should guide you?'), style: Night.title, textAlign: TextAlign.center),
            const SizedBox(height: Night.space4),
            NightButton(tx('Apple 地圖', 'Apple Maps'), icon: Icons.map_outlined, onPressed: () => Navigator.pop(ctx, 'apple')),
            const SizedBox(height: Night.space2),
            NightButton(tx('Google 地圖', 'Google Maps'), kind: NightButtonKind.ghost, icon: Icons.directions_walk, onPressed: () => Navigator.pop(ctx, 'google')),
            const SizedBox(height: Night.space2),
            NightButton(tx('取消', 'Cancel'), kind: NightButtonKind.text, onPressed: () => Navigator.pop(ctx)),
          ])),
        ),
      ),
    ),
  );
  if (choice == null) return;
  bool ok;
  if (choice == 'apple') {
    ok = await _open(apple);
  } else {
    ok = (await canLaunchUrl(gApp) && await _open(gApp)) || await _open(web);
  }
  if (!ok && context.mounted) _failed(context);
}

/// 攻略連結：用瀏覽器打開（只開 http／https）
Future<void> openLink(BuildContext context, String url) async {
  final u = Uri.tryParse(url);
  if (u == null || (u.scheme != 'http' && u.scheme != 'https')) return _failed(context);
  if (!await _open(u) && context.mounted) _failed(context);
}

/// 撥電話
Future<void> callPhone(BuildContext context, String phone) async {
  final n = phone.replaceAll(RegExp(r'[^0-9+#*]'), '');
  if (n.isEmpty) return;
  if (!await launchUrl(Uri(scheme: 'tel', path: n)) && context.mounted) _failed(context);
}

Future<bool> _open(Uri u) async {
  try {
    return await launchUrl(u, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

void _failed(BuildContext context) => showGlassToast(context, tx('打不開，請稍後再試。', "Couldn't open it."), danger: true, icon: Icons.error_outline);

/// 當地緊急電話（依集合點的時區判斷國家；不認得的時區不顯示，避免給錯號碼）
class EmergencyNumbers {
  final String country, police, ambulance;
  final String? extraLabel, extra;
  const EmergencyNumbers(this.country, this.police, this.ambulance, {this.extraLabel, this.extra});
}

EmergencyNumbers? emergencyFor(String tz) {
  const us = EmergencyNumbers('', '911', '911');
  final t = tz;
  if (t == 'Asia/Taipei') return EmergencyNumbers(tx('台灣', 'Taiwan'), '110', '119');
  if (t == 'Asia/Tokyo') return EmergencyNumbers(tx('日本', 'Japan'), '110', '119');
  if (t == 'Asia/Seoul') return EmergencyNumbers(tx('韓國', 'Korea'), '112', '119');
  if (['Asia/Shanghai', 'Asia/Chongqing', 'Asia/Harbin', 'Asia/Urumqi'].contains(t)) return EmergencyNumbers(tx('中國', 'China'), '110', '120');
  if (t == 'Asia/Hong_Kong') return EmergencyNumbers(tx('香港', 'Hong Kong'), '999', '999');
  if (t == 'Asia/Macau') return EmergencyNumbers(tx('澳門', 'Macau'), '999', '999');
  if (t == 'Asia/Bangkok') return EmergencyNumbers(tx('泰國', 'Thailand'), '191', '1669', extraLabel: tx('觀光警察', 'Tourist police'), extra: '1155');
  if (t == 'Asia/Ho_Chi_Minh' || t == 'Asia/Saigon') return EmergencyNumbers(tx('越南', 'Vietnam'), '113', '115');
  if (t == 'Asia/Singapore') return EmergencyNumbers(tx('新加坡', 'Singapore'), '999', '995');
  if (t == 'Asia/Kuala_Lumpur' || t == 'Asia/Kuching') return EmergencyNumbers(tx('馬來西亞', 'Malaysia'), '999', '999');
  if (['Asia/Jakarta', 'Asia/Pontianak', 'Asia/Makassar', 'Asia/Jayapura'].contains(t)) return EmergencyNumbers(tx('印尼', 'Indonesia'), '110', '118', extraLabel: tx('緊急總機', 'General emergency'), extra: '112');
  if (t == 'Asia/Manila') return EmergencyNumbers(tx('菲律賓', 'Philippines'), '911', '911');
  if (t.startsWith('Australia/')) return EmergencyNumbers(tx('澳洲', 'Australia'), '000', '000');
  if (t == 'Pacific/Auckland') return EmergencyNumbers(tx('紐西蘭', 'New Zealand'), '111', '111');
  if (t == 'Europe/London') return EmergencyNumbers(tx('英國', 'UK'), '999', '999', extraLabel: tx('也可以撥', 'Also'), extra: '112');
  if (t.startsWith('Europe/') && t != 'Europe/Moscow' && t != 'Europe/Istanbul') return EmergencyNumbers(tx('歐洲', 'Europe'), '112', '112');
  if (t == 'Asia/Kolkata' || t == 'Asia/Calcutta') return EmergencyNumbers(tx('印度', 'India'), '112', '112');
  if (['America/Sao_Paulo', 'America/Bahia', 'America/Fortaleza', 'America/Recife', 'America/Manaus', 'America/Belem'].contains(t)) return EmergencyNumbers(tx('巴西', 'Brazil'), '190', '192');
  if (['America/Mexico_City', 'America/Cancun', 'America/Monterrey', 'America/Tijuana'].contains(t)) return EmergencyNumbers(tx('墨西哥', 'Mexico'), '911', '911');
  if (t == 'America/Bogota') return EmergencyNumbers(tx('哥倫比亞', 'Colombia'), '123', '123');
  if (t == 'America/Lima') return EmergencyNumbers(tx('秘魯', 'Peru'), '105', '106');
  if (t == 'America/Santiago') return EmergencyNumbers(tx('智利', 'Chile'), '133', '131');
  if (t.startsWith('America/Argentina/')) return EmergencyNumbers(tx('阿根廷', 'Argentina'), '911', '107');
  if (['America/New_York', 'America/Chicago', 'America/Denver', 'America/Los_Angeles', 'America/Phoenix', 'America/Anchorage', 'Pacific/Honolulu', 'America/Toronto', 'America/Vancouver'].contains(t)) {
    return EmergencyNumbers(tx('美國／加拿大', 'US / Canada'), us.police, us.ambulance);
  }
  return null;
}
