import 'package:flutter/material.dart';

import '../../core/export.dart';
import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/utils.dart';
import '../common/basics.dart';

/// إيصال بعرض ٨٠ ملم (مقاس الطابعة الحرارية) — مثل إيصال الموقع، مع اسم
/// المطعم في أعلاه لأن التطبيق يستطيع مشاركته صورةً مع العميل.
/// أبيض وأسود دائمًا: الطابعات الحرارية لا تطبع الألوان.
class ReceiptView extends StatelessWidget {
  const ReceiptView({super.key, required this.order, required this.restaurantName});

  final OrderWithItems order;
  final String restaurantName;

  static const width = 300.0;
  static const _ink = Color(0xFF000000);
  static const _muted = Color(0xFF555555);

  @override
  Widget build(BuildContext context) {
    final o = order.order;
    TextStyle s(double size, {FontWeight weight = FontWeight.w400, Color color = _ink, double height = 1.5}) =>
        TextStyle(fontFamily: Fonts.body, fontSize: size, fontWeight: weight, color: color, height: height);
    String money(double v) => formatMoney(v, o.currency);

    Widget dashed() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CustomPaint(size: const Size(double.infinity, 1), painter: _DashPainter()),
    );

    Widget row(String label, double value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: s(bold ? 15 : 12.5, weight: bold ? FontWeight.w700 : FontWeight.w400)),
          ),
          Text(ltr(money(value)), style: s(bold ? 15 : 12.5, weight: bold ? FontWeight.w700 : FontWeight.w400)),
        ],
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: width,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              restaurantName,
              textAlign: TextAlign.center,
              style: s(14, weight: FontWeight.w700, color: _muted),
            ),
            const SizedBox(height: 4),
            Text(
              'طلب ${ltr('#${o.orderNumber}')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: Fonts.display, fontSize: 24, fontWeight: FontWeight.w800, color: _ink),
            ),
            Text(
              [
                orderTypeLabel[o.type],
                ?o.tableLabel,
                ltr(formatTime(o.createdAt)),
                ltr(formatDate(o.createdAt)),
              ].join(' · '),
              textAlign: TextAlign.center,
              style: s(11.5, color: _muted),
            ),
            if (o.customerName.isNotEmpty)
              Text(
                [o.customerName, if (o.customerPhone.isNotEmpty) ltr(o.customerPhone)].join(' · '),
                textAlign: TextAlign.center,
                style: s(11.5, color: _muted),
              ),
            if (o.address.isNotEmpty)
              Text(
                o.address,
                textAlign: TextAlign.center,
                style: s(11.5, color: _muted),
              ),
            dashed(),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${ltr('${item.item.qty}×')} ',
                                  style: s(13, weight: FontWeight.w700),
                                ),
                                TextSpan(text: item.item.dishName, style: s(13)),
                              ],
                            ),
                          ),
                          if (item.options.isNotEmpty)
                            Text(item.options.map((op) => op.optionName).join(' · '), style: s(11, color: _muted)),
                          if (item.item.note.isNotEmpty)
                            Text(
                              'ملاحظة: ${item.item.note}',
                              style: s(11, color: _muted, weight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(ltr(money(item.item.lineTotal)), style: s(13)),
                  ],
                ),
              ),
            dashed(),
            row('المجموع', o.subtotal),
            if (o.taxAmount > 0) row('الضريبة', o.taxAmount),
            if (o.deliveryFee > 0) row('التوصيل', o.deliveryFee),
            const SizedBox(height: 4),
            row('الإجمالي', o.total, bold: true),
            if (o.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(border: Border.all(color: _muted)),
                child: Text(o.note, style: s(11.5)),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              o.paymentStatus == PaymentStatus.paid ? 'مدفوع · كاش' : 'الدفع كاش عند الاستلام',
              textAlign: TextAlign.center,
              style: s(11, color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF999999)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}

/// يفتح نافذة الطباعة بالإيصال (طابعة حرارية أو حفظ PDF)
Future<void> printReceipt(OrderWithItems order, String restaurantName) async {
  try {
    final png = await renderToPng(
      ReceiptView(order: order, restaurantName: restaurantName),
      width: ReceiptView.width,
      pixelRatio: 3,
    );
    final pdf = await imagesToPdf([png]);
    await printPdf(pdf, name: 'طلب ${order.order.orderNumber}');
  } catch (e) {
    toastError('تعذّر تجهيز الإيصال للطباعة');
  }
}

/// يشارك الإيصال صورةً — لإرساله للعميل على واتساب مثلًا
Future<void> shareReceipt(OrderWithItems order, String restaurantName) async {
  try {
    final png = await renderToPng(
      ReceiptView(order: order, restaurantName: restaurantName),
      width: ReceiptView.width,
      pixelRatio: 3,
    );
    await shareBytes(
      png,
      filename: 'receipt-${order.order.orderNumber}.png',
      mime: 'image/png',
      text: 'إيصال طلب ${order.order.orderNumber} — $restaurantName',
    );
  } catch (e) {
    toastError('تعذّر تجهيز الإيصال للمشاركة');
  }
}
