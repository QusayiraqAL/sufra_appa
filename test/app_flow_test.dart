// اختبار المسار الكامل للتطبيق: الدخول ← كل أداة ← طلب عميل كامل ← الوضع
// الليلي ← الكاشير ← المشرف. يعمل مع كل `flutter test`.
//
// ولقطات شاشة لكل الواجهات للمراجعة البصرية حين يُحدَّد مجلد الحفظ:
//   SHOT_DIR=/path/to/dir flutter test test/app_flow_test.dart
// وبخط مكبّر كما في إعدادات الجوال (أي تجاوز للمساحة يُفشل الاختبار):
//   TEXT_SCALE=1.3 flutter test test/app_flow_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:sufra/app.dart';
import 'package:sufra/data/cart.dart';
import 'package:sufra/data/models.dart';
import 'package:sufra/data/mutations.dart';
import 'package:sufra/data/seed.dart';
import 'package:sufra/data/store.dart';
import 'package:sufra/state/nav.dart';
import 'package:sufra/state/prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final shotDir = Platform.environment['SHOT_DIR'];
final textScale = double.tryParse(Platform.environment['TEXT_SCALE'] ?? '');

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  const dir = 'assets/fonts';
  await load('Tajawal', ['$dir/Tajawal-Medium.ttf', '$dir/Tajawal-Bold.ttf', '$dir/Tajawal-ExtraBold.ttf']);
  await load('PlexArabic', [
    '$dir/IBMPlexSansArabic-Regular.ttf',
    '$dir/IBMPlexSansArabic-Medium.ttf',
    '$dir/IBMPlexSansArabic-SemiBold.ttf',
    '$dir/IBMPlexSansArabic-Bold.ttf',
  ]);
  await load('Amiri', ['$dir/Amiri-Regular.ttf', '$dir/Amiri-Bold.ttf']);
  // خط الأيقونات من ذاكرة Flutter — إن لم يوجد تُرسم الأيقونات مربعات ولا يتأثر شيء
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
  final icons = '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
  if (File(icons).existsSync()) await load('MaterialIcons', [icons]);
}

Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  testWidgets('المسار الكامل: كل الأدوات وطلب عميل من البداية للنهاية', (tester) async {
    if (shotDir != null) Directory(shotDir!).createSync(recursive: true);
    // الخطوط الحقيقية حتى يطابق التخطيط ما يراه المستخدم (لا خط الاختبار المربّع)
    await tester.runAsync(_loadFonts);

    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    if (textScale != null) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale!;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final prefs = AppPrefs(sp)..chimeEnabled = false;

    // المطعم مفتوح طوال اليوم حتى لا تختلف اللقطات بحسب ساعة التشغيل
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
    final key = GlobalKey();

    Future<void> shot(String name) async {
      await _settle(tester);
      if (shotDir == null) return;
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$shotDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    NavState nav() => Provider.of<NavState>(tester.element(find.byType(RootGate, skipOffstage: false)), listen: false);

    Future<void> open(ToolId tool, String name) async {
      nav().open(tool);
      await shot(name);
    }

    // يمرّر القوائم المحيطة حتى يتوسّط العنصر الشاشة، كما يفعل المستخدم — بالخط
    // المكبّر قد يقع خارج الشاشة أو خارج شريط التصنيفات. التوسيط لا الحافة
    // العليا، حتى لا يختفي تحت شريط مثبّت.
    Future<void> reveal(Finder finder) async {
      await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
      await _settle(tester, 3);
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: SufraApp(store: store, prefs: prefs, carts: CartRegistry(sp)),
      ),
    );
    await shot('01-auth');

    // ============ صاحب المطعم ============
    store.signIn('0551234567', '123456');
    await shot('02-hub-owner');

    await tester.tap(find.byTooltip('القائمة'));
    await shot('03-drawer');
    await tester.tapAt(const Offset(10, 400));
    await _settle(tester);

    await open(ToolId.orders, '04-orders');
    await tester.tap(find.textContaining('1041').first);
    await shot('05-order-detail');
    Navigator.of(tester.element(find.byType(RootGate, skipOffstage: false))).pop();
    await _settle(tester);

    await open(ToolId.overview, '06-overview');
    await open(ToolId.menu, '07-menu');

    await tester.tap(find.text('حمص بالطحينة').first);
    await shot('08-dish-editor');
    await tester.tap(find.byType(BackButton));
    await _settle(tester);

    await open(ToolId.tables, '09-tables');
    await open(ToolId.reports, '10-reports');
    await open(ToolId.staff, '11-staff');
    await open(ToolId.settings, '12-settings');
    await open(ToolId.printMenu, '13-print-menu');
    prefs.setPrintSettings('rest_demo', {'style': 'modern'});
    await shot('13b-print-modern');
    prefs.setPrintSettings('rest_demo', {'style': 'night', 'columns': 1});
    await shot('13c-print-night-1col');
    prefs.setPrintSettings('rest_demo', {});

    // قالبا المنيو الآخران في واجهة العميل
    store.updateRestaurant('rest_demo', (r) => r.template = MenuTemplate.gallery);
    await open(ToolId.storefront, '14b-storefront-gallery');
    store.updateRestaurant('rest_demo', (r) => r.template = MenuTemplate.compact);
    await shot('14c-storefront-compact');
    store.updateRestaurant('rest_demo', (r) => r.template = MenuTemplate.classic);
    nav().goHome();
    await _settle(tester);

    // ============ منيو العميل ومسار الطلب كاملًا ============
    await open(ToolId.storefront, '14-storefront');
    await reveal(find.text('أطباق رئيسية').first);
    await tester.tap(find.text('أطباق رئيسية').first);
    await _settle(tester);
    await reveal(find.text('شاورما دجاج بالصاج').first);
    await tester.tap(find.text('شاورما دجاج بالصاج').first);
    await shot('15-dish-sheet');
    await tester.tap(find.bySemanticsLabel('زيادة').first);
    await _settle(tester, 3);
    await tester.tap(find.text('أضف للسلة').last);
    await shot('16-storefront-cart-bar');
    await tester.tap(find.text('عرض السلة'));
    await shot('17-cart');
    await tester.tap(find.text('إتمام الطلب'));
    await shot('18-checkout');
    await tester.enterText(find.byType(TextFormField).at(0), 'فيصل');
    await tester.enterText(find.byType(TextFormField).at(1), '0567778888');
    await tester.tap(find.text('أرسل الطلب'));
    await shot('19-order-status');
    // الطلب وصل لشاشة الطلبات بالرقم التالي وبياناته
    final placed = store.db.orders.firstWhere((o) => o.orderNumber == 1042);
    expect(placed.customerName, 'فيصل');
    expect(placed.status, OrderStatus.newOrder);
    expect(placed.subtotal, 56);
    expect(find.textContaining('1042'), findsWidgets);
    Navigator.of(tester.element(find.byType(RootGate, skipOffstage: false))).popUntil((r) => r.isFirst);
    await _settle(tester);

    // ============ الوضع الليلي ============
    prefs.themeMode = ThemeMode.dark;
    nav().goHome();
    await shot('20-hub-dark');
    await open(ToolId.storefront, '21-storefront-dark');
    await open(ToolId.orders, '22-orders-dark');
    prefs.themeMode = ThemeMode.light;

    // ============ شاشة الطلبات على جهاز لوحي ============
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2;
    await open(ToolId.orders, '22b-orders-tablet');
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    nav().goHome();
    await _settle(tester);

    // ============ الكاشير ============
    nav().goHome();
    store.signOut();
    await _settle(tester);
    store.signIn('0559876543', '123456');
    await shot('23-hub-staff');
    // الكاشير يرى أداتين فقط: الطلبات ومنيو العميل
    expect(find.text('المنيو الورقي'), findsNothing);
    expect(find.text('التقارير'), findsNothing);

    // ============ مشرف المنصة ============
    store.signOut();
    await _settle(tester);
    store.signIn('0500000000', 'admin123');
    await shot('24-hub-admin');
    await open(ToolId.restaurants, '25-admin-restaurants');
    await open(ToolId.plans, '26-admin-plans');

    // تنظيف: يوقف المؤقّتات والحركات قبل نهاية الاختبار
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
