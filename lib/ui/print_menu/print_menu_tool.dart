import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/export.dart';
import '../../core/feedback.dart';
import '../../core/images.dart';
import '../../core/theme.dart';
import '../../data/arabic.dart';
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
import '../common/inputs.dart';
import '../common/sheets.dart';
import 'menu_sheet.dart';
import 'paginate.dart';

const _defaultTitle = 'قائمة الطعام';

/// دقة الصورة المصدّرة: 3 × 96 = 288 نقطة/إنش — كافية للمطبعة
const _exportScale = 3.0;

/* ===================== الإعدادات ===================== */

/// إعدادات الطباعة تفضيل على هذا الجهاز، لا بيانات مطعم — نفس مفاتيح الموقع
class PrintSettings {
  const PrintSettings({
    this.style = PrintStyle.classic,
    this.columns = 2,
    this.logoSize = LogoSize.md,
    this.title,
    this.tagline,
    this.note,
    this.showDescriptions = true,
    this.showImages = true,
    this.showOptions = true,
    this.showQR = true,
    this.showPhone = true,
    this.includeUnavailable = true,
  });

  final PrintStyle style;
  final int columns;
  final LogoSize logoSize;

  /// null = النص الافتراضي المأخوذ من بيانات المطعم
  final String? title;
  final String? tagline;
  final String? note;
  final bool showDescriptions;
  final bool showImages;
  final bool showOptions;
  final bool showQR;
  final bool showPhone;
  final bool includeUnavailable;

  factory PrintSettings.fromMap(Map<String, Object?> m) => PrintSettings(
    style: PrintStyle.values.where((s) => s.name == m['style']).firstOrNull ?? PrintStyle.classic,
    columns: m['columns'] == 1 ? 1 : 2,
    logoSize: LogoSize.values.where((s) => s.name == m['logoSize']).firstOrNull ?? LogoSize.md,
    title: m['title'] as String?,
    tagline: m['tagline'] as String?,
    note: m['note'] as String?,
    showDescriptions: m['showDescriptions'] as bool? ?? true,
    showImages: m['showImages'] as bool? ?? true,
    showOptions: m['showOptions'] as bool? ?? true,
    showQR: m['showQR'] as bool? ?? true,
    showPhone: m['showPhone'] as bool? ?? true,
    includeUnavailable: m['includeUnavailable'] as bool? ?? true,
  );

  Map<String, Object?> toMap() => {
    'style': style.name,
    'columns': columns,
    'logoSize': logoSize.name,
    'title': title,
    'tagline': tagline,
    'note': note,
    'showDescriptions': showDescriptions,
    'showImages': showImages,
    'showOptions': showOptions,
    'showQR': showQR,
    'showPhone': showPhone,
    'includeUnavailable': includeUnavailable,
  };
}

PrintSettings _read(AppPrefs prefs, String restaurantId) => PrintSettings.fromMap(prefs.printSettings(restaurantId));

void _update(AppPrefs prefs, String restaurantId, Map<String, Object?> patch) =>
    prefs.setPrintSettings(restaurantId, {...prefs.printSettings(restaurantId), ...patch});

String _defaultNote(Restaurant r) {
  if (r.taxRate <= 0) return '';
  return r.taxIncluded
      ? 'جميع الأسعار شاملة ضريبة القيمة المضافة'
      : 'تُضاف ضريبة القيمة المضافة ${formatNumber(r.taxRate)}٪ إلى الأسعار';
}

String _signed(double n) => '${n > 0 ? '+' : '−'}${formatNumber(round2(n.abs()))}';

