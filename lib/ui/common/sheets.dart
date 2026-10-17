import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// لوح منسدل من الأسفل بعنوان، ومحتوى قابل للتمرير، وتذييل ثابت للأزرار.
/// الطلب والإدارة تحدث بإبهام واحد على الجوال، فالأزرار في المتناول دائمًا.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
  WidgetBuilder? footer,
  double maxHeightFactor = .9,
  bool scrollable = true,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 4, 16, 16),
  Color? barrierColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    barrierColor: barrierColor,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _SheetBody(
      title: title,
      subtitle: subtitle,
      builder: builder,
      footer: footer,
      maxHeightFactor: maxHeightFactor,
      scrollable: scrollable,
      padding: padding,
    ),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.subtitle,
    required this.builder,
    required this.footer,
    required this.maxHeightFactor,
    required this.scrollable,
    required this.padding,
  });

  final String title;
  final String? subtitle;
  final WidgetBuilder builder;
  final WidgetBuilder? footer;
  final double maxHeightFactor;
  final bool scrollable;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final content = builder(context);
    return Padding(
      // لوحة المفاتيح لا تغطي الحقول
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * maxHeightFactor),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: heading(18.5, color: p.ink)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: txt(13, color: p.inkFaint, height: 1.5)),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: p.line),
            Flexible(
              child: scrollable
                  ? SingleChildScrollView(padding: padding.add(const EdgeInsets.only(top: 12)), child: content)
                  : Padding(padding: padding, child: content),
            ),
            if (footer != null)
              Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border(top: BorderSide(color: p.line)),
                ),
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + (media.viewInsets.bottom > 0 ? 0 : media.padding.bottom)),
                child: footer!(context),
              ),
          ],
        ),
      ),
    );
  }
}

/// نافذة إدخال نص واحد — لإعادة التسمية وما يشبهها
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String confirmLabel = 'احفظ',
  String? hint,
  int minLength = 1,
  TextInputType? keyboardType,
  bool ltr = false,
}) {
  final controller = TextEditingController(text: initial);
  return showAppSheet<String>(
    context,
    title: title,
    builder: (c) => _PromptBody(
      controller: controller,
      label: label,
      hint: hint,
      keyboardType: keyboardType,
      ltr: ltr,
      onSubmit: () {
        if (controller.text.trim().length >= minLength) Navigator.pop(c, controller.text.trim());
      },
    ),
    footer: (c) => ListenableBuilder(
      listenable: controller,
      builder: (c, _) => Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: controller.text.trim().length >= minLength
                  ? () => Navigator.pop(c, controller.text.trim())
                  : null,
              child: Text(confirmLabel),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(onPressed: () => Navigator.pop(c), child: const Text('تراجع')),
          ),
        ],
      ),
    ),
  );
}

class _PromptBody extends StatelessWidget {
  const _PromptBody({
    required this.controller,
    required this.label,
    required this.hint,
    required this.keyboardType,
    required this.ltr,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool ltr;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: txt(13.5, color: p.ink, weight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          textDirection: ltr ? TextDirection.ltr : null,
          style: txt(15, color: p.ink),
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (_) => onSubmit(),
        ),
      ],
    );
  }
}
