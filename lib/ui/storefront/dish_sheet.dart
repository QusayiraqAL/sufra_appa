import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/images.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/utils.dart';
import '../../data/validation.dart';
import '../common/basics.dart';
import '../common/inputs.dart';
import 'brand_scope.dart';

/// نتيجة لوح الطبق حين يضغط العميل «أضف للسلة»
typedef DishPick = ({List<CartSelection> selections, String note, int qty});

/// لوح تفاصيل الطبق. يفتح من الأسفل لأن الطلب يحدث على الجوال في الغالب،
/// فيبقى الإبهام قريبًا من الأزرار.
Future<DishPick?> showDishSheet(BuildContext context, {required DishWithOptions dish, required Restaurant restaurant}) {
  return showModalBottomSheet<DishPick>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    // لون المطعم يُشتق داخل اللوح نفسه: سياق المستدعي فوق نطاق الهوية
    builder: (sheetContext) =>
        BrandScope.wrap(sheetContext, restaurant, _DishSheet(dish: dish, restaurant: restaurant)),
  );
}

/// الخيارات المبدئية مختارة سلفًا، والمجموعة الإجبارية تختار أول خيار
Map<String, List<String>> _initialSelections(DishWithOptions dish) => {
  for (final g in dish.groups)
    g.id: () {
      final defaults = [
        for (final o in g.options)
          if (o.isDefault) o.id,
      ];
      if (g.type == OptionGroupType.single && defaults.isEmpty && g.isRequired && g.options.isNotEmpty) {
        return [g.options.first.id];
      }
      return defaults;
    }(),
};

/// يحوّل حالة الشاشة إلى الشكل الذي تفهمه طبقة التحقق والسلة
List<CartSelection> _toSelections(DishWithOptions dish, Map<String, List<String>> picked) => [
  for (final g in dish.groups)
    if ((picked[g.id] ?? const []).isNotEmpty) CartSelection(groupId: g.id, optionIds: picked[g.id]!),
];

class _DishSheet extends StatefulWidget {
  const _DishSheet({required this.dish, required this.restaurant});

  final DishWithOptions dish;
  final Restaurant restaurant;

  @override
  State<_DishSheet> createState() => _DishSheetState();
}

class _DishSheetState extends State<_DishSheet> {
  late Map<String, List<String>> _picked = _initialSelections(widget.dish);
  final _note = TextEditingController();
  int _qty = 1;
  bool _showErrors = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _toggle(GroupWithOptions group, String optionId) {
    HapticFeedback.selectionClick();
    setState(() {
      final chosen = [...?_picked[group.id]];
      if (group.type == OptionGroupType.single) {
        _picked = {
          ..._picked,
          group.id: [optionId],
        };
        return;
      }
      if (chosen.contains(optionId)) {
        chosen.remove(optionId);
      } else {
        if (group.maxSelect > 0 && chosen.length >= group.maxSelect) return;
        chosen.add(optionId);
      }
      _picked = {..._picked, group.id: chosen};
    });
  }

