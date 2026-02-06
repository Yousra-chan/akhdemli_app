// screens/home/notifications_page.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:service_app/ViewModel/auth_view_model.dart' show AuthViewModel;
import 'package:service_app/ViewModel/chat_view_model.dart' show ChatViewModel;
import 'package:service_app/screens/Booking/my_booking_page.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_page.dart';
import 'package:provider/provider.dart';
import 'package:service_app/models/notification_item.dart';
import 'package:intl/intl.dart';

class NotificationsWindow extends StatefulWidget {
  const NotificationsWindow({super.key});

  @override
  State<NotificationsWindow> createState() => _NotificationsWindowState();
}

class _NotificationsWindowState extends State<NotificationsWindow> {
  late Stream<List<HomeNotificationItem>> _notificationsStream;
  String? _currentUserId;
  late StreamController<List<HomeNotificationItem>> _streamController;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _streamController =
        StreamController<List<HomeNotificationItem>>.broadcast();
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
    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) {
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
      print('Error loading notifications: $e');
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

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('time', descending: true)
          .limit(50)
          .get();

      final notifications = <HomeNotificationItem>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Skip notifications where user is the sender
        if (data['senderId'] == _currentUserId) {
          continue;
        }

        try {
          // Create a HomeNotificationItem directly from the data
          final notification = _createNotificationFromData(doc.id, data);
          notifications.add(notification);
        } catch (e) {
          print('Error parsing notification ${doc.id}: $e');
        }
      }

      return notifications;
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
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

  HomeNotificationItem _createNotificationFromData(
      String id, Map<String, dynamic> data) {
    return HomeNotificationItem(
      id: id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: _parseNotificationType(data['type']),
      chatId: data['chatId'],
      senderId: data['senderId'],
      senderName: data['senderName'],
      actionText: data['actionText'] ?? '',
      isRead: data['isRead'] ?? false,
      time: (data['time'] as Timestamp).toDate(),
      messageCount: (data['messageCount'] as num?)?.toInt() ?? 1,
      lastMessageTime: data['lastMessageTime'] != null
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : (data['time'] as Timestamp).toDate(),
      bookingId: data['bookingId'],
      bookingStatus: data['bookingStatus'],
      userRole: data['userRole'],
    );
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

  void _markAsReadAndDelete(String id) {
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(id)
        .delete()
        .then((_) {
      _loadNotifications();
    }).catchError((e) => print('Error deleting notification: $e'));
  }

  void _handleNotificationTap(
      BuildContext context, HomeNotificationItem notification) {
    _markAsReadAndDelete(notification.id);

    switch (notification.type) {
      case HomeNotificationType.message:
        _navigateToChat(context, notification);
        break;

      case HomeNotificationType.booking:
        _navigateToBookings(context, notification);
        break;

      case HomeNotificationType.payment:
      case HomeNotificationType.reminder:
      case HomeNotificationType.follow:
      default:
        _showNotificationDetails(context, notification);
        break;
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
    final isBookingNotification =
        notification.type == HomeNotificationType.booking;

    // Get booking status from notification data
    final bookingStatus = _getBookingStatusFromNotification(notification);

    return GestureDetector(
      onTap: () => _handleNotificationTap(context, notification),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isBookingNotification
              ? Border.all(color: Color(0xFF667EEA).withOpacity(0.3), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _getNotificationGradient(notification.type),
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isBookingNotification
                    ? Icon(
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
                          notification.senderName ?? 'Unknown User',
                          style: TextStyle(
                            color: Color(0xFF333333),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isBookingNotification && bookingStatus != null)
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(bookingStatus),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            bookingStatus.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        Text(
                          _formatTime(notification.time),
                          style: TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getActionText(notification),
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
                              size: 12, color: Color(0xFF999999)),
                          SizedBox(width: 4),
                          Text(
                            _formatTime(notification.time),
                            style: TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 12,
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

  // Helper method to extract booking status from notification
  String? _getBookingStatusFromNotification(HomeNotificationItem notification) {
    // Since HomeNotificationItem doesn't have bookingStatus field,
    // we need to extract it from the message or use a different approach
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
        return Color(0xFF28A745);
      case 'pending':
        return Color(0xFFFFC107);
      case 'rejected':
      case 'declined':
        return Color(0xFFDC3545);
      case 'completed':
        return Color(0xFF6F42C1);
      case 'cancelled':
        return Color(0xFF6C757D);
      default:
        return Color(0xFF007BFF);
    }
  }

  List<Color> _getNotificationGradient(HomeNotificationType type) {
    switch (type) {
      case HomeNotificationType.message:
        return [Color(0xFF667EEA), Color(0xFF764BA2)];
      case HomeNotificationType.booking:
        return [Color(0xFFA8C0FF), Color(0xFF3F2B96)];
      case HomeNotificationType.payment:
        return [Color(0xFFFD746C), Color(0xFFFF9068)];
      case HomeNotificationType.reminder:
        return [Color(0xFFF093FB), Color(0xFFF5576C)];
      case HomeNotificationType.follow:
        return [Color(0xFF4CAF50), Color(0xFF8BC34A)];
      case HomeNotificationType.promotional:
        return [Color(0xFFFF6B6B), Color(0xFFFFA726)];
      case HomeNotificationType.rating:
        return [Color(0xFFFFD93D), Color(0xFF6BCF7F)];
      case HomeNotificationType.health:
        return [Color(0xFFFF6B6B), Color(0xFF4ECDC4)];
      default:
        return [Color(0xFF667EEA), Color(0xFF764BA2)];
    }
  }

  String _getActionText(HomeNotificationItem notification) {
    switch (notification.type) {
      case HomeNotificationType.message:
        return 'Sent you a message';
      case HomeNotificationType.follow:
        return 'Started following';
      case HomeNotificationType.booking:
        return 'Booking update';
      case HomeNotificationType.payment:
        return 'Made a payment';
      case HomeNotificationType.reminder:
        return 'Reminder for';
      case HomeNotificationType.promotional:
        return 'Special offer';
      case HomeNotificationType.rating:
        return 'Left a rating';
      case HomeNotificationType.health:
        return 'Health update';
      default:
        return 'Notification';
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: StreamBuilder<List<HomeNotificationItem>>(
          stream: _notificationsStream,
          initialData: const [],
          builder: (context, snapshot) {
            final notifications = snapshot.data ?? [];
            final (today, week) = _categorizeNotifications(notifications);

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8F9FF),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Notifications',
                            style: TextStyle(
                              color: Color(0xFF333333),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You have ${notifications.length} Notifications today.',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildNotificationsBody(snapshot, today, week),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationsBody(
    AsyncSnapshot<List<HomeNotificationItem>> snapshot,
    List<HomeNotificationItem> today,
    List<HomeNotificationItem> week,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        snapshot.data?.isEmpty == true) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Color(0xFF667EEA),
          ),
        ),
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading notifications',
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
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
            Icon(
              CupertinoIcons.bell_slash,
              size: 60,
              color: Color(0xFFCCCCCC),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                color: Color(0xFF999999),
                fontSize: 16,
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
                  'Today',
                  style: TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...today.map(_buildNotificationItem),
            ],
          ),
        if (week.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  'This Week',
                  style: TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...week.map(_buildNotificationItem),
            ],
          ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    }
  }

  void _navigateToChat(
      BuildContext context, HomeNotificationItem notification) {
    if (notification.chatId != null && _currentUserId != null) {
      _markAsReadAndDelete(notification.id);
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
  showDialog(
    context: context,
    builder: (context) {
      return NotificationsWindow();
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
        'userId': providerId,
        'title': 'New Booking Request',
        'message': '$clientName requested "$serviceTitle"',
        'senderId': clientId,
        'senderName': clientName,
        'type': 'booking',
        'bookingId': bookingId,
        'bookingStatus': 'pending',
        'userRole': 'provider',
        'time': Timestamp.now(),
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
      String userId = '';
      String senderId = '';
      String senderName = '';

      if (newStatus == 'accepted') {
        title = 'Booking Accepted!';
        message = '$providerName accepted your "$serviceTitle" booking';
        userId = clientId;
        senderId = providerId;
        senderName = providerName;
      } else if (newStatus == 'rejected') {
        title = 'Booking Declined';
        message = '$providerName declined your "$serviceTitle" booking';
        userId = clientId;
        senderId = providerId;
        senderName = providerName;
      } else if (newStatus == 'completed') {
        title = 'Service Completed';
        message = '$providerName marked "$serviceTitle" as completed';
        userId = clientId;
        senderId = providerId;
        senderName = providerName;
      } else if (newStatus == 'cancelled') {
        title = 'Booking Cancelled';
        message = '$clientName cancelled the "$serviceTitle" booking';
        userId = providerId;
        senderId = clientId;
        senderName = clientName;
      }

      if (title.isNotEmpty) {
        final notificationData = {
          'userId': userId,
          'title': title,
          'message': message,
          'senderId': senderId,
          'senderName': senderName,
          'type': 'booking',
          'bookingId': bookingId,
          'bookingStatus': newStatus,
          'userRole': newStatus == 'cancelled' ? 'provider' : 'client',
          'time': Timestamp.now(),
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

class _NotificationDetailsPage extends StatelessWidget {
  final HomeNotificationItem notification;

  const _NotificationDetailsPage({required this.notification});

  List<Color> _getNotificationGradient(HomeNotificationType type) {
    switch (type) {
      case HomeNotificationType.message:
        return [Color(0xFF667EEA), Color(0xFF764BA2)];
      case HomeNotificationType.booking:
        return [Color(0xFFA8C0FF), Color(0xFF3F2B96)];
      case HomeNotificationType.payment:
        return [Color(0xFFFD746C), Color(0xFFFF9068)];
      case HomeNotificationType.reminder:
        return [Color(0xFFF093FB), Color(0xFFF5576C)];
      case HomeNotificationType.follow:
        return [Color(0xFF4CAF50), Color(0xFF8BC34A)];
      default:
        return [Color(0xFF667EEA), Color(0xFF764BA2)];
    }
  }

  String _getNotificationTitle(HomeNotificationType type) {
    switch (type) {
      case HomeNotificationType.booking:
        return 'Booking Details';
      case HomeNotificationType.payment:
        return 'Payment Details';
      case HomeNotificationType.reminder:
        return 'Reminder';
      case HomeNotificationType.follow:
        return 'New Follower';
      case HomeNotificationType.message:
        return 'New Message';
      default:
        return 'Notification';
    }
  }

  String _formatDetailedTime(DateTime time) {
    final formatter = DateFormat('MMMM d, y • h:mm a');
    return formatter.format(time);
  }

  String? _extractServiceTitle(String message) {
    final match = RegExp(r'"([^"]+)"').firstMatch(message);
    return match?.group(1);
  }

  Widget _buildBookingDetails() {
    final serviceTitle =
        _extractServiceTitle(notification.message) ?? 'Service';
    final bookingStatus = _getBookingStatusFromNotification(notification);
    final statusColor = _getStatusColor(bookingStatus ?? 'pending');

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFD1E9FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Booking Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0066CC),
            ),
          ),
          SizedBox(height: 12),
          if (bookingStatus != null)
            _buildDetailRow('Status', bookingStatus.toUpperCase(), statusColor),
          _buildDetailRow('Service', '"$serviceTitle"', Colors.grey.shade700),
          _buildDetailRow('From', notification.senderName ?? 'Unknown',
              Colors.grey.shade700),
          _buildDetailRow('Time', _formatDetailedTime(notification.time),
              Colors.grey.shade700),
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
        return Color(0xFF28A745);
      case 'pending':
        return Color(0xFFFFC107);
      case 'rejected':
      case 'declined':
        return Color(0xFFDC3545);
      case 'completed':
        return Color(0xFF6F42C1);
      case 'cancelled':
        return Color(0xFF6C757D);
      default:
        return Color(0xFF007BFF);
    }
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _getNotificationGradient(notification.type),
              ),
              borderRadius: BorderRadius.only(
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
                        _getNotificationTitle(notification.type),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatDetailedTime(notification.time),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
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
                            colors: _getNotificationGradient(notification.type),
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child:
                              notification.type == HomeNotificationType.booking
                                  ? Icon(
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
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.senderName ?? 'Unknown User',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF333333),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              notification.formattedTitle,
                              style: TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Message',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF667EEA),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          notification.message,
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF333333),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  if (notification.type == HomeNotificationType.booking)
                    _buildBookingDetails(),
                  SizedBox(height: 32),
                  if (notification.type == HomeNotificationType.booking)
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 8),
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
                            icon: Icon(Icons.calendar_today, size: 16),
                            label: Text('View Bookings'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Color(0xFF667EEA),
                              padding: EdgeInsets.symmetric(
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
    );
  }
}
