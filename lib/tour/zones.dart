import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n.dart';

/// 時區：集合時間、行程表一律用「集合點的當地時間」（規格：時區）。
/// 伺服器存 IANA 名稱（Asia/Tokyo），App 用 timezone 套件換算成當地的幾點幾分。

bool _ready = false;
String deviceTz = 'Asia/Taipei';

Future<void> initZones() async {
  if (!_ready) {
    tzdata.initializeTimeZones();
    _ready = true;
  }
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    final name = info.identifier;
    if (name.isNotEmpty && _valid(name)) deviceTz = name;
  } catch (_) {}
}

bool _valid(String name) {
  try { tz.getLocation(name); return true; } catch (_) { return false; }
}

tz.Location _loc(String name) {
  try { return tz.getLocation(name.isEmpty ? deviceTz : name); } catch (_) { return tz.getLocation('Asia/Taipei'); }
}

/// 某一刻在某時區的時間
tz.TZDateTime localAt(int ms, String zone) => tz.TZDateTime.fromMillisecondsSinceEpoch(_loc(zone), ms);

/// 某時區的某年某月某日幾點幾分 → 時間戳
int msAt(String zone, int y, int m, int d, int hh, int mm) => tz.TZDateTime(_loc(zone), y, m, d, hh, mm).millisecondsSinceEpoch;

String two(int n) => n.toString().padLeft(2, '0');

/// 「14:30」
String hm(int ms, String zone) {
  final t = localAt(ms, zone);
  return '${two(t.hour)}:${two(t.minute)}';
}

/// 「11/18（三）」
String md(int ms, String zone) {
  final t = localAt(ms, zone);
  final w = weekdayShort(t.weekday);
  return switch (lang) {
    'zh-Hant' || 'zh-Hans' || 'ja' => '${t.month}/${t.day}（$w）',
    'ko' => '${t.month}/${t.day}($w)',
    'en' => '$w ${t.month}/${t.day}',
    _ => '$w ${t.day}/${t.month}',
  };
}

/// 「UTC+9」
String utcLabel(int ms, String zone) {
  final off = localAt(ms, zone).timeZoneOffset;
  final h = off.inMinutes ~/ 60, m = (off.inMinutes % 60).abs();
  return 'UTC${off.isNegative ? '-' : '+'}${h.abs()}${m == 0 ? '' : ':${two(m)}'}';
}

/// 時區的顯示名稱：常用城市用城市名，其他用 IANA 名稱最後一段
String zoneName(String zone) {
  for (final z in commonZones) {
    if (z.$1 == zone) return tx(z.$2, z.$3);
  }
  final last = zone.split('/').last.replaceAll('_', ' ');
  return last.isEmpty ? zone : last;
}

/// 「京都 UTC+9」
String zoneChip(int ms, String zone) => '${zoneName(zone)} ${utcLabel(ms, zone)}';

/// 行程表、集合時可選的時區：台灣旅行團常去的地方（出境、入境都有）
const commonZones = <(String, String, String)>[
  ('Asia/Taipei', '台北', 'Taipei'),
  ('Asia/Tokyo', '東京・京都・大阪', 'Tokyo / Kyoto / Osaka'),
  ('Asia/Seoul', '首爾・釜山', 'Seoul / Busan'),
  ('Asia/Shanghai', '上海・北京', 'Shanghai / Beijing'),
  ('Asia/Hong_Kong', '香港・澳門', 'Hong Kong / Macau'),
  ('Asia/Bangkok', '曼谷・清邁', 'Bangkok / Chiang Mai'),
  ('Asia/Ho_Chi_Minh', '胡志明市・河內', 'Ho Chi Minh / Hanoi'),
  ('Asia/Singapore', '新加坡', 'Singapore'),
  ('Asia/Kuala_Lumpur', '吉隆坡', 'Kuala Lumpur'),
  ('Asia/Manila', '馬尼拉・宿霧', 'Manila / Cebu'),
  ('Asia/Jakarta', '雅加達', 'Jakarta'),
  ('Asia/Makassar', '峇里島', 'Bali'),
  ('Asia/Dubai', '杜拜', 'Dubai'),
  ('Europe/Istanbul', '伊斯坦堡', 'Istanbul'),
  ('Europe/London', '倫敦', 'London'),
  ('Europe/Paris', '巴黎', 'Paris'),
  ('Europe/Rome', '羅馬・米蘭', 'Rome / Milan'),
  ('Europe/Zurich', '蘇黎世', 'Zurich'),
  ('Australia/Sydney', '雪梨・墨爾本', 'Sydney / Melbourne'),
  ('Pacific/Auckland', '奧克蘭', 'Auckland'),
  ('Pacific/Honolulu', '夏威夷', 'Hawaii'),
  ('America/Los_Angeles', '洛杉磯・舊金山', 'Los Angeles / San Francisco'),
  ('America/Vancouver', '溫哥華', 'Vancouver'),
  ('America/New_York', '紐約', 'New York'),
];