/// الورق لا يفتح نافذة خيارات، فتُكتب الخيارات تحت الطبق.
/// أول مجموعة إجبارية بفروق سعر (الحجم غالبًا) تُكتب بأسعارها الكاملة
/// «صغير 28 · كبير 40»، وما عداها بفرق السعر «جبنة +4».
List<OptionLine> _describeOptions(DB db, Dish dish) {
  var absoluteUsed = false;
  return [
    for (final group in getOptionGroups(db, dish.id))
      if (getOptions(db, group.id) case final options when options.isNotEmpty)
        () {
          final priced = options.any((o) => o.priceDelta != 0);
          final absolute = group.type == OptionGroupType.single && group.isRequired && priced && !absoluteUsed;
          if (absolute) absoluteUsed = true;
          return OptionLine(group.name, [
            for (final o in options)
              (
                name: o.name,
                price: absolute
                    ? formatNumber(round2(dish.price + o.priceDelta))
                    : o.priceDelta == 0
                    ? null
                    : _signed(o.priceDelta),
              ),
          ]);
        }(),
  ];
}

List<PrintSection> _buildSections(DB db, String restaurantId, PrintSettings s) => [
  for (final section in getMenu(db, restaurantId, visibleOnly: true))
    if (PrintSection(
          id: section.category.id,
          name: section.category.name,
          dishes: [
            for (final dish in section.dishes)
              if (s.includeUnavailable || dish.isAvailable)
                PrintDish(
                  id: dish.id,
                  name: dish.name,
                  description: dish.description,
                  price: dish.price,
                  featured: dish.isFeatured,
                  image: s.showImages ? dish.imageUrl : null,
                  options: s.showOptions ? _describeOptions(db, dish) : const [],
                ),
          ],
        )
        case final printSection when printSection.dishes.isNotEmpty)
      printSection,
];

String _pagesLabel(int n) => countOf(n, nPage);

/* ===================== الأداة ===================== */

class PrintMenuTool extends StatefulWidget {
  const PrintMenuTool({super.key});

  @override
  State<PrintMenuTool> createState() => _PrintMenuToolState();
}

class _PrintMenuToolState extends State<PrintMenuTool> {
  final _keys = MeasureKeys();
  final _pager = PageController(viewportFraction: .9);
  int _page = 0;

