import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/colors.dart';
import '../../core/export.dart';
import '../../core/feedback.dart';
import '../../core/images.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/mutations.dart';
import '../../data/store.dart';
import '../../data/utils.dart';
import '../../state/nav.dart';
import '../../state/session.dart';
import '../auth/auth_screen.dart' show SlugField;
import '../common/basics.dart';
import '../common/buttons.dart';
import '../common/inputs.dart';
import '../common/sheets.dart';

const _swatches = [
  ('#a96a00', 'زعفران'),
  ('#0e6b4f', 'زعتر'),
  ('#8c2f39', 'سماق'),
  ('#1f4e79', 'نيلي'),
  ('#5b3a8e', 'توت'),
  ('#2c2c2c', 'فحمي'),
];

const _templates = [
  (MenuTemplate.classic, 'كلاسيكي', 'صف لكل طبق مع صورة صغيرة — الأنسب للمنيو الطويل'),
  (MenuTemplate.gallery, 'معرض', 'بطاقات بصور كبيرة — يبرز الصور الجيدة'),
  (MenuTemplate.compact, 'مضغوط', 'أسماء وأسعار بلا صور — الأسرع تصفّحًا'),
];

/// الإعدادات — مقابل /dashboard/settings في الموقع
class SettingsTool extends StatelessWidget {
  const SettingsTool({super.key});

