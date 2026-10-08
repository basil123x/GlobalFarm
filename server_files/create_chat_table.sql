-- إنشاء جدول رسائل الدردشة
CREATE TABLE IF NOT EXISTS Chat_Messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sender_id VARCHAR(50) NOT NULL,
    receiver_id VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_read TINYINT(1) DEFAULT 0,
    INDEX idx_sender_receiver (sender_id, receiver_id),
    INDEX idx_timestamp (timestamp),
    INDEX idx_is_read (is_read)
);

-- إضافة فهارس لتحسين الأداء
ALTER TABLE Chat_Messages 
ADD INDEX idx_conversation (sender_id, receiver_id, timestamp);

-- إضافة عمود fcm_token في جدول Users إذا لم يكن موجوداً
ALTER TABLE Users 
ADD COLUMN fcm_token VARCHAR(255) NULL 
AFTER phone;
