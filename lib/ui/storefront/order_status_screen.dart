import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/queries.dart';
import '../../data/utils.dart';
import '../../state/nav.dart';
import '../../state/session.dart';
import '../common/basics.dart';
import '../common/buttons.dart';
import 'brand_scope.dart';
import 'cart_screen.dart';
import 'storefront_menu.dart';

const _stepHint = {
  OrderStatus.newOrder: 'وصل طلبك للمطعم',
  OrderStatus.preparing: 'المطبخ يجهّز طلبك',
  OrderStatus.ready: 'طلبك جاهز',
  OrderStatus.completed: 'تم التسليم',
};

/// متابعة الطلب — تتحدّث لحظيًا حين يحرّك الكاشير الطلب
class OrderStatusScreen extends StatefulWidget {
  const OrderStatusScreen({super.key, required this.slug, required this.orderId, required this.mode});

  final String slug;
  final String orderId;
  final StorefrontMode mode;

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // «محدَّث قبل ٣ دقائق» يتحدّث بلا تفاعل
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watchDb();
    final p = context.palette;
    final restaurant = getRestaurantBySlug(db, widget.slug);
    final data = getOrderWithItems(db, widget.orderId);
    final appBar = AppBar(
      title: Text('متابعة الطلب', style: heading(18, color: p.ink)),
    );

