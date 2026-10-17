/// صيغ العدد والمعدود بالعربية: «طلب واحد»، «طلبان»، «٣ طلبات»، «١١ طلبًا».
/// العرض الصحيح للعدد جزء من جودة الواجهة العربية، لا تفصيل ثانوي.
library;

class ArabicNoun {
  const ArabicNoun({
    required this.singular,
    required this.one,
    required this.two,
    required this.plural,
    required this.accusative,
  });

  /// المفرد: «طلب» — بعد ٠ و ١٠٠ و ١٠١…
  final String singular;

  /// الواحد: «طلب واحد»
  final String one;

  /// المثنّى: «طلبان»
  final String two;

  /// الجمع بعد ٣–١٠: «طلبات»
  final String plural;

  /// التمييز المنصوب بعد ١١–٩٩: «طلبًا»
  final String accusative;
}

const nOrder = ArabicNoun(singular: 'طلب', one: 'طلب واحد', two: 'طلبان', plural: 'طلبات', accusative: 'طلبًا');
const nDish = ArabicNoun(singular: 'طبق', one: 'طبق واحد', two: 'طبقان', plural: 'أطباق', accusative: 'طبقًا');
const nItem = ArabicNoun(singular: 'بند', one: 'بند واحد', two: 'بندان', plural: 'بنود', accusative: 'بندًا');
const nTable = ArabicNoun(singular: 'طاولة', one: 'طاولة واحدة', two: 'طاولتان', plural: 'طاولات', accusative: 'طاولة');
const nStaff = ArabicNoun(singular: 'موظف', one: 'موظف واحد', two: 'موظفان', plural: 'موظفين', accusative: 'موظفًا');
const nSection = ArabicNoun(singular: 'قسم', one: 'قسم واحد', two: 'قسمان', plural: 'أقسام', accusative: 'قسمًا');
const nPage = ArabicNoun(singular: 'صفحة', one: 'صفحة واحدة', two: 'صفحتان', plural: 'صفحات', accusative: 'صفحة');
const nRestaurant = ArabicNoun(
  singular: 'مطعم',
  one: 'مطعم واحد',
  two: 'مطعمان',
  plural: 'مطاعم',
  accusative: 'مطعمًا',
);
const nOption = ArabicNoun(singular: 'خيار', one: 'خيار واحد', two: 'خياران', plural: 'خيارات', accusative: 'خيارًا');
const nTime = ArabicNoun(singular: 'مرة', one: 'مرة واحدة', two: 'مرتان', plural: 'مرات', accusative: 'مرة');
const nImage = ArabicNoun(singular: 'صورة', one: 'صورة واحدة', two: 'صورتان', plural: 'صور', accusative: 'صورة');

/// «٣ طلبات» بالأرقام اللاتينية كبقية الواجهة. [isolate] يعزل الرقم اتجاهيًا.
String countOf(int n, ArabicNoun noun, {String Function(String)? isolate}) {
  final number = isolate == null ? '$n' : isolate('$n');
  if (n == 1) return noun.one;
  if (n == 2) return noun.two;
  final tail = n % 100;
  if (n >= 3 && tail >= 3 && tail <= 10) return '$number ${noun.plural}';
  if (tail >= 11 && tail <= 99) return '$number ${noun.accusative}';
  return '$number ${noun.singular}';
}

/// المعدود وحده حسب العدد — حين يُعرض الرقم منفصلًا بخط أكبر
String nounFor(int n, ArabicNoun noun) {
  final tail = n % 100;
  if (n >= 3 && tail >= 3 && tail <= 10) return noun.plural;
  if (tail >= 11 && tail <= 99) return noun.accusative;
  return noun.singular;
}

const nOptionGroup = ArabicNoun(
  singular: 'مجموعة خيارات',
  one: 'مجموعة خيارات',
  two: 'مجموعتا خيارات',
  plural: 'مجموعات خيارات',
  accusative: 'مجموعة خيارات',
);

/// «طلب جديد»، «طلبان جديدان»، «٣ طلبات جديدة»، «١١ طلبًا جديدًا»
String newOrdersPhrase(int n, {String Function(String)? isolate}) {
  if (n == 1) return 'طلب جديد';
  if (n == 2) return 'طلبان جديدان';
  final tail = n % 100;
  final number = isolate == null ? '$n' : isolate('$n');
  if (tail >= 3 && tail <= 10) return '$number طلبات جديدة';
  if (tail >= 11 && tail <= 99) return '$number طلبًا جديدًا';
  return '$number طلب جديد';
}
