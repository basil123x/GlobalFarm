# Globee 🌐📱

تطبيق تسوق إلكتروني يجمع بين مميزات TikTok/Reels ومنصات التسوق التقليدية مثل Amazon/Jumia.

## الوصف 📝

Globee هو تطبيق مبتكر يدمج بين:
- **المحتوى القصير**: فيديوهات تفاعلية للمنتجات مثل TikTok
- **التسوق الإلكتروني**: نظام شراء متكامل مع سلة التسوق والدفع
- **التفاعل الاجتماعي**: إعجابات، تعليقات، ومتابعة البائعين

## المميزات الرئيسية ✨

### 🎥 المحتوى التفاعلي
- فيديوهات قصيرة للمنتجات
- تفاعل مباشر (إعجاب، تعليق، مشاركة)
- خوارزمية ذكية لعرض المحتوى المناسب

### 🛒 التسوق المتقدم
- سلة تسوق ذكية
- نظام دفع آمن
- تتبع الطلبات
- تقييمات المنتجات والبائعين

### 👥 الشبكة الاجتماعية
- متابعة البائعين المفضلين
- مشاركة المنتجات
- نظام إشعارات متطور

## التقنيات المستخدمة 🛠️

### Frontend (Flutter)
- **Framework**: Flutter 3.x
- **State Management**: GetX + Provider
- **Navigation**: GetX Navigation
- **UI Components**: Material Design 3
- **Video Player**: Chewie + Video Player
- **Image Handling**: Image Picker + Cached Network Image
- **Animations**: Lottie + Custom Animations

### Backend (PHP + MySQL)
- **Server**: PHP 8.x
- **Database**: MySQL 8.x
- **API**: RESTful API
- **Authentication**: JWT Tokens
- **File Upload**: Secure file handling

### الباكجات الرئيسية
```yaml
dependencies:
  # HTTP & Networking
  dio: ^5.4.0
  
  # Video & Media
  video_player: ^2.8.1
  chewie: ^1.7.5
  
  # Image Handling
  image_picker: ^1.0.4
  cached_network_image: ^3.3.0
  
  # State Management
  provider: ^6.1.1
  get: ^4.6.6
  
  # UI Components
  flutter_staggered_grid_view: ^0.7.0
  shimmer: ^3.0.0
  lottie: ^2.7.0
```

## هيكل المشروع 📁

```
lib/
├── core/
│   ├── constants/          # الثوابت والإعدادات
│   ├── utils/             # الأدوات المساعدة
│   ├── services/          # الخدمات العامة
│   └── network/           # إعدادات الشبكة
├── features/
│   ├── splash/            # شاشة البداية
│   ├── auth/              # المصادقة
│   ├── home/              # الشاشة الرئيسية
│   ├── product/           # المنتجات
│   ├── cart/              # سلة التسوق
│   └── profile/           # الملف الشخصي
└── shared/
    ├── widgets/           # الويدجت المشتركة
    ├── models/            # نماذج البيانات
    └── providers/         # مزودي الحالة
```

## التشغيل 🚀

### المتطلبات
- Flutter SDK 3.x
- Dart SDK 3.x
- Android Studio / VS Code
- PHP 8.x (للباك إند)
- MySQL 8.x (قاعدة البيانات)

### خطوات التشغيل

1. **استنساخ المشروع**
```bash
git clone <repository-url>
cd Globee
```

2. **تحميل الباكجات**
```bash
flutter pub get
```

3. **تشغيل التطبيق**
```bash
flutter run
```

## الحالة الحالية 📊

### ✅ مكتمل
- [x] إعداد هيكل المشروع
- [x] إضافة الباكجات المطلوبة
- [x] إنشاء Splash Screen
- [x] إعداد الـ Theme والألوان
- [x] إعداد الـ Navigation الأساسي
- [x] إنشاء الشاشات الأساسية

### 🔄 قيد التطوير
- [ ] تطوير شاشة الفيديوهات الرئيسية
- [ ] نظام المصادقة
- [ ] واجهة المنتجات
- [ ] سلة التسوق
- [ ] نظام الدفع

### 📋 مخطط له
- [ ] تطوير الباك إند (PHP + MySQL)
- [ ] نظام الإشعارات
- [ ] تحسين الأداء
- [ ] اختبارات الوحدة
- [ ] نشر التطبيق

## المساهمة 🤝

نرحب بالمساهمات! يرجى اتباع الخطوات التالية:

1. Fork المشروع
2. إنشاء branch جديد (`git checkout -b feature/AmazingFeature`)
3. Commit التغييرات (`git commit -m 'Add some AmazingFeature'`)
4. Push إلى البرانش (`git push origin feature/AmazingFeature`)
5. فتح Pull Request

## الترخيص 📄

هذا المشروع مرخص تحت رخصة MIT - انظر ملف [LICENSE](LICENSE) للتفاصيل.

## التواصل 📞

- **المطور**: [اسمك]
- **البريد الإلكتروني**: [بريدك الإلكتروني]
- **GitHub**: [رابط GitHub]

---

**ملاحظة**: هذا المشروع في مرحلة التطوير الأولى. المميزات والواجهات قابلة للتغيير.

<!-- Android -->
<!-- 35600706278-3954gt7h529125sn0j0qi284cimt3soq.apps.googleusercontent.com -->
<!-- IOS -->
<!-- 35600706278-5lqdgabaj0tdpe34819ooad6uf8i4cbu.apps.googleusercontent.com -->
<!-- Web -->
<!-- 35600706278-g91lt4njajab7v64mgi2s5brn8vr22kb.apps.googleusercontent.com -->
<!-- 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 -->