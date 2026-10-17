import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/colors.dart';
import '../../core/images.dart';
import '../../core/theme.dart';
import '../../data/utils.dart';
import '../common/basics.dart';
import 'paginate.dart';

/// صفحات المنيو الورقي — منقولة من MenuSheet.tsx في الموقع.
///
/// كل التنسيق بقيم ثابتة لا ألوان الثيم: الصفحة تُصوَّر وتُطبع، فيجب أن
/// تخرج بنفس الألوان مهما كان مظهر التطبيق (نهاري أو ليلي).

/* ===================== الأبعاد ===================== */

/// A4 بوحدات 96 نقطة/إنش
const pageW = 794.0;
const pageH = 1123.0;
const padX = 58.0;
const padY = 54.0;
const contentW = pageW - padX * 2;
const colGap = 44.0;

/// المسافة بين الترويسة والأطباق، وبين الأطباق والتذييل
const bodyGap = 22.0;
const sectionGap = 26.0;

/// هامش أمان لكسور البكسل في القياس
const safety = 3.0;

double columnWidth(int columns) => (contentW - colGap * (columns - 1)) / columns;

/* ===================== الأنواع ===================== */

enum PrintStyle {
  classic('كلاسيكي', 'ورق كريمي وإطار مزخرف وخط نسخ'),
  modern('عصري', 'أبيض نظيف وترويسة بلون مطعمك'),
  night('ليلي', 'خلفية داكنة فاخرة — الأنسب للمطبعة');

  const PrintStyle(this.label, this.hint);
  final String label;
  final String hint;
}

enum LogoSize {
  sm(64),
  md(86),
  lg(112);

  const LogoSize(this.height);
  final double height;
}

class OptionLine {
  const OptionLine(this.label, this.items);

  final String label;
  final List<({String name, String? price})> items;
}

