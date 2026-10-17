// «إزالة الحركة» من إعدادات الجهاز: لا نبض يدور ولا إطارات تُرسم بلا داعٍ،
// ولا خطأ عند إغلاق شاشة متابعة الطلب.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sufra/app.dart';
import 'package:sufra/core/feedback.dart';
import 'package:sufra/data/cart.dart';
import 'package:sufra/data/models.dart';
import 'package:sufra/data/mutations.dart';
import 'package:sufra/data/seed.dart';
import 'package:sufra/data/store.dart';
import 'package:sufra/state/prefs.dart';
import 'package:sufra/ui/storefront/order_status_screen.dart';
import 'package:sufra/ui/storefront/storefront_menu.dart';

void main() {
  testWidgets('مع «إزالة الحركة» تسكن الواجهة وتُغلق متابعة الطلب بلا خطأ', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final prefs = AppPrefs(sp)..chimeEnabled = false;
    // المطعم مفتوح طوال اليوم: نقطة «مفتوح الآن» تنبض في الوضع العادي
    final db = createSeedDB();
    for (final r in db.restaurants) {
      for (final h in r.workingHours) {
        h
          ..closed = false
          ..open = '00:00'
          ..close = '23:59';
      }
    }
    final store = DataStore.memory(db);

    await tester.pumpWidget(SufraApp(store: store, prefs: prefs, carts: CartRegistry(sp)));
    store.signIn('0551234567', '123456');
    // الرئيسية فيها نقاط نابضة (المطعم مفتوح، طلبات حيّة): لو دارت لما استقرّ الإطار أبدًا
    await tester.pumpAndSettle();
    expect(find.text('ماذا تريد أن تستخدم الآن؟'), findsOneWidget);

    // طلب قيد التجهيز: خطوته الحالية تنبض في الوضع العادي
    final order = db.orders.firstWhere((o) => o.status == OrderStatus.preparing);
    final slug = db.restaurants.firstWhere((r) => r.id == order.restaurantId).slug;
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => OrderStatusScreen(slug: slug, orderId: order.id, mode: StorefrontMode.guest),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('المطبخ يجهّز طلبك'), findsOneWidget);

    // الإغلاق لا يُنشئ مؤقّت الحركة داخل dispose
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
