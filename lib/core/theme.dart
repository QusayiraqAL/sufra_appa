import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// نظام التصميم — «زعفران وسماق»، منقول من globals.css في الموقع.
/// حبر أخضر داكن (زعتر) · لكنة زعفران · سماق للخطر · بازيليك للنجاح.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.isDark,
    required this.paper,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.saffron,
    required this.saffronHi,
    required this.saffronTint,
    required this.onSaffron,
    required this.sumac,
    required this.sumacTint,
    required this.basil,
    required this.basilTint,
    required this.ember,
    required this.emberTint,
    required this.chart1,
    required this.chartTrack,
    required this.chartGrid,
  });

  final bool isDark;

  // الأسطح
  final Color paper;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color lineStrong;

  // الحبر
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;

  // اللكنة — زعفران
  final Color saffron;
  final Color saffronHi;
  final Color saffronTint;
  final Color onSaffron;

  // دلالية
  final Color sumac;
  final Color sumacTint;
  final Color basil;
  final Color basilTint;
  final Color ember;
  final Color emberTint;

  /// لون علامات الرسوم — منفصل عن لكنة الواجهة عن قصد كما في الموقع
  final Color chart1;
  final Color chartTrack;
  final Color chartGrid;

  static const light = Palette(
    isDark: false,
    paper: Color(0xFFF5F6F2),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEF1EA),
    line: Color(0xFFDFE4DA),
    lineStrong: Color(0xFFC8D0C2),
    ink: Color(0xFF18201A),
    inkSoft: Color(0xFF5C6A61),
    inkFaint: Color(0xFF8B978F),
    saffron: Color(0xFFA96A00),
    saffronHi: Color(0xFF8D5800),
    saffronTint: Color(0xFFFBF0D8),
    onSaffron: Color(0xFFFFFFFF),
    sumac: Color(0xFFA32235),
    sumacTint: Color(0xFFFCECEE),
    basil: Color(0xFF2C6F4E),
    basilTint: Color(0xFFE6F2EB),
    ember: Color(0xFFB35410),
    emberTint: Color(0xFFFDEEE1),
    chart1: Color(0xFFA96A00),
    chartTrack: Color(0xFFEEF1EA),
    chartGrid: Color(0xFFE6EAE2),
  );

  static const dark = Palette(
    isDark: true,
    paper: Color(0xFF0F130F),
    surface: Color(0xFF171D18),
    surface2: Color(0xFF1E251F),
    line: Color(0xFF2A332C),
    lineStrong: Color(0xFF3B463D),
    ink: Color(0xFFE9EEE6),
    inkSoft: Color(0xFF9AA79E),
    inkFaint: Color(0xFF75817A),
    saffron: Color(0xFFE9AE3C),
    saffronHi: Color(0xFFF5C05A),
    saffronTint: Color(0xFF2B2313),
    onSaffron: Color(0xFF1A1405),
    sumac: Color(0xFFE8798A),
    sumacTint: Color(0xFF2E1A1D),
    basil: Color(0xFF5CB98A),
    basilTint: Color(0xFF14261D),
    ember: Color(0xFFEF9A55),
    emberTint: Color(0xFF2B1C11),
    chart1: Color(0xFFC08420),
    chartTrack: Color(0xFF232B24),
    chartGrid: Color(0xFF262F28),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => other is Palette && t > .5 ? other : this;
}

extension PaletteX on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}

/// خطا الموقع: Tajawal للعناوين و IBM Plex Sans Arabic للنصوص.
abstract final class Fonts {
  static const display = 'Tajawal';
  static const body = 'PlexArabic';
  static const serif = 'Amiri';
}

/// عنوان بخط Tajawal
TextStyle heading(double size, {Color? color, FontWeight weight = FontWeight.w800, double height = 1.3}) =>
    TextStyle(fontFamily: Fonts.display, fontSize: size, fontWeight: weight, color: color, height: height);

/// نص بخط IBM Plex Sans Arabic
TextStyle txt(double size, {Color? color, FontWeight weight = FontWeight.w400, double height = 1.6}) =>
    TextStyle(fontFamily: Fonts.body, fontSize: size, fontWeight: weight, color: color, height: height);

/// الأرقام بعرض ثابت — لصفوف القوائم حيث تتراصف الأرقام
const tabular = [FontFeature.tabularFigures()];

/// أنصاف الأقطار
abstract final class Radii {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
}

