/// أنواع البيانات = جداول قاعدة البيانات، بنفس أسماء الأعمدة (snake_case)
/// المستخدمة في الموقع (src/lib/types.ts).
///
/// تطابق الأسماء مقصود: ملف النسخة الاحتياطية الذي يُنزَّل من الموقع يُستعاد
/// في التطبيق كما هو، والعكس — وحين تُربط قاعدة البيانات يصير كل صنف هنا
/// صفًّا من جدوله بلا ترجمة أسماء.
library;

/* ===================== أدوات القراءة الآمنة ===================== */

// ملف النسخة الاحتياطية يأتي من خارج التطبيق: لا نثق بأنواع قيمه.
String _str(Object? v, [String fallback = '']) => v is String ? v : fallback;
String? _strOrNull(Object? v) => v is String ? v : null;
double _num(Object? v, [double fallback = 0]) => v is num && v.isFinite ? v.toDouble() : fallback;
double? _numOrNull(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
int _int(Object? v, [int fallback = 0]) => v is num && v.isFinite ? v.toInt() : fallback;
bool _bool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;
List<Map<String, Object?>> _rows(Object? v) => v is List
    ? [
        for (final row in v)
          if (row is Map) row.cast<String, Object?>(),
      ]
    : const [];

/// الأرقام الصحيحة تُكتب بلا كسر (15 لا 15.0) كما يكتبها JSON.stringify،
/// فيبقى ملف النسخة الاحتياطية مطابقًا لما يُنتجه الموقع.
num _jsonNum(double v) => v == v.truncateToDouble() && v.abs() < 1e15 ? v.toInt() : v;

/* ===================== التعدادات ===================== */

enum Role {
  owner('owner'),
  staff('staff'),
  admin('admin');

  const Role(this.wire);
  final String wire;

  static Role parse(Object? v) => values.firstWhere((e) => e.wire == v, orElse: () => Role.staff);
}

enum OrderType {
  dineIn('dine_in'),
  pickup('pickup'),
  delivery('delivery');

  const OrderType(this.wire);
  final String wire;

  static OrderType parse(Object? v) => values.firstWhere((e) => e.wire == v, orElse: () => OrderType.pickup);
}

enum OrderStatus {
  // «new» كلمة محجوزة في Dart، والقيمة المخزّنة تبقى 'new'
  newOrder('new'),
  preparing('preparing'),
  ready('ready'),
  completed('completed'),
  cancelled('cancelled');

  const OrderStatus(this.wire);
  final String wire;

  static OrderStatus parse(Object? v) => values.firstWhere((e) => e.wire == v, orElse: () => OrderStatus.newOrder);
}

enum PaymentMethod {
  cash('cash'),
  online('online');

  const PaymentMethod(this.wire);
  final String wire;

  static PaymentMethod parse(Object? v) => values.firstWhere((e) => e.wire == v, orElse: () => PaymentMethod.cash);
}

enum PaymentStatus {
  unpaid('unpaid'),
  paid('paid');

  const PaymentStatus(this.wire);
  final String wire;

  static PaymentStatus parse(Object? v) => values.firstWhere((e) => e.wire == v, orElse: () => PaymentStatus.unpaid);
}

enum OptionGroupType {
  single('single'),
  multi('multi');

  const OptionGroupType(this.wire);
  final String wire;

  static OptionGroupType parse(Object? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => OptionGroupType.single);
}

enum MenuTemplate {
  classic('classic'),
  gallery('gallery'),
  compact('compact');

  const MenuTemplate(this.wire);
  final String wire;

  static MenuTemplate parse(Object? v) => values.firstWhere((e) => e.wire == v, orElse: () => MenuTemplate.classic);
}

enum SubscriptionStatus {
  trial('trial'),
  active('active'),
  expired('expired');

  const SubscriptionStatus(this.wire);
  final String wire;

  static SubscriptionStatus parse(Object? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => SubscriptionStatus.active);
}

/* ===================== الجداول ===================== */

/// يوم عمل واحد. الفهرس 0 = الأحد ... 6 = السبت (يطابق Date.getDay في الموقع).
class WorkingHour {
  WorkingHour({required this.closed, required this.open, required this.close});

  bool closed;

  /// "HH:mm" بنظام ٢٤ ساعة
  String open;
  String close;

  factory WorkingHour.fromJson(Map<String, Object?> j) =>
      WorkingHour(closed: _bool(j['closed']), open: _str(j['open'], '11:00'), close: _str(j['close'], '23:59'));

  Map<String, Object?> toJson() => {'closed': closed, 'open': open, 'close': close};

  WorkingHour copy() => WorkingHour(closed: closed, open: open, close: close);
}

/// جدول restaurants
class Restaurant {
  Restaurant({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.ownerName,
    required this.phone,
    required this.logoUrl,
    required this.coverUrl,
    required this.themeColor,
    required this.template,
    required this.currency,
    required this.taxRate,
    required this.taxIncluded,
    required this.workingHours,
    required this.dineInEnabled,
    required this.pickupEnabled,
    required this.deliveryEnabled,
    required this.deliveryFee,
    required this.minOrder,
    required this.isActive,
    required this.planId,
    required this.createdAt,
  });

  String id;
  String slug;
  String name;
  String description;
  String ownerName;
  String phone;
  String? logoUrl;
  String? coverUrl;
  String themeColor;
  MenuTemplate template;
  String currency;

  /// نسبة مئوية، مثال: 15
  double taxRate;

  /// true = الأسعار المعروضة شاملة الضريبة أصلًا
  bool taxIncluded;
  List<WorkingHour> workingHours;
  bool dineInEnabled;
  bool pickupEnabled;
  bool deliveryEnabled;
  double deliveryFee;
  double minOrder;
  bool isActive;
  String planId;
  String createdAt;

  factory Restaurant.fromJson(Map<String, Object?> j) {
    final hours = _rows(j['working_hours']).map(WorkingHour.fromJson).toList();
    return Restaurant(
      id: _str(j['id']),
      slug: _str(j['slug']),
      name: _str(j['name']),
      description: _str(j['description']),
      ownerName: _str(j['owner_name']),
      phone: _str(j['phone']),
      logoUrl: _strOrNull(j['logo_url']),
      coverUrl: _strOrNull(j['cover_url']),
      themeColor: _str(j['theme_color'], '#a96a00'),
      template: MenuTemplate.parse(j['template']),
      currency: _str(j['currency'], 'SAR'),
      taxRate: _num(j['tax_rate']),
      taxIncluded: _bool(j['tax_included']),
      // جدول الأوقات يُفهرس بيوم الأسبوع، فلا بد أن يكون سبعة أيام
      workingHours: hours.length == 7
          ? hours
          : List.generate(7, (_) => WorkingHour(closed: false, open: '11:00', close: '23:59')),
      dineInEnabled: _bool(j['dine_in_enabled'], true),
      pickupEnabled: _bool(j['pickup_enabled'], true),
      deliveryEnabled: _bool(j['delivery_enabled']),
      deliveryFee: _num(j['delivery_fee']),
      minOrder: _num(j['min_order']),
      isActive: _bool(j['is_active'], true),
      planId: _str(j['plan_id'], 'plan_free'),
      createdAt: _str(j['created_at']),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'slug': slug,
    'name': name,
    'description': description,
    'owner_name': ownerName,
    'phone': phone,
    'logo_url': logoUrl,
    'cover_url': coverUrl,
    'theme_color': themeColor,
    'template': template.wire,
    'currency': currency,
    'tax_rate': _jsonNum(taxRate),
    'tax_included': taxIncluded,
    'working_hours': [for (final h in workingHours) h.toJson()],
    'dine_in_enabled': dineInEnabled,
    'pickup_enabled': pickupEnabled,
    'delivery_enabled': deliveryEnabled,
    'delivery_fee': _jsonNum(deliveryFee),
    'min_order': _jsonNum(minOrder),
    'is_active': isActive,
    'plan_id': planId,
    'created_at': createdAt,
  };

  Restaurant copy() => Restaurant.fromJson(toJson());
}

/// جدول profiles. password موجود للنموذج المبدئي فقط — حين تُربط قاعدة
/// البيانات يُدار مشفّرًا في الخادم ولا يُخزّن هنا إطلاقًا.
class Profile {
  Profile({
    required this.id,
    required this.name,
    required this.phone,
    required this.password,
    required this.role,
    required this.restaurantId,
    required this.createdAt,
  });

  String id;
  String name;
  String phone;
  String password;
  Role role;
  String? restaurantId;
  String createdAt;

  factory Profile.fromJson(Map<String, Object?> j) => Profile(
    id: _str(j['id']),
    name: _str(j['name']),
    phone: _str(j['phone']),
    password: _str(j['password']),
    role: Role.parse(j['role']),
    restaurantId: _strOrNull(j['restaurant_id']),
    createdAt: _str(j['created_at']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'password': password,
    'role': role.wire,
    'restaurant_id': restaurantId,
    'created_at': createdAt,
  };

  Profile copy() => Profile.fromJson(toJson());
}

/// جدول categories
class Category {
  Category({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.sortOrder,
    required this.isVisible,
  });

  String id;
  String restaurantId;
  String name;
  int sortOrder;
  bool isVisible;

  factory Category.fromJson(Map<String, Object?> j) => Category(
    id: _str(j['id']),
    restaurantId: _str(j['restaurant_id']),
    name: _str(j['name']),
    sortOrder: _int(j['sort_order']),
    isVisible: _bool(j['is_visible'], true),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'restaurant_id': restaurantId,
    'name': name,
    'sort_order': sortOrder,
    'is_visible': isVisible,
  };

  Category copy() => Category.fromJson(toJson());
}

/// جدول dishes
class Dish {
  Dish({
    required this.id,
    required this.restaurantId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.compareAtPrice,
    required this.imageUrl,
    required this.isAvailable,
    required this.isFeatured,
    required this.allowNote,
    required this.sortOrder,
  });

  String id;
  String restaurantId;
  String categoryId;
  String name;
  String description;
  double price;

  /// السعر قبل الخفض — يُشطب في الواجهة عند وجوده
  double? compareAtPrice;
  String? imageUrl;
  bool isAvailable;
  bool isFeatured;
  bool allowNote;
  int sortOrder;

  factory Dish.fromJson(Map<String, Object?> j) => Dish(
    id: _str(j['id']),
    restaurantId: _str(j['restaurant_id']),
    categoryId: _str(j['category_id']),
    name: _str(j['name']),
    description: _str(j['description']),
    price: _num(j['price']),
    compareAtPrice: _numOrNull(j['compare_at_price']),
    imageUrl: _strOrNull(j['image_url']),
    isAvailable: _bool(j['is_available'], true),
    isFeatured: _bool(j['is_featured']),
    allowNote: _bool(j['allow_note']),
    sortOrder: _int(j['sort_order']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'restaurant_id': restaurantId,
    'category_id': categoryId,
    'name': name,
    'description': description,
    'price': _jsonNum(price),
    'compare_at_price': compareAtPrice == null ? null : _jsonNum(compareAtPrice!),
    'image_url': imageUrl,
    'is_available': isAvailable,
    'is_featured': isFeatured,
    'allow_note': allowNote,
    'sort_order': sortOrder,
  };

  Dish copy() => Dish.fromJson(toJson());
}

/// جدول option_groups — مجموعة خيارات لطبق (الحجم، درجة الاستواء، الإضافات)
class OptionGroup {
  OptionGroup({
    required this.id,
    required this.dishId,
    required this.name,
    required this.type,
    required this.isRequired,
    required this.minSelect,
    required this.maxSelect,
    required this.sortOrder,
  });

  String id;
  String dishId;
  String name;
  OptionGroupType type;
  bool isRequired;
  int minSelect;

  /// 0 = بلا حد أعلى
  int maxSelect;
  int sortOrder;

  factory OptionGroup.fromJson(Map<String, Object?> j) => OptionGroup(
    id: _str(j['id']),
    dishId: _str(j['dish_id']),
    name: _str(j['name']),
    type: OptionGroupType.parse(j['type']),
    isRequired: _bool(j['is_required']),
    minSelect: _int(j['min_select']),
    maxSelect: _int(j['max_select']),
    sortOrder: _int(j['sort_order']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'dish_id': dishId,
    'name': name,
    'type': type.wire,
    'is_required': isRequired,
    'min_select': minSelect,
    'max_select': maxSelect,
    'sort_order': sortOrder,
  };

  OptionGroup copy() => OptionGroup.fromJson(toJson());
}

/// جدول options
class DishOption {
  DishOption({
    required this.id,
    required this.groupId,
    required this.name,
    required this.priceDelta,
    required this.isDefault,
    required this.sortOrder,
  });

  String id;
  String groupId;
  String name;

  /// فرق السعر المضاف على سعر الطبق (يقبل السالب)
  double priceDelta;
  bool isDefault;
  int sortOrder;

  factory DishOption.fromJson(Map<String, Object?> j) => DishOption(
    id: _str(j['id']),
    groupId: _str(j['group_id']),
    name: _str(j['name']),
    priceDelta: _num(j['price_delta']),
    isDefault: _bool(j['is_default']),
    sortOrder: _int(j['sort_order']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'group_id': groupId,
    'name': name,
    'price_delta': _jsonNum(priceDelta),
    'is_default': isDefault,
    'sort_order': sortOrder,
  };

  DishOption copy() => DishOption.fromJson(toJson());
}

/// جدول tables
class RestaurantTable {
  RestaurantTable({required this.id, required this.restaurantId, required this.label, required this.qrToken});

  String id;
  String restaurantId;
  String label;
  String qrToken;

  factory RestaurantTable.fromJson(Map<String, Object?> j) => RestaurantTable(
    id: _str(j['id']),
    restaurantId: _str(j['restaurant_id']),
    label: _str(j['label']),
    qrToken: _str(j['qr_token']),
  );

  Map<String, Object?> toJson() => {'id': id, 'restaurant_id': restaurantId, 'label': label, 'qr_token': qrToken};

  RestaurantTable copy() => RestaurantTable.fromJson(toJson());
}

/// جدول orders
class Order {
  Order({
    required this.id,
    required this.restaurantId,
    required this.orderNumber,
    required this.type,
    required this.tableId,
    required this.tableLabel,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.note,
    required this.status,
    required this.subtotal,
    required this.taxAmount,
    required this.deliveryFee,
    required this.total,
    required this.currency,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  String id;
  String restaurantId;
  int orderNumber;
  OrderType type;
  String? tableId;

  /// نسخة مجمّدة من اسم الطاولة وقت الطلب
  String? tableLabel;
  String customerName;
  String customerPhone;
  String address;
  String note;
  OrderStatus status;
  double subtotal;
  double taxAmount;
  double deliveryFee;
  double total;
  String currency;
  PaymentMethod paymentMethod;
  PaymentStatus paymentStatus;
  String createdAt;
  String updatedAt;

  factory Order.fromJson(Map<String, Object?> j) => Order(
    id: _str(j['id']),
    restaurantId: _str(j['restaurant_id']),
    orderNumber: _int(j['order_number']),
    type: OrderType.parse(j['type']),
    tableId: _strOrNull(j['table_id']),
    tableLabel: _strOrNull(j['table_label']),
    customerName: _str(j['customer_name']),
    customerPhone: _str(j['customer_phone']),
    address: _str(j['address']),
    note: _str(j['note']),
    status: OrderStatus.parse(j['status']),
    subtotal: _num(j['subtotal']),
    taxAmount: _num(j['tax_amount']),
    deliveryFee: _num(j['delivery_fee']),
    total: _num(j['total']),
    currency: _str(j['currency'], 'SAR'),
    paymentMethod: PaymentMethod.parse(j['payment_method']),
    paymentStatus: PaymentStatus.parse(j['payment_status']),
    createdAt: _str(j['created_at']),
    updatedAt: _str(j['updated_at']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'restaurant_id': restaurantId,
    'order_number': orderNumber,
    'type': type.wire,
    'table_id': tableId,
    'table_label': tableLabel,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'address': address,
    'note': note,
    'status': status.wire,
    'subtotal': _jsonNum(subtotal),
    'tax_amount': _jsonNum(taxAmount),
    'delivery_fee': _jsonNum(deliveryFee),
    'total': _jsonNum(total),
    'currency': currency,
    'payment_method': paymentMethod.wire,
    'payment_status': paymentStatus.wire,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  Order copy() => Order.fromJson(toJson());
}

/// جدول order_items. dish_name و unit_price نسخ مجمّدة وقت الطلب:
/// تغيير سعر الطبق غدًا لا يغيّر الفواتير القديمة.
class OrderItem {
  OrderItem({
    required this.id,
    required this.orderId,
    required this.dishId,
    required this.dishName,
    required this.unitPrice,
    required this.qty,
    required this.note,
    required this.lineTotal,
  });

  String id;
  String orderId;
  String dishId;
  String dishName;
  double unitPrice;
  int qty;
  String note;
  double lineTotal;

  factory OrderItem.fromJson(Map<String, Object?> j) => OrderItem(
    id: _str(j['id']),
    orderId: _str(j['order_id']),
    dishId: _str(j['dish_id']),
    dishName: _str(j['dish_name']),
    unitPrice: _num(j['unit_price']),
    qty: _int(j['qty'], 1),
    note: _str(j['note']),
    lineTotal: _num(j['line_total']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'order_id': orderId,
    'dish_id': dishId,
    'dish_name': dishName,
    'unit_price': _jsonNum(unitPrice),
    'qty': qty,
    'note': note,
    'line_total': _jsonNum(lineTotal),
  };

  OrderItem copy() => OrderItem.fromJson(toJson());
}

/// جدول order_item_options — نسخة مجمّدة من الخيارات المختارة
class OrderItemOption {
  OrderItemOption({required this.id, required this.orderItemId, required this.optionName, required this.priceDelta});

  String id;
  String orderItemId;
  String optionName;
  double priceDelta;

  factory OrderItemOption.fromJson(Map<String, Object?> j) => OrderItemOption(
    id: _str(j['id']),
    orderItemId: _str(j['order_item_id']),
    optionName: _str(j['option_name']),
    priceDelta: _num(j['price_delta']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'order_item_id': orderItemId,
    'option_name': optionName,
    'price_delta': _jsonNum(priceDelta),
  };

  OrderItemOption copy() => OrderItemOption.fromJson(toJson());
}

/// جدول plans — مبني ومعطّل، يُشغّل حين تتحوّل المنصة لمدفوعة
class Plan {
  Plan({
    required this.id,
    required this.name,
    required this.price,
    required this.maxDishes,
    required this.maxTables,
    required this.features,
    required this.isActive,
  });

  String id;
  String name;
  double price;

  /// 0 = بلا حد
  int maxDishes;
  int maxTables;
  List<String> features;
  bool isActive;

  factory Plan.fromJson(Map<String, Object?> j) => Plan(
    id: _str(j['id']),
    name: _str(j['name']),
    price: _num(j['price']),
    maxDishes: _int(j['max_dishes']),
    maxTables: _int(j['max_tables']),
    features: j['features'] is List
        ? [
            for (final f in j['features'] as List)
              if (f is String) f,
          ]
        : <String>[],
    isActive: _bool(j['is_active']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'price': _jsonNum(price),
    'max_dishes': maxDishes,
    'max_tables': maxTables,
    'features': [...features],
    'is_active': isActive,
  };

  Plan copy() => Plan.fromJson(toJson());
}

/// جدول subscriptions — مبني ومعطّل
class Subscription {
  Subscription({
    required this.id,
    required this.restaurantId,
    required this.planId,
    required this.status,
    required this.expiresAt,
  });

  String id;
  String restaurantId;
  String planId;
  SubscriptionStatus status;
  String? expiresAt;

  factory Subscription.fromJson(Map<String, Object?> j) => Subscription(
    id: _str(j['id']),
    restaurantId: _str(j['restaurant_id']),
    planId: _str(j['plan_id']),
    status: SubscriptionStatus.parse(j['status']),
    expiresAt: _strOrNull(j['expires_at']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'restaurant_id': restaurantId,
    'plan_id': planId,
    'status': status.wire,
    'expires_at': expiresAt,
  };

  Subscription copy() => Subscription.fromJson(toJson());
}

class Session {
  Session(this.profileId);

  String profileId;

  Map<String, Object?> toJson() => {'profile_id': profileId};
}

/// شكل المخزن كاملًا. كل مفتاح = جدول واحد، وهذا ما يجعل الانتقال إلى
/// Postgres مباشرًا: كل قائمة هنا تصير جدولًا بنفس الاسم والأعمدة.
class DB {
  DB({
    required this.version,
    required this.restaurants,
    required this.profiles,
    required this.categories,
    required this.dishes,
    required this.optionGroups,
    required this.options,
    required this.tables,
    required this.orders,
    required this.orderItems,
    required this.orderItemOptions,
    required this.plans,
    required this.subscriptions,
    required this.session,
    required this.orderSeq,
  });

  int version;
  List<Restaurant> restaurants;
  List<Profile> profiles;
  List<Category> categories;
  List<Dish> dishes;
  List<OptionGroup> optionGroups;
  List<DishOption> options;
  List<RestaurantTable> tables;
  List<Order> orders;
  List<OrderItem> orderItems;
  List<OrderItemOption> orderItemOptions;
  List<Plan> plans;
  List<Subscription> subscriptions;

  /// لا يقابل جدولًا — تحلّ محلّه جلسة الخادم حين تُربط قاعدة البيانات
  Session? session;

  /// عدّاد أرقام الطلبات لكل مطعم
  Map<String, int> orderSeq;

  factory DB.fromJson(Map<String, Object?> j) {
    final session = j['session'];
    final seq = j['order_seq'];
    return DB(
      version: _int(j['version'], 1),
      restaurants: _rows(j['restaurants']).map(Restaurant.fromJson).toList(),
      profiles: _rows(j['profiles']).map(Profile.fromJson).toList(),
      categories: _rows(j['categories']).map(Category.fromJson).toList(),
      dishes: _rows(j['dishes']).map(Dish.fromJson).toList(),
      optionGroups: _rows(j['option_groups']).map(OptionGroup.fromJson).toList(),
      options: _rows(j['options']).map(DishOption.fromJson).toList(),
      tables: _rows(j['tables']).map(RestaurantTable.fromJson).toList(),
      orders: _rows(j['orders']).map(Order.fromJson).toList(),
      orderItems: _rows(j['order_items']).map(OrderItem.fromJson).toList(),
      orderItemOptions: _rows(j['order_item_options']).map(OrderItemOption.fromJson).toList(),
      plans: _rows(j['plans']).map(Plan.fromJson).toList(),
      subscriptions: _rows(j['subscriptions']).map(Subscription.fromJson).toList(),
      session: session is Map && session['profile_id'] is String ? Session(session['profile_id'] as String) : null,
      orderSeq: seq is Map
          ? {
              for (final e in seq.entries)
                if (e.key is String && e.value is num) e.key as String: (e.value as num).toInt(),
            }
          : <String, int>{},
    );
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'restaurants': [for (final r in restaurants) r.toJson()],
    'profiles': [for (final p in profiles) p.toJson()],
    'categories': [for (final c in categories) c.toJson()],
    'dishes': [for (final d in dishes) d.toJson()],
    'option_groups': [for (final g in optionGroups) g.toJson()],
    'options': [for (final o in options) o.toJson()],
    'tables': [for (final t in tables) t.toJson()],
    'orders': [for (final o in orders) o.toJson()],
    'order_items': [for (final i in orderItems) i.toJson()],
    'order_item_options': [for (final o in orderItemOptions) o.toJson()],
    'plans': [for (final p in plans) p.toJson()],
    'subscriptions': [for (final s in subscriptions) s.toJson()],
    'session': session?.toJson(),
    'order_seq': {...orderSeq},
  };

  /// نسخة عميقة للتعديل عليها. النصوص (ومنها الصور) تُشارَك بالمرجع لأنها
  /// ثابتة في Dart، فالنسخ رخيص حتى مع الصور الكبيرة.
  DB copy() => DB.fromJson(toJson());
}

/* ===================== أنواع مركّبة (نتائج استعلامات، لا جداول) ===================== */

class CartSelection {
  const CartSelection({required this.groupId, required this.optionIds});

  final String groupId;
  final List<String> optionIds;

  factory CartSelection.fromJson(Map<String, Object?> j) => CartSelection(
    groupId: _str(j['group_id']),
    optionIds: j['option_ids'] is List
        ? [
            for (final id in j['option_ids'] as List)
              if (id is String) id,
          ]
        : const [],
  );

  Map<String, Object?> toJson() => {'group_id': groupId, 'option_ids': optionIds};
}

class CartLine {
  const CartLine({
    required this.key,
    required this.dishId,
    required this.qty,
    required this.note,
    required this.selections,
  });

  /// مفتاح السطر في السلة، لا يقابل عمودًا في قاعدة البيانات
  final String key;
  final String dishId;
  final int qty;
  final String note;
  final List<CartSelection> selections;

  CartLine withQty(int next) => CartLine(key: key, dishId: dishId, qty: next, note: note, selections: selections);

  factory CartLine.fromJson(Map<String, Object?> j) => CartLine(
    key: _str(j['key']),
    dishId: _str(j['dish_id']),
    qty: _int(j['qty'], 1),
    note: _str(j['note']),
    selections: _rows(j['selections']).map(CartSelection.fromJson).toList(),
  );

  Map<String, Object?> toJson() => {
    'key': key,
    'dish_id': dishId,
    'qty': qty,
    'note': note,
    'selections': [for (final s in selections) s.toJson()],
  };
}

class OptionName {
  const OptionName(this.name, this.priceDelta);

  final String name;
  final double priceDelta;
}

class PricedCartLine {
  const PricedCartLine({
    required this.line,
    required this.dish,
    required this.optionNames,
    required this.unitPrice,
    required this.lineTotal,
  });

  final CartLine line;
  final DishWithOptions dish;
  final List<OptionName> optionNames;
  final double unitPrice;
  final double lineTotal;

  String get key => line.key;
  int get qty => line.qty;
  String get note => line.note;
}

class GroupWithOptions {
  const GroupWithOptions(this.group, this.options);

  final OptionGroup group;
  final List<DishOption> options;

  String get id => group.id;
  String get name => group.name;
  OptionGroupType get type => group.type;
  bool get isRequired => group.isRequired;
  int get minSelect => group.minSelect;
  int get maxSelect => group.maxSelect;
}

class DishWithOptions {
  const DishWithOptions(this.dish, this.groups);

  final Dish dish;
  final List<GroupWithOptions> groups;

  String get id => dish.id;
  String get name => dish.name;
}

class OrderItemWithOptions {
  const OrderItemWithOptions(this.item, this.options);

  final OrderItem item;
  final List<OrderItemOption> options;
}

class OrderWithItems {
  const OrderWithItems(this.order, this.items);

  final Order order;
  final List<OrderItemWithOptions> items;

  String get id => order.id;
  OrderStatus get status => order.status;
}