  @override
  Widget build(BuildContext context) {
    return RestaurantBuilder(
      builder: (context, db, restaurant, profile) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // key بمعرّف المطعم يعيد تهيئة الحقول إن تبدّل المطعم
          _InfoCard(key: ValueKey(restaurant.id), restaurant: restaurant),
          const SizedBox(height: 14),
          _LookCard(restaurant: restaurant),
          const SizedBox(height: 14),
          _TaxCard(restaurant: restaurant),
          const SizedBox(height: 14),
          _OrderTypesCard(restaurant: restaurant),
          const SizedBox(height: 14),
          _HoursCard(restaurant: restaurant),
          const SizedBox(height: 14),
          _PasswordCard(profile: profile),
          const SizedBox(height: 14),
          const _DataCard(),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title, {this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: heading(16, color: p.ink)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: txt(12.5, color: p.inkFaint, height: 1.6)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/* ===================== معلومات المطعم ===================== */

class _InfoCard extends StatefulWidget {
  const _InfoCard({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  State<_InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<_InfoCard> {
  late final _name = TextEditingController(text: widget.restaurant.name);
  late final _description = TextEditingController(text: widget.restaurant.description);
  late final _slug = TextEditingController(text: widget.restaurant.slug);
  late final _phone = TextEditingController(text: widget.restaurant.phone);
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _description, _slug, _phone]) {
      c.addListener(() {
        final r = widget.restaurant;
        final changed =
            _name.text != r.name ||
            _description.text != r.description ||
            _slug.text != r.slug ||
            _phone.text != r.phone;
        if (changed != _dirty) setState(() => _dirty = changed);
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _slug, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final r = widget.restaurant;
    if (_name.text.trim().length < 2) return toastError('اكتب اسم المطعم');
    if (slugify(_slug.text) != r.slug) {
      final ok = await confirmAction(
        context,
        title: 'تغيير رابط المنيو',
        body: 'تغيير الرابط يُبطل كل رموز QR المطبوعة — ستحتاج طباعتها من جديد. هل تريد المتابعة؟',
        confirmLabel: 'غيّر الرابط',
      );
      if (!ok || !mounted) return;
    }
    final result = context.store.updateRestaurant(r.id, (x) {
      x.name = _name.text.trim();
      x.description = _description.text.trim();
      x.slug = _slug.text;
      x.phone = _phone.text.trim();
    });
    if (!result.ok) return toastError(result.error!);
    setState(() => _dirty = false);
    toast('حُفظت التعديلات');
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            'معلومات المطعم',
            trailing: _dirty ? const Tag('تغييرات غير محفوظة', tone: Tone.ember, dense: true) : null,
          ),
          LabeledField(
            label: 'اسم المطعم',
            child: AppTextField(controller: _name),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'وصف قصير',
            hint: 'سطر يظهر تحت الاسم في المنيو.',
            child: AppTextField(controller: _description, hint: 'مشاوي ومقبلات شامية على أصولها'),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'رابط المنيو',
            hint: 'تغييره يُبطل كل رموز QR المطبوعة — ستحتاج طباعتها من جديد.',
            child: SlugField(controller: _slug),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'رقم تواصل المطعم',
            hint: 'يظهر للعميل في صفحة متابعة الطلب.',
            child: AppTextField(controller: _phone, ltr: true, keyboardType: TextInputType.phone),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'احفظ التغييرات',
            icon: Icons.save_outlined,
            tone: BtnTone.primary,
            onPressed: _dirty ? _save : null,
          ),
        ],
      ),
    );
  }
}

/* ===================== شكل المنيو ===================== */

class _LookCard extends StatelessWidget {
  const _LookCard({required this.restaurant});

  final Restaurant restaurant;

  Future<void> _upload(BuildContext context, {required bool cover}) async {
    final source = await _pickSource(context);
    if (source == null || !context.mounted) return;
    final store = context.read<DataStore>();
    try {
      final url = cover
          ? await pickImageAsDataUrl(source: source, maxWidth: 1200, quality: 70)
          : await pickImageAsDataUrl(source: source, maxWidth: 800, quality: 90);
      if (url == null) return;
      store.updateRestaurant(restaurant.id, (r) => cover ? r.coverUrl = url : r.logoUrl = url);
      toast('رُفعت الصورة');
    } catch (_) {
      toastError('تعذّر فتح الصورة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final store = context.read<DataStore>();
    final brand = parseHex(restaurant.themeColor);
    final cover = dataImage(restaurant.coverUrl);
    final isCustom = !_swatches.any((s) => s.$1.toLowerCase() == restaurant.themeColor.toLowerCase());

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle('شكل المنيو'),
          Text(
            'اللوجو',
            style: txt(13.5, color: p.ink, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              DishThumb(
                name: restaurant.name,
                label: brandInitial(restaurant.name),
                src: restaurant.logoUrl,
                size: 68,
                radius: 18,
              ),
              const SizedBox(width: 12),
              AppButton(
                label: restaurant.logoUrl == null ? 'ارفع' : 'استبدل',
                icon: Icons.image_outlined,
                size: BtnSize.sm,
                onPressed: () => _upload(context, cover: false),
              ),
              if (restaurant.logoUrl != null) ...[
                const SizedBox(width: 8),
                AppButton(
                  label: 'احذف',
                  size: BtnSize.sm,
                  tone: BtnTone.ghost,
                  onPressed: () => store.updateRestaurant(restaurant.id, (r) => r.logoUrl = null),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text('أجمل نتيجة من صورة PNG بخلفية شفافة.', style: txt(12, color: p.inkFaint)),
          const SizedBox(height: 18),
          Text(
            'صورة الغلاف',
            style: txt(13.5, color: p.ink, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md),
            child: SizedBox(
              height: 96,
              child: cover != null
                  ? Image(image: cover, fit: BoxFit.cover)
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: AlignmentDirectional.topStart,
                          end: AlignmentDirectional.bottomEnd,
                          colors: [brand, mixOklab(brand, Colors.black, .65)],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              AppButton(
                label: restaurant.coverUrl == null ? 'ارفع' : 'استبدل',
                icon: Icons.image_outlined,
                size: BtnSize.sm,
                onPressed: () => _upload(context, cover: true),
              ),
              if (restaurant.coverUrl != null) ...[
                const SizedBox(width: 8),
                AppButton(
                  label: 'احذف',
                  size: BtnSize.sm,
                  tone: BtnTone.ghost,
                  onPressed: () => store.updateRestaurant(restaurant.id, (r) => r.coverUrl = null),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'اللون الأساسي',
            style: txt(13.5, color: p.ink, weight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (hex, label) in _swatches)
                _Swatch(
                  color: parseHex(hex),
                  label: label,
                  selected: restaurant.themeColor.toLowerCase() == hex,
                  onTap: () => store.updateRestaurant(restaurant.id, (r) => r.themeColor = hex),
                ),
              _Swatch(
                color: isCustom ? brand : null,
                label: 'مخصّص',
                selected: isCustom,
                onTap: () async {
                  final hex = await showColorPicker(context, initial: brand);
                  if (hex == null) return;
                  store.updateRestaurant(restaurant.id, (r) => r.themeColor = hex);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('تُرفع إضاءة اللون تلقائيًا في المظهر الليلي حتى يبقى مقروءًا.', style: txt(12, color: p.inkFaint)),
          const SizedBox(height: 18),
          Text(
            'قالب المنيو',
            style: txt(13.5, color: p.ink, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final (value, label, hint) in _templates)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TemplateTile(
                template: value,
                label: label,
                hint: hint,
                selected: restaurant.template == value,
                brand: brand,
                onTap: () => store.updateRestaurant(restaurant.id, (r) => r.template = value),
              ),
            ),
        ],
      ),
    );
  }
}

Future<ImageSource?> _pickSource(BuildContext context) => showAppSheet<ImageSource>(
  context,
  title: 'اختر الصورة من',
  builder: (c) => Column(
    children: [
      ListTile(
        leading: const Icon(Icons.photo_library_outlined),
        title: const Text('المعرض'),
        onTap: () => Navigator.pop(c, ImageSource.gallery),
      ),
      ListTile(
        leading: const Icon(Icons.photo_camera_outlined),
        title: const Text('الكاميرا'),
        onTap: () => Navigator.pop(c, ImageSource.camera),
      ),
    ],
  ),
);

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label, required this.selected, required this.onTap});

  final Color? color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? p.ink : Colors.transparent, width: 2),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  gradient: color == null
                      ? const SweepGradient(
                          colors: [
                            Colors.red,
                            Colors.orange,
                            Colors.yellow,
                            Colors.green,
                            Colors.blue,
                            Colors.purple,
                            Colors.red,
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: txt(11, color: selected ? p.ink : p.inkFaint, weight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.label,
    required this.hint,
    required this.selected,
    required this.brand,
    required this.onTap,
  });

  final MenuTemplate template;
  final String label;
  final String hint;
  final bool selected;
  final Color brand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget bar(double w, [Color? c]) => Container(
      width: w,
      height: 3,
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(color: c ?? p.lineStrong, borderRadius: BorderRadius.circular(2)),
    );
    // معاينة مصغّرة لشكل القالب
    final preview = Container(
      width: 46,
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.line),
      ),
      child: switch (template) {
        MenuTemplate.classic => Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(18), bar(12, brand)]),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(3)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        MenuTemplate.gallery => GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(3)),
              ),
          ],
        ),
        MenuTemplate.compact => Column(
          children: [
            for (var i = 0; i < 6; i++)
              Row(
                children: [
                  Expanded(child: bar(20)),
                  const SizedBox(width: 3),
                  bar(6, brand),
                ],
              ),
          ],
        ),
      },
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
              preview,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: txt(14.5, color: selected ? p.saffron : p.ink, weight: FontWeight.w700),
                    ),
                    Text(hint, style: txt(12.5, color: p.inkFaint, height: 1.5)),
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

/// منتقي لون: درجة اللون والتشبّع والإضاءة، أو رمز hex مباشرة
Future<String?> showColorPicker(BuildContext context, {required Color initial}) {
  var hsl = HSLColor.fromColor(initial);
  final hexController = TextEditingController(text: toHex(initial));
  return showAppSheet<String>(
    context,
    title: 'لون مخصّص',
    subtitle: 'اختر لونًا يمثّل مطعمك — يظهر في المنيو والأزرار',
    builder: (c) => StatefulBuilder(
      builder: (c, setSheet) {
        final p = c.palette;
        final color = hsl.toColor();
        void update(HSLColor next) {
          setSheet(() => hsl = next);
          hexController.text = toHex(next.toColor());
        }

        Widget slider(String label, double value, double max, ValueChanged<double> onChanged, List<Color> track) =>
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  style: txt(13, color: p.inkSoft, weight: FontWeight.w600),
                ),
                SizedBox(
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 12,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          gradient: LinearGradient(colors: track),
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(c).copyWith(
                          trackHeight: 0,
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          thumbColor: Colors.white,
                          overlayColor: Colors.black12,
                        ),
                        child: Slider(value: value, max: max, onChanged: onChanged),
                      ),
                    ],
                  ),
                ),
              ],
            );

        final readable = contrastRatio(color, Colors.white) >= 3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.md)),
              child: Text(
                'أضف للسلة',
                style: heading(17, color: readable ? Colors.white : const Color(0xFF18201A), weight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 14),
            slider('درجة اللون', hsl.hue, 360, (v) => update(hsl.withHue(v)), [
              for (var h = 0; h <= 360; h += 60) HSLColor.fromAHSL(1, h.toDouble(), .7, .45).toColor(),
            ]),
            slider('التشبّع', hsl.saturation, 1, (v) => update(hsl.withSaturation(v)), [
              hsl.withSaturation(0).toColor(),
              hsl.withSaturation(1).toColor(),
            ]),
            slider('الإضاءة', hsl.lightness, 1, (v) => update(hsl.withLightness(v)), [
              Colors.black,
              hsl.withLightness(.5).toColor(),
              Colors.white,
            ]),
            const SizedBox(height: 6),
            LabeledField(
              label: 'رمز اللون',
              child: AppTextField(
                controller: hexController,
                ltr: true,
                hint: '#a96a00',
                onChanged: (v) {
                  if (RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(v.trim())) {
                    setSheet(() => hsl = HSLColor.fromColor(parseHex(v)));
                  }
                },
              ),
            ),
            if (!readable) ...[
              const SizedBox(height: 10),
              const AlertBox('لون فاتح: سيُكتب النص فوقه داكنًا حتى يُقرأ.', tone: Tone.ember),
            ],
          ],
        );
      },
    ),
    footer: (c) =>
        FilledButton(onPressed: () => Navigator.pop(c, toHex(hsl.toColor())), child: const Text('استخدم هذا اللون')),
  );
}

