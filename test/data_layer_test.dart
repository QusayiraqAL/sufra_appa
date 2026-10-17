// فحص منطق طبقة البيانات — منقول من scripts/smoke-check.ts في الموقع،
// فحصًا بفحص، ليضمن أن التطبيق يحسب الفواتير والضريبة والخيارات ويرفض
// الطلبات غير الصالحة تمامًا كما يفعل الموقع.
import 'package:sufra/data/models.dart';
import 'package:sufra/data/mutations.dart';
import 'package:sufra/data/queries.dart';
import 'package:sufra/data/store.dart';
import 'package:sufra/data/utils.dart';
import 'package:sufra/data/validation.dart';
import 'package:sufra/ui/print_menu/paginate.dart';
import 'package:flutter_test/flutter_test.dart';

Restaurant rukn(DataStore s) => getRestaurantBySlug(s.db, 'al-rukn')!;

void main() {
  group('سلامة البيانات التجريبية', () {
    final store = DataStore.memory();
    final db = store.db;
    final rest = rukn(store);

    test('المطعم التجريبي موجود', () => expect(getRestaurantBySlug(db, 'al-rukn'), isNotNull));

    test('كل طبق ينتمي لقسم موجود', () {
      final catIds = {for (final c in db.categories) c.id};
      expect(db.dishes.every((d) => catIds.contains(d.categoryId)), isTrue);
    });

    test('كل مجموعة خيارات تنتمي لطبق موجود', () {
      final dishIds = {for (final d in db.dishes) d.id};
      expect(db.optionGroups.every((g) => dishIds.contains(g.dishId)), isTrue);
    });

    test('كل خيار ينتمي لمجموعة موجودة', () {
      final groupIds = {for (final g in db.optionGroups) g.id};
      expect(db.options.every((o) => groupIds.contains(o.groupId)), isTrue);
    });

    test('كل مجموعة اختيار-واحد إجبارية لها خيار مبدئي', () {
      final singles = db.optionGroups.where((g) => g.type == OptionGroupType.single && g.isRequired);
      expect(singles.every((g) => db.options.any((o) => o.groupId == g.id && o.isDefault)), isTrue);
    });

    test('توجد طلبات تجريبية', () => expect(getOrdersWithItems(db, rest.id), isNotEmpty));

    test('إجمالي كل طلب يطابق مجموع بنوده', () {
      final bad = getOrdersWithItems(db, rest.id).where((o) {
        final itemsSum = round2(o.items.fold(0.0, (s, i) => s + i.item.lineTotal));
        final bill = computeBill(
          subtotal: itemsSum,
          taxRate: rest.taxRate,
          taxIncluded: rest.taxIncluded,
          deliveryFee: o.order.deliveryFee,
        );
        return (bill.total - o.order.total).abs() > 0.011;
      });
      expect(bad, isEmpty, reason: bad.map((o) => '#${o.order.orderNumber}').join(','));
    });

    test('سعر كل بند = سعر الوحدة × الكمية', () {
      final bad = db.orderItems.where((i) => (round2(i.unitPrice * i.qty) - i.lineTotal).abs() > 0.011);
      expect(bad, isEmpty);
    });

    test('منيو العميل فيه أقسام', () => expect(getMenu(db, rest.id, visibleOnly: true), isNotEmpty));
    test('توجد أطباق ذات خيارات', () => expect(db.optionGroups, isNotEmpty));
    test('يوجد طبق نافد للعرض', () => expect(db.dishes.any((d) => !d.isAvailable), isTrue));
    test('يوجد طبق عليه عرض', () => expect(db.dishes.any((d) => d.compareAtPrice != null), isTrue));

    test('ملف JSON يعود كما خرج (توافق النسخة الاحتياطية مع الموقع)', () {
      final back = DB.fromJson(db.toJson());
      expect(back.toJson(), equals(db.toJson()));
      // الأرقام الصحيحة تُكتب بلا كسر كما في JSON الموقع
      expect(db.restaurants.first.toJson()['tax_rate'], isA<int>());
    });
  });

  group('حساب الفاتورة', () {
    test('ضريبة مضافة: 100 + 15% + 12 = 127', () {
      final b = computeBill(subtotal: 100, taxRate: 15, taxIncluded: false, deliveryFee: 12);
      expect(b.total, 127);
      expect(b.taxAmount, 15);
    });

    test('ضريبة مشمولة: الإجمالي 115 والصافي 100 والضريبة 15', () {
      final b = computeBill(subtotal: 115, taxRate: 15, taxIncluded: true, deliveryFee: 0);
      expect(b.total, 115);
      expect(b.subtotal, 100);
      expect(b.taxAmount, 15);
    });

    test('بلا ضريبة: 50', () {
      final b = computeBill(subtotal: 50, taxRate: 0, taxIncluded: false, deliveryFee: 0);
      expect(b.total, 50);
      expect(b.taxAmount, 0);
    });

    test('round2 يطابق Math.round في JavaScript', () {
      expect(round2(4.95), 4.95);
      expect(round2(1.005), 1.01);
      expect(round2(-2.5), -2.5);
      expect(round2(33 * 0.15), 4.95);
    });
  });

  group('تسعير السلة والخيارات', () {
    final store = DataStore.memory();
    final db = store.db;
    final shawarma = getDishWithOptions(db, 'dish_12')!;
    final size = shawarma.groups.firstWhere((g) => g.name == 'الحجم');
    final large = size.options.firstWhere((o) => o.name == 'كبير');
    final extras = shawarma.groups.firstWhere((g) => g.name == 'إضافات');
    final cheese = extras.options.firstWhere((o) => o.name == 'جبنة');

    final priced = priceCart(db, [
      CartLine(
        key: 'k1',
        dishId: shawarma.id,
        qty: 2,
        note: 'بدون مخلل',
        selections: [
          CartSelection(groupId: size.id, optionIds: [large.id]),
          CartSelection(groupId: extras.id, optionIds: [cheese.id]),
        ],
      ),
    ]);

    test('سطر واحد مسعّر', () => expect(priced.length, 1));
    test('سعر الوحدة 28 + 12 + 4 = 44', () => expect(priced.first.unitPrice, 44));
    test('إجمالي السطر 44 × 2 = 88', () => expect(priced.first.lineTotal, 88));
    test('أسماء الخيارات محفوظة', () => expect(priced.first.optionNames.length, 2));

    test('فرق السعر السالب يخصم: 55 − 8 = 47', () {
      final kabsa = getDishWithOptions(db, 'dish_16')!;
      final meat = kabsa.groups.firstWhere((g) => g.name == 'نوع اللحم');
      final beef = meat.options.firstWhere((o) => o.name == 'لحم بقر');
      final p2 = priceCart(db, [
        CartLine(
          key: 'k2',
          dishId: kabsa.id,
          qty: 1,
          note: '',
          selections: [
            CartSelection(groupId: meat.id, optionIds: [beef.id]),
          ],
        ),
      ]);
      expect(p2.first.unitPrice, 47);
    });

    test('عملة المطعم مضبوطة', () => expect(rukn(store).currency, 'SAR'));
  });

  group('إنشاء طلب من طرف لطرف', () {
    final store = DataStore.memory();
    final rest = rukn(store);
    final before = getOrdersWithItems(store.db, rest.id).length;
    final seqBefore = store.db.orderSeq[rest.id]!;

    final result = store.createOrder(
      CreateOrderInput(
        restaurantId: rest.id,
        type: OrderType.pickup,
        tableId: null,
        customerName: 'تجربة',
        customerPhone: '0551112223',
        address: '',
        note: 'اختبار آلي',
        lines: const [
          CartLine(key: 'a', dishId: 'dish_1', qty: 2, note: '', selections: []),
          CartLine(key: 'b', dishId: 'dish_26', qty: 1, note: '', selections: []),
        ],
      ),
    );

    test('نجح إنشاء الطلب', () => expect(result.ok, isTrue, reason: result.error));

    test('تفاصيل الطلب صحيحة', () {
      final order = getOrderWithItems(store.db, result.data!.orderId)!;
      expect(order.order.orderNumber, seqBefore + 1, reason: 'رقم الطلب تسلسلي');
      expect(getOrdersWithItems(store.db, rest.id).length, before + 1);
      expect(order.status, OrderStatus.newOrder);
      expect(order.order.subtotal, 33, reason: 'المجموع 14×2 + 5');
      expect(order.order.taxAmount, 4.95, reason: 'الضريبة 15% من 33');
      expect(order.order.total, 37.95);
      expect(order.order.deliveryFee, 0);
      expect(order.items.first.item.dishName, 'حمص بالطحينة');
    });

    test('تغيير السعر لا يغيّر الطلب القديم', () {
      store.updateDish('dish_1', (d) => d.price = 99);
      final after = getOrderWithItems(store.db, result.data!.orderId)!;
      expect(after.items.first.item.unitPrice, 14);
      expect(after.order.total, 37.95);
    });

    test('الانتقال بين الحالات يعمل والمكتمل يُعلَّم مدفوعًا', () {
      final id = result.data!.orderId;
      store.setOrderStatus(id, OrderStatus.preparing);
      store.setOrderStatus(id, OrderStatus.completed);
      final done = getOrderWithItems(store.db, id)!;
      expect(done.status, OrderStatus.completed);
      expect(done.order.paymentStatus, PaymentStatus.paid);
    });
  });

  group('رفض الطلبات غير الصالحة', () {
    final store = DataStore.memory();
    final rest = rukn(store);

    Result<({String orderId, int number})> order({
      required OrderType type,
      String phone = '0551112223',
      String address = '',
      String? tableId,
      required List<CartLine> lines,
    }) => store.createOrder(
      CreateOrderInput(
        restaurantId: rest.id,
        type: type,
        tableId: tableId,
        customerName: 'أحمد',
        customerPhone: phone,
        address: address,
        note: '',
        lines: lines,
      ),
    );

    CartLine one(String dishId) => CartLine(key: 'x', dishId: dishId, qty: 1, note: '', selections: const []);

    test('سلة فارغة تُرفض', () => expect(order(type: OrderType.pickup, lines: []).ok, isFalse));
    test('طبق نافد يُرفض', () => expect(order(type: OrderType.pickup, lines: [one('dish_17')]).ok, isFalse));
    test('جوال غير صالح يُرفض', () {
      expect(order(type: OrderType.pickup, phone: '12', lines: [one('dish_1')]).ok, isFalse);
    });
    test('عنوان ناقص للتوصيل يُرفض', () {
      expect(order(type: OrderType.delivery, address: 'قصير', lines: [one('dish_16')]).ok, isFalse);
    });
    test('طلب طاولة بلا طاولة يُرفض', () {
      expect(order(type: OrderType.dineIn, lines: [one('dish_1')]).ok, isFalse);
    });
    test('أقل من الحد الأدنى يُرفض', () {
      final r = order(type: OrderType.delivery, address: 'حي النرجس، شارع 15، مبنى 4', lines: [one('dish_30')]);
      expect(r.ok, isFalse);
    });
  });

  group('الحسابات', () {
    final store = DataStore.memory();

    test('كلمة مرور خاطئة تُرفض', () => expect(store.signIn('0551234567', 'wrong').ok, isFalse));
    test('جوال غير مسجّل يُرفض', () => expect(store.signIn('0500000999', '123456').ok, isFalse));
    test('دخول صاحب المطعم ينجح والجلسة محفوظة', () {
      final good = store.signIn('0551234567', '123456');
      expect(good.ok && good.data == Role.owner, isTrue);
      expect(store.db.session, isNotNull);
    });
    test('الأرقام العربية في الجوال تُقبل', () {
      expect(store.signIn('٠٥٥١٢٣٤٥٦٧', '123456').ok, isTrue);
    });

    test('جوال مكرّر يُرفض في التسجيل', () {
      final dup = store.signUp(
        const SignUpInput(
          ownerName: 'شخص',
          restaurantName: 'مطعم',
          phone: '0551234567',
          password: '123456',
          slug: 'another',
        ),
      );
      expect(dup.ok, isFalse);
    });

    test('رابط محجوز يُرفض', () {
      final dupSlug = store.signUp(
        const SignUpInput(
          ownerName: 'شخص',
          restaurantName: 'مطعم',
          phone: '0509998887',
          password: '123456',
          slug: 'al-rukn',
        ),
      );
      expect(dupSlug.ok, isFalse);
    });

    test('تسجيل جديد ينجح بقسم مبدئي وخطة مجانية وعدّاد مهيّأ', () {
      final fresh = store.signUp(
        const SignUpInput(
          ownerName: 'نورة',
          restaurantName: 'بيت الكبسة',
          phone: '0509998887',
          password: '123456',
          slug: 'bait-alkabsa',
        ),
      );
      expect(fresh.ok, isTrue, reason: fresh.error);
      final id = fresh.data!;
      final db = store.db;
      expect(db.categories.any((c) => c.restaurantId == id), isTrue);
      expect(db.restaurants.firstWhere((r) => r.id == id).planId, 'plan_free');
      expect(db.orderSeq[id], 1000);
      final added = store.addDish(
        id,
        categoryId: db.categories.firstWhere((c) => c.restaurantId == id).id,
        name: 'كبسة دجاج',
        price: 35,
      );
      expect(added.ok, isTrue);
    });
  });

  group('التقارير', () {
    final store = DataStore.memory();
    final db = store.db;
    final rest = rukn(store);
    final stats = reportStats(db, rest.id, 7);

    test('عدد نقاط الرسم = 7', () => expect(stats.daily.length, 7));
    test('الإيراد موجب', () => expect(stats.revenue, greaterThan(0)));
    test('متوسط الطلب = الإيراد ÷ العدد', () {
      expect((stats.avgOrder - round2(stats.revenue / stats.orders)).abs(), lessThan(0.011));
    });
    test('توجد أطباق في الأكثر طلبًا', () => expect(stats.topDishes, isNotEmpty));
    test('الملغاة محسوبة منفصلة', () => expect(stats.cancelled, greaterThanOrEqualTo(1)));
    test('الملغاة مستبعدة من الإيراد', () {
      final cancelledTotal = db.orders.where((o) => o.status == OrderStatus.cancelled).fold(0.0, (s, o) => s + o.total);
      final allTotal = db.orders.fold(0.0, (s, o) => s + o.total);
      expect(stats.revenue, lessThan(allTotal - cancelledTotal + 0.02));
    });
    test('أرقام اليوم متسقة وفيها طلبات مفتوحة', () {
      final today = todayStats(db, rest.id);
      expect(today.orders >= 0 && today.revenue >= 0, isTrue);
      expect(today.open, greaterThan(0));
    });
  });

  group('طبقة التحقق: ما كان يمرّ ولا يجب أن يمرّ', () {
    final store = DataStore.memory();
    // الحد الأدنى للطلب يحجب رسائل الرفض الأخرى، فنُلغيه لهذه المجموعة
    store.updateRestaurant(rukn(store).id, (r) => r.minOrder = 0);
    final db = store.db;
    final shawarma = getDishWithOptions(db, 'dish_12')!;
    final size = shawarma.groups.firstWhere((g) => g.name == 'الحجم');
    final medium = size.options.firstWhere((o) => o.name == 'وسط');
    final kabsa = getDishWithOptions(db, 'dish_16')!;
    final meat = kabsa.groups.firstWhere((g) => g.name == 'نوع اللحم');
    final beef = meat.options.firstWhere((o) => o.name == 'لحم بقر');

    Result<({String orderId, int number})> order(List<CartSelection> selections, [int qty = 1]) => store.createOrder(
      CreateOrderInput(
        restaurantId: rukn(store).id,
        type: OrderType.pickup,
        tableId: null,
        customerName: 'تجربة',
        customerPhone: '0551112223',
        address: '',
        note: '',
        lines: [CartLine(key: 'vk', dishId: shawarma.id, qty: qty, note: '', selections: selections)],
      ),
    );

    final valid = [
      CartSelection(groupId: size.id, optionIds: [medium.id]),
    ];

    test('مجموعة إجبارية غير مختارة تُرفض', () => expect(order([]).ok, isFalse));
    test('خيار من طبق آخر يُرفض', () {
      expect(
        order([
          CartSelection(groupId: size.id, optionIds: [medium.id]),
          CartSelection(groupId: meat.id, optionIds: [beef.id]),
        ]).ok,
        isFalse,
      );
    });
    test('الخيار المكرّر يُرفض', () {
      expect(
        order([
          CartSelection(groupId: size.id, optionIds: [medium.id, medium.id]),
        ]).ok,
        isFalse,
      );
    });
    test('أكثر من خيار في مجموعة اختيار-واحد يُرفض', () {
      expect(
        order([
          CartSelection(groupId: size.id, optionIds: [for (final o in size.options.take(2)) o.id]),
        ]).ok,
        isFalse,
      );
    });
    test('كمية سالبة أو صفر أو فوق الحد تُرفض', () {
      expect(order(valid, -5).ok, isFalse);
      expect(order(valid, 0).ok, isFalse);
      expect(order(valid, maxLineQty + 1).ok, isFalse);
    });

    test('الاختيار الصحيح يُقبل بسعر 28 + 6 = 34 وإجمالي 68', () {
      final good = order(valid, 2);
      expect(good.ok, isTrue, reason: good.error);
      final placed = getOrderWithItems(store.db, good.data!.orderId)!;
      expect(placed.items.first.item.unitPrice, 34);
      expect(placed.items.first.item.lineTotal, 68);
    });

    test('تدقيق السلة يفصل المرفوض ولا يحذفه بصمت', () {
      final audit = auditCart(store.db, [
        CartLine(key: 'ok', dishId: shawarma.id, qty: 1, note: '', selections: valid),
        const CartLine(key: 'ghost', dishId: 'dish_does_not_exist', qty: 1, note: '', selections: []),
        CartLine(key: 'bad', dishId: shawarma.id, qty: 1, note: '', selections: const []),
      ]);
      expect(audit.lines.length, 1);
      expect(audit.rejected.length, 2);
      expect(audit.rejected.any((r) => r.issues.first.code == IssueCode.dishMissing), isTrue);
      expect(audit.rejected.every((r) => r.issues.first.message.isNotEmpty), isTrue);
    });
  });

  group('تعديل الطبق: التحقق على الحالة النهائية', () {
    final store = DataStore.memory();
    const id = 'dish_12';
    double price() => getDish(store.db, id)!.price;

    test('سعر الطبق المرجعي 28', () => expect(price(), 28));
    test('«السعر قبل الخفض» وحده أقل من السعر يُرفض', () {
      expect(store.updateDish(id, (d) => d.compareAtPrice = 1).ok, isFalse);
    });
    test('«السعر قبل الخفض» أعلى من السعر يُقبل', () {
      expect(store.updateDish(id, (d) => d.compareAtPrice = 35).ok, isTrue);
    });
    test('سعر غير رقمي أو سالب أو اسم فارغ أو طبق مفقود يُرفض', () {
      expect(store.updateDish(id, (d) => d.price = double.nan).ok, isFalse);
      expect(store.updateDish(id, (d) => d.price = -10).ok, isFalse);
      expect(store.updateDish(id, (d) => d.name = ' ').ok, isFalse);
      expect(store.updateDish('dish_nope', (d) => d.price = 10).ok, isFalse);
    });
    test('السعر لم يتلوّث بالمحاولات المرفوضة', () => expect(price(), 28));
    test('خفض السعر تحت «السعر قبل الخفض» الحالي مسموح', () {
      expect(store.updateDish(id, (d) => d.price = 25).ok, isTrue);
    });
    test('رفع السعر فوق «السعر قبل الخفض» الحالي يُرفض', () {
      expect(store.updateDish(id, (d) => d.price = 40).ok, isFalse);
    });
  });

  group('المنيو الورقي: توزيع الأطباق على الصفحات', () {
    // قسمان: ٤ أطباق ثم ٣، كل طبق 100، العنوان 40 منها 20 مسافة علوية.
    // سعة الصفحة الأولى 280: يتّسع فيها عنوان القسم الثاني وحده لا مع طبقه
    List<MeasuredDish> dishes(List<String> ids) => [for (final id in ids) MeasuredDish(id, 100)];
    final sections = [
      MeasuredSection(id: 'a', head: 40, cont: 30, dishes: dishes(['a1', 'a2', 'a3', 'a4'])),
      MeasuredSection(id: 'b', head: 40, cont: 30, dishes: dishes(['b1', 'b2', 'b3'])),
    ];
    final pages = paginate(sections: sections, firstCapacity: 280, capacity: 350, columns: 2, headGap: 20);
    String ids(List<PageBlock> blocks) => blocks
        .map(
          (b) => switch (b) {
            DishBlock(:final dishId) => dishId,
            HeadBlock() => 'head:${b.sectionId}',
            ContBlock() => 'cont:${b.sectionId}',
          },
        )
        .join(',');

    test('كل طبق يظهر مرة واحدة بالترتيب', () {
      final all = pages.expand((p) => p.columns.expand((c) => c)).whereType<DishBlock>().map((b) => b.dishId);
      expect(all.join(','), 'a1,a2,a3,a4,b1,b2,b3');
    });
    test('الصفحة الأولى أقصر بسبب الترويسة', () => expect(ids(pages[0].columns[0]), 'head:a,a1,a2'));
    test('القسم المكمل في عمود جديد يُعاد عنوانه «تابع»', () {
      expect(ids(pages[0].columns[1]), 'cont:a,a3,a4');
    });
    test('العنوان لا يبقى وحيدًا أسفل العمود', () => expect(ids(pages[1].columns[0]), 'head:b,b1,b2,b3'));
    test('أول العمود بلا مسافة علوية', () => expect((pages[1].columns[0][0] as HeadBlock).atTop, isTrue));
    test('لا صفحة فارغة زائدة', () => expect(pages.length, 2));
    test('طبق أطول من العمود يُوضع ولا يعلق التوزيع', () {
      final p = paginate(
        sections: const [
          MeasuredSection(id: 'x', head: 10, cont: 10, dishes: [MeasuredDish('x1', 999)]),
        ],
        firstCapacity: 100,
        capacity: 100,
        columns: 1,
        headGap: 0,
      );
      expect(p.length, 1);
    });
    test('منيو فارغ = لا صفحات', () {
      expect(paginate(sections: const [], firstCapacity: 100, capacity: 100, columns: 2, headGap: 0), isEmpty);
    });
  });

  group('أدوات النصوص', () {
    test('slugify يحوّل العربية', () {
      expect(slugify('بيت الكبسة'), 'byt-alkbsh');
      expect(slugify('  '), 'matam');
      expect(slugify('Al Rukn!!'), 'al-rukn');
    });
    test('الترتيب الطبيعي للطاولات', () {
      final labels = ['طاولة 10', 'طاولة 2', 'طاولة 1'];
      labels.sort(naturalCompare);
      expect(labels, ['طاولة 1', 'طاولة 2', 'طاولة 10']);
    });
    test('الأرقام العربية في المبالغ', () {
      expect(parseAmount('١٢٫٥'), 12.5);
      expect(parseAmount(''), isNull);
      expect(parseAmount('abc'), isNull);
    });
    test('isOpenNow يدعم الدوام بعد منتصف الليل', () {
      final hours = List.generate(7, (_) => WorkingHour(closed: false, open: '17:00', close: '02:00'));
      expect(isOpenNow(hours, DateTime(2026, 9, 29, 23, 30)), isTrue);
      expect(isOpenNow(hours, DateTime(2026, 9, 29, 1, 30)), isTrue);
      expect(isOpenNow(hours, DateTime(2026, 9, 29, 12, 0)), isFalse);
    });
  });
}
