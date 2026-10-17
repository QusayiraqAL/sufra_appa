import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/export.dart';
import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../data/arabic.dart';
import '../../data/models.dart';
import '../../data/mutations.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../../data/utils.dart';
import '../../state/nav.dart';
import '../../state/session.dart';
import '../common/basics.dart';
import '../common/buttons.dart';
import '../orders/orders_tool.dart';

/// نظرة عامة — لوحة اليوم لصاحب المطعم (مقابل /dashboard في الموقع)
class OverviewTool extends StatefulWidget {
  const OverviewTool({super.key});

  @override
  State<OverviewTool> createState() => _OverviewToolState();
}

class _OverviewToolState extends State<OverviewTool> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RestaurantBuilder(
      builder: (context, db, restaurant, profile) {
        final p = context.palette;
        final nav = context.read<NavState>();
        final stats = todayStats(db, restaurant.id);
        final open = isOpenNow(restaurant.workingHours);
        final unavailable = getUnavailableDishes(db, restaurant.id);
        final recent = getOrdersWithItems(db, restaurant.id).take(6).toList();
        final url = AppConfig.menuUrl(restaurant.slug);

        final setup = [
          (countDishes(db, restaurant.id) >= 3, 'أضف ٣ أطباق على الأقل', ToolId.menu),
          (getMenu(db, restaurant.id).length >= 2, 'أنشئ قسمين أو أكثر', ToolId.menu),
          (restaurant.logoUrl != null, 'ارفع لوجو المطعم', ToolId.settings),
          (
            !restaurant.dineInEnabled || getTables(db, restaurant.id).isNotEmpty,
            'أضف طاولاتك واطبع رموزها',
            ToolId.tables,
          ),
        ];
        final pending = setup.where((s) => !s.$1).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('لوحة التحكم'),
                      Text(restaurant.name, style: heading(23, color: p.ink)),
                    ],
                  ),
                ),
                Tag(open ? 'مفتوح الآن' : 'مغلق الآن', tone: open ? Tone.basil : Tone.sumac, icon: Icons.circle),
              ],
            ),
            const SizedBox(height: 16),
            StatGrid(
              children: [
                StatTile(label: 'طلبات اليوم', value: Text(ltr('${stats.orders}')), icon: Icons.receipt_long_rounded),
                StatTile(
                  label: 'مبيعات اليوم',
                  value: MoneyText(stats.revenue, currency: restaurant.currency),
                  tone: Tone.basil,
                  icon: Icons.payments_outlined,
                ),
                StatTile(
                  label: 'قيد التجهيز',
                  value: Text(ltr('${stats.open}')),
                  tone: stats.open > 0 ? Tone.ember : Tone.neutral,
                  sub: stats.open > 0 ? 'تحتاج متابعة' : 'لا شيء معلّق',
                  icon: Icons.soup_kitchen_outlined,
                ),
                StatTile(
                  label: 'جاهز للتسليم',
                  value: Text(ltr('${stats.ready}')),
                  tone: stats.ready > 0 ? Tone.saffron : Tone.neutral,
                  icon: Icons.room_service_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Eyebrow('رابط المنيو'),
                  const SizedBox(height: 4),
                  Text(
                    url,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: txt(14, color: p.ink, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _QuickAction(
                        icon: Icons.copy_rounded,
                        label: 'انسخ',
                        onTap: () async {
                          await copyText(url);
                          toast('نُسخ الرابط');
                        },
                      ),
                      const SizedBox(width: 8),
                      _QuickAction(
                        icon: Icons.ios_share_rounded,
                        label: 'شارك',
                        onTap: () => shareText('منيو ${restaurant.name}:\n$url'),
                      ),
                      const SizedBox(width: 8),
                      _QuickAction(
                        icon: Icons.qr_code_2_rounded,
                        label: 'رموز QR',
                        onTap: () => nav.open(ToolId.tables),
                      ),
                      const SizedBox(width: 8),
                      _QuickAction(
                        icon: Icons.storefront_rounded,
                        label: 'افتح',
                        primary: true,
                        onTap: () => nav.open(ToolId.storefront),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (pending > 0) ...[
              const SizedBox(height: 14),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('أكمل إعداد مطعمك', style: heading(16, color: p.ink)),
                        ),
                        Text(
                          ltr('${setup.length - pending}/${setup.length}'),
                          style: txt(13, color: p.inkFaint, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: LinearProgressIndicator(
                        value: (setup.length - pending) / setup.length,
                        minHeight: 6,
                        backgroundColor: p.surface2,
                        color: p.basil,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final (done, label, tool) in setup)
                      InkWell(
                        borderRadius: BorderRadius.circular(Radii.sm),
                        onTap: done ? null : () => nav.open(tool),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done ? p.basilTint : Colors.transparent,
                                  border: Border.all(color: done ? p.basilTint : p.lineStrong, width: 1.5),
                                ),
                                child: done ? Icon(Icons.check_rounded, size: 14, color: p.basil) : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  label,
                                  style: txt(
                                    14,
                                    color: done ? p.inkFaint : p.ink,
                                    weight: done ? FontWeight.w400 : FontWeight.w600,
                                  ).copyWith(decoration: done ? TextDecoration.lineThrough : null),
                                ),
                              ),
                              if (!done) Icon(Icons.chevron_right_rounded, color: p.inkFaint),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            SectionTitle(
              'أحدث الطلبات',
              trailing: TextButton(onPressed: () => nav.open(ToolId.orders), child: const Text('كل الطلبات')),
            ),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              const EmptyState(
                title: 'ما وصل طلب بعد',
                body: 'افتح «منيو العميل» وجرّب إرسال طلب لترى كيف يظهر هنا.',
                icon: Icons.receipt_long_outlined,
              )
            else
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (i, order) in recent.indexed) ...[
                      if (i > 0) Divider(height: 1, color: p.line),
                      InkWell(
                        onTap: () => showOrderDetail(context, order.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          ltr('#${order.order.orderNumber}'),
                                          style: heading(15, color: p.ink, weight: FontWeight.w700),
                                        ),
                                        const SizedBox(width: 8),
                                        Tag(
                                          orderStatusLabel[order.status]!,
                                          tone: switch (order.status) {
                                            OrderStatus.newOrder => Tone.saffron,
                                            OrderStatus.preparing => Tone.ember,
                                            OrderStatus.ready => Tone.basil,
                                            OrderStatus.cancelled => Tone.sumac,
                                            OrderStatus.completed => Tone.neutral,
                                          },
                                          dense: true,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        orderTypeLabel[order.order.type],
                                        ?order.order.tableLabel,
                                        countOf(order.items.length, nItem),
                                        timeAgo(order.order.createdAt),
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: txt(12.5, color: p.inkSoft),
                                    ),
                                  ],
                                ),
                              ),
                              MoneyText(
                                order.order.total,
                                currency: order.order.currency,
                                style: txt(14, color: p.ink),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 22),
            SectionTitle(
              'نفد اليوم',
              trailing: TextButton(onPressed: () => nav.open(ToolId.menu), child: const Text('المنيو')),
            ),
            const SizedBox(height: 8),
            if (unavailable.isEmpty)
              SurfaceCard(
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: p.basil),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('كل الأطباق متوفّرة. لا شيء يحتاج انتباهك.', style: txt(14, color: p.inkSoft)),
                    ),
                  ],
                ),
              )
            else
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (i, dish) in unavailable.indexed) ...[
                      if (i > 0) Divider(height: 1, color: p.line),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            DishThumb(name: dish.name, src: dish.imageUrl, size: 40, radius: 10, dim: true),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                dish.name,
                                style: txt(14.5, color: p.ink, weight: FontWeight.w600),
                              ),
                            ),
                            AppButton(
                              label: 'أعِده',
                              size: BtnSize.sm,
                              tone: BtnTone.success,
                              onPressed: () {
                                context.read<DataStore>().toggleDishAvailable(dish.id);
                                toast('عاد «${dish.name}» للمنيو');
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// زر إجراء مدمج: أيقونة فوق عنوان — أربعة منها تتسع في صف واحد على الجوال
class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap, this.primary = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = primary ? p.onSaffron : p.ink;
    return Expanded(
      child: Material(
        color: primary ? p.saffron : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: primary ? Colors.transparent : p.lineStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Icon(icon, size: 21, color: fg),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  style: txt(12.5, color: fg, weight: FontWeight.w600, height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
