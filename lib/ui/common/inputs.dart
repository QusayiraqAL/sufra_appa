import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// حقل بعنوان فوقه وتلميح تحته — نفس ترتيب حقول الموقع، وأوضح بالعربية
/// من العنوان العائم.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child, this.hint, this.error, this.trailing});

  final String label;
  final Widget child;
  final String? hint;
  final String? error;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: txt(13.5, color: p.ink, weight: FontWeight.w600, height: 1.4),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 7),
        child,
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(
            error!,
            style: txt(12, color: p.sumac, weight: FontWeight.w500, height: 1.5),
          ),
        ] else if (hint != null) ...[
          const SizedBox(height: 5),
          Text(hint!, style: txt(12, color: p.inkFaint, height: 1.5)),
        ],
      ],
    );
  }
}

/// حقل نص بإعدادات التطبيق. [ltr] للأرقام والجوالات والروابط.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hint,
    this.keyboardType,
    this.ltr = false,
    this.obscure = false,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.prefixIcon,
    this.suffix,
    this.textInputAction,
    this.maxLength,
    this.enabled = true,
    this.error = false,
    this.dense = false,
    this.autofillHints,
    this.focusNode,
    this.inputFormatters,
    this.initialValue,
  });

  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool ltr;
  final bool obscure;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final bool enabled;
  final bool error;
  final bool dense;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  final String? initialValue;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textDirection: ltr ? TextDirection.ltr : null,
      textAlign: TextAlign.start,
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      minLines: minLines,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      autofocus: autofocus,
      textInputAction: textInputAction,
      maxLength: maxLength,
      enabled: enabled,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      style: txt(15, color: p.ink, height: 1.5),
      decoration: InputDecoration(
        hintText: hint,
        hintTextDirection: ltr ? TextDirection.ltr : null,
        isDense: dense,
        counterText: '',
        contentPadding: dense
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
        suffixIcon: suffix,
        enabledBorder: error
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
                borderSide: BorderSide(color: p.sumac),
              )
            : null,
      ),
    );
  }
}

/// حقل كلمة مرور بزر إظهار
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.hint = '••••••',
    this.onSubmitted,
    this.autofillHints,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => AppTextField(
    controller: widget.controller,
    hint: widget.hint,
    obscure: _hidden,
    onSubmitted: widget.onSubmitted,
    autofillHints: widget.autofillHints,
    textInputAction: widget.textInputAction,
    suffix: IconButton(
      tooltip: _hidden ? 'إظهار' : 'إخفاء',
      icon: Icon(_hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20),
      onPressed: () => setState(() => _hidden = !_hidden),
    ),
  );
}

/// سطر بعنوان وتلميح ومفتاح تشغيل — مثل Toggle في الموقع
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.enabled = true,
  });

  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged(!value);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: txt(14.5, color: enabled ? p.ink : p.inkFaint, weight: FontWeight.w600, height: 1.45),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 2),
                      Text(hint!, style: txt(12.5, color: p.inkFaint, height: 1.55)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(value: value, onChanged: enabled ? onChanged : null),
            ],
          ),
        ),
      ),
    );
  }
}

/// عدّاد كمية بزرّي زيادة ونقص — أسهل من لوحة المفاتيح على الجوال
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = compact ? 36.0 : 44.0;
    Widget btn(IconData icon, String label, int next, bool enabled) => Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged(next);
              }
            : null,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: compact ? 17 : 19, color: enabled ? p.ink : p.inkFaint.withValues(alpha: .5)),
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: p.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.add_rounded, 'زيادة', value + 1, value < max),
          SizedBox(
            width: compact ? 26 : 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: txt(
                compact ? 14 : 15.5,
                color: p.ink,
                weight: FontWeight.w700,
                height: 1,
              ).copyWith(fontFeatures: tabular),
            ),
          ),
          btn(Icons.remove_rounded, 'إنقاص', value - 1, value > min),
        ],
      ),
    );
  }
}

/// أزرار اختيار متلاصقة — للفترة، الترتيب، المقاس
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged, this.label});

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            for (final (v, text) in options)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: v == value,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (v == value) return;
                      HapticFeedback.selectionClick();
                      onChanged(v);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: v == value ? p.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(Radii.sm),
                        boxShadow: v == value
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: p.isDark ? .3 : .07),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: txt(
                          13.5,
                          color: v == value ? p.ink : p.inkFaint,
                          weight: v == value ? FontWeight.w700 : FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// مؤشّر اختيار واحد مرسوم — بديل Radio يتلوّن بلون المطعم في واجهة العميل
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.selected, this.color, this.size = 20});

  final bool selected;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.saffron;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? c : p.lineStrong, width: 2),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: selected ? 1 : 0,
        child: Container(
          width: size * .5,
          height: size * .5,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c),
        ),
      ),
    );
  }
}

/// مربّع اختيار متعدد مرسوم
class CheckDot extends StatelessWidget {
  const CheckDot({super.key, required this.selected, this.color, this.size = 20, this.onColor});

  final bool selected;
  final Color? color;
  final Color? onColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.saffron;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? c : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selected ? c : p.lineStrong, width: 2),
      ),
      child: selected ? Icon(Icons.check_rounded, size: size * .75, color: onColor ?? p.onSaffron) : null,
    );
  }
}

/// حقل يحفظ عند مغادرته أو الضغط على «تم» — لا مع كل حرف، فالكتابة
/// السريعة لا تعيد كتابة ملف البيانات عشرات المرات. يتبع القيمة الخارجية
/// حين تتغيّر من مكان آخر وهو غير مركّز.
class CommitField extends StatefulWidget {
  const CommitField({
    super.key,
    required this.value,
    required this.onCommit,
    this.hint,
    this.ltr = false,
    this.keyboardType,
    this.dense = true,
    this.style,
    this.bare = false,
    this.semanticLabel,
  });

  final String value;
  final ValueChanged<String> onCommit;
  final String? hint;
  final bool ltr;
  final TextInputType? keyboardType;
  final bool dense;
  final TextStyle? style;

  /// بلا إطار — للتحرير داخل سطر
  final bool bare;
  final String? semanticLabel;

  @override
  State<CommitField> createState() => _CommitFieldState();
}

class _CommitFieldState extends State<CommitField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(CommitField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    if (_controller.text != widget.value) widget.onCommit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: widget.semanticLabel,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        keyboardType: widget.keyboardType,
        textDirection: widget.ltr ? TextDirection.ltr : null,
        onSubmitted: (_) => _commit(),
        style: widget.style ?? txt(14.5, color: p.ink),
        decoration: widget.bare
            ? InputDecoration(
                hintText: widget.hint,
                isDense: true,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: p.saffron, width: 1.5)),
              )
            : InputDecoration(
                hintText: widget.hint,
                isDense: widget.dense,
                contentPadding: widget.dense
                    ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
      ),
    );
  }
}