  /// الخطة مع الإعدادات التي قيست بها — المعاينة تُرسم بها دائمًا، فلا
  /// تُعرض خطة قديمة على إعدادات جديدة (عمودان على صفحة بعمود واحد مثلًا)
  ({List<PagePlan> plan, SheetContext ctx, SheetLookup lookup, Object sig})? _planned;
  Object? _scheduled;
  String? _busy;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  /// القياس بعد رسم الإطار: نسخة غير مرئية من كل كتلة، ثم التوزيع
  void _schedulePlan(Object signature, SheetContext ctx, List<PrintSection> sections) {
    if (signature == _scheduled) return;
    _scheduled = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || signature != _scheduled) return;
      final plan = measurePages(_keys, sections, ctx.columns);
      setState(() {
        _planned = (plan: plan, ctx: ctx, lookup: SheetLookup(sections), sig: signature);
        if (_page >= plan.length) _page = 0;
      });
    });
  }

  Future<List<Uint8List>> _render(SheetContext ctx, List<PagePlan> plan, SheetLookup lookup, List<int> indexes) async {
    // الصور تُفكّ مسبقًا فتظهر في الصورة المصدّرة من أول رسم
    final providers = [?dataImage(ctx.logo), for (final d in lookup.dishes.values) ?dataImage(d.image)];
    for (final provider in providers) {
      await precacheImage(provider, context);
    }
    final out = <Uint8List>[];
    for (final (n, i) in indexes.indexed) {
      setState(() => _busy = indexes.length > 1 ? 'جارٍ التجهيز ${n + 1} من ${indexes.length}…' : 'جارٍ التجهيز…');
      out.add(
        await renderToPng(
          MenuPage(ctx: ctx, plan: plan[i], index: i, total: plan.length, lookup: lookup),
          width: pageW,
          height: pageH,
          pixelRatio: _exportScale,
        ),
      );
    }
    return out;
  }

  Future<void> _print(SheetContext ctx, List<PagePlan> plan, SheetLookup lookup, String name) async {
    try {
      final pngs = await _render(ctx, plan, lookup, [for (var i = 0; i < plan.length; i++) i]);
      setState(() => _busy = 'جارٍ فتح الطباعة…');
      final pdf = await imagesToPdf(pngs, format: PdfPageFormat.a4);
      await printPdf(pdf, name: 'منيو $name');
    } catch (e) {
      toastError('تعذّر تجهيز الطباعة — حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _share(SheetContext ctx, List<PagePlan> plan, SheetLookup lookup, String slug, List<int> indexes) async {
    try {
      final pngs = await _render(ctx, plan, lookup, indexes);
      await shareFiles([
        for (final (n, png) in pngs.indexed)
          (png, plan.length > 1 ? '$slug-menu-${indexes[n] + 1}.png' : '$slug-menu.png'),
      ], mime: 'image/png');
    } catch (e) {
      toastError('تعذّر تجهيز الصورة — حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RestaurantBuilder(
      builder: (context, db, restaurant, profile) {
        final p = context.palette;
        final prefs = context.watch<AppPrefs>();
        final settings = _read(prefs, restaurant.id);
        final sections = _buildSections(db, restaurant.id, settings);
        final ctx = SheetContext(
          style: settings.style,
          t: makeTokens(settings.style, restaurant.themeColor),
          name: restaurant.name,
          logo: restaurant.logoUrl,
          logoSize: settings.logoSize,
          title: settings.title ?? _defaultTitle,
          tagline: settings.tagline ?? restaurant.description,
          note: settings.note ?? _defaultNote(restaurant),
          phone: settings.showPhone ? restaurant.phone : '',
          qr: settings.showQR ? AppConfig.menuUrl(restaurant.slug) : null,
          currency: restaurant.currency,
          columns: settings.columns,
          showDescriptions: settings.showDescriptions,
        );
        // التوقيع: لقطة البيانات مع الإعدادات — أي تغيير فيهما يعيد القياس
        final signature = (db, prefs.printSettings(restaurant.id).toString());
        _schedulePlan(signature, ctx, sections);
        final planned = _planned;
        final plan = planned?.plan;
        final ready = planned != null && planned.sig == signature && planned.plan.isNotEmpty && _busy == null;

        return Stack(
          children: [
            // نسخة القياس: تُرسم خارج الشاشة ولا تُرى
            Positioned(
              left: 0,
              top: 0,
              width: contentW,
              child: Offstage(
                child: MenuMeasurer(ctx: ctx, sections: sections, keys: _keys),
              ),
            ),
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan == null
                                    ? 'جارٍ ترتيب الصفحات…'
                                    : '${_pagesLabel(plan.length)} · A4 · ${settings.style.label}',
                                style: txt(13.5, color: p.ink, weight: FontWeight.w700),
                              ),
                              Text(
                                'منيو للطباعة من أطباقك الحالية — يتحدّث تلقائيًا كلما عدّلت المنيو.',
                                style: txt(12, color: p.inkFaint),
                              ),
                            ],
                          ),
                        ),
                        if (plan != null && plan.length > 1)
                          IconButton(
                            tooltip: 'شارك هذه الصفحة',
                            onPressed: ready
                                ? () => _share(planned.ctx, plan, planned.lookup, restaurant.slug, [
                                    _page.clamp(0, plan.length - 1),
                                  ])
                                : null,
                            icon: const Icon(Icons.ios_share_rounded),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: plan == null
                        ? const LoadingView(label: 'جارٍ ترتيب الصفحات')
                        : plan.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: EmptyState(
                                title: 'لا أطباق للطباعة',
                                body: 'أضف أطباقًا من «المنيو»، أو أظهر الأقسام المخفية، ثم عد إلى هنا.',
                                icon: Icons.menu_book_outlined,
                                action: AppButton(
                                  label: 'افتح المنيو',
                                  onPressed: () => context.read<NavState>().open(ToolId.menu),
                                ),
                              ),
                            ),
                          )
                        : PageView.builder(
                            controller: _pager,
                            itemCount: plan.length,
                            onPageChanged: (i) => setState(() => _page = i),
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: pageW / pageH,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: p.isDark ? .5 : .16),
                                          blurRadius: 18,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: FittedBox(
                                        child: MenuPage(
                                          ctx: planned!.ctx,
                                          plan: plan[i],
                                          index: i,
                                          total: plan.length,
                                          lookup: planned.lookup,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  if (plan != null && plan.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < plan.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _page ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == _page ? p.saffron : p.lineStrong,
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                        ],
                      ),
                    ),
                  // التخصيص في ألواح خفيفة تُبقي المعاينة ظاهرة فوقها
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      children: [
                        _SettingChip(
                          icon: Icons.palette_outlined,
                          label: 'التصميم',
                          onTap: () => _designSheet(context, restaurant.id),
                        ),
                        _SettingChip(
                          icon: Icons.image_outlined,
                          label: 'الشعار',
                          onTap: () => _logoSheet(context, restaurant.id),
                        ),
                        _SettingChip(
                          icon: Icons.text_fields_rounded,
                          label: 'النصوص',
                          onTap: () => _textsSheet(context, restaurant),
                        ),
                        _SettingChip(
                          icon: Icons.checklist_rounded,
                          label: 'المحتوى',
                          onTap: () => _contentSheet(context, restaurant.id),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: p.surface,
                      border: Border(top: BorderSide(color: p.line)),
                    ),
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.paddingOf(context).bottom),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: _busy ?? 'اطبع أو احفظ PDF',
                            icon: Icons.print_rounded,
                            tone: BtnTone.primary,
                            busy: _busy != null,
                            onPressed: ready ? () => _print(planned.ctx, plan!, planned.lookup, restaurant.name) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppButton(
                          label: plan != null && plan.length > 1 ? 'الصور (${plan.length})' : 'صورة',
                          icon: Icons.ios_share_rounded,
                          onPressed: ready
                              ? () => _share(planned.ctx, plan!, planned.lookup, restaurant.slug, [
                                  for (var i = 0; i < plan.length; i++) i,
                                ])
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SettingChip extends StatelessWidget {
  const _SettingChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
          side: BorderSide(color: p.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(icon, size: 18, color: p.saffron),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: txt(13.5, color: p.ink, weight: FontWeight.w600, height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================== ألواح التخصيص ===================== */

/// لوح بخلفية شبه شفافة — المعاينة تبقى ظاهرة وتتحدّث خلفه
Future<void> _sheet(BuildContext context, String title, WidgetBuilder builder) => showAppSheet<void>(
  context,
  title: title,
  maxHeightFactor: .62,
  barrierColor: Colors.black.withValues(alpha: .12),
  builder: builder,
);

Future<void> _designSheet(BuildContext context, String restaurantId) => _sheet(context, 'التصميم', (c) {
  final prefs = c.watch<AppPrefs>();
  final restaurant = sessionOf(c.watchDb()).restaurant;
  final s = _read(prefs, restaurantId);
  final p = c.palette;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final style in PrintStyle.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _StyleTile(
            style: style,
            brand: restaurant?.themeColor ?? '#a96a00',
            selected: s.style == style,
            onTap: () => _update(prefs, restaurantId, {'style': style.name}),
          ),
        ),
      const SizedBox(height: 6),
      Text(
        'الترتيب',
        style: txt(13.5, color: p.ink, weight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Segmented<int>(
        value: s.columns,
        options: const [(2, 'عمودان'), (1, 'عمود واحد')],
        onChanged: (v) => _update(prefs, restaurantId, {'columns': v}),
      ),
      const SizedBox(height: 10),
      Text('اللون من الإعدادات ← اللون الأساسي.', style: txt(12, color: p.inkFaint)),
    ],
  );
});

class _StyleTile extends StatelessWidget {
  const _StyleTile({required this.style, required this.brand, required this.selected, required this.onTap});

  final PrintStyle style;
  final String brand;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tk = makeTokens(style, brand);
    // صفحة مصغّرة بألوان القالب الفعلية
    final mini = Container(
      width: 38,
      height: 50,
      decoration: BoxDecoration(
        color: tk.bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tk.line),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: style == PrintStyle.modern ? tk.band : tk.accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < 4; i++)
            Container(
              height: 2,
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              color: tk.muted.withValues(alpha: .55),
            ),
        ],
      ),
    );
    return Material(
      color: selected ? p.saffronTint : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: selected ? p.saffron : p.line, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              mini,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.label,
                      style: txt(14.5, color: selected ? p.saffron : p.ink, weight: FontWeight.w700),
                    ),
                    Text(style.hint, style: txt(12.5, color: p.inkFaint)),
                  ],
                ),
              ),
              RadioDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _logoSheet(BuildContext context, String restaurantId) => _sheet(context, 'الشعار', (c) {
  final prefs = c.watch<AppPrefs>();
  final restaurant = sessionOf(c.watchDb()).restaurant;
  final s = _read(prefs, restaurantId);
  final p = c.palette;
  if (restaurant == null) return const SizedBox.shrink();
  final logo = dataImage(restaurant.logoUrl);
  Future<void> upload(ImageSource source) async {
    try {
      final url = await pickImageAsDataUrl(source: source, maxWidth: 800, quality: 90);
      if (url == null || !c.mounted) return;
      c.read<DataStore>().updateRestaurant(restaurant.id, (r) => r.logoUrl = url);
      toast('رُفع الشعار');
    } catch (_) {
      toastError('تعذّر رفع الشعار');
    }
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: p.line),
            ),
            child: logo != null
                ? Image(image: logo, fit: BoxFit.contain)
                : const Icon(Icons.image_outlined, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  label: restaurant.logoUrl == null ? 'ارفع شعارًا' : 'استبدل',
                  icon: Icons.photo_library_outlined,
                  size: BtnSize.sm,
                  onPressed: () => upload(ImageSource.gallery),
                ),
                if (restaurant.logoUrl != null)
                  AppButton(
                    label: 'احذف',
                    size: BtnSize.sm,
                    tone: BtnTone.ghost,
                    onPressed: () => c.read<DataStore>().updateRestaurant(restaurant.id, (r) => r.logoUrl = null),
                  ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'هو نفسه شعار منيوك الرقمي. أجمل نتيجة من صورة PNG بخلفية شفافة.${restaurant.logoUrl == null ? ' بدون شعار يظهر أول حرف من اسم المطعم.' : ''}',
        style: txt(12, color: p.inkFaint, height: 1.6),
      ),
      const SizedBox(height: 14),
      Text(
        'حجم الشعار',
        style: txt(13.5, color: p.ink, weight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Segmented<LogoSize>(
        value: s.logoSize,
        options: const [(LogoSize.sm, 'صغير'), (LogoSize.md, 'وسط'), (LogoSize.lg, 'كبير')],
        onChanged: (v) => _update(prefs, restaurantId, {'logoSize': v.name}),
      ),
    ],
  );
});

