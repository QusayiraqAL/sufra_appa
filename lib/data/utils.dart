import 'dart:math';

import 'models.dart';

/* ===================== معرّفات ===================== */

final _random = Random.secure();

/// معرّف بنفس شكل الموقع: بادئة_ثم وقت بأساس 36 ثم ثمانية أحرف عشوائية.
String uid([String prefix = '']) {
  final rand = List.generate(8, (_) => _random.nextInt(16).toRadixString(16)).join();
  final time = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  return '$prefix${prefix.isEmpty ? '' : '_'}$time$rand';
}

const _slugMap = <String, String>{
  'ا': 'a',
  'أ': 'a',
  'إ': 'a',
  'آ': 'a',
  'ب': 'b',
  'ت': 't',
  'ث': 'th',
  'ج': 'j',
  'ح': 'h',
  'خ': 'kh',
  'د': 'd',
  'ذ': 'dh',
  'ر': 'r',
  'ز': 'z',
  'س': 's',
  'ش': 'sh',
  'ص': 's',
  'ض': 'd',
  'ط': 't',
  'ظ': 'z',
  'ع': 'a',
  'غ': 'gh',
  'ف': 'f',
  'ق': 'q',
  'ك': 'k',
  'ل': 'l',
  'م': 'm',
  'ن': 'n',
  'ه': 'h',
  'و': 'w',
  'ي': 'y',
  'ى': 'a',
  'ة': 'h',
  'ء': '',
  'ئ': 'e',
  'ؤ': 'o',
};

String slugify(String input) {
  final mapped = input.trim().toLowerCase().split('').map((ch) => _slugMap[ch] ?? ch).join();
  final out = mapped
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return out.isEmpty ? 'matam' : out;
}

/* ===================== العملات والمال ===================== */

class Currency {
  const Currency(this.code, this.symbol, this.label);

  final String code;
  final String symbol;
  final String label;
}

const currencies = <Currency>[
  Currency('SAR', 'ر.س', 'ريال سعودي'),
  Currency('AED', 'د.إ', 'درهم إماراتي'),
  Currency('KWD', 'د.ك', 'دينار كويتي'),
  Currency('QAR', 'ر.ق', 'ريال قطري'),
  Currency('BHD', 'د.ب', 'دينار بحريني'),
  Currency('OMR', 'ر.ع', 'ريال عماني'),
  Currency('JOD', 'د.أ', 'دينار أردني'),
  Currency('EGP', 'ج.م', 'جنيه مصري'),
  Currency('IQD', 'د.ع', 'دينار عراقي'),
  Currency('SYP', 'ل.س', 'ليرة سورية'),
  Currency('LBP', 'ل.ل', 'ليرة لبنانية'),
  Currency('MAD', 'د.م', 'درهم مغربي'),
  Currency('DZD', 'د.ج', 'دينار جزائري'),
  Currency('TND', 'د.ت', 'دينار تونسي'),
  Currency('YER', 'ر.ي', 'ريال يمني'),
  Currency('SDG', 'ج.س', 'جنيه سوداني'),
];

String currencySymbol(String code) {
  for (final c in currencies) {
    if (c.code == code) return c.symbol;
  }
  return code;
}

/// Number.EPSILON في JavaScript
const double _jsEpsilon = 2.220446049250313e-16;

/// يقرّب لأقرب هللة ويتجنّب أخطاء الفاصلة العائمة.
/// مطابق لـ Math.round في JavaScript (يقرّب النصف نحو +∞، لا بعيدًا عن الصفر).
double round2(num n) => ((n + _jsEpsilon) * 100 + 0.5).floorToDouble() / 100;

/// الرقم الصحيح بلا كسور، وغيره بخانتين — مثل formatNumber في الموقع.
String formatNumber(num n) {
  if (n == n.truncateToDouble() && n.abs() < 1e15) return n.toInt().toString();
  return n.toStringAsFixed(2);
}

/// نص المال كسلسلة واحدة — للإيصالات ورسائل المشاركة
String formatMoney(num n, String currency) => '${formatNumber(round2(n))} ${currencySymbol(currency)}';

/* ===================== حساب الفاتورة ===================== */

class Bill {
  const Bill({required this.subtotal, required this.taxAmount, required this.deliveryFee, required this.total});

  final double subtotal;
  final double taxAmount;
  final double deliveryFee;
  final double total;
}

