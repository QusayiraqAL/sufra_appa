import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

enum BtnTone { primary, outline, ghost, danger, success }

enum BtnSize { sm, md, lg }

/// زر التطبيق — نفس أنماط أزرار الموقع (أساسي، محدّد، شفاف، خطر، نجاح)
/// بمقاسات لمس مريحة. [brand] يلوّن الزر الأساسي بلون المطعم في واجهة العميل.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = BtnTone.outline,
    this.size = BtnSize.md,
    this.expand = false,
    this.busy = false,
    this.brand,
    this.onBrand,
    this.trailing,
    this.haptic = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BtnTone tone;
  final BtnSize size;
  final bool expand;
  final bool busy;
  final Color? brand;
  final Color? onBrand;
  final Widget? trailing;
  final bool haptic;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null && !busy;
    final (bg, fg, border) = switch (tone) {
      BtnTone.primary => (brand ?? p.saffron, onBrand ?? p.onSaffron, Colors.transparent),
      BtnTone.outline => (p.surface, p.ink, p.lineStrong),
      BtnTone.ghost => (Colors.transparent, p.inkSoft, Colors.transparent),
      BtnTone.danger => (p.sumac, p.surface, Colors.transparent),
      BtnTone.success => (p.basil, p.surface, Colors.transparent),
    };
    final height = switch (size) {
      BtnSize.sm => 38.0,
      BtnSize.md => 46.0,
      BtnSize.lg => 54.0,
    };
    final fontSize = switch (size) {
      BtnSize.sm => 13.5,
      BtnSize.md => 14.5,
      BtnSize.lg => 16.0,
    };
    final radius = size == BtnSize.sm ? Radii.sm : Radii.md;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: border),
    );

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(
            width: fontSize,
            height: fontSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: fontSize + 3, color: fg),
        if (busy || icon != null) SizedBox(width: size == BtnSize.sm ? 6 : 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tone == BtnTone.primary && size == BtnSize.lg
                ? heading(fontSize, color: fg, weight: FontWeight.w700, height: 1.2)
                : txt(fontSize, color: fg, weight: FontWeight.w600, height: 1.2),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );

    return Opacity(
      opacity: enabled || busy ? 1 : .45,
      child: SizedBox(
        height: height,
        width: expand ? double.infinity : null,
        child: Material(
          color: bg,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled
                ? () {
                    if (haptic) HapticFeedback.selectionClick();
                    onPressed!();
                  }
                : null,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: size == BtnSize.sm ? 12 : 16),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// زر أيقونة مربّع بإطار
class IconBtn extends StatelessWidget {
  const IconBtn({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 40,
    this.color,
    this.danger = false,
    this.filled = false,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final bool danger;
  final bool filled;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = color ?? (danger ? p.sumac : p.inkSoft);
    final button = Opacity(
      opacity: onPressed == null ? .4 : 1,
      child: Material(
        color: filled ? p.surface2 : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          side: BorderSide(color: p.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * .45, color: fg),
          ),
        ),
      ),
    );
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: badge == null || badge == 0
            ? button
            : Badge(
                label: Text('$badge', style: txt(10.5, weight: FontWeight.w700, height: 1)),
                backgroundColor: p.saffron,
                textColor: p.onSaffron,
                offset: const Offset(-4, -4),
                child: button,
              ),
      ),
    );
  }
}
