import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../ui/night.dart';

/// 3D 地圖上一個人的圖示：上面是氣泡（可以沒有），中間是大頭貼（光環是身分色），下面是稱呼。
/// 整張用 Flutter 畫成圖片再交給地圖，中文氣泡才不受地圖字型限制。
/// 大頭貼的中心就是圖片的中心，地圖用 icon-anchor center 把它對準那個人的位置。
class PersonMarker {
  PersonMarker._();
  static final Map<String, ui.Image?> _photos = {};

  static Future<ui.Image?> _photo(String url) async {
    if (url.isEmpty) return null;
    if (_photos.containsKey(url)) return _photos[url];
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return _photos[url] = null;
      final codec = await ui.instantiateImageCodec(r.bodyBytes, targetWidth: 160);
      return _photos[url] = (await codec.getNextFrame()).image;
    } catch (_) {
      return _photos[url] = null;
    }
  }

  static TextPainter _text(String s, double size, Color color, {double maxWidth = 200, int lines = 1, FontWeight weight = FontWeight.w500}) {
    return TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size, fontWeight: weight, height: 1.3, fontFamilyFallback: const ['PingFang TC', 'Noto Sans TC'],
          shadows: const [Shadow(color: Color(0xCC070B1F), blurRadius: 3)])),
      textDirection: TextDirection.ltr, maxLines: lines, ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }

  static const av = 31.0, gap = 5.0; // 大頭貼直徑（原本 46，縮小 1/3）
  static const _iconW = 18.0; // 翻譯過的氣泡前面的小圖示

  /// 圖示裡看得到的部分（氣泡、大頭貼、稱呼），座標以大頭貼中心為原點。
  /// 地圖用它判斷點到的是不是氣泡，集合點的旗子也用它避開大家的頭像和氣泡。
  static ({Rect? bubble, Rect avatar, Rect name}) shapes({required String label, required String bubble, bool translated = false}) {
    final name = _text(label, 12, Night.ink, maxWidth: 140);
    final bub = bubble.isEmpty ? null : _text(bubble, 14, Night.ink, maxWidth: 170, lines: 2);
    final bubW = bub == null ? 0.0 : bub.width + 24 + (translated ? _iconW : 0), bubH = bub == null ? 0.0 : bub.height + 14;
    return (
      bubble: bub == null ? null : Rect.fromLTWH(-bubW / 2, -av / 2 - gap - 8 - bubH, bubW, bubH + 8),
      avatar: Rect.fromCircle(center: Offset.zero, radius: av / 2 + 2),
      name: Rect.fromLTWH(-name.width / 2, av / 2 + gap, name.width, name.height),
    );
  }

  /// PNG：dpr 是螢幕倍率（地圖會用同一個倍率把圖縮回邏輯大小）
  /// translated：氣泡顯示的是翻譯（前面加翻譯小圖示、外框改藍色）
  static Future<Uint8List> render({required String label, required String bubble, required String avatar, required Color ring, required double dpr, bool me = false, bool translated = false}) async {
    final photo = await _photo(avatar);
    final name = _text(label, 12, me ? Night.auroraBlue : Night.ink, maxWidth: 140);
    final bub = bubble.isEmpty ? null : _text(bubble, 14, Night.ink, maxWidth: 170, lines: 2);
    final iconW = translated ? _iconW : 0.0;
    final bubW = bub == null ? 0.0 : bub.width + 24 + iconW, bubH = bub == null ? 0.0 : bub.height + 14;
    final top = bub == null ? 0.0 : bubH + 8 + gap; // 氣泡＋尾巴
    final bottom = gap + name.height;
    final half = max(top, bottom); // 上下等高，大頭貼才會在正中央
    final w = [bubW, name.width + 8, av + 16].reduce(max) + 8;
    final h = half * 2 + av;
    final cx = w / 2, cy = half + av / 2;

    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(dpr);

    // 氣泡
    if (bub != null) {
      final y0 = half - top;
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(cx - bubW / 2, y0, bubW, bubH), const Radius.circular(14));
      final tail = Path()..moveTo(cx - 7, y0 + bubH - 1)..lineTo(cx, y0 + bubH + 8)..lineTo(cx + 7, y0 + bubH - 1)..close();
      final fill = Paint()..color = const Color(0xE61A1F4A);
      c.drawRRect(r, fill);
      c.drawPath(tail, fill);
      c.drawRRect(r, Paint()..color = (translated ? Night.auroraBlue : ring).withValues(alpha: 0.85)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      final tx0 = cx - (bub.width + iconW) / 2;
      if (translated) {
        final icon = TextPainter(
          text: TextSpan(text: String.fromCharCode(Icons.translate.codePoint), style: TextStyle(fontSize: 13, fontFamily: Icons.translate.fontFamily, package: Icons.translate.fontPackage, color: Night.auroraBlue)),
          textDirection: TextDirection.ltr,
        )..layout();
        icon.paint(c, Offset(tx0, y0 + bubH / 2 - icon.height / 2));
      }
      bub.paint(c, Offset(tx0 + iconW, y0 + 7));
    }

    // 大頭貼：光暈＋光環＋照片（沒有照片就畫人形）
    c.drawCircle(Offset(cx, cy), av / 2 + 4, Paint()..color = ring.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    c.drawCircle(Offset(cx, cy), av / 2, Paint()..color = ring);
    final inner = Rect.fromCircle(center: Offset(cx, cy), radius: av / 2 - 2);
    c.save();
    c.clipPath(Path()..addOval(inner));
    c.drawRect(inner, Paint()..color = Night.night800);
    if (photo != null) {
      final s = min(photo.width, photo.height).toDouble();
      final src = Rect.fromCenter(center: Offset(photo.width / 2, photo.height / 2), width: s, height: s);
      c.drawImageRect(photo, src, inner, Paint()..filterQuality = FilterQuality.medium);
    } else {
      final icon = TextPainter(
        text: TextSpan(text: String.fromCharCode(Icons.person.codePoint), style: TextStyle(fontSize: av * 0.6, fontFamily: Icons.person.fontFamily, package: Icons.person.fontPackage, color: Night.inkMuted)),
        textDirection: TextDirection.ltr,
      )..layout();
      icon.paint(c, Offset(cx - icon.width / 2, cy - icon.height / 2));
    }
    c.restore();

    // 稱呼
    name.paint(c, Offset(cx - name.width / 2, cy + av / 2 + gap));

    final img = await rec.endRecording().toImage((w * dpr).ceil(), (h * dpr).ceil());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  }
}
