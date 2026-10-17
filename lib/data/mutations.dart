import 'dart:math';

import 'models.dart';
import 'queries.dart';
import 'store.dart';
import 'utils.dart';
import 'validation.dart';

/// دوال الكتابة — المقابل لـ src/lib/data/mutations.ts في الموقع.
/// كل واحدة تمثّل عملية واحدة على قاعدة البيانات، بنفس قواعد التحقق
/// ونفس رسائل الخطأ العربية.

class Result<T> {
  const Result._(this.ok, this.data, this.error);

  const Result.ok(T data) : this._(true, data, null);
  const Result.fail(String error) : this._(false, null, error);

  final bool ok;
  final T? data;
  final String? error;
}

Result<T> _fail<T>(String error) => Result<T>.fail(error);

T? _first<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

String _newToken() => uid('t').replaceAll('_', '');

class SignUpInput {
  const SignUpInput({
    required this.ownerName,
    required this.restaurantName,
    required this.phone,
    required this.password,
    required this.slug,
  });

  final String ownerName;
  final String restaurantName;
  final String phone;
  final String password;
  final String slug;
}

class CreateOrderInput {
  const CreateOrderInput({
    required this.restaurantId,
    required this.type,
    required this.tableId,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.note,
    required this.lines,
  });

  final String restaurantId;
  final OrderType type;
  final String? tableId;
  final String customerName;
  final String customerPhone;
  final String address;
  final String note;
  final List<CartLine> lines;
}

extension Mutations on DataStore {
  /* ===================== الحسابات والدخول ===================== */

  Result<String> signUp(SignUpInput input) {
    final phone = normalizePhone(input.phone);
    final name = input.ownerName.trim();
    final restaurantName = input.restaurantName.trim();
    final slug = slugify(input.slug.isNotEmpty ? input.slug : input.restaurantName);

    if (name.length < 2) return _fail('اكتب اسمك كاملًا');
    if (restaurantName.length < 2) return _fail('اكتب اسم المطعم');
    if (!isValidPhone(phone)) return _fail('رقم الجوال غير صحيح');
    if (input.password.length < 6) return _fail('كلمة المرور ٦ أحرف على الأقل');

    if (db.profiles.any((p) => p.phone == phone)) {
      return _fail('هذا الجوال مسجّل مسبقًا. سجّل الدخول بدلًا من إنشاء حساب.');
    }
    if (db.restaurants.any((r) => r.slug == slug)) {
      return _fail('رابط المطعم محجوز. اختر رابطًا آخر.');
    }

    final restaurantId = uid('rest');
    final profileId = uid('prof');
    final now = isoNow();

    mutate((db) {
      db.restaurants.add(
        Restaurant(
          id: restaurantId,
          slug: slug,
          name: restaurantName,
          description: '',
          ownerName: name,
          phone: phone,
          logoUrl: null,
          coverUrl: null,
          themeColor: '#a96a00',
          template: MenuTemplate.classic,
          currency: 'SAR',
          taxRate: 15,
          taxIncluded: false,
          workingHours: defaultWorkingHours(),
          dineInEnabled: true,
          pickupEnabled: true,
          deliveryEnabled: false,
          deliveryFee: 0,
          minOrder: 0,
          isActive: true,
          planId: 'plan_free',
          createdAt: now,
        ),
      );
      db.profiles.add(
        Profile(
          id: profileId,
          name: name,
          phone: phone,
          password: input.password,
          role: Role.owner,
          restaurantId: restaurantId,
          createdAt: now,
        ),
      );
      db.orderSeq[restaurantId] = 1000;
      db.subscriptions.add(
        Subscription(
          id: uid('sub'),
          restaurantId: restaurantId,
          planId: 'plan_free',
          status: SubscriptionStatus.active,
          expiresAt: null,
        ),
      );
      // قسم أول جاهز حتى لا تكون لوحة المنيو فارغة تمامًا
      db.categories.add(
        Category(id: uid('cat'), restaurantId: restaurantId, name: 'الأطباق الرئيسية', sortOrder: 0, isVisible: true),
      );
      db.session = Session(profileId);
    });

    return Result.ok(restaurantId);
  }

