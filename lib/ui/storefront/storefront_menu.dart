import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/colors.dart';
import '../../core/config.dart';
import '../../core/export.dart';
import '../../core/feedback.dart';
import '../../core/images.dart';
import '../../core/theme.dart';
import '../../data/cart.dart';
import '../../data/models.dart';
import '../../data/queries.dart';
import '../../data/utils.dart';
import '../../data/validation.dart';
import '../../state/session.dart';
import '../common/basics.dart';
import '../common/sheets.dart';
import 'brand_scope.dart';
import 'cart_screen.dart';
import 'dish_sheet.dart';

/// من يتصفّح المنيو: عميل (زائر) أو طاقم المطعم نيابةً عن عميل.
enum StorefrontMode { guest, operator }

/// منيو العميل — مقابل صفحة /m/[slug] في الموقع.
class StorefrontMenu extends StatefulWidget {
  const StorefrontMenu({super.key, required this.slug, this.mode = StorefrontMode.guest, this.initialTableToken});

  final String slug;
  final StorefrontMode mode;
  final String? initialTableToken;

  @override
  State<StorefrontMenu> createState() => _StorefrontMenuState();
}

class _StorefrontMenuState extends State<StorefrontMenu> with SingleTickerProviderStateMixin {
  static const _chipsHeight = 58.0;

  /// نبضة شريط السلة عند الإضافة — التغذية الراجعة حيث سيضغط الإبهام تاليًا.
  /// تُنشأ في initState لا عند أول استخدام: إنشاؤها كسولًا داخل dispose
  /// يطلب مؤقّتًا من شجرة لم تعد نشطة.
  late final AnimationController _bounce;
  late final Animation<double> _bounceScale;

  final _scroll = ScrollController();
  final _chipsScroll = ScrollController();
  final _search = TextEditingController();
  final _sectionKeys = <String, GlobalKey>{};
  final _chipKeys = <String, GlobalKey>{};
  String _query = '';
  String? _active;
  bool _jumping = false;

