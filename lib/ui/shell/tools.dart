import 'package:flutter/material.dart';

import '../../state/nav.dart';
import '../admin/plans_tool.dart';
import '../admin/restaurants_tool.dart';
import '../common/basics.dart';
import '../menu/menu_tool.dart';
import '../orders/orders_tool.dart';
import '../overview/overview_tool.dart';
import '../print_menu/print_menu_tool.dart';
import '../reports/reports_tool.dart';
import '../settings/settings_tool.dart';
import '../staff/staff_tool.dart';
import '../storefront/storefront_tool.dart';
import '../tables/tables_tool.dart';

/// مجموعات الأدوات في شاشة الاختيار وفي القائمة ☰
enum ToolGroup {
  operations('التشغيل اليومي'),
  menu('المنيو والطاولات'),
  management('الإدارة'),
  platform('إدارة المنصة');

  const ToolGroup(this.label);
  final String label;
}

/// كيف تظهر كل أداة في شاشة الاختيار والقائمة وشريط العنوان.
extension ToolInfo on ToolId {
  String get title => switch (this) {
    ToolId.orders => 'الطلبات',
    ToolId.overview => 'نظرة عامة',
    ToolId.storefront => 'منيو العميل',
    ToolId.menu => 'المنيو',
    ToolId.printMenu => 'المنيو الورقي',
    ToolId.tables => 'الطاولات و QR',
    ToolId.reports => 'التقارير',
    ToolId.staff => 'الموظفون',
    ToolId.settings => 'الإعدادات',
    ToolId.restaurants => 'المطاعم',
    ToolId.plans => 'الخطط',
  };

  String get blurb => switch (this) {
    ToolId.orders => 'استقبل الطلبات لحظيًا وحرّكها حتى التسليم',
    ToolId.overview => 'أرقام اليوم ورابط المنيو وما يحتاج انتباهك',
    ToolId.storefront => 'منيوك كما يراه العميل — واطلب منه بنفسك',
    ToolId.menu => 'الأقسام والأطباق والأسعار والإضافات',
    ToolId.printMenu => 'منيو جاهز للطباعة من أطباقك الحالية',
    ToolId.tables => 'رمز لكل طاولة، جاهز للطباعة والمشاركة',
    ToolId.reports => 'المبيعات والأطباق الأكثر طلبًا والذروة',
    ToolId.staff => 'حسابات الكاشير: يرون الطلبات فقط',
    ToolId.settings => 'الهوية والعملة والضريبة وأوقات العمل',
    ToolId.restaurants => 'كل مطاعم المنصة: تفعيل وإيقاف واستعادة',
    ToolId.plans => 'خطط الاشتراك المجهّزة للمرحلة المدفوعة',
  };

  IconData get icon => switch (this) {
    ToolId.orders => Icons.receipt_long_rounded,
    ToolId.overview => Icons.space_dashboard_rounded,
    ToolId.storefront => Icons.storefront_rounded,
    ToolId.menu => Icons.restaurant_menu_rounded,
    ToolId.printMenu => Icons.menu_book_rounded,
    ToolId.tables => Icons.qr_code_2_rounded,
    ToolId.reports => Icons.insights_rounded,
    ToolId.staff => Icons.badge_rounded,
    ToolId.settings => Icons.tune_rounded,
    ToolId.restaurants => Icons.store_mall_directory_rounded,
    ToolId.plans => Icons.workspace_premium_rounded,
  };

  Tint get tint => switch (this) {
    ToolId.orders => Tint.saffron,
    ToolId.overview => Tint.zaatar,
    ToolId.storefront => Tint.ember,
    ToolId.menu => Tint.sumac,
    ToolId.printMenu => Tint.berry,
    ToolId.tables => Tint.indigo,
    ToolId.reports => Tint.teal,
    ToolId.staff => Tint.olive,
    ToolId.settings => Tint.charcoal,
    ToolId.restaurants => Tint.saffron,
    ToolId.plans => Tint.berry,
  };

  ToolGroup get group => switch (this) {
    ToolId.orders || ToolId.overview || ToolId.storefront => ToolGroup.operations,
    ToolId.menu || ToolId.printMenu || ToolId.tables => ToolGroup.menu,
    ToolId.reports || ToolId.staff || ToolId.settings => ToolGroup.management,
    ToolId.restaurants || ToolId.plans => ToolGroup.platform,
  };

  Widget body() => switch (this) {
    ToolId.orders => const OrdersTool(),
    ToolId.overview => const OverviewTool(),
    ToolId.storefront => const StorefrontTool(),
    ToolId.menu => const MenuTool(),
    ToolId.printMenu => const PrintMenuTool(),
    ToolId.tables => const TablesTool(),
    ToolId.reports => const ReportsTool(),
    ToolId.staff => const StaffTool(),
    ToolId.settings => const SettingsTool(),
    ToolId.restaurants => const RestaurantsTool(),
    ToolId.plans => const PlansTool(),
  };
}

/// أدوات الدور مجمّعة بترتيب المجموعات
List<(ToolGroup, List<ToolId>)> groupedTools(List<ToolId> tools) => [
  for (final g in ToolGroup.values)
    if (tools.where((t) => t.group == g).toList() case final list when list.isNotEmpty) (g, list),
];
