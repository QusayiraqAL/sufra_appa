import 'package:shared_preferences/shared_preferences.dart';

import 'persistence.dart';

/// على الويب: localStorage عبر shared_preferences — نفس مفتاح الموقع.
class PrefsPersistence implements Persistence {
  PrefsPersistence(this.prefs);

  final SharedPreferences prefs;
  static const _key = 'sufra_db_v1';

  @override
  Future<String?> read() async => prefs.getString(_key);

  @override
  Future<void> write(String data) async {
    await prefs.setString(_key, data);
  }
}

Future<Persistence> openPlatformPersistence() async => PrefsPersistence(await SharedPreferences.getInstance());
