import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/mutations.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../../data/utils.dart';
import '../../state/nav.dart';
import '../../state/prefs.dart';
import '../../state/session.dart';
import '../common/basics.dart';
import '../common/buttons.dart';
import '../common/sheets.dart';
import 'receipt.dart';

const _columns = [OrderStatus.newOrder, OrderStatus.preparing, OrderStatus.ready, OrderStatus.completed];

/// حدود التأخّر بالدقائق قبل التلوين — نفس قيم الموقع
const _lateWarn = 12;
const _lateBad = 25;

Tone _statusTone(OrderStatus s) => switch (s) {
  OrderStatus.newOrder => Tone.saffron,
  OrderStatus.preparing => Tone.ember,
  OrderStatus.ready => Tone.basil,
  OrderStatus.completed => Tone.neutral,
  OrderStatus.cancelled => Tone.sumac,
};

/// شاشة الطلبات — تتحدّث لحظيًا. على الجوال: تبويبات تُسحب بين المراحل؛
/// على الجهاز اللوحي: أربعة أعمدة جنبًا إلى جنب كشاشة المطبخ.
class OrdersTool extends StatefulWidget {
  const OrdersTool({super.key});

  @override
  State<OrdersTool> createState() => _OrdersToolState();
}

class _OrdersToolState extends State<OrdersTool> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Timer? _ticker;
  late final AppPrefs _prefs = context.read<AppPrefs>();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _columns.length, vsync: this);
    // «قبل ٣ دقائق» وتلوين التأخّر يتحدّثان بلا تفاعل
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
    _prefs.addListener(_applyWakelock);
    _applyWakelock();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tabs.dispose();
    _prefs.removeListener(_applyWakelock);
    _setWakelock(false);
    super.dispose();
  }

  void _applyWakelock() => _setWakelock(_prefs.keepAwake);

  Future<void> _setWakelock(bool on) async {
    try {
      await (on ? WakelockPlus.enable() : WakelockPlus.disable());
    } catch (_) {
      // منصة لا تدعم إبقاء الشاشة — لا بأس
    }
  }

  @override
  Widget build(BuildContext context) {
    return RestaurantBuilder(
      builder: (context, db, restaurant, profile) {
        final orders = getOrdersWithItems(db, restaurant.id);
        final grouped = {for (final s in _columns) s: orders.where((o) => o.status == s).toList()};
        final cancelled = orders.where((o) => o.status == OrderStatus.cancelled).toList();
        final wide = MediaQuery.sizeOf(context).width >= 900;

        final header = _Controls(cancelled: cancelled, restaurant: restaurant);

        if (orders.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              header,
              const SizedBox(height: 12),
              EmptyState(
                title: 'ما وصل طلب بعد',
                body: 'افتح «منيو العميل» وأرسل طلبًا تجريبيًا — سيظهر هنا فورًا مع تنبيه صوتي.',
                icon: Icons.receipt_long_outlined,
                action: AppButton(
                  label: 'افتح منيو العميل',
                  icon: Icons.storefront_rounded,
                  tone: BtnTone.primary,
                  onPressed: () => context.read<NavState>().open(ToolId.storefront),
                ),
              ),
            ],
          );
        }

        if (wide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, s) in _columns.indexed) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(
                          child: _Column(status: s, orders: grouped[s]!, restaurant: restaurant, showHeader: true),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final p = context.palette;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: header),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(color: p.saffron, borderRadius: BorderRadius.circular(99)),
              labelColor: p.onSaffron,
              unselectedLabelColor: p.inkSoft,
              labelStyle: txt(13.5, weight: FontWeight.w700),
              unselectedLabelStyle: txt(13.5, weight: FontWeight.w600),
              splashBorderRadius: BorderRadius.circular(99),
              onTap: (_) => HapticFeedback.selectionClick(),
              tabs: [
                for (final s in _columns)
                  Tab(
                    height: 38,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Text(orderStatusLabel[s]!),
                          const SizedBox(width: 6),
                          Text(ltr('${grouped[s]!.length}'), style: const TextStyle(fontFeatures: tabular)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [for (final s in _columns) _Column(status: s, orders: grouped[s]!, restaurant: restaurant)],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// أزرار أعلى الشاشة: التنبيه، إبقاء الشاشة مضاءة، الملغاة، طلب جديد
class _Controls extends StatelessWidget {
  const _Controls({required this.cancelled, required this.restaurant});

  final List<OrderWithItems> cancelled;
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPrefs>();
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Pill(
                icon: prefs.chimeEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                label: prefs.chimeEnabled ? 'التنبيه مفعّل' : 'التنبيه مطفأ',
                active: prefs.chimeEnabled,
                onTap: () {
                  prefs.chimeEnabled = !prefs.chimeEnabled;
                  toast(prefs.chimeEnabled ? 'التنبيه الصوتي مفعّل' : 'أُطفئ التنبيه الصوتي');
                },
              ),
              const SizedBox(width: 8),
              _Pill(
                icon: prefs.keepAwake ? Icons.light_mode_rounded : Icons.light_mode_outlined,
                label: prefs.keepAwake ? 'الشاشة مضاءة' : 'أبقِ الشاشة مضاءة',
                active: prefs.keepAwake,
                onTap: () {
                  prefs.keepAwake = !prefs.keepAwake;
                  toast(prefs.keepAwake ? 'ستبقى الشاشة مضاءة ما دامت الطلبات مفتوحة' : 'عادت الشاشة لإطفائها المعتاد');
                },
              ),
              if (cancelled.isNotEmpty) ...[
                const SizedBox(width: 8),
                _Pill(
                  icon: Icons.block_rounded,
                  label: 'الملغاة (${cancelled.length})',
                  onTap: () => _showCancelled(context, cancelled, restaurant),
                ),
              ],
              const SizedBox(width: 8),
              _Pill(
                icon: Icons.add_rounded,
                label: 'طلب جديد',
                onTap: () => context.read<NavState>().open(ToolId.storefront),
              ),
            ],
          ),
        ),
        if (!prefs.chimeEnabled) ...[
          const SizedBox(height: 10),
          Text(
            'التنبيه الصوتي مطفأ — لن تسمع الطلبات الجديدة. شغّله من الزر أعلاه.',
            style: txt(12.5, color: p.ember, weight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onTap, this.active = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: active ? p.basilTint : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(99),
        side: BorderSide(color: active ? p.basil.withValues(alpha: .35) : p.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: active ? p.basil : p.inkSoft),
              const SizedBox(width: 6),
              Text(
                label,
                style: txt(13, color: active ? p.basil : p.ink, weight: FontWeight.w600, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.status, required this.orders, required this.restaurant, this.showHeader = false});

  final OrderStatus status;
  final List<OrderWithItems> orders;
  final Restaurant restaurant;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(orderStatusLabel[status]!, style: heading(15.5, color: p.ink)),
                const SizedBox(width: 8),
                Tag(ltr('${orders.length}'), tone: orders.isEmpty ? Tone.neutral : _statusTone(status), dense: true),
              ],
            ),
          ),
        Expanded(
          child: orders.isEmpty
              ? ListView(
                  padding: EdgeInsets.fromLTRB(showHeader ? 0 : 16, 8, showHeader ? 0 : 16, 16),
                  children: [
                    CustomPaint(
                      painter: DashedBorderPainter(color: p.line, radius: Radii.md),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'لا شيء هنا',
                          textAlign: TextAlign.center,
                          style: txt(13, color: p.inkFaint),
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(showHeader ? 0 : 16, 8, showHeader ? 0 : 16, 24),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => OrderCard(order: orders[i], restaurant: restaurant),
                ),
        ),
      ],
    );
  }
}