  late final CartStore _cart = context.read<CartRegistry>().of(widget.slug);

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.045).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.045, end: 1).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_bounce);
    // رمز الطاولة يُحفظ في السلة، فيبقى لو تنقّل العميل بين الشاشات
    final token = widget.initialTableToken;
    if (token != null) WidgetsBinding.instance.addPostFrameCallback((_) => _cart.setTableToken(token));
    _scroll.addListener(_syncActive);
  }

  @override
  void dispose() {
    _bounce.dispose();
    _scroll.dispose();
    _chipsScroll.dispose();
    _search.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(Map<String, GlobalKey> map, String id) => map.putIfAbsent(id, GlobalKey.new);

  double? _revealOffset(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box == null || !box.attached) return null;
    final viewport = RenderAbstractViewport.maybeOf(box);
    return viewport?.getOffsetToReveal(box, 0).offset;
  }

  /// القسم النشط في شريط الأقسام يتبع موضع التمرير
  void _syncActive() {
    if (_jumping || _query.isNotEmpty || !_scroll.hasClients) return;
    String? current;
    for (final entry in _sectionKeys.entries) {
      final at = _revealOffset(entry.value);
      if (at != null && at - _chipsHeight <= _scroll.offset + 12) current = entry.key;
    }
    current ??= _sectionKeys.keys.firstOrNull;
    if (current != _active) {
      setState(() => _active = current);
      _revealChip(current);
    }
  }

  void _revealChip(String? id) {
    final ctx = id == null ? null : _chipKeys[id]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, alignment: .5, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _jumpTo(String id) async {
    HapticFeedback.selectionClick();
    final at = _revealOffset(_keyFor(_sectionKeys, id));
    if (at == null) return;
    setState(() => _active = id);
    _revealChip(id);
    _jumping = true;
    final target = (at - _chipsHeight + 1).clamp(0.0, _scroll.position.maxScrollExtent);
    await _scroll.animateTo(target, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    _jumping = false;
  }

  Future<void> _openDish(Restaurant restaurant, String dishId) async {
    final db = context.store.db;
    final dish = getDishWithOptions(db, dishId);
    if (dish == null) return;
    final pick = await showDishSheet(context, dish: dish, restaurant: restaurant);
    if (pick == null) return;
    final added = _cart.add(dish.id, pick.selections, pick.note, pick.qty);
    HapticFeedback.lightImpact();
    _bounce.forward(from: 0);
    if (added < pick.qty) {
      toastError('أقصى كمية للصنف الواحد $maxLineQty');
    } else {
      toast('أُضيف «${dish.name}» للسلة', icon: Icons.shopping_bag_rounded);
    }
  }

  Future<void> _pickTable(DB db, Restaurant restaurant) async {
    final tables = getTables(db, restaurant.id);
    final picked = await showAppSheet<String>(
      context,
      title: 'الطلب لأي طاولة؟',
      subtitle: 'يُحفظ رقم الطاولة في السلة كما لو مسح العميل رمزها',
      builder: (c) {
        final p = c.palette;
        if (tables.isEmpty) {
          return const EmptyState(
            title: 'لا طاولات بعد',
            body: 'أضف طاولاتك من أداة «الطاولات و QR» لتظهر هنا.',
            icon: Icons.table_restaurant_outlined,
          );
        }
        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.shopping_bag_outlined),
              title: const Text('بدون طاولة (استلام أو توصيل)'),
              onTap: () => Navigator.pop(c, ''),
            ),
            const Divider(),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.9,
              children: [
                for (final t in tables)
                  Material(
                    color: _cart.tableToken == t.qrToken ? p.saffronTint : p.surface2,
                    borderRadius: BorderRadius.circular(Radii.md),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.md),
                      onTap: () => Navigator.pop(c, t.qrToken),
                      child: Center(
                        child: Text(
                          t.label,
                          textAlign: TextAlign.center,
                          style: txt(13.5, color: p.ink, weight: FontWeight.w700, height: 1.3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
    if (picked == null) return;
    _cart.setTableToken(picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watchDb();
    final restaurant = getRestaurantBySlug(db, widget.slug);
    final p = context.palette;

    if (restaurant == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            title: 'لا يوجد مطعم بهذا الرابط',
            body: 'تأكّد من الرابط أو أعد مسح رمز QR. الرابط المطلوب: ${ltr('/m/${widget.slug}')}',
            icon: Icons.link_off_rounded,
          ),
        ),
      );
    }
    if (!restaurant.isActive) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            title: '${restaurant.name} غير متاح حاليًا',
            body: 'حساب المطعم موقوف مؤقتًا، فلا يمكن استقبال الطلبات.',
            icon: Icons.pause_circle_outline_rounded,
          ),
        ),
      );
    }

    return BrandScope.wrap(
      context,
      restaurant,
      ListenableBuilder(
        listenable: _cart,
        builder: (context, _) {
          final sections = getMenu(db, restaurant.id, visibleOnly: true);
          final table = _cart.tableToken == null ? null : getTableByToken(db, restaurant.id, _cart.tableToken!);
          final open = isOpenNow(restaurant.workingHours);
          final priced = priceCart(db, _cart.lines);
          final cartTotal = round2(priced.fold(0.0, (s, l) => s + l.lineTotal));
          final searching = _query.trim().isNotEmpty;
          final results = searching
              ? [
                  for (final s in sections)
                    for (final d in s.dishes)
                      if (matchesQuery('${d.name} ${d.description}', _query)) d,
                ]
              : const <Dish>[];

          // مفاتيح الأقسام الحالية فقط — قسم حُذف لا يبقى في حساب التمرير
          _sectionKeys.removeWhere((id, _) => !sections.any((s) => s.category.id == id));
          _active ??= sections.firstOrNull?.category.id;

          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: p.surface,
                  child: CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      SliverToBoxAdapter(
                        child: _Cover(restaurant: restaurant, open: open),
                      ),
                      SliverToBoxAdapter(
                        child: _Info(
                          restaurant: restaurant,
                          open: open,
                          table: table,
                          mode: widget.mode,
                          onPickTable: () => _pickTable(db, restaurant),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                          child: TextField(
                            controller: _search,
                            onChanged: (v) => setState(() => _query = v),
                            textInputAction: TextInputAction.search,
                            style: txt(15, color: p.ink),
                            decoration: InputDecoration(
                              hintText: 'ابحث في المنيو',
                              filled: true,
                              fillColor: p.surface2.withValues(alpha: .6),
                              prefixIcon: const Icon(Icons.search_rounded),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'امسح البحث',
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () {
                                        _search.clear();
                                        setState(() => _query = '');
                                      },
                                    ),
                            ),
                          ),
                        ),
                      ),
                      if (!searching && sections.length > 1)
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _ChipsHeader(
                            height: _chipsHeight,
                            child: _CategoryChips(
                              sections: sections,
                              active: _active,
                              controller: _chipsScroll,
                              keyFor: (id) => _keyFor(_chipKeys, id),
                              onTap: _jumpTo,
                            ),
                          ),
                        ),
                      if (searching)
                        results.isEmpty
                            ? SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: EmptyState(
                                    title: 'لا نتائج',
                                    body: 'ما وجدنا طبقًا يطابق «${_query.trim()}».',
                                    icon: Icons.search_off_rounded,
                                  ),
                                ),
                              )
                            : SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                sliver: SliverList.separated(
                                  itemCount: results.length,
                                  separatorBuilder: (_, _) => Divider(height: 1, color: p.line),
                                  itemBuilder: (_, i) => _DishRow(
                                    dish: results[i],
                                    currency: restaurant.currency,
                                    onTap: () => _openDish(restaurant, results[i].id),
                                  ),
                                ),
                              )
                      else if (sections.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: EmptyState(
                              title: 'المنيو قيد التحضير',
                              body: 'لم يُضف المطعم أطباقه بعد.',
                              icon: Icons.restaurant_outlined,
                            ),
                          ),
                        )
                      else
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final section in sections)
                                _Section(
                                  key: _keyFor(_sectionKeys, section.category.id),
                                  section: section,
                                  template: restaurant.template,
                                  currency: restaurant.currency,
                                  onOpen: (id) => _openDish(restaurant, id),
                                ),
                            ],
                          ),
                        ),
                      SliverToBoxAdapter(child: SizedBox(height: _cart.count > 0 ? 110 : 32)),
                    ],
                  ),
                ),
              ),
              if (_cart.count > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: StickyBar(
                    child: open
                        ? ScaleTransition(
                            scale: _bounceScale,
                            child: BrandBarButton(
                              label: 'عرض السلة',
                              icon: Icons.shopping_bag_rounded,
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CartScreen(slug: widget.slug, mode: widget.mode),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(ltr('${_cart.count}')),
                                  Text(
                                    '  ·  ',
                                    style: TextStyle(color: BrandScope.of(context).onBrand.withValues(alpha: .5)),
                                  ),
                                  MoneyText(
                                    cartTotal,
                                    currency: restaurant.currency,
                                    style: heading(
                                      15.5,
                                      color: BrandScope.of(context).onBrand,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const BrandBarButton(label: 'مغلق الآن — لا يمكن إرسال الطلب', onPressed: null),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/* ===================== الغلاف ===================== */

class _Cover extends StatelessWidget {
  const _Cover({required this.restaurant, required this.open});

  final Restaurant restaurant;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final brand = BrandScope.of(context);
    final cover = dataImage(restaurant.coverUrl);
    final logo = dataImage(restaurant.logoUrl);
    final canPop = Navigator.of(context).canPop() && ModalRoute.of(context)?.isFirst == false;

    return SizedBox(
      height: 176,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            bottom: 34,
            child: cover != null
                ? Image(image: cover, fit: BoxFit.cover)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                        colors: [brand.raw, mixOklab(brand.raw, Colors.black, .65)],
                      ),
                    ),
                    child: CustomPaint(painter: _PatternPainter(Colors.white.withValues(alpha: .07))),
                  ),
          ),
          PositionedDirectional(
            top: 12,
            start: 12,
            child: Row(
              children: [
                if (canPop) ...[
                  Material(
                    color: Colors.black.withValues(alpha: .35),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'رجوع',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .38),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulseDot(color: open ? const Color(0xFF6EE7B7) : const Color(0xFFFDA4AF), size: 7, animate: open),
                      const SizedBox(width: 3),
                      Text(
                        open ? 'مفتوح الآن' : 'مغلق الآن',
                        style: txt(12, color: Colors.white, weight: FontWeight.w600, height: 1.2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // اللوجو يركب على حافة الغلاف
          PositionedDirectional(
            start: 16,
            bottom: 0,
            child: Container(
              width: 72,
              height: 72,
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.surface, width: 3),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: logo != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Image(image: logo, fit: BoxFit.cover, width: 72, height: 72),
                    )
                  : Text(
                      brandInitial(restaurant.name),
                      textScaler: TextScaler.noScaling,
                      style: heading(28, color: brand.brand),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// نقش هادئ على الغلاف الافتراضي — دوائر صغيرة مثل صحون مصفوفة
class _PatternPainter extends CustomPainter {
  _PatternPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const step = 34.0;
    for (var y = 12.0; y < size.height + step; y += step) {
      final shift = ((y / step).round().isOdd) ? step / 2 : 0.0;
      for (var x = -step + shift; x < size.width + step; x += step) {
        canvas.drawCircle(Offset(x, y), 7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.color != color;
}

/* ===================== معلومات المطعم ===================== */

class _Info extends StatelessWidget {
  const _Info({
    required this.restaurant,
    required this.open,
    required this.table,
    required this.mode,
    required this.onPickTable,
  });

  final Restaurant restaurant;
  final bool open;
  final RestaurantTable? table;
  final StorefrontMode mode;
  final VoidCallback onPickTable;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final brand = BrandScope.of(context);
    final now = DateTime.now();
    final today = restaurant.workingHours[jsDay(now)];
    final types = [
      if (restaurant.dineInEnabled) OrderType.dineIn,
      if (restaurant.pickupEnabled) OrderType.pickup,
      if (restaurant.deliveryEnabled) OrderType.delivery,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(restaurant.name, style: heading(23, color: p.ink)),
          if (restaurant.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(restaurant.description, style: txt(14, color: p.inkSoft, height: 1.65)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in types) Tag(orderTypeLabel[t]!),
              if (!open)
                Tag(today.closed ? 'مغلق ${dayNames[jsDay(now)]}' : 'يفتح ${ltr(today.open)}', tone: Tone.sumac),
              if (restaurant.minOrder > 0) Tag('الحد الأدنى ${formatMoney(restaurant.minOrder, restaurant.currency)}'),
            ],
          ),
          if (mode == StorefrontMode.operator) ...[
            const SizedBox(height: 12),
            Material(
              color: brand.soft,
              borderRadius: BorderRadius.circular(Radii.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.md),
                onTap: onPickTable,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.table_restaurant_rounded, size: 20, color: brand.brand),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          table != null ? 'تطلب من ${table!.label}' : 'طلب بلا طاولة — اضغط لاختيار طاولة',
                          style: txt(14, color: brand.brand, weight: FontWeight.w700),
                        ),
                      ),
                      Icon(Icons.expand_more_rounded, color: brand.brand),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 15, color: p.inkFaint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'هذا منيوك كما يراه العميل. ما ترسله هنا طلب حقيقي يظهر في شاشة الطلبات.',
                    style: txt(12, color: p.inkFaint, height: 1.5),
                  ),
                ),
                IconButton(
                  tooltip: 'شارك رابط المنيو',
                  onPressed: () => shareText('منيو ${restaurant.name}:\n${AppConfig.menuUrl(restaurant.slug)}'),
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                ),
              ],
            ),
          ] else if (table != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: brand.soft, borderRadius: BorderRadius.circular(Radii.md)),
              child: Row(
                children: [
                  Icon(Icons.table_restaurant_rounded, size: 20, color: brand.brand),
                  const SizedBox(width: 10),
                  Text(
                    'تطلب من ${table!.label}',
                    style: txt(14, color: brand.brand, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ===================== شريط الأقسام ===================== */

class _ChipsHeader extends SliverPersistentHeaderDelegate {
  _ChipsHeader({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: .97),
        border: Border(bottom: BorderSide(color: p.line)),
        boxShadow: overlapsContent || shrinkOffset > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: p.isDark ? .3 : .05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(_ChipsHeader old) => true;
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.sections,
    required this.active,
    required this.controller,
    required this.keyFor,
    required this.onTap,
  });

  final List<MenuSection> sections;
  final String? active;
  final ScrollController controller;
  final GlobalKey Function(String id) keyFor;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final brand = BrandScope.of(context);
    return ListView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      children: [
        for (final s in sections)
          Padding(
            key: keyFor(s.category.id),
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Material(
              color: active == s.category.id ? brand.brand : p.surface2,
              borderRadius: BorderRadius.circular(99),
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => onTap(s.category.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Center(
                    child: Text(
                      s.category.name,
                      style: txt(
                        13.5,
                        color: active == s.category.id ? brand.onBrand : p.inkSoft,
                        weight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/* ===================== الأقسام والأطباق ===================== */

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.section,
    required this.template,
    required this.currency,
    required this.onOpen,
  });

  final MenuSection section;
  final MenuTemplate template;
  final String currency;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dishes = section.dishes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(section.category.name, style: heading(18.5, color: p.ink)),
          const SizedBox(height: 4),
          switch (template) {
            MenuTemplate.classic => Column(
              children: [
                for (final (i, d) in dishes.indexed) ...[
                  if (i > 0) Divider(height: 1, color: p.line),
                  _DishRow(dish: d, currency: currency, onTap: () => onOpen(d.id)),
                ],
              ],
            ),
            MenuTemplate.compact => Column(
              children: [
                for (final (i, d) in dishes.indexed) ...[
                  if (i > 0) Divider(height: 1, color: p.line),
                  _CompactRow(dish: d, currency: currency, onTap: () => onOpen(d.id)),
                ],
              ],
            ),
            MenuTemplate.gallery => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  for (var i = 0; i < dishes.length; i += 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _DishCard(dish: dishes[i], currency: currency, onTap: () => onOpen(dishes[i].id)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: i + 1 < dishes.length
                                  ? _DishCard(
                                      dish: dishes[i + 1],
                                      currency: currency,
                                      onTap: () => onOpen(dishes[i + 1].id),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          },
        ],
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.dish, required this.currency, this.size = 14.5});

  final Dish dish;
  final String currency;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final brand = BrandScope.of(context);
    final soldOut = !dish.isAvailable;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        MoneyText(
          dish.price,
          currency: currency,
          style: heading(size, color: soldOut ? p.inkFaint : brand.brand, weight: FontWeight.w700),
        ),
        if (dish.compareAtPrice != null)
          MoneyText(
            dish.compareAtPrice!,
            currency: currency,
            strike: true,
            style: txt(size - 2, color: p.inkFaint),
          ),
      ],
    );
  }
}

List<Widget> _dishTags(Dish dish) => [
  if (dish.isFeatured && dish.isAvailable) const Tag('الأكثر طلبًا', tone: Tone.saffron, dense: true),
  if (!dish.isAvailable) const Tag('نفد اليوم', tone: Tone.sumac, dense: true),
];

/// صف طبق — القالب الكلاسيكي
class _DishRow extends StatelessWidget {
  const _DishRow({required this.dish, required this.currency, required this.onTap});

  final Dish dish;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final soldOut = !dish.isAvailable;
    final tags = _dishTags(dish);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        dish.name,
                        style: txt(15.5, color: soldOut ? p.inkFaint : p.ink, weight: FontWeight.w700, height: 1.4),
                      ),
                      ...tags,
                    ],
                  ),
                  if (dish.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      dish.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: txt(13, color: p.inkFaint, height: 1.6),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _Price(dish: dish, currency: currency),
                ],
              ),
            ),
            const SizedBox(width: 14),
            DishThumb(name: dish.name, src: dish.imageUrl, size: 84, radius: 16, dim: soldOut),
          ],
        ),
      ),
    );
  }
}

/// سطر مضغوط — أسماء وأسعار بلا صور
class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.dish, required this.currency, required this.onTap});

  final Dish dish;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final soldOut = !dish.isAvailable;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الاسم بعرضه الطبيعي (حتى حدّ)، والنقاط تملأ ما بقي حتى السعر
            LayoutBuilder(
              builder: (context, c) => Row(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: c.maxWidth * .6),
                    child: Text(
                      dish.name,
                      style: txt(15, color: soldOut ? p.inkFaint : p.ink, weight: FontWeight.w700, height: 1.4),
                    ),
                  ),
                  for (final tag in _dishTags(dish)) ...[const SizedBox(width: 6), tag],
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomPaint(size: const Size(double.infinity, 2), painter: _DotsPainter(p.lineStrong)),
                  ),
                  const SizedBox(width: 8),
                  _Price(dish: dish, currency: currency, size: 14.5),
                ],
              ),
            ),
            if (dish.description.isNotEmpty)
              Text(
                dish.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: txt(12.5, color: p.inkFaint, height: 1.6),
              ),
          ],
        ),
      ),
    );
  }
}

/// نقاط تصل الاسم بالسعر — تقليد المنيو المطبوع
class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 0.0; x < size.width; x += 5) {
      canvas.drawCircle(Offset(x, size.height / 2), .9, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

/// بطاقة بصورة كبيرة — قالب المعرض
class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish, required this.currency, required this.onTap});

  final Dish dish;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final soldOut = !dish.isAvailable;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: LayoutBuilder(
              builder: (context, c) =>
                  DishThumb(name: dish.name, src: dish.imageUrl, size: c.maxWidth, radius: 0, dim: soldOut),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: txt(14.5, color: soldOut ? p.inkFaint : p.ink, weight: FontWeight.w700, height: 1.4),
                ),
                if (_dishTags(dish).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(spacing: 4, runSpacing: 4, children: _dishTags(dish)),
                ],
                const SizedBox(height: 6),
                _Price(dish: dish, currency: currency, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
