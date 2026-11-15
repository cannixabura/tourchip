import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../ui/night.dart';

/// 旅程回憶卡：團名、日期、天數、走過的集合點（足跡）、旅伴人數，帶 App 名稱與網址的分享圖。
/// 足跡只用行程表上的集合點座標（伺服器不存任何人的移動路線）。
/// 團解散後伺服器的資料就刪了，所以每次更新團的狀態時在手機上存一份摘要，解散後 14 天內還能從首頁打開。
class TripMemory {
  final String name, color, startDate, endDate;
  final int days, people, stops;
  final List<String> places;
  final List<List<double>> points;
  final int savedAt;
  const TripMemory({required this.name, required this.color, required this.startDate, required this.endDate, required this.days, required this.people, required this.stops, required this.places, required this.points, required this.savedAt});

  factory TripMemory.of(TourGroup g) {
    final stops = [...g.stops]..sort((a, b) => a.at.compareTo(b.at));
    final places = <String>[];
    for (final s in stops) {
      final p = s.place.trim();
      if (p.isNotEmpty && !places.contains(p)) places.add(p);
    }
    return TripMemory(
      name: g.name, color: g.color, startDate: g.startDate, endDate: g.endDate, days: g.days, people: g.count, stops: stops.length,
      places: places, points: [for (final s in stops) if (s.lat != null && s.lng != null) [s.lat!, s.lng!]],
      savedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'color': color, 'startDate': startDate, 'endDate': endDate, 'days': days, 'people': people, 'stops': stops, 'places': places, 'points': points, 'savedAt': savedAt};

  static TripMemory? fromJson(Object? j) {
    if (j is! Map) return null;
    try {
      return TripMemory(
        name: '${j['name']}', color: '${j['color']}', startDate: '${j['startDate']}', endDate: '${j['endDate']}',
        days: (j['days'] as num).toInt(), people: (j['people'] as num).toInt(), stops: (j['stops'] as num).toInt(),
        places: [for (final p in j['places'] as List) '$p'],
        points: [for (final p in j['points'] as List) [((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()]],
        savedAt: (j['savedAt'] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  String get dates {
    String f(String d) {
      final x = d.split('-');
      return x.length == 3 ? '${int.tryParse(x[1]) ?? x[1]}/${int.tryParse(x[2]) ?? x[2]}' : d;
    }
    final y = startDate.split('-').first;
    return startDate == endDate ? '$y  ${f(startDate)}' : '$y  ${f(startDate)} – ${f(endDate)}';
  }
}

/// 手機上存的最後一團摘要（解散後還能做回憶卡）
class MemoryStore {
  MemoryStore._();
  static const _key = 'trip_memory';
  static String? _last;
  static int _lastAt = 0;
  static final latest = ValueNotifier<TripMemory?>(null);

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final m = TripMemory.fromJson(jsonDecode(p.getString(_key) ?? 'null'));
      // 14 天後就不再顯示在首頁
      latest.value = m != null && DateTime.now().millisecondsSinceEpoch - m.savedAt < 14 * 86400000 ? m : null;
    } catch (_) {}
  }

  static Future<void> save(TourGroup g) async {
    final m = TripMemory.of(g);
    final raw = jsonEncode({...m.toJson(), 'savedAt': 0});
    // 內容沒變也每小時重寫一次 savedAt：14 天要從最後一次在團裡算起
    final now = DateTime.now().millisecondsSinceEpoch;
    if (raw == _last && now - _lastAt < 3600000) return;
    _last = raw;
    _lastAt = now;
    latest.value = m;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(m.toJson()));
    } catch (_) {}
  }
}

/// 回憶卡畫面：預覽（9:16）＋分享
class MemoryCardScreen extends StatefulWidget {
  final TripMemory memory;
  const MemoryCardScreen({super.key, required this.memory});
  @override
  State<MemoryCardScreen> createState() => _MemoryCardScreenState();
}

class _MemoryCardScreenState extends State<MemoryCardScreen> {
  final _key = GlobalKey();
  var _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final box = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await box.toImage(pixelRatio: 1080 / box.size.width);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return;
      final m = widget.memory;
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(png.buffer.asUint8List(), mimeType: 'image/png', name: 'tourchip_memory.png')],
        text: tx('「${m.name}」${m.days} 天的旅程回憶 · 旅行團 TourChip https://tourchip.web.app', '"${m.name}": ${m.days} days together · TourChip https://tourchip.web.app'),
      ));
    } catch (_) {
      if (mounted) showGlassToast(context, tx('沒辦法產生圖片，請再試一次。', "Couldn't create the image. Please try again."), danger: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Night.night900,
      appBar: AppBar(backgroundColor: Night.night900, foregroundColor: Night.ink, title: Text(tx('旅程回憶卡', 'Trip memory card'), style: Night.title)),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Night.space4, Night.space2, Night.space4, Night.space3),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: RepaintBoundary(key: _key, child: MemoryCard(memory: widget.memory)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Night.space4, 0, Night.space4, Night.space4),
            child: NightButton(tx('分享回憶卡', 'Share card'), icon: Icons.ios_share, expand: true, onPressed: _busy ? null : _share),
          ),
        ]),
      ),
    );
  }
}

