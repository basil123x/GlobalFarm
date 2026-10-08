# دليل الإعداد السريع - نظام الطلبات

## ⚠️ خطوات مهمة قبل الاستخدام

### 1️⃣ إنشاء جدول Orders في قاعدة البيانات

افتح phpMyAdmin أو أي أداة لإدارة قاعدة البيانات وقم بتشغيل هذا الكود:

```sql
CREATE TABLE IF NOT EXISTS `Orders` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uid` text NOT NULL COMMENT 'معرف البائع',
  `cust_id` text NOT NULL COMMENT 'معرف العميل/المشتري',
  `oid` text NOT NULL COMMENT 'رقم الطلب',
  `ship_id` text DEFAULT NULL COMMENT 'معرف عنوان الشحن',
  `created_at` text NOT NULL COMMENT 'تاريخ إنشاء الطلب',
  `status` varchar(50) NOT NULL DEFAULT 'pending' COMMENT 'حالة الطلب',
  `items` text DEFAULT NULL COMMENT 'المنتجات بصيغة JSON',
  `total_amount` text DEFAULT NULL COMMENT 'المبلغ الإجمالي',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

أو قم بتشغيل الملف: `server_files/create_orders_table.sql`

### 2️⃣ رفع الملفات على السيرفر

ارفع هذه الملفات على السيرفر في مجلد `app2026`:

✅ `server_files/sql.php` (تم تحديثه - استبدل القديم)
✅ `server_files/invoice.php` (ملف جديد)

### 3️⃣ التأكد من الأعمدة في جدول Orders

تأكد من وجود هذه الأعمدة في جدول Orders:

| العمود | النوع | الوصف |
|--------|------|-------|
| id | INT AUTO_INCREMENT | المعرف الفريد |
| uid | TEXT | معرف البائع |
| cust_id | TEXT | معرف العميل |
| oid | TEXT | رقم الطلب |
| ship_id | TEXT | معرف عنوان الشحن |
| created_at | TEXT | تاريخ الطلب |
| status | VARCHAR(50) | حالة الطلب |
| items | TEXT | المنتجات JSON |
| total_amount | TEXT | المبلغ الإجمالي |

## 🚀 كيفية الاستخدام

### للمشتري (طلباتي):
1. افتح التطبيق
2. اضغط على زر "المزيد" (الثلاث نقاط)
3. اختر "طلباتي"
4. ستظهر جميع طلباتك
5. اضغط على "عرض الفاتورة" لأي طلب

### للبائع (طلبات العملاء):
1. افتح التطبيق
2. اضغط على زر "المزيد" (الثلاث نقاط)
3. اختر "طلبات العملاء"
4. ستظهر جميع طلبات عملائك
5. اضغط على "عرض الفاتورة" لأي طلب

## 🔍 التحقق من عمل النظام

### اختبار إنشاء طلب:
1. أضف منتجات إلى السلة
2. اذهب إلى السلة
3. اضغط "ملخص الطلب"
4. أضف عنوان شحن
5. اضغط "إكمال الدفع"
6. ✅ يجب أن يتم إنشاء الطلب تلقائياً

### التحقق من قاعدة البيانات:
```sql
SELECT * FROM Orders ORDER BY id DESC LIMIT 10;
```

يجب أن ترى الطلبات الجديدة في الجدول.

## ❗ حل المشاكل الشائعة

### المشكلة: "الطلب غير موجود" عند فتح الفاتورة
**الحل:**
- تأكد من رفع ملف `invoice.php`
- تأكد من أن رابط السيرفر صحيح في الكود

### المشكلة: لا تظهر الطلبات
**الحل:**
- تأكد من إنشاء جدول Orders
- تأكد من رفع `sql.php` المحدث
- تحقق من تسجيل الدخول

### المشكلة: لا تُنشأ الطلبات عند الشراء
**الحل:**
- افتح Console في Flutter
- ابحث عن رسائل الخطأ
- تأكد من وجود عنوان شحن

## 📱 الصلاحيات المطلوبة

تأكد من إضافة صلاحيات فتح الروابط:

### Android (AndroidManifest.xml):
```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="https" />
  </intent>
</queries>
```

### iOS (Info.plist):
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>https</string>
  <string>http</string>
</array>
```

## ✨ الميزات

✅ إنشاء طلبات تلقائياً عند الشراء
✅ فصل الطلبات حسب البائع
✅ عرض طلباتي كمشتري
✅ عرض طلبات العملاء كبائع
✅ فواتير احترافية قابلة للطباعة
✅ معلومات شحن كاملة
✅ حالة الطلب (قيد المعالجة/مكتمل/ملغي)

## 📞 الدعم

إذا واجهت أي مشكلة:
1. راجع هذا الدليل
2. تحقق من Console logs
3. راجع ملف `ORDERS_SYSTEM_README.md` للتفاصيل الكاملة

---

**ملاحظة مهمة:** يجب تنفيذ الخطوة 1 (إنشاء جدول Orders) قبل استخدام النظام، وإلا لن يعمل!
