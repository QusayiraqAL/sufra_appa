import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/arabic.dart';
import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../data/mutations.dart';
import '../../data/store.dart';
import '../../data/utils.dart';
import '../../state/session.dart';
import '../common/basics.dart';
import '../common/inputs.dart';

/// الخطط — مبنية ومعطّلة، تُشغّل حين تتحوّل المنصة لمدفوعة (مقابل /admin/plans)
class PlansTool extends StatelessWidget {
  const PlansTool({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watchDb();
    final p = context.palette;
    final store = context.read<DataStore>();
    final counts = {for (final plan in db.plans) plan.id: db.restaurants.where((r) => r.planId == plan.id).length};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Text(
          'مبنية ومعطّلة — تُشغّل عند تحويل المنصة لمدفوعة',
          style: txt(12.5, color: p.inkFaint, weight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SurfaceCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: p.saffron),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('لماذا الخطط موجودة وهي معطّلة؟', style: heading(15.5, color: p.ink)),
                    const SizedBox(height: 6),
                    Text(
                      'المنصة مجانية بالكامل الآن، لكن جدولي الخطط والاشتراكات مبنيان في قاعدة البيانات من البداية. فرض الحدود وربط بوابة الدفع يصير تشغيلًا لما هو موجود، لا إعادة بناء لهيكل البيانات. تفعيل خطة هنا لا يفرض حدودها بعد؛ يعلّمها فقط كمتاحة.',
                      style: txt(13.5, color: p.inkSoft, height: 1.75),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final plan in db.plans)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(plan.name, style: heading(16.5, color: p.ink)),
                            Text(
                              '${countOf(counts[plan.id] ?? 0, nRestaurant)} عليها',
                              style: txt(12.5, color: p.inkFaint),
                            ),
                          ],
                        ),
                      ),
                      Tag(plan.isActive ? 'مفعّلة' : 'معطّلة', tone: plan.isActive ? Tone.basil : Tone.neutral),
                    ],
                  ),
                  const SizedBox(height: 10),
                  plan.price == 0
                      ? Text('مجانية', style: heading(22, color: p.saffron))
                      : Row(
                          children: [
                            MoneyText(
                              plan.price,
                              currency: 'SAR',
                              style: heading(22, color: p.saffron),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '/ شهريًا',
                              style: txt(12.5, color: p.inkFaint, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                  const SizedBox(height: 10),
                  for (final feature in plan.features)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_rounded, size: 17, color: p.basil),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(feature, style: txt(13.5, color: p.inkSoft)),
                          ),
                        ],
                      ),
                    ),
                  Divider(height: 24, color: p.line),
                  if (plan.price > 0) ...[
                    LabeledField(
                      label: 'السعر الشهري',
                      child: CommitField(
                        value: formatNumber(plan.price),
                        ltr: true,
                        dense: false,
                        keyboardType: TextInputType.number,
                        onCommit: (v) {
                          final price = parseAmount(v);
                          if (price == null || price < 0) return toastError('اكتب سعرًا صحيحًا');
                          store.updatePlan(plan.id, price: price);
                          toast('حُفظ السعر');
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  ToggleRow(
                    label: 'متاحة للمطاعم',
                    value: plan.isActive,
                    enabled: plan.id != 'plan_free',
                    hint: plan.id == 'plan_free'
                        ? 'الخطة المجانية لا تُعطّل — هي الخطة الافتراضية لكل حساب جديد.'
                        : null,
                    onChanged: (v) {
                      store.setPlanActive(plan.id, v);
                      toast(v ? 'فُعّلت الخطة' : 'عُطّلت الخطة');
                    },
                  ),
                ],
              ),
            ),
          ),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ما يلزم لتشغيل الاشتراكات فعليًا', style: heading(15.5, color: p.ink)),
              const SizedBox(height: 10),
              for (final (i, step) in const [
                'ربط بوابة دفع (Moyasar أو Tap) لسحب الاشتراك الشهري',
                'فرض الحد الأعلى للأطباق والطاولات عند الإضافة في لوحة المطعم',
                'شاشة ترقية داخل لوحة المطعم مع مقارنة الخطط',
                'تنبيه قبل انتهاء الاشتراك، وسلوك محدَّد عند انتهائه',
              ].indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: p.surface2, shape: BoxShape.circle),
                        child: Text(
                          ltr('${i + 1}'),
                          style: txt(11.5, color: p.inkSoft, weight: FontWeight.w700, height: 1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(step, style: txt(13.5, color: p.inkSoft, height: 1.6)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