/// إذا كانت الأسعار شاملة الضريبة نستخرجها من المجموع بدل إضافتها،
/// وإلا نضيفها فوقه. رسوم التوصيل تُضاف بلا ضريبة.
Bill computeBill({
  required double subtotal,
  required double taxRate,
  required bool taxIncluded,
  required double deliveryFee,
}) {
  final rate = max(0.0, taxRate) / 100;
  if (taxIncluded) {
    final net = subtotal / (1 + rate);
    return Bill(
      subtotal: round2(net),
      taxAmount: round2(subtotal - net),
      deliveryFee: round2(deliveryFee),
      total: round2(subtotal + deliveryFee),
    );
  }
  final tax = subtotal * rate;
  return Bill(
    subtotal: round2(subtotal),
    taxAmount: round2(tax),
    deliveryFee: round2(deliveryFee),
    total: round2(subtotal + tax + deliveryFee),
  );
}

/* ===================== الوقت ===================== */

const dayNames = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

List<WorkingHour> defaultWorkingHours() =>
    List.generate(7, (_) => WorkingHour(closed: false, open: '11:00', close: '23:59'));

/// فهرس اليوم كما في JavaScript: الأحد 0 ... السبت 6
int jsDay(DateTime d) => d.weekday % 7;

/// التاريخ الحالي بصيغة toISOString في الموقع (UTC بثلاث خانات للملّي ثانية)،
/// فتبقى المقارنة النصية بين التواريخ صحيحة أيًّا كان مصدرها.
String isoNow() => isoAt(DateTime.now());

String isoAt(DateTime d) =>
    DateTime.fromMillisecondsSinceEpoch(d.millisecondsSinceEpoch, isUtc: true).toIso8601String();

DateTime parseIso(String iso) => (DateTime.tryParse(iso) ?? DateTime.now()).toLocal();

String _two(int n) => n.toString().padLeft(2, '0');

String formatTime(String iso) {
  final d = parseIso(iso);
  return '${_two(d.hour)}:${_two(d.minute)}';
}

String formatDate(String iso) {
  final d = parseIso(iso);
  return '${d.year}/${_two(d.month)}/${_two(d.day)}';
}

String timeAgo(String iso) {
  final mins = minutesSince(iso);
  if (mins < 1) return 'الآن';
  if (mins < 60) return 'قبل ${_ago(mins, 'دقيقة', 'دقيقتين', 'دقائق', 'دقيقة')}';
  final hrs = mins ~/ 60;
  if (hrs < 24) return 'قبل ${_ago(hrs, 'ساعة', 'ساعتين', 'ساعات', 'ساعة')}';
  final days = hrs ~/ 24;
  if (days == 1) return 'أمس';
  return 'قبل ${_ago(days, 'يوم', 'يومين', 'أيام', 'يومًا')}';
}

/// «دقيقة»، «دقيقتين»، «٥ دقائق»، «١٥ دقيقة» — العدد بعد «قبل» مجرور
String _ago(int n, String one, String two, String few, String many) {
  if (n == 1) return one;
  if (n == 2) return two;
  if (n % 100 >= 3 && n % 100 <= 10) return '$n $few';
  return '$n $many';
}

/// دقائق مرّت — للتلوين التحذيري في شاشة الطلبات
int minutesSince(String iso) => (DateTime.now().difference(parseIso(iso)).inMilliseconds / 60000).floor();

bool isSameDay(String iso, [DateTime? ref]) {
  final d = parseIso(iso);
  final r = ref ?? DateTime.now();
  return d.year == r.year && d.month == r.month && d.day == r.day;
}

int _minutesOf(String hhmm) {
  final parts = hhmm.split(':');
  final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
  return h * 60 + m;
}

bool isOpenNow(List<WorkingHour> hours, [DateTime? at]) {
  final now = at ?? DateTime.now();
  final index = jsDay(now);
  if (index >= hours.length) return false;
  final today = hours[index];
  if (today.closed) return false;
  final mins = now.hour * 60 + now.minute;
  final open = _minutesOf(today.open);
  final close = _minutesOf(today.close);
  // يتعامل مع الدوام الممتد بعد منتصف الليل (مثال 17:00 إلى 02:00)
  return close >= open ? mins >= open && mins <= close : mins >= open || mins <= close;
}

/* ===================== تسميات عربية ===================== */

const orderTypeLabel = <OrderType, String>{
  OrderType.dineIn: 'في المطعم',
  OrderType.pickup: 'استلام',
  OrderType.delivery: 'توصيل',
};

