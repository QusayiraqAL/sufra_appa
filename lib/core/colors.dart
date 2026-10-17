import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// أدوات الألوان. الموقع يمزج ألوان الهوية بـ color-mix(in oklab) ويرسم
/// بدائل صور الأطباق بـ oklch — هنا نفس الحساب، فيظهر لون المطعم في التطبيق
/// كما يظهر في الموقع تمامًا.

Color parseHex(String hex, [Color fallback = const Color(0xFFA96A00)]) {
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length < 6 || !RegExp(r'^[0-9a-fA-F]{6}').hasMatch(h)) return fallback;
  return Color(0xFF000000 | int.parse(h.substring(0, 6), radix: 16));
}

String toHex(Color c) {
  String two(double v) => (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${two(c.r)}${two(c.g)}${two(c.b)}';
}

/* ===================== OKLab ===================== */

double _toLinear(double c) => c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
double _toSrgb(double c) => c <= 0.0031308 ? 12.92 * c : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;
double _cbrt(double x) => x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

typedef Lab = ({double l, double a, double b});

Lab toOklab(Color c) {
  final r = _toLinear(c.r), g = _toLinear(c.g), b = _toLinear(c.b);
  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return (
    l: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  );
}

Color fromOklab(Lab lab, [double alpha = 1]) {
  final l = math.pow(lab.l + 0.3963377774 * lab.a + 0.2158037573 * lab.b, 3).toDouble();
  final m = math.pow(lab.l - 0.1055613458 * lab.a - 0.0638541728 * lab.b, 3).toDouble();
  final s = math.pow(lab.l - 0.0894841775 * lab.a - 1.2914855480 * lab.b, 3).toDouble();
  double ch(double v) => _toSrgb(v).clamp(0.0, 1.0);
  return Color.from(
    alpha: alpha,
    red: ch(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
    green: ch(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
    blue: ch(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
  );
}

/// color-mix(in oklab, a weightA%, b)
Color mixOklab(Color a, Color b, double weightA) {
  final x = toOklab(a), y = toOklab(b);
  final t = 1 - weightA;
  return fromOklab((l: x.l + (y.l - x.l) * t, a: x.a + (y.a - x.a) * t, b: x.b + (y.b - x.b) * t));
}

/// oklch(L C h) كما في CSS
Color oklch(double l, double c, double hueDeg) {
  final h = hueDeg * math.pi / 180;
  return fromOklab((l: l, a: c * math.cos(h), b: c * math.sin(h)));
}

/* ===================== التباين ===================== */

double luminance(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrastRatio(Color a, Color b) {
  final la = luminance(a), lb = luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// مزج خطّي في sRGB — المنيو الورقي في الموقع يمزج هكذا (لا oklab)
Color mixSrgb(Color a, Color b, double amountB) => Color.from(
  alpha: 1,
  red: a.r + (b.r - a.r) * amountB,
  green: a.g + (b.g - a.g) * amountB,
  blue: a.b + (b.b - a.b) * amountB,
);

/// يقرّب اللون من الأسود أو الأبيض بالتدريج حتى يُقرأ على الخلفية.
/// صاحب المطعم يختار لونه بحرية، وبعض الألوان (أصفر فاتح مثلًا) تختفي.
Color readableOn(Color color, Color bg, double minContrast) {
  final toward = luminance(bg) > 0.4 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  for (var step = 0; step <= 10; step++) {
    final candidate = mixSrgb(color, toward, step / 10);
    if (contrastRatio(candidate, bg) >= minContrast) return candidate;
  }
  return toward;
}

/* ===================== لون هوية المطعم ===================== */

/// ألوان واجهة العميل المشتقة من لون المطعم — مقابل [data-brand] في الموقع.
/// اللون الداكن الذي يصلح على خلفية نهارية يصير غير مقروء ليلًا، فتُرفع
/// إضاءته في الثيم الليلي ويُقلب لون النص فوقه.
class BrandColors {
  const BrandColors({required this.raw, required this.brand, required this.onBrand, required this.soft});

  /// اللون كما اختاره صاحب المطعم
  final Color raw;

  /// اللون المستخدم على الواجهة (مرفوع الإضاءة ليلًا)
  final Color brand;
  final Color onBrand;

  /// خلفية خفيفة بلون الهوية
  final Color soft;

  factory BrandColors.from(String themeColor, {required bool dark, required Color surface}) {
    final raw = parseHex(themeColor);
    if (dark) {
      final brand = mixOklab(raw, const Color(0xFFFFFFFF), 0.58);
      return BrandColors(raw: raw, brand: brand, onBrand: const Color(0xFF101410), soft: mixOklab(raw, surface, 0.26));
    }
    // الموقع يكتب بالأبيض دائمًا؛ هنا نتحقق من التباين فلا يختفي النص على لون فاتح
    final onBrand = contrastRatio(raw, const Color(0xFFFFFFFF)) >= 3
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF18201A);
    return BrandColors(raw: raw, brand: raw, onBrand: onBrand, soft: mixOklab(raw, surface, 0.12));
  }
}

/// ألوان بديل صورة الطبق — مشتقة من اسمه، ثابتة لكل طبق.
({Color from, Color to, Color text}) thumbColors(int hue, {required bool dark}) {
  final h = hue.toDouble();
  if (dark) {
    return (from: oklch(0.34, 0.045, h), to: oklch(0.29, 0.055, h), text: oklch(0.83, 0.08, h));
  }
  return (from: oklch(0.93, 0.045, h), to: oklch(0.88, 0.06, h), text: oklch(0.42, 0.09, h));
}
