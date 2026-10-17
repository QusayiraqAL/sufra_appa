import 'dart:math';

import 'models.dart';
import 'utils.dart';
import 'validation.dart';

/// دوال القراءة. كلها نقية: تأخذ لقطة البيانات وتُعيد نتيجة، بلا آثار جانبية.
/// مطابقة لـ src/lib/data/queries.ts — حين تُربط قاعدة البيانات يصير كل
/// واحدة منها استعلامًا بنفس التوقيع.

T? _find<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

/* ===================== المطاعم والحسابات ===================== */

Restaurant? getRestaurantBySlug(DB db, String slug) => _find(db.restaurants, (r) => r.slug == slug);

Restaurant? getRestaurantById(DB db, String? id) => id == null ? null : _find(db.restaurants, (r) => r.id == id);

Profile? getProfileById(DB db, String id) => _find(db.profiles, (p) => p.id == id);

Profile? getProfileByPhone(DB db, String phone) => _find(db.profiles, (p) => p.phone == phone);

Profile? getSessionProfile(DB db) {
  final session = db.session;
  if (session == null) return null;
  return getProfileById(db, session.profileId);
}

Restaurant? getSessionRestaurant(DB db) {
  final profile = getSessionProfile(db);
  if (profile == null) return null;
  return getRestaurantById(db, profile.restaurantId);
}

List<Profile> getStaff(DB db, String restaurantId) =>
    db.profiles.where((p) => p.restaurantId == restaurantId && p.role == Role.staff).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

Profile? getOwner(DB db, String restaurantId) =>
    _find(db.profiles, (p) => p.restaurantId == restaurantId && p.role == Role.owner);

Plan? getPlan(DB db, String id) => _find(db.plans, (p) => p.id == id);

/* ===================== المنيو ===================== */

