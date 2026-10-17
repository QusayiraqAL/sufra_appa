import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/cart.dart';
import '../../data/arabic.dart';
import '../../data/models.dart';
import '../../data/mutations.dart';
import '../../data/queries.dart';
import '../../data/utils.dart';
import '../../state/session.dart';
import '../common/basics.dart';
import '../common/buttons.dart';
import '../common/inputs.dart';
import 'brand_scope.dart';
import 'cart_screen.dart';
import 'order_status_screen.dart';
import 'storefront_menu.dart';

const _typeHint = {
  OrderType.dineIn: 'يُجهَّز ويُقدَّم على طاولتك',
  OrderType.pickup: 'تستلمه من المطعم بنفسك',
  OrderType.delivery: 'يوصل إلى عنوانك',
};

const _typeIcon = {
  OrderType.dineIn: Icons.table_restaurant_rounded,
  OrderType.pickup: Icons.shopping_bag_rounded,
  OrderType.delivery: Icons.delivery_dining_rounded,
};

/// إتمام الطلب — مقابل /m/[slug]/checkout في الموقع
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.slug, required this.mode});

  final String slug;
  final StorefrontMode mode;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  OrderType? _chosen;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  String? _error;
  bool _busy = false;

  late final CartStore _cart = context.read<CartRegistry>().of(widget.slug);

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watchDb();
    final restaurant = getRestaurantBySlug(db, widget.slug);
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
        listenable: _cart,
        builder: (context, _) {
          final table = _cart.tableToken == null ? null : getTableByToken(db, restaurant.id, _cart.tableToken!);

          // الأنواع المتاحة تُحسب عند العرض: الطلب من الطاولة يظهر فقط لمن جاء
          // عبر رمز طاولة، والنوع المبدئي أوّل متاح — فلو أطفأ المطعم نوعًا
          // كان مختارًا سقط الاختيار تلقائيًا لأوّل نوع صالح.
          final available = [
            if (restaurant.dineInEnabled && table != null) OrderType.dineIn,
            if (restaurant.pickupEnabled) OrderType.pickup,
            if (restaurant.deliveryEnabled) OrderType.delivery,
          ];
          final type = _chosen != null && available.contains(_chosen) ? _chosen : available.firstOrNull;

          final audit = auditCart(db, _cart.lines);
          final scaffoldBar = AppBar(
            title: Text('إتمام الطلب', style: heading(18, color: p.ink)),
          );

          if (audit.rejected.isNotEmpty || audit.lines.isEmpty) {
            final changed = audit.rejected.isNotEmpty;
            return Scaffold(
              backgroundColor: p.surface,
              appBar: scaffoldBar,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: EmptyState(
                    title: changed ? 'تغيّر المنيو' : 'السلة فارغة',
                    body: changed
                        ? 'تغيّر المنيو بعد إضافتك للسلة، وبعض الأصناف لم تعد صالحة.'
                        : 'السلة فارغة، فلا شيء لإتمامه.',
                    icon: changed ? Icons.sync_problem_rounded : Icons.shopping_bag_outlined,
                    action: AppButton(
                      label: changed ? 'راجع السلة' : 'تصفّح المنيو',
                      tone: BtnTone.primary,
                      brand: BrandScope.of(context).brand,
                      onBrand: BrandScope.of(context).onBrand,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              ),
            );
          }

          final lines = audit.lines;
          final subtotal = round2(lines.fold(0.0, (s, l) => s + l.lineTotal));
          final deliveryFee = type == OrderType.delivery ? restaurant.deliveryFee : 0.0;
          final bill = computeBill(
            subtotal: subtotal,
            taxRate: restaurant.taxRate,
            taxIncluded: restaurant.taxIncluded,
            deliveryFee: deliveryFee,
          );
          final open = isOpenNow(restaurant.workingHours);
          final currency = restaurant.currency;
          final brand = BrandScope.of(context);

          void submit() {
            FocusScope.of(context).unfocus();
            if (type == null) {
              setState(() => _error = 'اختر نوع الطلب');
              return;
            }
            if (!open) {
              setState(() => _error = 'المطعم مغلق الآن، فلا يمكن إرسال الطلب.');
              return;
            }
            setState(() {
              _error = null;
              _busy = true;
            });
            final result = context.store.createOrder(
              CreateOrderInput(
                restaurantId: restaurant.id,
                type: type,
                tableId: type == OrderType.dineIn ? table?.id : null,
                customerName: _name.text,
                customerPhone: _phone.text,
                address: _address.text,
                note: _note.text,
                lines: _cart.lines,
              ),
            );
            if (!result.ok) {
              HapticFeedback.heavyImpact();
              setState(() {
                _error = result.error;
                _busy = false;
              });
              return;
            }
            HapticFeedback.mediumImpact();
            _cart.clear();
            // يرجع لشاشة المنيو ثم يفتح متابعة الطلب — فالرجوع منها يعيد للمنيو
            final navigator = Navigator.of(context);
            navigator.popUntil(_isMenuRoute);
            navigator.push(
              MaterialPageRoute(
                builder: (_) => OrderStatusScreen(slug: widget.slug, orderId: result.data!.orderId, mode: widget.mode),
              ),
            );
          }

          return Scaffold(
            backgroundColor: p.surface,
            appBar: scaffoldBar,
            bottomNavigationBar: StickyBar(
              child: BrandBarButton(
                label: !open
                    ? 'مغلق الآن'
                    : _busy
                    ? 'جارٍ الإرسال…'
                    : 'أرسل الطلب',
                icon: open ? Icons.send_rounded : Icons.lock_clock_rounded,
                busy: _busy,
                onPressed: open && !_busy ? submit : null,
                trailing: MoneyText(
                  bill.total,
                  currency: currency,
                  style: heading(15.5, color: open ? brand.onBrand : p.inkFaint, weight: FontWeight.w700),
                ),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  'نوع الطلب',
                  style: txt(15, color: p.ink, weight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                if (available.isEmpty)
                  AlertBox(
                    restaurant.dineInEnabled
                        ? 'هذا المطعم يستقبل الطلبات من الطاولة فقط. امسح رمز QR الموجود على طاولتك لتتمكّن من الإرسال.'
                        : 'لم يفعّل المطعم أي طريقة طلب بعد.',
                    tone: Tone.ember,
                  )
                else
                  for (final option in available)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TypeTile(
                        type: option,
                        selected: type == option,
                        label: option == OrderType.dineIn && table != null
                            ? '${orderTypeLabel[option]} — ${table.label}'
                            : orderTypeLabel[option]!,
                        fee: option == OrderType.delivery && restaurant.deliveryFee > 0
                            ? formatMoney(restaurant.deliveryFee, currency)
                            : null,
                        onTap: () => setState(() => _chosen = option),
                      ),
                    ),
                if (restaurant.dineInEnabled && table == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, size: 16, color: p.inkFaint),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.mode == StorefrontMode.operator
                                ? 'للطلب من طاولة، اخترها من أعلى المنيو.'
                                : 'للطلب من الطاولة، امسح رمز QR الموجود عليها.',
                            style: txt(12.5, color: p.inkFaint),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (type != OrderType.dineIn) ...[
                  const SizedBox(height: 22),
                  Text(
                    widget.mode == StorefrontMode.operator ? 'بيانات العميل' : 'بياناتك',
                    style: txt(15, color: p.ink, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  LabeledField(
                    label: 'الاسم',
                    child: AppTextField(
                      controller: _name,
                      hint: 'مثال: فيصل',
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                    ),
                  ),
                  const SizedBox(height: 14),
                  LabeledField(
                    label: 'رقم الجوال',
                    hint: 'يتصل بك المطعم عليه إذا احتاج.',
                    child: AppTextField(
                      controller: _phone,
                      hint: '05xxxxxxxx',
                      ltr: true,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                    ),
                  ),
                  if (type == OrderType.delivery) ...[
                    const SizedBox(height: 14),
                    LabeledField(
                      label: 'العنوان',
                      hint: 'الحي، الشارع، رقم المبنى، والدور.',
                      child: AppTextField(
                        controller: _address,
                        hint: 'حي النرجس، شارع الأمير سلطان، عمارة 12، الدور 3',
                        maxLines: 3,
                        minLines: 2,
                        autofillHints: const [AutofillHints.fullStreetAddress],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 22),
                LabeledField(
                  label: 'ملاحظة على الطلب',
                  hint: 'اختياري — مثل «أجي بعد نصف ساعة».',
                  child: AppTextField(controller: _note, maxLines: 3, minLines: 2, maxLength: 200),
                ),
                const SizedBox(height: 22),
                BillCard(
                  currency: currency,
                  header: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'الفاتورة · ${countOf(lines.length, nItem)}',
                          style: txt(14.5, color: p.ink, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        for (final line in lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${ltr('${line.qty}×')} ',
                                          style: txt(13, color: p.ink, weight: FontWeight.w700),
                                        ),
                                        TextSpan(text: line.dish.name),
                                      ],
                                    ),
                                    style: txt(13, color: p.inkSoft),
                                  ),
                                ),
                                MoneyText(
                                  line.lineTotal,
                                  currency: currency,
                                  style: txt(13, color: p.inkSoft),
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
                    ('المجموع', bill.subtotal),
                    if (restaurant.taxRate > 0) ('ضريبة ${ltr(formatNumber(restaurant.taxRate))}%', bill.taxAmount),
                    if (deliveryFee > 0) ('رسوم التوصيل', bill.deliveryFee),
                  ],
                  total: bill.total,
                  footnote: 'الدفع كاش عند الاستلام.',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AlertBox(_error!, icon: Icons.error_outline_rounded),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static bool _isMenuRoute(Route<dynamic> route) => route.isFirst || route.settings.name == storefrontRouteName;
}

/// اسم مسار صفحة المنيو — الرجوع بعد إرسال الطلب يتوقف عنده
const storefrontRouteName = 'storefront';

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.type, required this.selected, required this.label, required this.onTap, this.fee});

  final OrderType type;
  final bool selected;
  final String label;
  final String? fee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final brand = BrandScope.of(context);
    return Material(
      color: selected ? brand.soft : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: selected ? brand.brand : p.line, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              RadioDot(selected: selected, color: brand.brand),
              const SizedBox(width: 12),
              Icon(_typeIcon[type], size: 22, color: selected ? brand.brand : p.inkSoft),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: txt(14.5, color: p.ink, weight: FontWeight.w700),
                    ),
                    Text(_typeHint[type]!, style: txt(12.5, color: p.inkFaint)),
                  ],
                ),
              ),
              if (fee != null)
                Text(
                  fee!,
                  style: txt(12.5, color: p.inkSoft, weight: FontWeight.w600),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
