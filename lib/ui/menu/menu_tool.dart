import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
import '../common/inputs.dart';
import '../common/sheets.dart';
import 'dish_editor_screen.dart';

/// المنيو — الأقسام والأطباق (مقابل /dashboard/menu في الموقع)
class MenuTool extends StatefulWidget {
  const MenuTool({super.key});

  @override
  State<MenuTool> createState() => _MenuToolState();
}

class _MenuToolState extends State<MenuTool> {
  final _newCategory = TextEditingController();
  final _collapsed = <String>{};

  @override
  void dispose() {
    _newCategory.dispose();
    super.dispose();
  }

  void _addCategory(String restaurantId) {
    final result = context.store.addCategory(restaurantId, _newCategory.text);
    if (!result.ok) return toastError(result.error!);
    _newCategory.clear();
    FocusScope.of(context).unfocus();
    toast('أُضيف القسم');
  }

  @override
  Widget build(BuildContext context) {
    return RestaurantBuilder(
      builder: (context, db, restaurant, profile) {
        final p = context.palette;
        final sections = getMenu(db, restaurant.id);
        final totalDishes = sections.fold(0, (s, x) => s + x.dishes.length);
        final nav = context.read<NavState>();
        final allCollapsed = sections.isNotEmpty && sections.every((s) => _collapsed.contains(s.category.id));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Text(
              '${countOf(sections.length, nSection, isolate: ltr)} · ${countOf(totalDishes, nDish, isolate: ltr)}',
              style: txt(12.5, color: p.inkFaint, weight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  label: 'كما يراه العميل',
                  icon: Icons.storefront_rounded,
                  size: BtnSize.sm,
                  onPressed: () => nav.open(ToolId.storefront),
                ),
                AppButton(
                  label: 'اطبع المنيو',
                  icon: Icons.menu_book_rounded,
                  size: BtnSize.sm,
                  onPressed: () => nav.open(ToolId.printMenu),
                ),
                if (sections.length > 1)
                  AppButton(
                    label: 'رتّب الأقسام',
                    icon: Icons.swap_vert_rounded,
                    size: BtnSize.sm,
                    onPressed: () => _reorderCategories(context, restaurant.id, sections),
                  ),
                if (sections.isNotEmpty)
                  AppButton(
                    label: allCollapsed ? 'افرد الكل' : 'اطوِ الكل',
                    icon: allCollapsed ? Icons.unfold_more_rounded : Icons.unfold_less_rounded,
                    size: BtnSize.sm,
                    tone: BtnTone.ghost,
                    onPressed: () => setState(() {
                      if (allCollapsed) {
                        _collapsed.clear();
                      } else {
                        _collapsed.addAll(sections.map((s) => s.category.id));
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // إضافة قسم
            SurfaceCard(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _newCategory,
                      hint: 'اسم قسم جديد — مثال: مشاوي',
                      dense: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addCategory(restaurant.id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ListenableBuilder(
                    listenable: _newCategory,
                    builder: (context, _) => AppButton(
                      label: 'أضف قسمًا',
                      icon: Icons.add_rounded,
                      tone: BtnTone.primary,
                      size: BtnSize.sm,
                      onPressed: _newCategory.text.trim().length >= 2 ? () => _addCategory(restaurant.id) : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (sections.isEmpty)
              const EmptyState(
                title: 'المنيو فارغ',
                body: 'ابدأ بإضافة قسم — مثل «مقبلات» أو «مشاوي» — ثم أضف أطباقه.',
                icon: Icons.restaurant_menu_rounded,
              )
            else
              for (final (index, section) in sections.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CategoryCard(
                    key: ValueKey(section.category.id),
                    section: section,
                    restaurant: restaurant,
                    db: db,
                    index: index,
                    count: sections.length,
                    allIds: [for (final s in sections) s.category.id],
                    categories: [for (final s in sections) s.category],
                    expanded: !_collapsed.contains(section.category.id),
                    onToggle: () => setState(() {
                      if (!_collapsed.remove(section.category.id)) _collapsed.add(section.category.id);
                    }),
                  ),
                ),
          ],
        );
      },
    );
  }
}

List<String> _moved(List<String> ids, int from, int to) {
  final next = [...ids];
  next.insert(to, next.removeAt(from));
  return next;
}

Future<void> _reorderCategories(BuildContext context, String restaurantId, List<MenuSection> sections) {
  var order = [for (final s in sections) s.category];
  return showAppSheet<void>(
    context,
    title: 'رتّب الأقسام',
    subtitle: 'اسحب من المقبض لتغيير الترتيب — يظهر بنفس الترتيب عند العميل',
    scrollable: false,
    builder: (c) => StatefulBuilder(
      builder: (c, setSheet) => _ReorderList(
        items: [for (final cat in order) (cat.id, cat.name, null)],
        onReorder: (from, to) {
          setSheet(() {
            final moved = order.removeAt(from);
            order.insert(to, moved);
          });
          c.read<DataStore>().reorderCategories(restaurantId, [for (final cat in order) cat.id]);
        },
      ),
    ),
  );
}

Future<void> _reorderDishes(BuildContext context, Category category, List<Dish> dishes) {
  var order = [...dishes];
  return showAppSheet<void>(
    context,
    title: 'رتّب أطباق «${category.name}»',
    subtitle: 'اسحب من المقبض لتغيير الترتيب',
    scrollable: false,
    builder: (c) => StatefulBuilder(
      builder: (c, setSheet) => _ReorderList(
        items: [for (final d in order) (d.id, d.name, d.imageUrl)],
        thumbs: true,
        onReorder: (from, to) {
          setSheet(() {
            final moved = order.removeAt(from);
            order.insert(to, moved);
          });
          c.read<DataStore>().reorderDishes(category.id, [for (final d in order) d.id]);
        },
      ),
    ),
  );
}

class _ReorderList extends StatelessWidget {
  const _ReorderList({required this.items, required this.onReorder, this.thumbs = false});

  final List<(String, String, String?)> items;
  final void Function(int from, int to) onReorder;
  final bool thumbs;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ReorderableListView.builder(
      shrinkWrap: true,
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(top: 8),
      itemCount: items.length,
      onReorderStart: (_) => HapticFeedback.mediumImpact(),
      onReorder: (from, to) => onReorder(from, to > from ? to - 1 : to),
      proxyDecorator: (child, _, _) => Material(
        color: p.surface,
        elevation: 6,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(Radii.md),
        child: child,
      ),
      itemBuilder: (context, i) {
        final (id, name, image) = items[i];
        return Container(
          key: ValueKey(id),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: p.line),
          ),
          child: ReorderableDragStartListener(
            index: i,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.drag_indicator_rounded, color: p.inkFaint),
                  const SizedBox(width: 10),
                  if (thumbs) ...[DishThumb(name: name, src: image, size: 36, radius: 10), const SizedBox(width: 10)],
                  Expanded(
                    child: Text(
                      name,
                      style: txt(14.5, color: p.ink, weight: FontWeight.w600),
                    ),
                  ),
                  Text(ltr('${i + 1}'), style: txt(12.5, color: p.inkFaint)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ===================== بطاقة قسم ===================== */

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    super.key,
    required this.section,
    required this.restaurant,
    required this.db,
    required this.index,
    required this.count,
    required this.allIds,
    required this.categories,
    required this.expanded,
    required this.onToggle,
  });

  final MenuSection section;
  final Restaurant restaurant;
  final DB db;
  final int index;
  final int count;
  final List<String> allIds;
  final List<Category> categories;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final category = section.category;
    final store = context.read<DataStore>();

    return Opacity(
      opacity: category.isVisible ? 1 : .75,
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: p.surface2.withValues(alpha: .5),
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 4, 6),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: expanded ? 0 : .25,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more_rounded, color: p.inkFaint),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: heading(16, color: p.ink, weight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(ltr('(${section.dishes.length})'), style: txt(12.5, color: p.inkFaint)),
                      if (!category.isVisible) ...[const SizedBox(width: 8), const Tag('مخفي عن العميل', dense: true)],
                      const Spacer(),
                      IconButton(
                        tooltip: category.isVisible ? 'أخفِ القسم عن العميل' : 'أظهر القسم للعميل',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          store.updateCategory(category.id, (c) => c.isVisible = !c.isVisible);
                          toast(
                            category.isVisible ? 'أُخفي «${category.name}» عن العميل' : 'ظهر «${category.name}» للعميل',
                          );
                        },
                        icon: Icon(
                          category.isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: category.isVisible ? p.inkSoft : p.saffron,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'خيارات القسم',
                        icon: Icon(Icons.more_vert_rounded, color: p.inkSoft),
                        onSelected: (v) => _onAction(context, v),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'rename', child: _MenuRow(Icons.edit_outlined, 'أعد التسمية')),
                          if (section.dishes.length > 1)
                            const PopupMenuItem(
                              value: 'sort',
                              child: _MenuRow(Icons.swap_vert_rounded, 'رتّب الأطباق'),
                            ),
                          if (index > 0)
                            const PopupMenuItem(value: 'up', child: _MenuRow(Icons.arrow_upward_rounded, 'انقل لأعلى')),
                          if (index < count - 1)
                            const PopupMenuItem(
                              value: 'down',
                              child: _MenuRow(Icons.arrow_downward_rounded, 'انقل لأسفل'),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            child: _MenuRow(Icons.delete_outline_rounded, 'احذف القسم', color: p.sumac),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (expanded) ...[
              Divider(height: 1, color: p.line),
              if (section.dishes.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('لا أطباق في هذا القسم بعد. أضف أول طبق من الأسفل.', style: txt(13.5, color: p.inkFaint)),
                )
              else
                for (final (i, dish) in section.dishes.indexed) ...[
                  if (i > 0) Divider(height: 1, color: p.line, indent: 16, endIndent: 16),
                  _DishRow(
                    dish: dish,
                    restaurant: restaurant,
                    groups: getOptionGroups(db, dish.id).length,
                    index: i,
                    siblings: section.dishes,
                    categories: categories,
                  ),
                ],
              _QuickAddDish(categoryId: category.id, restaurantId: restaurant.id, currency: restaurant.currency),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, String action) async {
    final store = context.read<DataStore>();
    final category = section.category;
    switch (action) {
      case 'rename':
        final name = await promptText(
          context,
          title: 'أعد تسمية القسم',
          label: 'اسم القسم',
          initial: category.name,
          minLength: 2,
        );
        if (name == null) return;
        store.updateCategory(category.id, (c) => c.name = name);
        toast('تم التعديل');
      case 'sort':
        if (context.mounted) await _reorderDishes(context, category, section.dishes);
      case 'up':
        store.reorderCategories(restaurant.id, _moved(allIds, index, index - 1));
      case 'down':
        store.reorderCategories(restaurant.id, _moved(allIds, index, index + 1));
      case 'delete':
        final ok = await confirmAction(
          context,
          title: 'حذف «${category.name}»',
          body:
              'سيُحذف القسم وكل أطباقه وخياراتها. الطلبات القديمة لا تتأثر لأنها تحفظ نسخة مستقلة من أسماء الأطباق وأسعارها.',
          confirmLabel: 'احذف القسم وأطباقه',
        );
        if (!ok) return;
        store.deleteCategory(category.id);
        toast('حُذف القسم');
    }
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: color ?? context.palette.inkSoft),
      const SizedBox(width: 12),
      Text(
        label,
        style: txt(14.5, color: color ?? context.palette.ink, weight: FontWeight.w500),
      ),
    ],
  );
}

/* ===================== صف طبق ===================== */

class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.dish,
    required this.restaurant,
    required this.groups,
    required this.index,
    required this.siblings,
    required this.categories,
  });

  final Dish dish;
  final Restaurant restaurant;
  final int groups;
  final int index;
  final List<Dish> siblings;
  final List<Category> categories;

  void _openEditor(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DishEditorScreen(dishId: dish.id)));

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final store = context.read<DataStore>();
    return Material(
      color: dish.isAvailable ? Colors.transparent : p.sumacTint.withValues(alpha: .35),
      child: InkWell(
        onTap: () => _openEditor(context),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 4, 10),
          child: Row(
            children: [
              DishThumb(name: dish.name, src: dish.imageUrl, size: 52, radius: 12, dim: !dish.isAvailable),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: txt(14.5, color: dish.isAvailable ? p.ink : p.inkFaint, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        MoneyText(
                          dish.price,
                          currency: restaurant.currency,
                          style: txt(13, color: p.ink),
                        ),
                        if (dish.compareAtPrice != null)
                          MoneyText(
                            dish.compareAtPrice!,
                            currency: restaurant.currency,
                            strike: true,
                            style: txt(12, color: p.inkFaint),
                          ),
                        if (dish.isFeatured) const Tag('مميّز', tone: Tone.saffron, dense: true),
                        if (!dish.isAvailable) const Tag('نفد اليوم', tone: Tone.sumac, dense: true),
                        if (dish.compareAtPrice != null) const Tag('عرض', tone: Tone.basil, dense: true),
                        if (groups > 0) Tag(countOf(groups, nOptionGroup), dense: true),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _AvailabilityPill(
                available: dish.isAvailable,
                onTap: () {
                  HapticFeedback.selectionClick();
                  store.toggleDishAvailable(dish.id);
                  toast(dish.isAvailable ? '«${dish.name}» نفد اليوم' : 'عاد «${dish.name}» للمنيو');
                },
              ),
              PopupMenuButton<String>(
                tooltip: 'خيارات الطبق',
                icon: Icon(Icons.more_vert_rounded, color: p.inkSoft),
                onSelected: (v) => _onAction(context, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: _MenuRow(Icons.edit_outlined, 'حرّر الطبق')),
                  if (index > 0)
                    const PopupMenuItem(value: 'up', child: _MenuRow(Icons.arrow_upward_rounded, 'انقل لأعلى')),
                  if (index < siblings.length - 1)
                    const PopupMenuItem(value: 'down', child: _MenuRow(Icons.arrow_downward_rounded, 'انقل لأسفل')),
                  if (categories.length > 1)
                    const PopupMenuItem(
                      value: 'move',
                      child: _MenuRow(Icons.drive_file_move_outline, 'انقل إلى قسم آخر'),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: _MenuRow(Icons.delete_outline_rounded, 'احذف الطبق', color: p.sumac),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, String action) async {
    final store = context.read<DataStore>();
    final ids = [for (final d in siblings) d.id];
    switch (action) {
      case 'edit':
        _openEditor(context);
      case 'up':
        store.reorderDishes(dish.categoryId, _moved(ids, index, index - 1));
      case 'down':
        store.reorderDishes(dish.categoryId, _moved(ids, index, index + 1));
      case 'move':
        final target = await showAppSheet<String>(
          context,
          title: 'انقل «${dish.name}» إلى',
          builder: (c) => Column(
            children: [
              for (final category in categories)
                if (category.id != dish.categoryId)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(category.name),
                    onTap: () => Navigator.pop(c, category.id),
                  ),
            ],
          ),
        );
        if (target == null) return;
        store.moveDishToCategory(dish.id, target);
        toast('نُقل الطبق');
      case 'delete':
        final ok = await confirmAction(
          context,
          title: 'حذف «${dish.name}»',
          body: 'إذا كان الطبق نافدًا مؤقتًا فاستخدم «نفد اليوم» بدل الحذف — يبقى في المنيو معلَّمًا وتعيده بضغطة.',
        );
        if (!ok) return;
        store.deleteDish(dish.id);
        toast('حُذف الطبق');
    }
  }
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({required this.available, required this.onTap});

  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: available ? 'علّمه نافدًا اليوم' : 'أعِده للمنيو',
      child: Material(
        color: available ? p.surface : p.basil,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
          side: BorderSide(color: available ? p.lineStrong : p.basil),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              available ? 'نفد اليوم' : 'أعِده',
              style: txt(12, color: available ? p.inkSoft : p.surface, weight: FontWeight.w700, height: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================== إضافة طبق سريعة ===================== */

class _QuickAddDish extends StatefulWidget {
  const _QuickAddDish({required this.categoryId, required this.restaurantId, required this.currency});

  final String categoryId;
  final String restaurantId;
  final String currency;

  @override
  State<_QuickAddDish> createState() => _QuickAddDishState();
}

class _QuickAddDishState extends State<_QuickAddDish> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _priceFocus = FocusNode();

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().length >= 2 && (parseAmount(_price.text) ?? -1) >= 0;

  void _submit() {
    if (!_valid) return;
    final result = context.store.addDish(
      widget.restaurantId,
      categoryId: widget.categoryId,
      name: _name.text,
      price: parseAmount(_price.text),
    );
    if (!result.ok) return toastError(result.error!);
    toast('أُضيف «${_name.text.trim()}»');
    _name.clear();
    _price.clear();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface2.withValues(alpha: .35),
        border: Border(top: BorderSide(color: p.line)),
      ),
      padding: const EdgeInsets.all(10),
      child: ListenableBuilder(
        listenable: Listenable.merge([_name, _price]),
        builder: (context, _) => Row(
          children: [
            Expanded(
              flex: 5,
              child: AppTextField(
                controller: _name,
                hint: 'اسم طبق جديد',
                dense: true,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _priceFocus.requestFocus(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: AppTextField(
                controller: _price,
                focusNode: _priceFocus,
                hint: 'السعر',
                dense: true,
                ltr: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            IconBtn(
              icon: Icons.add_rounded,
              tooltip: 'أضف طبقًا',
              size: 44,
              color: _valid ? p.saffron : null,
              onPressed: _valid ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
