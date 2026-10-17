import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../data/arabic.dart';
import '../../data/models.dart';
import '../../data/mutations.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../../data/utils.dart';
import '../../state/session.dart';
import '../common/basics.dart';
import '../common/buttons.dart';
import '../common/sheets.dart';
import '../storefront/storefront_page.dart';

/// المطاعم — لوحة مشرف المنصة (مقابل /admin في الموقع)
class RestaurantsTool extends StatefulWidget {
  const RestaurantsTool({super.key});

  @override
  State<RestaurantsTool> createState() => _RestaurantsToolState();
}

class _RestaurantsToolState extends State<RestaurantsTool> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final db = context.watchDb();
    final p = context.palette;
    final stats = platformStats(db);
    final restaurants = db.restaurants
        .where(
          (r) =>
              _query.trim().isEmpty ||
              matchesQuery(r.name, _query) ||
              r.slug.contains(_query.trim().toLowerCase()) ||
              r.phone.contains(normalizePhone(_query)),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Text(
          'كل مطاعم المنصة',
          style: txt(12.5, color: p.inkFaint, weight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        StatGrid(
          children: [
            StatTile(
              label: 'مطاعم',
              value: Text(ltr('${stats.restaurants}')),
              icon: Icons.store_mall_directory_outlined,
            ),
            StatTile(
              label: 'نشطة',
              value: Text(ltr('${stats.activeRestaurants}')),
              tone: Tone.basil,
              sub: stats.suspended > 0 ? '${stats.suspended} موقوفة' : null,
              icon: Icons.check_circle_outline_rounded,
            ),
            StatTile(label: 'أطباق', value: Text(ltr('${stats.dishes}')), icon: Icons.restaurant_outlined),
            StatTile(
              label: 'طلبات اليوم',
              value: Text(ltr('${stats.ordersToday}')),
              tone: Tone.saffron,
              sub: '${stats.orders} إجمالًا',
              icon: Icons.receipt_long_outlined,
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          style: txt(15, color: p.ink),
          decoration: const InputDecoration(
            hintText: 'ابحث باسم المطعم أو الرابط أو الجوال',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 14),
        if (restaurants.isEmpty)
          const EmptyState(title: 'لا مطاعم تطابق البحث', icon: Icons.search_off_rounded)
        else
          for (final r in restaurants)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RestaurantCard(restaurant: r, db: db),
            ),
        const SizedBox(height: 6),
        const InfoNote(
          'هي قناة الاستعادة الوحيدة في هذه المرحلة: التسجيل بالجوال بلا رسائل SMS ولا بريد، فلا يملك صاحب المطعم طريقة لاستعادتها بنفسه. تحقّق من هويته قبل التعيين.',
          title: 'إعادة تعيين كلمة المرور',
          icon: Icons.shield_outlined,
        ),
      ],
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.restaurant, required this.db});

  final Restaurant restaurant;
  final DB db;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final owner = getOwner(db, restaurant.id);
    final orders = getOrders(db, restaurant.id);
    final today = orders.where((o) => isSameDay(o.createdAt)).length;
    final plan = getPlan(db, restaurant.planId);
    final store = context.read<DataStore>();

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DishThumb(
                name: restaurant.name,
                label: brandInitial(restaurant.name),
                src: restaurant.logoUrl,
                size: 46,
                radius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(restaurant.name, style: heading(16, color: p.ink)),
                        Tag(
                          restaurant.isActive ? 'نشط' : 'موقوف',
                          tone: restaurant.isActive ? Tone.basil : Tone.sumac,
                          dense: true,
                        ),
                        if (plan != null) Tag(plan.name, dense: true),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(ltr('/m/${restaurant.slug}'), style: txt(12.5, color: p.inkFaint)),
                    if (owner != null) Text('${owner.name} · ${ltr(owner.phone)}', style: txt(12.5, color: p.inkFaint)),
                    Text('سُجّل ${ltr(formatDate(restaurant.createdAt))}', style: txt(12.5, color: p.inkFaint)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            children: [
              _Count(countDishes(db, restaurant.id), nDish),
              _Count(orders.length, nOrder),
              _Count(today, null, label: 'اليوم'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                label: 'المنيو',
                icon: Icons.storefront_rounded,
                size: BtnSize.sm,
                onPressed: () => Navigator.of(context).push(storefrontRoute(restaurant.slug)),
              ),
              if (owner != null)
                AppButton(
                  label: 'كلمة مرور المالك',
                  icon: Icons.key_rounded,
                  size: BtnSize.sm,
                  onPressed: () async {
                    final password = await promptText(
                      context,
                      title: 'كلمة مرور جديدة لـ ${owner.name}',
                      label: 'كلمة المرور الجديدة — ٦ أحرف على الأقل',
                      hint: 'سلّمها للمالك بقناة موثوقة',
                      confirmLabel: 'عيّنها',
                      minLength: 6,
                    );
                    if (password == null) return;
                    final result = store.resetProfilePassword(owner.id, password);
                    if (!result.ok) return toastError(result.error!);
                    toast('تغيّرت كلمة المرور');
                  },
                ),
              if (restaurant.isActive)
                AppButton(
                  label: 'أوقف',
                  icon: Icons.pause_circle_outline_rounded,
                  size: BtnSize.sm,
                  tone: BtnTone.danger,
                  onPressed: () async {
                    final ok = await confirmAction(
                      context,
                      title: 'إيقاف «${restaurant.name}»',
                      body:
                          'سيتوقّف منيو المطعم عن العمل فورًا، ولا يستطيع صاحبه الدخول للوحة. البيانات تبقى محفوظة ويمكن التفعيل لاحقًا.',
                      confirmLabel: 'أوقف المطعم',
                    );
                    if (!ok) return;
                    store.setRestaurantActive(restaurant.id, false);
                    toast('أُوقف المطعم');
                  },
                )
              else
                AppButton(
                  label: 'فعّل',
                  icon: Icons.play_circle_outline_rounded,
                  size: BtnSize.sm,
                  tone: BtnTone.success,
                  onPressed: () {
                    store.setRestaurantActive(restaurant.id, true);
                    toast('فُعّل المطعم');
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.value, this.noun, {this.label});

  final int value;
  final ArabicNoun? noun;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: ltr('$value'),
            style: txt(13, color: p.ink, weight: FontWeight.w700),
          ),
          TextSpan(text: ' ${noun == null ? label : nounFor(value, noun!)}'),
        ],
      ),
      style: txt(13, color: p.inkSoft),
    );
  }
}
