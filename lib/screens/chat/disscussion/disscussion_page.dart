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
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:service_app/Services/notification_service.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:provider/provider.dart';
import '../../auth/constants.dart';
import 'dart:ui' as ui;

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
  bool _isLoading = true;
  bool _isSendingMessage = false;
  bool _imagesLoaded = false;
  Timer? _scrollToBottomTimer;
  bool _initialScrollDone = false;
  bool _shouldAutoScroll = true;
  bool _serverOnline = true;
  bool _hasErrorLoadingMessages = false;

  static const String _renderServerUrl =
      'https://notifications-f7n2.onrender.com';

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _checkRenderServer();
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
    _setupMessageListener();

    _messageController.addListener(() {
      if (mounted) setState(() {});
    });

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

  // Check if Render server is working
  void _checkRenderServer() async {
    try {
      print('🔍 Checking Render server connection...');
      final response = await http.get(
        Uri.parse('$_renderServerUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _serverOnline = response.statusCode == 200;
        });
      }

      if (response.statusCode == 200) {
        print('✅ Render server is online');
      } else {
        print('⚠️ Render server returned ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Cannot connect to Render server: $e');
      if (mounted) {
        setState(() {
          _serverOnline = false;
        });
      }
    }
  }

  void _setupMessageListener() {
    print('📡 Setting up message listener for chatId: ${widget.chatId}');
    _messagesSubscription?.cancel();

    _messagesSubscription = widget.chatViewModel
        .listenMessages(widget.chatId)
        .handleError((error, stackTrace) {
      print('❌ Error listening to messages: $error');
      if (mounted) {
        final languageProvider =
            Provider.of<LanguageProvider>(context, listen: false);
        setState(() {
          _isLoading = false;
          _hasErrorLoadingMessages = true;
        });
        showErrorSnackBar(
            context,
            languageProvider.tr('error_loading_messages',
                category: 'disscussion'));
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
            _isLoading = false;
            _hasErrorLoadingMessages = false;
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
      print('⚠️ Error loading profile images: $e');
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

    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

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

      // 🔥 SEND NOTIFICATION VIA RENDER SERVER (SINGLE PATH)
      await _sendNotificationViaRenderServer(messageText, languageProvider);

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
            content: Text(
              languageProvider.tr('failed_to_send_message',
                  category: 'disscussion'),
            ),
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

  Future<void> _sendNotificationViaRenderServer(
      String message, LanguageProvider lang) async {
    try {
      print('🔍 NOTIFICATION DEBUG - Checking source...');
      print('📱 Current User: ${widget.currentUserId}');
      print('👤 Contact User: ${_contactUserId}');
      print('💬 Message: $message');
      print('🔗 Chat ID: ${widget.chatId}');

      // 🔥 ADD THIS CHECK - Only send if receiver is NOT current user
      if (_contactUserId == widget.currentUserId) {
        print('⚠️ SKIPPING: Receiver is same as sender');
        return;
      }

      final receiverId = _contactUserId ?? widget.contactUserId;
      if (receiverId == null || receiverId.isEmpty) {
        print('⚠️ SKIPPING: No receiver ID');
        return;
      }

      print('📤 Sending notification to user: $receiverId');

      // 🔥 ADD UNIQUE ID to prevent duplicates
      final notificationId =
          '${widget.chatId}_${DateTime.now().millisecondsSinceEpoch}';
      print('🆔 Notification ID: $notificationId');

      final response = await http
          .post(
            Uri.parse(
                'https://notifications-f7n2.onrender.com/send-notification'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'senderId': widget.currentUserId,
              'receiverId': receiverId,
              'message': message,
              'senderName': widget.contactName,
              'chatId': widget.chatId,
              'notificationId': notificationId,
              'title': lang.trParams(
                'new_message_from',
                category: 'disscussion',
                params: {'name': widget.contactName},
              ),
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('📡 Server response: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          print('✅ Notification sent successfully');
          print('🎯 Message ID: ${result['messageId']}');
        } else {
          print('❌ Server returned error: ${result['error']}');
        }
      } else {
        print('❌ Server error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending notification: $e');
      print('💡 Check if server is sleeping (free tier)');
    }
  }

  // Fallback: Send direct FCM notification (if Render server fails)
  Future<void> _sendFallbackNotification(
      String receiverToken, String message, LanguageProvider lang) async {
    try {
      print('🔄 Trying fallback notification method...');

      // Option 1: Use NotificationService
      final success =
          await NotificationService().sendNotificationViaRenderServer(
        receiverToken: receiverToken,
        title: lang.trParams(
          'new_message_from',
          category: 'disscussion',
          params: {'name': widget.contactName},
        ),
        body: message,
        data: {
          'type': 'message',
          'chatId': widget.chatId,
          'senderId': widget.currentUserId,
        },
      );

      if (success) {
        print('✅ Fallback notification sent via NotificationService');
      } else {
        print('❌ NotificationService fallback failed, trying direct FCM...');
        await _sendDirectFCMNotification(receiverToken, message, lang);
      }
    } catch (e) {
      print('❌ Fallback error: $e');
    }
  }

  // Direct FCM as last resort
  Future<void> _sendDirectFCMNotification(
      String receiverToken, String message, LanguageProvider lang) async {
    try {
      print('🚨 Using direct FCM as last resort...');

      // You need to add your FCM server key from Firebase Console
      const serverKey = 'YOUR_FCM_SERVER_KEY_HERE'; // Get from Firebase Console

      if (serverKey == 'YOUR_FCM_SERVER_KEY_HERE') {
        print('⚠️ Please add your FCM server key in discussion_page.dart');
        return;
      }

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: json.encode({
          'to': receiverToken,
          'notification': {
            'title': lang.trParams(
              'new_message_from',
              category: 'disscussion',
              params: {'name': widget.contactName},
            ),
            'body': message,
            'sound': 'default',
            'android_channel_id': 'high_importance_channel',
          },
          'data': {
            'type': 'message',
            'chatId': widget.chatId,
            'senderId': widget.currentUserId,
          },
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Direct FCM notification sent');
      } else {
        print('❌ Direct FCM failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Direct FCM error: $e');
    }
  }

  // Alternative fallback
  Future<void> _sendFallbackDirectNotification(
      String message, LanguageProvider lang) async {
    try {
      final receiverId = _contactUserId ?? widget.contactUserId;
      if (receiverId == null) return;

      // Try using NotificationService directly
      await NotificationService().sendMessageNotification(
        receiverUserId: receiverId,
        messageText: message,
        chatId: widget.chatId,
        senderName: widget.contactName,
      );
    } catch (e) {
      print('❌ All notification methods failed: $e');
    }
  }

  // Test notification button (for debugging)
  Future<void> _testNotification() async {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    try {
      print('🧪 Testing notification system...');

      // Test Render server connection
      final healthResponse = await http
          .get(
            Uri.parse('$_renderServerUrl/health'),
          )
          .timeout(Duration(seconds: 10));

      print('✅ Render server health: ${healthResponse.statusCode}');

      // Send test message
      await _sendNotificationViaRenderServer(
          languageProvider.tr('test_notification_message',
              category: 'disscussion'),
          languageProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.tr('test_notification_sent',
                category: 'disscussion'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Test failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.trParams(
              'test_failed',
              category: 'disscussion',
              params: {'error': e.toString()},
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final screenSize = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Directionality(
        textDirection: languageProvider.isRtl
            ? ui.TextDirection.rtl
            : ui.TextDirection.ltr,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(screenSize, languageProvider),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (!_serverOnline)
                  Container(
                    width: double.infinity,
                    color: Colors.orange.shade100,
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade800, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            languageProvider.isRtl
                                ? "خادم الإشعارات غير متصل. قد تتأخر التنبيهات."
                                : "Notification server is offline. Alerts might be delayed.",
                            style: TextStyle(
                                color: Colors.orange.shade900,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh,
                              color: Colors.orange.shade800, size: 20),
                          onPressed: _checkRenderServer,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _buildMessagesList(languageProvider),
                ),
                _buildMessageInput(languageProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Size screenSize, LanguageProvider lang) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(lang.isRtl ? Icons.arrow_forward : Icons.arrow_back,
            color: Colors.black87, size: 24),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
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
                    fontFamily: 'Exo2',
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
                      widget.isOnline
                          ? lang.tr('online', category: 'disscussion')
                          : lang.tr('offline', category: 'disscussion'),
                      style: TextStyle(
                        color: widget.isOnline
                            ? Colors.green
                            : Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Exo2',
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

  Widget _buildMessagesList(LanguageProvider lang) {
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
              lang.tr('loading_messages', category: 'disscussion'),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontFamily: 'Exo2',
              ),
            ),
          ],
        ),
      );
    }

    if (_hasErrorLoadingMessages && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              lang.tr('error_loading_messages', category: 'disscussion'),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasErrorLoadingMessages = false;
                });
                _setupMessageListener();
              },
              icon: const Icon(Icons.refresh),
              label: Text(lang.isRtl ? "إعادة المحاولة" : "Retry"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ],
        ),
      );
    }

    return _messages.isEmpty
        ? _buildEmptyState(lang)
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
                      _buildDateSeparator(message.timestamp.toDate(), lang),
                    _MessageBubble(
                      message: message,
                      isMe: isMe,
                      lang: lang,
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

  Widget _buildDateSeparator(DateTime date, LanguageProvider lang) {
    final today = DateTime.now();
    final yesterday = today.subtract(Duration(days: 1));

    String dateStr;
    if (_isSameDay(date, today)) {
      dateStr = lang.tr('today', category: 'disscussion');
    } else if (_isSameDay(date, yesterday)) {
      dateStr = lang.tr('yesterday', category: 'disscussion');
    } else {
      dateStr = DateFormat(lang.tr('date_format', category: 'disscussion'))
          .format(date);
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
                fontFamily: 'Exo2',
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider lang) {
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
            lang.tr('no_messages_yet', category: 'disscussion'),
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Exo2',
            ),
          ),
          SizedBox(height: 8),
          Text(
            lang.tr('start_conversation', category: 'disscussion'),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontFamily: 'Exo2',
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _testNotification,
            child: Text(
              lang.tr('test_notifications', category: 'disscussion'),
              style: const TextStyle(fontFamily: 'Exo2'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: max(16.0, MediaQuery.of(context).viewInsets.bottom),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: 100, // Prevents text field from growing too tall
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: lang.tr('type_message', category: 'disscussion'),
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 15,
                      fontFamily: 'Exo2',
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    height: 1.4,
                    fontFamily: 'Exo2',
                  ),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => _sendMessage(),
                ),
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
  final LanguageProvider lang;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
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

    final formatTime =
        DateFormat(lang.tr('time_format', category: 'disscussion'))
            .format(timestamp);

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
                  fontFamily: 'Exo2',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
