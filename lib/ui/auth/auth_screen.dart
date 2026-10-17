import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../data/mutations.dart';
import '../../data/queries.dart';
import '../../data/seed.dart';
import '../../data/store.dart';
import '../../data/utils.dart';
import '../common/basics.dart';
import '../common/brand.dart';
import '../common/buttons.dart';
import '../common/inputs.dart';
import '../common/sheets.dart';
import '../storefront/storefront_page.dart';

enum _Mode { login, signup }

/// الدخول والتسجيل بالجوال وكلمة المرور — نفس حسابات الموقع وقواعده.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  var _mode = _Mode.login;

  final _phone = TextEditingController();
  final _password = TextEditingController();

  final _owner = TextEditingController();
  final _restaurant = TextEditingController();
  final _slug = TextEditingController();
  final _signupPhone = TextEditingController();
  final _signupPassword = TextEditingController();
  bool _slugTouched = false;

  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _restaurant.addListener(() {
      if (!_slugTouched) _slug.text = slugify(_restaurant.text);
    });
  }

  @override
  void dispose() {
    for (final c in [_phone, _password, _owner, _restaurant, _slug, _signupPhone, _signupPassword]) {
      c.dispose();
    }
    super.dispose();
  }

  void _login() {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _busy = true;
    });
    final store = context.read<DataStore>();
    final result = store.signIn(_phone.text, _password.text);
    if (!result.ok) {
      setState(() {
        _error = result.error;
        _busy = false;
      });
      HapticFeedback.heavyImpact();
      return;
    }
    TextInput.finishAutofillContext();
    final name = getSessionProfile(store.db)?.name.split(' ').first ?? '';
    toast('أهلًا $name', icon: Icons.waving_hand_rounded);
  }

  void _signup() {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _busy = true;
    });
    final store = context.read<DataStore>();
    final result = store.signUp(
      SignUpInput(
        ownerName: _owner.text,
        restaurantName: _restaurant.text,
        phone: _signupPhone.text,
        password: _signupPassword.text,
        slug: _slugTouched ? _slug.text : _restaurant.text,
      ),
    );
    if (!result.ok) {
      setState(() {
        _error = result.error;
        _busy = false;
      });
      HapticFeedback.heavyImpact();
      return;
    }
    TextInput.finishAutofillContext();
    toast('أُنشئ حساب مطعمك — ابدأ ببناء المنيو', icon: Icons.celebration_rounded);
  }

  void _fill(DemoAccount account) {
    HapticFeedback.selectionClick();
    setState(() {
      _mode = _Mode.login;
      _phone.text = account.phone;
      _password.text = account.password;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: Stack(
        children: [
          // توهّج زعفراني خفيف أعلى الشاشة — مثل صفحة الدخول في الموقع
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -1.1),
                  radius: 1.1,
                  colors: [
                    p.saffron.withValues(alpha: p.isDark ? .16 : .13),
                    p.paper,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: Wordmark(size: 38)),
                      const SizedBox(height: 14),
                      Text(
                        'منيو مطعمك على الجوال،\nوالطلبات على شاشة واحدة.',
                        textAlign: TextAlign.center,
                        style: heading(20, color: p.ink, height: 1.45),
                      ),
                      const SizedBox(height: 22),
                      SurfaceCard(
                        padding: const EdgeInsets.all(18),
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Segmented<_Mode>(
                                value: _mode,
                                onChanged: (m) => setState(() {
                                  _mode = m;
                                  _error = null;
                                }),
                                options: const [(_Mode.login, 'تسجيل الدخول'), (_Mode.signup, 'سجّل مطعمك')],
                              ),
                              const SizedBox(height: 18),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: _mode == _Mode.login ? _loginForm() : _signupForm(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _DemoCard(onPick: _fill),
                      const SizedBox(height: 14),
                      AppButton(
                        label: 'تصفّح منيو كعميل',
                        icon: Icons.storefront_rounded,
                        expand: true,
                        onPressed: () => openGuestStorefront(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 14),
          child: AlertBox(_error!, icon: Icons.error_outline_rounded),
        );

  Widget _loginForm() {
    final p = context.palette;
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: 'رقم الجوال',
          child: AppTextField(
            controller: _phone,
            hint: '05xxxxxxxx',
            ltr: true,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_iphone_rounded,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
          ),
        ),
        const SizedBox(height: 14),
        LabeledField(
          label: 'كلمة المرور',
          child: PasswordField(
            controller: _password,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _login(),
          ),
        ),
        _errorBox(),
        const SizedBox(height: 18),
        AppButton(
          label: _busy ? 'جارٍ الدخول…' : 'دخول',
          tone: BtnTone.primary,
          size: BtnSize.lg,
          expand: true,
          busy: _busy,
          onPressed: _login,
        ),
        const SizedBox(height: 12),
        Text(
          'نسيت كلمة المرور؟ لا توجد قناة استعادة في هذه المرحلة لأن التسجيل بالجوال بلا رسائل SMS — يعيد مشرف المنصة تعيينها لك.',
          textAlign: TextAlign.center,
          style: txt(12, color: p.inkFaint, height: 1.7),
        ),
      ],
    );
  }

  Widget _signupForm() {
    final p = context.palette;
    return Column(
      key: const ValueKey('signup'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('دقيقة واحدة، ويصير عندك منيو برابط خاص.', style: txt(13.5, color: p.inkSoft)),
        const SizedBox(height: 14),
        LabeledField(
          label: 'اسمك',
          child: AppTextField(
            controller: _owner,
            hint: 'مثال: خالد العمري',
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
          ),
        ),
        const SizedBox(height: 14),
        LabeledField(
          label: 'اسم المطعم',
          child: AppTextField(
            controller: _restaurant,
            hint: 'مثال: الركن الشامي',
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 14),
        LabeledField(
          label: 'رابط المنيو',
          hint: 'هذا الرابط يمسحه عملاؤك من رمز QR. يمكن تعديله لاحقًا من الإعدادات.',
          child: SlugField(controller: _slug, onChanged: (_) => _slugTouched = true),
        ),
        const SizedBox(height: 14),
        LabeledField(
          label: 'رقم الجوال',
          hint: 'هو معرّف دخولك للوحة التحكم.',
          child: AppTextField(
            controller: _signupPhone,
            hint: '05xxxxxxxx',
            ltr: true,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_iphone_rounded,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
          ),
        ),
        const SizedBox(height: 14),
        LabeledField(
          label: 'كلمة المرور',
          hint: '٦ أحرف على الأقل. احفظها — لا توجد استعادة تلقائية بعد.',
          child: PasswordField(
            controller: _signupPassword,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _signup(),
          ),
        ),
        _errorBox(),
        const SizedBox(height: 18),
        AppButton(
          label: _busy ? 'جارٍ إنشاء الحساب…' : 'أنشئ الحساب',
          tone: BtnTone.primary,
          size: BtnSize.lg,
          expand: true,
          busy: _busy,
          onPressed: _signup,
        ),
      ],
    );
  }
}

/// حقل رابط المنيو: البادئة ثابتة والرابط يُنظَّف أثناء الكتابة
class SlugField extends StatelessWidget {
  const SlugField({super.key, required this.controller, this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.url,
        autocorrect: false,
        style: txt(15, color: p.ink),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
          TextInputFormatter.withFunction((old, next) => next.copyWith(text: next.text.toLowerCase())),
        ],
        decoration: InputDecoration(
          hintText: 'al-rukn',
          prefixIcon: Container(
            margin: const EdgeInsetsDirectional.only(end: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            width: 50,
            decoration: BoxDecoration(
              color: p.surface2,
              border: Border(right: BorderSide(color: p.line)),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(Radii.md)),
            ),
            child: Text('/m/', style: txt(13, color: p.inkFaint)),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
        ),
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.onPick});

  final ValueChanged<DemoAccount> onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface2.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 17, color: p.saffron),
              const SizedBox(width: 6),
              Text(
                'حسابات للتجربة',
                style: txt(13.5, color: p.ink, weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'هذا نموذج مبدئي، فالحسابات جاهزة. اضغط أيًّا منها لتعبئة الحقول.',
            style: txt(12, color: p.inkFaint, height: 1.6),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final account in demoAccounts)
                AppButton(label: account.label, size: BtnSize.sm, onPressed: () => onPick(account)),
            ],
          ),
        ],
      ),
    );
  }
}