class PrintDish {
  const PrintDish({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.featured,
    required this.image,
    required this.options,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final bool featured;

  /// null حين لا صورة للطبق أو حين أطفأ صاحب المطعم الصور
  final String? image;
  final List<OptionLine> options;
}

class PrintSection {
  const PrintSection({required this.id, required this.name, required this.dishes});

  final String id;
  final String name;
  final List<PrintDish> dishes;
}

class Tokens {
  const Tokens({
    required this.bg,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.line,
    required this.soft,
    required this.band,
    required this.onBand,
    required this.onWhite,
    required this.head,
    required this.body,
  });

  final Color bg;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color line;
  final Color soft;

  /// شريط الترويسة في القالب العصري، ولون النص فوقه
  final Color band;
  final Color onBand;

  /// لون الحرف الاستهلالي على شارة الشعار البيضاء
  final Color onWhite;
  final String head;
  final String body;
}

/// كل ما تحتاجه الصفحة غير الأطباق
class SheetContext {
  const SheetContext({
    required this.style,
    required this.t,
    required this.name,
    required this.logo,
    required this.logoSize,
    required this.title,
    required this.tagline,
    required this.note,
    required this.phone,
    required this.qr,
    required this.currency,
    required this.columns,
    required this.showDescriptions,
  });

  final PrintStyle style;
  final Tokens t;
  final String name;
  final String? logo;
  final LogoSize logoSize;
  final String title;
  final String tagline;
  final String note;
  final String phone;

  /// رابط المنيو الرقمي لرمز QR — null لإخفائه
  final String? qr;
  final String currency;
  final int columns;
  final bool showDescriptions;

  bool get modern => style == PrintStyle.modern;
}

/* ===================== الألوان ===================== */

const _white = Color(0xFFFFFFFF);

Tokens makeTokens(PrintStyle style, String brandHex) {
  final brand = parseHex(brandHex);
  final onWhite = readableOn(brand, _white, 3);

  switch (style) {
    case PrintStyle.modern:
      final accent = readableOn(brand, _white, 3.2);
      return Tokens(
        bg: _white,
        ink: const Color(0xFF161B17),
        muted: const Color(0xFF636C65),
        accent: accent,
        line: const Color(0xFFE2E6E0),
        soft: mixSrgb(accent, _white, .92),
        band: brand,
        onBand: contrastRatio(brand, _white) >= 3 ? _white : const Color(0xFF161B17),
        onWhite: onWhite,
        head: Fonts.display,
        body: Fonts.body,
      );
    case PrintStyle.night:
      const bg = Color(0xFF121613);
      final accent = readableOn(mixSrgb(brand, _white, .35), bg, 4.5);
      return Tokens(
        bg: bg,
        ink: const Color(0xFFF1ECE1),
        muted: const Color(0xFFA39E91),
        accent: accent,
        line: mixSrgb(accent, bg, .62),
        soft: mixSrgb(accent, bg, .86),
        band: brand,
        onBand: _white,
        onWhite: onWhite,
        head: Fonts.serif,
        body: Fonts.body,
      );
    case PrintStyle.classic:
      const bg = Color(0xFFFBF6EC);
      final accent = readableOn(brand, bg, 3.5);
      return Tokens(
        bg: bg,
        ink: const Color(0xFF2A2119),
        muted: const Color(0xFF76695B),
        accent: accent,
        line: mixSrgb(accent, bg, .6),
        soft: mixSrgb(accent, bg, .9),
        band: brand,
        onBand: _white,
        onWhite: onWhite,
        head: Fonts.serif,
        body: Fonts.body,
      );
  }
}

/// نمط نص كامل — كل قيمة صريحة، فالقياس والطباعة يعطيان نفس النتيجة
TextStyle _s(
  String family,
  double size, {
  FontWeight weight = FontWeight.w400,
  required Color color,
  double height = 1.5,
}) => TextStyle(
  fontFamily: family,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  decoration: TextDecoration.none,
  letterSpacing: 0,
);

/* ===================== عناصر صغيرة ===================== */

class _Diamond extends StatelessWidget {
  const _Diamond({required this.color, this.size = 6});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: .785398,
    child: Container(width: size, height: size, color: color),
  );
}

class _Rule extends StatelessWidget {
  const _Rule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(child: Container(height: 1, color: color));
}

/// حرف الشارة عند غياب الشعار. «ال» التعريف تُتخطّى: ألف «الركن» وحدها
/// تُقرأ رقم ١، والحرف الذي يميّز الاسم هو ما بعدها.
String monogram(String name) {
  final trimmed = name.trim();
  final rest = trimmed.replaceFirst(RegExp(r'^ال(?=\S)'), '');
  return initial(rest.isEmpty ? trimmed : rest);
}

/// الشعار داخل شارة بيضاء دائمًا: الشعارات المرفوعة كثيرًا ما تأتي بخلفية
/// بيضاء، فتبدو مربّعًا دخيلًا على الورق الكريمي أو الداكن.
class _LogoBadge extends StatelessWidget {
  const _LogoBadge({required this.ctx, required this.height, this.bordered = true});

