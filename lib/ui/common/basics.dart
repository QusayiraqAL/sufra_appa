import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/colors.dart';
import '../../core/images.dart';
import '../../core/theme.dart';
import '../../data/utils.dart';

/* ===================== الأرقام واتجاهها ===================== */

/// يعزل نصًّا لاتينيًّا (رقم، جوال، رابط) داخل سطر عربي.
/// بدون العزل ينقلب ترتيب «#1041» أو «+4» أو الرابط في سياق RTL.
String ltr(String s) => '$_lri$s$_pdi';

final _lri = String.fromCharCode(0x2066);
final _pdi = String.fromCharCode(0x2069);

/// المال: الرقم لاتيني معزول الاتجاه، والرمز عربي أصغر بعده —
/// مثل مكوّن Money في الموقع.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.value, {
    super.key,
    required this.currency,
    this.style,
    this.strike = false,
    this.color,
    this.symbolScale = .78,
  });

  final double value;
  final String currency;
  final TextStyle? style;
  final bool strike;
  final Color? color;
  final double symbolScale;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? DefaultTextStyle.of(context).style).copyWith(
      color: color,
      decoration: strike ? TextDecoration.lineThrough : null,
      decorationColor: color ?? style?.color,
    );
    final size = base.fontSize ?? 14;
    return Opacity(
      opacity: strike ? .55 : 1,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: ltr(formatNumber(round2(value))),
              style: base.copyWith(fontWeight: base.fontWeight ?? FontWeight.w600, fontFeatures: tabular),
            ),
            TextSpan(
              text: ' ${currencySymbol(currency)}',
              style: base.copyWith(
                fontSize: size * symbolScale,
                fontWeight: FontWeight.w500,
                color: (base.color ?? context.palette.ink).withValues(alpha: .72),
              ),
            ),
          ],
        ),
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

/* ===================== ألوان الأدوات ===================== */

/// ألوان الأدوات مأخوذة من مكوّنات المطبخ الشامي — نفس لوحة ألوان
/// الهوية في إعدادات المطعم (زعفران، زعتر، سماق، نيلي، توت…).
enum Tint {
  saffron(Color(0xFFA96A00)),
  zaatar(Color(0xFF0E6B4F)),
  sumac(Color(0xFF8C2F39)),
  indigo(Color(0xFF1F4E79)),
  berry(Color(0xFF5B3A8E)),
  ember(Color(0xFFB35410)),
  teal(Color(0xFF0F6D74)),
  olive(Color(0xFF5F6B1E)),
  charcoal(Color(0xFF4A524C));

  const Tint(this.base);
  final Color base;
}

final _tintCache = <(Tint, bool), ({Color bg, Color fg})>{};

({Color bg, Color fg}) tintColors(Tint tint, bool dark) => _tintCache.putIfAbsent((tint, dark), () {
  if (dark) {
    return (
      bg: mixOklab(tint.base, const Color(0xFF171D18), .34),
      fg: mixOklab(tint.base, const Color(0xFFFFFFFF), .5),
    );
  }
  return (bg: mixOklab(tint.base, const Color(0xFFFFFFFF), .11), fg: tint.base);
});

/// أيقونة داخل مربّع ملوّن ناعم
class TintIcon extends StatelessWidget {
  const TintIcon(this.icon, this.tint, {super.key, this.size = 40});

  final IconData icon;
  final Tint tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = tintColors(tint, context.palette.isDark);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(size * .3)),
      alignment: Alignment.center,
      child: Icon(icon, size: size * .5, color: c.fg),
    );
  }
}

/* ===================== النصوص ===================== */

