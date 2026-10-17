import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/config.dart';
import '../../core/export.dart';
import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../data/arabic.dart';
import '../../data/models.dart';
import '../../data/mutations.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../../state/session.dart';
import '../common/basics.dart';
import '../common/buttons.dart';
import '../common/inputs.dart';
import '../common/sheets.dart';

/// الطاولات ورموز QR — مقابل /dashboard/tables في الموقع
class TablesTool extends StatefulWidget {
  const TablesTool({super.key});

  @override
  State<TablesTool> createState() => _TablesToolState();
}

class _TablesToolState extends State<TablesTool> {
  final _label = TextEditingController();
  int _bulk = 4;
  bool _printing = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _add(String restaurantId) {
    final result = context.store.addTable(restaurantId, _label.text);
    if (!result.ok) return toastError(result.error!);
    _label.clear();
    FocusScope.of(context).unfocus();
    toast('أُضيفت الطاولة');
  }

  Future<void> _exportAll(Restaurant restaurant, List<RestaurantTable> tables, {required bool share}) async {
    setState(() => _printing = true);
    try {
      final cards = [for (final t in tables) (label: t.label, url: AppConfig.tableUrl(restaurant.slug, t.qrToken))];
      final pages = <Uint8List>[];
      for (var i = 0; i < cards.length; i += 6) {
        pages.add(
          await renderToPng(
            QrSheetPage(cards: cards.sublist(i, (i + 6).clamp(0, cards.length)), restaurantName: restaurant.name),
            width: QrSheetPage.width,
            height: QrSheetPage.height,
            pixelRatio: 2.5,
          ),
        );
      }
      final pdf = await imagesToPdf(pages, format: PdfPageFormat.a4);
      if (share) {
        await shareBytes(pdf, filename: '${restaurant.slug}-tables-qr.pdf', mime: 'application/pdf');
      } else {
        await printPdf(pdf, name: 'رموز الطاولات — ${restaurant.name}');
      }
    } catch (e) {
      toastError('تعذّر تجهيز صفحة الطباعة');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RestaurantBuilder(
      builder: (context, db, restaurant, profile) {
        final p = context.palette;
        final tables = getTables(db, restaurant.id);
        final menuUrl = AppConfig.menuUrl(restaurant.slug);
        final width = MediaQuery.sizeOf(context).width;
        final columns = width >= 900
            ? 4
            : width >= 600
            ? 3
            : 2;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Text(
              countOf(tables.length, nTable, isolate: ltr),
              style: txt(12.5, color: p.inkFaint, weight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            // ============ رمز المنيو العام ============
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      QrBox(data: menuUrl, size: 118),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('رمز المنيو العام', style: heading(16, color: p.ink)),
                            const SizedBox(height: 4),
                            Text(
                              'يفتح المنيو بلا طاولة — للواجهة والملصقات وحساباتك في التواصل. من يمسحه يطلب استلامًا أو توصيلًا.',
                              style: txt(12.5, color: p.inkSoft, height: 1.65),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    menuUrl,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.end,
                    style: txt(12.5, color: p.inkFaint),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppButton(
                        label: 'انسخ الرابط',
                        icon: Icons.copy_rounded,
                        size: BtnSize.sm,
                        onPressed: () async {
                          await copyText(menuUrl);
                          toast('نُسخ الرابط');
                        },
                      ),
                      AppButton(
                        label: 'شارك الرمز',
                        icon: Icons.ios_share_rounded,
                        size: BtnSize.sm,
                        onPressed: () => _shareCard(restaurant, 'المنيو', menuUrl),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ============ إضافة طاولات ============
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('أضف طاولات', style: heading(16, color: p.ink)),
                  const SizedBox(height: 12),
                  LabeledField(
                    label: 'طاولة واحدة باسم مخصّص',
                    child: Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _label,
                            hint: 'مثال: الجلسة الخارجية 2',
                            dense: true,
                            onSubmitted: (_) => _add(restaurant.id),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ListenableBuilder(
                          listenable: _label,
                          builder: (context, _) => AppButton(
                            label: 'أضف',
                            icon: Icons.add_rounded,
                            size: BtnSize.sm,
                            onPressed: _label.text.trim().isNotEmpty ? () => _add(restaurant.id) : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 28, color: p.line),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'أو أضف عددًا مرقّمًا تلقائيًا',
                          style: txt(13.5, color: p.ink, weight: FontWeight.w600),
                        ),
                      ),
                      NumberStepper(
                        value: _bulk,
                        min: 1,
                        max: 50,
                        compact: true,
                        onChanged: (v) => setState(() => _bulk = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    label: 'أضف ${countOf(_bulk, nTable)}',
                    icon: Icons.add_rounded,
                    onPressed: () {
                      context.read<DataStore>().addTablesBulk(restaurant.id, _bulk);
                      toast('أُضيفت ${countOf(_bulk, nTable)}');
                    },
                  ),
                  if (tables.isNotEmpty) ...[
                    Divider(height: 28, color: p.line),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: _printing ? 'جارٍ التجهيز…' : 'اطبع كل الرموز',
                            icon: Icons.print_rounded,
                            tone: BtnTone.primary,
                            busy: _printing,
                            onPressed: () => _exportAll(restaurant, tables, share: false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconBtn(
                          icon: Icons.ios_share_rounded,
                          tooltip: 'شارك ملف PDF بكل الرموز',
                          size: 46,
                          onPressed: _printing ? null : () => _exportAll(restaurant, tables, share: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ست بطاقات في كل صفحة A4 جاهزة للقص — بطاقة لكل طاولة باسمها.',
                      style: txt(12, color: p.inkFaint),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ============ الطاولات ============
            if (tables.isEmpty)
              const EmptyState(
                title: 'لا طاولات بعد',
                body: 'أضف طاولاتك ليتمكّن عملاؤك من الطلب وهم جالسون.',
                icon: Icons.table_restaurant_outlined,
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tables.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 250 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3),
                ),
                itemBuilder: (context, i) => _TableCard(
                  table: tables[i],
                  restaurant: restaurant,
                  openOrders: getOpenOrdersForTable(db, tables[i].id).length,
                  onShare: () =>
                      _shareCard(restaurant, tables[i].label, AppConfig.tableUrl(restaurant.slug, tables[i].qrToken)),
                ),
              ),
            const SizedBox(height: 16),
            const InfoNote(
              'أي شخص يعرف رابط الطاولة يقدر يرسل طلبًا عليها. إن وصلك طلب مشكوك فيه فألغِه من شاشة الطلبات، وإن تسرّب رابط طاولة فاستخدم «جدّد الرمز» — يُبطل القديم فورًا ويحتاج طباعة رمز جديد.',
              title: 'ملاحظة أمنية:',
              icon: Icons.shield_outlined,
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareCard(Restaurant restaurant, String label, String url) async {
    try {
      final png = await renderToPng(
        QrCard(label: label, url: url, restaurantName: restaurant.name, standalone: true),
        width: QrCard.cardWidth,
        pixelRatio: 3,
      );
      await shareBytes(
        png,
        filename: '${restaurant.slug}-${label.replaceAll(' ', '-')}-qr.png',
        mime: 'image/png',
        text: '$label — ${restaurant.name}\n$url',
      );
    } catch (e) {
      toastError('تعذّر تجهيز الرمز');
    }
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.table, required this.restaurant, required this.openOrders, required this.onShare});

  final RestaurantTable table;
  final Restaurant restaurant;
  final int openOrders;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final url = AppConfig.tableUrl(restaurant.slug, table.qrToken);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => QrBox(data: url, size: c.maxHeight.clamp(80, 140)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            table.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: heading(15, color: p.ink, weight: FontWeight.w700),
          ),
          Text(
            switch (openOrders) {
              0 => 'لا طلبات مفتوحة',
              1 => 'طلب مفتوح',
              2 => 'طلبان مفتوحان',
              _ => '${countOf(openOrders, nOrder)} مفتوحة',
            },
            style: txt(
              12,
              color: openOrders > 0 ? p.ember : p.inkFaint,
              weight: openOrders > 0 ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'انسخ رابط الطاولة',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_rounded, size: 19),
                onPressed: () async {
                  await copyText(url);
                  toast('نُسخ رابط ${table.label}');
                },
              ),
              IconButton(
                tooltip: 'شارك الرمز',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.ios_share_rounded, size: 19),
                onPressed: onShare,
              ),
              PopupMenuButton<String>(
                tooltip: 'خيارات الطاولة',
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                onSelected: (v) => _onAction(context, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: Text('أعد التسمية')),
                  const PopupMenuItem(value: 'regenerate', child: Text('جدّد الرمز')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('احذف الطاولة', style: TextStyle(color: p.sumac)),
                  ),
                ],
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
      case 'rename':
        final label = await promptText(context, title: 'أعد تسمية الطاولة', label: 'اسم الطاولة', initial: table.label);
        if (label == null) return;
        store.updateTable(table.id, (t) => t.label = label);
        toast('تم التعديل');
      case 'regenerate':
        final ok = await confirmAction(
          context,
          title: 'تجديد رمز «${table.label}»',
          body: 'سيتوقّف الرمز المطبوع حاليًا عن العمل فورًا، ويلزمك طبع الرمز الجديد ولصقه على الطاولة.',
          confirmLabel: 'جدّد الرمز',
        );
        if (!ok) return;
        store.regenerateTableToken(table.id);
        HapticFeedback.mediumImpact();
        toast('جُدّد الرمز — اطبعه من جديد');
      case 'delete':
        final ok = await confirmAction(
          context,
          title: 'حذف «${table.label}»',
          body: 'لن يعمل رمز هذه الطاولة بعد الحذف. الطلبات السابقة تبقى محفوظة باسم الطاولة.',
        );
        if (!ok) return;
        store.deleteTable(table.id);
        toast('حُذفت الطاولة');
    }
  }
}

/* ===================== بطاقات الطباعة ===================== */

/// بطاقة رمز جاهزة للقص — مثل صفحة طباعة الرموز في الموقع.
/// ألوان ثابتة: تُطبع على ورق أبيض أيًّا كان مظهر التطبيق.
class QrCard extends StatelessWidget {
  const QrCard({
    super.key,
    required this.label,
    required this.url,
    required this.restaurantName,
    this.standalone = false,
  });

  final String label;
  final String url;
  final String restaurantName;

  /// بطاقة منفردة للمشاركة (بخلفية بيضاء وحواف)، لا خلية في صفحة
  final bool standalone;

  static const cardWidth = 340.0;

  @override
  Widget build(BuildContext context) {
    final card = CustomPaint(
      painter: DashedBorderPainter(color: const Color(0xFF9AA79E), radius: 22, width: 1.2),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: url,
              size: 196,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF18201A)),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF18201A),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: Fonts.display,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF18201A),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'امسح الرمز لتصفّح المنيو والطلب',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: Fonts.body, fontSize: 12, color: Color(0xFF5C6A61), height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              restaurantName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: Fonts.body,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFA96A00),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
    if (!standalone) return card;
    return Container(
      width: cardWidth,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Directionality(textDirection: TextDirection.rtl, child: card),
    );
  }
}

/// صفحة A4 بست بطاقات (عمودان × ثلاثة صفوف)
class QrSheetPage extends StatelessWidget {
  const QrSheetPage({super.key, required this.cards, required this.restaurantName});

  final List<({String label, String url})> cards;
  final String restaurantName;

  /// A4 بوحدات 96 نقطة/إنش
  static const width = 794.0;
  static const height = 1123.0;

  @override
  Widget build(BuildContext context) {
    const margin = 45.0; // 12 ملم
    const gap = 23.0; // 6 ملم
    return Container(
      width: width,
      height: height,
      color: Colors.white,
      padding: const EdgeInsets.all(margin),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            for (var row = 0; row < 3; row++) ...[
              if (row > 0) const SizedBox(height: gap),
              Expanded(
                child: Row(
                  children: [
                    for (var col = 0; col < 2; col++) ...[
                      if (col > 0) const SizedBox(width: gap),
                      Expanded(
                        child: row * 2 + col < cards.length
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: SizedBox(
                                  width: (width - margin * 2 - gap) / 2,
                                  child: QrCard(
                                    label: cards[row * 2 + col].label,
                                    url: cards[row * 2 + col].url,
                                    restaurantName: restaurantName,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
