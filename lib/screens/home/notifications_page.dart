// screens/home/notifications_page.dart
import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/language_provider.dart';
import '../../ViewModel/auth_view_model.dart' show AuthViewModel;
import '../../ViewModel/chat_view_model.dart' show ChatViewModel;
import '../../screens/Booking/my_booking_page.dart';
import '../../screens/chat/disscussion/disscussion_page.dart';
import '../../models/notification_item.dart';

class NotificationsWindow extends StatefulWidget {
  final ChatViewModel? chatViewModel;

  const NotificationsWindow({super.key, this.chatViewModel});

  @override
  State<NotificationsWindow> createState() => _NotificationsWindowState();
}

class _NotificationsWindowState extends State<NotificationsWindow> {
  late Stream<List<HomeNotificationItem>> _notificationsStream;
  String? _currentUserId;
  late StreamController<List<HomeNotificationItem>> _streamController;
  Timer? _pollingTimer;
  late ChatViewModel _chatViewModel;

  @override
  void initState() {
    super.initState();
    _streamController =
        StreamController<List<HomeNotificationItem>>.broadcast();
    _chatViewModel = widget.chatViewModel ?? ChatViewModel(userId: '');
    _initializeNotifications();
  }

  @override
  void dispose() {
    _streamController.close();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _initializeNotifications() {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    _currentUserId = authViewModel.currentUser?.uid;

    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      _notificationsStream = _streamController.stream;
      _loadNotifications();
      _startPolling();
    } else {
      _notificationsStream = Stream<List<HomeNotificationItem>>.value([]);
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentUserId != null && mounted) {
        _loadNotifications();
      }
    });
  }

  void _loadNotifications() async {
    try {
      final notifications = await _fetchNotifications();
      if (mounted) {
        _streamController.add(notifications);
      }
    } catch (e) {
      print('❌ Error loading notifications: $e');
      if (mounted) {
        _streamController.add([]);
      }
    }
  }

  Future<List<HomeNotificationItem>> _fetchNotifications() async {
    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        return [];
      }

      print('📥 Fetching notifications for user: $_currentUserId');

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: _currentUserId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      print('📊 Found ${snapshot.docs.length} total notifications');

      final notifications = <HomeNotificationItem>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        if (data['senderId'] == _currentUserId) {
          continue;
        }

        try {
          final notification = _createNotificationFromData(doc.id, data);
          notifications.add(notification);
        } catch (e) {
          print('Error parsing notification ${doc.id}: $e');
        }
      }

      final unreadCount = notifications.where((n) => !n.isRead).length;
      print(
          '✅ Loaded ${notifications.length} notifications ($unreadCount unread)');

      return notifications;
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      return [];
    }
  }

  HomeNotificationItem _createNotificationFromData(
      String id, Map<String, dynamic> data) {
    DateTime notificationTime;
    if (data['timestamp'] != null) {
      notificationTime = (data['timestamp'] as Timestamp).toDate();
    } else if (data['time'] != null) {
      notificationTime = (data['time'] as Timestamp).toDate();
    } else {
      notificationTime = DateTime.now();
    }

    return HomeNotificationItem(
      id: id,
      title: data['title'] ?? '',
      message: data['body'] ?? data['message'] ?? data['messageContent'] ?? '',
      type: _parseNotificationType(data['type']),
      chatId: data['chatId'],
      senderId: data['senderId'],
      senderName: data['senderName'],
      actionText: data['actionText'] ?? '',
      isRead: data['read'] ?? data['isRead'] ?? false,
      time: notificationTime,
      messageCount: (data['messageCount'] as num?)?.toInt() ?? 1,
      lastMessageTime: data['lastMessageTime'] != null
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : notificationTime,
      bookingId: data['bookingId'],
      bookingStatus: data['bookingStatus'],
      userRole: data['userRole'],
    );
  }

  HomeNotificationType _parseNotificationType(String? type) {
    switch (type) {
      case 'booking':
        return HomeNotificationType.booking;
      case 'payment':
        return HomeNotificationType.payment;
      case 'reminder':
        return HomeNotificationType.reminder;
      case 'promotional':
        return HomeNotificationType.promotional;
      case 'rating':
        return HomeNotificationType.rating;
      case 'health':
        return HomeNotificationType.health;
      case 'follow':
        return HomeNotificationType.follow;
      case 'message':
      default:
        return HomeNotificationType.message;
    }
  }

  (List<HomeNotificationItem>, List<HomeNotificationItem>)
      _categorizeNotifications(List<HomeNotificationItem> notifications) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    final today = notifications.where((notification) {
      return notification.time.isAfter(startOfToday);
    }).toList();

    final week = notifications.where((notification) {
      return notification.time.isAfter(startOfWeek) &&
          !notification.time.isAfter(startOfToday);
    }).toList();

    return (today, week);
  }

  Future<void> _markAllAsRead() async {
    print('🔵 _markAllAsRead() called');
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        print('❌ Current user ID is null or empty!');
        return;
      }

      print('🔵 Marking all notifications as read for user: $_currentUserId');

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: _currentUserId)
          .where('read', isEqualTo: false)
          .get();

      print('🔵 Found ${snapshot.docs.length} unread notifications');

      if (snapshot.docs.isEmpty) {
        print('⚠️ No unread notifications found');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ Marked ${snapshot.docs.length} notifications as read');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .update({'unreadCount': 0});

      print('✅ Cleared user unreadCount');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.tr('all_marked_read', category: 'notifications'),
              style: const TextStyle(
                fontFamily: 'Exo2',
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      print('❌ Error in _markAllAsRead: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.tr('error_mark_read', category: 'notifications'),
              style: const TextStyle(
                fontFamily: 'Exo2',
              ),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _markAsRead(String id) {
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(id)
        .update({'isRead': true}).then((_) {
      print('✅ Marked notification $id as read');
      _loadNotifications();
    }).catchError((e) => print('❌ Error updating notification: $e'));
  }

  void _handleNotificationTap(HomeNotificationItem notification) async {
    print('👆 Notification tapped: ${notification.id}');

    if (!notification.isRead) {
      try {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notification.id)
            .update({
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
        print('✅ Marked notification ${notification.id} as read');
      } catch (e) {
        print('❌ Error marking notification as read: $e');
      }
    }

    if (notification.type == HomeNotificationType.message) {
      if (notification.chatId != null) {
        Navigator.of(context).pop();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiscussionPage(
              chatId: notification.chatId!,
              currentUserId: _currentUserId!,
              contactName: notification.senderName ??
                  Provider.of<LanguageProvider>(context, listen: false)
                      .tr('unknown_user', category: 'notifications'),
              isOnline: true,
              chatViewModel: _chatViewModel,
            ),
          ),
        );
      }
    } else if (notification.type == HomeNotificationType.booking) {
      Navigator.of(context).pop();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MyBookingsScreen(),
        ),
      );
    }
  }

  void _navigateToBookings(
      BuildContext context, HomeNotificationItem notification) {
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyBookingsScreen(),
      ),
    );
  }

  void _showNotificationDetails(
      BuildContext context, HomeNotificationItem notification) {
    Navigator.of(context).pop();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _NotificationDetailsPage(notification: notification);
      },
      useRootNavigator: true,
    );
  }

  Widget _buildNotificationItem(HomeNotificationItem notification) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isBookingNotification =
        notification.type == HomeNotificationType.booking;
    final isRead = notification.isRead;

    final bookingStatus = _getBookingStatusFromNotification(notification);

    return GestureDetector(
      onTap: () => _handleNotificationTap(notification),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(12),
          border: isBookingNotification
              ? Border.all(
                  color: const Color(0xFF667EEA).withOpacity(0.3), width: 2)
              : isRead
                  ? Border.all(color: Colors.grey.shade100, width: 1)
                  : Border.all(
                      color: const Color(0xFF667EEA).withOpacity(0.5),
                      width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(isRead ? 0.05 : 0.1),
              blurRadius: isRead ? 5 : 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4, right: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF667EEA),
                  shape: BoxShape.circle,
                ),
              ),
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _getNotificationGradient(notification.type)
                      .map((color) => isRead ? color.withOpacity(0.5) : color)
                      .toList(),
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isBookingNotification
                    ? const Icon(
                        Icons.calendar_today,
                        color: Colors.white,
                        size: 20,
                      )
                    : Icon(
                        notification.icon,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.senderName ??
                              languageProvider.tr('unknown_user',
                                  category: 'notifications'),
                          style: TextStyle(
                            color: isRead
                                ? const Color(0xFF666666)
                                : const Color(0xFF333333),
                            fontSize: 14,
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.w600,
                            fontFamily: 'Exo2',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isBookingNotification && bookingStatus != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(bookingStatus),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _getTranslatedBookingStatus(
                                bookingStatus, languageProvider),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Exo2',
                            ),
                          ),
                        )
                      else
                        Text(
                          _formatTime(notification.time, languageProvider),
                          style: TextStyle(
                            color: isRead
                                ? const Color(0xFF999999)
                                : const Color(0xFF667EEA),
                            fontSize: 12,
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.w500,
                            fontFamily: 'Exo2',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getActionText(notification.type, languageProvider),
                    style: TextStyle(
                      color: isRead
                          ? const Color(0xFF999999)
                          : const Color(0xFF666666),
                      fontSize: 13,
                      fontFamily: 'Exo2',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      color: isRead
                          ? const Color(0xFF666666)
                          : const Color(0xFF333333),
                      fontSize: 14,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                      fontFamily: 'Exo2',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isBookingNotification)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: const Color(0xFF999999)),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(notification.time, languageProvider),
                            style: const TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 12,
                              fontFamily: 'Exo2',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTranslatedBookingStatus(String status, LanguageProvider lang) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return lang.tr('booking_status_accepted', category: 'notifications');
      case 'rejected':
        return lang.tr('booking_status_rejected', category: 'notifications');
      case 'declined':
        return lang.tr('booking_status_declined', category: 'notifications');
      case 'completed':
        return lang.tr('booking_status_completed', category: 'notifications');
      case 'cancelled':
        return lang.tr('booking_status_cancelled', category: 'notifications');
      case 'pending':
        return lang.tr('booking_status_pending', category: 'notifications');
      default:
        return status.toUpperCase();
    }
  }

  String? _getBookingStatusFromNotification(HomeNotificationItem notification) {
    final message = notification.message.toLowerCase();

    if (message.contains('accepted')) return 'accepted';
    if (message.contains('declined') || message.contains('rejected'))
      return 'rejected';
    if (message.contains('completed')) return 'completed';
    if (message.contains('cancelled')) return 'cancelled';
    if (message.contains('requested') || message.contains('pending'))
      return 'pending';

    return null;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return const Color(0xFF28A745);
      case 'pending':
        return const Color(0xFFFFC107);
      case 'rejected':
      case 'declined':
        return const Color(0xFFDC3545);
      case 'completed':
        return const Color(0xFF6F42C1);
      case 'cancelled':
        return const Color(0xFF6C757D);
      default:
        return const Color(0xFF007BFF);
    }
  }

  List<Color> _getNotificationGradient(HomeNotificationType type) {
    switch (type) {
      case HomeNotificationType.message:
        return const [Color(0xFF667EEA), Color(0xFF764BA2)];
      case HomeNotificationType.booking:
        return const [Color(0xFFA8C0FF), Color(0xFF3F2B96)];
      case HomeNotificationType.payment:
        return const [Color(0xFFFD746C), Color(0xFFFF9068)];
      case HomeNotificationType.reminder:
        return const [Color(0xFFF093FB), Color(0xFFF5576C)];
      case HomeNotificationType.follow:
        return const [Color(0xFF4CAF50), Color(0xFF8BC34A)];
      case HomeNotificationType.promotional:
        return const [Color(0xFFFF6B6B), Color(0xFFFFA726)];
      case HomeNotificationType.rating:
        return const [Color(0xFFFFD93D), Color(0xFF6BCF7F)];
      case HomeNotificationType.health:
        return const [Color(0xFFFF6B6B), Color(0xFF4ECDC4)];
      default:
        return const [Color(0xFF667EEA), Color(0xFF764BA2)];
    }
  }

  String _getActionText(HomeNotificationType type, LanguageProvider lang) {
    switch (type) {
      case HomeNotificationType.message:
        return lang.tr('action_message', category: 'notifications');
      case HomeNotificationType.follow:
        return lang.tr('action_follow', category: 'notifications');
      case HomeNotificationType.booking:
        return lang.tr('action_booking', category: 'notifications');
      case HomeNotificationType.payment:
        return lang.tr('action_payment', category: 'notifications');
      case HomeNotificationType.reminder:
        return lang.tr('action_reminder', category: 'notifications');
      case HomeNotificationType.promotional:
        return lang.tr('action_promotional', category: 'notifications');
      case HomeNotificationType.rating:
        return lang.tr('action_rating', category: 'notifications');
      case HomeNotificationType.health:
        return lang.tr('action_health', category: 'notifications');
      default:
        return lang.tr('action_default', category: 'notifications');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Directionality(
              // CORRECTED: Using ui.TextDirection
              textDirection: languageProvider.isRtl
                  ? ui.TextDirection.rtl
                  : ui.TextDirection.ltr,
              child: StreamBuilder<List<HomeNotificationItem>>(
                stream: _notificationsStream,
                initialData: const [],
                builder: (context, snapshot) {
                  final notifications = snapshot.data ?? [];
                  final unreadCount =
                      notifications.where((n) => !n.isRead).length;
                  final (today, week) = _categorizeNotifications(notifications);

                  return Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8F9FF),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageProvider.tr('notifications',
                                      category: 'notifications'),
                                  style: const TextStyle(
                                    color: Color(0xFF333333),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Exo2',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  languageProvider.trParams(
                                    'unread_count',
                                    category: 'notifications',
                                    params: {
                                      'unread': unreadCount.toString(),
                                      'total': notifications.length.toString(),
                                    },
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 12,
                                    fontFamily: 'Exo2',
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),

                      // Main content area
                      Expanded(
                        child: _buildNotificationsBody(snapshot, today, week,
                            unreadCount, languageProvider),
                      ),

                      // Bottom button (only if there are unread notifications)
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                                top: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              print('🔘 Button pressed!');
                              print('🔘 Calling _markAllAsRead()');
                              _markAllAsRead().catchError((e) {
                                print('❌ Button error: $e');
                              });
                            },
                            icon: const Icon(Icons.check_circle_outline,
                                size: 18),
                            label: Text(
                              languageProvider.trParams(
                                'mark_all_as_read',
                                category: 'notifications',
                                params: {'count': unreadCount.toString()},
                              ),
                              style: const TextStyle(fontFamily: 'Exo2'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667EEA),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationsBody(
    AsyncSnapshot<List<HomeNotificationItem>> snapshot,
    List<HomeNotificationItem> today,
    List<HomeNotificationItem> week,
    int unreadCount,
    LanguageProvider lang,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        snapshot.data?.isEmpty == true) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            const Color(0xFF667EEA),
          ),
        ),
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              lang.tr('error_loading', category: 'notifications'),
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontFamily: 'Exo2',
              ),
            ),
          ],
        ),
      );
    }

    final notifications = snapshot.data ?? [];

    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.bell_slash,
              size: 60,
              color: Color(0xFFCCCCCC),
            ),
            const SizedBox(height: 16),
            Text(
              lang.tr('no_notifications', category: 'notifications'),
              style: const TextStyle(
                color: Color(0xFF999999),
                fontSize: 16,
                fontFamily: 'Exo2',
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (today.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  lang.tr('today', category: 'notifications'),
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Exo2',
                  ),
                ),
              ),
              ...today
                  .map((notification) => _buildNotificationItem(notification)),
            ],
          ),
        if (week.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  lang.tr('this_week', category: 'notifications'),
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Exo2',
                  ),
                ),
              ),
              ...week
                  .map((notification) => _buildNotificationItem(notification)),
            ],
          ),
      ],
    );
  }

  String _formatTime(DateTime time, LanguageProvider lang) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return lang.tr('just_now', category: 'notifications');
    } else if (difference.inMinutes < 60) {
      return lang.trParams(
        'minutes_ago',
        category: 'notifications',
        params: {'minutes': difference.inMinutes.toString()},
      );
    } else if (difference.inHours < 24) {
      return lang.trParams(
        'hours_ago',
        category: 'notifications',
        params: {'hours': difference.inHours.toString()},
      );
    } else if (difference.inDays < 7) {
      return lang.trParams(
        'days_ago',
        category: 'notifications',
        params: {'days': difference.inDays.toString()},
      );
    } else {
      final weeks = (difference.inDays / 7).floor();
      return lang.trParams(
        'weeks_ago',
        category: 'notifications',
        params: {'weeks': weeks.toString()},
      );
    }
  }

  void _navigateToChat(
      BuildContext context, HomeNotificationItem notification) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    if (notification.chatId != null && _currentUserId != null) {
      Navigator.of(context).pop();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider(
            create: (context) => ChatViewModel(userId: _currentUserId!),
            child: DiscussionPage(
              contactName: notification.senderName ??
                  notification.title
                      .replaceAll('New message from ', '')
                      .replaceAll(RegExp(r' \(\d+ new\)'), ''),
              isOnline: true,
              chatId: notification.chatId!,
              currentUserId: _currentUserId!,
              chatViewModel: ChatViewModel(userId: _currentUserId!),
            ),
          ),
        ),
      );
    }
  }
}

