import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../common/basics.dart';
import '../common/brand.dart';
import '../common/buttons.dart';

const _steps = [
  ('سجّل برقم جوالك', 'اسمك، اسم المطعم، ورقم الجوال. لا بطاقة ولا التزام — الحساب يفتح فورًا.'),
  ('ابنِ المنيو', 'أقسام وأطباق وأسعار وصور، مع الأحجام والإضافات لكل طبق كما هي في مطعمك.'),
  ('اطبع رمز QR', 'رمز للمنيو، ورمز مستقل لكل طاولة. شاركها جاهزة للطباعة أو اطبعها بضغطة.'),
  ('استقبل الطلبات', 'الطلب يظهر على شاشة الكاشير لحظيًا مع تنبيه صوتي، وتنقله بين المراحل بزر واحد.'),
];

const _features = [
  (
    Icons.bolt_rounded,
    'منيو يُحدَّث في ثانية',
    'نفد طبق؟ اضغط «نفد اليوم» فيظهر معلَّمًا عند العميل بدل أن يطلبه ويُرفض.',
  ),
  (
    Icons.tune_rounded,
    'أحجام وإضافات حقيقية',
    'صغير ووسط وكبير بأسعار مختلفة، وإضافات مدفوعة، وملاحظة يكتبها العميل بنفسه.',
  ),
  (
    Icons.alt_route_rounded,
    'ثلاثة أنواع طلب',
    'من الطاولة عبر رمزها، أو استلام، أو توصيل. تشغّل ما يناسبك وتطفئ الباقي.',
  ),
  (
    Icons.view_kanban_outlined,
    'شاشة طلبات كالمطبخ',
    'جديد، قيد التجهيز، جاهز، مكتمل. الطلب المتأخّر يتلوّن، والجديد ينبّهك بصوت.',
  ),
  (
    Icons.insights_rounded,
    'تقارير تقرأ بلحظة',
    'مبيعات اليوم والأسبوع، أكثر الأطباق طلبًا، متوسط الطلب، وأكثر ساعة ازدحامًا.',
  ),
  (Icons.badge_outlined, 'حساب لكل كاشير', 'الموظف يرى الطلبات ويحرّكها فقط — لا يعدّل أسعارًا ولا يفتح التقارير.'),
];

/// عن سُفرة — محتوى الصفحة التعريفية في الموقع
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: Text('عن سُفرة', style: heading(18, color: p.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          const Center(child: Wordmark(size: 40)),
          const SizedBox(height: 14),
          Text(
            'منيو مطعمك على الجوال،',
            textAlign: TextAlign.center,
            style: heading(24, color: p.ink),
          ),
          Text(
            'والطلبات على شاشة واحدة.',
            textAlign: TextAlign.center,
            style: heading(24, color: p.saffron),
          ),
          const SizedBox(height: 10),
          Text(
            'تُنشئ منيو مطعمك بأقسامه وأسعاره وصوره في دقائق، فتحصل على رابط ورمز QR يمسحه عميلك من الطاولة ويطلب مباشرة. الطلب يصلك لحظيًا، وتحرّكه بين المراحل حتى يُسلَّم.',
            textAlign: TextAlign.center,
            style: txt(14.5, color: p.inkSoft, height: 1.8),
          ),
          const SizedBox(height: 26),
          Text(
            'من التسجيل إلى أول طلب',
            style: txt(12.5, color: p.inkFaint, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text('أربع خطوات، بالترتيب.', style: heading(19, color: p.ink)),
          const SizedBox(height: 12),
          for (final (i, (title, body)) in _steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SurfaceCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.saffronTint, shape: BoxShape.circle),
                      child: Text(ltr('${i + 1}'), style: heading(14, color: p.saffron)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: heading(15.5, color: p.ink, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(body, style: txt(13.5, color: p.inkSoft, height: 1.7)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            'ما تحصل عليه',
            style: txt(12.5, color: p.inkFaint, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text('مبني على ما يحتاجه المطعم فعلًا.', style: heading(19, color: p.ink)),
          const SizedBox(height: 12),
          for (final (icon, title, body) in _features)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SurfaceCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TintIcon(icon, Tint.saffron, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: heading(15.5, color: p.ink, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(body, style: txt(13.5, color: p.inkSoft, height: 1.7)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: p.saffron, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('الخطة المجانية', style: heading(17, color: p.ink)),
                    ),
                    Text(ltr('0'), style: heading(26, color: p.saffron)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'كل المزايا مفتوحة بلا حدود ولا بطاقة. لاحقًا ستُضاف خطة مدفوعة للمزايا المتقدّمة — إشعارات واتساب، الدفع الإلكتروني، الفروع المتعددة — وما تستخدمه اليوم يبقى مجانيًا.',
                  style: txt(13.5, color: p.inkSoft, height: 1.75),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'افتح الموقع',
            icon: Icons.language_rounded,
            expand: true,
            onPressed: () => launchUrl(Uri.parse(AppConfig.siteUrl), mode: LaunchMode.externalApplication),
          ),
          const SizedBox(height: 14),
          Text(
            'نموذج مبدئي — البيانات محفوظة على هذا الجهاز، ولم تُربط قاعدة بيانات بعد.',
            textAlign: TextAlign.center,
            style: txt(12, color: p.inkFaint),
          ),
        ],
      ),
    );
  }
}