  final SheetContext ctx;
  final double height;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final pad = (height * .14).roundToDouble();
    final inner = height - pad * 2 - (bordered ? 2 : 0);
    final logo = dataImage(ctx.logo);
    // بعرض المحتوى (لا يتمدّد في العمود) وبحد أدنى مربّع
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: height, minHeight: height, maxHeight: height),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular((height * .26).roundToDouble()),
          border: bordered ? Border.all(color: ctx.t.line) : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: logo != null
                ? ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: (height * 2.6).roundToDouble() - pad * 2, maxHeight: inner),
                    child: Image(image: logo, height: inner, fit: BoxFit.contain),
                  )
                : Text(
                    monogram(ctx.name),
                    style: _s(
                      ctx.t.head,
                      (height * .5).roundToDouble(),
                      weight: FontWeight.w700,
                      color: ctx.t.onWhite,
                      height: 1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.ctx, required this.value});

  final SheetContext ctx;
  final double value;

  static TextStyle styleOf(SheetContext ctx) =>
      _s(ctx.t.body, 15, weight: FontWeight.w700, color: ctx.modern ? ctx.t.accent : ctx.t.ink, height: 1.4);

  static InlineSpan span(SheetContext ctx, double value) => TextSpan(
    children: [
      TextSpan(
        text: ltr(formatNumber(round2(value))),
        style: styleOf(ctx).copyWith(fontFeatures: tabular),
      ),
      TextSpan(
        text: ' ${currencySymbol(ctx.currency)}',
        style: _s(ctx.t.body, 11, weight: FontWeight.w500, color: ctx.t.muted, height: 1.4),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Text.rich(span(ctx, value), softWrap: false);
}

/* ===================== أجزاء الصفحة ===================== */

class MenuCover extends StatelessWidget {
  const MenuCover({super.key, required this.ctx});

  final SheetContext ctx;

  @override
  Widget build(BuildContext context) {
    final t = ctx.t;
    if (ctx.modern) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 32),
        decoration: BoxDecoration(color: t.band, borderRadius: BorderRadius.circular(22)),
        child: Row(
          children: [
            _LogoBadge(ctx: ctx, height: ctx.logoSize.height, bordered: false),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ctx.title.isNotEmpty)
                    Text(
                      ctx.title,
                      style: _s(
                        t.body,
                        13,
                        weight: FontWeight.w700,
                        color: t.onBand.withValues(alpha: .85),
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    ctx.name,
                    style: _s(t.head, 40, weight: FontWeight.w800, color: t.onBand, height: 1.2),
                  ),
                  if (ctx.tagline.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(ctx.tagline, style: _s(t.body, 13.5, color: t.onBand.withValues(alpha: .88), height: 1.6)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _LogoBadge(ctx: ctx, height: ctx.logoSize.height),
        const SizedBox(height: 14),
        Text(
          ctx.name,
          textAlign: TextAlign.center,
          style: _s(t.head, 46, weight: FontWeight.w700, color: t.ink, height: 1.25),
        ),
        if (ctx.tagline.isNotEmpty) ...[
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Text(
              ctx.tagline,
              textAlign: TextAlign.center,
              style: _s(t.body, 13.5, color: t.muted, height: 1.7),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: 440,
          child: Row(
            children: [
              _Rule(color: t.line),
              const SizedBox(width: 12),
              _Diamond(color: t.accent),
              if (ctx.title.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  ctx.title,
                  softWrap: false,
                  style: _s(t.head, 21, weight: FontWeight.w700, color: t.accent, height: 1.3),
                ),
                const SizedBox(width: 12),
                _Diamond(color: t.accent),
              ],
              const SizedBox(width: 12),
              _Rule(color: t.line),
            ],
          ),
        ),
      ],
    );
  }
}

/// ترويسة الصفحات التالية للأولى
class MenuCompactHeader extends StatelessWidget {
  const MenuCompactHeader({super.key, required this.ctx});

  final SheetContext ctx;

  @override
  Widget build(BuildContext context) {
    final t = ctx.t;
    if (ctx.modern) {
      return Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.accent, width: 2)),
        ),
        child: Row(
          children: [
            _LogoBadge(ctx: ctx, height: 40),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                ctx.name,
                style: _s(t.head, 21, weight: FontWeight.w800, color: t.ink, height: 1.3),
              ),
            ),
            const Spacer(),
            if (ctx.title.isNotEmpty)
              Text(
                ctx.title,
                style: _s(t.body, 12, weight: FontWeight.w600, color: t.muted, height: 1.5),
              ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LogoBadge(ctx: ctx, height: 42),
            const SizedBox(width: 12),
            Text(
              ctx.name,
              style: _s(t.head, 26, weight: FontWeight.w700, color: t.ink, height: 1.3),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 300,
          child: Row(
            children: [
              _Rule(color: t.line),
              const SizedBox(width: 10),
              _Diamond(color: t.accent, size: 5),
              const SizedBox(width: 10),
              _Rule(color: t.line),
            ],
          ),
        ),
      ],
    );
  }
}

class MenuSectionHeader extends StatelessWidget {
  const MenuSectionHeader({super.key, required this.ctx, required this.name, required this.atTop, required this.cont});

  final SheetContext ctx;
  final String name;
  final bool atTop;

  /// القسم يكمل من العمود السابق
  final bool cont;

