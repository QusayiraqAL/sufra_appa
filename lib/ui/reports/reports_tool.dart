import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/arabic.dart';
import '../../data/models.dart';
import '../../data/queries.dart';
import '../../data/utils.dart';
import '../../state/session.dart';
import '../common/basics.dart';
import '../common/inputs.dart';
import 'charts.dart';

/// التقارير — مقابل /dashboard/reports في الموقع
class ReportsTool extends StatefulWidget {
  const ReportsTool({super.key});

  @override
  State<ReportsTool> createState() => _ReportsToolState();
}

class _ReportsToolState extends State<ReportsTool> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    return RestaurantBuilder(
      builder: (context, db, restaurant, profile) {
        final p = context.palette;
        final stats = reportStats(db, restaurant.id, _days);
        final currency = restaurant.currency;

        final typeItems = [
          for (final t in OrderType.values)
            if (stats.byType[t]!.revenue > 0 || stats.orders == 0)
              BarItem(
                label: orderTypeLabel[t]!,
                value: stats.byType[t]!.revenue,
                note: countOf(stats.byType[t]!.orders, nOrder),
              ),
        ]..sort((a, b) => b.value.compareTo(a.value));

        final byRevenue = [...stats.topDishes]..sort((a, b) => b.revenue.compareTo(a.revenue));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Text(
              'الطلبات الملغاة غير محسوبة في الإيراد',
              style: txt(12.5, color: p.inkFaint, weight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Segmented<int>(
              label: 'فترة التقرير',
              value: _days,
              onChanged: (d) => setState(() => _days = d),
              options: const [(7, '٧ أيام'), (14, '١٤ يومًا'), (30, '٣٠ يومًا')],
            ),
            const SizedBox(height: 14),
            StatGrid(
              children: [
                StatTile(
                  label: 'الإيراد',
                  value: MoneyText(stats.revenue, currency: currency),
                  tone: Tone.basil,
                  icon: Icons.payments_outlined,
                ),
                StatTile(label: 'الطلبات', value: Text(ltr('${stats.orders}')), icon: Icons.receipt_long_outlined),
                StatTile(
                  label: 'متوسط قيمة الطلب',
                  value: MoneyText(stats.avgOrder, currency: currency),
                  icon: Icons.functions_rounded,
                ),
                StatTile(
                  label: 'أكثر ساعة ازدحامًا',
                  value: Text(
                    stats.busiestHour == null ? '—' : ltr('${stats.busiestHour.toString().padLeft(2, '0')}:00'),
                  ),
                  tone: Tone.saffron,
                  sub: stats.cancelled > 0 ? 'الملغاة في الفترة: ${ltr('${stats.cancelled}')}' : null,
                  icon: Icons.schedule_rounded,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ColumnChart(
                    title: 'الإيراد اليومي — آخر $_days يومًا',
                    currency: currency,
                    emptyLabel: 'لا مبيعات في هذه الفترة بعد.',
                    points: [
                      for (final day in stats.daily)
                        ColumnPoint(
                          label: day.label,
                          value: day.revenue,
                          meta: day.orders > 0 ? countOf(day.orders, nOrder) : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'الزمن يجري من اليمين لليسار: الأقدم يمينًا واليوم يسارًا. اضغط عمودًا لتفاصيله.',
                    style: txt(11.5, color: p.inkFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SurfaceCard(
              child: BarList(
                title: 'أكثر الأطباق طلبًا',
                items: [for (final d in stats.topDishes) BarItem(label: d.name, value: d.qty.toDouble())],
                unitLabel: 'مرة',
                noun: nTime,
                currency: currency,
                emptyLabel: 'لا طلبات في هذه الفترة.',
              ),
            ),
            const SizedBox(height: 14),
            SurfaceCard(
              child: BarList(
                title: 'الإيراد حسب نوع الطلب',
                items: typeItems,
                unitLabel: 'إيراد',
                currency: currency,
                showMoney: true,
                emptyLabel: 'لا طلبات في هذه الفترة.',
              ),
            ),
            const SizedBox(height: 14),
            SurfaceCard(
              child: BarList(
                title: 'أعلى الأطباق إيرادًا',
                items: [for (final d in byRevenue) BarItem(label: d.name, value: d.revenue)],
                unitLabel: 'إيراد',
                currency: currency,
                showMoney: true,
                emptyLabel: 'لا طلبات في هذه الفترة.',
              ),
            ),
          ],
        );
      },
    );
  }
}
