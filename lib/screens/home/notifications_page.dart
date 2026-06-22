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
import '../../utils/ui_widgets.dart';

// ─── Dark-theme color helpers ────────────────────────────────────────────────
class _NC {
  // call with isDark = Theme.of(context).brightness == Brightness.dark
  static Color bg(bool d)           => d ? const Color(0xFF0F0F1A) : Colors.white;
  static Color headerBg(bool d)     => d ? const Color(0xFF16213E) : const Color(0xFFF8F9FF);
  static Color cardUnread(bool d)   => d ? const Color(0xFF1E2A4A) : const Color(0xFFF0F7FF);
  static Color cardRead(bool d)     => d ? const Color(0xFF161625) : Colors.white;
  static Color titleText(bool d)    => d ? const Color(0xFFE0E0E0) : const Color(0xFF333333);
  static Color subtitleText(bool d) => d ? const Color(0xFFAAAAAA) : const Color(0xFF666666);
  static Color timeUnread(bool d)   => d ? const Color(0xFF8B9EFF) : const Color(0xFF667EEA);
  static Color timeRead(bool d)     => d ? const Color(0xFF777777) : const Color(0xFF999999);
  static Color sectionLabel(bool d) => d ? const Color(0xFFDDDDDD) : const Color(0xFF333333);
  static Color divider(bool d)      => d ? const Color(0xFF2A2A40) : Colors.grey.shade200;
  static Color bottomBar(bool d)    => d ? const Color(0xFF16213E) : Colors.white;
  static Color borderRead(bool d)   => d ? const Color(0xFF2A2A40) : Colors.grey.shade100;
  static Color shadow(bool d)       => d ? Colors.black54 : Colors.black12;
  static Color emptyIcon(bool d)    => d ? const Color(0xFF3E3E5E) : const Color(0xFFCCCCCC);
  static Color emptyText(bool d)    => d ? const Color(0xFF8888AA) : const Color(0xFF999999);
  static Color msgBg(bool d)        => d ? const Color(0xFF1A1A2E) : const Color(0xFFF8F9FF);
  static Color msgLabel(bool d)     => d ? const Color(0xFF8B9EFF) : const Color(0xFF667EEA);
  static Color msgBody(bool d)      => d ? const Color(0xFFDDDDDD) : const Color(0xFF333333);
  static Color bookingInfoBg(bool d)  => d ? const Color(0xFF101B3A) : const Color(0xFFF0F7FF);
  static Color bookingInfoBorder(bool d) => d ? const Color(0xFF1A3A6E) : const Color(0xFFD1E9FF);
  static Color bookingInfoTitle(bool d)  => d ? const Color(0xFF5A9FFF) : const Color(0xFF0066CC);
  static Color detailLabel(bool d)  => d ? const Color(0xFF999999) : Colors.grey.shade600;
  static Color detailValue(bool d)  => d ? const Color(0xFFDDDDDD) : Colors.grey.shade700;
  static Color actionBorder(bool d) => d ? const Color(0xFF2A2A40) : Colors.grey.shade200;
}
// ─────────────────────────────────────────────────────────────────────────────

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
      debugPrint('❌ Error loading notifications: $e');
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
        AppSnackBar.showSuccess(
          context,
          languageProvider.tr('all_marked_read', category: 'notifications'),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in _markAllAsRead: $e');
      if (mounted) {
        AppSnackBar.showError(
          context,
          languageProvider.tr('error_mark_read', category: 'notifications'),
        );
      }
    }
  }

  void _markAsRead(String id) {
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(id)
        .update({'isRead': true}).then((_) {
      debugPrint('✅ Marked notification $id as read');
      _loadNotifications();
    }).catchError((e) => debugPrint('❌ Error updating notification: $e'));
  }

  void _handleNotificationTap(HomeNotificationItem notification) async {
    debugPrint('👆 Notification tapped: ${notification.id}');

    if (!notification.isRead) {
      try {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notification.id)
            .update({
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Marked notification ${notification.id} as read');
      } catch (e) {
        debugPrint('❌ Error marking notification as read: $e');
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
              contactUserId: notification.senderId,
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

  Widget _buildNotificationItem(
      HomeNotificationItem notification, bool isDark) {
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
          color: isRead ? _NC.cardRead(isDark) : _NC.cardUnread(isDark),
          borderRadius: BorderRadius.circular(12),
          border: isBookingNotification
              ? Border.all(
              color: const Color(0xFF667EEA).withOpacity(isDark ? 0.5 : 0.3),
              width: 2)
              : isRead
              ? Border.all(color: _NC.borderRead(isDark), width: 1)
              : Border.all(
              color: const Color(0xFF667EEA).withOpacity(isDark ? 0.7 : 0.5),
              width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _NC.shadow(isDark).withOpacity(isRead ? 0.05 : 0.12),
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
                      .map((color) =>
                  isRead ? color.withOpacity(isDark ? 0.6 : 0.5) : color)
                      .toList(),
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isBookingNotification
                    ? const Icon(Icons.calendar_today,
                    color: Colors.white, size: 20)
                    : Icon(notification.icon, color: Colors.white, size: 20),
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
                                ? _NC.subtitleText(isDark)
                                : _NC.titleText(isDark),
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
                                ? _NC.timeRead(isDark)
                                : _NC.timeUnread(isDark),
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
                          ? _NC.timeRead(isDark)
                          : _NC.subtitleText(isDark),
                      fontSize: 13,
                      fontFamily: 'Exo2',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      color: isRead
                          ? _NC.subtitleText(isDark)
                          : _NC.titleText(isDark),
                      fontSize: 14,
                      fontWeight:
                      isRead ? FontWeight.normal : FontWeight.w500,
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
                              size: 12, color: _NC.timeRead(isDark)),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(notification.time, languageProvider),
                            style: TextStyle(
                              color: _NC.timeRead(isDark),
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
    if (message.contains('declined') || message.contains('rejected')) {
      return 'rejected';
    }
    if (message.contains('completed')) return 'completed';
    if (message.contains('cancelled')) return 'cancelled';
    if (message.contains('requested') || message.contains('pending')) {
      return 'pending';
    }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: _NC.bg(isDark),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Directionality(
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
                      // ── Header ──────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _NC.headerBg(isDark),
                          borderRadius: const BorderRadius.only(
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
                                  style: TextStyle(
                                    color: _NC.titleText(isDark),
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
                                  style: TextStyle(
                                    color: _NC.subtitleText(isDark),
                                    fontSize: 12,
                                    fontFamily: 'Exo2',
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  size: 20, color: _NC.subtitleText(isDark)),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),

                      // ── Main content ─────────────────────────────────────
                      Expanded(
                        child: _buildNotificationsBody(snapshot, today, week,
                            unreadCount, languageProvider, isDark),
                      ),

                      // ── Bottom "mark all read" button ─────────────────────
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _NC.bottomBar(isDark),
                            border: Border(
                                top: BorderSide(
                                    color: _NC.divider(isDark))),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              print('🔘 Button pressed!');
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
      bool isDark,
      ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        snapshot.data?.isEmpty == true) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
        ),
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.exclamationmark_circle,
                size: 60, color: Colors.red.withOpacity(isDark ? 0.8 : 1.0)),
            const SizedBox(height: 16),
            Text(
              lang.tr('error_loading', category: 'notifications'),
              style: TextStyle(
                color: Colors.red.withOpacity(isDark ? 0.8 : 1.0),
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
            Icon(CupertinoIcons.bell_slash,
                size: 60, color: _NC.emptyIcon(isDark)),
            const SizedBox(height: 16),
            Text(
              lang.tr('no_notifications', category: 'notifications'),
              style: TextStyle(
                color: _NC.emptyText(isDark),
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
                  style: TextStyle(
                    color: _NC.sectionLabel(isDark),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Exo2',
                  ),
                ),
              ),
              ...today.map((n) => _buildNotificationItem(n, isDark)),
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
                  style: TextStyle(
                    color: _NC.sectionLabel(isDark),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Exo2',
                  ),
                ),
              ),
              ...week.map((n) => _buildNotificationItem(n, isDark)),
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
      return lang.trParams('minutes_ago',
          category: 'notifications',
          params: {'minutes': difference.inMinutes.toString()});
    } else if (difference.inHours < 24) {
      return lang.trParams('hours_ago',
          category: 'notifications',
          params: {'hours': difference.inHours.toString()});
    } else if (difference.inDays < 7) {
      return lang.trParams('days_ago',
          category: 'notifications',
          params: {'days': difference.inDays.toString()});
    } else {
      final weeks = (difference.inDays / 7).floor();
      return lang.trParams('weeks_ago',
          category: 'notifications',
          params: {'weeks': weeks.toString()});
    }
  }

  void _navigateToChat(
      BuildContext context, HomeNotificationItem notification) {
    if (notification.chatId != null && _currentUserId != null) {
      final chatVM = Provider.of<ChatViewModel?>(context, listen: false);
      if (chatVM == null) return;

      Navigator.of(context).pop();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DiscussionPage(
            contactName: notification.senderName ?? 
                Provider.of<LanguageProvider>(context, listen: false)
                    .tr('chat', category: 'notifications'),
            isOnline: true,
            chatId: notification.chatId!,
            currentUserId: _currentUserId!,
            chatViewModel: chatVM,
            contactUserId: notification.senderId,
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

  Widget _buildBookingDetails(LanguageProvider lang, bool isDark) {
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
        color: _NC.bookingInfoBg(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _NC.bookingInfoBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.tr('booking_information', category: 'notifications'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _NC.bookingInfoTitle(isDark),
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 12),
          if (bookingStatus != null)
            _buildDetailRow(lang.tr('status', category: 'notifications'),
                translatedStatus, statusColor, isDark),
          _buildDetailRow(lang.tr('service', category: 'notifications'),
              '"$serviceTitle"', _NC.detailValue(isDark), isDark),
          _buildDetailRow(
              lang.tr('from', category: 'notifications'),
              notification.senderName ??
                  lang.tr('unknown_user', category: 'notifications'),
              _NC.detailValue(isDark),
              isDark),
          _buildDetailRow(
              lang.tr('time', category: 'notifications'),
              _formatDetailedTime(notification.time, lang),
              _NC.detailValue(isDark),
              isDark),
        ],
      ),
    );
  }

  String? _getBookingStatusFromNotification(HomeNotificationItem notification) {
    final message = notification.message.toLowerCase();

    if (message.contains('accepted')) return 'accepted';
    if (message.contains('declined') || message.contains('rejected')) {
      return 'rejected';
    }
    if (message.contains('completed')) return 'completed';
    if (message.contains('cancelled')) return 'cancelled';
    if (message.contains('requested') || message.contains('pending')) {
      return 'pending';
    }

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
      String label, String value, Color valueColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _NC.detailLabel(isDark),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.isRtl
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: _NC.bg(isDark),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // ── Gradient header (stays the same in both themes) ────────
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

                // ── Scrollable body ────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // sender row
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
                                    ? const Icon(Icons.calendar_today,
                                    color: Colors.white, size: 28)
                                    : Icon(notification.icon,
                                    color: Colors.white, size: 28),
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
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: _NC.titleText(isDark),
                                      fontFamily: 'Exo2',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notification.title,
                                    style: TextStyle(
                                      color: _NC.subtitleText(isDark),
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

                        // message box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _NC.msgBg(isDark),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.tr('message',
                                    category: 'notifications'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _NC.msgLabel(isDark),
                                  fontFamily: 'Exo2',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                notification.message,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _NC.msgBody(isDark),
                                  height: 1.5,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (notification.type == HomeNotificationType.booking)
                          _buildBookingDetails(languageProvider, isDark),
                        const SizedBox(height: 32),

                        // action buttons for booking
                        if (notification.type == HomeNotificationType.booking)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: _NC.actionBorder(isDark)),
                                bottom:
                                BorderSide(color: _NC.actionBorder(isDark)),
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
