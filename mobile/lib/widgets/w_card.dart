import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// 웹의 .card 스타일 — 다크 배경 + 테두리 + 퍼플 글로우 옵션
class WCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool neonPurple;
  final bool neonCyan;
  final VoidCallback? onTap;

  const WCard({
    super.key,
    required this.child,
    this.padding,
    this.neonPurple = false,
    this.neonCyan = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    BoxDecoration decoration = BoxDecoration(
      color: WColors.bg2,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: neonPurple
            ? WColors.purple.withValues(alpha: 0.4)
            : neonCyan
                ? WColors.cyan.withValues(alpha: 0.4)
                : WColors.border,
      ),
      boxShadow: neonPurple
          ? [BoxShadow(color: WColors.purple.withValues(alpha: 0.25), blurRadius: 24)]
          : neonCyan
              ? [BoxShadow(color: WColors.cyan.withValues(alpha: 0.25), blurRadius: 24)]
              : null,
    );

    final content = Container(
      decoration: decoration,
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

/// 웹의 .tag 스타일 배지
class WTag extends StatelessWidget {
  final String label;
  final Color color;

  WTag(this.label, {super.key, Color? color}) : color = color ?? WColors.purple;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 웹의 .progress-track / .progress-fill
class WProgressBar extends StatelessWidget {
  final double value; // 0.0 ~ 1.0
  final bool green;
  final bool yellow;

  const WProgressBar(this.value, {super.key, this.green = false, this.yellow = false});

  @override
  Widget build(BuildContext context) {
    final colors = green
        ? [WColors.green, Color(0xFF22c55e)]
        : yellow
            ? [WColors.yellow, Color(0xFFf59e0b)]
            : [WColors.purple, WColors.cyan];

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 6,
        color: WColors.bg3,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              boxShadow: [BoxShadow(color: colors[0].withValues(alpha: 0.5), blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }
}

/// 그라디언트 텍스트 (웹의 .gradient-text)
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const GradientText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [WColors.purple, WColors.cyan, WColors.pink],
        stops: [0.0, 0.5, 1.0],
      ).createShader(bounds),
      child: Text(text, style: (style ?? const TextStyle()).copyWith(color: Colors.white)),
    );
  }
}

/// 아바타 (이니셜 + 퍼플→시안 그라디언트)
class WAvatar extends StatelessWidget {
  final String name;
  final double size;

  const WAvatar(this.name, {super.key, this.size = 38});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: WColors.gradientPurpleCyan,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

/// 그라디언트 버튼 (웹의 .btn-primary)
class WGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const WGradientButton(
    this.label, {
    super.key,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: onPressed != null
              ? WColors.gradientPurplePink
              : LinearGradient(colors: [WColors.bg3, WColors.bg3]),
          borderRadius: BorderRadius.circular(999),
          boxShadow: onPressed != null
              ? [BoxShadow(color: WColors.purple.withValues(alpha: 0.4), blurRadius: 20)]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else ...[
              if (icon != null) ...[Icon(icon, size: 18, color: Colors.white), const SizedBox(width: 6)],
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ],
        ),
      ),
    );
  }
}
