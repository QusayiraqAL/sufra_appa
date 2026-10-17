import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// التصدير: تحويل أي واجهة إلى صورة، ثم مشاركتها أو طباعتها.
///
/// الإيصال والمنيو الورقي وبطاقات QR تُرسم بواجهات Flutter نفسها ثم تُصوَّر:
/// محرّك Flutter يشكّل الحروف العربية ويربطها بدقة، بينما مكتبات PDF تتعثّر
/// في ذلك. فالصورة تخرج مطابقة لما يراه صاحب المطعم على الشاشة.

/// يرسم [widget] خارج الشاشة بعرض [width] ويُرجع صورة PNG.
/// الارتفاع يتبع المحتوى ما لم يُحدَّد [height].
Future<Uint8List> renderToPng(
  Widget widget, {
  required double width,
  double? height,
  double pixelRatio = 3,
  TextDirection direction = TextDirection.rtl,
}) async {
  final boundary = RenderRepaintBoundary();
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final logical = Size(width, height ?? 20000);
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(alignment: Alignment.topCenter, child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints(maxWidth: logical.width, maxHeight: logical.height),
      physicalConstraints: BoxConstraints(maxWidth: logical.width * pixelRatio, maxHeight: logical.height * pixelRatio),
      devicePixelRatio: pixelRatio,
    ),
  );

  final pipeline = PipelineOwner();
  var dirty = false;
  final buildOwner = BuildOwner(focusManager: FocusManager(), onBuildScheduled: () => dirty = true);
  pipeline.rootNode = renderView;
  renderView.prepareInitialFrame();

  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: MediaQuery(
      data: MediaQueryData(size: logical, devicePixelRatio: pixelRatio),
      child: Directionality(
        textDirection: direction,
        child: SizedBox(width: width, height: height, child: widget),
      ),
    ),
  ).attachToRenderTree(buildOwner);

  void pump() {
    buildOwner.buildScope(root);
    buildOwner.finalizeTree();
    pipeline.flushLayout();
    pipeline.flushCompositingBits();
    pipeline.flushPaint();
  }

  pump();
  // الصور (الشعار وصور الأطباق) تُفكّ بعد أول رسم — نعيد الرسم حتى تستقر
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!dirty) break;
    dirty = false;
    pump();
  }

  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// يصوّر واجهة معروضة على الشاشة داخل RepaintBoundary بمفتاح [key].
Future<Uint8List?> captureBoundary(GlobalKey key, {double pixelRatio = 3}) async {
  final object = key.currentContext?.findRenderObject();
  if (object is! RenderRepaintBoundary) return null;
  final image = await object.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List();
}

/// يجمع صورًا في ملف PDF، صورة لكل صفحة تملأ الصفحة.
/// [format] null = مقاس الصفحة يتبع الصورة (للإيصال بعرض ٨٠ ملم).
Future<Uint8List> imagesToPdf(List<Uint8List> pngs, {PdfPageFormat? format, double rollWidthMm = 80}) async {
  final doc = pw.Document(title: 'سُفرة', creator: 'سُفرة');
  for (final png in pngs) {
    final image = pw.MemoryImage(png);
    final pageFormat =
        format ??
        () {
          final w = rollWidthMm * PdfPageFormat.mm;
          final ratio = (image.height ?? 1) / (image.width ?? 1);
          return PdfPageFormat(w, w * ratio);
        }();
    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
      ),
    );
  }
  return doc.save();
}

/// يفتح نافذة الطباعة في النظام (تتيح أيضًا الحفظ PDF)
Future<void> printPdf(Uint8List pdf, {required String name}) async {
  await Printing.layoutPdf(onLayout: (_) async => pdf, name: name);
}

Future<File> _tempFile(String filename, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final safe = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
  final file = File('${dir.path}${Platform.pathSeparator}$safe');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

/// مشاركة ملف (صورة، PDF، نسخة احتياطية) عبر قائمة المشاركة في النظام:
/// واتساب، الحفظ في الملفات، البريد…
Future<void> shareBytes(Uint8List bytes, {required String filename, required String mime, String? text}) async {
  final file = await _tempFile(filename, bytes);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mime, name: filename)],
      text: text,
      title: filename,
    ),
  );
}

Future<void> shareFiles(List<(Uint8List, String)> files, {required String mime, String? text}) async {
  final xfiles = <XFile>[];
  for (final (bytes, name) in files) {
    final file = await _tempFile(name, bytes);
    xfiles.add(XFile(file.path, mimeType: mime, name: name));
  }
  await SharePlus.instance.share(ShareParams(files: xfiles, text: text));
}

Future<void> shareText(String text, {String? subject}) async {
  await SharePlus.instance.share(ShareParams(text: text, subject: subject));
}

Future<void> copyText(String text) => Clipboard.setData(ClipboardData(text: text));
