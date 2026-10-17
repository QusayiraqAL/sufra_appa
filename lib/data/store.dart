import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'persistence.dart';
import 'seed.dart';

/// مخزن التطبيق — المقابل لـ src/lib/data/store.ts في الموقع.
///
/// هذا الملف و queries.dart و mutations.dart هي نقطة التبديل الوحيدة حين
/// تُربط قاعدة البيانات: الواجهات لا تعرف أن البيانات محفوظة على الجهاز.
///
/// كل تعديل يجري على نسخة (draft) ثم تحلّ النسخة محلّ الحالية دفعة واحدة:
/// إن فشل التعديل في منتصفه لا تبقى البيانات نصف معدّلة. وكل مستمع يُبلَّغ
/// فورًا — فالطلب الذي يُرسل من منيو العميل يظهر في شاشة الطلبات لحظيًا.
class DataStore extends ChangeNotifier {
  DataStore._(this._persistence, this._db);

  final Persistence _persistence;
  DB _db;

  /// آخر خطأ حفظ — تعرضه الواجهة تنبيهًا ثم تصفّره
  final ValueNotifier<String?> saveError = ValueNotifier(null);

  /// اللقطة الحالية. لا تُعدَّل مباشرة — كل كتابة تمرّ بـ mutate.
  DB get db => _db;

  /// يفتح المخزن: يقرأ المحفوظ، وإن لم يوجد أو كان تالفًا يبدأ بالبيانات التجريبية.
  static Future<DataStore> open(Persistence persistence) async {
    DB? loaded;
    try {
      final raw = await persistence.read();
      if (raw != null && raw.isNotEmpty) {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, Object?> && parsed['version'] == dbVersion && parsed['restaurants'] is List) {
          loaded = DB.fromJson(parsed);
        }
      }
    } catch (_) {
      // بيانات تالفة — نبدأ من جديد
    }
    final store = DataStore._(persistence, loaded ?? createSeedDB());
    if (loaded == null) store._scheduleSave();
    return store;
  }

  /// مخزن في الذاكرة فقط — للاختبارات
  @visibleForTesting
  factory DataStore.memory([DB? db]) => DataStore._(MemoryPersistence(), db ?? createSeedDB());

  /// يطبّق تعديلًا على نسخة من البيانات ثم يعتمدها ويحفظها.
  void mutate(void Function(DB draft) apply) {
    final draft = _db.copy();
    apply(draft);
    _db = draft;
    _scheduleSave();
    notifyListeners();
  }

  /// يعيد البيانات التجريبية كما كانت أول مرة
  void reset() {
    _db = createSeedDB();
    _scheduleSave();
    notifyListeners();
  }

  /// تصدير نسخة احتياطية كنص JSON — بنفس صيغة ملف الموقع
  String exportJson() => const JsonEncoder.withIndent('  ').convert(_db.toJson());

  /// استيراد نسخة احتياطية (من التطبيق أو من الموقع)
  void importJson(String json) {
    final Object? parsed;
    try {
      parsed = jsonDecode(json);
    } catch (_) {
      throw const FormatException('الملف ليس نسخة صالحة');
    }
    if (parsed is! Map<String, Object?> || parsed['restaurants'] is! List) {
      throw const FormatException('الملف ليس نسخة صالحة');
    }
    final next = DB.fromJson(parsed)..version = dbVersion;
    _db = next;
    _scheduleSave();
    notifyListeners();
  }

  /* ---------- الحفظ ---------- */

  Future<void>? _saving;
  bool _dirty = false;

  /// الكتابة متسلسلة: تعديلات متلاحقة أثناء كتابة جارية تُجمع في كتابة
  /// واحدة بعدها بأحدث لقطة، فلا تتسابق كتابتان على الملف.
  void _scheduleSave() {
    _dirty = true;
    _saving ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_dirty) {
        _dirty = false;
        final data = jsonEncode(_db.toJson());
        await _persistence.write(data);
      }
    } catch (e) {
      saveError.value = 'تعذّر حفظ البيانات على الجهاز. تأكّد من وجود مساحة كافية.';
    } finally {
      _saving = null;
    }
  }

  /// ينتظر اكتمال أي حفظ معلّق — قبل إغلاق التطبيق وفي الاختبارات
  Future<void> flush() async {
    while (_saving != null) {
      await _saving;
    }
  }
}
