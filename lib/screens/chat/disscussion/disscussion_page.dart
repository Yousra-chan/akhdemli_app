import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/models/MessageModel.dart';
import 'package:intl/intl.dart';
import 'package:service_app/Services/notification_service.dart';
import 'package:service_app/Services/firebase_service.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:service_app/utils/ui_widgets.dart';
import '../../../ViewModel/auth_view_model.dart';
import '../../../utils/image_utils.dart';
import 'dart:ui' as ui;

class DiscussionPage extends StatefulWidget {
  final String contactName;
  final bool isOnline;
  final String chatId;
  final String currentUserId;
  final ChatViewModel chatViewModel;
  final String? profileImageUrl;
  final String? contactUserId;

  const DiscussionPage({
    super.key,
    required this.contactName,
    required this.isOnline,
    required this.chatId,
    required this.currentUserId,
    required this.chatViewModel,
    this.profileImageUrl,
    this.contactUserId,
  });

  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends State<DiscussionPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<MessageModel> _messages = [];
  final List<MessageModel> _pendingMessages = []; // Local messages while sending
  StreamSubscription? _messagesSubscription;
  String? _contactProfileImageUrl;
  String? _contactUserId;

  bool _isLoading = true;
  bool _isSendingMessage = false;
  bool _shouldAutoScroll = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _contactProfileImageUrl = widget.profileImageUrl;
    _contactUserId = widget.contactUserId;
    
    if (_contactUserId == null || _contactUserId!.isEmpty) {
      final parts = widget.chatId.split('_');
      if (parts.length >= 2) {
        _contactUserId = parts.firstWhere((id) => id != widget.currentUserId, orElse: () => parts[0]);
      }
    }

    _setupMessageListener();
    _loadContactProfile();

    _messageController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadContactProfile() async {
    if (_contactUserId == null || _contactUserId!.isEmpty) return;
    try {
      final imageUrl = await widget.chatViewModel.getUserProfileImageUrl(_contactUserId!);
      if (mounted && imageUrl != null && imageUrl.isNotEmpty) {
        setState(() => _contactProfileImageUrl = imageUrl);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  void _setupMessageListener() {
    // Clear notifications for this chat when entering
    FirebaseService.deleteNotificationsForChat(widget.currentUserId, widget.chatId);

    _messagesSubscription?.cancel();
    _messagesSubscription = widget.chatViewModel
        .listenMessages(widget.chatId)
        .handleError((error) {
          if (mounted) setState(() { _isLoading = false; _hasError = true; });
        })
        .listen((messages) {
          if (mounted) {
            setState(() {
              _messages = messages;
              _isLoading = false;
              _hasError = false;
            });
            if (_shouldAutoScroll) _scrollToBottom();
          }
        });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final senderName = authViewModel.currentUser?.name ?? lang.tr('someone', category: 'disscussion');

    // 1. OPTIMISTIC UI: Create local message and clear input immediately
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = MessageModel(
      id: 'pending_$tempId',
      senderId: widget.currentUserId,
      text: text,
      timestamp: Timestamp.now(),
      type: 'text',
    );

    setState(() {
      _pendingMessages.add(message);
      _messageController.clear(); // Clear input instantly
      _shouldAutoScroll = true;
    });
    _scrollToBottom();

    // 2. BACKGROUND SYNC: Send to database without blocking the UI
    try {
      final success = await widget.chatViewModel.sendMessage(widget.chatId, message);
      
      if (success) {
        if (_contactUserId != null && _contactUserId != widget.currentUserId) {
          NotificationService().sendMessageNotification(
            receiverUserId: _contactUserId!,
            messageText: text,
            chatId: widget.chatId,
            senderId: widget.currentUserId,
            senderName: senderName,
          ).catchError((e) => debugPrint('Notification error: $e'));
        }
      } else {
        // If send failed, remove from pending and show error
        if (mounted) {
          AppSnackBar.showError(context, lang.tr('failed_to_send_message', category: 'disscussion'));
        }
      }
    } catch (e) {
      debugPrint('❌ Send message error: $e');
    } finally {
      if (mounted) {
        setState(() => _pendingMessages.removeWhere((m) => m.id == 'pending_$tempId'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final languageProvider = Provider.of<LanguageProvider>(context);
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Directionality(
        textDirection: languageProvider.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _buildAppBar(isDark, languageProvider),
          body: Column(
            children: [
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _hasError 
                    ? ErrorStateWidget(onRetry: _setupMessageListener)
                    : _buildMessagesList(languageProvider, isDark),
              ),
              _buildInputArea(languageProvider, isDark),
            ],
          ),
        ),
      );
    } catch (e) {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      return Scaffold(body: Center(child: Text(lang.trParams('ui_guard_error', category: 'disscussion', params: {'error': e.toString()}), style: const TextStyle(color: Colors.red))));
    }
  }

  PreferredSizeWidget _buildAppBar(bool isDark, LanguageProvider lang) {
    final imgProvider = _contactProfileImageUrl != null && _contactProfileImageUrl!.isNotEmpty
        ? ImageUtils.getImageProvider(_contactProfileImageUrl!)
        : null;

    return AppBar(
      elevation: 1,
      backgroundColor: Theme.of(context).cardColor,
      leading: IconButton(
        icon: Icon(lang.isRtl ? Icons.arrow_forward : Icons.arrow_back, 
             color: isDark ? Colors.white : Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blue.shade100,
            backgroundImage: imgProvider,
            child: imgProvider == null 
              ? Text(widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))
              : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.contactName, 
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                Text(widget.isOnline ? lang.tr('online', category: 'disscussion') : lang.tr('offline', category: 'disscussion'),
                  style: TextStyle(fontSize: 11, color: widget.isOnline ? Colors.green : Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(LanguageProvider lang, bool isDark) {
    final combinedMessages = [..._messages, ..._pendingMessages];
    
    if (combinedMessages.isEmpty) {
      return EmptyStateWidget(
        message: lang.tr('no_messages_yet', category: 'disscussion'),
        icon: Icons.chat_bubble_outline,
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: combinedMessages.length,
      itemBuilder: (context, index) {
        final msg = combinedMessages[index];
        final isMe = msg.senderId == widget.currentUserId;
        final isPending = msg.id?.startsWith('pending_') ?? false;
        
        return Opacity(
          opacity: isPending ? 0.6 : 1.0,
          child: _MessageBubble(message: msg, isMe: isMe),
        );
      },
    );
  }

  Widget _buildInputArea(LanguageProvider lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, -2))]
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: lang.tr('type_message', category: 'disscussion'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _messageController.text.trim().isEmpty || _isSendingMessage ? null : _sendMessage,
            icon: Icon(Icons.send_rounded, color: _messageController.text.trim().isEmpty ? Colors.grey : Theme.of(context).primaryColor),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String time = '--:--';
    try {
      time = DateFormat('HH:mm').format(message.timestamp.toDate());
    } catch (e) {
      // Message might still be syncing
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(message.text, style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87), fontSize: 14)),
            const SizedBox(height: 2),
            Text(time, style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}
