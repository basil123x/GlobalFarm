import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';

enum LegalDocumentType { privacyPolicy, termsOfUse }

class LegalDocumentScreen extends StatelessWidget {
  final LegalDocumentType type;

  const LegalDocumentScreen({super.key, required this.type});

  bool get _ar => LocalizationService.instance.currentLanguage == 'ar';

  bool get _isPrivacy => type == LegalDocumentType.privacyPolicy;

  String get _title {
    if (_isPrivacy) {
      return _ar ? 'سياسة الخصوصية' : 'Privacy Policy';
    }
    return _ar ? 'شروط الاستخدام' : 'Terms of Use';
  }

  List<_LegalSection> get _sections {
    if (_isPrivacy) return _privacySections;
    return _termsSections;
  }

  List<_LegalSection> get _privacySections => _ar
      ? const [
          _LegalSection(
            title: '1. المقدمة',
            body:
                'مرحبًا بك في Global Farm. نحن نحترم خصوصيتك ونلتزم بحماية بياناتك الشخصية. توضح سياسة الخصوصية هذه كيفية جمع معلوماتك واستخدامها وحمايتها.',
          ),
          _LegalSection(
            title: '2. المعلومات التي نجمعها',
            body:
                'نجمع البيانات التالية:\n• البيانات الشخصية: الاسم والبريد الإلكتروني ورقم الهاتف عند إنشاء الحساب.\n• المحتوى المرفوع: الصور والفيديوهات والمنشورات.\n• البيانات التقنية: نوع الجهاز وعنوان IP وبيانات الاستخدام.\n• صلاحيات الكاميرا والمعرض: لالتقاط أو اختيار الوسائط داخل التطبيق.',
          ),
          _LegalSection(
            title: '3. كيف نستخدم المعلومات',
            body:
                'نستخدم بياناتك من أجل:\n• تقديم خدماتنا وتخصيصها.\n• تمكين رفع المحتوى والمشاركة والتفاعل.\n• تعزيز الأمان ومنع إساءة الاستخدام.\n• إرسال الإشعارات والعروض ذات الصلة.',
          ),
          _LegalSection(
            title: '4. مشاركة المعلومات',
            body:
                'لا نبيع بياناتك الشخصية. قد نشارك المعلومات مع مزودي خدمات موثوقين أو عند الطلب بموجب القانون.',
          ),
          _LegalSection(
            title: '5. حماية البيانات',
            body:
                'نتخذ تدابير مناسبة لتأمين معلوماتك ضد الوصول أو التعديل أو الإفصاح غير المصرح به.',
          ),
          _LegalSection(
            title: '6. حقوق المستخدم',
            body:
                'يحق لك الوصول إلى بياناتك الشخصية أو تحديثها أو حذفها في أي وقت، بما في ذلك حذف الحساب نهائيًا من داخل التطبيق.',
          ),
          _LegalSection(
            title: '7. المحتوى الذي ينشئه المستخدم',
            body:
                'باستخدامك للتطبيق، توافق على عدم نشر أي محتوى مسيء أو غير قانوني أو ضار. نحتفظ بالحق في إزالة هذا المحتوى وإيقاف الحسابات المخالفة.',
          ),
          _LegalSection(
            title: '8. ملفات التعريف والتتبع',
            body:
                'قد نستخدم ملفات تعريف الارتباط أو أدوات التحليل لتحسين تجربة التطبيق.',
          ),
          _LegalSection(
            title: '9. تحديثات السياسة',
            body:
                'قد نحدّث سياسة الخصوصية من وقت لآخر. سنُعلمك بأي تغييرات جوهرية داخل التطبيق.',
          ),
          _LegalSection(
            title: '10. تواصل معنا',
            body:
                'لأي استفسار بخصوص هذه السياسة، تواصل معنا عبر الدعم الفني داخل تطبيق Global Farm.',
          ),
        ]
      : const [
          _LegalSection(
            title: '1. Introduction',
            body:
                'Welcome to Global Farm. We respect your privacy and are committed to protecting your personal data. This Privacy Policy explains how we collect, use, and protect your information.',
          ),
          _LegalSection(
            title: '2. Information We Collect',
            body:
                'We collect the following information:\n• Personal details: name, email, phone (when creating an account).\n• Uploaded content: images, videos, posts.\n• Technical data: device type, IP address, usage data.\n• Camera and gallery access: to capture or select media within the app.',
          ),
          _LegalSection(
            title: '3. How We Use Information',
            body:
                'We use your data to:\n• Provide and personalize our services.\n• Enable content upload, sharing, and interaction.\n• Enhance security and prevent abuse.\n• Send notifications and offers.',
          ),
          _LegalSection(
            title: '4. Sharing Information',
            body:
                'We do not sell your personal data. We may share information with trusted service providers or if legally required.',
          ),
          _LegalSection(
            title: '5. Data Protection',
            body:
                'We take appropriate measures to secure your information against unauthorized access, modification, or disclosure.',
          ),
          _LegalSection(
            title: '6. User Rights',
            body:
                'You have the right to access, update, or delete your personal data at any time, including permanently deleting your account from within the app.',
          ),
          _LegalSection(
            title: '7. User-Generated Content',
            body:
                'By using our app, you agree not to post any offensive, illegal, or abusive content. We reserve the right to remove such content and suspend offending accounts.',
          ),
          _LegalSection(
            title: '8. Cookies and Tracking',
            body:
                'We may use cookies or analytics tools to improve your app experience.',
          ),
          _LegalSection(
            title: '9. Policy Updates',
            body:
                'We may update this Privacy Policy from time to time. We will notify you of any significant changes within the app.',
          ),
          _LegalSection(
            title: '10. Contact Us',
            body:
                'If you have any questions about this policy, please contact us through technical support inside the Global Farm app.',
          ),
        ];

