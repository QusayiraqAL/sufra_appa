import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/export.dart';
import '../../core/images.dart';
import '../../core/theme.dart';
import '../../data/arabic.dart';
import '../../data/models.dart';
import '../../data/queries.dart';
import '../../data/utils.dart';
import '../../state/nav.dart';
import '../../state/session.dart';
import '../common/basics.dart';
import '../common/buttons.dart';
import 'tools.dart';

void openTool(BuildContext context, ToolId tool) {
  HapticFeedback.selectionClick();
  context.read<NavState>().open(tool);
}

/// أول شاشة بعد الدخول: «ماذا تريد أن تستخدم الآن؟»
/// فوقها ما يحتاج انتباهًا فوريًا (طلبات تنتظر، أطباق نفدت)، ثم الأدوات
/// مجمّعة حسب طبيعة العمل.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  @override
  Widget build(BuildContext context) {
    final db = context.watchDb();
    final (:profile, :restaurant) = sessionOf(db);
    if (profile == null) return const SizedBox.shrink();
    final tools = toolsForRole(profile.role);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _Greeting(profile: profile),
        const SizedBox(height: 18),
        if (restaurant != null) ...[
          _RestaurantCard(restaurant: restaurant, canManage: profile.role == Role.owner),
          _NowStrip(db: db, restaurant: restaurant, owner: profile.role == Role.owner),
        ] else if (profile.role == Role.admin)
          _PlatformCard(db: db),
        const _RecentRow(),
        for (final (group, list) in groupedTools(tools)) ...[
          const SizedBox(height: 24),
          Text(
            group.label,
            style: txt(13, color: context.palette.inkFaint, weight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _ToolGrid(tools: list, db: db, restaurant: restaurant),
        ],
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hour = DateTime.now().hour;
    final salute = hour < 12 ? 'صباح الخير' : 'مساء الخير';
    final first = profile.name.trim().split(RegExp(r'\s+')).first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$salute، $first',
          style: txt(15, color: p.inkSoft, weight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text('ماذا تريد أن تستخدم الآن؟', style: heading(25, color: p.ink)),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'اختر أداة وابدأ مباشرة، وبدّل بينها من القائمة '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: p.saffronTint, borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.menu_rounded, size: 14, color: p.saffron),
                ),
              ),
              const TextSpan(text: ' متى شئت.'),
            ],
          ),
          style: txt(13.5, color: p.inkFaint, height: 1.7),
        ),
      ],
    );
  }
}

/// بطاقة المطعم: حالته الآن ورابط منيوه
class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.restaurant, required this.canManage});

  final Restaurant restaurant;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final open = isOpenNow(restaurant.workingHours);
    final today = restaurant.workingHours[jsDay(DateTime.now())];
    final status = open
        ? 'مفتوح الآن · حتى ${ltr(today.close)}'
        : today.closed
        ? 'مغلق اليوم'
        : 'مغلق الآن · يفتح ${ltr(today.open)}';
    final logo = dataImage(restaurant.logoUrl);
    final url = AppConfig.menuUrl(restaurant.slug);

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.line),
                ),
                child: logo != null
                    ? Image(image: logo, fit: BoxFit.cover, width: 52, height: 52)
                    : Text(
                        brandInitial(restaurant.name),
                        textScaler: TextScaler.noScaling,
                        style: heading(22, color: p.saffron),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: heading(17, color: p.ink),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        PulseDot(color: open ? p.basil : p.sumac, size: 7, animate: open),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: txt(12.5, color: open ? p.basil : p.sumac, weight: FontWeight.w600, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'افتح المنيو',
                  icon: Icons.storefront_rounded,
                  size: BtnSize.sm,
                  expand: true,
                  onPressed: () => openTool(context, ToolId.storefront),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'شارك الرابط',
                  icon: Icons.ios_share_rounded,
                  size: BtnSize.sm,
                  expand: true,
                  onPressed: () => shareText('منيو ${restaurant.name}:\n$url'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ما يحتاج انتباهًا الآن: بطاقة واحدة للطلبات (جديدة، متأخرة، جاهزة)،
/// ثم الأطباق النافدة والإعداد الناقص — مختصرة حتى تبقى الأدوات قريبة.
class _NowStrip extends StatelessWidget {
  const _NowStrip({required this.db, required this.restaurant, required this.owner});

  final DB db;
  final Restaurant restaurant;
  final bool owner;

  @override
  Widget build(BuildContext context) {
    final orders = getOrders(db, restaurant.id);
    final fresh = orders.where((o) => o.status == OrderStatus.newOrder).toList();
    final overdue = orders
        .where(
          (o) =>
              (o.status == OrderStatus.newOrder || o.status == OrderStatus.preparing) &&
              minutesSince(o.createdAt) >= 12,
        )
        .length;
    final ready = orders.where((o) => o.status == OrderStatus.ready).length;
    final soldOut = getUnavailableDishes(db, restaurant.id);

    final cards = <Widget>[
      if (fresh.isNotEmpty || overdue > 0 || ready > 0)
        _OrdersNowCard(
          fresh: fresh.length,
          overdue: overdue,
          ready: ready,
          oldest: fresh.isEmpty ? null : timeAgo(fresh.last.createdAt),
          onTap: () => openTool(context, ToolId.orders),
        ),
      if (owner && soldOut.isNotEmpty)
        _NowCard(
          icon: Icons.no_food_outlined,
          tint: Tint.sumac,
          title: soldOut.length == 1 ? 'طبق نافد اليوم' : '${countOf(soldOut.length, nDish)} نافدة اليوم',
          subtitle: soldOut.map((d) => d.name).take(3).join('، '),
          onTap: () => openTool(context, ToolId.menu),
        ),
      if (owner) ?_setupCard(context),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: c)],
      ),
    );
  }

  Widget? _setupCard(BuildContext context) {
    final steps = [
      countDishes(db, restaurant.id) >= 3,
      getMenu(db, restaurant.id).length >= 2,
      restaurant.logoUrl != null,
      !restaurant.dineInEnabled || getTables(db, restaurant.id).isNotEmpty,
    ];
    final done = steps.where((s) => s).length;
    if (done == steps.length) return null;
    return _NowCard(
      icon: Icons.checklist_rounded,
      tint: Tint.indigo,
      title: 'أكمل إعداد مطعمك',
      subtitle: '${ltr('$done/${steps.length}')} — التفاصيل في «نظرة عامة»',
      onTap: () => openTool(context, ToolId.overview),
    );
  }
}

