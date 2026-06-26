// models/notification_item.dart - UPDATED VERSION
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:service_app/screens/home/home_screen/home_constants.dart';

class HomeNotificationItem {
  final String id;
  final String title;
  final String message;
  final HomeNotificationType type;
  final String? chatId;
  final String? senderId;
  final String? senderName;
  final String actionText;
  final bool isRead;
  final DateTime time;
  final int messageCount;
  final DateTime lastMessageTime;

  // ADDED: Booking notification fields
  final String? bookingId;
  final String? bookingStatus;
  final String? userRole; // 'client' or 'provider'

  HomeNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.chatId,
    this.senderId,
    this.senderName,
    this.actionText = '',
    required this.isRead,
    required this.time,
    this.messageCount = 1,
    required this.lastMessageTime,

    // ADDED: Booking fields
    this.bookingId,
    this.bookingStatus,
    this.userRole,
  });
  factory HomeNotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final time = data['time'] is Timestamp 
        ? (data['time'] as Timestamp).toDate() 
        : DateTime.now();
    
    return HomeNotificationItem(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: _parseNotificationType(data['type']),
      chatId: data['chatId'],
      senderId: data['senderId'],
      senderName: data['senderName'],
      actionText: data['actionText'] ?? '',
      isRead: data['isRead'] ?? false,
      time: time,
      messageCount: (data['messageCount'] as num?)?.toInt() ?? 1,
      lastMessageTime: data['lastMessageTime'] is Timestamp
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : time,
      // ADDED: Parse booking fields
      bookingId: data['bookingId'],
      bookingStatus: data['bookingStatus'],
      userRole: data['userRole'],
    );
  }

  static HomeNotificationType _parseNotificationType(String? type) {
    switch (type) {
      case 'message':
        return HomeNotificationType.message;
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
      default:
        return HomeNotificationType.message;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'time': Timestamp.fromDate(time),
      'isRead': isRead,
      'type': _notificationTypeToString(type),
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'actionText': actionText,
      'messageCount': messageCount,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),

      // ADDED: Booking fields
      'bookingId': bookingId,
      'bookingStatus': bookingStatus,
      'userRole': userRole,
    };
  }

  static String _notificationTypeToString(HomeNotificationType type) {
    switch (type) {
      case HomeNotificationType.message:
        return 'message';
      case HomeNotificationType.booking:
        return 'booking';
      case HomeNotificationType.payment:
        return 'payment';
      case HomeNotificationType.reminder:
        return 'reminder';
      case HomeNotificationType.promotional:
        return 'promotional';
      case HomeNotificationType.rating:
        return 'rating';
      case HomeNotificationType.health:
        return 'health';
      case HomeNotificationType.follow:
        return 'follow';
    }
  }

  String get formattedTitle {
    if (type == HomeNotificationType.message && messageCount > 1) {
      return title.replaceAllMapped(
        RegExp(r'New message from (.*?)( \(\d+ new\))?'),
        (match) {
          final sender = match[1] ?? '';
          return 'New message from $sender ($messageCount new)';
        },
      );
    }
    return title;
  }

  HomeNotificationItem copyWithNewMessage(String newMessage, DateTime newTime) {
    return HomeNotificationItem(
      id: id,
      title: title,
      message: newMessage,
      type: type,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      actionText: actionText,
      isRead: false,
      time: time,
      messageCount: messageCount + 1,
      lastMessageTime: newTime,

      // ADDED: Booking fields
      bookingId: bookingId,
      bookingStatus: bookingStatus,
      userRole: userRole,
    );
  }

  IconData get icon {
    switch (type) {
      case HomeNotificationType.booking:
        return CupertinoIcons.calendar;
      case HomeNotificationType.payment:
        return CupertinoIcons.money_dollar_circle_fill;
      case HomeNotificationType.reminder:
        return CupertinoIcons.clock_fill;
      case HomeNotificationType.promotional:
        return CupertinoIcons.sparkles;
      case HomeNotificationType.rating:
        return CupertinoIcons.star_fill;
      case HomeNotificationType.health:
        return CupertinoIcons.heart_fill;
      case HomeNotificationType.follow:
        return CupertinoIcons.person_add_solid;
      case HomeNotificationType.message:
      default:
        return CupertinoIcons.chat_bubble_fill;
    }
  }

  Color get iconColor {
    switch (type) {
      case HomeNotificationType.booking:
        return Colors.blue;
      case HomeNotificationType.payment:
        return Colors.green;
      case HomeNotificationType.reminder:
        return Colors.orange;
      case HomeNotificationType.promotional:
        return Colors.purple;
      case HomeNotificationType.rating:
        return kRatingYellow;
      case HomeNotificationType.health:
        return Colors.red;
      case HomeNotificationType.follow:
        return Colors.teal;
      case HomeNotificationType.message:
      default:
        return kPrimaryBlue;
    }
  }
}

enum HomeNotificationType {
  message,
  booking,
  payment,
  reminder,
  promotional,
  rating,
  health,
  follow,
}