void showNotificationsWindow(BuildContext context) {
  final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);

  showDialog(
    context: context,
    builder: (context) {
      return NotificationsWindow(chatViewModel: chatViewModel);
    },
    barrierColor: Colors.black.withOpacity(0.3),
  );
}

// =================== Booking Notification Service ===================
class BookingNotificationService {
  static Future<void> createNewBookingNotification({
    required String providerId,
    required String clientName,
    required String serviceTitle,
    required String clientId,
    required String bookingId,
  }) async {
    try {
      final notificationData = {
        'receiverId': providerId,
        'title': 'New Booking Request',
        'message': '$clientName requested "$serviceTitle"',
        'senderId': clientId,
        'senderName': clientName,
        'type': 'booking',
        'bookingId': bookingId,
        'bookingStatus': 'pending',
        'userRole': 'provider',
        'timestamp': Timestamp.now(),
        'isRead': false,
        'lastMessageTime': Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notificationData);

      print('✅ Booking notification created for provider $providerId');
    } catch (e) {
      print('❌ Error creating booking notification: $e');
    }
  }

  static Future<void> updateBookingStatusNotification({
    required String bookingId,
    required String newStatus,
    required String providerId,
    required String clientId,
    required String providerName,
    required String clientName,
    required String serviceTitle,
  }) async {
    try {
      String title = '';
      String message = '';
      String receiverId = '';
      String senderId = '';
      String senderName = '';

      if (newStatus == 'accepted') {
        title = 'Booking Accepted!';
        message = '$providerName accepted your "$serviceTitle" booking';
        receiverId = clientId;
        senderId = providerId;
        senderName = providerName;
      } else if (newStatus == 'rejected') {
        title = 'Booking Declined';
        message = '$providerName declined your "$serviceTitle" booking';
        receiverId = clientId;
        senderId = providerId;
        senderName = providerName;
      } else if (newStatus == 'completed') {
        title = 'Service Completed';
        message = '$providerName marked "$serviceTitle" as completed';
        receiverId = clientId;
        senderId = providerId;
        senderName = providerName;
      } else if (newStatus == 'cancelled') {
        title = 'Booking Cancelled';
        message = '$clientName cancelled the "$serviceTitle" booking';
        receiverId = providerId;
        senderId = clientId;
        senderName = clientName;
      }

      if (title.isNotEmpty) {
        final notificationData = {
          'receiverId': receiverId,
          'title': title,
          'message': message,
          'senderId': senderId,
          'senderName': senderName,
          'type': 'booking',
          'bookingId': bookingId,
          'bookingStatus': newStatus,
          'userRole': newStatus == 'cancelled' ? 'provider' : 'client',
          'timestamp': Timestamp.now(),
          'isRead': false,
          'lastMessageTime': Timestamp.now(),
        };

        await FirebaseFirestore.instance
            .collection('notifications')
            .add(notificationData);

        print('✅ Booking status notification sent for booking $bookingId');
      }
    } catch (e) {
      print('❌ Error creating booking status notification: $e');
    }
  }
}