  Result<Role> signIn(String phoneInput, String password) {
    final phone = normalizePhone(phoneInput);
    final profile = _first(db.profiles, (p) => p.phone == phone);

    if (profile == null) return _fail('لا يوجد حساب بهذا الجوال');
    if (profile.password != password) return _fail('كلمة المرور غير صحيحة');

    if (profile.restaurantId != null) {
      final restaurant = _first(db.restaurants, (r) => r.id == profile.restaurantId);
      if (restaurant != null && !restaurant.isActive) {
        return _fail('حساب المطعم موقوف. تواصل مع إدارة المنصة.');
      }
    }

    mutate((draft) => draft.session = Session(profile.id));
    return Result.ok(profile.role);
  }

  void signOut() => mutate((db) => db.session = null);

  Result<void> changePassword(String profileId, String current, String next) {
    if (next.length < 6) return _fail('كلمة المرور الجديدة ٦ أحرف على الأقل');
    final profile = _first(db.profiles, (p) => p.id == profileId);
    if (profile == null) return _fail('الحساب غير موجود');
    if (profile.password != current) return _fail('كلمة المرور الحالية غير صحيحة');

    mutate((db) => _first(db.profiles, (p) => p.id == profileId)?.password = next);
    return const Result.ok(null);
  }

  /* ===================== إعدادات المطعم ===================== */

  /// patch يُطبَّق على نسخة أولًا للتحقق، ثم على البيانات. الرابط يُنظَّف
  /// دائمًا ويُفحص تفرّده بين المطاعم الأخرى.
  Result<void> updateRestaurant(String id, void Function(Restaurant r) patch) {
    final current = _first(db.restaurants, (r) => r.id == id);
    if (current == null) return _fail('المطعم غير موجود');
    final next = current.copy();
    patch(next);
    final slug = slugify(next.slug);
    if (slug != current.slug && db.restaurants.any((r) => r.slug == slug && r.id != id)) {
      return _fail('رابط المطعم محجوز');
    }
    mutate((db) {
      final restaurant = _first(db.restaurants, (r) => r.id == id);
      if (restaurant == null) return;
      patch(restaurant);
      restaurant.slug = slug;
    });
    return const Result.ok(null);
  }

  /* ===================== الأقسام ===================== */

  Result<String> addCategory(String restaurantId, String name) {
    final trimmed = name.trim();
    if (trimmed.length < 2) return _fail('اكتب اسم القسم');
    final id = uid('cat');
    mutate((db) {
      final top = db.categories.where((c) => c.restaurantId == restaurantId).fold(-1, (m, c) => max(m, c.sortOrder));
      db.categories.add(
        Category(id: id, restaurantId: restaurantId, name: trimmed, sortOrder: top + 1, isVisible: true),
      );
    });
    return Result.ok(id);
  }

  void updateCategory(String id, void Function(Category c) patch) {
    mutate((db) {
      final category = _first(db.categories, (c) => c.id == id);
      if (category != null) patch(category);
    });
  }

  /// حذف قسم يحذف أطباقه وخياراتها. الطلبات القديمة لا تتأثر (نسخها مجمّدة).
  void deleteCategory(String id) {
    mutate((db) {
      final dishIds = {
        for (final d in db.dishes)
          if (d.categoryId == id) d.id,
      };
      final groupIds = {
        for (final g in db.optionGroups)
          if (dishIds.contains(g.dishId)) g.id,
      };
      db.options.removeWhere((o) => groupIds.contains(o.groupId));
      db.optionGroups.removeWhere((g) => groupIds.contains(g.id));
      db.dishes.removeWhere((d) => d.categoryId == id);
      db.categories.removeWhere((c) => c.id == id);
    });
  }

  void reorderCategories(String restaurantId, List<String> orderedIds) {
    mutate((db) {
      for (final (index, categoryId) in orderedIds.indexed) {
        final category = _first(db.categories, (c) => c.id == categoryId && c.restaurantId == restaurantId);
        if (category != null) category.sortOrder = index;
      }
    });
  }

  /* ===================== الأطباق ===================== */