ThemeData buildTheme(Palette p) {
  final brightness = p.isDark ? Brightness.dark : Brightness.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.saffron,
    onPrimary: p.onSaffron,
    primaryContainer: p.saffronTint,
    onPrimaryContainer: p.saffron,
    secondary: p.basil,
    onSecondary: p.surface,
    secondaryContainer: p.basilTint,
    onSecondaryContainer: p.basil,
    tertiary: p.ember,
    onTertiary: p.surface,
    error: p.sumac,
    onError: p.surface,
    errorContainer: p.sumacTint,
    onErrorContainer: p.sumac,
    surface: p.surface,
    onSurface: p.ink,
    onSurfaceVariant: p.inkSoft,
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface2,
    surfaceContainerHigh: p.surface2,
    surfaceContainerHighest: p.surface2,
    outline: p.lineStrong,
    outlineVariant: p.line,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: p.ink,
    onInverseSurface: p.paper,
    inversePrimary: p.saffronHi,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: Fonts.body,
    scaffoldBackgroundColor: p.paper,
    canvasColor: p.surface,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    extensions: [p],
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.md),
    borderSide: BorderSide(color: c, width: w),
  );

  final buttonShape = WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)));
  final buttonText = WidgetStatePropertyAll(txt(15, weight: FontWeight.w600, height: 1.2));

  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: Fonts.body, bodyColor: p.ink, displayColor: p.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 4,
      titleTextStyle: heading(18, color: p.ink),
      iconTheme: IconThemeData(color: p.inkSoft),
      systemOverlayStyle: (p.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: p.surface,
        systemNavigationBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      isDense: false,
      hintStyle: txt(14.5, color: p.inkFaint),
      labelStyle: txt(14, color: p.inkSoft),
      floatingLabelStyle: txt(14, color: p.saffron, weight: FontWeight.w600),
      helperStyle: txt(12, color: p.inkFaint, height: 1.4),
      errorStyle: txt(12, color: p.sumac, weight: FontWeight.w500, height: 1.4),
      helperMaxLines: 3,
      errorMaxLines: 3,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(p.line),
      enabledBorder: border(p.line),
      focusedBorder: border(p.saffron, 1.6),
      errorBorder: border(p.sumac),
      focusedErrorBorder: border(p.sumac, 1.6),
      disabledBorder: border(p.line),
      prefixIconColor: p.inkFaint,
      suffixIconColor: p.inkFaint,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: buttonShape,
        textStyle: buttonText,
        minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? p.surface2 : p.saffron,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? p.inkFaint : p.onSaffron,
        ),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: buttonShape,
        textStyle: buttonText,
        minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? p.inkFaint : p.ink),
        backgroundColor: WidgetStatePropertyAll(p.surface),
        side: WidgetStatePropertyAll(BorderSide(color: p.lineStrong)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        shape: buttonShape,
        textStyle: WidgetStatePropertyAll(txt(14.5, weight: FontWeight.w600, height: 1.2)),
        foregroundColor: WidgetStatePropertyAll(p.saffron),
        minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(p.inkSoft),
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.line, space: 1, thickness: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.surface,
      showDragHandle: true,
      dragHandleColor: p.lineStrong,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
      titleTextStyle: heading(18, color: p.ink),
      contentTextStyle: txt(14.5, color: p.inkSoft, height: 1.7),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.isDark ? const Color(0xFFE9EEE6) : const Color(0xFF18201A),
      contentTextStyle: txt(14, weight: FontWeight.w600, color: p.isDark ? const Color(0xFF18201A) : Colors.white),
      actionTextColor: p.isDark ? p.saffronHi : const Color(0xFFE9AE3C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onSaffron : p.surface),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.saffron : p.surface2),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.saffron : p.lineStrong,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.saffron : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(p.onSaffron),
      side: BorderSide(color: p.lineStrong, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.saffron, linearTrackColor: p.surface2),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(8)),
      textStyle: txt(12.5, color: p.paper, weight: FontWeight.w500),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: p.surface, surfaceTintColor: Colors.transparent),
    listTileTheme: ListTileThemeData(
      iconColor: p.inkSoft,
      textColor: p.ink,
      titleTextStyle: txt(15, color: p.ink, weight: FontWeight.w600),
      subtitleTextStyle: txt(13, color: p.inkFaint),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: p.line),
      ),
      textStyle: txt(14.5, color: p.ink, weight: FontWeight.w500),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.saffron,
      selectionColor: p.saffron.withValues(alpha: .25),
      selectionHandleColor: p.saffron,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
