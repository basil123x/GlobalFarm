# ميزة تحديث حالة الطلبات للبائع

## الوصف
تم إضافة ميزة تسمح للبائع بتحديث حالة طلبات العملاء بسهولة من خلال Bottom Modal Sheet يحتوي على جميع الحالات المتاحة.

## الحالات المتاحة
1. **Pending** - قيد الانتظار (برتقالي)
2. **Preparing** - قيد التحضير (أزرق)
3. **ReadyToShip** - جاهز للشحن (بنفسجي)
4. **Shipping** - قيد الشحن (نيلي)
5. **Delivered** - تم التوصيل (أخضر)

## التعديلات المنفذة

### 1. Backend - sql.php
تم إضافة API endpoint جديد:
- **Action**: `update_order_status`
- **Parameters**:
  - `order_id`: معرف الطلب (oid)
  - `status`: الحالة الجديدة
- **Response**: 
  ```json
  {
    "success": true,
    "message": "تم تحديث حالة الطلب بنجاح",
    "new_status": "Preparing"
  }
  ```

### 2. ApiService - api_service.dart
تم إضافة دالة جديدة:
```dart
static Future<Map<String, dynamic>> updateOrderStatus({
  required String orderId,
  required String status,
}) async
```

### 3. CustomerOrdersScreen - customer_orders_screen.dart
تم إضافة:
- **_showStatusBottomSheet()**: عرض Bottom Modal Sheet مع جميع الحالات
- **_buildStatusOption()**: بناء خيار حالة واحد في القائمة
- **_updateOrderStatus()**: تحديث حالة الطلب في قاعدة البيانات
- تحديث **_getStatusColor()**: لدعم جميع الحالات الجديدة
- تحديث **_getStatusText()**: لعرض النصوص العربية لكل حالة

## كيفية الاستخدام
1. يفتح البائع شاشة "طلبات العملاء"
2. يضغط على حالة الطلب الحالية (مثل "قيد الانتظار")
3. يظهر Bottom Modal Sheet مع جميع الحالات المتاحة
4. يختار البائع الحالة الجديدة
5. يتم تحديث الحالة فوراً في قاعدة البيانات
6. تظهر رسالة نجاح وتُحدث قائمة الطلبات

## مميزات الواجهة
- تصميم عصري مع Bottom Modal Sheet
- أيقونات مميزة لكل حالة
- ألوان مختلفة لكل حالة لسهولة التمييز
- الحالة الحالية تظهر بتصميم مميز مع علامة صح
- لا يمكن اختيار الحالة الحالية مرة أخرى
- مؤشر تحميل أثناء التحديث
- رسائل نجاح/فشل واضحة

## الأمان
- التحقق من صحة الحالة في Backend
- فقط الحالات المسموح بها يمكن تحديثها
- استخدام prepared statements لمنع SQL Injection

## الملفات المعدلة
1. `/server_files/sql.php` - إضافة API endpoint
2. `/lib/core/services/api_service.dart` - إضافة دالة API
3. `/lib/features/orders/customer_orders_screen.dart` - إضافة UI والوظائف

## ملاحظات
- يتم تحديث الحالة فوراً في قاعدة البيانات
- القائمة تُحدث تلقائياً بعد التحديث الناجح
- التصميم يدعم RTL للغة العربية