  /// التحقق والتسعير يمرّان بـ validation.dart — نفس الدوال التي يستدعيها
  /// createOrder. فما تمنعه هذه الشاشة يُمنع أيضًا لو تجاوزها أحد.
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final brand = BrandScope.of(context);
    final dish = widget.dish;
    final d = dish.dish;
    final currency = widget.restaurant.currency;
    final selections = _toSelections(dish, _picked);
    final unitPrice = priceSelections(dish, selections).unitPrice;
    final issues = checkSelections(dish, selections);
    final invalid = {for (final i in issues) ?i.groupId};
    final soldOut = !d.isAvailable;
    final image = dataImage(d.imageUrl);
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * .92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: CustomScrollView(
                shrinkWrap: true,
                slivers: [
                  SliverToBoxAdapter(
                    child: image != null
                        ? Stack(
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 10,
                                child: Image(image: image, fit: BoxFit.cover),
                              ),
                              PositionedDirectional(top: 10, end: 10, child: _CloseButton(onDark: true)),
                            ],
                          )
                        : Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 0),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: p.lineStrong,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                                const Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: _CloseButton(onDark: false),
                                ),
                              ],
                            ),
                          ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    sliver: SliverList.list(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (image == null) ...[
                              DishThumb(name: d.name, src: null, size: 76, radius: 18, dim: soldOut),
                              const SizedBox(width: 14),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d.name, style: heading(21, color: p.ink)),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (d.isFeatured) const Tag('الأكثر طلبًا', tone: Tone.saffron, dense: true),
                                      if (soldOut) const Tag('نفد اليوم', tone: Tone.sumac, dense: true),
                                      if (d.compareAtPrice != null) const Tag('عرض', tone: Tone.basil, dense: true),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (d.description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(d.description, style: txt(14.5, color: p.inkSoft, height: 1.75)),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            MoneyText(
                              d.price,
                              currency: currency,
                              style: heading(20, color: brand.brand),
                            ),
                            if (d.compareAtPrice != null) ...[
                              const SizedBox(width: 10),
                              MoneyText(
                                d.compareAtPrice!,
                                currency: currency,
                                strike: true,
                                style: txt(14.5, color: p.inkFaint),
                              ),
                            ],
                          ],
                        ),
                        for (final group in dish.groups) ...[
                          const SizedBox(height: 22),
                          _GroupPicker(
                            group: group,
                            chosen: _picked[group.id] ?? const [],
                            invalid: _showErrors && invalid.contains(group.id),
                            message: _showErrors
                                ? issues.where((i) => i.groupId == group.id).firstOrNull?.message
                                : null,
                            currency: currency,
                            onToggle: (id) => _toggle(group, id),
                          ),
                        ],
                        if (d.allowNote) ...[
                          const SizedBox(height: 22),
                          Text(
                            'ملاحظة للمطبخ',
                            style: txt(14.5, color: p.ink, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _note,
                            hint: 'مثال: بدون بصل · حار زيادة',
                            maxLines: 3,
                            minLines: 2,
                            maxLength: 160,
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.line)),
              ),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + media.padding.bottom),
              child: Row(
                children: [
                  NumberStepper(value: _qty, onChanged: (v) => setState(() => _qty = v), min: 1, max: maxLineQty),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BrandBarButton(
                      label: soldOut ? 'نفد اليوم' : 'أضف للسلة',
                      icon: soldOut ? null : Icons.add_shopping_cart_rounded,
                      onPressed: soldOut
                          ? null
                          : () {
                              if (issues.isNotEmpty) {
                                HapticFeedback.heavyImpact();
                                setState(() => _showErrors = true);
                                return;
                              }
                              Navigator.pop(context, (selections: selections, note: _note.text, qty: _qty));
                            },
                      trailing: soldOut
                          ? null
                          : MoneyText(
                              round2(unitPrice * _qty),
                              currency: currency,
                              style: heading(15.5, color: brand.onBrand, weight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onDark});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: onDark ? Colors.black.withValues(alpha: .45) : p.surface2,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: 'إغلاق',
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.close_rounded, color: onDark ? Colors.white : p.inkSoft),
      ),
    );
  }
}

class _GroupPicker extends StatelessWidget {
  const _GroupPicker({
    required this.group,
    required this.chosen,
    required this.invalid,
    required this.message,
    required this.currency,
    required this.onToggle,
  });

  final GroupWithOptions group;
  final List<String> chosen;
  final bool invalid;
  final String? message;
  final String currency;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final brand = BrandScope.of(context);
    final single = group.type == OptionGroupType.single;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              group.name,
              style: txt(15, color: p.ink, weight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            if (group.isRequired)
              Tag('مطلوب', tone: invalid ? Tone.sumac : Tone.neutral, dense: true)
            else
              Text('اختياري', style: txt(12, color: p.inkFaint)),
            const Spacer(),
            if (!single && group.maxSelect > 0)
              Text(
                ltr('${chosen.length}/${group.maxSelect}'),
                style: txt(12.5, color: p.inkFaint, weight: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: invalid ? p.sumacTint.withValues(alpha: .6) : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: invalid ? p.sumac : p.line),
          ),
          child: Column(
            children: [
              for (final option in group.options)
                () {
                  final active = chosen.contains(option.id);
                  final blocked = !single && group.maxSelect > 0 && !active && chosen.length >= group.maxSelect;
                  return Opacity(
                    opacity: blocked ? .4 : 1,
                    child: Material(
                      color: active ? brand.soft : Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.sm),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Radii.sm),
                        onTap: blocked ? null : () => onToggle(option.id),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                single
                                    ? RadioDot(selected: active, color: brand.brand)
                                    : CheckDot(selected: active, color: brand.brand, onColor: brand.onBrand),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(option.name, style: txt(14.5, color: p.ink)),
                                ),
                                if (option.priceDelta != 0)
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(text: option.priceDelta > 0 ? '+' : '−'),
                                        WidgetSpan(
                                          alignment: PlaceholderAlignment.baseline,
                                          baseline: TextBaseline.alphabetic,
                                          child: MoneyText(
                                            option.priceDelta.abs(),
                                            currency: currency,
                                            style: txt(13, color: p.inkSoft, weight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    style: txt(13, color: p.inkSoft, weight: FontWeight.w600),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }(),
            ],
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            style: txt(12.5, color: p.sumac, weight: FontWeight.w500),
          ),
        ],
      ],
    );
  }
}