/* ===================== العملة والضريبة ===================== */

class _TaxCard extends StatelessWidget {
  const _TaxCard({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final store = context.read<DataStore>();
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle('العملة والضريبة'),
          LabeledField(
            label: 'العملة',
            child: DropdownButtonFormField<String>(
              initialValue: currencies.any((c) => c.code == restaurant.currency) ? restaurant.currency : null,
              isExpanded: true,
              borderRadius: BorderRadius.circular(Radii.md),
              menuMaxHeight: 420,
              items: [
                for (final c in currencies) DropdownMenuItem(value: c.code, child: Text('${c.label} (${c.symbol})')),
              ],
              onChanged: (code) {
                if (code == null) return;
                store.updateRestaurant(restaurant.id, (r) => r.currency = code);
                toast('صارت العملة ${currencies.firstWhere((c) => c.code == code).label}');
              },
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'نسبة الضريبة %',
            hint: 'صفر = بلا ضريبة.',
            child: CommitField(
              value: formatNumber(restaurant.taxRate),
              ltr: true,
              dense: false,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onCommit: (v) {
                final rate = parseAmount(v);
                if (rate == null || rate < 0 || rate > 100) return toastError('اكتب نسبة بين 0 و 100');
                store.updateRestaurant(restaurant.id, (r) => r.taxRate = rate);
                toast('حُفظت نسبة الضريبة');
              },
            ),
          ),
          const SizedBox(height: 10),
          ToggleRow(
            label: 'الأسعار المكتوبة شاملة الضريبة',
            hint: restaurant.taxIncluded
                ? 'تُستخرج الضريبة من السعر المعروض — العميل يدفع السعر المكتوب.'
                : 'تُضاف الضريبة فوق السعر المعروض في الفاتورة.',
            value: restaurant.taxIncluded,
            onChanged: (v) => store.updateRestaurant(restaurant.id, (r) => r.taxIncluded = v),
          ),
        ],
      ),
    );
  }
}