/// 回憶卡本體：用相對大小排版（寬度的比例），預覽和輸出的 1080×1920 圖一樣
class MemoryCard extends StatelessWidget {
  final TripMemory memory;
  const MemoryCard({super.key, required this.memory});

  @override
  Widget build(BuildContext context) {
    final m = memory;
    final tint = tourColor(m.color);
    return LayoutBuilder(builder: (context, c) {
      final u = c.maxWidth / 100; // 1u = 寬度的 1%
      TextStyle t(double size, {Color color = Night.ink, FontWeight w = FontWeight.w400, double h = 1.3}) => TextStyle(color: color, fontSize: size * u, fontWeight: w, height: h, decoration: TextDecoration.none);
      final route = m.places.length <= 5 ? m.places : [...m.places.take(4), '…', m.places.last];
      return ClipRRect(
        borderRadius: BorderRadius.circular(4 * u),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(center: Alignment(0, -1.1), radius: 1.5, colors: [Color(0xFF3A1F7A), Color(0xFF141A4A), Night.night900], stops: [0, 0.45, 1]),
          ),
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _Stars())),
            Padding(
              padding: EdgeInsets.fromLTRB(8 * u, 9 * u, 8 * u, 7 * u),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tx('旅程回憶', 'TRIP MEMORY'), style: t(3.4, color: tint, w: FontWeight.w600).copyWith(letterSpacing: 0.4 * u)),
                SizedBox(height: 2 * u),
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(colors: [Color(0xFFD9A8FF), Color(0xFF8FDCFF)]).createShader(r),
                  child: Text(m.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: t(9.5, w: FontWeight.w800, h: 1.2)),
                ),
                SizedBox(height: 2 * u),
                Text(m.dates, style: t(4, color: Night.inkMuted)),
                SizedBox(height: 5 * u),
                // 足跡：行程表上的集合點連成一條發光的線
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Night.night800.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(4 * u),
                      border: Border.all(color: Night.glassLine.withValues(alpha: 0.5), width: 0.3 * u),
                    ),
                    child: CustomPaint(painter: _Footprint(m.points, tint, u), child: const SizedBox.expand()),
                  ),
                ),
                SizedBox(height: 5 * u),
                Row(children: [
                  _Stat('${m.days}', tx('天', m.days == 1 ? 'day' : 'days'), t),
                  _Stat('${m.stops}', tx('個集合點', m.stops == 1 ? 'stop' : 'stops'), t),
                  _Stat('${m.people}', tx('位旅伴', m.people == 1 ? 'traveler' : 'travelers'), t),
                ]),
                if (route.isNotEmpty) ...[
                  SizedBox(height: 4 * u),
                  Text(route.join('  →  '), maxLines: 3, overflow: TextOverflow.ellipsis, style: t(3.6, color: Night.ink, h: 1.5)),
                ],
                SizedBox(height: 5 * u),
                Container(height: 0.25 * u, color: Night.glassLine.withValues(alpha: 0.6)),
                SizedBox(height: 3.5 * u),
                Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(2.4 * u), child: Image.asset('assets/images/app_icon_256.png', width: 10 * u, height: 10 * u)),
                  SizedBox(width: 3 * u),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tx('旅行團 TourChip', 'TourChip'), style: t(4, w: FontWeight.w700)),
                      Text('tourchip.web.app', style: t(3.2, color: const Color(0xFF8FDCFF))),
                    ]),
                  ),
                  Text(tx('一起出發', 'Travel together'), style: t(3.2, color: Night.inkFaint)),
                ]),
              ]),
            ),
          ]),
        ),
      );
    });
  }
}

