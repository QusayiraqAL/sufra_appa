import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تفضيلات هذا الجهاز — ليست بيانات مطعم، فلا تمرّ بطبقة البيانات التي
/// ستنتقل إلى الخادم لاحقًا (مثل مظهر الموقع sufra_theme في الموقع).
class AppPrefs extends ChangeNotifier {
  AppPrefs(this._prefs);

  final SharedPreferences? _prefs;

  static const _themeKey = 'sufra_theme';
  static const _chimeKey = 'sufra_chime';
  static const _awakeKey = 'sufra_keep_awake';
  static const _welcomeKey = 'sufra_welcomed';

  /* ---------- المظهر: نهاري / ليلي / النظام ---------- */

  ThemeMode get themeMode => switch (_prefs?.getString(_themeKey)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  set themeMode(ThemeMode mode) {
    if (mode == ThemeMode.system) {
      _prefs?.remove(_themeKey);
    } else {
      _prefs?.setString(_themeKey, mode == ThemeMode.dark ? 'dark' : 'light');
    }
    notifyListeners();
  }

  /* ---------- تنبيه الطلبات ---------- */

  /// التطبيق — بخلاف المتصفح — يستطيع تشغيل الصوت بلا ضغطة مسبقة،
  /// فالتنبيه مفعّل افتراضيًا.
  bool get chimeEnabled => _prefs?.getBool(_chimeKey) ?? true;

  set chimeEnabled(bool v) {
    _prefs?.setBool(_chimeKey, v);
    notifyListeners();
  }

  /// إبقاء الشاشة مضاءة في شاشة الطلبات — لجهاز الكاشير الثابت
  bool get keepAwake => _prefs?.getBool(_awakeKey) ?? false;

  set keepAwake(bool v) {
    _prefs?.setBool(_awakeKey, v);
    notifyListeners();
  }

  /* ---------- أول تشغيل ---------- */

  bool get welcomed => _prefs?.getBool(_welcomeKey) ?? false;

  void markWelcomed() {
    _prefs?.setBool(_welcomeKey, true);
    notifyListeners();
  }

  /* ---------- الأدوات المستخدمة مؤخرًا (لكل حساب) ---------- */

  List<String> recentTools(String profileId) => _prefs?.getStringList('sufra_recent_tools:$profileId') ?? const [];

  void setRecentTools(String profileId, List<String> tools) {
    _prefs?.setStringList('sufra_recent_tools:$profileId', tools);
  }

  /* ---------- إعدادات المنيو الورقي (لكل مطعم) ---------- */

  Map<String, Object?> printSettings(String restaurantId) {
    final raw = _prefs?.getString('sufra_print_v1:$restaurantId');
    if (raw == null) return const {};
    try {
      final parsed = jsonDecode(raw);
      return parsed is Map ? parsed.cast<String, Object?>() : const {};
    } catch (_) {
      return const {};
    }
  }

  void setPrintSettings(String restaurantId, Map<String, Object?> value) {
    _prefs?.setString('sufra_print_v1:$restaurantId', jsonEncode(value));
    notifyListeners();
  }
}
