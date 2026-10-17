import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/feedback.dart';
import '../../core/sound.dart';
import '../../core/theme.dart';
import '../../data/arabic.dart';
import '../../data/models.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../../state/nav.dart';
import '../../state/prefs.dart';
import '../../state/session.dart';
import '../common/basics.dart';
import '../common/brand.dart';
import '../common/buttons.dart';
import 'app_drawer.dart';
import 'hub_screen.dart';
import 'tools.dart';

/// إطار ما بعد الدخول: زر القائمة ☰، شريط العنوان، وإما شاشة
/// «ماذا تريد أن تستخدم؟» أو الأداة المفتوحة.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.profile});

  final Profile profile;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// الخروج من التطبيق يحتاج ضغطتي رجوع متتاليتين من شاشة الاختيار —
  /// جهاز الكاشير يُمسك طوال اليوم، والضغطة العارضة لا يجب أن تغلقه
  DateTime? _exitArmedAt;

  bool get _exitArmed => _exitArmedAt != null && DateTime.now().difference(_exitArmedAt!) < const Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    context.read<NavState>().bind(widget.profile);
  }

  @override
  void didUpdateWidget(AppShell old) {
    super.didUpdateWidget(old);
    if (old.profile.id != widget.profile.id) context.read<NavState>().bind(widget.profile);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final nav = context.watch<NavState>();
    final tool = nav.tool;
    final role = widget.profile.role;

    return PopScope(
      // الرجوع من أداة يعود لشاشة الاختيار؛ ومن شاشة الاختيار يحتاج تأكيدًا
      canPop: tool == null && _exitArmed,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (nav.tool != null) {
          nav.goHome();
          return;
        }
        setState(() => _exitArmedAt = DateTime.now());
        toast('اضغط رجوع مرة أخرى للخروج', icon: Icons.exit_to_app_rounded);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _exitArmedAt = null);
        });
      },
      child: OrderAlerts(
        enabled: role != Role.admin,
        child: Scaffold(
          drawer: const AppDrawer(),
          drawerEdgeDragWidth: 28,
          appBar: AppBar(
            toolbarHeight: 60,
            leading: Builder(
              builder: (c) => IconButton(
                tooltip: 'القائمة',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Scaffold.of(c).openDrawer();
                },
                icon: Icon(Icons.menu_rounded, color: p.ink, size: 26),
              ),
            ),
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: tool == null
                  ? const Align(
                      key: ValueKey('hub'),
                      alignment: AlignmentDirectional.centerStart,
                      child: Wordmark(size: 26),
                    )
                  : Row(
                      key: ValueKey(tool),
                      children: [
                        TintIcon(tool.icon, tool.tint, size: 32),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            tool.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: heading(18, color: p.ink),
                          ),
                        ),
                      ],
                    ),
            ),
            actions: [
              if (role != Role.admin) const _OrdersBell(),
              if (tool != null)
                IconButton(
                  tooltip: 'كل الأدوات',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    nav.goHome();
                  },
                  icon: const Icon(Icons.apps_rounded),
                ),
              const SizedBox(width: 6),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: p.line),
            ),
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .025), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(tool),
              child: tool == null ? HubScreen(profile: widget.profile) : tool.body(),
            ),
          ),
        ),
      ),
    );
  }
}

/// جرس الطلبات الجديدة في شريط العنوان — يفتح شاشة الطلبات من أي أداة
class _OrdersBell extends StatelessWidget {
  const _OrdersBell();

  @override
  Widget build(BuildContext context) {
    final count = context.select<DataStore, int>((s) {
      final restaurant = sessionOf(s.db).restaurant;
      return restaurant == null ? 0 : countOrdersByStatus(s.db, restaurant.id, OrderStatus.newOrder);
    });
    final nav = context.watch<NavState>();
    final p = context.palette;
    return IconButton(
      tooltip: count > 0 ? '$count طلب جديد' : 'الطلبات',
      onPressed: nav.tool == ToolId.orders
          ? null
          : () {
              HapticFeedback.selectionClick();
              nav.open(ToolId.orders);
            },
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count', style: txt(10.5, weight: FontWeight.w700, height: 1)),
        backgroundColor: p.saffron,
        textColor: p.onSaffron,
        child: Icon(
          count > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
          color: count > 0 ? p.saffron : p.inkSoft,
        ),
      ),
    );
  }
}

/// ينبّه للطلب الجديد من أي شاشة: نغمة + اهتزاز + تنبيه بزر «افتح».
/// يتذكّر كل طلب رآه، فلا يرنّ عند فتح التطبيق على طلبات موجودة، ولا عند
/// إعادة طلب ملغي.
class OrderAlerts extends StatefulWidget {
  const OrderAlerts({super.key, required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  State<OrderAlerts> createState() => _OrderAlertsState();
}

class _OrderAlertsState extends State<OrderAlerts> {
  late final DataStore _store = context.read<DataStore>();
  Set<String>? _seen;
  String? _restaurantId;

  @override
  void initState() {
    super.initState();
    _store.addListener(_check);
    _check();
  }

  @override
  void dispose() {
    _store.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!widget.enabled) return;
    final db = _store.db;
    final restaurant = sessionOf(db).restaurant;
    if (restaurant == null) return;
    final orders = db.orders.where((o) => o.restaurantId == restaurant.id).toList();
    if (_seen == null || _restaurantId != restaurant.id) {
      _restaurantId = restaurant.id;
      _seen = {for (final o in orders) o.id};
      return;
    }
    final fresh = orders.where((o) => o.status == OrderStatus.newOrder && !_seen!.contains(o.id)).toList();
    _seen!.addAll(orders.map((o) => o.id));
    if (fresh.isEmpty || !mounted) return;

    final prefs = context.read<AppPrefs>();
    if (prefs.chimeEnabled) OrderChime.instance.play();
    final latest = fresh.last;
    final where =
        latest.tableLabel ??
        switch (latest.type) {
          OrderType.dineIn => 'في المطعم',
          OrderType.pickup => 'استلام',
          OrderType.delivery => 'توصيل',
        };
    final nav = context.read<NavState>();
    toastAction(
      fresh.length == 1
          ? 'طلب جديد ${ltr('#${latest.orderNumber}')} · $where'
          : '${newOrdersPhrase(fresh.length)} وصلت',
      label: 'افتح',
      icon: Icons.notifications_active_rounded,
      onPressed: () => nav.open(ToolId.orders),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// ترويسة موحّدة لأعلى كل أداة: عنوان صغير، عنوان، وأزرار اختيارية.
class ToolHeader extends StatelessWidget {
  const ToolHeader({super.key, required this.title, this.eyebrow, this.actions = const [], this.subtitle});

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[Eyebrow(eyebrow!), const SizedBox(height: 2)],
          Text(title, style: heading(24, color: p.ink)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: txt(13.5, color: p.inkSoft, height: 1.6)),
          ],
          if (actions.isNotEmpty) ...[const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: actions)],
        ],
      ),
    );
  }
}

/// زر صغير لرأس الأداة
AppButton headerButton(String label, IconData icon, VoidCallback onPressed, {bool primary = false}) => AppButton(
  label: label,
  icon: icon,
  onPressed: onPressed,
  size: BtnSize.sm,
  tone: primary ? BtnTone.primary : BtnTone.outline,
);