/* ===================== أنواع الطلب ===================== */

class _OrderTypesCard extends StatelessWidget {
  const _OrderTypesCard({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final store = context.read<DataStore>();
    final none = !restaurant.dineInEnabled && !restaurant.pickupEnabled && !restaurant.deliveryEnabled;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle('أنواع الطلب', subtitle: 'شغّل ما يناسب مطعمك وأطفئ الباقي.'),
          ToggleRow(
            label: 'الطلب من الطاولة',
            hint: 'يحتاج طاولات ورموز QR مطبوعة عليها.',
            value: restaurant.dineInEnabled,
            onChanged: (v) => store.updateRestaurant(restaurant.id, (r) => r.dineInEnabled = v),
          ),
          Divider(height: 18, color: p.line),
          ToggleRow(
            label: 'الاستلام من المطعم',
            hint: 'يطلب العميل من جواله ويجي يستلم.',
            value: restaurant.pickupEnabled,
            onChanged: (v) => store.updateRestaurant(restaurant.id, (r) => r.pickupEnabled = v),
          ),
          Divider(height: 18, color: p.line),
          ToggleRow(
            label: 'التوصيل',
            hint: 'يُطلب من العميل عنوانه، وتُضاف رسوم التوصيل للفاتورة.',
            value: restaurant.deliveryEnabled,
            onChanged: (v) => store.updateRestaurant(restaurant.id, (r) => r.deliveryEnabled = v),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (restaurant.deliveryEnabled) ...[
                Expanded(
                  child: LabeledField(
                    label: 'رسوم التوصيل',
                    child: CommitField(
                      value: formatNumber(restaurant.deliveryFee),
                      ltr: true,
                      dense: false,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onCommit: (v) {
                        final fee = parseAmount(v);
                        if (fee == null || fee < 0) return toastError('اكتب رسومًا صحيحة');
                        store.updateRestaurant(restaurant.id, (r) => r.deliveryFee = fee);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: LabeledField(
                  label: 'الحد الأدنى للطلب',
                  hint: 'على كل الطلبات. صفر = بلا حد.',
                  child: CommitField(
                    value: formatNumber(restaurant.minOrder),
                    ltr: true,
                    dense: false,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onCommit: (v) {
                      final min = parseAmount(v);
                      if (min == null || min < 0) return toastError('اكتب مبلغًا صحيحًا');
                      store.updateRestaurant(restaurant.id, (r) => r.minOrder = min);
                    },
                  ),
                ),
              ),
            ],
          ),
          if (none) ...[
            const SizedBox(height: 12),
            const AlertBox('كل الأنواع مطفأة — لا يستطيع أي عميل إرسال طلب الآن.', icon: Icons.warning_amber_rounded),
          ],
        ],
      ),
    );
  }
}

/* ===================== أوقات العمل ===================== */

class _HoursCard extends StatelessWidget {
  const _HoursCard({required this.restaurant});