    if (restaurant == null || data == null) {
      return Scaffold(
        appBar: appBar,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: EmptyState(
              title: 'لا يوجد طلب بهذا الرقم',
              body: 'قد يكون الطلب محذوفًا أو الرابط خاطئًا.',
              icon: Icons.receipt_long_outlined,
            ),
          ),
        ),
      );
    }

    final order = data.order;
    final cancelled = order.status == OrderStatus.cancelled;
    final current = statusFlow.indexOf(order.status);

    return BrandScope.wrap(
      context,
      restaurant,
      Builder(
        builder: (context) {
          final brand = BrandScope.of(context);
          return Scaffold(
            backgroundColor: p.surface,
            appBar: appBar,
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                Center(child: Eyebrow('رقم طلبك')),
                const SizedBox(height: 4),
                Center(
                  child: Text(ltr('#${order.orderNumber}'), style: heading(50, color: brand.brand, height: 1.1)),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    [orderTypeLabel[order.type], ?order.tableLabel, ltr(formatTime(order.createdAt))].join(' · '),
                    style: txt(14, color: p.inkSoft),
                  ),
                ),
                const SizedBox(height: 24),
                if (cancelled)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: p.sumacTint,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: p.sumac.withValues(alpha: .25)),
                    ),
                    child: Column(
                      children: [
                        Text('أُلغي الطلب', style: heading(17, color: p.sumac)),
                        const SizedBox(height: 4),
                        Text(
                          'تواصل مع المطعم على ${ltr(restaurant.phone)} لمعرفة السبب.',
                          textAlign: TextAlign.center,
                          style: txt(13.5, color: p.sumac),
                        ),
                      ],
                    ),
                  )
                else
                  for (final (index, step) in statusFlow.indexed)
                    _Step(
                      label: orderStatusLabel[step]!,
                      hint: _stepHint[step]!,
                      index: index,
                      reached: index <= current,
                      current: index == current,
                      last: index == statusFlow.length - 1,
                      lineFilled: index < current,
                      updated: index == current ? 'محدَّث ${timeAgo(order.updatedAt)}' : null,
                    ),
                const SizedBox(height: 22),
                BillCard(
                  currency: order.currency,
                  header: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'تفاصيل الطلب',
                          style: txt(14.5, color: p.ink, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        for (final item in data.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '${ltr('${item.item.qty}×')} ',
                                              style: txt(14, weight: FontWeight.w700),
                                            ),
                                            TextSpan(text: item.item.dishName),
                                          ],
                                        ),
                                        style: txt(14, color: p.ink),
                                      ),
                                      if (item.options.isNotEmpty)
                                        Text(
                                          item.options.map((o) => o.optionName).join(' · '),
                                          style: txt(12.5, color: p.inkFaint),
                                        ),
                                      if (item.item.note.isNotEmpty)
                                        Text('ملاحظة: ${item.item.note}', style: txt(12.5, color: p.inkSoft)),
                                    ],
                                  ),
                                ),
                                MoneyText(
                                  item.item.lineTotal,
                                  currency: order.currency,
                                  style: txt(14, color: p.ink),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        Divider(height: 1, color: p.line),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                  rows: [
                    ('المجموع', order.subtotal),
                    if (order.taxAmount > 0) ('الضريبة', order.taxAmount),
                    if (order.deliveryFee > 0) ('التوصيل', order.deliveryFee),
                  ],
                  total: order.total,
                  footnote: [
                    if (order.note.isNotEmpty) 'ملاحظتك: ${order.note}',
                    if (order.address.isNotEmpty) 'العنوان: ${order.address}',
                  ].join('\n').ifEmpty(null),
                ),
                const SizedBox(height: 18),
                if (restaurant.phone.isNotEmpty)
                  AppButton(
                    label: 'اتصل بالمطعم  ${ltr(restaurant.phone)}',
                    icon: Icons.call_rounded,
                    expand: true,
                    onPressed: () => launchUrl(Uri.parse('tel:${restaurant.phone}')),
                  ),
                const SizedBox(height: 10),
                if (widget.mode == StorefrontMode.operator)
                  AppButton(
                    label: 'افتح شاشة الطلبات',
                    icon: Icons.receipt_long_rounded,
                    tone: BtnTone.primary,
                    expand: true,
                    brand: brand.brand,
                    onBrand: brand.onBrand,
                    onPressed: () {
                      final nav = context.read<NavState>();
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      nav.open(ToolId.orders);
                    },
                  )
                else
                  AppButton(
                    label: 'اطلب مرة أخرى',
                    icon: Icons.restaurant_menu_rounded,
                    tone: BtnTone.primary,
                    expand: true,
                    brand: brand.brand,
                    onBrand: brand.onBrand,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                const SizedBox(height: 14),
                Text(
                  'حالة الطلب تتحدّث هنا تلقائيًا.',
                  textAlign: TextAlign.center,
                  style: txt(12.5, color: p.inkFaint),
                ),
                if (order.status == OrderStatus.newOrder) ...[
                  const SizedBox(height: 10),
                  const Center(child: Tag('في انتظار تأكيد المطعم', tone: Tone.saffron)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

extension on String {
  String? ifEmpty(String? fallback) => isEmpty ? fallback : this;
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.hint,
    required this.index,
    required this.reached,
    required this.current,
    required this.last,
    required this.lineFilled,
    this.updated,
  });

  final String label;
  final String hint;
  final int index;
  final bool reached;
  final bool current;
  final bool last;
  final bool lineFilled;
  final String? updated;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final brand = BrandScope.of(context);
    final dot = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: reached ? brand.brand : Colors.transparent,
        border: Border.all(color: reached ? brand.brand : p.lineStrong, width: 2),
      ),
      child: reached
          ? Icon(Icons.check_rounded, size: 17, color: brand.onBrand)
          : Text(
              ltr('${index + 1}'),
              style: txt(12.5, color: p.inkFaint, weight: FontWeight.w700, height: 1),
            ),
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              if (current) _Glow(color: brand.brand, child: dot) else dot,
              if (!last)
                Expanded(
                  child: Container(
                    width: 2.5,
                    constraints: const BoxConstraints(minHeight: 28),
                    color: lineFilled ? brand.brand : p.line,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 22, top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: txt(15, color: reached ? p.ink : p.inkFaint, weight: FontWeight.w700),
                  ),
                  Text(hint, style: txt(12.5, color: p.inkFaint)),
                  if (updated != null)
                    Text(
                      updated!,
                      style: txt(12.5, color: brand.brand, weight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// نبض حول الخطوة الحالية — مثل anim-alert في الموقع
class _Glow extends StatefulWidget {
  const _Glow({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  State<_Glow> createState() => _GlowState();
}

class _GlowState extends State<_Glow> with SingleTickerProviderStateMixin {
  /// تُنشأ في initState لا عند أول استخدام: مع «إزالة الحركة» لا يلمسها build،
  /// فكانت ستُنشأ أول مرة داخل dispose وتطلب مؤقّتًا من شجرة لم تعد نشطة.
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // لا نبض — ولا إطارات تُرسم بلا داعٍ — حين يلغي المستخدم الحركة من إعدادات الجهاز
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: .45 * (1 - _c.value)),
              spreadRadius: 10 * _c.value,
            ),
          ],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}