  Result<String> addDish(
    String restaurantId, {
    required String categoryId,
    required String name,
    required double? price,
    String description = '',
    double? compareAtPrice,
    String? imageUrl,
    bool isAvailable = true,
    bool isFeatured = false,
    bool allowNote = false,
  }) {
    if (!isText(name, 2)) return _fail('اكتب اسم الطبق');
    if (!isMoney(price)) return _fail('اكتب سعرًا صحيحًا');
    if (compareAtPrice != null) {
      if (!isMoney(compareAtPrice)) return _fail('السعر قبل الخفض غير صحيح');
      if (compareAtPrice <= price!) {
        return _fail('السعر قبل الخفض يجب أن يكون أعلى من السعر الحالي');
      }
    }
    final id = uid('dish');
    mutate((db) {
      final top = db.dishes.where((d) => d.categoryId == categoryId).fold(-1, (m, d) => max(m, d.sortOrder));
      db.dishes.add(
        Dish(
          id: id,
          restaurantId: restaurantId,
          categoryId: categoryId,
          name: name.trim(),
          description: description.trim(),
          price: round2(price!),
          compareAtPrice: compareAtPrice,
          imageUrl: imageUrl,
          isAvailable: isAvailable,
          isFeatured: isFeatured,
          allowNote: allowNote,
          sortOrder: top + 1,
        ),
      );
    });
    return Result.ok(id);
  }

  /// التحقق يجري على الحالة **بعد** الدمج، لا على ما وصل في patch وحده:
  /// «السعر قبل الخفض» يُقارن بالسعر النهائي أيًّا كان الحقل الذي تغيّر.
  Result<void> updateDish(String id, void Function(Dish d) patch) {
    final current = _first(db.dishes, (d) => d.id == id);
    if (current == null) return _fail('الطبق غير موجود');
    final next = current.copy();
    patch(next);

    if (!isText(next.name, 2)) return _fail('اكتب اسم الطبق');
    if (!isMoney(next.price)) return _fail('اكتب سعرًا صحيحًا');
    final compare = next.compareAtPrice;
    if (compare != null) {
      if (!isMoney(compare)) return _fail('السعر قبل الخفض غير صحيح');
      if (compare <= next.price) return _fail('السعر قبل الخفض يجب أن يكون أعلى من السعر الحالي');
    }

    mutate((db) {
      final dish = _first(db.dishes, (d) => d.id == id);
      if (dish != null) patch(dish);
    });
    return const Result.ok(null);
  }

  void deleteDish(String id) {
    mutate((db) {
      final groupIds = {
        for (final g in db.optionGroups)
          if (g.dishId == id) g.id,
      };
      db.options.removeWhere((o) => groupIds.contains(o.groupId));
      db.optionGroups.removeWhere((g) => g.dishId == id);
      db.dishes.removeWhere((d) => d.id == id);
    });
  }

  void toggleDishAvailable(String id) {
    mutate((db) {
      final dish = _first(db.dishes, (d) => d.id == id);
      if (dish != null) dish.isAvailable = !dish.isAvailable;
    });
  }

  void reorderDishes(String categoryId, List<String> orderedIds) {
    mutate((db) {
      for (final (index, dishId) in orderedIds.indexed) {
        final dish = _first(db.dishes, (d) => d.id == dishId && d.categoryId == categoryId);
        if (dish != null) dish.sortOrder = index;
      }
    });
  }

  void moveDishToCategory(String dishId, String categoryId) {
    mutate((db) {
      final dish = _first(db.dishes, (d) => d.id == dishId);
      if (dish == null) return;
      final top = db.dishes.where((d) => d.categoryId == categoryId).fold(-1, (m, d) => max(m, d.sortOrder));
      dish.categoryId = categoryId;
      dish.sortOrder = top + 1;
    });
  }

  /* ===================== الخيارات والإضافات ===================== */

  Result<String> addOptionGroup(
    String dishId, {
    required String name,
    OptionGroupType type = OptionGroupType.single,
    bool isRequired = false,
    int minSelect = 0,
    int? maxSelect,
  }) {
    if (name.trim().length < 2) return _fail('اكتب اسم المجموعة');
    final id = uid('grp');
    mutate((db) {
      final top = db.optionGroups.where((g) => g.dishId == dishId).fold(-1, (m, g) => max(m, g.sortOrder));
      db.optionGroups.add(
        OptionGroup(
          id: id,
          dishId: dishId,
          name: name.trim(),
          type: type,
          isRequired: isRequired,
          minSelect: minSelect,
          maxSelect: maxSelect ?? (type == OptionGroupType.multi ? 0 : 1),
          sortOrder: top + 1,
        ),
      );
    });
    return Result.ok(id);
  }

