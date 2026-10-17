import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// مفتاح المتصفّح الجذري — لعرض التنبيهات من أي مكان، حتى بعد إغلاق الشاشة
/// التي طلبتها.
final navigatorKey = GlobalKey<NavigatorState>();

/// يُبقى لـ MaterialApp؛ التنبيهات نفسها تُعرض أعلى الشاشة (انظر _show).
final messengerKey = GlobalKey<ScaffoldMessengerState>();

/* ===================== تنبيهات أعلى الشاشة ===================== */

// التنبيه ينزل من أعلى الشاشة كإشعار النظام، لا من أسفلها: أسفل الشاشة
// في هذا التطبيق للأزرار الأهم (السلة، إرسال الطلب، الطباعة)، والتنبيه
// الذي يغطيها يوقف المستخدم حتى يختفي.

OverlayEntry? _current;
GlobalKey<_ToastViewState>? _currentKey;

enum _Kind { ok, error, info }

void _show({
  required String message,
  required _Kind kind,
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(milliseconds: 2600),
}) {
  final overlay = navigatorKey.currentState?.overlay;
  if (overlay == null) return;
  _currentKey?.currentState?.dismiss(immediate: true);
  _current?.remove();

  final key = GlobalKey<_ToastViewState>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastView(
      key: key,
      message: message,
      kind: kind,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      onGone: () {
        if (_current == entry) {
          _current = null;
          _currentKey = null;
        }
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  _currentKey = key;
  overlay.insert(entry);

  // قارئ الشاشة يعلن التنبيه
  final context = navigatorKey.currentContext;
  if (context != null) {
    final view = View.maybeOf(context);
    if (view != null) {
      SemanticsService.sendAnnouncement(view, message, TextDirection.rtl);
    }
  }
}

/// يخفي أي تنبيه ظاهر — عند تسجيل الخروج مثلًا، فلا يبقى تنبيه حساب سابق
void dismissToasts() {
  _currentKey?.currentState?.dismiss(immediate: true);
  _current?.remove();
  _current = null;
  _currentKey = null;
}

/// تنبيه نجاح قصير
void toast(String message, {IconData icon = Icons.check_circle_rounded}) =>
    _show(message: message, kind: _Kind.ok, icon: icon);

/// تنبيه خطأ — يبقى أطول قليلًا ليُقرأ
void toastError(String message) {
  HapticFeedback.heavyImpact();
  _show(message: message, kind: _Kind.error, icon: Icons.error_rounded, duration: const Duration(milliseconds: 3800));
}

/// تنبيه مع زر تراجع — بديل عن نافذة التأكيد للأفعال القابلة للعكس
void toastUndo(String message, VoidCallback onUndo) => _show(
  message: message,
  kind: _Kind.info,
  icon: Icons.undo_rounded,
  actionLabel: 'تراجع',
  onAction: onUndo,
  duration: const Duration(seconds: 5),
);

/// تنبيه بإجراء — مثل «طلب جديد · افتح»
void toastAction(String message, {required String label, required VoidCallback onPressed, IconData? icon}) => _show(
  message: message,
  kind: _Kind.info,
  icon: icon ?? Icons.notifications_active_rounded,
  actionLabel: label,
  onAction: onPressed,
  duration: const Duration(seconds: 6),
);

class _ToastView extends StatefulWidget {
  const _ToastView({
    super.key,
    required this.message,
    required this.kind,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
    required this.onGone,
  });

  final String message;
  final _Kind kind;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onGone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  );
  Timer? _timer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(widget.duration, dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  Future<void> dismiss({bool immediate = false}) async {
    if (_leaving) return;
    _leaving = true;
    _timer?.cancel();
    if (!immediate && mounted) await _c.reverse();
    widget.onGone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.extension<Palette>() ?? Palette.light;
    // لوح داكن في النهاري وفاتح في الليلي — يبرز فوق أي خلفية
    final bg = p.isDark ? const Color(0xFFE9EEE6) : const Color(0xFF18201A);
    final fg = p.isDark ? const Color(0xFF18201A) : Colors.white;
    final accent = switch (widget.kind) {
      _Kind.ok => p.isDark ? const Color(0xFF2C6F4E) : const Color(0xFF5CB98A),
      _Kind.error => p.isDark ? const Color(0xFFA32235) : const Color(0xFFE8798A),
      _Kind.info => p.isDark ? const Color(0xFFA96A00) : const Color(0xFFE9AE3C),
    };
    final media = MediaQuery.of(context);
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);

    // تحت شريط العنوان لا فوقه: زر الرجوع والقائمة يبقيان في المتناول
    return Positioned(
      top: media.padding.top + kToolbarHeight + 6,
      left: 12,
      right: 12,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -1.4), end: Offset.zero).animate(curve),
          child: FadeTransition(
            opacity: curve,
            child: Dismissible(
              key: const ValueKey('toast'),
              direction: DismissDirection.up,
              onDismissed: (_) {
                _leaving = true;
                _timer?.cancel();
                widget.onGone();
              },
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Material(
                    color: bg,
                    elevation: 6,
                    shadowColor: Colors.black38,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(14, 10, widget.actionLabel == null ? 16 : 6, 10),
                      child: Row(
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, size: 21, color: accent),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              widget.message,
                              style: txt(14, color: fg, weight: FontWeight.w600, height: 1.45),
                            ),
                          ),
                          if (widget.actionLabel != null)
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: accent, minimumSize: const Size(56, 40)),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                widget.onAction?.call();
                                dismiss();
                              },
                              child: Text(widget.actionLabel!, style: txt(14, weight: FontWeight.w700)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================== التأكيد ===================== */

/// نافذة تأكيد للأفعال التي لا رجوع عنها. تُرجع true عند التأكيد.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = 'احذف',
  bool destructive = true,
}) async {
  final p = context.palette;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: destructive ? p.sumac : p.saffron,
                  foregroundColor: destructive ? p.surface : p.onSaffron,
                ),
                onPressed: () => Navigator.pop(c, true),
                child: Text(confirmLabel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('تراجع')),
            ),
          ],
        ),
      ],
    ),
  );
  return ok ?? false;
}
