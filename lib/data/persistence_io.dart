import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'persistence.dart';

/// ملف JSON في مجلد التطبيق الخاص. الكتابة ذرّية: تُكتب نسخة مؤقتة ثم
/// تُستبدل بالأصل دفعة واحدة، فانقطاع الكهرباء أو إغلاق التطبيق وسط
/// الكتابة لا يترك ملفًا نصف مكتوب.
class FilePersistence implements Persistence {
  FilePersistence(this.file);

  final File file;

  @override
  Future<String?> read() async {
    try {
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String data) async {
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(data, flush: true);
    await temp.rename(file.path);
  }
}

Future<Persistence> openPlatformPersistence() async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return FilePersistence(File('${dir.path}${Platform.pathSeparator}sufra_db_v1.json'));
}