/* ===================== بطاقة طلب ===================== */

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.restaurant});

  final OrderWithItems order;
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final o = order.order;
    final mins = minutesSince(o.createdAt);
    final stale = o.status == OrderStatus.newOrder || o.status == OrderStatus.preparing;
    final lateness = stale && mins >= _lateBad
        ? 2
        : stale && mins >= _lateWarn
        ? 1
        : 0;
    final next = nextStatus(o.status);
    final border = switch (lateness) {
      2 => p.sumac.withValues(alpha: .6),
      1 => p.ember.withValues(alpha: .6),
      _ => o.status == OrderStatus.newOrder ? p.saffron.withValues(alpha: .5) : p.line,
    };
    final timeColor = switch (lateness) {
      2 => p.sumac,
      1 => p.ember,
      _ => p.inkFaint,
    };

    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: border, width: lateness > 0 || o.status == OrderStatus.newOrder ? 1.4 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => showOrderDetail(context, order.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // سطر واحد عادةً: الرقم والوسم في جهة والوقت في الأخرى. بخط الجوال
                  // المكبّر ينزل الوقت لسطر ثانٍ بدل أن يُقصّ شيء.
                  _SpreadLine(
                    start: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(ltr('#${o.orderNumber}'), style: heading(19, color: p.ink)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Tag(
                            o.tableLabel ?? orderTypeLabel[o.type]!,
                            tone: o.type == OrderType.dineIn ? Tone.saffron : Tone.neutral,
                            icon: switch (o.type) {
                              OrderType.dineIn => Icons.table_restaurant_rounded,
                              OrderType.pickup => Icons.shopping_bag_outlined,
                              OrderType.delivery => Icons.delivery_dining_rounded,
                            },
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                    end: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: timeColor),
                        const SizedBox(width: 3),
                        Text(
                          timeAgo(o.createdAt),
                          style: txt(12, color: timeColor, weight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in order.items.take(3))
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${ltr('${item.item.qty}×')} ',
                            style: txt(13.5, color: p.ink, weight: FontWeight.w700),
                          ),
                          TextSpan(text: item.item.dishName),
                          if (item.options.isNotEmpty)
                            TextSpan(
                              text: ' · ${item.options.map((x) => x.optionName).join('، ')}',
                              style: txt(12.5, color: p.inkFaint),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: txt(13.5, color: p.inkSoft, height: 1.6),
                    ),
                  if (order.items.length > 3)
                    Text('+ ${order.items.length - 3} أخرى', style: txt(12.5, color: p.inkFaint)),
                  if (o.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: p.saffronTint, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        o.note,
                        style: txt(12.5, color: p.saffron, weight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _SpreadLine(
                    start: MoneyText(
                      o.total,
                      currency: restaurant.currency,
                      style: txt(15, color: p.ink, weight: FontWeight.w700),
                    ),
                    end: o.customerPhone.isEmpty ? null : Text(ltr(o.customerPhone), style: txt(12, color: p.inkFaint)),
                  ),
                ],
              ),
            ),
          ),
          if (next != null)
            Material(
              color: o.status == OrderStatus.ready ? p.basil : p.saffron,
              child: InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.read<DataStore>().setOrderStatus(o.id, next);
                },
                child: SizedBox(
                  height: 46,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 19,
                        color: o.status == OrderStatus.ready ? p.surface : p.onSaffron,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        orderStatusLabel[next]!,
                        style: txt(
                          14.5,
                          color: o.status == OrderStatus.ready ? p.surface : p.onSaffron,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// سطر بطرفين: [start] في جهة و[end] في الأخرى. حين لا يتّسعان معًا (خط الجوال
/// المكبّر) ينزل [end] لسطر ثانٍ بدل أن يتجاوز حدود البطاقة.
class _SpreadLine extends StatelessWidget {
  const _SpreadLine({required this.start, this.end});

  final Widget start;
  final Widget? end;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [start, ?end],
    ),
  );
}

/* ===================== تفاصيل الطلب ===================== */

/// لوح تفاصيل الطلب. يقرأ الطلب من المخزن في كل عرض، فيبقى محدّثًا.
Future<void> showOrderDetail(BuildContext context, String orderId) {
  final store = context.read<DataStore>();
  final initial = getOrderWithItems(store.db, orderId);
  if (initial == null) return Future.value();
  return showAppSheet<void>(
    context,
    title: 'طلب ${ltr('#${initial.order.orderNumber}')}',
    subtitle:
        '${orderTypeLabel[initial.order.type]}${initial.order.tableLabel != null ? ' · ${initial.order.tableLabel}' : ''} · ${ltr(formatTime(initial.order.createdAt))}',
    builder: (c) => _OrderDetailBody(orderId: orderId),
    footer: (c) => _OrderDetailActions(orderId: orderId),
  );
}

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final db = context.watchDb();
    final data = getOrderWithItems(db, orderId);
    final p = context.palette;
    if (data == null) return const SizedBox.shrink();
    final o = data.order;

    Widget info(String label, Widget value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Eyebrow(label), const SizedBox(height: 2), value],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Tag(orderTypeLabel[o.type]!, tone: Tone.saffron),
            if (o.tableLabel != null) Tag(o.tableLabel!),
            Tag(orderStatusLabel[o.status]!, tone: _statusTone(o.status)),
            Tag(
              '${o.paymentStatus == PaymentStatus.paid ? 'مدفوع' : 'غير مدفوع'} · كاش',
              tone: o.paymentStatus == PaymentStatus.paid ? Tone.basil : Tone.ember,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: info('الوقت', Text(ltr(formatTime(o.createdAt)), style: txt(14.5, color: p.ink))),
            ),
            Expanded(
              child: info('مضى', Text(timeAgo(o.createdAt), style: txt(14.5, color: p.ink))),
            ),
          ],
        ),
        if (o.customerName.isNotEmpty || o.customerPhone.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (o.customerName.isNotEmpty)
                Expanded(
                  child: info('العميل', Text(o.customerName, style: txt(14.5, color: p.ink))),
                ),
              if (o.customerPhone.isNotEmpty)
                Expanded(
                  child: info(
                    'الجوال',
                    InkWell(
                      onTap: () => launchUrl(Uri.parse('tel:${o.customerPhone}')),
                      child: Row(
                        children: [
                          Icon(Icons.call_rounded, size: 15, color: p.saffron),
                          const SizedBox(width: 4),
                          Text(
                            ltr(o.customerPhone),
                            style: txt(14.5, color: p.saffron, weight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (o.address.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Eyebrow('العنوان'),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.surface2.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: p.line),
            ),
            child: Text(o.address, style: txt(14, color: p.ink, height: 1.7)),
          ),
        ],
        if (o.note.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Eyebrow('ملاحظة العميل'),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.saffronTint,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: p.saffron.withValues(alpha: .25)),
            ),
            child: Text(
              o.note,
              style: txt(14, color: p.saffron, weight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Eyebrow('البنود'),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: p.line),
          ),
          child: Column(
            children: [
              for (final (i, item) in data.items.indexed) ...[
                if (i > 0) Divider(height: 1, color: p.line),
                Padding(
                  padding: const EdgeInsets.all(12),
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
                                  TextSpan(text: '${ltr('${item.item.qty}×')} '),
                                  TextSpan(text: item.item.dishName),
                                ],
                              ),
                              style: txt(14.5, color: p.ink, weight: FontWeight.w600),
                            ),
                            if (item.options.isNotEmpty)
                              Text(
                                item.options
                                    .map(
                                      (op) =>
                                          op.optionName +
                                          (op.priceDelta != 0
                                              ? ' (${ltr('${op.priceDelta > 0 ? '+' : '−'}${formatNumber(op.priceDelta.abs())}')})'
                                              : ''),
                                    )
                                    .join(' · '),
                                style: txt(12.5, color: p.inkFaint),
                              ),
                            if (item.item.note.isNotEmpty)
                              Text(
                                'ملاحظة: ${item.item.note}',
                                style: txt(12.5, color: p.ember, weight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                      MoneyText(
                        item.item.lineTotal,
                        currency: o.currency,
                        style: txt(14, color: p.ink),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.surface2.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: p.line),
          ),
          child: Column(
            children: [
              _TotalRow('المجموع', o.subtotal, o.currency),
              if (o.taxAmount > 0) _TotalRow('الضريبة', o.taxAmount, o.currency),
              if (o.deliveryFee > 0) _TotalRow('التوصيل', o.deliveryFee, o.currency),
              Divider(height: 14, color: p.line),
              _TotalRow('الإجمالي', o.total, o.currency, bold: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, this.currency, {this.bold = false});

  final String label;
  final double value;
  final String currency;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = bold ? heading(16.5, color: p.ink) : txt(14, color: p.inkSoft);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          MoneyText(
            value,
            currency: currency,
            style: bold ? style : txt(14, color: p.ink),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailActions extends StatelessWidget {
  const _OrderDetailActions({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final db = context.watchDb();
    final data = getOrderWithItems(db, orderId);
    if (data == null) return const SizedBox.shrink();
    final o = data.order;
    final next = nextStatus(o.status);
    final restaurantName = getRestaurantById(db, o.restaurantId)?.name ?? '';
    final store = context.read<DataStore>();
    final canCancel = o.status != OrderStatus.cancelled && o.status != OrderStatus.completed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next != null) ...[
          AppButton(
            label: 'انقله إلى «${orderStatusLabel[next]}»',
            icon: Icons.check_circle_rounded,
            tone: BtnTone.primary,
            expand: true,
            onPressed: () {
              HapticFeedback.mediumImpact();
              store.setOrderStatus(o.id, next);
              Navigator.pop(context);
              toast('صار «${orderStatusLabel[next]}»');
            },
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'اطبع',
                icon: Icons.print_rounded,
                size: BtnSize.sm,
                onPressed: () => printReceipt(data, restaurantName),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: 'شارك',
                icon: Icons.ios_share_rounded,
                size: BtnSize.sm,
                onPressed: () => shareReceipt(data, restaurantName),
              ),
            ),
            if (canCancel) ...[
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'ألغِ',
                  icon: Icons.block_rounded,
                  size: BtnSize.sm,
                  tone: BtnTone.danger,
                  onPressed: () {
                    final previous = o.status;
                    store.setOrderStatus(o.id, OrderStatus.cancelled);
                    Navigator.pop(context);
                    // التراجع بدل نافذة التأكيد: الإلغاء قابل للعكس، والنقرة الخاطئة تُصلح بضغطة
                    toastUndo('أُلغي الطلب ${ltr('#${o.orderNumber}')}', () => store.setOrderStatus(o.id, previous));
                  },
                ),
              ),
            ],
            if (o.status == OrderStatus.cancelled) ...[
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'أعِده',
                  icon: Icons.restore_rounded,
                  size: BtnSize.sm,
                  onPressed: () {
                    store.setOrderStatus(o.id, OrderStatus.newOrder);
                    Navigator.pop(context);
                    toast('عاد الطلب إلى «جديد»');
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

Future<void> _showCancelled(BuildContext context, List<OrderWithItems> initial, Restaurant restaurant) {
  return showAppSheet<void>(
    context,
    title: 'الطلبات الملغاة',
    builder: (c) {
      final db = c.watchDb();
      final p = c.palette;
      final cancelled = getOrdersByStatus(db, restaurant.id, OrderStatus.cancelled);
      if (cancelled.isEmpty) {
        return const EmptyState(title: 'لا طلبات ملغاة', icon: Icons.check_circle_outline_rounded);
      }
      return Column(
        children: [
          for (final order in cancelled)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => showOrderDetail(c, order.id),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ltr('#${order.order.orderNumber}'),
                            style: txt(15, color: p.ink, weight: FontWeight.w700),
                          ),
                          Text(
                            '${orderTypeLabel[order.order.type]} · ${ltr(formatTime(order.order.createdAt))}',
                            style: txt(12.5, color: p.inkFaint),
                          ),
                        ],
                      ),
                    ),
                  ),
                  MoneyText(
                    order.order.total,
                    currency: order.order.currency,
                    style: txt(14, color: p.ink),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'أعِده',
                    size: BtnSize.sm,
                    onPressed: () {
                      c.read<DataStore>().setOrderStatus(order.id, OrderStatus.newOrder);
                      toast('عاد الطلب ${ltr('#${order.order.orderNumber}')} إلى «جديد»');
                    },
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