  List<_LegalSection> get _termsSections => _ar
      ? const [
          _LegalSection(
            title: '1. قبول الشروط',
            body:
                'باستخدامك لتطبيق Global Farm، فإنك توافق على الالتزام بشروط الاستخدام هذه. إذا لم توافق، يرجى عدم استخدام التطبيق.',
          ),
          _LegalSection(
            title: '2. مسؤوليات المستخدم',
            body:
                'يجب على المستخدمين تقديم معلومات صحيحة، واحترام الآخرين، والامتناع عن نشر أي محتوى غير قانوني أو مسيء أو مضلل أو ينتهك الحقوق.',
          ),
          _LegalSection(
            title: '3. المحتوى الذي ينشئه المستخدم',
            body:
                'يظل المحتوى الذي تنشره تحت مسؤوليتك. نحتفظ بالحق في مراجعة أو إزالة أو تقييد أي محتوى يخالف إرشاداتنا أو يتم الإبلاغ عنه.',
          ),
          _LegalSection(
            title: '4. الحظر والإبلاغ',
            body:
                'يمكن للمستخدمين الإبلاغ عن محتوى غير لائق أو حظر مستخدمين آخرين داخل التطبيق. نتعامل مع البلاغات خلال 24 ساعة وقد نزيل المحتوى أو نوقف الحسابات عند الحاجة.',
          ),
          _LegalSection(
            title: '5. حذف الحساب',
            body:
                'يحق لك حذف حسابك نهائيًا من داخل التطبيق. ستتم إزالة بياناتك ومحتواك وفقًا لسياسة الخصوصية.',
          ),
          _LegalSection(
            title: '6. الملكية الفكرية',
            body:
                'جميع محتويات التطبيق والشعارات والعلامات التجارية تعود لـ Global Farm ولا يجوز استخدامها دون موافقة كتابية مسبقة.',
          ),
          _LegalSection(
            title: '7. تحديد المسؤولية',
            body:
                'لسنا مسؤولين عن أي أضرار أو خسائر ناتجة عن استخدامك للتطبيق. يتحمل المستخدمون وحدهم مسؤولية تفاعلاتهم والمحتوى المنشور.',
          ),
          _LegalSection(
            title: '8. تحديثات الشروط',
            body:
                'قد نحدّث هذه الشروط من وقت لآخر. استمرارك في استخدام التطبيق بعد التحديث يعني قبولك للشروط الجديدة.',
          ),
          _LegalSection(
            title: '9. التواصل',
            body:
                'لأي استفسار حول شروط الاستخدام، تواصل معنا عبر الدعم الفني داخل تطبيق Global Farm.',
          ),
        ]
      : const [
          _LegalSection(
            title: '1. Acceptance of Terms',
            body:
                'By using Global Farm, you agree to be bound by these Terms of Use. If you do not agree, please do not use the app.',
          ),
          _LegalSection(
            title: '2. User Responsibilities',
            body:
                'Users must provide accurate information, respect others, and refrain from posting any content that is illegal, offensive, abusive, misleading, or violates any laws or rights.',
          ),
          _LegalSection(
            title: '3. User-Generated Content',
            body:
                'All content you post remains your responsibility. We reserve the right to review, remove, or restrict any content that violates our guidelines or is reported by other users.',
          ),
          _LegalSection(
            title: '4. Blocking and Reporting',
            body:
                'Users can report inappropriate content or block other users within the app. We act on reports within 24 hours and may remove content or suspend accounts as necessary.',
          ),
          _LegalSection(
            title: '5. Account Deletion',
            body:
                'You have the right to delete your account permanently from within the app. All your data and content will be removed in accordance with our Privacy Policy.',
          ),
          _LegalSection(
            title: '6. Intellectual Property',
            body:
                'All app content, logos, and trademarks belong to Global Farm and cannot be used without prior written consent.',
          ),
          _LegalSection(
            title: '7. Limitation of Liability',
            body:
                'We are not liable for any damages or losses resulting from your use of the app. Users are solely responsible for their interactions and posted content.',
          ),
          _LegalSection(
            title: '8. Policy Updates',
            body:
                'We may update these terms from time to time. Continued use of the app after updates means acceptance of the new terms.',
          ),
          _LegalSection(
            title: '9. Contact',
            body:
                'If you have any questions regarding these Terms of Use, please contact us through technical support inside the Global Farm app.',
          ),
        ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Iconsax.arrow_right_3, color: context.appTextPrimary),
        ),
        title: Text(
          _title,
          style: TextStyle(
            color: context.appTextPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.appBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isPrivacy ? Iconsax.shield_tick : Iconsax.document_text,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _ar
                            ? 'Global Farm — سوقك الزراعي'
                            : 'Global Farm',
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < _sections.length; i++) ...[
                  Text(
                    _sections[i].title,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sections[i].body,
                    style: TextStyle(
                      color: context.appTextSecondary,
                      height: 1.55,
                      fontSize: 13.5,
                    ),
                  ),
                  if (i != _sections.length - 1) ...[
                    const SizedBox(height: 16),
                    Divider(color: context.appBorder, height: 1),
                    const SizedBox(height: 16),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSection {
  final String title;
  final String body;

  const _LegalSection({required this.title, required this.body});
}
