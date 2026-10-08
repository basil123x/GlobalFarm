import 'dart:async';
import 'package:GlobalFarm/core/services/onesignal_service.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/services/translation_service.dart';
import 'package:GlobalFarm/core/models/chat_model.dart';
import 'package:GlobalFarm/core/widgets/chat_location_preview.dart';
import 'package:GlobalFarm/core/widgets/smart_avatar_widget.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import 'package:GlobalFarm/features/profile/profile_screen.dart';
import 'package:GlobalFarm/features/profile/seller_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String? receiverName;
  final String? receiverAvatar;
  final String? receiverToken;
  final String? conversationId;
  final bool isOnline;

  const ChatScreen({
    super.key,
    required this.receiverId,
    this.receiverName,
    this.receiverAvatar,
    this.receiverToken,
    this.conversationId,
    this.isOnline = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isFirstLoad = true; // ✅ للتفريق بين التحميل الأول والـ polling
  bool _isSending = false;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserAvatar;
  String? _currentConversationId;
  bool _isOnline = false;
  Timer? _statusUpdateTimer;
  Timer? _statusCheckTimer;
  Timer? _messagePollingTimer; // ✅ Timer للـ polling

  // ✅ الرسائل التي طلب المستخدم رؤية نصها الأصلي بدلاً من الترجمة
  final Set<String> _showOriginal = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _startStatusUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _statusUpdateTimer?.cancel();
    _statusCheckTimer?.cancel();
    _messagePollingTimer?.cancel(); // ✅ إلغاء الـ polling timer
    super.dispose();
  }

  // ✅ عند العودة للتطبيق - تحديث فوري
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkUserStatus(); // تحديث فوري
    }
  }

  void _startStatusUpdates() {
    // ✅ تحديث حالتك كل 30 ثانية (كفاية)
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (_currentUserId != null) {
        await ApiService.updateOnlineStatus(userId: _currentUserId!);
      }
    });

    // ✅ تحقق من حالة الطرف الآخر كل 3 ثواني (سريع وفوري)
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      await _checkUserStatus();
    });
  }

  Future<void> _initializeChat() async {
    _currentUserId = await AuthService.getCurrentUserId();
    _currentUserName = await AuthService.getCurrentName();
    _currentUserAvatar = await AuthService.getCurrentProfileImage();
    _currentConversationId = widget.conversationId;

    if (_currentUserId != null) {
      // Update own status immediately
      await ApiService.updateOnlineStatus(userId: _currentUserId!);
      await _loadMessages();
      await _checkUserStatus();

      // ✅ بدء polling للرسائل كل 3 ثواني
      _startMessagePolling();
    }
  }

  // ✅ Polling للرسائل الجديدة
  void _startMessagePolling() {
    _messagePollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadMessages(isPolling: true);
    });
  }

  Future<void> _checkUserStatus() async {
    try {
      final result = await ApiService.getUserStatus(userId: widget.receiverId);
      if (result['success'] == true && mounted) {
        final minutesAgo = result['minutes_ago'] ?? 999;
        setState(() {
          // ✅ متصل لو آخر ظهور أقل من دقيقة
          _isOnline = minutesAgo < 1;
        });
      }
    } catch (e) {
      print('Error checking user status: $e');
    }
  }

  Future<void> _loadMessages({bool isPolling = false}) async {
    // ✅ لا نظهر loading spinner أثناء الـ polling
    if (!isPolling) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final result = await ApiService.getChatMessages(
        senderId: _currentUserId!,
        receiverId: widget.receiverId,
      );

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        final newMessages = data
            .map((item) => ChatMessage.fromJson(item))
            .toList();

        // ✅ تحقق إذا وصلت رسائل جديدة
        final hadNewMessages = newMessages.length > _messages.length;

        setState(() {
          _messages = newMessages;
          _isLoading = false;
          _isFirstLoad = false;
        });

        // ✅ scroll للأسفل فقط إذا وصلت رسائل جديدة أو كان التحميل الأول
        if (hadNewMessages || !isPolling) {
          _scrollToBottom();
        }

        // ✅ ترجمة الرسائل التي لغتها مختلفة عن لغة التطبيق (بدون تعطيل العرض)
        _translateMessages();
      } else {
        setState(() {
          _isLoading = false;
          _isFirstLoad = false;
        });
      }
    } catch (e) {
      print('Error loading messages: $e');
      if (!isPolling) {
        setState(() {
          _isLoading = false;
          _isFirstLoad = false;
        });
      }
    }
  }

  // ✅ الترجمة التلقائية: أي رسالة نصية لغتها مختلفة عن لغة التطبيق تُترجم
  // مرة واحدة، والسيرفر يخزّن النتيجة فلا تتكرر التكلفة.
  Future<void> _translateMessages() async {
    final targetLang = LocalizationService.instance.currentLanguage;

    // الرسائل الواردة فقط — ما كتبته أنت لا يحتاج ترجمة
    final candidates = _messages
        .where(
          (m) =>
              m.messageType == 'text' &&
              m.message.trim().isNotEmpty &&
              m.senderId != _currentUserId,
        )
        .map((m) => (id: m.id, text: m.message))
        .toList();

    if (candidates.isEmpty) return;

    final changed = await TranslationService.instance.translateMessages(
      messages: candidates,
      targetLang: targetLang,
    );

    if (changed && mounted) setState(() {});
  }

  Future<void> _launchUrl(latitude, longitude) async {
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _sendMessage({
    String? locationMessage,
    double? lat,
    double? lng,
  }) async {
    final messageText = locationMessage ?? _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;

    if (locationMessage == null) {
      _messageController.clear();
    }

    setState(() {
      _isSending = true;
    });

    try {
      final result = await ApiService.sendChatMessage(
        senderId: _currentUserId!,
        receiverId: widget.receiverId,
        message: messageText,
        conversationId: _currentConversationId,
        messageType: locationMessage != null ? 'location' : 'text',
        locationLat: lat,
        locationLng: lng,
      );

      if (result['success'] == true) {
        // Update conversation ID if it's a new conversation
        if (_currentConversationId == null &&
            result['conversation_id'] != null) {
          setState(() {
            _currentConversationId = result['conversation_id'].toString();
          });
        }

        // Add message to local list immediately
        final newMessage = ChatMessage(
          id:
              result['message_id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: _currentUserId!,
          receiverId: widget.receiverId,
          message: messageText,
          timestamp: DateTime.now(),
          isRead: false,
          conversationId: _currentConversationId,
          messageType: locationMessage != null ? 'location' : 'text',
          locationLat: lat,
          locationLng: lng,
        );
        setState(() {
          _messages.add(newMessage);
        });
        _scrollToBottom();

        String? name = await AuthService.getCurrentName() ?? 'مستخدم';

        if (widget.receiverToken != null) {
          await OneSignalService.sendNotificationToUser(
            playerId: widget.receiverToken!,
            title: name,
            message: messageText,
            data: {
              "receiverId": _currentUserId ?? '',
              "receiverName": _currentUserName ?? '',
              "receiverAvatar": _currentUserAvatar ?? '',
              "receiverToken": '',
              "conversationId": _currentConversationId ?? '',
              "isOnline": false,
            },
          );
        }
      } else {
        showAppSnackbar(
          context,
          message: result['error'] ?? tr('chat.send_failed'),
          type: SnackType.error,
        );
      }
    } catch (e) {
      showAppSnackbar(
        context,
        message: tr('chat.send_error'),
        type: SnackType.error,
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        // backgroundColor: const Color(0xFF0A0E27),
        backgroundColor: context.appBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            // icon: const Icon(Iconsax.arrow_right_3, color: Colors.white),
            icon: Icon(Iconsax.arrow_right, color: context.appTextPrimary),
          ),
          title: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SellerProfileScreen(userId: widget.receiverId),
              ),
            ),
            child: Row(
              children: [
                _buildReceiverAvatar(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.receiverName ?? tr('chat.user'),
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {
                showAppSnackbar(
                  context,
                  message: tr('chat.voice_calls_soon'),
                  type: SnackType.info,
                );
              },
              icon: Icon(Iconsax.call, color: context.appTextPrimary),
            ),
          ],
        ),
        body: Column(
          children: [
            // Messages List
            Expanded(
              // ✅ نظهر loading فقط في التحميل الأول
              child: _isLoading && _isFirstLoad
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),

            // Message Input
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Iconsax.message,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('chat.start_new_conversation'),
            style: TextStyle(
              // color: Colors.white,
              color: context.appTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${tr('chat.send_message_to_start')} '
            '${widget.receiverName ?? tr('chat.user')}',
            style: TextStyle(
              // color: Colors.white.withOpacity(0.7),
              color: context.appTextSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReceiverAvatar({required double size}) {
    return SmartAvatarWidget(
      userId: widget.receiverId,
      name: widget.receiverName ?? "",
      size: size,
      fallbackUrl: widget.receiverAvatar,
      backgroundColor: AppColors.primary,
      initialsStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: size * 0.4,
      ),
    );
  }

  // ✅ نص الرسالة: يعرض الترجمة إن وُجدت مع إمكانية الرجوع للنص الأصلي
  Widget _buildMessageText(ChatMessage message, bool isMyMessage) {
    final targetLang = LocalizationService.instance.currentLanguage;
    final translation = TranslationService.instance.cachedTranslation(
      message.id,
      targetLang,
    );
    final isTranslating = TranslationService.instance.isTranslating(
      message.id,
      targetLang,
    );
    final showingOriginal = _showOriginal.contains(message.id);

    final displayText = translation != null && !showingOriginal
        ? translation.text
        : message.message;

    final textColor = isMyMessage ? Colors.white : context.appTextPrimary;
    final hintColor = isMyMessage
        ? Colors.white.withOpacity(0.75)
        : context.appTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayText,
          textDirection: _textDirectionOf(displayText),
          style: TextStyle(color: textColor, fontSize: 16),
        ),

        if (translation != null) ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() {
              if (showingOriginal) {
                _showOriginal.remove(message.id);
              } else {
                _showOriginal.add(message.id);
              }
            }),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.translate, size: 13, color: hintColor),
                  const SizedBox(width: 4),
                  Text(
                    showingOriginal
                        ? tr('chat.show_translation')
                        : tr('chat.show_original'),
                    style: TextStyle(
                      color: hintColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else if (isTranslating) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: hintColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                // أول مرة يتم فيها تحميل موديل اللغة تأخذ وقتاً أطول
                TranslationService.instance.isPreparingModels
                    ? tr('chat.preparing_translation')
                    : tr('chat.translating'),
                style: TextStyle(color: hintColor, fontSize: 11),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ✅ اتجاه النص حسب حروفه، لأن الشاشة كلها مثبتة على RTL
  TextDirection _textDirectionOf(String text) {
    final lang = TranslationService.guessLanguage(text);
    if (lang == null) return TextDirection.rtl;
    return lang == 'ar' ? TextDirection.rtl : TextDirection.ltr;
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMyMessage = message.senderId == _currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMyMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                    SellerProfileScreen(userId: widget.receiverId),
                ),
              ),
              child: _buildReceiverAvatar(size: 32),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              padding: message.messageType == 'location'
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                // gradient: isMyMessage
                //     ? LinearGradient(
                //         colors: [
                //           AppColors.primary,
                //           AppColors.primary.withOpacity(0.8),
                //         ],
                //       )
                //     : LinearGradient(
                //         colors: [
                //           Colors.white.withOpacity(0.1),
                //           Colors.white.withOpacity(0.05),
                //         ],
                //       ),
                // borderRadius: BorderRadius.only(
                //   topLeft: const Radius.circular(16),
                //   topRight: const Radius.circular(16),
                //   bottomLeft: isMyMessage
                //       ? const Radius.circular(16)
                //       : const Radius.circular(4),
                //   bottomRight: isMyMessage
                //       ? const Radius.circular(4)
                //       : const Radius.circular(16),
                color: isMyMessage
                    ? AppColors.primary
                    : (context.isDarkMode
                          ? AppColors.darkSurface
                          : const Color(0xFFE8EAF6)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMyMessage
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isMyMessage
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
                border: !isMyMessage
                    ? Border.all(color: context.appBorder)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.messageType == 'location' &&
                      message.locationLat != null &&
                      message.locationLng != null)
                    ChatLocationPreview(
                      latitude: message.locationLat!,
                      longitude: message.locationLng!,
                      timeLabel: _formatTime(message.timestamp),
                      showReadReceipt: isMyMessage,
                      isRead: message.isRead,
                      onTap: () => _launchUrl(
                        message.locationLat,
                        message.locationLng,
                      ),
                    )
                  else if (message.messageType == 'location')
                    const SizedBox.shrink()
                  else
                    _buildMessageText(message, isMyMessage),
                  if (message.messageType != 'location') ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            color: isMyMessage
                                ? Colors.white.withOpacity(0.7)
                                : context.appTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (isMyMessage) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead
                                ? Iconsax.tick_circle
                                : Iconsax.tick_square,
                            size: 14,
                            color: message.isRead
                                ? Colors.blue.shade300
                                : Colors.white.withOpacity(0.7),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (isMyMessage) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_currentUserId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: _currentUserId!),
                    ),
                  );
                }
              },
              child: _buildSenderAvatar(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSenderAvatar() {
    if (_currentUserId == null) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.primary,
        child: Text(
          _currentUserName != null && _currentUserName!.isNotEmpty
              ? _currentUserName![0]
              : tr('chat.user_initial'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return SmartAvatarWidget(
      userId: _currentUserId!,
      name: _currentUserName ?? "",
      size: 32,
      loadSocialFromStorage: true,
      backgroundColor: AppColors.primary,
      initialsStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Future<void> _sendLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          showAppSnackbar(
            context,
            message: tr('chat.location_permission_required'),
            type: SnackType.warning,
          );
          return;
        }
      }

      // Get current location
      Position position = await Geolocator.getCurrentPosition();

      // Send location message
      await _sendMessage(
        locationMessage: 'موقعي الحالي',
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (e) {
      print('Error getting location: $e');
      showAppSnackbar(
        context,
        message: tr('chat.location_failed'),
        type: SnackType.error,
      );
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: context.bottomBarGradient(),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        border: Border.all(color: context.appBorder),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Location button
            GestureDetector(
              onTap: _sendLocation,
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(22.5),
                  border: Border.all(color: context.appBorder),
                ),
                child: const Icon(
                  Iconsax.location,
                  // color: Colors.white,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.isDarkMode
                      ? AppColors.darkElevated.withOpacity(0.6)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: context.appBorder),
                ),
                child: TextField(
                  controller: _messageController,
                  // style: const TextStyle(color: Colors.white),
                  style: TextStyle(color: context.appTextPrimary),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: tr('chat.type_message'),
                    hintStyle: TextStyle(
                      // color: Colors.white.withOpacity(0.5)
                      color: context.appTextSecondary.withOpacity(0.8),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isSending
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : Transform.flip(
                        flipX: true,
                        child: const Icon(
                          Iconsax.send_1,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${timestamp.day}/${timestamp.month}';
    } else if (difference.inHours > 0) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inMinutes > 0) {
      return tr('chat.minutes_ago', {'n': difference.inMinutes});
    } else {
      return tr('chat.now');
    }
  }
}
