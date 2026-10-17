import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../data/arabic.dart';
import '../../data/utils.dart';
import '../common/basics.dart';

/// رسوم بيانية بسيطة مبنية بلا مكتبة — منقولة من charts.tsx في الموقع:
/// - سلسلة واحدة بلون واحد؛ المقدار يُقرأ من طول العمود لا من لونه.
/// - العلامة نحيفة بسقف ٢٤، طرفها مستدير ومربّعة عند خط الأساس.
/// - الشبكة خط شعري خافت، والتسمية المباشرة على القيمة القصوى فقط.
/// - الزمن يجري من اليمين لليسار: الأقدم يمينًا واليوم يسارًا.
/// - لكل رسم عرض جدولي بديل، فالمعلومة لا تعتمد على البصر وحده.

const _gridSteps = [1.0, .75, .5, .25];

double niceCeil(double value) {
  if (value <= 0) return 1;
  final magnitude = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
  final normalized = value / magnitude;
  final step = normalized <= 1
      ? 1
      : normalized <= 2
      ? 2
      : normalized <= 5
      ? 5
      : 10;
  return step * magnitude;
}

class ColumnPoint {
  const ColumnPoint({required this.label, required this.value, this.meta});

  final String label;
  final double value;
  final String? meta;
}

class _ChartFrame extends StatefulWidget {
  const _ChartFrame({
    required this.title,
    required this.hasData,
    required this.chart,
    required this.table,
    required this.emptyLabel,
  });

  final String title;
  final bool hasData;
  final Widget chart;
  final Widget table;
  final String emptyLabel;

  @override
  State<_ChartFrame> createState() => _ChartFrameState();
}

class _ChartFrameState extends State<_ChartFrame> {
  bool _asTable = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: heading(15.5, color: p.ink, weight: FontWeight.w700),
              ),
            ),
            if (widget.hasData)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: p.inkSoft,
                  minimumSize: const Size(40, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  side: BorderSide(color: p.line),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _asTable = !_asTable);
                },
                child: Text(_asTable ? 'اعرض الرسم' : 'اعرض كجدول', style: txt(12, weight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (!widget.hasData)
          CustomPaint(
            painter: DashedBorderPainter(color: p.line, radius: Radii.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
              child: Text(
                widget.emptyLabel,
                textAlign: TextAlign.center,
                style: txt(13.5, color: p.inkFaint),
              ),
            ),
          )
        else
          AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: _asTable ? widget.table : widget.chart),
      ],
    );
  }
}

/* ===================== أعمدة زمنية ===================== */

class ColumnChart extends StatefulWidget {
  const ColumnChart({
    super.key,
    required this.points,
    required this.currency,
    required this.title,
    this.emptyLabel = 'لا بيانات في هذه الفترة',
  });

  final List<ColumnPoint> points;
  final String currency;
  final String title;
  final String emptyLabel;

  @override
  State<ColumnChart> createState() => _ColumnChartState();
}

