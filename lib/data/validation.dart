import 'dart:math';

import 'models.dart';
import 'utils.dart';

/// التحقق من صحة سطر السلة — منطق نقي بلا قاعدة بيانات وبلا واجهة.
///
/// هذا الملف هو المصدر الوحيد لقواعد «ما الذي يُعتبر سطرًا صالحًا».
/// تستدعيه الواجهة (لوح الطبق) لتعطيل الزر وإظهار الأخطاء قبل الإضافة،
/// ويستدعيه createOrder ليرفض ما وصله مهما كان مصدره — فالواجهة ليست حارسًا.
/// مطابق لـ src/lib/data/validation.ts في الموقع حرفيًا.

/// أقصى كمية لسطر واحد. مطابق للحد في عدّاد الكمية داخل الواجهة.
const maxLineQty = 50;

/// أقصى سعر مقبول — يحمي من قيم عبثية ومن فيضان الحساب
const maxMoney = 1000000.0;

enum IssueCode {
  dishMissing,
  dishUnavailable,
  qtyInvalid,
  unknownGroup,
  unknownOption,
  duplicateOption,
  belowMin,
  aboveMax,
}

class Issue {
  const Issue(this.code, this.message, [this.groupId]);

  final IssueCode code;

  /// المجموعة المعنية إن وُجدت — تستخدمها الواجهة لتلوين الحقل
  final String? groupId;

  /// رسالة عربية جاهزة للعرض
  final String message;
}

/* ===================== حرّاس القيم ===================== */

bool isMoney(num? value) => value != null && value.isFinite && value >= 0 && value <= maxMoney;

/// فرق سعر الخيار يقبل السالب (نصف طلب، بلا جبن)
bool isDelta(num? value) => value != null && value.isFinite && value >= -maxMoney && value <= maxMoney;

bool isQty(num? value) => value != null && value is int && value >= 1 && value <= maxLineQty;

bool isText(String? value, int minLength) => value != null && value.trim().length >= minLength;

/* ===================== قواعد الاختيارات ===================== */

/// الحد الأدنى الفعلي لمجموعة: الإجبارية تعني واحدًا على الأقل مهما كان min_select
int effectiveMin(GroupWithOptions group) => group.isRequired ? max(1, group.minSelect) : max(0, group.minSelect);

/// الحد الأقصى الفعلي: مجموعة الاختيار الواحد لا تقبل أكثر من واحد. 0 = بلا حد
int effectiveMax(GroupWithOptions group) => group.type == OptionGroupType.single ? 1 : max(0, group.maxSelect);

/// يوحّد الاختيارات في خريطة مجموعة → معرّفات، ويكشف المشاكل البنيوية.
/// التوحيد ضروري لأن القائمة القادمة من الخارج قد تكرّر المجموعة نفسها.
({Map<String, List<String>> chosen, List<Issue> issues}) _collect(
  DishWithOptions dish,
  List<CartSelection> selections,
) {
  final issues = <Issue>[];
  final chosen = <String, List<String>>{for (final g in dish.groups) g.id: <String>[]};

  for (final selection in selections) {
    GroupWithOptions? group;
    for (final g in dish.groups) {
      if (g.id == selection.groupId) group = g;
    }
    if (group == null) {
      issues.add(Issue(IssueCode.unknownGroup, 'هذا الخيار لا يخصّ هذا الطبق', selection.groupId));
      continue;
    }
    final bucket = chosen[group.id]!;
    for (final optionId in selection.optionIds) {
      // الخيار يجب أن يكون داخل هذه المجموعة تحديدًا — لا في أي مجموعة أخرى.
      // بدون هذا الشرط يمكن تمرير خيار سالب من طبق آخر وتخفيض السعر.
      if (!group.options.any((o) => o.id == optionId)) {
        issues.add(Issue(IssueCode.unknownOption, 'خيار غير صالح في «${group.name}»', group.id));
        continue;
      }
      if (bucket.contains(optionId)) {
        // تكرار الخيار نفسه كان يضاعف فرق سعره
        issues.add(Issue(IssueCode.duplicateOption, 'خيار مكرّر في «${group.name}»', group.id));
        continue;
      }
      bucket.add(optionId);
    }
  }

  return (chosen: chosen, issues: issues);
}

/// يتحقق من اختيارات طبق واحد. يُستدعى من الواجهة مباشرة (لا يحتاج قاعدة بيانات).
/// يُعيد قائمة فارغة إذا كان كل شيء سليمًا.
List<Issue> checkSelections(DishWithOptions dish, List<CartSelection> selections) {
  final (:chosen, :issues) = _collect(dish, selections);

  for (final group in dish.groups) {
    final count = chosen[group.id]!.length;
    final lo = effectiveMin(group);
    final hi = effectiveMax(group);
    if (count < lo) {
      issues.add(
        Issue(
          IssueCode.belowMin,
          lo == 1 ? 'اختر من «${group.name}»' : 'اختر $lo على الأقل من «${group.name}»',
          group.id,
        ),
      );
    }
    if (hi > 0 && count > hi) {
      issues.add(Issue(IssueCode.aboveMax, 'أقصى اختيار من «${group.name}» هو $hi', group.id));
    }
  }

  return issues;
}

/// يسعّر اختيارات صالحة. يتجاهل ما ليس في الطبق، لكن الاستدعاء الصحيح
/// يمرّ بـ checkSelections أولًا فلا يصل إليه شيء غير صالح أصلًا.
({List<OptionName> optionNames, double unitPrice}) priceSelections(
  DishWithOptions dish,
  List<CartSelection> selections,
) {
  final (:chosen, issues: _) = _collect(dish, selections);
  final optionNames = <OptionName>[];
  var delta = 0.0;

  // نمشي على مجموعات الطبق بترتيبها، لا بترتيب ما وصل، ليكون العرض ثابتًا
  for (final group in dish.groups) {
    for (final optionId in chosen[group.id] ?? const <String>[]) {
      for (final option in group.options) {
        if (option.id != optionId) continue;
        optionNames.add(OptionName(option.name, option.priceDelta));
        delta += option.priceDelta;
      }
    }
  }

  // السعر لا ينزل تحت الصفر مهما بلغت الخصومات
  return (optionNames: optionNames, unitPrice: max(0.0, round2(dish.dish.price + delta)));
}

/// رسالة موجزة تصلح للعرض حين نملك خطأ واحدًا فقط
String firstMessage(List<Issue> issues, [String fallback = 'تعذّر إتمام الطلب']) =>
    issues.isEmpty ? fallback : issues.first.message;
