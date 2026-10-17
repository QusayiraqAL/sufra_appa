import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/queries.dart';
import '../data/store.dart';

/// اختصارات للوصول إلى البيانات من الواجهات.
extension StoreX on BuildContext {
  /// المخزن بلا اشتراك — للكتابة من داخل الأحداث
  DataStore get store => read<DataStore>();

  /// اللقطة الحالية مع الاشتراك في كل تغيير — للعرض
  DB watchDb() => watch<DataStore>().db;
}

/// الحساب والمطعم الحاليان
({Profile? profile, Restaurant? restaurant}) sessionOf(DB db) {
  final profile = getSessionProfile(db);
  return (profile: profile, restaurant: profile == null ? null : getRestaurantById(db, profile.restaurantId));
}

/// يبني المحتوى حين يكون للحساب مطعم — أدوات المطعم كلها تحتاجه.
class RestaurantBuilder extends StatelessWidget {
  const RestaurantBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, DB db, Restaurant restaurant, Profile profile) builder;

  @override
  Widget build(BuildContext context) {
    final db = context.watchDb();
    final (:profile, :restaurant) = sessionOf(db);
    if (profile == null || restaurant == null) return const SizedBox.shrink();
    return builder(context, db, restaurant, profile);
  }
}
