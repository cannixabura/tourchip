import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../l10n.dart';
import '../ui/night.dart';
import 'model.dart';
import 'zones.dart';

/// 每天的天氣：用那一天集合點的座標向 Open-Meteo 查預報（免費、不需要金鑰；只送集合點座標，不送任何人的位置）。
/// 預報最多 16 天；同一個地點 3 小時內不重查。
class DayWeather {
  final int code;
  final double hi, lo;
  final int rain; // 降雨機率 %
  const DayWeather(this.code, this.hi, this.lo, this.rain);

  /// WMO 天氣代碼 → 文字
  String get label => switch (code) {
        0 => tx('晴', 'Clear'),
        1 || 2 => tx('晴時多雲', 'Partly cloudy'),
        3 => tx('陰', 'Cloudy'),
        45 || 48 => tx('霧', 'Fog'),
        >= 51 && <= 57 => tx('毛毛雨', 'Drizzle'),
        >= 61 && <= 67 => tx('雨', 'Rain'),
        >= 71 && <= 77 => tx('雪', 'Snow'),
        >= 80 && <= 82 => tx('陣雨', 'Showers'),
        85 || 86 => tx('陣雪', 'Snow showers'),
        >= 95 => tx('雷雨', 'Thunderstorm'),
        _ => tx('多雲', 'Cloudy'),
      };

  IconData get icon => switch (code) {
        0 => Icons.wb_sunny_outlined,
        1 || 2 => Icons.wb_cloudy_outlined,
        3 || 45 || 48 => Icons.cloud_outlined,
        >= 71 && <= 77 || 85 || 86 => Icons.ac_unit,
        >= 95 => Icons.thunderstorm_outlined,
        >= 51 => Icons.umbrella_outlined,
        _ => Icons.cloud_outlined,
      };

  /// 帶傘、外套、防曬的提醒（可能有好幾個）
  List<String> get tips => [
        if (rain >= 50 || (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95) tx('記得帶傘', 'Bring an umbrella'),
        if ((code >= 71 && code <= 77) || code == 85 || code == 86) tx('路面可能結冰，穿防滑的鞋', 'Roads may be icy; wear grippy shoes'),
        if (lo <= 5)
          tx('很冷，穿厚外套、戴手套', 'Very cold: heavy coat and gloves')
        else if (lo <= 14)
          tx('早晚涼，帶件外套', 'Cool mornings and evenings: bring a jacket'),
        if (hi >= 30) tx('很熱，防曬、多喝水', 'Hot: sunscreen and water'),
      ];
}

class Weather {
  Weather._();
  static final _cache = <String, (DateTime, Map<String, DayWeather>)>{};
  static final _inflight = <String, Future<Map<String, DayWeather>>>{};

  /// 某個地點、某一天（當地日期 yyyy-mm-dd）的預報；查不到（太遠的日子、沒網路）回 null
  static Future<DayWeather?> of(double lat, double lng, String date) async {
    final key = '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.$1).inHours < 3) return hit.$2[date];
    final days = await (_inflight[key] ??= _fetch(lat, lng).whenComplete(() => _inflight.remove(key)));
    return days[date];
  }

  static Future<Map<String, DayWeather>> _fetch(double lat, double lng) async {
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': lat.toStringAsFixed(3), 'longitude': lng.toStringAsFixed(3),
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
        'timezone': 'auto', 'forecast_days': '16',
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return const {};
      final d = (jsonDecode(r.body) as Map)['daily'] as Map;
      final time = d['time'] as List, code = d['weather_code'] as List, hi = d['temperature_2m_max'] as List, lo = d['temperature_2m_min'] as List, rain = d['precipitation_probability_max'] as List;
      final out = <String, DayWeather>{};
      for (var i = 0; i < time.length; i++) {
        if (code[i] == null || hi[i] == null || lo[i] == null) continue;
        out['${time[i]}'] = DayWeather((code[i] as num).toInt(), (hi[i] as num).toDouble(), (lo[i] as num).toDouble(), (rain[i] as num?)?.toInt() ?? 0);
      }
      _cache['${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}'] = (DateTime.now(), out);
      return out;
    } catch (_) {
      return const {};
    }
  }

  /// 這一天在哪裡：當天第一個有座標的集合點；沒有就用前一個有座標的（晚上住的地方），再沒有就用之後第一個
  static TourStop? placeFor(List<TourStop> stops, DateTime day) {
    bool same(TourStop s) {
      final t = localAt(s.at, s.tz);
      return t.year == day.year && t.month == day.month && t.day == day.day;
    }
    final withPos = stops.where((s) => s.lat != null && s.lng != null).toList()..sort((a, b) => a.at.compareTo(b.at));
    final today = withPos.where(same).firstOrNull;
    if (today != null) return today;
    final start = DateTime(day.year, day.month, day.day);
    final before = withPos.where((s) => localAt(s.at, s.tz).isBefore(start)).lastOrNull;
    return before ?? withPos.where((s) => localAt(s.at, s.tz).isAfter(start)).firstOrNull;
  }
}

/// 行程表每天上方的天氣列：圖示、天氣、高低溫、降雨機率，下面是提醒
class WeatherLine extends StatelessWidget {
  final List<TourStop> stops;
  final DateTime day;
  const WeatherLine({super.key, required this.stops, required this.day});

  @override
  Widget build(BuildContext context) {
    final at = Weather.placeFor(stops, day);
    if (at == null) return const SizedBox.shrink();
    final date = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return FutureBuilder<DayWeather?>(
      key: ValueKey('${at.id}$date'),
      future: Weather.of(at.lat!, at.lng!, date),
      builder: (context, snap) {
        final w = snap.data;
        if (w == null) return const SizedBox.shrink();
        final tips = w.tips;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Night.night700, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(w.icon, color: Night.auroraBlue, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${w.label}  ', style: const TextStyle(color: Night.ink, fontSize: 16, fontWeight: FontWeight.w600)),
                  TextSpan(text: '${w.lo.round()}–${w.hi.round()}°C', style: const TextStyle(color: Night.ink, fontSize: 16)),
                  TextSpan(text: '  ${tx('降雨 ${w.rain}%', 'Rain ${w.rain}%')}', style: const TextStyle(color: Night.inkMuted, fontSize: 13)),
                ])),
              ),
            ]),
            if (at.place.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 36),
                child: Text(tx('${at.place}一帶的預報', 'Forecast near ${at.place}'), style: const TextStyle(color: Color(0xFF8C89B0), fontSize: 12)),
              ),
            if (tips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 36),
                child: Text(tips.join(' · '), style: const TextStyle(color: Color(0xFFFFB547), fontSize: 13)),
              ),
          ]),
        );
      },
    );
  }
}