/// عنوان صغير فوق العنوان — بديل عن الترقيم الزخرفي (.eyebrow في الموقع)
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: txt(12, color: color ?? context.palette.inkFaint, weight: FontWeight.w600, height: 1.4),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.eyebrow, this.trailing, this.padding = EdgeInsets.zero});

  final String title;
  final String? eyebrow;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[Eyebrow(eyebrow!), const SizedBox(height: 2)],
                Text(
                  title,
                  style: heading(17, color: p.ink, weight: FontWeight.w800),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/* ===================== الشارات ===================== */

enum Tone { neutral, saffron, basil, sumac, ember }

({Color bg, Color fg, Color border}) toneColors(BuildContext context, Tone tone) {
  final p = context.palette;
  return switch (tone) {
    Tone.neutral => (bg: p.surface2, fg: p.inkSoft, border: p.line),
    Tone.saffron => (bg: p.saffronTint, fg: p.saffron, border: p.saffron.withValues(alpha: .25)),
    Tone.basil => (bg: p.basilTint, fg: p.basil, border: p.basil.withValues(alpha: .25)),
    Tone.sumac => (bg: p.sumacTint, fg: p.sumac, border: p.sumac.withValues(alpha: .25)),
    Tone.ember => (bg: p.emberTint, fg: p.ember, border: p.ember.withValues(alpha: .25)),
  };
}

class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.tone = Tone.neutral, this.icon, this.dense = false});

  final String label;
  final Tone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(context, tone);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 1.5 : 3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: dense ? 11 : 13, color: c.fg), const SizedBox(width: 4)],
          // مرن: يأخذ عرضه الطبيعي، ويُختصر بنقاط حين يضيق المكان (خط الجوال المكبّر مثلًا)
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: txt(dense ? 11 : 12, color: c.fg, weight: FontWeight.w600, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// نقطة حيّة تنبض — لـ«مفتوح الآن» ولطلبات تنتظر
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 8, this.animate = true});

  final Color color;
  final double size;
  final bool animate;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _sync();
  }

  @override
  void didUpdateWidget(PulseDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// النبض يدور فقط حين يُطلب ولم يُلغِ المستخدم الحركة — فلا مؤقّت يرسم إطارات بلا داعٍ
  void _sync() {
    final run = widget.animate && !_reduce;
    if (run && !_c.isAnimating) _c.repeat();
    if (!run && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.2,
      height: widget.size * 2.2,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.isAnimating ? _c.value : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (t > 0)
                Container(
                  width: widget.size * (1 + 1.2 * t),
                  height: widget.size * (1 + 1.2 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: .35 * (1 - t)),
                  ),
                ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ===================== الأسطح ===================== */

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = Radii.lg,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? p.line),
    );
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(customBorder: shape, onTap: onTap, child: content);
    }
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(color: color ?? p.surface, shape: shape, clipBehavior: Clip.antiAlias, child: content),
    );
  }
}

/// رقم مع عنوان — لأرقام اليوم والتقارير
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.sub, this.tone = Tone.neutral, this.icon});

  final String label;
  final Widget value;
  final String? sub;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = switch (tone) {
      Tone.neutral => p.ink,
      Tone.saffron => p.saffron,
      Tone.basil => p.basil,
      Tone.sumac => p.sumac,
      Tone.ember => p.ember,
    };
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Eyebrow(label)),
              if (icon != null) Icon(icon, size: 16, color: accent.withValues(alpha: .7)),
            ],
          ),
          const SizedBox(height: 4),
          DefaultTextStyle.merge(
            style: txt(23, color: accent, weight: FontWeight.w700, height: 1.25),
            child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: value),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              style: txt(12, color: p.inkFaint, height: 1.4),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// شبكة أرقام بارتفاع المحتوى: عمودان على الجوال وأربعة على اللوحي،
