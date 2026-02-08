import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/models/MessageModel.dart';
import 'package:intl/intl.dart';
import 'package:service_app/Services/http_polling_service.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

// Profile image cache with expiration
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
  String? _contactProfileImageUrl;
  String? _contactUserId;

  // State
  bool _isLoading = true; // ✅ FIXED: Start as true to show loading
  bool _isSendingMessage = false;
  bool _imagesLoaded = false;
  Timer? _scrollToBottomTimer;
  bool _initialScrollDone = false;
  bool _shouldAutoScroll = true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _scrollToBottomTimer?.cancel();
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _refreshController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeChat() {
    print('🔄 Initializing chat with chatId: ${widget.chatId}');
    _extractContactUserId();
    _loadProfileImages();
    _setupMessageListener(); // ✅ This sets up the stream

    _messageController.addListener(() {
      if (mounted) setState(() {});
    });

    // Stop auto-scroll when user scrolls up
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        _shouldAutoScroll = false;
      } else if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100) {
        _shouldAutoScroll = true;
      }
    });
  }

  void _setupMessageListener() {
    print('📡 Setting up message listener for chatId: ${widget.chatId}');
    _messagesSubscription?.cancel();

    // ✅ FIXED: Better error handling with detailed logs
    _messagesSubscription = widget.chatViewModel
        .listenMessages(widget.chatId)
        .handleError((error, stackTrace) {
      print('❌ CRITICAL ERROR listening to messages: $error');
      print('📍 Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading messages: $error'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }).listen(
      (messages) {
        print('📨 Received ${messages.length} messages from stream');
        if (mounted) {
          final wasAtBottom = !_scrollController.hasClients ||
              _scrollController.position.pixels >=
                  _scrollController.position.maxScrollExtent - 100;

          setState(() {
            _messages = messages;
            _isLoading = false; // ✅ FIXED: Set to false when data arrives
            print('✅ Updated UI with ${_messages.length} messages');
          });

          if (wasAtBottom && _shouldAutoScroll) {
            _scrollToBottom();
          }

          _initialScrollDone = true;
        }
      },
      onDone: () {
        print('📍 Message stream completed');
      },
    );
  }

  void _scrollToBottom() {
    _scrollToBottomTimer?.cancel();
    _scrollToBottomTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && _scrollController.hasClients && _messages.isNotEmpty) {
        try {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } catch (e) {
          print('⚠️ Error scrolling: $e');
        }
      }
    });
  }

  void _extractContactUserId() {
    if (widget.contactUserId != null && widget.contactUserId!.isNotEmpty) {
      _contactUserId = widget.contactUserId;
      print('✅ Contact ID from widget: $_contactUserId');
      return;
    }

    final participants = widget.chatId.split('_');
    if (participants.length >= 2) {
      _contactUserId = participants.firstWhere(
        (id) => id != widget.currentUserId,
        orElse: () => participants.isNotEmpty ? participants[0] : '',
      );
      print('✅ Contact ID from chatId: $_contactUserId');
    }
  }

  Future<void> _loadProfileImages() async {
    if (_imagesLoaded) return;

    try {
      final contactUserId = _contactUserId ?? widget.contactUserId;
      if (contactUserId != null && contactUserId.isNotEmpty) {
        final cachedImage = ProfileImageCache.get(contactUserId);
        if (cachedImage != null) {
          if (mounted) {
            setState(() {
              _contactProfileImageUrl = cachedImage;
            });
          }
        } else {
          final contactImage =
              await widget.chatViewModel.getUserProfileImageUrl(contactUserId);
          if (mounted) {
            setState(() {
              _contactProfileImageUrl = contactImage;
            });
          }
          if (contactImage != null) {
            ProfileImageCache.set(contactUserId, contactImage);
          }
        }
      }

      if (mounted) {
        setState(() {
          _imagesLoaded = true;
        });
      }
    } catch (e) {
      print('Error loading profile images: $e');
      if (mounted) {
        setState(() {
          _imagesLoaded = true;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    setState(() {
      _isSendingMessage = true;
    });

    try {
      final newMessage = MessageModel(
        senderId: widget.currentUserId,
        text: messageText,
        timestamp: Timestamp.now(),
        type: 'text',
      );

      print('📤 Sending message: $messageText');
      await widget.chatViewModel.sendMessage(widget.chatId, newMessage);
      print('✅ Message saved to Firestore');

      _messageController.clear();
      _shouldAutoScroll = true;
      _scrollToBottom();

      await _notifyRecipient(messageText);
      await _saveNotificationToFirestore(
        receiverId: _contactUserId ?? widget.contactUserId ?? '',
        message: messageText,
        senderName: widget.contactName,
      );

      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      }
    } catch (e) {
      print('❌ Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          _isSendingMessage = false;
        });
      }
    }
  }

  Future<void> _notifyRecipient(String message) async {
    try {
      final receiverId = _contactUserId ?? widget.contactUserId;
      if (receiverId == null || receiverId.isEmpty) {
        print('⚠️ No receiver ID for notification');
        return;
      }

      await http
          .post(
            Uri.parse('https://notifications-server-66y2.onrender.com/send'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'senderId': widget.currentUserId,
              'receiverId': receiverId,
              'message': message,
              'chatId': widget.chatId,
              'senderName': widget.contactName,
            }),
          )
          .timeout(const Duration(seconds: 10));

      print('✅ Notification sent to HTTP server');
    } catch (e) {
      print('⚠️ Error notifying recipient: $e');
    }
  }

  Future<void> _saveNotificationToFirestore({
    required String receiverId,
    required String message,
    required String senderName,
  }) async {
    try {
      if (receiverId.isEmpty) {
        print('⚠️ Empty receiver ID, skipping notification save');
        return;
      }

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': receiverId,
        'senderId': widget.currentUserId,
        'senderName': senderName,
        'message': message,
        'title': '$senderName sent a message',
        'type': 'message',
        'chatId': widget.chatId,
        'time': Timestamp.now(),
        'isRead': false,
        'messageCount': 1,
        'lastMessageTime': Timestamp.now(),
      });

      print('✅ Notification saved to Firestore');
    } catch (e) {
      print('⚠️ Error saving notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(screenSize),
        body: Column(
          children: [
            Expanded(
              child: _buildMessagesList(),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Size screenSize) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.black87, size: 24),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // User profile image circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
              border: Border.all(
                color: widget.isOnline ? Colors.green : Colors.grey,
                width: 2.5,
              ),
            ),
            child: _contactProfileImageUrl != null
                ? ClipOval(
                    child: Image.network(
                      _contactProfileImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              widget.contactName.isNotEmpty
                                  ? widget.contactName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.contactName.isNotEmpty
                            ? widget.contactName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.contactName,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isOnline
                            ? Colors.green
                            : Colors.grey.shade400,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      widget.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: widget.isOnline
                            ? Colors.green
                            : Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildMessagesList() {
    // ✅ FIXED: Show loading first, then messages, then empty state
    if (_isLoading && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 16),
            Text(
              'Loading messages...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return _messages.isEmpty
        ? _buildEmptyState()
        : SmartRefresher(
            enablePullDown: true,
            onRefresh: () {
              _refreshController.refreshCompleted();
            },
            controller: _refreshController,
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message.senderId == widget.currentUserId;
                final showDate = index == 0 ||
                    !_isSameDay(
                      _messages[index - 1].timestamp.toDate(),
                      message.timestamp.toDate(),
                    );

                return Column(
                  children: [
                    if (showDate)
                      _buildDateSeparator(message.timestamp.toDate()),
                    _MessageBubble(
                      message: message,
                      isMe: isMe,
                    ),
                  ],
                );
              },
            ),
          );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildDateSeparator(DateTime date) {
    final today = DateTime.now();
    final yesterday = today.subtract(Duration(days: 1));

    String dateStr;
    if (_isSameDay(date, today)) {
      dateStr = 'Today';
    } else if (_isSameDay(date, yesterday)) {
      dateStr = 'Yesterday';
    } else {
      dateStr = DateFormat('MMM d, yyyy').format(date);
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              dateStr,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        ],
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
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.blue,
              size: 40,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'No messages yet',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start the conversation',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        max(16.0, MediaQuery.of(context).viewInsets.bottom),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  height: 1.4,
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: 12),
          GestureDetector(
            onTap: _messageController.text.trim().isEmpty || _isSendingMessage
                ? null
                : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _messageController.text.trim().isNotEmpty
                    ? LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      )
                    : LinearGradient(
                        colors: [Colors.grey.shade300, Colors.grey.shade400],
                      ),
                shape: BoxShape.circle,
                boxShadow: _messageController.text.trim().isNotEmpty
                    ? [
                        BoxShadow(
                          color: Colors.blue.shade400.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                _isSendingMessage ? Icons.hourglass_top : Icons.send_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: Better timestamp handling
    DateTime timestamp;
    try {
      if (message.timestamp is Timestamp) {
        timestamp = (message.timestamp as Timestamp).toDate();
      } else if (message.timestamp is DateTime) {
        timestamp = message.timestamp as DateTime;
      } else {
        timestamp = DateTime.now();
      }
    } catch (e) {
      print('⚠️ Error parsing timestamp: $e');
      timestamp = DateTime.now();
    }

    final formatTime = DateFormat('HH:mm').format(timestamp);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue.shade500 : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                  height: 1.4,
                  fontFamily: 'Exo2',
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: 4,
                left: isMe ? 0 : 8,
                right: isMe ? 8 : 0,
              ),
              child: Text(
                formatTime,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