class _ColumnChartState extends State<ColumnChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final points = widget.points;
    final max = points.fold(0.0, (m, x) => math.max(m, x.value));
    final scale = niceCeil(max);
    final peak = max > 0 ? points.indexWhere((x) => x.value == max) : -1;
    final hasData = points.any((x) => x.value > 0);
    // تسميات المحور تُخفَّف حين تكثر الأعمدة فلا تتراكب
    final every = points.length <= 10 ? 1 : (points.length / 6).ceil();
    // ارتفاع منطقة الرسم، وفوقها هامش لتسمية القيمة القصوى
    const plotHeight = 160.0;
    const topPad = 20.0;
    const axisPad = 34.0;
    final selected = _selected;

    final chart = Column(
      key: const ValueKey('chart'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 22,
          child: selected == null || selected >= points.length || points[selected].value == 0
              ? null
              : Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.line),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: ltr(points[selected].label),
                            style: txt(12, color: p.inkSoft, weight: FontWeight.w600),
                          ),
                          const TextSpan(text: ' · '),
                          TextSpan(text: formatMoney(points[selected].value, widget.currency)),
                          if (points[selected].meta != null) TextSpan(text: ' · ${points[selected].meta}'),
                        ],
                      ),
                      style: txt(12, color: p.ink, weight: FontWeight.w600),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: topPad + plotHeight,
          child: Stack(
            children: [
              // خطوط الشبكة: كل خط على ارتفاع قيمته بالضبط، وعلامته بجانبه
              for (final step in _gridSteps)
                Positioned(
                  left: 0,
                  right: 0,
                  top: topPad + plotHeight * (1 - step) - 7,
                  height: 14,
                  child: Row(
                    children: [
                      SizedBox(
                        width: axisPad,
                        child: Text(
                          ltr(formatNumber(round2(scale * step))),
                          style: txt(10, color: p.inkFaint, height: 1.4),
                        ),
                      ),
                      Expanded(child: Container(height: 1, color: p.chartGrid)),
                    ],
                  ),
                ),
              Positioned(left: 0, right: 0, bottom: 0, child: Container(height: 1, color: p.lineStrong)),
              // الأعمدة — بنفس مقياس الشبكة
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: axisPad),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final (i, point) in points.indexed)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selected = _selected == i ? null : i);
                            },
                            child: Semantics(
                              label: '${point.label}: ${formatNumber(round2(point.value))}',
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (i == peak && point.value > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: FittedBox(
                                        child: Text(
                                          ltr(formatNumber(round2(point.value))),
                                          style: txt(10, color: p.ink, weight: FontWeight.w700, height: 1),
                                        ),
                                      ),
                                    ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOutCubic,
                                    width: 24,
                                    constraints: const BoxConstraints(maxWidth: 24),
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    height: point.value > 0 ? math.max(2, (point.value / scale) * plotHeight) : 0,
                                    decoration: BoxDecoration(
                                      color: p.chart1.withValues(alpha: selected == null || selected == i ? 1 : .45),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: axisPad),
          child: Row(
            children: [
              for (final (i, point) in points.indexed)
                Expanded(
                  child: Text(
                    i % every == 0 || i == peak || i == points.length - 1 ? ltr(point.label) : '',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: txt(
                      9.5,
                      color: i == peak ? p.ink : p.inkFaint,
                      weight: i == peak ? FontWeight.w700 : FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final table = DataTableView(
      key: const ValueKey('table'),
      head: const ['اليوم', 'الإيراد'],
      rows: [
        for (final point in points) [Text(ltr(point.label)), MoneyText(point.value, currency: widget.currency)],
      ],
    );

    return _ChartFrame(
      title: widget.title,
      hasData: hasData,
      chart: chart,
      table: table,
      emptyLabel: widget.emptyLabel,
    );
  }
}

/* ===================== أعمدة أفقية مرتّبة ===================== */

class BarItem {
  const BarItem({required this.label, required this.value, this.note});

  final String label;
  final double value;

  /// يُعرض بجانب القيمة — مثل عدد الطلبات
  final String? note;
}

class BarList extends StatelessWidget {
  const BarList({
    super.key,
    required this.items,
    required this.title,
    required this.unitLabel,
    required this.currency,
    this.emptyLabel = 'لا بيانات',
    this.showMoney = false,
    this.noun,
  });

  final List<BarItem> items;
  final String title;
  final String unitLabel;

  /// المعدود بصيغته الصحيحة مع العدد («٥ مرات»، «١١ مرة») بدل unitLabel الثابت
  final ArabicNoun? noun;
  final String currency;
  final String emptyLabel;
  final bool showMoney;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final max = items.fold(0.0, (m, x) => math.max(m, x.value));

    final chart = Column(
      key: const ValueKey('chart'),
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: txt(14, color: p.ink),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (showMoney)
                      MoneyText(
                        item.value,
                        currency: currency,
                        style: txt(12.5, color: p.inkSoft, weight: FontWeight.w600),
                      )
                    else
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: ltr(formatNumber(round2(item.value))),
                              style: txt(12.5, weight: FontWeight.w700),
                            ),
                            TextSpan(
                              text: ' ${noun == null ? unitLabel : nounFor(item.value.round(), noun!)}',
                              style: txt(12.5, color: p.inkFaint),
                            ),
                          ],
                        ),
                        style: txt(12.5, color: p.inkSoft),
                      ),
                    if (item.note != null) ...[
                      const SizedBox(width: 6),
                      Text(item.note!, style: txt(12, color: p.inkFaint)),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    height: 8,
                    color: p.chartTrack,
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: max > 0 ? math.max(.02, item.value / max) : 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.chart1,
                          borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    final table = DataTableView(
      key: const ValueKey('table'),
      head: ['الاسم', unitLabel],
      rows: [
        for (final item in items)
          [
            Text(item.label),
            showMoney
                ? MoneyText(item.value, currency: currency)
                : Text('${ltr(formatNumber(round2(item.value)))}${item.note != null ? ' · ${item.note}' : ''}'),
          ],
      ],
    );

    return _ChartFrame(title: title, hasData: items.isNotEmpty, chart: chart, table: table, emptyLabel: emptyLabel);
  }
}

/* ===================== الجدول البديل ===================== */

class DataTableView extends StatelessWidget {
  const DataTableView({super.key, required this.head, required this.rows});

  final List<String> head;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: p.surface2,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  for (final h in head)
                    Expanded(
                      child: Text(
                        h,
                        style: txt(12.5, color: p.inkSoft, weight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
            for (final row in rows)
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: p.line)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: DefaultTextStyle.merge(
                  style: txt(13.5, color: p.ink),
                  child: Row(
                    children: [
                      for (final cell in row)
                        Expanded(
                          child: Align(alignment: AlignmentDirectional.centerStart, child: cell),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