// =================== Notification Details Page ===================
class _NotificationDetailsPage extends StatelessWidget {
  final HomeNotificationItem notification;

  const _NotificationDetailsPage({required this.notification});

  List<Color> _getNotificationGradient(HomeNotificationType type) {
    switch (type) {
      case HomeNotificationType.message:
        return const [Color(0xFF667EEA), Color(0xFF764BA2)];
      case HomeNotificationType.booking:
        return const [Color(0xFFA8C0FF), Color(0xFF3F2B96)];
      case HomeNotificationType.payment:
        return const [Color(0xFFFD746C), Color(0xFFFF9068)];
      case HomeNotificationType.reminder:
        return const [Color(0xFFF093FB), Color(0xFFF5576C)];
      case HomeNotificationType.follow:
        return const [Color(0xFF4CAF50), Color(0xFF8BC34A)];
      default:
        return const [Color(0xFF667EEA), Color(0xFF764BA2)];
    }
  }

  String _getNotificationTitle(
      HomeNotificationType type, LanguageProvider lang) {
    switch (type) {
      case HomeNotificationType.booking:
        return lang.tr('notification_title_booking', category: 'notifications');
      case HomeNotificationType.payment:
        return lang.tr('notification_title_payment', category: 'notifications');
      case HomeNotificationType.reminder:
        return lang.tr('notification_title_reminder',
            category: 'notifications');
      case HomeNotificationType.follow:
        return lang.tr('notification_title_follow', category: 'notifications');
      case HomeNotificationType.message:
        return lang.tr('notification_title_message', category: 'notifications');
      default:
        return lang.tr('notification_title_default', category: 'notifications');
    }
  }

