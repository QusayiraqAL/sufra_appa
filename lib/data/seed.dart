import 'models.dart';
import 'utils.dart';

/// مطعم تجريبي واحد كامل — أقسام وأطباق وخيارات وطاولات وطلبات سابقة.
/// نفس بيانات الموقع (src/lib/mock/seed.ts) حرفيًا، ليكون التطبيق قابلًا
/// للتجربة فورًا: التقارير ليست فارغة، وشاشة الطلبات فيها طلبات حقيقية،
/// والمنيو فيه عرض وطبق نافد.

const _rId = 'rest_demo';

const _min = 60000;
const _hour = 60 * _min;
const _day = 24 * _hour;

String _ago(int ms) => isoAt(DateTime.now().subtract(Duration(milliseconds: ms)));

const dbVersion = 1;

/// بيانات الدخول التجريبية — تُعرض في شاشة الدخول لتسهيل التجربة
class DemoAccount {
  const DemoAccount(this.phone, this.password, this.label);

  final String phone;
  final String password;
  final String label;
}

const demoAccounts = [
  DemoAccount('0551234567', '123456', 'صاحب المطعم'),
  DemoAccount('0559876543', '123456', 'كاشير'),
  DemoAccount('0500000000', 'admin123', 'مشرف المنصة'),
];

const demoSlug = 'al-rukn';

List<Plan> _plans() => [
  Plan(
    id: 'plan_free',
    name: 'مجانية',
    price: 0,
    maxDishes: 0,
    maxTables: 0,
    features: ['منيو غير محدود', 'طلبات غير محدودة', 'رمز QR', 'تقارير أساسية'],
    isActive: true,
  ),
  Plan(
    id: 'plan_basic',
    name: 'أساسية',
    price: 49,
    maxDishes: 0,
    maxTables: 0,
    features: ['كل مزايا المجانية', 'إشعار واتساب', 'حسابات موظفين', 'تقارير متقدمة'],
    isActive: false,
  ),
  Plan(
    id: 'plan_pro',
    name: 'متقدمة',
    price: 99,
    maxDishes: 0,
    maxTables: 0,
    features: ['كل مزايا الأساسية', 'دفع إلكتروني', 'فروع متعددة', 'دومين خاص'],
    isActive: false,
  ),
];

Restaurant _restaurant() => Restaurant(
  id: _rId,
  slug: demoSlug,
  name: 'الركن الشامي',
  description: 'مشاوي ومقبلات شامية على أصولها — طازج يوميًا',
  ownerName: 'خالد العمري',
  phone: '0551234567',
  logoUrl: null,
  coverUrl: null,
  themeColor: '#0e6b4f',
  template: MenuTemplate.classic,
  currency: 'SAR',
  taxRate: 15,
  taxIncluded: false,
  workingHours: [
    for (final (i, h) in defaultWorkingHours().indexed)
      i == 5 ? WorkingHour(closed: h.closed, open: '13:00', close: '23:59') : h,
  ],
  dineInEnabled: true,
  pickupEnabled: true,
  deliveryEnabled: true,
  deliveryFee: 12,
  minOrder: 30,
  isActive: true,
  planId: 'plan_free',
  createdAt: _ago(40 * _day),
);

List<Profile> _profiles() => [
  Profile(
    id: 'prof_owner',
    name: 'خالد العمري',
    phone: '0551234567',
    password: '123456',
    role: Role.owner,
    restaurantId: _rId,
    createdAt: _ago(40 * _day),
  ),
  Profile(
    id: 'prof_staff',
    name: 'سعود الحربي',
    phone: '0559876543',
    password: '123456',
    role: Role.staff,
    restaurantId: _rId,
    createdAt: _ago(12 * _day),
  ),
  Profile(
    id: 'prof_admin',
    name: 'مشرف المنصة',
    phone: '0500000000',
    password: 'admin123',
    role: Role.admin,
    restaurantId: null,
    createdAt: _ago(60 * _day),
  ),
];

List<Category> _categories() => [
  for (final (i, name) in const ['مقبلات', 'مشاوي', 'أطباق رئيسية', 'مناقيش وفطائر', 'حلويات', 'مشروبات'].indexed)
    Category(id: 'cat_${i + 1}', restaurantId: _rId, name: name, sortOrder: i, isVisible: true),
];

