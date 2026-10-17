import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/feedback.dart';
import '../../core/images.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/mutations.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../../data/utils.dart';
import '../../state/nav.dart';
import '../../state/prefs.dart';
import '../../state/session.dart';
import '../about/about_screen.dart';
import '../common/basics.dart';
import '../common/brand.dart';
import '../common/inputs.dart';
import 'tools.dart';

/// القائمة ☰: التبديل بين الأدوات من أي مكان، ثم الحساب والمظهر.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final nav = context.watch<NavState>();
    final db = context.watchDb();
    final (:profile, :restaurant) = sessionOf(db);
    if (profile == null) return const Drawer();

    final newOrders = restaurant == null ? 0 : countOrdersByStatus(db, restaurant.id, OrderStatus.newOrder);

    // يُغلق الدرج أولًا فيتحرّك تبديل الأداة خلفه
    void go(VoidCallback action) {
      HapticFeedback.selectionClick();
      Navigator.of(context).pop();
      action();
    }

    return Drawer(
      width: 312,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.horizontal(end: Radius.circular(Radii.xl)),
      ),
      child: Column(
        children: [
          _Header(profile: profile, restaurant: restaurant),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              children: [
                _Item(icon: Icons.apps_rounded, label: 'كل الأدوات', selected: nav.atHub, onTap: () => go(nav.goHome)),
                for (final (group, tools) in groupedTools(toolsForRole(profile.role))) ...[
                  _Section(group.label),
                  for (final t in tools)
                    _Item(
                      leading: TintIcon(t.icon, t.tint, size: 32),
                      label: t.title,
                      selected: nav.tool == t,
                      badge: t == ToolId.orders && newOrders > 0 ? newOrders : null,
                      onTap: () => go(() => nav.open(t)),
                    ),
                ],
                const _Section('المظهر والحساب'),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: _ThemePicker()),
                const SizedBox(height: 6),
                _Item(
                  icon: Icons.info_outline_rounded,
                  label: 'عن سُفرة',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen()));
                  },
                ),
                _Item(
                  icon: Icons.language_rounded,
                  label: 'افتح الموقع',
                  onTap: () {
                    Navigator.of(context).pop();
                    launchUrl(Uri.parse(AppConfig.siteUrl), mode: LaunchMode.externalApplication);
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: p.line),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: _Item(
                icon: Icons.logout_rounded,
                label: 'تسجيل الخروج',
                color: p.sumac,
                onTap: () => _logout(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'تسجيل الخروج',
      body: 'ستعود لشاشة الدخول. بياناتك تبقى محفوظة على هذا الجهاز.',
      confirmLabel: 'خروج',
    );
    if (!ok || !context.mounted) return;
    final store = context.read<DataStore>();
    final nav = context.read<NavState>();
    Navigator.of(context).pop();
    dismissToasts();
    nav.unbind();
    store.signOut();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.restaurant});

  final Profile profile;
  final Restaurant? restaurant;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const ink = Color(0xFF18201A);
    final bg = p.isDark ? p.surface2 : ink;
    final roleLabel = switch (profile.role) {
      Role.owner => 'صاحب المطعم',
      Role.staff => 'كاشير',
      Role.admin => 'مشرف المنصة',
    };
    final title = restaurant?.name ?? 'سُفرة';
    final logo = dataImage(restaurant?.logoUrl);
    final open = restaurant != null && isOpenNow(restaurant!.workingHours);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        gradient: RadialGradient(
          center: const AlignmentDirectional(.9, -1.2).resolve(Directionality.of(context)),
          radius: 1.4,
          colors: [const Color(0xFFA96A00).withValues(alpha: .38), bg],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wordmark(size: 22, color: Color(0xFFE9AE3C), textColor: Colors.white),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: logo == null ? .12 : 1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: logo != null
                        ? Image(image: logo, fit: BoxFit.cover, width: 50, height: 50)
                        : profile.role == Role.admin
                        ? const Icon(Icons.shield_rounded, color: Colors.white)
                        : Text(
                            brandInitial(title),
                            textScaler: TextScaler.noScaling,
                            style: heading(21, color: Colors.white),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: heading(17, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${profile.name} · $roleLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: txt(12.5, color: Colors.white.withValues(alpha: .75), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (restaurant != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulseDot(color: open ? const Color(0xFF6EE7B7) : const Color(0xFFFDA4AF), size: 7, animate: open),
                      const SizedBox(width: 4),
                      Text(
                        open ? 'مفتوح الآن' : 'مغلق الآن',
                        style: txt(12, color: Colors.white, weight: FontWeight.w600, height: 1.2),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(12, 18, 12, 6),
    child: Text(
      label,
      style: txt(12, color: context.palette.inkFaint, weight: FontWeight.w700),
    ),
  );
}

class _Item extends StatelessWidget {
  const _Item({
    required this.label,
    required this.onTap,
    this.icon,
    this.leading,
    this.selected = false,
    this.badge,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? leading;
  final bool selected;
  final int? badge;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = color ?? (selected ? p.saffron : p.ink);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? p.saffronTint : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  leading ?? SizedBox(width: 32, child: Icon(icon, size: 21, color: fg)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: txt(14.5, color: fg, weight: selected ? FontWeight.w700 : FontWeight.w600, height: 1.3),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: p.saffron, borderRadius: BorderRadius.circular(99)),
                      child: Text(
                        '$badge',
                        textAlign: TextAlign.center,
                        style: txt(11.5, color: p.onSaffron, weight: FontWeight.w700, height: 1.3),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPrefs>();
    return Segmented<ThemeMode>(
      label: 'المظهر',
      value: prefs.themeMode,
      onChanged: (m) => prefs.themeMode = m,
      options: const [(ThemeMode.light, 'نهاري'), (ThemeMode.dark, 'ليلي'), (ThemeMode.system, 'النظام')],
    );
  }
}