const orderStatusLabel = <OrderStatus, String>{
  OrderStatus.newOrder: 'جديد',
  OrderStatus.preparing: 'قيد التجهيز',
  OrderStatus.ready: 'جاهز',
  OrderStatus.completed: 'مكتمل',
  OrderStatus.cancelled: 'ملغي',
};

/// الترتيب المسموح للانتقال بين الحالات
const statusFlow = [OrderStatus.newOrder, OrderStatus.preparing, OrderStatus.ready, OrderStatus.completed];

OrderStatus? nextStatus(OrderStatus current) {
  final i = statusFlow.indexOf(current);
  if (i == -1 || i == statusFlow.length - 1) return null;
  return statusFlow[i + 1];
}

/* ===================== أدوات متنوعة ===================== */

/// حرف استهلالي للطبق أو المطعم عند غياب الصورة
String initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '؟' : String.fromCharCode(trimmed.runes.first);
}

/// حرف شارة المطعم: «ال» التعريف تُتخطّى — ألف «الركن» وحدها تُقرأ رقم ١،
/// والحرف الذي يميّز الاسم هو ما بعدها.
String brandInitial(String name) {
  final trimmed = name.trim();
  final rest = trimmed.replaceFirst(RegExp(r'^ال(?=\S)'), '');
  return initial(rest.isEmpty ? trimmed : rest);
}

/// لون ثابت مشتق من النص — لبطاقات الأطباق بلا صور (درجة لون 0..359)
int tintFromName(String name) {
  var h = 0;
  for (var i = 0; i < name.length; i++) {
    h = (h * 31 + name.codeUnitAt(i)) % 360;
  }
  return h;
}

/// الأرقام الهندية (٠١٢…) والفارسية (۰۱۲…) تُحوَّل للاتينية: لوحات المفاتيح
/// العربية على الجوال تكتبها أحيانًا، وبدون التحويل يسقط الرقم كله.
String toLatinDigits(String input) {
  final out = StringBuffer();
  for (final code in input.runes) {
    if (code >= 0x0660 && code <= 0x0669) {
      out.writeCharCode(0x30 + code - 0x0660);
    } else if (code >= 0x06F0 && code <= 0x06F9) {
      out.writeCharCode(0x30 + code - 0x06F0);
    } else {
      out.writeCharCode(code);
    }
  }
  return out.toString();
}

String normalizePhone(String phone) => toLatinDigits(phone).replaceAll(RegExp(r'[^\d+]'), '');

bool isValidPhone(String phone) {
  final p = normalizePhone(phone);
  return p.length >= 9 && p.length <= 15;
}

/// يقرأ رقمًا كتبه المستخدم: يقبل الأرقام العربية والفاصلة العشرية العربية.
/// يُرجع null للنص الفارغ أو غير الرقمي.
double? parseAmount(String input) {
  final cleaned = toLatinDigits(
    input.trim(),
  ).replaceAll('٫', '.').replaceAll('،', '.').replaceAll(',', '.').replaceAll('−', '-');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || !value.isFinite) return null;
  return value;
}

/// مقارنة «طبيعية»: «طاولة 2» قبل «طاولة 10» — بديل localeCompare(numeric)
int naturalCompare(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final ma = re.allMatches(a).toList();
  final mb = re.allMatches(b).toList();
  for (var i = 0; i < min(ma.length, mb.length); i++) {
    final x = ma[i].group(0)!;
    final y = mb[i].group(0)!;
    final nx = int.tryParse(x);
    final ny = int.tryParse(y);
    final c = nx != null && ny != null ? nx.compareTo(ny) : x.compareTo(y);
    if (c != 0) return c;
  }
  return ma.length.compareTo(mb.length);
}

/// تطبيع النص العربي للبحث: يوحّد الألف والتاء المربوطة والياء، ويحذف
/// التشكيل والتطويل — فـ«احمد» يجد «أحمد» و«كنافه» يجد «كنافة».
String normalizeForSearch(String input) => input
    .toLowerCase()
    .replaceAll(RegExp('[ً-ٰٟـ]'), '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي')
    .trim();

/// هل يحتوي النص على الاستعلام بعد التطبيع؟
bool matchesQuery(String text, String query) {
  final q = normalizeForSearch(query);
  return q.isEmpty || normalizeForSearch(text).contains(q);
}