/// يفتح منيو مطعم كعميل بلا حساب: مطعم واحد يُفتح مباشرة، وأكثر يُختار
/// من قائمة، أو يُلصق رابط منيو.
Future<void> openGuestStorefront(BuildContext context) async {
  final db = context.read<DataStore>().db;
  final active = db.restaurants.where((r) => r.isActive).toList();
  if (active.length == 1) {
    await Navigator.of(context).push(storefrontRoute(active.first.slug));
    return;
  }
  final link = TextEditingController();
  final picked = await showAppSheet<({String slug, String? token})>(
    context,
    title: 'اختر المطعم',
    subtitle: 'المطاعم المحفوظة على هذا الجهاز',
    builder: (c) {
      final p = c.palette;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in active)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: () => Navigator.pop(c, (slug: r.slug, token: null)),
                child: Row(
                  children: [
                    DishThumb(name: r.name, label: brandInitial(r.name), src: r.logoUrl, size: 42, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: txt(15, color: p.ink, weight: FontWeight.w700),
                          ),
                          Text(ltr('/m/${r.slug}'), style: txt(12, color: p.inkFaint)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: p.inkFaint),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          LabeledField(
            label: 'أو الصق رابط منيو',
            child: AppTextField(
              controller: link,
              hint: '${AppConfig.siteUrl}/m/…',
              ltr: true,
              keyboardType: TextInputType.url,
              onSubmitted: (v) {
                final parsed = AppConfig.parseMenuLink(v);
                if (parsed != null) Navigator.pop(c, parsed);
              },
            ),
          ),
        ],
      );
    },
  );
  if (picked == null || !context.mounted) return;
  final exists = getRestaurantBySlug(context.read<DataStore>().db, picked.slug) != null;
  if (!exists) {
    toastError('لا يوجد مطعم بهذا الرابط على هذا الجهاز');
    return;
  }
  // رابط طاولة (…?t=رمز) يفتح المنيو والطاولة محدّدة كما لو مُسح رمزها
  await Navigator.of(context).push(storefrontRoute(picked.slug, tableToken: picked.token));
}
