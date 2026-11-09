import 'dart:math';

import 'package:flutter/material.dart';

import '../ui/night.dart';

/// 集合點標記：長桿三角旗（團色，會飄揚）＋地面彩色光圈（顏色沿著光圈流動）。
/// 錨點是光圈中心＝widget 的 [MeetFlag.anchor]（底部中央往上 [ringH]/2）。
/// 系統開啟「減少動態效果」時旗子和光圈都靜止。
class MeetFlag extends StatefulWidget {
  final Color tint;
  final double scale;
  const MeetFlag({super.key, required this.tint, this.scale = 1});

  static const width = 150.0, height = 170.0, ringH = 26.0;
  /// 光圈中心在 widget 裡的位置（用來把它對準地圖上的點）
  static Offset anchor(double scale) => Offset(width / 2 * scale, (height - ringH / 2) * scale);

  @override
  State<MeetFlag> createState() => _MeetFlagState();
}

class _MeetFlagState extends State<MeetFlag> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _t.stop();
      _t.value = 0.1;
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return IgnorePointer(
      child: SizedBox(
        width: MeetFlag.width * s, height: MeetFlag.height * s,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _t,
            builder: (_, _) => CustomPaint(painter: _FlagPainter(widget.tint, _t.value, s)),
          ),
        ),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  final Color tint;
  final double t; // 0..1，6 秒一圈
  final double s;
  _FlagPainter(this.tint, this.t, this.s);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(s);
    const w = MeetFlag.width, h = MeetFlag.height, rh = MeetFlag.ringH;
    final cx = w / 2, cy = h - rh / 2;

    // ---- 地面光圈：柔光＋流動的彩色圈 ----
    final ringRect = Rect.fromCenter(center: Offset(cx, cy), width: 76, height: rh - 4);
    canvas.drawOval(ringRect.inflate(10), Paint()
      ..shader = RadialGradient(colors: [tint.withValues(alpha: 0.45), tint.withValues(alpha: 0)]).createShader(ringRect.inflate(10))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    final colors = [tint, Night.auroraBlue, Night.moodCalm, Night.cityAmber, Night.knockPink, tint];
    final sweep = SweepGradient(colors: colors, transform: GradientRotation(t * 2 * pi * 2));
    // 外層光暈
    canvas.drawOval(ringRect, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..shader = sweep.createShader(ringRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawOval(ringRect, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = sweep.createShader(ringRect));

    // ---- 旗桿 ----
    const poleTop = 8.0, poleW = 4.0;
    final poleRect = RRect.fromRectAndRadius(Rect.fromLTRB(cx - poleW / 2, poleTop, cx + poleW / 2, cy), const Radius.circular(2));
    canvas.drawRRect(poleRect.inflate(2), Paint()..color = tint.withValues(alpha: 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawRRect(poleRect, Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFCFE9FF)]).createShader(poleRect.outerRect));
    canvas.drawCircle(Offset(cx, poleTop), 4, Paint()..color = Colors.white);

    // ---- 三角旗：沿著旗面的正弦波飄動，離旗桿越遠擺得越大 ----
    const fw = 64.0, fh = 42.0, steps = 18;
    final x0 = cx + poleW / 2, y0 = poleTop + 2;
    final phase = t * 2 * pi * 6; // 一秒一次
    double wave(double u) => sin(phase - u * pi * 1.6) * 5 * u;
    final top = <Offset>[], bottom = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final u = i / steps;
      final x = x0 + u * fw * (1 - 0.04 * sin(phase - u * pi) * u); // 擺動時旗面略縮短
      final dy = wave(u);
      top.add(Offset(x, y0 + u * fh / 2 + dy));
      bottom.add(Offset(x, y0 + fh - u * fh / 2 + dy));
    }
    final path = Path()..moveTo(top.first.dx, top.first.dy);
    for (final p in top.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in bottom.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    final bounds = Rect.fromLTWH(x0, y0 - 6, fw, fh + 12);
    canvas.drawPath(path, Paint()..color = tint.withValues(alpha: 0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    final light = Color.lerp(tint, Colors.white, 0.35)!;
    canvas.drawPath(path, Paint()..shader = LinearGradient(colors: [light, tint]).createShader(bounds));
    // 波紋的明暗：每一段依斜率加一點亮或暗，看起來有起伏
    for (var i = 0; i < steps; i++) {
      final slope = wave((i + 1) / steps) - wave(i / steps);
      final seg = Path()
        ..moveTo(top[i].dx, top[i].dy)
        ..lineTo(top[i + 1].dx, top[i + 1].dy)
        ..lineTo(bottom[i + 1].dx, bottom[i + 1].dy)
        ..lineTo(bottom[i].dx, bottom[i].dy)
        ..close();
      final a = (slope.abs() * 0.12).clamp(0.0, 0.28);
      canvas.drawPath(seg, Paint()..color = (slope > 0 ? Colors.black : Colors.white).withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(_FlagPainter old) => old.t != t || old.tint != tint || old.s != s;
}
