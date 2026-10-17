import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// العلامة: طبق دائري تعلوه ثلاث علامات — إشارة إلى الطبق والقائمة معًا.
/// منقولة من مكوّن Wordmark في الموقع (نفس المسارات بمقياس 32).
class SufraMark extends StatelessWidget {
  const SufraMark({super.key, this.size = 28, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: SufraMarkPainter(color ?? context.palette.saffron));
}

class SufraMarkPainter extends CustomPainter {
  SufraMarkPainter(this.color, {this.stroke = 1.6});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 32;
    canvas.save();
    canvas.scale(s);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(16, 16), 14, Paint.from(paint)..color = color.withValues(alpha: .35));
    canvas.drawCircle(const Offset(16, 16), 8.5, paint);
    canvas.drawLine(const Offset(11, 8.5), const Offset(11, 4.5), paint);
    canvas.drawLine(const Offset(16, 8.5), const Offset(16, 3.5), paint);
    canvas.drawLine(const Offset(21, 8.5), const Offset(21, 4.5), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SufraMarkPainter old) => old.color != color || old.stroke != stroke;
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 26, this.color, this.textColor});

  final double size;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SufraMark(size: size, color: color),
        SizedBox(width: size * .3),
        Text('سُفرة', style: heading(size * .72, color: textColor ?? p.ink, height: 1.1)),
      ],
    );
  }
}