  void updateOptionGroup(String id, void Function(OptionGroup g) patch) {
    mutate((db) {
      final group = _first(db.optionGroups, (g) => g.id == id);
      if (group == null) return;
      patch(group);
      // مجموعة الاختيار الواحد لا تقبل أكثر من اختيار
      if (group.type == OptionGroupType.single) {
        group.maxSelect = 1;
        group.minSelect = group.isRequired ? 1 : 0;
      } else {
        // حدود متناقضة (min > max، أو قيم سالبة) تجعل المجموعة غير قابلة للإرضاء
        group.minSelect = max(0, group.minSelect);
        group.maxSelect = max(0, group.maxSelect);
        if (group.isRequired) group.minSelect = max(1, group.minSelect);
        if (group.maxSelect > 0 && group.minSelect > group.maxSelect) {
          group.minSelect = group.maxSelect;
        }
      }
    });
  }

  void deleteOptionGroup(String id) {
    mutate((db) {
      db.options.removeWhere((o) => o.groupId == id);
      db.optionGroups.removeWhere((g) => g.id == id);
    });
  }

  Result<String> addOption(String groupId, {required String name, required double? priceDelta}) {
    if (!isText(name, 1)) return _fail('اكتب اسم الخيار');
    if (!isDelta(priceDelta)) return _fail('اكتب فرق سعر صحيحًا');
    final id = uid('opt');
    mutate((db) {
      final group = _first(db.optionGroups, (g) => g.id == groupId);
      final siblings = db.options.where((o) => o.groupId == groupId).toList();
      final top = siblings.fold(-1, (m, o) => max(m, o.sortOrder));
      db.options.add(
        DishOption(
          id: id,
          groupId: groupId,
          name: name.trim(),
          priceDelta: round2(priceDelta!),
          // أول خيار في مجموعة اختيار واحد يصير المبدئي تلقائيًا
          isDefault: group?.type == OptionGroupType.single && siblings.isEmpty,
          sortOrder: top + 1,
        ),
      );
    });
    return Result.ok(id);
  }

  void updateOption(String id, void Function(DishOption o) patch) {
    mutate((db) {
      final option = _first(db.options, (o) => o.id == id);
      if (option == null) return;
      patch(option);
      // خيار مبدئي واحد فقط في مجموعة الاختيار الواحد
      if (option.isDefault) {
        final group = _first(db.optionGroups, (g) => g.id == option.groupId);
        if (group?.type == OptionGroupType.single) {
          for (final other in db.options) {
            if (other.groupId == option.groupId && other.id != option.id) other.isDefault = false;
          }
        }
      }
    });
  }

  void deleteOption(String id) => mutate((db) => db.options.removeWhere((o) => o.id == id));

  /* ===================== الطاولات ===================== */

  Result<String> addTable(String restaurantId, String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return _fail('اكتب اسم الطاولة');
    final id = uid('tbl');
    mutate((db) {
      db.tables.add(RestaurantTable(id: id, restaurantId: restaurantId, label: trimmed, qrToken: _newToken()));
    });
    return Result.ok(id);
  }

  /// يضيف عددًا من الطاولات مرقّمة بعد آخر رقم موجود
  void addTablesBulk(String restaurantId, int count) {
    mutate((db) {
      var highest = 0;
      for (final table in db.tables.where((t) => t.restaurantId == restaurantId)) {
        final match = RegExp(r'\d+').firstMatch(table.label);
        if (match != null) highest = max(highest, int.parse(match.group(0)!));
      }
      for (var i = 1; i <= count; i++) {
        db.tables.add(
          RestaurantTable(
            id: uid('tbl'),
            restaurantId: restaurantId,
            label: 'طاولة ${highest + i}',
            qrToken: _newToken(),
          ),
        );
      }
    });
  }

  void updateTable(String id, void Function(RestaurantTable t) patch) {
    mutate((db) {
      final table = _first(db.tables, (t) => t.id == id);
      if (table != null) patch(table);
    });
  }

  void deleteTable(String id) => mutate((db) => db.tables.removeWhere((t) => t.id == id));

  /// يولّد رمزًا جديدًا فيُبطل رمز QR القديم للطاولة
  void regenerateTableToken(String id) {
    mutate((db) => _first(db.tables, (t) => t.id == id)?.qrToken = _newToken());
  }

  /* ===================== الطلبات ===================== */