  @override
  Widget build(BuildContext context) {
    final t = ctx.t;
    final top = atTop || cont ? 0.0 : sectionGap;
    // العنوان يأخذ عرضه الطبيعي (حتى حدٍّ يترك للزخرفة مكانًا)، والخطوط
    // تملأ الباقي — مثل flex في الموقع حيث الخطوط وحدها مرنة
    return LayoutBuilder(
      builder: (context, c) {
        if (ctx.modern) {
          final maxTitle = (c.maxWidth - 9 - 10 - 10 - 12 - (cont ? 50 : 0)).clamp(40.0, c.maxWidth);
          return Padding(
            padding: EdgeInsets.only(top: top, bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxTitle),
                  child: Text(
                    name,
                    style: _s(t.head, 21, weight: FontWeight.w800, color: t.ink, height: 1.3),
                  ),
                ),
                if (cont) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      'تابع',
                      style: _s(t.body, 10.5, weight: FontWeight.w700, color: t.accent, height: 1.6),
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                _Rule(color: t.line),
              ],
            ),
          );
        }
        final maxTitle = (c.maxWidth - 2 * (12 + 10 + 5 + 10)).clamp(40.0, c.maxWidth);
        return Padding(
          padding: EdgeInsets.only(top: top, bottom: 12),
          child: Row(
            children: [
              _Rule(color: t.line),
              const SizedBox(width: 10),
              _Diamond(color: t.accent, size: 5),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxTitle),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: name),
                      if (cont)
                        TextSpan(
                          text: '  (تابع)',
                          style: _s(t.body, 11, weight: FontWeight.w600, color: t.muted, height: 1.35),
                        ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: _s(t.head, 25, weight: FontWeight.w700, color: t.accent, height: 1.35),
                ),
              ),
              const SizedBox(width: 10),
              _Diamond(color: t.accent, size: 5),
              const SizedBox(width: 10),
              _Rule(color: t.line),
            ],
          ),
        );
      },
    );
  }
}

/// نقاط تصل الاسم بالسعر — تقليد المنيو المطبوع. ترسم أسفل نصّ فارغ،
/// فيشارك السطر في محاذاة خط الأساس مع الاسم والسعر.
class _Leader extends StatelessWidget {
  const _Leader({required this.color, required this.style});

  final Color? color;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: color == null ? null : _DotsPainter(color!),
    child: Text(' ', style: style),
  );
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final y = size.height - 4;
    for (var x = 0.0; x < size.width; x += 4.5) {
      canvas.drawCircle(Offset(x + 1, y), .85, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

class MenuDishRow extends StatelessWidget {
  const MenuDishRow({super.key, required this.ctx, required this.dish});

  final SheetContext ctx;
  final PrintDish dish;

  @override
  Widget build(BuildContext context) {
    final t = ctx.t;
    final thumb = ctx.columns == 1 ? 76.0 : 60.0;
    final image = dataImage(dish.image);
    final nameStyle = _s(t.head, ctx.modern ? 16.5 : 18.5, weight: FontWeight.w700, color: t.ink, height: 1.4);

    final nameSpan = TextSpan(
      children: [
        TextSpan(text: dish.name),
        if (dish.featured)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsetsDirectional.only(start: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: t.soft,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: t.line),
              ),
              child: Text(
                'مميز',
                style: _s(t.body, 10, weight: FontWeight.w700, color: t.accent, height: 1.6),
              ),
            ),
          ),
      ],
      style: nameStyle,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                width: thumb,
                height: thumb,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ctx.modern ? 12 : 10),
                  border: Border.all(color: t.line),
                ),
                child: Image(image: image, fit: BoxFit.cover, width: thumb, height: thumb),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    // الاسم يأخذ ما يحتاجه، والنقاط تملأ ما بقي حتى السعر
                    final pricePainter = TextPainter(
                      text: _Price.span(ctx, dish.price),
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                    )..layout();
                    final priceWidth = pricePainter.width;
                    pricePainter.dispose();
                    final nameMax = (c.maxWidth - priceWidth - 16 - 14).clamp(40.0, c.maxWidth);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: nameMax),
                          child: Text.rich(nameSpan),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Leader(color: ctx.modern ? null : t.line, style: _Price.styleOf(ctx)),
                        ),
                        const SizedBox(width: 8),
                        _Price(ctx: ctx, value: dish.price),
                      ],
                    );
                  },
                ),
                if (ctx.showDescriptions && dish.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(dish.description, style: _s(t.body, 12.5, color: t.muted, height: 1.65)),
                  ),
                for (final line in dish.options)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${line.label}: ',
                            style: _s(t.body, 11.5, weight: FontWeight.w700, color: t.accent, height: 1.6),
                          ),
                          for (final (j, item) in line.items.indexed) ...[
                            if (j > 0)
                              TextSpan(
                                text: ' · ',
                                style: TextStyle(color: t.muted.withValues(alpha: .6)),
                              ),
                            // المسافة غير الفاصلة تُبقي الخيار وسعره على سطر واحد
                            TextSpan(text: item.name.replaceAll(' ', ' ')),
                            if (item.price != null)
                              TextSpan(
                                text: ' ${ltr(item.price!)}',
                                style: _s(t.body, 11.5, weight: FontWeight.w700, color: t.ink, height: 1.6),
                              ),
                          ],
                        ],
                      ),
                      style: _s(t.body, 11.5, color: t.muted, height: 1.6),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MenuFooter extends StatelessWidget {
  const MenuFooter({super.key, required this.ctx, required this.page, required this.total});

  final SheetContext ctx;
  final int page;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = ctx.t;
    final content = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ctx.note.isNotEmpty) Text(ctx.note, style: _s(t.body, 12, color: t.muted, height: 1.65)),
              if (ctx.phone.isNotEmpty)
                Text(
                  'للطلب والاستفسار: ${ltr(ctx.phone)}',
                  style: _s(t.body, 12, weight: FontWeight.w600, color: t.ink, height: 1.65),
                ),
              // السطر محجوز دائمًا حتى يثبت ارتفاع التذييل الذي بُني عليه التوزيع
              Opacity(
                opacity: total > 1 ? 1 : 0,
                child: Text(
                  'صفحة ${ltr('$page')} من ${ltr('$total')}',
                  style: _s(t.body, 11, color: t.muted, height: 1.65),
                ),
              ),
            ],
          ),
        ),
        if (ctx.qr != null) ...[
          const SizedBox(width: 16),
          SizedBox(
            width: 104,
            child: Text(
              'امسح الرمز لتصفّح المنيو والطلب من جوالك',
              style: _s(t.body, 11, color: t.muted, height: 1.55),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.line),
            ),
            child: QrImageView(
              data: ctx.qr!,
              size: 70,
              padding: EdgeInsets.zero,
              backgroundColor: _white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF18201A)),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF18201A),
              ),
            ),
          ),
        ],
      ],
    );
    if (ctx.modern) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(16)),
        child: content,
      );
    }
    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: content,
    );
  }
}