Future<void> _textsSheet(BuildContext context, Restaurant restaurant) {
  final prefs = context.read<AppPrefs>();
  final s = _read(prefs, restaurant.id);
  final title = TextEditingController(text: s.title ?? _defaultTitle);
  final tagline = TextEditingController(text: s.tagline ?? restaurant.description);
  final note = TextEditingController(text: s.note ?? _defaultNote(restaurant));
  return _sheet(context, 'النصوص', (c) {
    final p = c.palette;
    final current = _read(c.watch<AppPrefs>(), restaurant.id);
    final changed = current.title != null || current.tagline != null || current.note != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: 'العنوان',
          child: AppTextField(
            controller: title,
            hint: _defaultTitle,
            onChanged: (v) => _update(prefs, restaurant.id, {'title': v}),
          ),
        ),
        const SizedBox(height: 12),
        LabeledField(
          label: 'سطر تحت اسم المطعم',
          child: AppTextField(
            controller: tagline,
            hint: 'مثال: مشاوي على الفحم منذ ١٩٩٥',
            onChanged: (v) => _update(prefs, restaurant.id, {'tagline': v}),
          ),
        ),
        const SizedBox(height: 12),
        LabeledField(
          label: 'ملاحظة أسفل كل صفحة',
          child: AppTextField(
            controller: note,
            hint: 'مثال: نقبل الدفع بالبطاقة · التوصيل مجاني فوق ١٠٠',
            maxLines: 3,
            minLines: 2,
            onChanged: (v) => _update(prefs, restaurant.id, {'note': v}),
          ),
        ),
        if (changed) ...[
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('استرجع الافتراضي'),
              style: TextButton.styleFrom(foregroundColor: p.saffron),
              onPressed: () {
                _update(prefs, restaurant.id, {'title': null, 'tagline': null, 'note': null});
                title.text = _defaultTitle;
                tagline.text = restaurant.description;
                note.text = _defaultNote(restaurant);
              },
            ),
          ),
        ],
      ],
    );
  });
}

