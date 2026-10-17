import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/cart.dart';
import '../../data/queries.dart';
import '../../data/utils.dart';
import '../../data/validation.dart';
import '../../state/session.dart';
import '../common/basics.dart';
import '../common/buttons.dart';
import '../common/inputs.dart';
import 'brand_scope.dart';
import 'checkout_screen.dart';
import 'storefront_menu.dart';

/// السلة — مقابل /m/[slug]/cart في الموقع
class CartScreen extends StatelessWidget {
  const CartScreen({super.key, required this.slug, required this.mode});

  final String slug;
  final StorefrontMode mode;

  @override
  Widget build(BuildContext context) {
    final db = context.watchDb();
    final restaurant = getRestaurantBySlug(db, slug);
    final cart = context.read<CartRegistry>().of(slug);
    final p = context.palette;

    if (restaurant == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('لا يوجد مطعم بهذا الرابط')),
      );
    }

    return BrandScope.wrap(
      context,
      restaurant,
      ListenableBuilder(
        listenable: cart,
        builder: (context, _) {
          final audit = auditCart(db, cart.lines);
          final lines = audit.lines;
          final rejected = audit.rejected;
          final subtotal = round2(lines.fold(0.0, (s, l) => s + l.lineTotal));
          final bill = computeBill(
            subtotal: subtotal,
            taxRate: restaurant.taxRate,
            taxIncluded: restaurant.taxIncluded,
            deliveryFee: 0,
          );
          final soldOut = lines.where((l) => !l.dish.dish.isAvailable).toList();
          final belowMin = restaurant.minOrder > 0 && subtotal < restaurant.minOrder;
          final currency = restaurant.currency;
          final empty = lines.isEmpty && rejected.isEmpty;

          return Scaffold(
            backgroundColor: p.surface,
            appBar: AppBar(
              title: Text('السلة', style: heading(18, color: p.ink)),
            ),
            bottomNavigationBar: empty
                ? null
                : StickyBar(
                    child: rejected.isNotEmpty
                        ? const AlertBox('راجع الأصناف المعلَّمة بالأعلى لإكمال الطلب', center: true)
                        : soldOut.isNotEmpty
                        ? const AlertBox('احذف الأطباق النافدة لإكمال الطلب', center: true)
                        : belowMin
                        ? AlertBox(
                            'الحد الأدنى للطلب ${formatMoney(restaurant.minOrder, currency)} — أضف المزيد',
                            tone: Tone.ember,
                            center: true,
                          )
                        : BrandBarButton(
                            label: 'إتمام الطلب',
                            icon: Icons.arrow_forward_rounded,
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CheckoutScreen(slug: slug, mode: mode),
                              ),
                            ),
                            trailing: MoneyText(
                              bill.total,
                              currency: currency,
                              style: heading(15.5, color: BrandScope.of(context).onBrand, weight: FontWeight.w700),
                            ),
                          ),
                  ),
            body: empty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyState(
                        title: 'السلة فارغة',
                        body: 'ارجع للمنيو واختر ما يعجبك.',
                        icon: Icons.shopping_bag_outlined,
                        action: AppButton(
                          label: 'تصفّح المنيو',
                          tone: BtnTone.primary,
                          brand: BrandScope.of(context).brand,
                          onBrand: BrandScope.of(context).onBrand,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      // الأسطر التي لم تعد صالحة تُعرض ولا تُحذف تلقائيًا: المنيو
                      // قد يتغيّر بعد إضافتها، والحذف الصامت يترك العميل بلا تفسير
                      for (final line in rejected)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          decoration: BoxDecoration(
                            color: p.sumacTint,
                            borderRadius: BorderRadius.circular(Radii.md),
                            border: Border.all(color: p.sumac.withValues(alpha: .25)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.dishName ?? 'صنف محذوف',
                                      style: txt(14.5, color: p.ink, weight: FontWeight.w700),
                                    ),
                                    Text(
                                      line.issues.firstOrNull?.message ?? 'لم يعد هذا الصنف صالحًا',
                                      style: txt(12.5, color: p.sumac),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: p.sumac),
                                onPressed: () => cart.remove(line.key),
                                child: const Text('احذفه'),
                              ),
                            ],
                          ),
                        ),
                      for (final (i, line) in lines.indexed) ...[
                        if (i > 0) Divider(height: 1, color: p.line),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DishThumb(
                                name: line.dish.name,
                                src: line.dish.dish.imageUrl,
                                size: 56,
                                radius: 14,
                                dim: !line.dish.dish.isAvailable,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          line.dish.name,
                                          style: txt(15, color: p.ink, weight: FontWeight.w700),
                                        ),
                                        if (!line.dish.dish.isAvailable)
                                          const Tag('نفد اليوم', tone: Tone.sumac, dense: true),
                                      ],
                                    ),
                                    if (line.optionNames.isNotEmpty)
                                      Text(
                                        line.optionNames.map((o) => o.name).join(' · '),
                                        style: txt(12.5, color: p.inkFaint, height: 1.6),
                                      ),
                                    if (line.note.isNotEmpty)
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'ملاحظة: ',
                                              style: txt(12.5, weight: FontWeight.w700),
                                            ),
                                            TextSpan(text: line.note),
                                          ],
                                        ),
                                        style: txt(12.5, color: p.inkSoft),
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        NumberStepper(
                                          value: line.qty,
                                          compact: true,
                                          min: 1,
                                          max: maxLineQty,
                                          onChanged: (q) => cart.setQty(line.key, q),
                                        ),
                                        const SizedBox(width: 8),
                                        IconBtn(
                                          icon: Icons.delete_outline_rounded,
                                          tooltip: 'احذف من السلة',
                                          size: 38,
                                          danger: true,
                                          onPressed: () => cart.remove(line.key),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  MoneyText(
                                    line.lineTotal,
                                    currency: currency,
                                    style: txt(14.5, color: p.ink, weight: FontWeight.w700),
                                  ),
                                  if (line.qty > 1)
                                    Text(
                                      '${formatMoney(line.unitPrice, currency)} × ${line.qty}',
                                      style: txt(11.5, color: p.inkFaint),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (lines.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        BillCard(
                          currency: currency,
                          rows: [
                            ('المجموع', bill.subtotal),
                            if (restaurant.taxRate > 0)
                              (
                                'ضريبة القيمة المضافة ${ltr(formatNumber(restaurant.taxRate))}%${restaurant.taxIncluded ? ' (مشمولة)' : ''}',
                                bill.taxAmount,
                              ),
                          ],
                          total: bill.total,
                          footnote: restaurant.deliveryEnabled && restaurant.deliveryFee > 0
                              ? 'رسوم التوصيل تُضاف في الخطوة التالية إذا اخترت التوصيل.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'أضف المزيد',
                          icon: Icons.add_rounded,
                          expand: true,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// ملخّص الفاتورة: أسطر ثم إجمالي بخط أعرض
class BillCard extends StatelessWidget {
  const BillCard({
    super.key,
    required this.currency,
    required this.rows,
    required this.total,
    this.footnote,
    this.header,
  });

  final String currency;
  final List<(String, double)> rows;
  final double total;
  final String? footnote;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface2.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: txt(14, color: p.inkSoft)),
                  ),
                  MoneyText(
                    value,
                    currency: currency,
                    style: txt(14, color: p.ink),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Divider(height: 1, color: p.line),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('الإجمالي', style: heading(16.5, color: p.ink)),
                ),
                MoneyText(
                  total,
                  currency: currency,
                  style: heading(16.5, color: p.ink),
                ),
              ],
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: 8),
            Text(footnote!, style: txt(12, color: p.inkFaint, height: 1.6)),
          ],
        ],
      ),
    );
  }
}
