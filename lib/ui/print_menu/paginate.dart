/// توزيع المنيو على صفحات A4 وأعمدة — منقول من paginate.ts في الموقع.
///
/// دالة صافية بلا واجهة: تستلم ارتفاعات مقيسة مسبقًا وتُرجع خطة الصفحات،
/// فيمكن فحصها في اختبار. القواعد:
/// - الطبق لا ينقسم بين عمودين.
/// - عنوان القسم لا يبقى وحيدًا أسفل العمود: يُوضع مع أول طبق أو ينتقلان معًا.
/// - القسم الذي يكمل في عمود جديد يُعاد عنوانه بصيغة «تابع».
library;

class MeasuredDish {
  const MeasuredDish(this.id, this.height);

  final String id;
  final double height;
}

class MeasuredSection {
  const MeasuredSection({required this.id, required this.head, required this.cont, required this.dishes});

  final String id;

  /// ارتفاع العنوان بمسافته العلوية
  final double head;

  /// ارتفاع عنوان «تابع» (بلا مسافة علوية لأنه أول العمود دائمًا)
  final double cont;
  final List<MeasuredDish> dishes;
}

sealed class PageBlock {
  const PageBlock(this.sectionId);

  final String sectionId;
}

class HeadBlock extends PageBlock {
  const HeadBlock(super.sectionId, {required this.atTop});

  final bool atTop;
}

class ContBlock extends PageBlock {
  const ContBlock(super.sectionId);
}

class DishBlock extends PageBlock {
  const DishBlock(super.sectionId, this.dishId);

  final String dishId;
}

class PagePlan {
  PagePlan(int columns) : columns = List.generate(columns, (_) => <PageBlock>[]);

  final List<List<PageBlock>> columns;
}

List<PagePlan> paginate({
  required List<MeasuredSection> sections,

  /// ارتفاع العمود المتاح في الصفحة الأولى (ترويستها أطول)
  required double firstCapacity,
  required double capacity,
  required int columns,

  /// المسافة فوق عنوان القسم — تُحذف حين يكون العنوان أول العمود
  required double headGap,
}) {
  final pages = <PagePlan>[];
  var page = PagePlan(columns);
  var col = 0;
  var used = 0.0;

  double limit() => pages.isEmpty ? firstCapacity : capacity;

  void nextColumn() {
    col++;
    used = 0;
    if (col >= columns) {
      pages.add(page);
      page = PagePlan(columns);
      col = 0;
    }
  }

  for (final section in sections) {
    for (final (index, dish) in section.dishes.indexed) {
      for (;;) {
        final atTop = used == 0;
        final PageBlock? head = index == 0
            ? HeadBlock(section.id, atTop: atTop)
            : atTop
            ? ContBlock(section.id)
            : null;
        final headHeight = switch (head) {
          HeadBlock() => section.head - (atTop ? headGap : 0),
          ContBlock() => section.cont,
          _ => 0.0,
        };
        final need = headHeight + dish.height;

        // أول العمود يقبل الطبق مهما طال، وإلا دار التوزيع بلا نهاية
        if (atTop || used + need <= limit()) {
          if (head != null) page.columns[col].add(head);
          page.columns[col].add(DishBlock(section.id, dish.id));
          used += need;
          break;
        }
        nextColumn();
      }
    }
  }

  if (page.columns.any((column) => column.isNotEmpty)) pages.add(page);
  return pages;
}