/// وكل صف بارتفاع أطول بطاقة فيه — بلا فراغ زائد ولا قصّ مع تكبير الخط.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children, this.spacing = 10});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 4 : 2;
        return Column(
          children: [
            for (var i = 0; i < children.length; i += columns) ...[
              if (i > 0) SizedBox(height: spacing),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i; j < i + columns; j++) ...[
                      if (j > i) SizedBox(width: spacing),
                      Expanded(child: j < children.length ? children[j] : const SizedBox.shrink()),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// ملاحظة داخل إطار — للتنبيهات الهادئة والشروح
class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key, this.title, this.icon = Icons.info_outline_rounded});

  final String text;
  final String? title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface2.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: p.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: p.inkFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (title != null)
                    TextSpan(
                      text: '$title ',
                      style: txt(13, color: p.ink, weight: FontWeight.w700),
                    ),
                  TextSpan(text: text),
                ],
              ),
              style: txt(12.5, color: p.inkSoft, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// رسالة ملوّنة: خطأ أو تحذير أو نجاح
class AlertBox extends StatelessWidget {
  const AlertBox(this.text, {super.key, this.tone = Tone.sumac, this.icon, this.center = false});

  final String text;
  final Tone tone;
  final IconData? icon;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(context, tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 17, color: c.fg),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: center ? TextAlign.center : TextAlign.start,
              style: txt(13.5, color: c.fg, weight: FontWeight.w600, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================== الحالة الفارغة ===================== */

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.body, this.icon, this.action});

  final String title;
  final String? body;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CustomPaint(
      painter: DashedBorderPainter(color: p.lineStrong, radius: Radii.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: p.surface2, shape: BoxShape.circle),
                child: Icon(icon, color: p.inkFaint, size: 26),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: heading(16, color: p.ink, weight: FontWeight.w700),
            ),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: txt(13.5, color: p.inkSoft, height: 1.7),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

/// إطار متقطّع بزوايا مستديرة
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({required this.color, this.radius = 16, this.dash = 6, this.gap = 5, this.width = 1.2});

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset(width / 2, width / 2) & Size(size.width - width, size.height - width),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) => old.color != color || old.radius != radius;
}

/* ===================== صورة الطبق ===================== */

/// صورة الطبق، أو — عند غيابها — بديل طباعي بلون مشتق من الاسم،
/// أفضل من مستطيل رمادي فارغ.
class DishThumb extends StatelessWidget {
  const DishThumb({
    super.key,
    required this.name,
    required this.src,
    this.size = 64,
    this.radius = 14,
    this.dim = false,
    this.label,
  });

  final String name;

  /// الحرف المعروض بدل الصورة — للمطاعم نمرّر brandInitial فتتخطّى «ال»
  final String? label;
  final String? src;
  final double size;
  final double radius;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final image = dataImage(src);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    Widget child;
    if (image != null) {
      child = Image(
        image: ResizeImage.resizeIfNeeded((size * dpr).round(), null, image),
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _placeholder(p),
      );
    } else {
      child = _placeholder(p);
    }
    return Opacity(
      opacity: dim ? .45 : 1,
      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
    );
  }

  Widget _placeholder(Palette p) {
    final c = thumbColors(tintFromName(name), dark: p.isDark);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [c.from, c.to],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: p.line),
      ),
      // الحرف رسم بحجم المربّع لا نصّ للقراءة، فلا يكبر مع خط الجوال فيُقصّ
      child: Text(
        label ?? initial(name),
        textScaler: TextScaler.noScaling,
        style: heading(size * .4, color: c.text, height: 1),
      ),
    );
  }
}

/* ===================== رمز QR ===================== */

/// ألوان ثابتة في الثيمين: الماسح يحتاج تضادًا داكنًا على أبيض دائمًا.
class QrBox extends StatelessWidget {
  const QrBox({super.key, required this.data, this.size = 140, this.padding = 8});

  final String data;
  final double size;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.line),
      ),
      child: QrImageView(
        data: data,
        size: size,
        padding: EdgeInsets.all(padding),
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        semanticsLabel: 'رمز QR',
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF18201A)),
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF18201A)),
      ),
    );
  }
}

/* ===================== التحميل ===================== */

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'جارٍ التحميل'});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6)),
        const SizedBox(height: 12),
        Text('$label…', style: txt(13.5, color: context.palette.inkFaint)),
      ],
    ),
  );
}
