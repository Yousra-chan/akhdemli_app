import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/models/MessageModel.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:intl/intl.dart';
import 'package:service_app/Services/provider_service.dart';
import 'package:service_app/screens/profile/provider_profile/provider_profile_page.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:service_app/Services/notification_service.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

// Global cache for profile images
class ProfileImageCache {
  static final Map<String, String?> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration cacheDuration = Duration(hours: 1);

  static String? get(String userId) {
    final timestamp = _cacheTimestamps[userId];
    if (timestamp != null &&
        DateTime.now().difference(timestamp) < cacheDuration) {
      return _cache[userId];
    }
    return null;
  }

  static void set(String userId, String? imageUrl) {
    _cache[userId] = imageUrl;
    _cacheTimestamps[userId] = DateTime.now();
  }

  static void clear() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  static void remove(String userId) {
    _cache.remove(userId);
    _cacheTimestamps.remove(userId);
  }

  static void cleanup() {
    final now = DateTime.now();
    _cacheTimestamps.removeWhere((userId, timestamp) {
      if (now.difference(timestamp) > cacheDuration) {
        _cache.remove(userId);
        return true;
      }
      return false;
    });
  }
}

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
  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  final ScrollController _scrollController = ScrollController();

  // Data
  List<MessageModel> _messages = [];
  StreamSubscription? _messagesSubscription;
  String? _currentUserProfileImageUrl;
  String? _contactProfileImageUrl;
  String? _contactUserId;

  // Optimizations
  bool _isLoading = false;
  bool _isSendingMessage = false;
  bool _imagesLoaded = false;
  final Map<String, bool> _imageValidityCache = {};
  Timer? _scrollToBottomTimer;
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    _extractContactUserId();
    _loadProfileImages();
    _setupMessageListener();

    _messageController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _setupMessageListener() {
    _messagesSubscription?.cancel();

    _messagesSubscription =
        widget.chatViewModel.listenMessages(widget.chatId).handleError((error) {
      print('Error listening to messages: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }).listen((messages) {
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
          _lastRefreshTime = DateTime.now();
        });
        _scheduleScrollToBottom();
      }
    });
  }

  void _scheduleScrollToBottom() {
    _scrollToBottomTimer?.cancel();
    _scrollToBottomTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && _scrollController.hasClients && _messages.isNotEmpty) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _extractContactUserId() {
    if (widget.contactUserId != null && widget.contactUserId!.isNotEmpty) {
      _contactUserId = widget.contactUserId;
      return;
    }

    final participants = widget.chatId.split('_');
    if (participants.length >= 2) {
      _contactUserId = participants.firstWhere(
        (id) => id != widget.currentUserId,
        orElse: () => participants.isNotEmpty ? participants[0] : '',
      );
    }
  }

  Future<void> _loadProfileImages() async {
    if (_imagesLoaded) return;

    try {
      // Check cache for current user image
      final cachedCurrentUserImage =
          ProfileImageCache.get(widget.currentUserId);
      if (cachedCurrentUserImage != null) {
        if (mounted) {
          setState(() {
            _currentUserProfileImageUrl = cachedCurrentUserImage;
          });
        }
      } else {
        // Load from network if not in cache
        final currentUserImage = await widget.chatViewModel
            .getUserProfileImageUrl(widget.currentUserId);

        if (mounted) {
          setState(() {
            _currentUserProfileImageUrl = currentUserImage;
          });
        }
        // Store in cache
        if (currentUserImage != null) {
          ProfileImageCache.set(widget.currentUserId, currentUserImage);
        }
      }

      // Check cache for contact image
      final contactUserId = _contactUserId ?? widget.contactUserId;
      if (contactUserId != null && contactUserId.isNotEmpty) {
        final cachedContactImage = ProfileImageCache.get(contactUserId);
        if (cachedContactImage != null) {
          if (mounted) {
            setState(() {
              _contactProfileImageUrl = cachedContactImage;
            });
          }
        } else {
          // Load from network if not in cache
          final contactImage =
              await widget.chatViewModel.getUserProfileImageUrl(contactUserId);

          if (mounted) {
            setState(() {
              _contactProfileImageUrl = contactImage;
            });
          }
          // Store in cache
          if (contactImage != null) {
            ProfileImageCache.set(contactUserId, contactImage);
          }
        }
      } else if (widget.profileImageUrl != null &&
          widget.profileImageUrl!.isNotEmpty) {
        // Use provided URL
        if (mounted) {
          setState(() {
            _contactProfileImageUrl = widget.profileImageUrl;
          });
        }
      }

      _imagesLoaded = true;
    } catch (e) {
      print('Error loading profile images: $e');
    }
  }

  void _onRefresh() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Re-initialize the listener to get fresh data
      _setupMessageListener();

      // Simulate loading time for better UX
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        _refreshController.refreshCompleted();
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Refresh error: $e');
      if (mounted) {
        _refreshController.refreshFailed();
        setState(() => _isLoading = false);
      }
    }
  }

  void _onLoading() async {
    _refreshController.loadComplete();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSendingMessage) return;

    setState(() => _isSendingMessage = true);
    final messageText = _messageController.text.trim();

    final newMessage = MessageModel(
      senderId: widget.currentUserId,
      text: messageText,
      timestamp: Timestamp.now(),
      type: 'text',
    );

    try {
      // Envoyer le message via chatViewModel
      await widget.chatViewModel.sendMessage(widget.chatId, newMessage);

      if (mounted) {
        _messageController.clear();
        _scheduleScrollToBottom();

        // ⚠️ NE PAS appeler _sendNotification() ici!
        // La notification sera gérée AUTOMATIQUEMENT par NotificationService
        // qui écoute les changements dans Firestore

        debugPrint('📤 Message sent by ${widget.currentUserId}');
        debugPrint(
            '   Notification will be sent to RECEIVER only via Firestore listener');
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  void _sendNotification(String messageText) async {
    final receiverId = _contactUserId ?? widget.contactUserId;
    if (receiverId == null ||
        receiverId.isEmpty ||
        receiverId == widget.currentUserId) {
      return;
    }

    try {
      final currentUserData =
          await widget.chatViewModel.getUserData(widget.currentUserId);
      final currentUserName = currentUserData?['displayName'] ??
          currentUserData?['name'] ??
          currentUserData?['fullName'] ??
          'User';

      final payload = {
        'chatId': widget.chatId,
        'senderId': widget.currentUserId,
        'message': messageText,
        'type': 'message',
      };

      // ✅ Call the static method on the class directly
      await NotificationService.showLocalNotification(
        title: currentUserName,
        body: messageText,
        payload: json.encode(payload),
      );
    } catch (e) {
      print('Notification error: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Map<String, List<MessageModel>> _groupMessagesByDay(
      List<MessageModel> messages) {
    final groupedMessages = <String, List<MessageModel>>{};
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final dateFormat = DateFormat('MMM d, yyyy');

    for (var message in messages) {
      final messageDate = _getMessageDate(message.timestamp);
      String day;

      if (messageDate.year == today.year &&
          messageDate.month == today.month &&
          messageDate.day == today.day) {
        day = "Today";
      } else if (messageDate.year == yesterday.year &&
          messageDate.month == yesterday.month &&
          messageDate.day == yesterday.day) {
        day = "Yesterday";
      } else {
        day = dateFormat.format(messageDate);
      }

      groupedMessages.putIfAbsent(day, () => []).add(message);
    }

    return groupedMessages;
  }

  DateTime _getMessageDate(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return DateTime.now();
  }

  Future<bool> _checkImageValidity(String imageUrl) async {
    if (_imageValidityCache.containsKey(imageUrl)) {
      return _imageValidityCache[imageUrl]!;
    }

    try {
      bool isValid = false;

      if (ImageUtils.isNetworkImage(imageUrl)) {
        final client = http.Client();
        try {
          final response = await client.head(Uri.parse(imageUrl));
          isValid = response.statusCode == 200;
        } finally {
          client.close();
        }
      } else if (ImageUtils.isBase64Image(imageUrl)) {
        final bytes = ImageUtils.decodeBase64Image(imageUrl);
        isValid = bytes != null && bytes.isNotEmpty;
      }

      _imageValidityCache[imageUrl] = isValid;
      return isValid;
    } catch (e) {
      _imageValidityCache[imageUrl] = false;
      return false;
    }
  }

  // UPDATED: Smaller message avatar
  Widget _buildMessageAvatar(bool isCurrentUser, String userId) {
    final profileImageUrl =
        isCurrentUser ? _currentUserProfileImageUrl : _contactProfileImageUrl;
    final imageProvider = ImageUtils.getImageProvider(profileImageUrl);

    return GestureDetector(
      onTap: userId.isNotEmpty ? () => _navigateToUserProfile(userId) : null,
      child: Container(
        width: 22, // Reduced from 28
        height: 22, // Reduced from 28
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isCurrentUser ? Colors.transparent : Colors.white,
            width: 1.5, // Reduced border width
          ),
        ),
        child: CircleAvatar(
          radius: 10, // Reduced from 13
          backgroundColor: Colors.grey.shade300,
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? Icon(
                  CupertinoIcons.person_fill,
                  color: Colors.grey.shade600,
                  size: 10, // Reduced from 14
                )
              : _buildMessageAvatarLoadingFallback(profileImageUrl!),
        ),
      ),
    );
  }

  Widget _buildMessageAvatarLoadingFallback(String imageUrl) {
    return FutureBuilder<bool>(
      future: _checkImageValidity(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.2, // Reduced
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
            ),
          );
        }

        return Icon(
          CupertinoIcons.person_fill,
          color:
              snapshot.data == true ? Colors.transparent : Colors.grey.shade600,
          size: 10, // Reduced from 14
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedMessages = _groupMessagesByDay(_messages);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildDiscussionAppBar(),
          Expanded(
            child: SmartRefresher(
              controller: _refreshController,
              enablePullDown: true,
              enablePullUp: false,
              header: ClassicHeader(
                height: 60,
                releaseIcon: const Icon(Icons.refresh, color: Colors.blue),
                refreshingIcon: const SizedBox(
                  width: 25,
                  height: 25,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                completeIcon: const Icon(Icons.check, color: Colors.green),
                failedIcon: const Icon(Icons.error, color: Colors.red),
                textStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                refreshingText: 'Updating messages...',
                releaseText: 'Release to refresh',
                completeText: 'Updated',
                failedText: 'Failed',
                idleText: 'Pull down to refresh',
              ),
              onRefresh: _onRefresh,
              onLoading: _onLoading,
              child: _messages.isEmpty
                  ? _buildEmptyChatState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: groupedMessages.keys.length,
                      itemBuilder: (context, dayIndex) {
                        final day = groupedMessages.keys.elementAt(dayIndex);
                        final dailyMessages = groupedMessages[day]!;

                        return Column(
                          key: ValueKey(day),
                          children: [
                            _buildDateSeparator(day),
                            ...dailyMessages.map(
                              (message) => _buildMessageBubble(message),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildDiscussionAppBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          _buildContactAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contactName,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Exo2',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isOnline ? 'Active now' : 'Offline',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontFamily: 'Exo2',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.video_call, color: Colors.blue, size: 26),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.call, color: Colors.blue, size: 22),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildContactAvatar() {
    final imageUrl = _contactProfileImageUrl ?? widget.profileImageUrl;
    final imageProvider = ImageUtils.getImageProvider(imageUrl);
    final displayInitial = widget.contactName.isNotEmpty
        ? widget.contactName[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: _contactUserId != null && _contactUserId!.isNotEmpty
          ? () => _navigateToUserProfile(_contactUserId!)
          : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blue.shade100, width: 2),
        ),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.blue.shade50,
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? Text(
                  displayInitial,
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message) {
    final isMe = message.senderId == widget.currentUserId;
    final isSameSenderAsPrevious = _isSameSenderAsPrevious(message);
    final isSameSenderAsNext = _isSameSenderAsNext(message);

    return Container(
      padding: EdgeInsets.only(
        left: isMe
            ? 50
            : 16, // Reduced left padding when message is from current user
        right: isMe
            ? 16
            : 50, // Reduced right padding when message is from other user
        top: isSameSenderAsPrevious ? 1 : 6, // Reduced spacing
        bottom: isSameSenderAsNext ? 1 : 6, // Reduced spacing
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe && !isSameSenderAsPrevious)
            Padding(
              padding: const EdgeInsets.only(
                  left: 4, bottom: 3), // Reduced bottom padding
              child: Text(
                widget.contactName,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11, // Slightly smaller
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe && !isSameSenderAsNext)
                Padding(
                  padding: const EdgeInsets.only(
                      right: 6, bottom: 2), // Reduced padding
                  child: _buildMessageAvatar(
                      false, _contactUserId ?? message.senderId),
                ),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width *
                        0.75, // Slightly wider
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? Color(0xFF0084FF) : Colors.grey.shade100,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 18 : 4),
                      topRight: Radius.circular(isMe ? 4 : 18),
                      bottomLeft: const Radius.circular(18),
                      bottomRight: const Radius.circular(18),
                    ),
                    boxShadow: isMe
                        ? [
                            BoxShadow(
                              color: Color(0xFF0084FF).withOpacity(0.2),
                              blurRadius: 3, // Reduced blur
                              offset: const Offset(0, 1.5), // Reduced offset
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black,
                      fontSize: 15,
                      height: 1.4,
                      fontFamily: 'Exo2',
                    ),
                  ),
                ),
              ),
              if (isMe && !isSameSenderAsNext)
                Padding(
                  padding: const EdgeInsets.only(
                      left: 6, bottom: 2), // Reduced padding
                  child: _buildMessageAvatar(true, widget.currentUserId),
                ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 2,
              left: isMe ? 0 : 10, // Reduced padding
              right: isMe ? 10 : 0, // Reduced padding
            ),
            child: Text(
              _formatMessageTime(message.timestamp),
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 10, // Slightly smaller
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameSenderAsPrevious(MessageModel currentMessage) {
    final index = _messages.indexOf(currentMessage);
    if (index > 0) {
      final previousMessage = _messages[index - 1];
      return previousMessage.senderId == currentMessage.senderId &&
          _getMessageDate(currentMessage.timestamp)
                  .difference(_getMessageDate(previousMessage.timestamp))
                  .inMinutes <
              5;
    }
    return false;
  }

  bool _isSameSenderAsNext(MessageModel currentMessage) {
    final index = _messages.indexOf(currentMessage);
    if (index < _messages.length - 1) {
      final nextMessage = _messages[index + 1];
      return nextMessage.senderId == currentMessage.senderId &&
          _getMessageDate(nextMessage.timestamp)
                  .difference(_getMessageDate(currentMessage.timestamp))
                  .inMinutes <
              5;
    }
    return false;
  }

  Widget _buildDateSeparator(String date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        date,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyChatState() {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.blue,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No messages yet',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontFamily: 'Exo2',
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send your first message to ${widget.contactName}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontFamily: 'Exo2',
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Say "Hello 👋"',
              style: TextStyle(
                color: Colors.blue,
                fontFamily: 'Exo2',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade100,
            ),
            child: IconButton(
              icon: Icon(Icons.add, color: Colors.blue, size: 24),
              onPressed: () {},
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: "Message...",
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                      maxLines: 5,
                      minLines: 1,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.emoji_emotions_outlined,
                        color: Colors.grey.shade500),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.photo_camera_outlined,
                        color: Colors.grey.shade500),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _messageController.text.trim().isEmpty ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _messageController.text.trim().isNotEmpty
                    ? Colors.blue
                    : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isSendingMessage ? Icons.more_horiz : Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(dynamic timestamp) {
    final time = _getMessageDate(timestamp);
    return DateFormat('h:mm a').format(time).toLowerCase();
  }

  void _navigateToUserProfile(String userId) async {
    if (userId.isEmpty) return;

    try {
      final providerService = ProviderService();
      final ProviderModel? provider =
          await providerService.getProviderById(userId);
    } catch (e) {
      print('Error navigating to profile: $e');
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _refreshController.dispose();
    _scrollController.dispose();
    _messageController.dispose();
    _scrollToBottomTimer?.cancel();
    _imageValidityCache.clear();
    super.dispose();
  }
}