  Result<({String orderId, int number})> createOrder(CreateOrderInput input) {
    final restaurant = _first(db.restaurants, (r) => r.id == input.restaurantId);
    if (restaurant == null) return _fail('المطعم غير موجود');
    if (!restaurant.isActive) return _fail('المطعم غير متاح حاليًا');

    if (input.lines.isEmpty) return _fail('السلة فارغة');

    // التحقق قبل التسعير، لا بعده: السطر الذي لا يمرّ لا يُسقَط بصمت بل
    // يُرفض الطلب كله. القواعد التي تفرضها الواجهة تُفرض هنا مرة أخرى.
    final audit = auditCart(db, input.lines);
    if (audit.rejected.isNotEmpty) {
      final first = audit.rejected.first;
      final detail = firstMessage(first.issues, 'سطر غير صالح في السلة');
      return _fail(first.dishName != null ? '«${first.dishName}»: $detail' : detail);
    }

    final priced = audit.lines;
    if (priced.isEmpty) return _fail('السلة فارغة');

    final unavailable = _first(priced, (line) => !line.dish.dish.isAvailable);
    if (unavailable != null) {
      return _fail('«${unavailable.dish.name}» نفد الآن. احذفه من السلة لإكمال الطلب.');
    }

    if (input.type == OrderType.dineIn) {
      if (!restaurant.dineInEnabled) return _fail('الطلب من الطاولة غير مفعّل');
      if (input.tableId == null) return _fail('رقم الطاولة مفقود. أعد مسح رمز الطاولة.');
    }
    if (input.type == OrderType.pickup && !restaurant.pickupEnabled) return _fail('الاستلام غير مفعّل');
    if (input.type == OrderType.delivery && !restaurant.deliveryEnabled) {
      return _fail('التوصيل غير مفعّل');
    }

    if (input.type != OrderType.dineIn) {
      if (input.customerName.trim().length < 2) return _fail('اكتب اسمك');
      if (!isValidPhone(input.customerPhone)) return _fail('اكتب رقم جوال صحيح');
    }
    if (input.type == OrderType.delivery && input.address.trim().length < 8) {
      return _fail('اكتب العنوان بتفصيل أكثر');
    }

    final subtotal = round2(priced.fold(0.0, (s, line) => s + line.lineTotal));
    if (restaurant.minOrder > 0 && subtotal < restaurant.minOrder) {
      return _fail('الحد الأدنى للطلب ${formatNumber(restaurant.minOrder)} — أضف المزيد لإكمال الطلب.');
    }

    final deliveryFee = input.type == OrderType.delivery ? restaurant.deliveryFee : 0.0;
    final bill = computeBill(
      subtotal: subtotal,
      taxRate: restaurant.taxRate,
      taxIncluded: restaurant.taxIncluded,
      deliveryFee: deliveryFee,
    );

    final orderId = uid('ord');
    var orderNumber = 0;
    final now = isoNow();

    mutate((draft) {
      final next = (draft.orderSeq[input.restaurantId] ?? 1000) + 1;
      draft.orderSeq[input.restaurantId] = next;
      orderNumber = next;

      final table = input.tableId == null ? null : _first(draft.tables, (t) => t.id == input.tableId);

      draft.orders.add(
        Order(
          id: orderId,
          restaurantId: input.restaurantId,
          orderNumber: next,
          type: input.type,
          tableId: input.tableId,
          tableLabel: table?.label,
          customerName: input.customerName.trim().isNotEmpty
              ? input.customerName.trim()
              : (input.type == OrderType.dineIn ? 'زبون الطاولة' : ''),
          customerPhone: normalizePhone(input.customerPhone),
          address: input.address.trim(),
          note: input.note.trim(),
          status: OrderStatus.newOrder,
          subtotal: bill.subtotal,
          taxAmount: bill.taxAmount,
          deliveryFee: bill.deliveryFee,
          total: bill.total,
          currency: restaurant.currency,
          paymentMethod: PaymentMethod.cash,
          paymentStatus: PaymentStatus.unpaid,
          createdAt: now,
          updatedAt: now,
        ),
      );

      for (final (index, line) in priced.indexed) {
        final itemId = '${orderId}_it_${index + 1}';
        draft.orderItems.add(
          OrderItem(
            id: itemId,
            orderId: orderId,
            dishId: line.dish.id,
            dishName: line.dish.name,
            unitPrice: line.unitPrice,
            qty: line.qty,
            note: line.note,
            lineTotal: line.lineTotal,
          ),
        );
        for (final (oi, option) in line.optionNames.indexed) {
          draft.orderItemOptions.add(
            OrderItemOption(
              id: '${itemId}_op_${oi + 1}',
              orderItemId: itemId,
              optionName: option.name,
              priceDelta: option.priceDelta,
            ),
          );
        }
      }
    });

    return Result.ok((orderId: orderId, number: orderNumber));
  }

