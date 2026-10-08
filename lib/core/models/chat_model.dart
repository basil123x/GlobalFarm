class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? conversationId;
  final String messageType; // 'text', 'location'
  final double? locationLat;
  final double? locationLng;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    required this.isRead,
    this.conversationId,
    this.messageType = 'text',
    this.locationLat,
    this.locationLng,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      conversationId: json['conversation_id']?.toString(),
      messageType: json['message_type']?.toString() ?? 'text',
      locationLat: json['location_lat'] != null
          ? double.tryParse(json['location_lat'].toString())
          : null,
      locationLng: json['location_lng'] != null
          ? double.tryParse(json['location_lng'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead ? 1 : 0,
      'conversation_id': conversationId,
      'message_type': messageType,
      'location_lat': locationLat,
      'location_lng': locationLng,
    };
  }
}

class ChatConversation {
  final String id;
  final String conversationId;
  final String participantId;
  final String participantName;
  final String participantAvatar;
  final String participantToken;
  final ChatMessage? lastMessage;
  final int unreadCount;

  ChatConversation({
    required this.id,
    required this.conversationId,
    required this.participantId,
    required this.participantName,
    required this.participantAvatar,
    required this.participantToken,
    this.lastMessage,
    required this.unreadCount,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      // ✅ استخدام participant_id كـ id إذا لم يكن id موجوداً
      id: json['id']?.toString() ?? json['participant_id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      participantId: json['participant_id']?.toString() ?? '',
      participantName: json['participant_name']?.toString() ?? '',
      participantAvatar: json['participant_avatar']?.toString() ?? '',
      participantToken: json['participant_token']?.toString() ?? '',
      lastMessage: json['last_message'] != null && json['last_message'] is Map
          ? ChatMessage.fromJson(json['last_message'])
          : (json['last_message'] != null && json['last_message'] is String
                ? ChatMessage(
                    id: '',
                    senderId: '',
                    receiverId: '',
                    message: json['last_message'].toString(),
                    timestamp:
                        DateTime.tryParse(
                          json['last_message_time']?.toString() ?? '',
                        ) ??
                        DateTime.now(),
                    isRead: false,
                  )
                : null),
      unreadCount: int.tryParse(json['unread_count']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'participant_id': participantId,
      'participant_name': participantName,
      'participant_avatar': participantAvatar,
      'participant_token': participantToken,
      'last_message': lastMessage?.toJson(),
      'unread_count': unreadCount,
    };
  }
}
