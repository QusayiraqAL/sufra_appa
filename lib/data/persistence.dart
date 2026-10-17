/// أين تُحفظ قاعدة البيانات على الجهاز.
///
/// واجهة صغيرة عن قصد: قراءة النص كاملًا وكتابته كاملًا. حين تُربط قاعدة
/// البيانات على الخادم يبقى هذا المخزن نسخة محلية للعمل بلا إنترنت.
library;

export 'persistence_stub.dart'
    if (dart.library.io) 'persistence_io.dart'
    if (dart.library.js_interop) 'persistence_web.dart';

abstract class Persistence {
  Future<String?> read();
  Future<void> write(String data);
}

/// في الذاكرة فقط — للاختبارات
class MemoryPersistence implements Persistence {
  MemoryPersistence([this.data]);

  String? data;
  int writes = 0;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String data) async {
    this.data = data;
    writes++;
  }
}