  void setOrderStatus(String orderId, OrderStatus status) {
    mutate((db) {
      final order = _first(db.orders, (o) => o.id == orderId);
      if (order == null) return;
      order.status = status;
      order.updatedAt = isoNow();
      if (status == OrderStatus.completed) order.paymentStatus = PaymentStatus.paid;
    });
  }

  /// حذف طلب نهائيًا مع بنوده وخياراتها. عدّاد الأرقام لا يتراجع: رقم الطلب
  /// المحذوف لا يُعطى لطلب جديد، فلا يلتبس إيصال قديم بطلب آخر.
  void deleteOrder(String orderId) {
    mutate((db) {
      final itemIds = {
        for (final i in db.orderItems)
          if (i.orderId == orderId) i.id,
      };
      db.orderItemOptions.removeWhere((o) => itemIds.contains(o.orderItemId));
      db.orderItems.removeWhere((i) => i.orderId == orderId);
      db.orders.removeWhere((o) => o.id == orderId);
    });
  }

  /* ===================== الموظفون ===================== */

  Result<String> addStaff(
    String restaurantId, {
    required String name,
    required String phone,
    required String password,
  }) {
    final normalized = normalizePhone(phone);
    if (name.trim().length < 2) return _fail('اكتب اسم الموظف');
    if (!isValidPhone(normalized)) return _fail('رقم الجوال غير صحيح');
    if (password.length < 6) return _fail('كلمة المرور ٦ أحرف على الأقل');
    if (db.profiles.any((p) => p.phone == normalized)) return _fail('هذا الجوال مستخدم مسبقًا');

    final id = uid('prof');
    mutate((db) {
      db.profiles.add(
        Profile(
          id: id,
          name: name.trim(),
          phone: normalized,
          password: password,
          role: Role.staff,
          restaurantId: restaurantId,
          createdAt: isoNow(),
        ),
      );
    });
    return Result.ok(id);
  }

  Result<void> updateStaff(String id, {String? name, String? phone}) {
    String? normalized;
    if (phone != null) {
      normalized = normalizePhone(phone);
      if (!isValidPhone(normalized)) return _fail('رقم الجوال غير صحيح');
      if (db.profiles.any((p) => p.phone == normalized && p.id != id)) {
        return _fail('هذا الجوال مستخدم مسبقًا');
      }
    }
    if (name != null && name.trim().length < 2) return _fail('اكتب اسم الموظف');
    mutate((db) {
      final profile = _first(db.profiles, (p) => p.id == id);
      if (profile == null) return;
      if (name != null) profile.name = name.trim();
      if (normalized != null) profile.phone = normalized;
    });
    return const Result.ok(null);
  }

  void deleteStaff(String id) {
    mutate((db) {
      db.profiles.removeWhere((p) => p.id == id);
      if (db.session?.profileId == id) db.session = null;
    });
  }

  /* ===================== لوحة المشرف العام ===================== */

  void setRestaurantActive(String restaurantId, bool active) {
    mutate((db) => _first(db.restaurants, (r) => r.id == restaurantId)?.isActive = active);
  }

  /// إعادة تعيين كلمة مرور — قناة الاستعادة الوحيدة في هذه المرحلة
  Result<void> resetProfilePassword(String profileId, String password) {
    if (password.length < 6) return _fail('كلمة المرور ٦ أحرف على الأقل');
    mutate((db) => _first(db.profiles, (p) => p.id == profileId)?.password = password);
    return const Result.ok(null);
  }

  void setPlanActive(String planId, bool active) {
    mutate((db) => _first(db.plans, (p) => p.id == planId)?.isActive = active);
  }

  void updatePlan(String planId, {double? price, String? name}) {
    mutate((db) {
      final plan = _first(db.plans, (p) => p.id == planId);
      if (plan == null) return;
      if (price != null) plan.price = price;
      if (name != null) plan.name = name;
    });
  }
}
