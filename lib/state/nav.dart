import 'package:flutter/foundation.dart';

import '../data/models.dart';
import 'prefs.dart';

/// كل أداة في التطبيق. تفاصيل العرض (الاسم والأيقونة واللون) في ui/shell/tools.dart.
enum ToolId { orders, overview, storefront, menu, printMenu, tables, reports, staff, settings, restaurants, plans }

/// ما يراه كل دور — مطابق لصلاحيات الموقع: الكاشير يرى الطلبات فقط،
/// والمشرف يدير المنصة لا مطعمًا بعينه.
/// «منيو العميل» متاح للكاشير أيضًا: هو المنيو العام نفسه الذي يفتحه أي
/// عميل، ويفيده في إدخال طلب زبون حاضر أو طلب هاتفي.
List<ToolId> toolsForRole(Role role) => switch (role) {
  Role.owner => const [
    ToolId.orders,
    ToolId.overview,
    ToolId.storefront,
    ToolId.menu,
    ToolId.printMenu,
    ToolId.tables,
    ToolId.reports,
    ToolId.staff,
    ToolId.settings,
  ],
  Role.staff => const [ToolId.orders, ToolId.storefront],
  Role.admin => const [ToolId.restaurants, ToolId.plans],
};

/// الأداة المفتوحة (null = شاشة «ماذا تريد أن تستخدم؟») والأدوات المستخدمة مؤخرًا.
class NavState extends ChangeNotifier {
  NavState(this._prefs);

  final AppPrefs _prefs;
  String? _profileId;
  Role? _role;

  ToolId? tool;
  List<ToolId> recent = const [];

  bool get atHub => tool == null;

  /// يُستدعى عند كل دخول: يبدأ من شاشة الاختيار ويحمّل أدوات هذا الحساب الأخيرة
  void bind(Profile profile) {
    if (_profileId == profile.id) return;
    _profileId = profile.id;
    _role = profile.role;
    tool = null;
    final allowed = toolsForRole(profile.role);
    recent = [for (final name in _prefs.recentTools(profile.id)) ...allowed.where((t) => t.name == name)];
  }

  void unbind() {
    _profileId = null;
    _role = null;
    tool = null;
    recent = const [];
  }

  bool allows(ToolId t) => _role != null && toolsForRole(_role!).contains(t);

  void open(ToolId t) {
    if (!allows(t)) return;
    tool = t;
    recent = [t, ...recent.where((r) => r != t)].take(4).toList();
    final id = _profileId;
    if (id != null) _prefs.setRecentTools(id, [for (final r in recent) r.name]);
    notifyListeners();
  }

  void goHome() {
    if (tool == null) return;
    tool = null;
    notifyListeners();
  }
}