/// إطار مزدوج بزوايا معيّنة — للقالبين الكلاسيكي والليلي
class _Decor extends StatelessWidget {
  const _Decor({required this.ctx});

  final SheetContext ctx;

  @override
  Widget build(BuildContext context) {
    if (ctx.modern) return const SizedBox.shrink();
    final t = ctx.t;
    const inset = 22.0;
    Widget corner(double left, double top) => Positioned(
      left: left - 4.5,
      top: top - 4.5,
      child: _Diamond(color: t.accent, size: 9),
    );
    return Stack(
      children: [
        Positioned.fill(
          left: inset,
          top: inset,
          right: inset,
          bottom: inset,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: t.line, width: 1.5)),
          ),
        ),
        Positioned.fill(
          left: inset + 6,
          top: inset + 6,
          right: inset + 6,
          bottom: inset + 6,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: t.line, width: .75)),
          ),
        ),
        corner(inset, inset),
        corner(pageW - inset, inset),
        corner(inset, pageH - inset),
        corner(pageW - inset, pageH - inset),
      ],
    );
  }
}

/* ===================== الصفحة ===================== */

class SheetLookup {
  SheetLookup(List<PrintSection> sections)
    : sections = {for (final s in sections) s.id: s},
      dishes = {
        for (final s in sections)
          for (final d in s.dishes) d.id: d,
      };

  final Map<String, PrintSection> sections;
  final Map<String, PrintDish> dishes;
}

Widget _block(SheetContext ctx, PageBlock block, SheetLookup lookup) {
  final section = lookup.sections[block.sectionId];
  if (section == null) return const SizedBox.shrink();
  return switch (block) {
    HeadBlock(:final atTop) => MenuSectionHeader(ctx: ctx, name: section.name, atTop: atTop, cont: false),
    ContBlock() => MenuSectionHeader(ctx: ctx, name: section.name, atTop: true, cont: true),
    DishBlock(:final dishId) =>
      lookup.dishes[dishId] == null ? const SizedBox.shrink() : MenuDishRow(ctx: ctx, dish: lookup.dishes[dishId]!),
  };
}

class MenuPage extends StatelessWidget {
  const MenuPage({
    super.key,
    required this.ctx,
    required this.plan,
    required this.index,
    required this.total,
    required this.lookup,
  });

  final SheetContext ctx;
  final PagePlan plan;
  final int index;
  final int total;
  final SheetLookup lookup;

