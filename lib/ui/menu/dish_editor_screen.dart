import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/feedback.dart';
import '../../core/images.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/mutations.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../../data/utils.dart';
import '../../state/session.dart';
import '../common/basics.dart';
import '../common/buttons.dart';
import '../common/inputs.dart';

/// تحرير طبق — مقابل /dashboard/menu/[dishId] في الموقع
class DishEditorScreen extends StatefulWidget {
  const DishEditorScreen({super.key, required this.dishId});

  final String dishId;

  @override
  State<DishEditorScreen> createState() => _DishEditorScreenState();
}

class _DishEditorScreenState extends State<DishEditorScreen> {
  final _basics = GlobalKey<_BasicsCardState>();
  bool _uploading = false;

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _uploading = true);
    try {
      final dataUrl = await pickImageAsDataUrl(source: source);
      if (dataUrl == null || !mounted) return;
      final result = context.store.updateDish(widget.dishId, (d) => d.imageUrl = dataUrl);
      if (!result.ok) return toastError(result.error!);
      toast('رُفعت الصورة');
    } catch (e) {
      toastError('تعذّر فتح الصورة');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<bool> _confirmLeave() async {
    if (!(_basics.currentState?.dirty ?? false)) return true;
    return confirmAction(
      context,
      title: 'تعديلات غير محفوظة',
      body: 'غيّرت الاسم أو السعر أو الوصف ولم تحفظ. هل تريد الخروج وتجاهلها؟',
      confirmLabel: 'اخرج وتجاهلها',
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watchDb();
    final p = context.palette;
    final dish = getDishWithOptions(db, widget.dishId);
    final restaurant = dish == null ? null : getRestaurantById(db, dish.dish.restaurantId);

    if (dish == null || restaurant == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyState(
              title: 'هذا الطبق غير موجود',
              body: 'قد يكون محذوفًا.',
              icon: Icons.no_food_outlined,
              action: AppButton(
                label: 'رجوع للمنيو',
                tone: BtnTone.primary,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
      );
    }

    final d = dish.dish;
    final categories = getCategories(db, restaurant.id);
    final cheapest =
        d.price +
        dish.groups
            .where((g) => g.type == OptionGroupType.single)
            .fold(0.0, (s, g) => s + (g.options.where((o) => o.isDefault).firstOrNull?.priceDelta ?? 0));
    final store = context.read<DataStore>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تحرير طبق',
                style: txt(12, color: p.inkFaint, weight: FontWeight.w600),
              ),
              Text(
                d.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: heading(17, color: p.ink),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'احذف الطبق',
              icon: Icon(Icons.delete_outline_rounded, color: p.sumac),
              onPressed: () => _delete(d),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // ============ الصورة ============
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: LayoutBuilder(
                      builder: (context, c) => Stack(
                        fit: StackFit.expand,
                        children: [
                          if (d.imageUrl != null)
                            DishThumb(name: d.name, src: d.imageUrl, size: c.maxWidth, radius: 0)
                          else
                            _NoPhoto(onTap: _uploading ? null : () => _pickImage(ImageSource.gallery)),
                          if (_uploading)
                            const ColoredBox(
                              color: Color(0x66000000),
                              child: Center(child: CircularProgressIndicator(color: Colors.white)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: d.imageUrl == null ? 'من المعرض' : 'استبدل',
                            icon: Icons.photo_library_outlined,
                            size: BtnSize.sm,
                            expand: true,
                            onPressed: _uploading ? null : () => _pickImage(ImageSource.gallery),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'بالكاميرا',
                            icon: Icons.photo_camera_outlined,
                            size: BtnSize.sm,
                            expand: true,
                            onPressed: _uploading ? null : () => _pickImage(ImageSource.camera),
                          ),
                        ),
                        if (d.imageUrl != null) ...[
                          const SizedBox(width: 8),
                          IconBtn(
                            icon: Icons.delete_outline_rounded,
                            tooltip: 'احذف الصورة',
                            danger: true,
                            size: 38,
                            onPressed: () {
                              store.updateDish(d.id, (x) => x.imageUrl = null);
                              toast('حُذفت الصورة');
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Text(
                      'تُصغَّر الصورة تلقائيًا قبل الحفظ. الصور محفوظة على هذا الجهاز، فلا ترفع صورًا كثيرة جدًا حتى تُربط قاعدة البيانات.',
                      style: txt(12, color: p.inkFaint, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // key بمعرّف الطبق يعيد تهيئة الحقول إن تغيّر الطبق
            _BasicsCard(key: _basics, dish: d, categories: categories, currency: restaurant.currency),
            const SizedBox(height: 14),
            // ============ الحالة ============
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('الحالة', style: heading(16, color: p.ink)),
                  const SizedBox(height: 8),
                  ToggleRow(
                    label: 'متوفّر اليوم',
                    hint: 'عند الإطفاء يظهر الطبق معلَّمًا «نفد» ولا يُطلب.',
                    value: d.isAvailable,
                    onChanged: (v) => store.updateDish(d.id, (x) => x.isAvailable = v),
                  ),
                  Divider(height: 18, color: p.line),
                  ToggleRow(
                    label: 'طبق مميّز',
                    hint: 'يُعلَّم «الأكثر طلبًا» في منيو العميل.',
                    value: d.isFeatured,
                    onChanged: (v) => store.updateDish(d.id, (x) => x.isFeatured = v),
                  ),
                  Divider(height: 18, color: p.line),
                  ToggleRow(
                    label: 'اسمح بملاحظة من العميل',
                    hint: 'مثل «بدون بصل» أو «حار زيادة».',
                    value: d.allowNote,
                    onChanged: (v) => store.updateDish(d.id, (x) => x.allowNote = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ============ الخيارات والإضافات ============
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('الخيارات والإضافات', style: heading(16, color: p.ink)),
                      ),
                      Text(ltr('${dish.groups.length}'), style: txt(13, color: p.inkFaint)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '«اختيار واحد» للأحجام ودرجة الاستواء — يختار العميل واحدًا فقط. «اختيار متعدد» للإضافات المدفوعة. فرق السعر يُضاف على سعر الطبق، ويقبل السالب.',
                    style: txt(12.5, color: p.inkFaint, height: 1.65),
                  ),
                  const SizedBox(height: 12),
                  for (final group in dish.groups)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GroupEditor(
                        key: ValueKey(group.id),
                        group: group,
                        basePrice: d.price,
                        currency: restaurant.currency,
                      ),
                    ),
                  _AddGroupForm(dishId: d.id),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SurfaceCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('سعر العميل', style: heading(16, color: p.ink)),
                        Text('أقل سعر ممكن بعد الخيارات المبدئية', style: txt(12.5, color: p.inkFaint)),
                      ],
                    ),
                  ),
                  MoneyText(
                    cheapest,
                    currency: restaurant.currency,
                    style: heading(22, color: p.saffron),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'احذف الطبق',
              icon: Icons.delete_outline_rounded,
              tone: BtnTone.danger,
              expand: true,
              onPressed: () => _delete(d),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(Dish d) async {
    final ok = await confirmAction(
      context,
      title: 'حذف «${d.name}»',
      body: 'سيُحذف الطبق وكل خياراته. إن كان نافدًا مؤقتًا فأطفئ «متوفّر اليوم» بدل الحذف.',
    );
    if (!ok || !mounted) return;
    final store = context.read<DataStore>();
    Navigator.of(context).pop();
    store.deleteDish(d.id);
    toast('حُذف الطبق');
  }
}

/* ===================== الأساسيات ===================== */

class _BasicsCard extends StatefulWidget {
  const _BasicsCard({super.key, required this.dish, required this.categories, required this.currency});

  final Dish dish;
  final List<Category> categories;
  final String currency;

  @override
  State<_BasicsCard> createState() => _BasicsCardState();
}

class _BasicsCardState extends State<_BasicsCard> {
  late final _name = TextEditingController(text: widget.dish.name);
  late final _description = TextEditingController(text: widget.dish.description);
  late final _price = TextEditingController(text: formatNumber(widget.dish.price));
  late final _compare = TextEditingController(
    text: widget.dish.compareAtPrice == null ? '' : formatNumber(widget.dish.compareAtPrice!),
  );
  bool dirty = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _description, _price, _compare]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    final changed =
        _name.text != widget.dish.name ||
        _description.text != widget.dish.description ||
        _price.text != formatNumber(widget.dish.price) ||
        _compare.text != (widget.dish.compareAtPrice == null ? '' : formatNumber(widget.dish.compareAtPrice!));
    if (changed != dirty) setState(() => dirty = changed);
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _price, _compare]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    final compareText = _compare.text.trim();
    final compare = compareText.isEmpty ? null : parseAmount(compareText);
    if (compareText.isNotEmpty && compare == null) return toastError('السعر قبل الخفض غير صحيح');
    final price = parseAmount(_price.text) ?? double.nan;
    final result = context.store.updateDish(widget.dish.id, (d) {
      d.name = _name.text.trim();
      d.description = _description.text.trim();
      d.price = price;
      d.compareAtPrice = compare;
    });
    if (!result.ok) return toastError(result.error!);
    setState(() => dirty = false);
    toast('حُفظت التعديلات');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('الأساسيات', style: heading(16, color: p.ink)),
              ),
              if (dirty) const Tag('تغييرات غير محفوظة', tone: Tone.ember, dense: true),
            ],
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'اسم الطبق',
            child: AppTextField(controller: _name),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'الوصف',
            hint: 'سطر واحد يشرح المكوّنات — يقرأه العميل تحت الاسم.',
            child: AppTextField(controller: _description, maxLines: 4, minLines: 2),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LabeledField(
                  label: 'السعر',
                  child: AppTextField(
                    controller: _price,
                    ltr: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  label: 'السعر قبل الخفض',
                  hint: 'اتركه فارغًا إن لا يوجد عرض.',
                  child: AppTextField(
                    controller: _compare,
                    hint: '—',
                    ltr: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'القسم',
            child: DropdownButtonFormField<String>(
              initialValue: widget.dish.categoryId,
              isExpanded: true,
              borderRadius: BorderRadius.circular(Radii.md),
              items: [for (final c in widget.categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (id) {
                if (id == null || id == widget.dish.categoryId) return;
                context.store.moveDishToCategory(widget.dish.id, id);
                toast('نُقل الطبق');
              },
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'احفظ التغييرات',
            icon: Icons.save_outlined,
            tone: BtnTone.primary,
            onPressed: dirty ? _save : null,
          ),
        ],
      ),
    );
  }
}

/* ===================== مجموعة خيارات ===================== */

class _GroupEditor extends StatelessWidget {
  const _GroupEditor({super.key, required this.group, required this.basePrice, required this.currency});

  final GroupWithOptions group;
  final double basePrice;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final store = context.read<DataStore>();
    final single = group.type == OptionGroupType.single;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: p.surface2.withValues(alpha: .5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.md)),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CommitField(
                        value: group.name,
                        bare: true,
                        semanticLabel: 'اسم المجموعة',
                        style: txt(15, color: p.ink, weight: FontWeight.w700),
                        onCommit: (v) {
                          if (v.trim().length < 2) return toastError('اكتب اسم المجموعة');
                          store.updateOptionGroup(group.id, (g) => g.name = v.trim());
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'احذف المجموعة',
                      icon: Icon(Icons.delete_outline_rounded, color: p.sumac),
                      onPressed: () async {
                        final ok = await confirmAction(
                          context,
                          title: 'حذف «${group.name}»',
                          body: 'ستُحذف المجموعة وكل خياراتها.',
                        );
                        if (!ok) return;
                        store.deleteOptionGroup(group.id);
                        toast('حُذفت المجموعة');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Segmented<OptionGroupType>(
                        value: group.type,
                        options: const [
                          (OptionGroupType.single, 'اختيار واحد'),
                          (OptionGroupType.multi, 'اختيار متعدد'),
                        ],
                        onChanged: (t) => store.updateOptionGroup(group.id, (g) => g.type = t),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      onTap: () => store.updateOptionGroup(group.id, (g) {
                        g.isRequired = !g.isRequired;
                        g.minSelect = g.isRequired ? (g.minSelect < 1 ? 1 : g.minSelect) : 0;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        child: Row(
                          children: [
                            CheckDot(selected: group.isRequired),
                            const SizedBox(width: 6),
                            Text(
                              'إجباري',
                              style: txt(13.5, color: p.inkSoft, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (!single) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.maxSelect == 0 ? 'حد أعلى للاختيار: بلا حد' : 'حد أعلى للاختيار',
                          style: txt(13, color: p.inkSoft),
                        ),
                      ),
                      NumberStepper(
                        value: group.maxSelect,
                        min: 0,
                        max: 20,
                        compact: true,
                        onChanged: (v) => store.updateOptionGroup(group.id, (g) => g.maxSelect = v),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (group.options.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('لا خيارات بعد. أضف أول خيار من الأسفل.', style: txt(12.5, color: p.inkFaint)),
            )
          else
            for (final (i, option) in group.options.indexed) ...[
              if (i > 0) Divider(height: 1, color: p.line),
              _OptionRow(option: option, single: single, basePrice: basePrice, currency: currency),
            ],
          _AddOption(groupId: group.id),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.single, required this.basePrice, required this.currency});

  final DishOption option;
  final bool single;
  final double basePrice;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final store = context.read<DataStore>();
    final negative = option.priceDelta < 0;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 2, 4),
      child: Row(
        children: [
          if (single)
            Tooltip(
              message: 'الخيار المبدئي',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => store.updateOption(option.id, (o) => o.isDefault = true),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: RadioDot(selected: option.isDefault, size: 18),
                ),
              ),
            ),
          Expanded(
            child: CommitField(
              value: option.name,
              bare: true,
              semanticLabel: 'اسم الخيار',
              onCommit: (v) {
                if (v.trim().isEmpty) return toastError('اكتب اسم الخيار');
                store.updateOption(option.id, (o) => o.name = v.trim());
              },
            ),
          ),
          // زر الإشارة: زيادة أم خصم
          Tooltip(
            message: negative ? 'اجعله زيادة' : 'اجعله خصمًا',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => store.updateOption(option.id, (o) => o.priceDelta = -o.priceDelta),
              child: Container(
                width: 30,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: negative ? p.basilTint : p.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  negative ? '−' : '+',
                  style: txt(17, color: negative ? p.basil : p.inkSoft, weight: FontWeight.w700, height: 1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 66,
            child: CommitField(
              value: formatNumber(option.priceDelta.abs()),
              ltr: true,
              semanticLabel: 'فرق السعر',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onCommit: (v) {
                final amount = parseAmount(v);
                if (amount == null) return toastError('اكتب فرق سعر صحيحًا');
                store.updateOption(option.id, (o) => o.priceDelta = round2((negative ? -1 : 1) * amount.abs()));
              },
            ),
          ),
          IconButton(
            tooltip: 'احذف الخيار',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 18, color: p.inkFaint),
            onPressed: () => store.deleteOption(option.id),
          ),
        ],
      ),
    );
  }
}

class _AddOption extends StatefulWidget {
  const _AddOption({required this.groupId});

  final String groupId;

  @override
  State<_AddOption> createState() => _AddOptionState();
}

class _AddOptionState extends State<_AddOption> {
  final _name = TextEditingController();
  final _delta = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _delta.dispose();
    super.dispose();
  }

  void _submit() {
    final deltaText = _delta.text.trim();
    final delta = deltaText.isEmpty ? 0.0 : parseAmount(deltaText);
    final result = context.store.addOption(widget.groupId, name: _name.text, priceDelta: delta);
    if (!result.ok) return toastError(result.error!);
    _name.clear();
    _delta.clear();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface2.withValues(alpha: .3),
        border: Border(top: BorderSide(color: p.line)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(Radii.md)),
      ),
      padding: const EdgeInsets.all(8),
      child: ListenableBuilder(
        listenable: _name,
        builder: (context, _) => Row(
          children: [
            Expanded(
              flex: 5,
              child: AppTextField(
                controller: _name,
                hint: 'خيار جديد — مثال: كبير',
                dense: true,
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 3,
              child: AppTextField(
                controller: _delta,
                hint: 'فرق السعر',
                dense: true,
                ltr: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 6),
            IconBtn(
              icon: Icons.add_rounded,
              tooltip: 'أضف الخيار',
              size: 42,
              color: _name.text.trim().isNotEmpty ? p.saffron : null,
              onPressed: _name.text.trim().isNotEmpty ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddGroupForm extends StatefulWidget {
  const _AddGroupForm({required this.dishId});

  final String dishId;

  @override
  State<_AddGroupForm> createState() => _AddGroupFormState();
}

class _AddGroupFormState extends State<_AddGroupForm> {
  final _name = TextEditingController();
  var _type = OptionGroupType.single;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final single = _type == OptionGroupType.single;
    final result = context.store.addOptionGroup(
      widget.dishId,
      name: _name.text,
      type: _type,
      isRequired: single,
      minSelect: single ? 1 : 0,
      maxSelect: single ? 1 : 0,
    );
    if (!result.ok) return toastError(result.error!);
    _name.clear();
    FocusScope.of(context).unfocus();
    toast('أُضيفت المجموعة');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CustomPaint(
      painter: DashedBorderPainter(color: p.lineStrong, radius: Radii.md),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ListenableBuilder(
          listenable: _name,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _name,
                hint: 'اسم مجموعة جديدة — مثال: الحجم',
                dense: true,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              Segmented<OptionGroupType>(
                value: _type,
                options: const [(OptionGroupType.single, 'اختيار واحد'), (OptionGroupType.multi, 'اختيار متعدد')],
                onChanged: (t) => setState(() => _type = t),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'أضف مجموعة',
                icon: Icons.add_rounded,
                size: BtnSize.sm,
                onPressed: _name.text.trim().length >= 2
                    ? () {
                        HapticFeedback.selectionClick();
                        _submit();
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// مكان الصورة الفارغ: دعوة واضحة للإضافة بدل حرف ضخم
class _NoPhoto extends StatelessWidget {
  const _NoPhoto({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface2.withValues(alpha: .7),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(color: p.saffronTint, shape: BoxShape.circle),
              child: Icon(Icons.add_a_photo_outlined, color: p.saffron, size: 27),
            ),
            const SizedBox(height: 10),
            Text(
              'أضف صورة للطبق',
              style: txt(15, color: p.ink, weight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text('الأطباق المصوّرة تجذب الطلب أكثر', style: txt(12.5, color: p.inkFaint)),
          ],
        ),
      ),
    );
  }
}
