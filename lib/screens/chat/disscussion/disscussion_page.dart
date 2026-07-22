import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
import '../../../models/UserModel.dart';
import '../../../models/ProviderModel.dart';
import '../../profile/provider_profile/provider_profile_page.dart';
import '../../../utils/image_utils.dart';
import '../constants.dart';
import 'dart:ui' as ui;

class DiscussionPage extends StatefulWidget {
  final String contactName;
  final bool isOnline;
  final String chatId;
  final String currentUserId;
  final ChatViewModel chatViewModel;
  final String? profileImageUrl;
  final String? contactUserId;
  final String? heroTag;

  const DiscussionPage({
    super.key,
    required this.contactName,
    required this.isOnline,
    required this.chatId,
    required this.currentUserId,
    required this.chatViewModel,
    this.profileImageUrl,
    this.contactUserId,
    this.heroTag,
  });

  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends State<DiscussionPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<MessageModel> _messages = [];
  final List<MessageModel> _pendingMessages = []; 
  final Set<String> _dismissedMessageIds = {}; 
  StreamSubscription? _messagesSubscription;
  String? _contactProfileImageUrl;
  late String _contactUserId;

  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _contactProfileImageUrl = widget.profileImageUrl;
    
    if (widget.contactUserId != null && widget.contactUserId!.isNotEmpty) {
      _contactUserId = widget.contactUserId!;
    } else {
      final parts = widget.chatId.split('_');
      _contactUserId = parts.firstWhere((id) => id != widget.currentUserId, orElse: () => parts[0]);
    }

    _setupMessageListener();
    _loadContactProfile();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadContactProfile() async {
    try {
      final imageUrl = await widget.chatViewModel.getUserProfileImageUrl(_contactUserId);
      if (mounted && imageUrl != null && imageUrl.isNotEmpty) {
        setState(() => _contactProfileImageUrl = imageUrl);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  void _navigateToContactProfile() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    try {
      final userData = await widget.chatViewModel.getUserData(_contactUserId);
      if (userData != null && mounted) {
        final user = UserModel.fromMap(userData, _contactUserId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProviderProfileScreen(
              provider: ProviderModel.fromUser(user),
              serviceCategory: user.profession ?? 'Service Provider',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to profile: $e');
    }
  }

  void _setupMessageListener() {
    FirebaseService.deleteNotificationsForChat(widget.currentUserId, widget.chatId);

    _messagesSubscription?.cancel();
    _messagesSubscription = widget.chatViewModel
        .listenMessages(widget.chatId)
        .listen(
          (messages) {
            if (mounted) {
              setState(() {
                _messages = messages;
                _isLoading = false;
                _hasError = false;
              });
              _scrollToBottom();
            }
          },
          onError: (e) {
            if (mounted) setState(() { _isLoading = false; _hasError = true; });
          }
        );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final senderName = authViewModel.currentUser?.name ?? 'Someone';

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
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      final success = await widget.chatViewModel.sendMessage(widget.chatId, message);
      if (success) {
        NotificationService().sendMessageNotification(
          receiverUserId: _contactUserId,
          messageText: text,
          chatId: widget.chatId,
          senderId: widget.currentUserId,
          senderName: senderName,
        ).catchError((e) => debugPrint('Notification error: $e'));
      }
    } catch (e) {
      debugPrint('❌ Send message error: $e');
    } finally {
      if (mounted) {
        setState(() => _pendingMessages.removeWhere((m) => m.id == 'pending_$tempId'));
      }
    }
  }

  Future<void> _handleDeleteMessage(MessageModel msg) async {
    if (msg.id == null || msg.id!.startsWith('pending_')) return;
    
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.tr('delete_message', category: 'chat')),
        content: Text(lang.tr('delete_message_confirm', category: 'chat')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lang.tr('cancel', category: 'common'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text(lang.tr('delete', category: 'common'), style: const TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _dismissedMessageIds.add(msg.id!));
      widget.chatViewModel.deleteMessage(widget.chatId, msg.id!).catchError((e) {
        if (mounted) setState(() => _dismissedMessageIds.remove(msg.id!));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: languageProvider.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: isDark ? const Color(0xFF121212) : kPrimaryBlue,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildAppBar(isDark, languageProvider),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                  ),
                  child: Column(
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark, LanguageProvider lang) {
    final imgProvider = _contactProfileImageUrl != null && _contactProfileImageUrl!.isNotEmpty
        ? ImageUtils.getImageProvider(_contactProfileImageUrl!)
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 25),
      child: Row(
        children: [
          IconButton(
            icon: Icon(lang.isRtl ? Icons.arrow_forward_ios : Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _navigateToContactProfile,
            child: Row(
              children: [
                Hero(
                  tag: widget.heroTag ?? 'avatar_${widget.chatId}',
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white24,
                    backgroundImage: imgProvider,
                    child: imgProvider == null ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.contactName, 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Exo2')
                    ),
                    Text(
                      widget.isOnline ? lang.tr('online', category: 'disscussion') : lang.tr('offline', category: 'disscussion'),
                      style: TextStyle(fontSize: 11, color: widget.isOnline ? const Color(0xFF00D261) : Colors.white60, fontFamily: 'Exo2')
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(LanguageProvider lang, bool isDark) {
    final combinedMessages = [..._messages, ..._pendingMessages]
        .where((m) => !_dismissedMessageIds.contains(m.id))
        .toList();
    
    if (combinedMessages.isEmpty) {
      return Center(child: Text(lang.tr('no_messages_yet', category: 'disscussion')));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: combinedMessages.length,
      itemBuilder: (context, index) {
        final msg = combinedMessages[index];
        final isMe = msg.senderId == widget.currentUserId;
        final isPending = msg.id?.startsWith('pending_') ?? false;

        return Dismissible(
          key: Key(msg.id ?? index.toString()),
          direction: isMe 
            ? (lang.isRtl ? DismissDirection.startToEnd : DismissDirection.endToStart) 
            : DismissDirection.none,
          confirmDismiss: (direction) async {
            if (isPending) return false;
            await _handleDeleteMessage(msg);
            return false; // We handle removal manually via state
          },
          background: Container(
            color: Colors.red.withOpacity(0.1),
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.red),
          ),
          child: _MessageBubble(
            message: msg, 
            isMe: isMe,
            profileImageUrl: isMe ? null : _contactProfileImageUrl,
            onLongPress: isMe ? () => _handleDeleteMessage(msg) : null,
          ),
        );
      },
    );
  }

  Widget _buildInputArea(LanguageProvider lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: lang.tr('type_message', category: 'disscussion'),
                filled: true,
                fillColor: isDark ? Colors.white10 : const Color(0xFFF5F7FB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            onPressed: _sendMessage,
            mini: true,
            backgroundColor: kPrimaryBlue,
            child: const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final String? profileImageUrl;
  final VoidCallback? onLongPress;

  const _MessageBubble({required this.message, required this.isMe, this.profileImageUrl, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final time = DateFormat('HH:mm').format(message.timestamp.toDate());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundImage: profileImageUrl != null ? ImageUtils.getImageProvider(profileImageUrl!) : null,
              child: profileImageUrl == null ? const Icon(Icons.person, size: 16) : null,
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onLongPress: onLongPress,
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe ? kPrimaryBlue : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    message.text, 
                    style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87), fontSize: 14)
                  ),
                ),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
