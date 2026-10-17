import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'validation.dart';

/// السلة حالة عميل لا جدول في قاعدة البيانات، فتُخزّن منفصلة ولكل مطعم على
/// حدة (مثل `sufra_cart_v1:<slug>` في الموقع). تخزّن المعرّفات فقط — السعر
/// يُحسب عند العرض من الأسعار الحالية.
class CartStore extends ChangeNotifier {
  CartStore._(this.slug, this._prefs) {
    _load();
  }

  final String slug;
  final SharedPreferences? _prefs;

  List<CartLine> _lines = const [];
  String? _tableToken;

  List<CartLine> get lines => _lines;
  String? get tableToken => _tableToken;
  int get count => _lines.fold(0, (s, l) => s + l.qty);
  bool get isEmpty => _lines.isEmpty;

  String get _key => 'sufra_cart_v1:$slug';

  void _load() {
    final raw = _prefs?.getString(_key);
    if (raw == null) return;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map) return;
      final lines = parsed['lines'];
      _lines = lines is List
          ? [
              for (final l in lines)
                if (l is Map) _lineFromJson(l.cast<String, Object?>()),
            ]
          : const [];
      final token = parsed['tableToken'];
      _tableToken = token is String ? token : null;
    } catch (_) {
      // سلة تالفة — نبدأ فارغين
    }
  }

  /// الكمية الكسرية أو غير الرقمية تُحفظ صفرًا فيرفضها تدقيق السلة ظاهرًا
  /// للعميل، بدل أن تُقرّب بصمت إلى كمية لم يطلبها.
  CartLine _lineFromJson(Map<String, Object?> j) {
    final qty = j['qty'];
    final line = CartLine.fromJson(j);
    if (qty is num && qty == qty.truncate()) return line;
    return line.withQty(0);
  }

  void _save() {
    notifyListeners();
    _prefs?.setString(
      _key,
      jsonEncode({
        'lines': [for (final l in _lines) l.toJson()],
        'tableToken': _tableToken,
      }),
    );
  }

  /// بصمة السطر: نفس الطبق بنفس الخيارات ونفس الملاحظة = سطر واحد تزيد كميته
  static String signature(String dishId, List<CartSelection> selections, String note) {
    final ids = selections.expand((s) => s.optionIds).toList()..sort();
    return '$dishId|${ids.join(',')}|${note.trim()}';
  }

  /// يضيف للسلة ويُرجع الكمية المضافة فعلًا — قد تقلّ عن المطلوبة إن بلغ
  /// السطر الحد الأعلى، فتُخبر الواجهة العميل بدل أن يرفض الطلب لاحقًا.
  int add(String dishId, List<CartSelection> selections, String note, int qty) {
    final key = signature(dishId, selections, note);
    final lines = [..._lines];
    final existing = lines.indexWhere((l) => l.key == key);
    var added = qty;
    if (existing >= 0) {
      final current = lines[existing].qty;
      final next = (current + qty).clamp(1, maxLineQty);
      added = next - current;
      lines[existing] = lines[existing].withQty(next);
    } else {
      lines.add(CartLine(key: key, dishId: dishId, qty: qty, note: note.trim(), selections: selections));
    }
    _lines = lines;
    _save();
    return added;
  }

  void setQty(String key, int qty) {
    _lines = [
      for (final l in _lines)
        if (l.key != key) l else if (qty > 0) l.withQty(qty),
    ];
    _save();
  }

  void remove(String key) {
    _lines = [
      for (final l in _lines)
        if (l.key != key) l,
    ];
    _save();
  }

  void clear() {
    _lines = const [];
    _save();
  }

  void setTableToken(String? token) {
    if (token == _tableToken) return;
    _tableToken = token;
    _save();
  }
}

/// سلة واحدة لكل مطعم، مشتركة بين كل شاشات العميل.
class CartRegistry {
  CartRegistry(this._prefs);

  final SharedPreferences? _prefs;
  final _carts = <String, CartStore>{};

  CartStore of(String slug) => _carts.putIfAbsent(slug, () => CartStore._(slug, _prefs));
}
