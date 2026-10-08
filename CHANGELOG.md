# سجل التغييرات - Globee Trading App

## التحديثات الجديدة

### 1. شريط تقدم رفع المنتج في الإشعارات ✅
- **الوصف**: عند رفع منتج جديد، يظهر شريط تقدم في الإشعارات يوضح نسبة الرفع
- **الميزات**:
  - إشعار مستمر أثناء الرفع مع نسبة التقدم
  - عرض "رفع الملف X من Y - Z%"
  - إشعار نجاح عند اكتمال الرفع
  - إشعار خطأ في حالة الفشل
- **الملفات المعدلة**:
  - `lib/core/services/upload_notification_service.dart` (جديد)
  - `lib/core/services/bunny_upload_service.dart`
  - `lib/features/add_product/add_product_screen.dart`
  - `pubspec.yaml` (إضافة `flutter_local_notifications`)

### 2. محادثة جديدة لكل طلب ✅
- **الوصف**: عند التواصل مع البائع لطلب جديد، يتم إنشاء محادثة منفصلة
- **الميزات**:
  - كل طلب له `conversation_id` فريد
  - إمكانية وجود عدة محادثات بين نفس المشتري والبائع
  - المحادثات القديمة تبقى محفوظة في الأرشيف
- **الملفات المعدلة**:
  - `server_files/sql.php` (تعديل `get_chat_messages`, `send_chat_message`)
  - `lib/core/models/chat_model.dart`
  - `lib/core/services/api_service.dart`
  - `lib/features/chat/chat_screen.dart`
  - `lib/features/sellers/sellers_contact_screen.dart`

### 3. أرشيف المحادثات ✅
- **الوصف**: صفحة تعرض جميع المحادثات السابقة والحالية
- **الميزات**:
  - عرض كل المحادثات مع آخر رسالة
  - عدد الرسائل غير المقروءة
  - ترتيب حسب آخر رسالة
  - إمكانية فتح أي محادثة قديمة
- **الملفات المعدلة**:
  - `server_files/sql.php` (تحسين `get_chat_conversations`)
  - `lib/features/chat/conversations_screen.dart`

### 4. إرسال الموقع في المحادثة ✅
- **الوصف**: إمكانية إرسال الموقع الحالي للطرف الآخر
- **الميزات**:
  - زر إرسال الموقع في شريط الرسائل
  - طلب إذن الوصول للموقع
  - عرض رسالة الموقع كزر قابل للضغط
  - فتح الموقع في خرائط Google عند الضغط
- **الملفات المعدلة**:
  - `server_files/sql.php` (إضافة `location_lat`, `location_lng`)
  - `lib/core/models/chat_model.dart`
  - `lib/core/services/api_service.dart`
  - `lib/features/chat/chat_screen.dart`
  - `pubspec.yaml` (إضافة `geolocator`)

### 5. حالة الاتصال الفعلية (متصل/غير متصل) ✅
- **الوصف**: عرض حالة الاتصال الفعلية للمستخدمين
- **الميزات**:
  - تحديث `last_seen` تلقائياً كل دقيقتين
  - فحص حالة الاتصال كل 30 ثانية
  - عرض "متصل الآن" إذا كان آخر نشاط خلال 5 دقائق
  - عرض "غير متصل" إذا تجاوز 5 دقائق
  - مؤشر أخضر في قائمة المحادثات للمستخدمين المتصلين
- **الملفات المعدلة**:
  - `server_files/sql.php` (إضافة `update_online_status`, `get_user_status`)
  - `lib/core/services/api_service.dart`
  - `lib/features/chat/chat_screen.dart`
  - `lib/features/chat/conversations_screen.dart`

## متطلبات قاعدة البيانات

يجب إضافة الأعمدة التالية لجدول `Chat_Messages`:
```sql
ALTER TABLE Chat_Messages 
ADD COLUMN conversation_id VARCHAR(255),
ADD COLUMN message_type VARCHAR(50) DEFAULT 'text',
ADD COLUMN location_lat DECIMAL(10, 8),
ADD COLUMN location_lng DECIMAL(11, 8);
```

يجب إضافة عمود `last_seen` لجدول `Users`:
```sql
ALTER TABLE Users 
ADD COLUMN last_seen DATETIME DEFAULT CURRENT_TIMESTAMP;
```

## التثبيت

1. تشغيل `flutter pub get` لتثبيت المكتبات الجديدة
2. تنفيذ استعلامات SQL أعلاه على قاعدة البيانات
3. إضافة الأذونات التالية في `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

4. إضافة الأذونات في `Info.plist` لـ iOS:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>نحتاج للوصول إلى موقعك لإرساله في المحادثة</string>
```

## الاختبار

1. **اختبار شريط التقدم**:
   - رفع منتج جديد مع صور/فيديوهات
   - التحقق من ظهور الإشعار مع نسبة التقدم
   - الخروج من التطبيق والتحقق من استمرار الرفع

2. **اختبار المحادثات**:
   - إنشاء طلب جديد والتواصل مع البائع
   - التحقق من إنشاء محادثة جديدة
   - فتح صفحة الأرشيف والتحقق من ظهور كل المحادثات

3. **اختبار الموقع**:
   - الضغط على زر الموقع في المحادثة
   - السماح بالوصول للموقع
   - التحقق من إرسال الموقع
   - الضغط على رسالة الموقع للتحقق من فتح الخرائط

4. **اختبار حالة الاتصال**:
   - فتح المحادثة والتحقق من حالة الاتصال
   - الانتظار 5 دقائق والتحقق من تغيير الحالة
   - فتح قائمة المحادثات والتحقق من المؤشر الأخضر

## ملاحظات

- يتم تحديث حالة الاتصال كل دقيقتين تلقائياً
- المستخدم يعتبر متصلاً إذا كان آخر نشاط خلال 5 دقائق
- يتم حفظ جميع المحادثات في قاعدة البيانات
- إرسال الموقع يتطلب إذن المستخدم
- الإشعارات تعمل في الخلفية حتى عند إغلاق التطبيق
