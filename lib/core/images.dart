import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';

/// الصور محفوظة كـ data URL — نفس صيغة الموقع، فالنسخة الاحتياطية تنتقل
/// بين الموقع والتطبيق بصورها. هنا فكّها مرة واحدة وتخزينها مؤقتًا: فكّ
/// base64 في كل إعادة رسم يُثقل القوائم الطويلة.

final _cache = <String, MemoryImage>{};
const _cacheLimit = 120;

Uint8List? decodeDataUrl(String url) {
  final comma = url.indexOf(',');
  if (!url.startsWith('data:') || comma < 0) return null;
  try {
    return base64Decode(url.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

/// مزوّد صورة لـ data URL. يُرجع null للرابط الفارغ أو التالف.
ImageProvider? dataImage(String? url) {
  if (url == null || url.isEmpty) return null;
  final hit = _cache.remove(url);
  if (hit != null) {
    _cache[url] = hit; // الأحدث استخدامًا في آخر القائمة
    return hit;
  }
  final bytes = decodeDataUrl(url);
  if (bytes == null) return null;
  final image = MemoryImage(bytes);
  _cache[url] = image;
  if (_cache.length > _cacheLimit) _cache.remove(_cache.keys.first);
  return image;
}

String toDataUrl(Uint8List bytes, String mime) => 'data:$mime;base64,${base64Encode(bytes)}';

String _mimeOf(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

/// يختار صورة ويضغطها قبل تخزينها. التطبيق يخزّن الصور داخل ملف البيانات،
/// فالضغط ضروري حتى لا يتضخّم — نفس مقاسات الموقع:
/// الطبق 720 بجودة 72٪، الغلاف 1200 بجودة 70٪، الشعار 800 بجودة عالية.
Future<String?> pickImageAsDataUrl({required ImageSource source, double maxWidth = 720, int quality = 72}) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: maxWidth,
    maxHeight: maxWidth * 2,
    imageQuality: quality,
    requestFullMetadata: false,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  // PNG يبقى PNG ليحفظ شفافية الشعار؛ غيره يُضغط JPEG
  return toDataUrl(bytes, _mimeOf(file.name));
}
