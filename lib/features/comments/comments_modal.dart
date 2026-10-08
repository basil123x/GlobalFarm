import 'package:GlobalFarm/core/services/onesignal_service.dart';
import 'package:GlobalFarm/features/auth/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/models/item_model.dart';
import 'package:GlobalFarm/core/widgets/smart_avatar_widget.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';

class CommentsModal extends StatefulWidget {
  final String itemId;
  final bool isLoggedIn;
  final ItemModel items;

  const CommentsModal({
    super.key,
    required this.itemId,
    required this.isLoggedIn,
    required this.items,
  });

  @override
  State<CommentsModal> createState() => _CommentsModalState();
}

class _CommentsModalState extends State<CommentsModal> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.getComments(int.parse(widget.itemId));

      if (response['success'] == true) {
        final List<dynamic> commentsData = response['data'] ?? [];
        setState(() {
          _comments = commentsData
              .map((comment) => CommentModel.fromJson(comment))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _comments = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _comments = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;

    if (!widget.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final currentUserId = await AuthService.getCurrentUserId();
      if (currentUserId == null) {
        showAppSnackbar(
          context,
          message: 'يجب تسجيل الدخول أولاً',
          type: SnackType.error,
        );
        setState(() {
          _isSending = false;
        });
        return;
      }

      final response = await ApiService.addComment(
        itemId: int.parse(widget.itemId),
        userId: currentUserId,
        comment: _commentController.text.trim(),
      );
      final user = await FlutterSecureStorage().read(key: 'user_name');

      OneSignalService.sendNotificationToUser(
        playerId: widget.items.seller.token,
        title: "تعليق جديد من $user",
        message: _commentController.text.trim(),
      );

      if (response['success'] == true) {
        _commentController.clear();
        _loadComments(); // Reload comments

        // Scroll to bottom
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      } else {
        showAppSnackbar(
          context,
          message: 'فشل في إرسال التعليق',
          type: SnackType.error,
        );
      }
    } catch (e) {
      showAppSnackbar(
        context,
        message: 'حدث خطأ في إرسال التعليق',
        type: SnackType.error,
      );
    }

    setState(() {
      _isSending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: keyboardHeight > 0
          ? screenHeight *
                0.9 // عند فتح الكيبورد
          : screenHeight * 0.8, // الحالة العادية
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),

          // Comments List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _comments.isEmpty
                ? _buildEmptyState()
                : _buildCommentsList(),
          ),

          // Comment Input
          _buildCommentInput(),

          // Add padding for keyboard
          if (keyboardHeight > 0) SizedBox(height: keyboardHeight),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.appCardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Iconsax.close_square, size: 24),
          ),
          const Text(
            'التعليقات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 40), // Balance the close button
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.message, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'لا توجد تعليقات بعد',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'كن أول من يعلق على هذا المنتج',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        return _buildCommentItem(_comments[index]);
      },
    );
  }

  Widget _buildCommentItem(CommentModel comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar
          SmartAvatarWidget(
            userId: comment.userId,
            name: comment.userName,
            size: 40,
            fallbackUrl: comment.userAvatar,
            backgroundColor: AppColors.secondary,
            initialsStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(width: 12),

          // Comment Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // User Name and Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(comment.createdAt),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Comment Text
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.appSurfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    comment.comment,
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.appSurfaceVariant)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Send Button
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isSending ? null : _sendComment,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Iconsax.send_1, color: Colors.white, size: 20),
              ),
            ),

            const SizedBox(width: 12),

            // Text Input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.appSurfaceVariant,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _commentController,
                  textAlign: TextAlign.right,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: 'اكتب تعليقك...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendComment(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _parseCommentTime(String timestamp) {
    final normalized = timestamp.trim();
    if (normalized.isEmpty) return DateTime.now();

    final iso = normalized.contains('T')
        ? normalized
        : normalized.replaceFirst(' ', 'T');
    if (iso.endsWith('Z') ||
        iso.contains('+') ||
        RegExp(r'-\d{2}:\d{2}$').hasMatch(iso)) {
      return DateTime.parse(iso).toLocal();
    }
    return DateTime.parse('${iso}Z').toLocal();
  }

  String _formatTime(String timestamp) {
    try {
      final DateTime dateTime = _parseCommentTime(timestamp);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} يوم';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ساعة';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} دقيقة';
      } else {
        return 'الآن';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