Future<void> _contentSheet(BuildContext context, String restaurantId) => _sheet(context, 'المحتوى', (c) {
  final prefs = c.watch<AppPrefs>();
  final db = c.watchDb();
  final restaurant = sessionOf(db).restaurant;
  final s = _read(prefs, restaurantId);
  final p = c.palette;
  final withImages = db.dishes.where((d) => d.restaurantId == restaurantId && d.imageUrl != null).length;
  final phone = restaurant?.phone ?? '';
  void set(String key, bool v) => _update(prefs, restaurantId, {key: v});
  Widget divider() => Divider(height: 18, color: p.line);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ToggleRow(
        label: 'صور الأطباق',
        hint: withImages > 0
            ? 'الأطباق المصوّرة: $withImages — ما لا صورة له يُطبع بدونها'
            : 'لا صور بعد — ارفعها من «المنيو» عند تعديل الطبق',
        value: s.showImages && withImages > 0,
        enabled: withImages > 0,
        onChanged: (v) => set('showImages', v),
      ),
      divider(),
      ToggleRow(label: 'وصف الأطباق', value: s.showDescriptions, onChanged: (v) => set('showDescriptions', v)),
      divider(),
      ToggleRow(
        label: 'الأحجام والإضافات بأسعارها',
        hint: 'تُكتب تحت الطبق، فالورق لا يعرض نافذة الخيارات',
        value: s.showOptions,
        onChanged: (v) => set('showOptions', v),
      ),
      divider(),
      ToggleRow(
        label: 'رمز QR للمنيو الرقمي',
        hint: 'يفتح منيوك على الجوال للطلب مباشرة',
        value: s.showQR,
        onChanged: (v) => set('showQR', v),
      ),
      divider(),
      ToggleRow(
        label: 'رقم الهاتف',
        hint: phone.isEmpty ? 'أضف رقمًا من الإعدادات أولًا' : null,
        value: s.showPhone && phone.isNotEmpty,
        enabled: phone.isNotEmpty,
        onChanged: (v) => set('showPhone', v),
      ),
      divider(),
      ToggleRow(
        label: 'الأطباق النافدة حاليًا',
        hint: 'الورق يبقى طويلًا، والنفاد غالبًا مؤقت',
        value: s.includeUnavailable,
        onChanged: (v) => set('includeUnavailable', v),
      ),
    ],
  );
});
