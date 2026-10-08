import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/models/chat_model.dart';
import 'package:GlobalFarm/core/widgets/smart_avatar_widget.dart';
import 'chat_screen.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';

class ConversationsScreen extends StatefulWidget {
  final String userId;

  const ConversationsScreen({super.key, required this.userId});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<ChatConversation> _conversations = [];
  final Map<String, bool> _onlineStatuses = {};
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _startStatusChecks();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  void _startStatusChecks() {
    // Check statuses every 15 seconds for real-time updates
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _checkAllStatuses();
    });
  }

  Future<void> _checkAllStatuses() async {
    for (var conversation in _conversations) {
      try {
        final result = await ApiService.getUserStatus(
          userId: conversation.participantId,
        );
        if (result['success'] == true && mounted) {
          setState(() {
            _onlineStatuses[conversation.participantId] =
                result['is_online'] == true || result['is_online'] == 1;
          });
        }
      } catch (e) {
        print('Error checking status for ${conversation.participantId}: $e');
      }
    }
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      print('🔍 Loading conversations for user: ${widget.userId}');
      final result = await ApiService.getChatConversations(
        userId: widget.userId,
      );
      print('📦 Conversations API response: $result');

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        print('✅ Found ${data.length} unique conversations');

        setState(() {
          _conversations = data
              .map((item) => ChatConversation.fromJson(item))
              .toList();
          _isLoading = false;
        });
        // Check statuses after loading conversations
        _checkAllStatuses();
      } else {
        print('❌ API returned success=false: ${result['error']}');
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading conversations: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print(widget.userId);
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
          title: Text(
            tr('chat.title'),
            style: TextStyle(
              // color: Colors.white,
              color: context.appTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Material(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _loadConversations,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.appBorder),
                    ),
                    child: Icon(
                      Iconsax.refresh,
                      size: 20,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _hasError
            ? _buildErrorWidget()
            : _conversations.isEmpty
            ? _buildEmptyWidget()
            : RefreshIndicator(
                onRefresh: _loadConversations,
                color: AppColors.primary,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    return _buildConversationCard(_conversations[index]);
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.warning_2, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            tr('chat.load_error'),
            style: TextStyle(
              // color: Colors.white,
              color: context.appTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadConversations,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(tr('chat.retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Iconsax.message,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr('chat.no_conversations'),
            style: TextStyle(
              // color: Colors.white,
              color: context.appTextPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('chat.start_chat_with_sellers'),
            style: TextStyle(
              // color: Colors.white.withOpacity(0.7),
              color: context.appTextSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              tr('chat.browse_products'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationCard(ChatConversation conversation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            SmartAvatarWidget(
              userId: conversation.participantId,
              name: conversation.participantName,
              size: 56,
              fallbackUrl: conversation.participantAvatar,
              backgroundColor: AppColors.primary,
              initialsStyle: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Online indicator
            if (_onlineStatuses[conversation.participantId] == true)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                conversation.participantName,
                style: TextStyle(
                  // color: Colors.white,
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (conversation.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  conversation.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Online status
              if (_onlineStatuses[conversation.participantId] == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tr('chat.online_now'),
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              // Last message
              Row(
                children: [
                  Expanded(
                    child: Text(
                      conversation.lastMessage?.message ??
                          tr('chat.start_new_conversation'),
                      style: TextStyle(
                        // color: Colors.white.withOpacity(0.7),
                        color: context.appTextSecondary,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (conversation.lastMessage != null)
                    Text(
                      _formatTime(conversation.lastMessage!.timestamp),
                      style: TextStyle(
                        // color: Colors.white.withOpacity(0.5),
                        color: context.appTextSecondary.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: const Icon(
            Iconsax.message,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                receiverId: conversation.participantId,
                receiverName: conversation.participantName,
                receiverAvatar: conversation.participantAvatar,
                receiverToken: conversation.participantToken,
                conversationId: conversation.conversationId,
                isOnline: _onlineStatuses[conversation.participantId] ?? false,
              ),
            ),
          ).then((_) {
            // Refresh conversations when returning from chat
            _loadConversations();
          });
        },
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return tr('chat.yesterday');
      } else if (difference.inDays < 7) {
        return tr('chat.days_ago', {'n': difference.inDays});
      } else {
        return '${timestamp.day}/${timestamp.month}';
      }
    } else if (difference.inHours > 0) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inMinutes > 0) {
      return tr('chat.minutes_ago', {'n': difference.inMinutes});
    } else {
      return tr('chat.now');
    }
  }
}
