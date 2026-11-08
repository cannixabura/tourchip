import 'package:flutter/material.dart';

/// 字距（旅行團目前只有中文、英文，直接回傳）
double ls(double v) => v;

/// 城市低語「夜光設計系統」的 Flutter 版本（旅行團沿用同一套）。
/// 數值與設計系統的 tokens.json 一致：https://claude.ai/artifact/TSf7xkrr7ZBbPfkFGqGAg4
class Night {
  Night._();

  // ---------- 色彩 ----------
  static const night900 = Color(0xFF070B1F); // App 背景
  static const night800 = Color(0xFF0E1433); // 地圖地面、聊天室
  static const night700 = Color(0xFF1A1F4A); // 輸入框、列表列
  static const night600 = Color(0xFF2A2F66); // 分隔線、按下狀態
  static const glassFill = Color(0xB81A1F4A); // rgba(26,31,74,0.72)
  static const glassLine = Color(0x61C4AAFF); // rgba(196,170,255,0.38)
  static const ink = Color(0xFFF3F0FF);
  static const inkMuted = Color(0xFFB9B6D6);
  static const inkFaint = Color(0xFF8C89B0);
  static const auroraViolet = Color(0xFFB44CFF); // 亮漸層：標題、發光邊框、焦點框；不可當白字底色
  static const auroraBlue = Color(0xFF4FC3F7);
  static const deepViolet = Color(0xFF8E2DE2); // 深漸層：按鈕底色，白字 5.8:1
  static const deepBlue = Color(0xFF2A63D4);
  static const onDeep = Color(0xFFFFFFFF);
  static const knockPink = Color(0xFFFF5FD2);
  static const cityAmber = Color(0xFFFFB547);
  static const danger = Color(0xFFFF6B7A);

  // 心情顏色：依心情文字的關鍵字決定，只用在氣泡邊框、光暈、定位點與漣漪
  static const moodJoy = Color(0xFFFFD54A);
  static const moodSad = Color(0xFF5AB8FF);
  static const moodAngry = Color(0xFFFF8A5C);
  static const moodCalm = Color(0xFF4DE3A0);
  static const moodPassion = Color(0xFFFF9F45);
  static const moodLove = Color(0xFFFF6BD6);
  static const moodDefault = Color(0xFFA99CFF);
  static const shadowInk = Color(0xFF6F6C8F);

  static const brightGradient = LinearGradient(colors: [auroraViolet, auroraBlue]);
  static const deepGradient = LinearGradient(colors: [deepViolet, deepBlue]);

  // ---------- 形狀與間距 ----------
  static const radiusSm = 10.0;
  static const radiusMd = 16.0;
  static const radiusLg = 24.0;
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space6 = 24.0;
  static const space8 = 32.0;

  // ---------- 光與陰影 ----------
  static const lift = BoxShadow(color: Color(0x8C000000), blurRadius: 48, offset: Offset(0, 18));
  static const glowViolet = BoxShadow(color: Color(0x73B44CFF), blurRadius: 24);

  // ---------- 字級 ----------
  static TextStyle get title => TextStyle(color: ink, fontSize: 20, height: 1.4, fontWeight: FontWeight.w500, letterSpacing: ls(1));
  static const body = TextStyle(color: inkMuted, fontSize: 15, height: 1.6);
  static TextStyle get label => TextStyle(fontSize: 15, height: 1.33, fontWeight: FontWeight.w600, letterSpacing: ls(1));
  static TextStyle get caption => TextStyle(color: inkFaint, fontSize: 12, height: 1.33, letterSpacing: ls(1));
}

/// 浮在地圖上的玻璃卡片。`glow` 只給需要使用者立刻決定的那一張（敲門、進場）。
class GlassCard extends StatelessWidget {
  final Widget child;
  final bool glow;
  final EdgeInsetsGeometry padding;
  const GlassCard({super.key, required this.child, this.glow = false, this.padding = const EdgeInsets.all(Night.space6)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Night.glassFill,
        borderRadius: BorderRadius.circular(Night.radiusLg),
        border: Border.all(color: Night.glassLine),
        boxShadow: [Night.lift, if (glow) Night.glowViolet],
      ),
      child: child,
    );
  }
}

