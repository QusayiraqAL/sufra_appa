import 'package:flutter/material.dart';

import '../../core/colors.dart';
import '../../core/theme.dart';
import '../../data/models.dart';

/// يمرّر لون هوية المطعم لكل شاشات العميل — مقابل [data-brand] في الموقع.
class BrandScope extends InheritedWidget {
  const BrandScope({super.key, required this.colors, required super.child});

  final BrandColors colors;

  static BrandColors of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BrandScope>();
    if (scope != null) return scope.colors;
    final p = context.palette;
    return BrandColors.from('#a96a00', dark: p.isDark, surface: p.surface);
  }

  /// يلفّ [child] بألوان [restaurant] حسب المظهر الحالي
  static Widget wrap(BuildContext context, Restaurant restaurant, Widget child) {
    final p = context.palette;
    return BrandScope(
      colors: BrandColors.from(restaurant.themeColor, dark: p.isDark, surface: p.surface),
      child: child,
    );
  }

  @override
  bool updateShouldNotify(BrandScope old) => old.colors.brand != colors.brand || old.colors.soft != colors.soft;
}

/// الشريط السفلي الثابت في شاشات العميل — لزر السلة وزر التأكيد
class StickyBar extends StatelessWidget {
  const StickyBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: .97),
        border: Border(top: BorderSide(color: p.line)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? .35 : .06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.paddingOf(context).bottom),
      child: child,
    );
  }
}

/// زر بلون المطعم: عنوان في جهة والمبلغ في الأخرى — مثل زر السلة في الموقع
class BrandBarButton extends StatelessWidget {
  const BrandBarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailing,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? trailing;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final brand = BrandScope.of(context);
    final p = context.palette;
    final enabled = onPressed != null && !busy;
    final fg = enabled || busy ? brand.onBrand : p.inkFaint;
    return Material(
      color: enabled || busy ? brand.brand : p.surface2,
      borderRadius: BorderRadius.circular(Radii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DefaultTextStyle.merge(
              style: heading(15.5, color: fg, weight: FontWeight.w700, height: 1.2),
              child: Row(
                children: [
                  if (busy)
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                  else if (icon != null)
                    Icon(icon, size: 20, color: fg),
                  if (busy || icon != null) const SizedBox(width: 10),
                  Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (trailing != null)
                    IconTheme(
                      data: IconThemeData(color: fg),
                      child: trailing!,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
