-- إنشاء جدول Orders لتخزين الطلبات
-- يجب تشغيل هذا الملف على قاعدة البيانات قبل استخدام نظام الطلبات

CREATE TABLE IF NOT EXISTS `Orders` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uid` text NOT NULL COMMENT 'معرف البائع',
  `cust_id` text NOT NULL COMMENT 'معرف العميل/المشتري',
  `oid` text NOT NULL COMMENT 'رقم الطلب',
  `ship_id` text DEFAULT NULL COMMENT 'معرف عنوان الشحن',
  `created_at` text NOT NULL COMMENT 'تاريخ إنشاء الطلب',
  `status` varchar(50) NOT NULL DEFAULT 'pending' COMMENT 'حالة الطلب: pending, completed, cancelled',
  `items` text DEFAULT NULL COMMENT 'المنتجات بصيغة JSON',
  `total_amount` text DEFAULT NULL COMMENT 'المبلغ الإجمالي',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ملاحظات:
-- 1. uid: معرف البائع الذي يملك المنتجات في الطلب
-- 2. cust_id: معرف العميل الذي قام بالطلب
-- 3. oid: رقم الطلب الفريد
-- 4. ship_id: معرف عنوان الشحن من جدول Shipping_Orders
-- 5. created_at: تاريخ ووقت إنشاء الطلب
-- 6. status: حالة الطلب (pending = قيد المعالجة، completed = مكتمل، cancelled = ملغي)
-- 7. items: بيانات المنتجات بصيغة JSON تحتوي على (id, name, price, quantity)
-- 8. total_amount: المبلغ الإجمالي للطلب

-- مثال على بيانات items:
-- [{"id":"123","name":"منتج 1","price":"100.00","quantity":2},{"id":"124","name":"منتج 2","price":"50.00","quantity":1}]