  @override
  Widget build(BuildContext context) {
    final t = ctx.t;
    final bothFilled = plan.columns.length > 1 && plan.columns.every((c) => c.isNotEmpty);
    return MediaQuery.withNoTextScaling(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: pageW,
          height: pageH,
          color: t.bg,
          child: Stack(
            children: [
              Positioned.fill(child: _Decor(ctx: ctx)),
              Positioned(
                top: padY,
                bottom: padY,
                left: padX,
                right: padX,
                child: Column(
                  children: [
                    if (index == 0) MenuCover(ctx: ctx) else MenuCompactHeader(ctx: ctx),
                    Expanded(
                      child: ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: bodyGap),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final (i, blocks) in plan.columns.indexed) ...[
                                if (i > 0)
                                  SizedBox(
                                    width: colGap,
                                    child: bothFilled && !ctx.modern
                                        ? Center(child: Container(width: 1, color: t.line))
                                        : null,
                                  ),
                                SizedBox(
                                  width: columnWidth(ctx.columns),
                                  // شبكة أمان: لو زاد المحتوى عن العمود لسببٍ ما يُقصّ
                                  // بصمت بدل أن يكسر الصفحة — التوزيع يمنع ذلك أصلًا
                                  child: OverflowBox(
                                    alignment: Alignment.topCenter,
                                    maxHeight: double.infinity,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [for (final b in blocks) _block(ctx, b, lookup)],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    MenuFooter(ctx: ctx, page: index + 1, total: total),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ===================== القياس ===================== */

/// مفاتيح القياس: نسخة غير مرئية من كل كتلة بعرضها الحقيقي تُقاس ارتفاعاتها
/// ثم تُوزَّع. القياس من محرّك الرسم نفسه لا تقدير: التفاف النص العربي لا
/// يُحسب مسبقًا بدقة.
class MeasureKeys {
  final cover = GlobalKey();
  final compact = GlobalKey();
  final footer = GlobalKey();
  final heads = <String, GlobalKey>{};
  final conts = <String, GlobalKey>{};
  final dishes = <String, GlobalKey>{};

  GlobalKey head(String id) => heads.putIfAbsent(id, GlobalKey.new);
  GlobalKey cont(String id) => conts.putIfAbsent(id, GlobalKey.new);
  GlobalKey dish(String id) => dishes.putIfAbsent(id, GlobalKey.new);
}

class MenuMeasurer extends StatelessWidget {
  const MenuMeasurer({super.key, required this.ctx, required this.sections, required this.keys});

  final SheetContext ctx;
  final List<PrintSection> sections;
  final MeasureKeys keys;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: contentW,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(
                key: keys.cover,
                child: MenuCover(ctx: ctx),
              ),
              KeyedSubtree(
                key: keys.compact,
                child: MenuCompactHeader(ctx: ctx),
              ),
              KeyedSubtree(
                key: keys.footer,
                child: MenuFooter(ctx: ctx, page: 1, total: 2),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(
                  width: columnWidth(ctx.columns),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final s in sections) ...[
                        KeyedSubtree(
                          key: keys.head(s.id),
                          child: MenuSectionHeader(ctx: ctx, name: s.name, atTop: false, cont: false),
                        ),
                        KeyedSubtree(
                          key: keys.cont(s.id),
                          child: MenuSectionHeader(ctx: ctx, name: s.name, atTop: true, cont: true),
                        ),
                        for (final d in s.dishes)
                          KeyedSubtree(
                            key: keys.dish(d.id),
                            child: MenuDishRow(ctx: ctx, dish: d),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _height(GlobalKey key) => key.currentContext?.size?.height ?? 0;

/// يقرأ الارتفاعات المقيسة ويوزّع الأطباق على الصفحات
List<PagePlan> measurePages(MeasureKeys keys, List<PrintSection> sections, int columns) {
  double body(double header) => pageH - padY * 2 - header - _height(keys.footer) - bodyGap * 2 - safety;
  return paginate(
    sections: [
      for (final s in sections)
        MeasuredSection(
          id: s.id,
          head: _height(keys.head(s.id)),
          cont: _height(keys.cont(s.id)),
          dishes: [for (final d in s.dishes) MeasuredDish(d.id, _height(keys.dish(d.id)))],
        ),
    ],
    firstCapacity: body(_height(keys.cover)),
    capacity: body(_height(keys.compact)),
    columns: columns,
    headGap: sectionGap,
  );
}
