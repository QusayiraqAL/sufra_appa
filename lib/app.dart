import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/feedback.dart';
import 'core/theme.dart';
import 'data/cart.dart';
import 'data/models.dart';
import 'data/queries.dart';
import 'data/store.dart';
import 'state/nav.dart';
import 'state/prefs.dart';
import 'ui/auth/auth_screen.dart';
import 'ui/shell/app_shell.dart';

/// جذر التطبيق: المزوّدات، الثيم العربي (RTL)، وبوابة الدخول.
class SufraApp extends StatelessWidget {
  const SufraApp({super.key, required this.store, required this.prefs, required this.carts});

  final DataStore store;
  final AppPrefs prefs;
  final CartRegistry carts;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider(create: (_) => NavState(prefs)),
        Provider.value(value: carts),
      ],
      child: Selector<AppPrefs, ThemeMode>(
        selector: (_, p) => p.themeMode,
        builder: (context, themeMode, _) => MaterialApp(
          title: 'سُفرة',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          theme: buildTheme(Palette.light),
          darkTheme: buildTheme(Palette.dark),
          themeMode: themeMode,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // خط الجوال المكبّر محترَم حتى الضعف — أقصى ما يتيحه أندرويد، وكل الشاشات
          // مختبرة عنده (TEXT_SCALE=2 في اختبار المسار الكامل)
          builder: (context, child) =>
              MediaQuery.withClampedTextScaling(maxScaleFactor: 2, child: _SaveErrorListener(child: child!)),
          home: const RootGate(),
        ),
      ),
    );
  }
}

/// شاشة الدخول ما لم تكن هناك جلسة محفوظة، وإلا إطار الأدوات.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    // يُعاد البناء عند تغيّر الجلسة فقط، لا مع كل تعديل على البيانات
    final sessionId = context.select<DataStore, String?>((s) => getSessionProfile(s.db)?.id);
    final Profile? profile = sessionId == null ? null : getProfileById(context.read<DataStore>().db, sessionId);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      child: profile == null
          ? const AuthScreen(key: ValueKey('auth'))
          : AppShell(key: ValueKey(profile.id), profile: profile),
    );
  }
}

/// ينبّه إن تعذّر حفظ البيانات على الجهاز (مساحة ممتلئة مثلًا)
class _SaveErrorListener extends StatefulWidget {
  const _SaveErrorListener({required this.child});

  final Widget child;

  @override
  State<_SaveErrorListener> createState() => _SaveErrorListenerState();
}

class _SaveErrorListenerState extends State<_SaveErrorListener> with WidgetsBindingObserver {
  late final DataStore _store = context.read<DataStore>();

  @override
  void initState() {
    super.initState();
    _store.saveError.addListener(_onError);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _store.saveError.removeListener(_onError);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onError() {
    final message = _store.saveError.value;
    if (message == null) return;
    _store.saveError.value = null;
    toastError(message);
  }

  /// قبل أن يُغلق النظام التطبيق في الخلفية: أكمل أي حفظ معلّق
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) _store.flush();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
