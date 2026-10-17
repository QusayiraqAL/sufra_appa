import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/cart.dart';
import 'data/persistence.dart';
import 'data/store.dart';
import 'state/prefs.dart';

/// سُفرة — تطبيق المنيو الرقمي والطلبات.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // الخطوط مضمّنة في التطبيق (assets/fonts) فيعمل بلا إنترنت من أول تشغيل.
  // رخصها (SIL OFL) تظهر في صفحة التراخيص.
  LicenseRegistry.addLicense(() async* {
    for (final (font, file) in [
      ('Tajawal', 'tajawal'),
      ('IBM Plex Sans Arabic', 'ibmplexsansarabic'),
      ('Amiri', 'amiri'),
    ]) {
      yield LicenseEntryWithLineBreaks([font], await rootBundle.loadString('assets/fonts/OFL-$file.txt'));
    }
  });

  final prefs = await SharedPreferences.getInstance();
  final store = await DataStore.open(await openPlatformPersistence());

  runApp(SufraApp(store: store, prefs: AppPrefs(prefs), carts: CartRegistry(prefs)));
}