class _DishSeed {
  const _DishSeed(
    this.id,
    this.name,
    this.description,
    this.price, {
    this.compareAt,
    this.featured = false,
    this.allowNote = false,
    this.available = true,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final double? compareAt;
  final bool featured;
  final bool allowNote;
  final bool available;
}

const _dishSeeds = <String, List<_DishSeed>>{
  'cat_1': [
    _DishSeed('dish_1', 'حمص بالطحينة', 'حمص مطحون ناعم، طحينة، زيت زيتون بكر وحبّة بركة', 14),
    _DishSeed('dish_2', 'متبل باذنجان', 'باذنجان مشوي على الفحم مع لبن وثوم', 14),
    _DishSeed('dish_3', 'تبولة', 'برغل ناعم، بقدونس، طماطم، ليمون طازج', 16),
    _DishSeed('dish_4', 'فتوش', 'خضار موسمية مع خبز محمّص ودبس رمان', 18, compareAt: 24),
    _DishSeed('dish_5', 'ورق عنب', 'ملفوف يدويًا محشو أرز وخضار — ١٢ حبة', 24),
    _DishSeed('dish_6', 'كبة مقلية', 'أربع حبات محشوة لحم وصنوبر', 22),
  ],
  'cat_2': [
    _DishSeed('dish_7', 'شيش طاووق', 'قطع دجاج متبّلة بالزبادي والليمون على الفحم', 42, allowNote: true),
    _DishSeed('dish_8', 'كباب لحم', 'لحم مفروم طازج مع بقدونس وبصل', 48),
    _DishSeed('dish_9', 'ريش غنم', 'ريش نجدية مشوية على الفحم', 75),
    _DishSeed(
      'dish_10',
      'مشاوي مشكّلة',
      'شيش طاووق، كباب، ريش، وشقف — مع الأرز والصوصات',
      95,
      featured: true,
      allowNote: true,
    ),
    _DishSeed('dish_11', 'شقف دجاج', 'قطع صدور دجاج متبّلة بالسماق', 45),
  ],
  'cat_3': [
    _DishSeed('dish_12', 'شاورما دجاج بالصاج', 'شاورما دجاج، بطاطس، مخلل، وصوص ثوم', 28, allowNote: true),
    _DishSeed('dish_13', 'شاورما لحم', 'لحم شاورما مع طحينة وبقدونس وبصل', 34, allowNote: true),
    _DishSeed('dish_14', 'مندي دجاج', 'نصف دجاجة على الأرز المندي مع الدقوس', 38),
    _DishSeed('dish_15', 'فتة حمص باللحم', 'خبز، حمص، لبن، صنوبر، ولحم مفروم', 42),
    _DishSeed('dish_16', 'كبسة لحم', 'أرز كبسة مع لحم طري ومكسرات', 55, featured: true),
    _DishSeed('dish_17', 'صيادية سمك', 'سمك هامور مع أرز الصيادية والبصل المحمّر', 65, available: false),
  ],
  'cat_4': [
    _DishSeed('dish_18', 'منقوشة زعتر', 'زعتر بلدي وزيت زيتون على عجين طازج', 8),
    _DishSeed('dish_19', 'منقوشة جبنة', 'جبنة عكاوي مع حبّة بركة', 12),
    _DishSeed('dish_20', 'فطاير سبانخ', 'ثلاث حبات بالسماق والبصل', 12),
    _DishSeed('dish_21', 'لحم بعجين', 'لحم مفروم مع دبس رمان وصنوبر', 14),
  ],
  'cat_5': [
    _DishSeed('dish_22', 'كنافة بالجبنة', 'كنافة ناعمة مع جبنة وقطر — تُقدّم ساخنة', 22, featured: true),
    _DishSeed('dish_23', 'بقلاوة', 'ست حبات مشكّلة بالفستق والكاجو', 18),
    _DishSeed('dish_24', 'مهلبية', 'مهلبية بالفستق وماء الزهر', 12),
    _DishSeed('dish_25', 'أم علي', 'تُقدّم ساخنة مع المكسرات والقشطة', 20),
  ],
  'cat_6': [
    _DishSeed('dish_26', 'شاي أحمر', 'براد صغير مع النعنع', 5),
    _DishSeed('dish_27', 'قهوة عربية', 'دلّة قهوة مع التمر', 8),
    _DishSeed('dish_28', 'عصير ليمون بالنعنع', 'طازج، يُعصر عند الطلب', 14),
    _DishSeed('dish_29', 'ليموناضة', 'ليمون، سكر، ماء غازي', 12),
    _DishSeed('dish_30', 'مياه معدنية', '٦٠٠ مل', 3),
  ],
};

List<Dish> _dishes() => [
  for (final entry in _dishSeeds.entries)
    for (final (i, d) in entry.value.indexed)
      Dish(
        id: d.id,
        restaurantId: _rId,
        categoryId: entry.key,
        name: d.name,
        description: d.description,
        price: d.price,
        compareAtPrice: d.compareAt,
        imageUrl: null,
        isAvailable: d.available,
        isFeatured: d.featured,
        allowNote: d.allowNote,
        sortOrder: i,
      ),
];

class _GroupSeed {
  const _GroupSeed(this.id, this.dishId, this.name, this.type, this.required, this.min, this.max, this.options);

  final String id;
  final String dishId;
  final String name;
  final OptionGroupType type;
  final bool required;
  final int min;
  final int max;
  final List<(String, double, bool)> options;
}

const _single = OptionGroupType.single;
const _multi = OptionGroupType.multi;

const _groupSeeds = [
  _GroupSeed('grp_1', 'dish_12', 'الحجم', _single, true, 1, 1, [
    ('صغير', 0, true),
    ('وسط', 6, false),
    ('كبير', 12, false),
  ]),
  _GroupSeed('grp_2', 'dish_12', 'إضافات', _multi, false, 0, 0, [
    ('بطاطس زيادة', 5, false),
    ('جبنة', 4, false),
    ('صوص ثوم زيادة', 2, false),
    ('مخلل زيادة', 2, false),
  ]),
  _GroupSeed('grp_3', 'dish_13', 'الحجم', _single, true, 1, 1, [('صغير', 0, true), ('كبير', 10, false)]),
  _GroupSeed('grp_4', 'dish_10', 'عدد الأشخاص', _single, true, 1, 1, [('شخصان', 0, true), ('أربعة أشخاص', 85, false)]),
  _GroupSeed('grp_5', 'dish_10', 'الجانب', _single, true, 1, 1, [
    ('أرز بخاري', 0, true),
    ('خبز تنور', 0, false),
    ('بطاطس مقلية', 8, false),
  ]),
  _GroupSeed('grp_6', 'dish_16', 'نوع اللحم', _single, true, 1, 1, [('لحم غنم', 0, true), ('لحم بقر', -8, false)]),
  _GroupSeed('grp_7', 'dish_16', 'إضافات', _multi, false, 0, 2, [
    ('دقوس', 2, false),
    ('سلطة', 6, false),
    ('لبن', 4, false),
  ]),
  _GroupSeed('grp_8', 'dish_7', 'الكمية', _single, true, 1, 1, [('طلب كامل', 0, true), ('نصف طلب', -14, false)]),
  _GroupSeed('grp_9', 'dish_18', 'إضافات', _multi, false, 0, 0, [('جبنة', 4, false), ('خضار', 3, false)]),
  _GroupSeed('grp_10', 'dish_27', 'التحضير', _single, true, 1, 1, [('سادة', 0, true), ('زعفران زيادة', 3, false)]),
];

List<RestaurantTable> _tables() => [
  for (var i = 0; i < 8; i++)
    RestaurantTable(
      id: 'tbl_${i + 1}',
      restaurantId: _rId,
      label: 'طاولة ${i + 1}',
      qrToken: 't${i + 1}x${(i + 1) * 7919}',
    ),
];

class _LineSeed {
  const _LineSeed(this.dishId, this.qty, {this.note = '', this.options = const []});

  final String dishId;
  final int qty;
  final String note;
  final List<(String, double)> options;
}

class _OrderSeed {
  const _OrderSeed({
    required this.id,
    required this.number,
    required this.type,
    this.table,
    required this.name,
    required this.phone,
    this.address = '',
    this.note = '',
    required this.status,
    required this.msAgo,
    required this.lines,
  });

  final String id;
  final int number;
  final OrderType type;
  final String? table;
  final String name;
  final String phone;
  final String address;
  final String note;
  final OrderStatus status;
  final int msAgo;
  final List<_LineSeed> lines;
}

const _orderSeeds = [
  _OrderSeed(
    id: 'ord_1',
    number: 1041,
    type: OrderType.dineIn,
    table: 'tbl_3',
    name: 'زبون الطاولة',
    phone: '',
    status: OrderStatus.newOrder,
    msAgo: 3 * _min,
    lines: [
      _LineSeed('dish_12', 2, options: [('وسط', 6), ('جبنة', 4)], note: 'بدون مخلل'),
      _LineSeed('dish_29', 2),
    ],
  ),
  _OrderSeed(
    id: 'ord_2',
    number: 1040,
    type: OrderType.delivery,
    name: 'أم عبدالله',
    phone: '0553334444',
    address: 'حي النرجس، شارع الأمير سلطان، عمارة ١٢، الدور ٣',
    status: OrderStatus.newOrder,
    msAgo: 9 * _min,
    lines: [
      _LineSeed('dish_16', 1, options: [('لحم غنم', 0), ('دقوس', 2)]),
      _LineSeed('dish_1', 1),
      _LineSeed('dish_22', 2),
    ],
  ),
  _OrderSeed(
    id: 'ord_3',
    number: 1039,
    type: OrderType.pickup,
    name: 'فيصل',
    phone: '0567778888',
    status: OrderStatus.preparing,
    msAgo: 22 * _min,
    note: 'أجي بعد نصف ساعة',
    lines: [
      _LineSeed('dish_10', 1, options: [('أربعة أشخاص', 85), ('أرز بخاري', 0)]),
      _LineSeed('dish_4', 1),
    ],
  ),
  _OrderSeed(
    id: 'ord_4',
    number: 1038,
    type: OrderType.dineIn,
    table: 'tbl_6',
    name: 'زبون الطاولة',
    phone: '',
    status: OrderStatus.ready,
    msAgo: 34 * _min,
    lines: [
      _LineSeed('dish_7', 1, options: [('طلب كامل', 0)]),
      _LineSeed('dish_3', 1),
      _LineSeed('dish_26', 1),
    ],
  ),
  _OrderSeed(
    id: 'ord_5',
    number: 1037,
    type: OrderType.dineIn,
    table: 'tbl_1',
    name: 'زبون الطاولة',
    phone: '',
    status: OrderStatus.completed,
    msAgo: 2 * _hour,
    lines: [
      _LineSeed('dish_9', 2),
      _LineSeed('dish_5', 1),
      _LineSeed('dish_27', 2, options: [('زعفران زيادة', 3)]),
    ],
  ),
  _OrderSeed(
    id: 'ord_6',
    number: 1036,
    type: OrderType.delivery,
    name: 'ناصر القحطاني',
    phone: '0501112222',
    address: 'حي الياسمين، شارع ١٥',
    status: OrderStatus.completed,
    msAgo: 4 * _hour,
    lines: [
      _LineSeed('dish_12', 3, options: [('كبير', 12)]),
      _LineSeed('dish_30', 3),
    ],
  ),
  _OrderSeed(
    id: 'ord_7',
    number: 1035,
    type: OrderType.pickup,
    name: 'هند',
    phone: '0544445555',
    status: OrderStatus.cancelled,
    msAgo: 5 * _hour,
    lines: [_LineSeed('dish_14', 1)],
  ),
  _OrderSeed(
    id: 'ord_8',
    number: 1030,
    type: OrderType.dineIn,
    table: 'tbl_4',
    name: 'زبون الطاولة',
    phone: '',
    status: OrderStatus.completed,
    msAgo: 1 * _day + 3 * _hour,
    lines: [
      _LineSeed('dish_16', 2, options: [('لحم غنم', 0)]),
      _LineSeed('dish_1', 2),
      _LineSeed('dish_22', 1),
    ],
  ),
  _OrderSeed(
    id: 'ord_9',
    number: 1028,
    type: OrderType.delivery,
    name: 'أبو تركي',
    phone: '0522223333',
    address: 'حي الملقا',
    status: OrderStatus.completed,
    msAgo: 1 * _day + 6 * _hour,
    lines: [
      _LineSeed('dish_10', 1, options: [('شخصان', 0), ('خبز تنور', 0)]),
      _LineSeed('dish_28', 2),
    ],
  ),
  _OrderSeed(
    id: 'ord_10',
    number: 1022,
    type: OrderType.pickup,
    name: 'سلمان',
    phone: '0577776666',
    status: OrderStatus.completed,
    msAgo: 2 * _day + 5 * _hour,
    lines: [
      _LineSeed('dish_12', 4, options: [('وسط', 6)]),
      _LineSeed('dish_18', 4, options: [('جبنة', 4)]),
    ],
  ),
  _OrderSeed(
    id: 'ord_11',
    number: 1015,
    type: OrderType.dineIn,
    table: 'tbl_2',
    name: 'زبون الطاولة',
    phone: '',
    status: OrderStatus.completed,
    msAgo: 3 * _day + 2 * _hour,
    lines: [_LineSeed('dish_8', 2), _LineSeed('dish_6', 1), _LineSeed('dish_23', 1)],
  ),
  _OrderSeed(
    id: 'ord_12',
    number: 1009,
    type: OrderType.delivery,
    name: 'منيرة',
    phone: '0566665555',
    address: 'حي القيروان',
    status: OrderStatus.completed,
    msAgo: 4 * _day + 4 * _hour,
    lines: [_LineSeed('dish_15', 2), _LineSeed('dish_24', 2)],
  ),
  _OrderSeed(
    id: 'ord_13',
    number: 1002,
    type: OrderType.dineIn,
    table: 'tbl_7',
    name: 'زبون الطاولة',
    phone: '',
    status: OrderStatus.completed,
    msAgo: 6 * _day + 3 * _hour,
    lines: [_LineSeed('dish_9', 1), _LineSeed('dish_11', 1), _LineSeed('dish_2', 1), _LineSeed('dish_26', 2)],
  ),
];

/// يُنشئ قاعدة البيانات التجريبية كاملة
DB createSeedDB() {
  final restaurant = _restaurant();
  final dishes = _dishes();
  final tables = _tables();

  final groups = <OptionGroup>[];
  final options = <DishOption>[];
  for (final (gi, g) in _groupSeeds.indexed) {
    groups.add(
      OptionGroup(
        id: g.id,
        dishId: g.dishId,
        name: g.name,
        type: g.type,
        isRequired: g.required,
        minSelect: g.min,
        maxSelect: g.max,
        sortOrder: gi,
      ),
    );
    for (final (oi, (name, delta, isDefault)) in g.options.indexed) {
      options.add(
        DishOption(
          id: '${g.id}_opt_${oi + 1}',
          groupId: g.id,
          name: name,
          priceDelta: delta,
          isDefault: isDefault,
          sortOrder: oi,
        ),
      );
    }
  }

  final orders = <Order>[];
  final items = <OrderItem>[];
  final itemOptions = <OrderItemOption>[];
  for (final seed in _orderSeeds) {
    var subtotal = 0.0;
    for (final (li, line) in seed.lines.indexed) {
      final dish = dishes.firstWhere((d) => d.id == line.dishId);
      final extras = line.options.fold(0.0, (s, o) => s + o.$2);
      final unit = round2(dish.price + extras);
      final lineTotal = round2(unit * line.qty);
      subtotal += lineTotal;

      final itemId = '${seed.id}_it_${li + 1}';
      items.add(
        OrderItem(
          id: itemId,
          orderId: seed.id,
          dishId: dish.id,
          dishName: dish.name,
          unitPrice: unit,
          qty: line.qty,
          note: line.note,
          lineTotal: lineTotal,
        ),
      );
      for (final (oi, (name, delta)) in line.options.indexed) {
        itemOptions.add(
          OrderItemOption(id: '${itemId}_op_${oi + 1}', orderItemId: itemId, optionName: name, priceDelta: delta),
        );
      }
    }

    final deliveryFee = seed.type == OrderType.delivery ? restaurant.deliveryFee : 0.0;
    final bill = computeBill(
      subtotal: round2(subtotal),
      taxRate: restaurant.taxRate,
      taxIncluded: restaurant.taxIncluded,
      deliveryFee: deliveryFee,
    );
    final created = _ago(seed.msAgo);
    orders.add(
      Order(
        id: seed.id,
        restaurantId: _rId,
        orderNumber: seed.number,
        type: seed.type,
        tableId: seed.table,
        tableLabel: seed.table == null ? null : tables.where((t) => t.id == seed.table).firstOrNull?.label,
        customerName: seed.name,
        customerPhone: seed.phone,
        address: seed.address,
        note: seed.note,
        status: seed.status,
        subtotal: bill.subtotal,
        taxAmount: bill.taxAmount,
        deliveryFee: bill.deliveryFee,
        total: bill.total,
        currency: restaurant.currency,
        paymentMethod: PaymentMethod.cash,
        paymentStatus: seed.status == OrderStatus.completed ? PaymentStatus.paid : PaymentStatus.unpaid,
        createdAt: created,
        updatedAt: created,
      ),
    );
  }

  return DB(
    version: dbVersion,
    restaurants: [restaurant],
    profiles: _profiles(),
    categories: _categories(),
    dishes: dishes,
    optionGroups: groups,
    options: options,
    tables: tables,
    orders: orders,
    orderItems: items,
    orderItemOptions: itemOptions,
    plans: _plans(),
    subscriptions: [
      Subscription(
        id: 'sub_demo',
        restaurantId: _rId,
        planId: 'plan_free',
        status: SubscriptionStatus.active,
        expiresAt: null,
      ),
    ],
    session: null,
    orderSeq: {_rId: 1041},
  );
}