  String _formatDetailedTime(DateTime time, LanguageProvider lang) {
    final formatter = DateFormat(
        lang.locale.languageCode == 'ar'
            ? 'd MMMM yyyy • h:mm a'
            : 'MMMM d, y • h:mm a',
        lang.locale.languageCode);
    return formatter.format(time);
  }

  String? _extractServiceTitle(String message) {
    final match = RegExp(r'"([^"]+)"').firstMatch(message);
    return match?.group(1);
  }

  String _getTranslatedBookingStatus(String status, LanguageProvider lang) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return lang.tr('booking_status_accepted', category: 'notifications');
      case 'rejected':
        return lang.tr('booking_status_rejected', category: 'notifications');
      case 'declined':
        return lang.tr('booking_status_declined', category: 'notifications');
      case 'completed':
        return lang.tr('booking_status_completed', category: 'notifications');
      case 'cancelled':
        return lang.tr('booking_status_cancelled', category: 'notifications');
      case 'pending':
        return lang.tr('booking_status_pending', category: 'notifications');
      default:
        return status.toUpperCase();
    }
  }

  Widget _buildBookingDetails(LanguageProvider lang) {
    final serviceTitle = _extractServiceTitle(notification.message) ??
        lang.tr('service', category: 'notifications');
    final bookingStatus = _getBookingStatusFromNotification(notification);
    final statusColor = _getStatusColor(bookingStatus ?? 'pending');
    final translatedStatus = bookingStatus != null
        ? _getTranslatedBookingStatus(bookingStatus, lang)
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1E9FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.tr('booking_information', category: 'notifications'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0066CC),
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 12),
          if (bookingStatus != null)
            _buildDetailRow(lang.tr('status', category: 'notifications'),
                translatedStatus, statusColor, lang),
          _buildDetailRow(lang.tr('service', category: 'notifications'),
              '"$serviceTitle"', Colors.grey.shade700, lang),
          _buildDetailRow(
              lang.tr('from', category: 'notifications'),
              notification.senderName ??
                  lang.tr('unknown_user', category: 'notifications'),
              Colors.grey.shade700,
              lang),
          _buildDetailRow(
              lang.tr('time', category: 'notifications'),
              _formatDetailedTime(notification.time, lang),
              Colors.grey.shade700,
              lang),
        ],
      ),
    );
  }

  String? _getBookingStatusFromNotification(HomeNotificationItem notification) {
    final message = notification.message.toLowerCase();

    if (message.contains('accepted')) return 'accepted';
    if (message.contains('declined') || message.contains('rejected'))
      return 'rejected';
    if (message.contains('completed')) return 'completed';
    if (message.contains('cancelled')) return 'cancelled';
    if (message.contains('requested') || message.contains('pending'))
      return 'pending';

    return null;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return const Color(0xFF28A745);
      case 'pending':
        return const Color(0xFFFFC107);
      case 'rejected':
      case 'declined':
        return const Color(0xFFDC3545);
      case 'completed':
        return const Color(0xFF6F42C1);
      case 'cancelled':
        return const Color(0xFF6C757D);
      default:
        return const Color(0xFF007BFF);
    }
  }

  Widget _buildDetailRow(
      String label, String value, Color valueColor, LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontFamily: 'Exo2',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Exo2',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          // CORRECTED: Using ui.TextDirection
          textDirection: languageProvider.isRtl
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _getNotificationGradient(notification.type),
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getNotificationTitle(
                                  notification.type, languageProvider),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Exo2',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDetailedTime(
                                  notification.time, languageProvider),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontFamily: 'Exo2',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _getNotificationGradient(
                                      notification.type),
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: notification.type ==
                                        HomeNotificationType.booking
                                    ? const Icon(
                                        Icons.calendar_today,
                                        color: Colors.white,
                                        size: 28,
                                      )
                                    : Icon(
                                        notification.icon,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notification.senderName ??
                                        languageProvider.tr('unknown_user',
                                            category: 'notifications'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF333333),
                                      fontFamily: 'Exo2',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notification.title,
                                    style: const TextStyle(
                                      color: Color(0xFF666666),
                                      fontSize: 14,
                                      fontFamily: 'Exo2',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.tr('message',
                                    category: 'notifications'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF667EEA),
                                  fontFamily: 'Exo2',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                notification.message,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF333333),
                                  height: 1.5,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (notification.type == HomeNotificationType.booking)
                          _buildBookingDetails(languageProvider),
                        const SizedBox(height: 32),
                        if (notification.type == HomeNotificationType.booking)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade200),
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const MyBookingsScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.calendar_today,
                                      size: 16),
                                  label: Text(
                                    languageProvider.tr('view_bookings',
                                        category: 'notifications'),
                                    style: const TextStyle(fontFamily: 'Exo2'),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: const Color(0xFF667EEA),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