enum NightButtonKind { primary, ghost, warm, danger, text }

/// 按鈕：primary 是深漸層實心（每個畫面只有一個），其餘是線框或純文字。
class NightButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final NightButtonKind kind;
  final IconData? icon;
  final bool expand;
  const NightButton(this.label, {super.key, required this.onPressed, this.kind = NightButtonKind.primary, this.icon, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final Color fg = !enabled
        ? Night.inkFaint
        : switch (kind) {
            NightButtonKind.primary => Night.onDeep,
            NightButtonKind.ghost => Night.inkMuted,
            NightButtonKind.warm => Night.cityAmber,
            NightButtonKind.danger => Night.danger,
            NightButtonKind.text => Night.inkMuted,
          };
    final Color? line = switch (kind) {
      NightButtonKind.ghost => Night.glassLine,
      NightButtonKind.warm => Night.cityAmber,
      NightButtonKind.danger => Night.danger,
      _ => null,
    };
    final bool filled = kind == NightButtonKind.primary && enabled;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: Night.space2)],
        Flexible(child: Text(label, style: Night.label.copyWith(color: fg), overflow: TextOverflow.ellipsis)),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: Night.space4),
            decoration: BoxDecoration(
              gradient: filled ? Night.deepGradient : null,
              color: kind == NightButtonKind.primary && !enabled ? Night.night700 : null,
              borderRadius: BorderRadius.circular(999),
              border: line != null && enabled ? Border.all(color: line) : null,
              boxShadow: filled ? const [Night.glowViolet] : null,
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}

/// 頂部玻璃提示條：從狀態列下方滑入，3 秒後淡出。放在頂部，避免蓋住聊天輸入框或底部選單。
/// 同一時間只顯示一則；新的提示會直接取代舊的。
OverlayEntry? _currentToast;

void showGlassToast(BuildContext context, String message, {IconData icon = Icons.favorite_border, bool danger = false}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _currentToast?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _GlassToast(
      message: message,
      icon: icon,
      danger: danger,
      onDone: () {
        if (_currentToast == entry) _currentToast = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _currentToast = entry;
  overlay.insert(entry);
}

class _GlassToast extends StatefulWidget {
  final String message;
  final IconData icon;
  final bool danger;
  final VoidCallback onDone;
  const _GlassToast({required this.message, required this.icon, required this.danger, required this.onDone});

  @override
  State<_GlassToast> createState() => _GlassToastState();
}

class _GlassToastState extends State<_GlassToast> with SingleTickerProviderStateMixin {
  // 用動畫控制時間（而不是 Timer），畫面關閉時會一起被釋放，不會留下計時器
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))
    ..forward().whenComplete(widget.onDone);
  late final Animation<double> _shown = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 8),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 80),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 12),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + Night.space2;
    return Positioned(
      top: top, left: Night.space4, right: Night.space4,
      child: AnimatedBuilder(
        animation: _shown,
        builder: (context, child) => Opacity(
          opacity: _shown.value,
          child: Transform.translate(offset: Offset(0, -16 * (1 - _shown.value)), child: child),
        ),
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            liveRegion: true,
            child: GestureDetector(
              onTap: widget.onDone, // 點一下立即關閉
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Night.space4, vertical: Night.space3),
                decoration: BoxDecoration(
                  color: Night.night700,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Night.glassLine),
                  boxShadow: const [Night.lift],
                ),
                child: Row(children: [
                  Icon(widget.icon, size: 20, color: widget.danger ? Night.danger : Night.knockPink),
                  const SizedBox(width: Night.space3),
                  Expanded(child: Text(widget.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Night.ink, fontSize: 14, height: 1.4))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 面板標題：置中標題，右上角一個關閉鈕（面板很長、點不到外面時也能關）
class SheetTitle extends StatelessWidget {
  final String title;
  final String closeTooltip;
  const SheetTitle(this.title, {super.key, required this.closeTooltip});

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Text(title, style: Night.title, textAlign: TextAlign.center),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          tooltip: closeTooltip,
          icon: const Icon(Icons.close, color: Night.inkMuted),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
    ]);
  }
}
