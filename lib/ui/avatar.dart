import 'package:flutter/material.dart';

import 'night.dart';

/// 圓形大頭貼：有網址顯示照片，沒有就顯示人形圖示；外圈是極光色光環
class Avatar extends StatelessWidget {
  final String url;
  final double size;
  final Color ring;
  const Avatar(this.url, {super.key, this.size = 40, this.ring = Night.auroraViolet});

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.person, color: Night.inkMuted, size: size * 0.55);
    return Container(
      width: size, height: size,
      padding: EdgeInsets.all(size > 60 ? 3 : 1.5),
      decoration: BoxDecoration(shape: BoxShape.circle, color: ring, boxShadow: [BoxShadow(color: ring.withValues(alpha: 0.45), blurRadius: size / 4)]),
      child: ClipOval(
        child: ColoredBox(
          color: Night.night800,
          child: url.isEmpty
              ? Center(child: fallback)
              : Image.network(url, fit: BoxFit.cover, width: size, height: size, errorBuilder: (_, _, _) => Center(child: fallback)),
        ),
      ),
    );
  }
}