/// بطاقة الطلبات الآن: ثلاثة عدّادات في بطاقة واحدة
class _OrdersNowCard extends StatelessWidget {
  const _OrdersNowCard({
    required this.fresh,
    required this.overdue,
    required this.ready,
    required this.oldest,
    required this.onTap,
  });

  final int fresh;
  final int overdue;
  final int ready;
  final String? oldest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = tintColors(Tint.saffron, p.isDark);
    Widget counter(int n, String label, Color color, {bool live = false}) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: n > 0 ? color.withValues(alpha: p.isDark ? .16 : .1) : p.surface2.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(ltr('$n'), style: heading(20, color: n > 0 ? color : p.inkFaint, height: 1.1)),
                if (live && n > 0) ...[const SizedBox(width: 2), PulseDot(color: color, size: 6)],
              ],
            ),
            Text(
              label,
              style: txt(12, color: n > 0 ? p.ink : p.inkFaint, weight: FontWeight.w600, height: 1.3),
            ),
          ],
        ),
      ),
    );
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: fresh > 0 ? c.fg.withValues(alpha: .45) : p.line, width: fresh > 0 ? 1.4 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 19, color: c.fg),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fresh > 0 ? '${newOrdersPhrase(fresh)} بانتظارك' : 'الطلبات الآن',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: txt(14.5, color: p.ink, weight: FontWeight.w700, height: 1.35),
                    ),
                  ),
                  if (oldest != null) Text('أقدمها $oldest', style: txt(12, color: p.inkFaint)),
                  Icon(Icons.chevron_right_rounded, color: c.fg),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  counter(fresh, 'جديد', p.saffron, live: true),
                  const SizedBox(width: 8),
                  counter(overdue, 'متأخر', p.ember),
                  const SizedBox(width: 8),
                  counter(ready, 'جاهز', p.basil),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NowCard extends StatelessWidget {
  const _NowCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Tint tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = tintColors(tint, p.isDark);
    return Material(
      color: c.fg.withValues(alpha: p.isDark ? .12 : .07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: c.fg.withValues(alpha: .28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              TintIcon(icon, tint, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: txt(14.5, color: p.ink, weight: FontWeight.w700, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: txt(12.5, color: p.inkSoft, height: 1.4),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// ملخّص المنصة للمشرف
class _PlatformCard extends StatelessWidget {
  const _PlatformCard({required this.db});

  final DB db;

  @override
  Widget build(BuildContext context) {
    final s = platformStats(db);
    return Row(
      children: [
        Expanded(
          child: StatTile(label: 'مطاعم', value: Text(ltr('${s.restaurants}')), sub: '${s.activeRestaurants} نشطة'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            label: 'طلبات اليوم',
            value: Text(ltr('${s.ordersToday}')),
            tone: Tone.saffron,
            sub: '${s.orders} إجمالًا',
          ),
        ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow();

  @override
  Widget build(BuildContext context) {
    final recent = context.select<NavState, List<ToolId>>((n) => n.recent);
    if (recent.isEmpty) return const SizedBox.shrink();
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تابع من حيث توقفت',
            style: txt(13, color: p.inkFaint, weight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = recent[i];
                return Material(
                  color: p.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    side: BorderSide(color: p.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => openTool(context, t),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 14, 6),
                      child: Row(
                        children: [
                          TintIcon(t.icon, t.tint, size: 34),
                          const SizedBox(width: 8),
                          Text(
                            t.title,
                            style: txt(13.5, color: p.ink, weight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.tools, required this.db, required this.restaurant});

  final List<ToolId> tools;
  final DB db;
  final Restaurant? restaurant;

  int? _badge(ToolId t) {
    final r = restaurant;
    if (r == null) return null;
    return switch (t) {
      ToolId.orders => countOrdersByStatus(db, r.id, OrderStatus.newOrder),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 480
            ? 3
            : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: tools.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 146 * scale,
          ),
          itemBuilder: (context, i) => _ToolTile(tool: tools[i], badge: _badge(tools[i])),
        );
      },
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool, this.badge});

  final ToolId tool;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: '${tool.title}. ${tool.blurb}',
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        onTap: () => openTool(context, tool),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TintIcon(tool.icon, tool.tint, size: 44),
                const Spacer(),
                if (badge != null && badge! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: p.saffron, borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      '$badge جديد',
                      style: txt(11.5, color: p.onSaffron, weight: FontWeight.w700, height: 1.35),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              tool.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: heading(15.5, color: p.ink, weight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              tool.blurb,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: txt(12, color: p.inkFaint, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
