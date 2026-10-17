import 'package:flutter/material.dart';

import '../../state/session.dart';
import 'storefront_menu.dart';

/// أداة «منيو العميل» لصاحب المطعم والكاشير: المنيو العام نفسه، مع اختيار
/// الطاولة وإرسال طلب نيابةً عن زبون حاضر أو متصل.
class StorefrontTool extends StatelessWidget {
  const StorefrontTool({super.key});

  @override
  Widget build(BuildContext context) => RestaurantBuilder(
    builder: (context, db, restaurant, profile) =>
        StorefrontMenu(key: ValueKey(restaurant.slug), slug: restaurant.slug, mode: StorefrontMode.operator),
  );
}
