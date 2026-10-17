/// إعدادات التطبيق الثابتة.
abstract final class AppConfig {
  static const appName = 'سُفرة';

  /// عنوان الموقع المنشور (NEXT_PUBLIC_APP_URL في .env.example).
  /// روابط المنيو ورموز QR تشير إليه: العميل يمسح الرمز فيفتح المنيو في
  /// متصفح جواله دون حاجة لتثبيت التطبيق.
  static const siteUrl = 'https://sufra.alqada.cloud';

  static String menuUrl(String slug) => '$siteUrl/m/$slug';

  static String tableUrl(String slug, String token) => '${menuUrl(slug)}?t=$token';

  /// يستخرج رابط المطعم ورمز الطاولة من رابط منيو ملصوق أو ممسوح.
  /// يقبل الرابط الكامل أو «/m/slug» أو الـ slug وحده.
  static ({String slug, String? token})? parseMenuLink(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri != null && uri.pathSegments.length >= 2 && uri.pathSegments.contains('m')) {
      final i = uri.pathSegments.indexOf('m');
      if (i + 1 < uri.pathSegments.length) {
        return (slug: uri.pathSegments[i + 1], token: uri.queryParameters['t']);
      }
    }
    final bare = text.replaceAll(RegExp(r'^/?m/'), '').split('?').first.split('/').first;
    if (RegExp(r'^[a-z0-9-]+$').hasMatch(bare)) return (slug: bare, token: null);
    return null;
  }
}
