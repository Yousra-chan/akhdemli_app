// models/notification_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum NotificationType {
  message,
  system,
  reminder,
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final String? chatId;
  final String? senderId;
  final String? senderName;
  final String actionText;
  final bool isRead;
  final DateTime time;
  final int messageCount;
  final DateTime lastMessageTime;

  NotificationItem({
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
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final time = data['time'] is Timestamp 
        ? (data['time'] as Timestamp).toDate() 
        : (data['timestamp'] is Timestamp 
            ? (data['timestamp'] as Timestamp).toDate() 
            : DateTime.now());

    return NotificationItem(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? (data['body'] ?? ''),
      type: _parseNotificationType(data['type']),
      chatId: data['chatId'],
      senderId: data['senderId'],
      senderName: data['senderName'],
      actionText: data['actionText'] ?? '',
      isRead: data['read'] ?? (data['isRead'] ?? false),
      time: time,
      messageCount: (data['messageCount'] as num?)?.toInt() ?? 1,
      lastMessageTime: data['lastMessageTime'] is Timestamp
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : time,
    );
  }

  static NotificationType _parseNotificationType(String? type) {
    switch (type) {
      case 'NotificationType.message':
      case 'message':
        return NotificationType.message;
      case 'NotificationType.system':
      case 'system':
        return NotificationType.system;
      case 'NotificationType.reminder':
      case 'reminder':
        return NotificationType.reminder;
      default:
        return NotificationType.system;
    }
  }

  String get formattedTitle {
    if (type == NotificationType.message && messageCount > 1) {
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

  IconData get icon {
    switch (type) {
      case NotificationType.message:
        return Icons.message;
      case NotificationType.system:
        return Icons.notifications;
      case NotificationType.reminder:
        return Icons.access_time;
      default:
        return Icons.notifications;
    }
  }

  Color get iconColor {
    switch (type) {
      case NotificationType.message:
        return Colors.blue;
      case NotificationType.system:
        return Colors.green;
      case NotificationType.reminder:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
