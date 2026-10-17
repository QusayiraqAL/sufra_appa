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
import '../common/inputs.dart';
import '../common/sheets.dart';

/// الموظفون — حسابات الكاشير (مقابل /dashboard/staff في الموقع)
class StaffTool extends StatefulWidget {
  const StaffTool({super.key});

  @override
  State<StaffTool> createState() => _StaffToolState();
}

class _StaffToolState extends State<StaffTool> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid => _name.text.trim().length >= 2 && _phone.text.trim().length >= 9 && _password.text.length >= 6;

  void _submit(String restaurantId) {
    final result = context.store.addStaff(restaurantId, name: _name.text, phone: _phone.text, password: _password.text);
    if (!result.ok) return toastError(result.error!);
    for (final c in [_name, _phone, _password]) {
      c.clear();
    }
    FocusScope.of(context).unfocus();
    toast('أُضيف الموظف — سلّمه رقم الجوال وكلمة المرور');
  }

  @override
  Widget build(BuildContext context) {
    return RestaurantBuilder(
      builder: (context, db, restaurant, profile) {
        final p = context.palette;
        final staff = getStaff(db, restaurant.id);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Text(
              countOf(staff.length, nStaff, isolate: ltr),
              style: txt(12.5, color: p.inkFaint, weight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('ماذا يرى الموظف؟', style: heading(16, color: p.ink)),
                  const SizedBox(height: 10),
                  _Point(
                    ok: true,
                    text:
                        'شاشة الطلبات: يرى الطلبات، ينقلها بين المراحل، يلغيها، ويطبع الإيصال — ويُدخل طلب زبون من «منيو العميل».',
                  ),
                  const SizedBox(height: 8),
                  const _Point(
                    ok: false,
                    text: 'لا يعدّل المنيو ولا الأسعار، ولا يفتح التقارير ولا الإعدادات ولا هذه الصفحة.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SurfaceCard(
              child: ListenableBuilder(
                listenable: Listenable.merge([_name, _phone, _password]),
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('أضف موظفًا', style: heading(16, color: p.ink)),
                    const SizedBox(height: 12),
                    LabeledField(
                      label: 'الاسم',
                      child: AppTextField(controller: _name, hint: 'مثال: سعود', textInputAction: TextInputAction.next),
                    ),
                    const SizedBox(height: 12),
                    LabeledField(
                      label: 'رقم الجوال',
                      hint: 'هو معرّف دخوله.',
                      child: AppTextField(
                        controller: _phone,
                        hint: '05xxxxxxxx',
                        ltr: true,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LabeledField(
                      label: 'كلمة المرور',
                      hint: '٦ أحرف على الأقل — سلّمها للموظف.',
                      child: AppTextField(
                        controller: _password,
                        hint: '••••••',
                        onSubmitted: (_) => _submit(restaurant.id),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      label: 'أضف الموظف',
                      icon: Icons.person_add_alt_rounded,
                      tone: BtnTone.primary,
                      onPressed: _valid ? () => _submit(restaurant.id) : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (staff.isEmpty)
              const EmptyState(
                title: 'لا موظفين بعد',
                body: 'أضف كاشيرًا ليتابع الطلبات دون الوصول لبقية اللوحة.',
                icon: Icons.badge_outlined,
              )
            else
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (i, person) in staff.indexed) ...[
                      if (i > 0) Divider(height: 1, color: p.line),
                      _StaffRow(person: person),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 18, color: ok ? p.basil : p.sumac),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: txt(13.5, color: p.inkSoft, height: 1.65)),
        ),
      ],
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.person});

  final Profile person;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 4, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: p.saffronTint,
            child: Text(initial(person.name), style: heading(17, color: p.saffron)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: txt(15, color: p.ink, weight: FontWeight.w700),
                ),
                Text(
                  '${ltr(person.phone)} · أُضيف ${ltr(formatDate(person.createdAt))}',
                  style: txt(12.5, color: p.inkFaint),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'خيارات الموظف',
            icon: Icon(Icons.more_vert_rounded, color: p.inkSoft),
            onSelected: (v) => _onAction(context, v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'password', child: Text('كلمة مرور جديدة')),
              const PopupMenuItem(value: 'edit', child: Text('عدّل البيانات')),
              PopupMenuItem(
                value: 'delete',
                child: Text('احذف الموظف', style: TextStyle(color: p.sumac)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, String action) async {
    final store = context.read<DataStore>();
    switch (action) {
      case 'password':
        final password = await promptText(
          context,
          title: 'كلمة مرور جديدة لـ ${person.name}',
          label: 'كلمة المرور الجديدة',
          hint: '٦ أحرف على الأقل',
          confirmLabel: 'عيّنها',
          minLength: 6,
        );
        if (password == null) return;
        final result = store.resetProfilePassword(person.id, password);
        if (!result.ok) return toastError(result.error!);
        toast('تغيّرت كلمة المرور — سلّمها للموظف بنفسك');
      case 'edit':
        if (!context.mounted) return;
        await _editSheet(context, person);
      case 'delete':
        final ok = await confirmAction(
          context,
          title: 'حذف «${person.name}»',
          body: 'لن يستطيع الدخول بعد الحذف. الطلبات التي تعامل معها تبقى محفوظة.',
        );
        if (!ok) return;
        store.deleteStaff(person.id);
        toast('حُذف الموظف');
    }
  }
}

Future<void> _editSheet(BuildContext context, Profile person) {
  final name = TextEditingController(text: person.name);
  final phone = TextEditingController(text: person.phone);
  return showAppSheet<void>(
    context,
    title: 'عدّل بيانات الموظف',
    builder: (c) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: 'الاسم',
          child: AppTextField(controller: name),
        ),
        const SizedBox(height: 12),
        LabeledField(
          label: 'رقم الجوال',
          child: AppTextField(controller: phone, ltr: true, keyboardType: TextInputType.phone),
        ),
      ],
    ),
    footer: (c) => Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: () {
              final result = c.read<DataStore>().updateStaff(
                person.id,
                name: name.text,
                phone: phone.text == person.phone ? null : phone.text,
              );
              if (!result.ok) return toastError(result.error!);
              Navigator.pop(c);
              toast('حُفظت التعديلات');
            },
            child: const Text('احفظ'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(onPressed: () => Navigator.pop(c), child: const Text('تراجع')),
        ),
      ],
    ),
  );
}
