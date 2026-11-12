import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/nav.dart';
import 'day_screen.dart';
import 'info_screen.dart';

/// 當地人看得懂的語言：依現在所在地的時區（集合點、行程表）判斷；不認得的地方用英文
String localLangFor(String tz) {
  if (const ['Asia/Taipei', 'Asia/Hong_Kong', 'Asia/Macau'].contains(tz)) return 'zh-Hant';
  if (const ['Asia/Shanghai', 'Asia/Chongqing', 'Asia/Harbin', 'Asia/Urumqi'].contains(tz)) return 'zh-Hans';
  if (tz == 'Asia/Tokyo') return 'ja';
  if (tz == 'Asia/Seoul') return 'ko';
  if (tz == 'Asia/Bangkok') return 'th';
  if (tz == 'Asia/Ho_Chi_Minh' || tz == 'Asia/Saigon') return 'vi';
  if (tz == 'Asia/Kuala_Lumpur' || tz == 'Asia/Kuching') return 'ms';
  if (const ['Asia/Jakarta', 'Asia/Pontianak', 'Asia/Makassar', 'Asia/Jayapura'].contains(tz)) return 'id';
  if (const ['Asia/Kolkata', 'Asia/Calcutta'].contains(tz)) return 'hi';
  if (tz.startsWith('America/Sao_Paulo') || const ['Europe/Lisbon', 'America/Bahia', 'America/Fortaleza', 'America/Recife', 'America/Manaus', 'America/Belem'].contains(tz)) return 'pt';
  if (const ['Europe/Madrid', 'Atlantic/Canary', 'America/Mexico_City', 'America/Cancun', 'America/Monterrey', 'America/Tijuana', 'America/Bogota', 'America/Lima', 'America/Santiago', 'America/Caracas', 'America/Guayaquil', 'America/La_Paz', 'America/Montevideo', 'America/Asuncion', 'America/Panama', 'America/Costa_Rica', 'America/Guatemala', 'America/Havana', 'America/Santo_Domingo', 'America/Puerto_Rico'].contains(tz) || tz.startsWith('America/Argentina/')) return 'es';
  return 'en';
}

/// 求助卡：走散時拿給當地人看。用當地語言寫「我和旅行團走散了、請打給領隊、我住在哪裡」，
/// 下面附上團員自己的語言。資料來自團體資訊（領隊電話、旅行社電話）與今晚的飯店。
Future<void> openHelpCard(BuildContext context, TourGroup g) =>
    Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => HelpCardScreen(group: g)));

class HelpCardScreen extends StatefulWidget {
  final TourGroup group;
  const HelpCardScreen({super.key, required this.group});
  @override
  State<HelpCardScreen> createState() => _HelpCardScreenState();
}

class _HelpCardScreenState extends State<HelpCardScreen> {
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // 拿給別人看的時候螢幕不要暗掉
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  /// 卡片上的句子（指定語言）
  List<String> _lines(String l, TourGroup g, String phone, TourHotel? hotel) => [
        txIn(l, '我和旅行團走散了，需要幫忙。', 'I got separated from my tour group and need help.'),
        txIn(l, '團名：${g.name}', 'Group: ${g.name}'),
        if (g.myNo != null && g.myNo! > 0) txIn(l, '我是 ${g.myNo} 號團員', 'I am member No. ${g.myNo}'),
        if (phone.isNotEmpty) txIn(l, '請幫我打電話給領隊：$phone', 'Please call my tour leader: $phone'),
        if (hotel != null && hotel.name.isNotEmpty) txIn(l, '我住的飯店：${hotel.name}', 'My hotel: ${hotel.name}'),
      ];

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final local = localLangFor(InfoScreen.hereTz(g));
    final hotel = g.dayCard(ymd(InfoScreen.today(g)))?.hotel;
    final phone = g.emergency.phone.isNotEmpty ? g.emergency.phone : g.emergency.agencyPhone;
    final emergency = emergencyFor(InfoScreen.hereTz(g));
    final mine = lang;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0,
        title: Text(tx('求助卡', 'Help card'), style: const TextStyle(color: Colors.black87)),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          Text(tx('拿給當地人看，請他幫你打電話給領隊。', 'Show this to someone nearby and ask them to call your leader.'),
              style: const TextStyle(color: Colors.black54, fontSize: 14)),
          const SizedBox(height: 16),
          // 當地語言（大字）
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFC94D), width: 2)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(txIn(local, '請幫幫我', 'Please help me'), style: const TextStyle(color: Colors.black, fontSize: 30, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final s in _lines(local, g, phone, hotel))
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(s, style: const TextStyle(color: Colors.black, fontSize: 21, height: 1.35))),
              if (hotel != null && hotel.addr.isNotEmpty)
                Text(hotel.addr, style: const TextStyle(color: Colors.black, fontSize: 19, height: 1.35)),
              if (phone.isEmpty)
                Text(txIn(local, '（領隊還沒填電話）', '(No leader phone number yet)'), style: const TextStyle(color: Colors.black45, fontSize: 15)),
            ]),
          ),
          // 自己的語言（小字，確認上面寫了什麼）
          if (mine != local) ...[
            const SizedBox(height: 14),
            Text(tx('上面寫的是：', 'The card says:'), style: const TextStyle(color: Colors.black45, fontSize: 13)),
            const SizedBox(height: 4),
            for (final s in _lines(mine, g, phone, hotel)) Text(s, style: const TextStyle(color: Colors.black54, fontSize: 14)),
          ],
          const SizedBox(height: 20),
          if (phone.isNotEmpty)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1F7A4D), padding: const EdgeInsets.symmetric(vertical: 14), shape: const StadiumBorder()),
              onPressed: () => callPhone(context, phone),
              icon: const Icon(Icons.call),
              label: Text(tx('撥給領隊 $phone', 'Call leader $phone'), style: const TextStyle(fontSize: 16)),
            ),
          if (hotel != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 14), shape: const StadiumBorder()),
              onPressed: () => showDriverCard(context, hotel),
              icon: const Icon(Icons.local_taxi_outlined),
              label: Text(tx('坐計程車回飯店：給司機看', 'Taxi to the hotel: show the driver'), style: const TextStyle(fontSize: 15)),
            ),
          ],
          if (emergency != null) ...[
            const SizedBox(height: 18),
            Text(tx('有危險請直接撥打當地緊急電話：', 'In danger? Call local emergency services:'), style: const TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              ActionChip(label: Text(tx('報警 ${emergency.police}', 'Police ${emergency.police}')), onPressed: () => callPhone(context, emergency.police)),
              if (emergency.ambulance != emergency.police)
                ActionChip(label: Text(tx('救護車 ${emergency.ambulance}', 'Ambulance ${emergency.ambulance}')), onPressed: () => callPhone(context, emergency.ambulance)),
            ]),
          ],
          const SizedBox(height: 16),
          Text(tx('也可以在團裡按「我迷路了」，把位置傳給領隊。', 'You can also tap "I\'m lost" to send your location to the leader.'),
              style: const TextStyle(color: Colors.black45, fontSize: 13)),
        ]),
      ),
    );
  }
}