  final Restaurant restaurant;

  Future<void> _pickTime(BuildContext context, int day, {required bool open}) async {
    final hour = restaurant.workingHours[day];
    final parts = (open ? hour.open : hour.close).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 11,
        minute: int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0,
      ),
      helpText: open ? 'وقت الافتتاح — ${dayNames[day]}' : 'وقت الإغلاق — ${dayNames[day]}',
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null || !context.mounted) return;
    final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    _set(context, day, (h) => open ? h.open = value : h.close = value);
  }

  void _set(BuildContext context, int day, void Function(WorkingHour h) patch) {
    context.read<DataStore>().updateRestaurant(restaurant.id, (r) => patch(r.workingHours[day]));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final today = jsDay(DateTime.now());
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            'أوقات العمل',
            subtitle:
                'خارج هذه الأوقات يظهر المنيو «مغلق الآن» ولا تُستقبل الطلبات. الدوام الممتد بعد منتصف الليل مدعوم — اختر مثلًا من 17:00 إلى 02:00.',
          ),
          for (final (day, hour) in restaurant.workingHours.indexed) ...[
            if (day > 0) Divider(height: 1, color: p.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: Text(
                      dayNames[day],
                      style: txt(14, color: p.ink, weight: day == today ? FontWeight.w800 : FontWeight.w600),
                    ),
                  ),
                  Switch(value: !hour.closed, onChanged: (v) => _set(context, day, (h) => h.closed = !v)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: hour.closed
                        ? Text('مغلق طول اليوم', style: txt(13, color: p.inkFaint))
                        : Row(
                            children: [
                              Expanded(
                                child: _TimeChip(value: hour.open, onTap: () => _pickTime(context, day, open: true)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text('—', style: txt(13, color: p.inkFaint)),
                              ),
                              Expanded(
                                child: _TimeChip(value: hour.close, onTap: () => _pickTime(context, day, open: false)),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface2.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(Radii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            ltr(value),
            textAlign: TextAlign.center,
            style: txt(14, color: p.ink, weight: FontWeight.w600).copyWith(fontFeatures: tabular),
          ),
        ),
      ),
    );
  }
}

/* ===================== كلمة المرور ===================== */

class _PasswordCard extends StatefulWidget {
  const _PasswordCard({required this.profile});

  final Profile profile;

  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  final _current = TextEditingController();
  final _next = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: ListenableBuilder(
        listenable: Listenable.merge([_current, _next]),
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardTitle(
              'كلمة المرور',
              subtitle:
                  'لا توجد استعادة تلقائية في هذه المرحلة — احفظ كلمة مرورك في مكان آمن. إن فقدتها فمشرف المنصة هو من يعيد تعيينها.',
            ),
            LabeledField(
              label: 'كلمة المرور الحالية',
              child: PasswordField(controller: _current),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'كلمة المرور الجديدة',
              hint: '٦ أحرف على الأقل.',
              child: PasswordField(controller: _next),
            ),
            const SizedBox(height: 14),
            AppButton(
              label: 'غيّر كلمة المرور',
              icon: Icons.lock_reset_rounded,
              onPressed: _current.text.isNotEmpty && _next.text.length >= 6
                  ? () {
                      final result = context.store.changePassword(widget.profile.id, _current.text, _next.text);
                      if (!result.ok) return toastError(result.error!);
                      _current.clear();
                      _next.clear();
                      FocusScope.of(context).unfocus();
                      toast('تغيّرت كلمة المرور');
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/* ===================== البيانات ===================== */

class _DataCard extends StatelessWidget {
  const _DataCard();

  Future<void> _backup(BuildContext context) async {
    final store = context.read<DataStore>();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    await shareBytes(utf8.encode(store.exportJson()), filename: 'sufra-backup-$date.json', mime: 'application/json');
  }

  Future<void> _restore(BuildContext context) async {
    final store = context.read<DataStore>();
    final nav = context.read<NavState>();
    final file = await FilePicker.pickFile(dialogTitle: 'اختر ملف النسخة الاحتياطية');
    if (file == null || !context.mounted) return;
    final ok = await confirmAction(
      context,
      title: 'استعادة نسخة احتياطية',
      body:
          'ستُستبدل كل البيانات على هذا الجهاز بما في الملف — المطاعم والمنيو والطلبات والحسابات. تقبل النسخة المنزّلة من الموقع أيضًا. قد تحتاج لتسجيل الدخول من جديد.',
      confirmLabel: 'استعد النسخة',
    );
    if (!ok) return;
    try {
      final text = utf8.decode(await file.readAsBytes());
      nav.goHome();
      store.importJson(text);
      toast('استُعيدت النسخة');
    } catch (_) {
      toastError('الملف ليس نسخة صالحة');
    }
  }

  Future<void> _reset(BuildContext context) async {
    final store = context.read<DataStore>();
    final nav = context.read<NavState>();
    final ok = await confirmAction(
      context,
      title: 'إعادة البيانات التجريبية',
      body:
          'سيُمحى كل ما أنشأته — المطاعم والمنيو والطلبات والحسابات — ويرجع المطعم التجريبي كما كان، ثم تعود لشاشة الدخول. لا رجوع بعد التأكيد.',
      confirmLabel: 'امحُ وأعد التجريبي',
    );
    if (!ok) return;
    nav.unbind();
    store.reset();
    toast('رجعت البيانات التجريبية');
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            'البيانات',
            subtitle:
                'في هذه المرحلة كل البيانات محفوظة على هذا الجهاز وحده. إن حذفت التطبيق فقدتها، فاحفظ نسخة احتياطية قبل أي تجربة كبيرة — والنسخة تنتقل بين التطبيق والموقع.',
          ),
          AppButton(
            label: 'احفظ نسخة احتياطية',
            icon: Icons.cloud_download_outlined,
            expand: true,
            onPressed: () => _backup(context),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'استعد نسخة',
            icon: Icons.restore_page_outlined,
            expand: true,
            onPressed: () => _restore(context),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'أعد البيانات التجريبية',
            icon: Icons.delete_sweep_outlined,
            tone: BtnTone.danger,
            expand: true,
            onPressed: () => _reset(context),
          ),
        ],
      ),
    );
  }
}