List<Category> getCategories(DB db, String restaurantId) =>
    db.categories.where((c) => c.restaurantId == restaurantId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

List<Dish> getDishes(DB db, String restaurantId) =>
    db.dishes.where((d) => d.restaurantId == restaurantId).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

List<Dish> getDishesInCategory(DB db, String categoryId) =>
    db.dishes.where((d) => d.categoryId == categoryId).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

Dish? getDish(DB db, String dishId) => _find(db.dishes, (d) => d.id == dishId);

List<OptionGroup> getOptionGroups(DB db, String dishId) =>
    db.optionGroups.where((g) => g.dishId == dishId).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

List<DishOption> getOptions(DB db, String groupId) =>
    db.options.where((o) => o.groupId == groupId).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

DishWithOptions? getDishWithOptions(DB db, String dishId) {
  final dish = getDish(db, dishId);
  if (dish == null) return null;
  return DishWithOptions(dish, [
    for (final g in getOptionGroups(db, dishId)) GroupWithOptions(g, getOptions(db, g.id)),
  ]);
}

class MenuSection {
  const MenuSection(this.category, this.dishes);

  final Category category;
  final List<Dish> dishes;
}

/// منيو المطعم مجمّعًا بالأقسام.
/// visibleOnly = منظور العميل: يُخفي الأقسام المطفأة والأقسام الفارغة،
/// لكنه يُبقي الأطباق النافدة ظاهرةً معلَّمةً (لا يخفيها) لأن إخفاءها
/// يجعل العميل يسأل عن طبق غائب بلا تفسير.
List<MenuSection> getMenu(DB db, String restaurantId, {bool visibleOnly = false}) => [
  for (final category in getCategories(db, restaurantId))
    if (!visibleOnly || category.isVisible)
      if (MenuSection(category, getDishesInCategory(db, category.id)) case final section
          when !visibleOnly || section.dishes.isNotEmpty)
        section,
];

int countDishes(DB db, String restaurantId) => db.dishes.where((d) => d.restaurantId == restaurantId).length;

List<Dish> getUnavailableDishes(DB db, String restaurantId) =>
    db.dishes.where((d) => d.restaurantId == restaurantId && !d.isAvailable).toList();

/* ===================== الطاولات ===================== */

List<RestaurantTable> getTables(DB db, String restaurantId) =>
    db.tables.where((t) => t.restaurantId == restaurantId).toList()..sort((a, b) => naturalCompare(a.label, b.label));

RestaurantTable? getTableByToken(DB db, String restaurantId, String token) =>
    _find(db.tables, (t) => t.restaurantId == restaurantId && t.qrToken == token);

/* ===================== الطلبات ===================== */

OrderWithItems? getOrderWithItems(DB db, String orderId) {
  final order = _find(db.orders, (o) => o.id == orderId);
  if (order == null) return null;
  final items = [
    for (final item in db.orderItems)
      if (item.orderId == order.id)
        OrderItemWithOptions(item, [
          for (final o in db.orderItemOptions)
            if (o.orderItemId == item.id) o,
        ]),
  ];
  return OrderWithItems(order, items);
}

List<Order> getOrders(DB db, String restaurantId) =>
    db.orders.where((o) => o.restaurantId == restaurantId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

List<OrderWithItems> getOrdersWithItems(DB db, String restaurantId) {
  // فهرسة البنود والخيارات مرة واحدة بدل مسح الجداول لكل طلب
  final optionsByItem = <String, List<OrderItemOption>>{};
  for (final o in db.orderItemOptions) {
    (optionsByItem[o.orderItemId] ??= []).add(o);
  }
  final itemsByOrder = <String, List<OrderItemWithOptions>>{};
  for (final item in db.orderItems) {
    (itemsByOrder[item.orderId] ??= []).add(OrderItemWithOptions(item, optionsByItem[item.id] ?? const []));
  }
  return [for (final order in getOrders(db, restaurantId)) OrderWithItems(order, itemsByOrder[order.id] ?? const [])];
}

List<OrderWithItems> getOrdersByStatus(DB db, String restaurantId, OrderStatus status) =>
    getOrdersWithItems(db, restaurantId).where((o) => o.status == status).toList();

int countOrdersByStatus(DB db, String restaurantId, OrderStatus status) =>
    db.orders.where((o) => o.restaurantId == restaurantId && o.status == status).length;

bool _isOpenStatus(OrderStatus s) => s == OrderStatus.newOrder || s == OrderStatus.preparing || s == OrderStatus.ready;

/// الطلبات المفتوحة لطاولة معيّنة — لكشف الطلبات المكرّرة من نفس الـ QR
List<Order> getOpenOrdersForTable(DB db, String tableId) =>
    db.orders.where((o) => o.tableId == tableId && _isOpenStatus(o.status)).toList();

/* ===================== تسعير السلة والتحقق منها ===================== */

sealed class LineCheck {
  const LineCheck();
}

class LineOk extends LineCheck {
  const LineOk(this.data);

  final PricedCartLine data;
}

class LineRejected extends LineCheck {
  const LineRejected(this.issues);

  final List<Issue> issues;
}

/// يتحقق من سطر السلة ويسعّره.
///
/// السلة تخزّن المعرّفات فقط، والسعر يُحسب عند العرض — فلو غيّر المطعم
/// السعر والسلة مفتوحة، يرى العميل السعر الصحيح لا القديم.
LineCheck validateCartLine(DB db, CartLine line) {
  final dish = getDishWithOptions(db, line.dishId);
  if (dish == null) {
    return const LineRejected([Issue(IssueCode.dishMissing, 'لم يعد هذا الطبق متاحًا في المنيو')]);
  }

  final issues = checkSelections(dish, line.selections);
  if (!isQty(line.qty)) {
    issues.add(const Issue(IssueCode.qtyInvalid, 'الكمية يجب أن تكون رقمًا صحيحًا بين 1 و$maxLineQty'));
  }
  if (issues.isNotEmpty) return LineRejected(issues);

  final (:optionNames, :unitPrice) = priceSelections(dish, line.selections);
  return LineOk(
    PricedCartLine(
      line: line,
      dish: dish,
      optionNames: optionNames,
      unitPrice: unitPrice,
      lineTotal: round2(unitPrice * line.qty),
    ),
  );
}

class RejectedCartLine {
  const RejectedCartLine({required this.key, required this.dishName, required this.issues});

  final String key;

  /// اسم الطبق إن كان لا يزال موجودًا — وإلا null
  final String? dishName;
  final List<Issue> issues;
}

class CartAudit {
  const CartAudit(this.lines, this.rejected);

  final List<PricedCartLine> lines;
  final List<RejectedCartLine> rejected;
}

/// يفحص السلة كاملة ويفصل الصالح عن المرفوض.
///
/// الفصل — لا الترشيح الصامت — مقصود: السلة تعيش على الجهاز وقد تتقادم،
/// فيُحذف طبق أو تُعدَّل مجموعة خياراته. الترشيح الصامت كان يجعل العميل
/// يفتح سلته فيجد صنفًا اختفى بلا تفسير.
CartAudit auditCart(DB db, List<CartLine> lines) {
  final priced = <PricedCartLine>[];
  final rejected = <RejectedCartLine>[];
  for (final line in lines) {
    switch (validateCartLine(db, line)) {
      case LineOk(:final data):
        priced.add(data);
      case LineRejected(:final issues):
        rejected.add(RejectedCartLine(key: line.key, dishName: getDish(db, line.dishId)?.name, issues: issues));
    }
  }
  return CartAudit(priced, rejected);
}

/// الأسطر الصالحة فقط — للعرض السريع حين لا يهمّ المرفوض
List<PricedCartLine> priceCart(DB db, List<CartLine> lines) => auditCart(db, lines).lines;

/* ===================== التقارير ===================== */

class DayPoint {
  const DayPoint({required this.label, required this.date, required this.revenue, required this.orders});

  final String label;
  final DateTime date;
  final double revenue;
  final int orders;
}

class TypeStat {
  TypeStat();

  int orders = 0;
  double revenue = 0;
}

class TopDish {
  TopDish(this.name);

  final String name;
  int qty = 0;
  double revenue = 0;
}

class ReportStats {
  const ReportStats({
    required this.orders,
    required this.revenue,
    required this.avgOrder,
    required this.cancelled,
    required this.byType,
    required this.topDishes,
    required this.daily,
    required this.busiestHour,
  });

  final int orders;
  final double revenue;
  final double avgOrder;
  final int cancelled;
  final Map<OrderType, TypeStat> byType;
  final List<TopDish> topDishes;
  final List<DayPoint> daily;
  final int? busiestHour;
}

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// الطلبات الملغاة لا تُحسب في الإيراد، لكن يُعرض عددها منفصلًا.
ReportStats reportStats(DB db, String restaurantId, int days) {
  final today = _startOfDay(DateTime.now());
  final since = DateTime(today.year, today.month, today.day - (days - 1));

  final all = getOrders(db, restaurantId).where((o) => !parseIso(o.createdAt).isBefore(since)).toList();
  final counted = all.where((o) => o.status != OrderStatus.cancelled).toList();

  final revenue = round2(counted.fold(0.0, (s, o) => s + o.total));
  final byType = {for (final t in OrderType.values) t: TypeStat()};
  for (final order in counted) {
    final stat = byType[order.type]!;
    stat.orders += 1;
    stat.revenue = round2(stat.revenue + order.total);
  }

  final tally = <String, TopDish>{};
  final countedIds = {for (final o in counted) o.id};
  for (final item in db.orderItems) {
    if (!countedIds.contains(item.orderId)) continue;
    final entry = tally[item.dishName] ??= TopDish(item.dishName);
    entry.qty += item.qty;
    entry.revenue = round2(entry.revenue + item.lineTotal);
  }
  // الترتيب الثابت: يحفظ ترتيب الظهور عند التعادل كما في Array.sort بالموقع
  final entries = tally.values.toList();
  final indexed = [for (var i = 0; i < entries.length; i++) (i, entries[i])]
    ..sort((a, b) {
      final c = b.$2.qty.compareTo(a.$2.qty);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  final topDishes = [for (final e in indexed.take(8)) e.$2];

  final daily = <DayPoint>[];
  for (var i = days - 1; i >= 0; i--) {
    final day = DateTime(today.year, today.month, today.day - i);
    final dayOrders = counted.where((o) => isSameDay(o.createdAt, day)).toList();
    daily.add(
      DayPoint(
        label: '${day.day}/${day.month}',
        date: day,
        revenue: round2(dayOrders.fold(0.0, (s, o) => s + o.total)),
        orders: dayOrders.length,
      ),
    );
  }

  final hourTally = List.filled(24, 0);
  for (final order in counted) {
    hourTally[parseIso(order.createdAt).hour] += 1;
  }
  final peak = hourTally.reduce(max);
  final busiestHour = peak > 0 ? hourTally.indexOf(peak) : null;

  return ReportStats(
    orders: counted.length,
    revenue: revenue,
    avgOrder: counted.isEmpty ? 0 : round2(revenue / counted.length),
    cancelled: all.length - counted.length,
    byType: byType,
    topDishes: topDishes,
    daily: daily,
    busiestHour: busiestHour,
  );
}

class TodayStats {
  const TodayStats({required this.orders, required this.revenue, required this.open, required this.ready});

  final int orders;
  final double revenue;
  final int open;
  final int ready;
}

/// أرقام لوحة النظرة العامة — اليوم فقط
TodayStats todayStats(DB db, String restaurantId) {
  final orders = getOrders(db, restaurantId).where((o) => isSameDay(o.createdAt)).toList();
  final counted = orders.where((o) => o.status != OrderStatus.cancelled).toList();
  return TodayStats(
    orders: counted.length,
    revenue: round2(counted.fold(0.0, (s, o) => s + o.total)),
    open: orders.where((o) => o.status == OrderStatus.newOrder || o.status == OrderStatus.preparing).length,
    ready: orders.where((o) => o.status == OrderStatus.ready).length,
  );
}

/* ===================== إحصاءات المنصة (لوحة المشرف) ===================== */

class PlatformStats {
  const PlatformStats({
    required this.restaurants,
    required this.activeRestaurants,
    required this.suspended,
    required this.dishes,
    required this.orders,
    required this.ordersToday,
    required this.owners,
  });

  final int restaurants;
  final int activeRestaurants;
  final int suspended;
  final int dishes;
  final int orders;
  final int ordersToday;
  final int owners;
}

PlatformStats platformStats(DB db) {
  final active = db.restaurants.where((r) => r.isActive).length;
  return PlatformStats(
    restaurants: db.restaurants.length,
    activeRestaurants: active,
    suspended: db.restaurants.length - active,
    dishes: db.dishes.length,
    orders: db.orders.length,
    ordersToday: db.orders.where((o) => isSameDay(o.createdAt)).length,
    owners: db.profiles.where((p) => p.role == Role.owner).length,
  );
}
