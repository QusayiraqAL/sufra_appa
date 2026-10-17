import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'checkout_screen.dart';
import 'storefront_menu.dart';

/// مسار صفحة المنيو باسمه — ليعود إليه التطبيق بعد إرسال الطلب
Route<void> storefrontRoute(String slug, {String? tableToken}) => MaterialPageRoute(
  settings: const RouteSettings(name: storefrontRouteName),
  builder: (_) => StorefrontPage(slug: slug, tableToken: tableToken),
);

/// منيو العميل كصفحة مستقلة: للزائر بلا حساب، وللمشرف حين يفتح منيو مطعم.
class StorefrontPage extends StatelessWidget {
  const StorefrontPage({super.key, required this.slug, this.tableToken});

  final String slug;
  final String? tableToken;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.surface,
    body: SafeArea(
      bottom: false,
      child: StorefrontMenu(slug: slug, initialTableToken: tableToken),
    ),
  );
}