class _Stat extends StatelessWidget {
  final String n, label;
  final TextStyle Function(double, {Color color, FontWeight w, double h}) t;
  const _Stat(this.n, this.label, this.t);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n, style: t(9, w: FontWeight.w800, h: 1.1)),
        Text(label, style: t(3.4, color: Night.inkMuted)),
      ]),
    );
  }
}

/// 足跡：座標換成卡片裡的位置（等比例、置中），發光的線＋每個集合點一個亮點，起點較大
class _Footprint extends CustomPainter {
  final List<List<double>> pts;
  final Color tint;
  final double u;
  _Footprint(this.pts, this.tint, this.u);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 30 * u || size.height < 30 * u) return;
    canvas.clipRect(Offset.zero & size);
    if (pts.isEmpty) {
      final p = Paint()..color = tint.withValues(alpha: 0.8);
      canvas.drawCircle(size.center(Offset.zero), 2 * u, p..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * u));
      canvas.drawCircle(size.center(Offset.zero), 1.2 * u, Paint()..color = Colors.white);
      return;
    }
    // 經度依緯度縮放，形狀才不會被拉長
    final midLat = pts.map((p) => p[0]).reduce((a, b) => a + b) / pts.length;
    final k = cos(midLat * pi / 180);
    final xs = pts.map((p) => p[1] * k).toList(), ys = pts.map((p) => -p[0]).toList();
    final minX = xs.reduce(min), maxX = xs.reduce(max), minY = ys.reduce(min), maxY = ys.reduce(max);
    final pad = 10 * u;
    final w = max(maxX - minX, 1e-6), h = max(maxY - minY, 1e-6);
    final s = min((size.width - 2 * pad) / w, (size.height - 2 * pad) / h);
    final ox = (size.width - w * s) / 2, oy = (size.height - h * s) / 2;
    final one = maxX - minX < 1e-6 && maxY - minY < 1e-6;
    final at = [for (var i = 0; i < pts.length; i++) one ? size.center(Offset.zero) : Offset(ox + (xs[i] - minX) * s, oy + (ys[i] - minY) * s)];

    if (at.length > 1) {
      final path = Path()..moveTo(at[0].dx, at[0].dy);
      for (var i = 1; i < at.length; i++) {
        // 微彎的線，像手繪的路線
        final a = at[i - 1], b = at[i];
        final mid = (a + b) / 2;
        final n = Offset(-(b.dy - a.dy), b.dx - a.dx) * 0.12;
        path.quadraticBezierTo(mid.dx + n.dx, mid.dy + n.dy, b.dx, b.dy);
      }
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4 * u..color = tint.withValues(alpha: 0.35)..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.6 * u));
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.7 * u..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: 0.85));
    }
    for (var i = 0; i < at.length; i++) {
      final big = i == 0 || i == at.length - 1;
      canvas.drawCircle(at[i], (big ? 2.6 : 1.6) * u, Paint()..color = tint..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.4 * u));
      canvas.drawCircle(at[i], (big ? 1.3 : 0.8) * u, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_Footprint old) => old.pts != pts || old.tint != tint || old.u != u;
}

/// 背景的小星星（固定種子，每次畫一樣）
class _Stars extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(7);
    final p = Paint();
    for (var i = 0; i < 70; i++) {
      p.color = Colors.white.withValues(alpha: 0.15 + r.nextDouble() * 0.45);
      canvas.drawCircle(Offset(r.nextDouble() * size.width, r.nextDouble() * size.height), 0.4 + r.nextDouble() * size.width / 400, p);
    }
  }

  @override
  bool shouldRepaint(_Stars old) => false;
}
