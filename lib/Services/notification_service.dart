import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:service_app/providers/language_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static LanguageProvider? _languageProvider;
  late FirebaseMessaging _firebaseMessaging;
  late FlutterLocalNotificationsPlugin _localNotifications;

  static const String _renderServerUrl = 'https://notifications-f7n2.onrender.com';
  bool _initialized = false;
  String? _currentUserId;
  String? _currentUserName;

  static Function(Map<String, dynamic>)? onNotificationTap;

  static void setLanguageProvider(LanguageProvider provider) {
    _languageProvider = provider;
  }

  static Future<void> initialize() async {
    await _instance._initialize();
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    try {
      _firebaseMessaging = FirebaseMessaging.instance;
      _localNotifications = FlutterLocalNotificationsPlugin();

      await _firebaseMessaging.requestPermission(alert: true, badge: true, sound: true);

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _localNotifications.initialize(
        const InitializationSettings(android: androidSettings),
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null && onNotificationTap != null) {
            onNotificationTap!(json.decode(details.payload!));
          }
        },
      );

      FirebaseMessaging.onMessage.listen((msg) => _showLocalNotification(msg));
      FirebaseMessaging.onMessageOpenedApp.listen((msg) => onNotificationTap?.call(msg.data));

      _initialized = true;
    } catch (e) {
      debugPrint('❌ Notification Init Error: $e');
    }
  }

  Future<void> registerUser({required String userId, required String userName}) async {
    _currentUserId = userId;
    _currentUserName = userName;
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ FCM token saved to Firestore');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: json.encode(message.data),
    );
  }

  // --- Send Message Notification ---
  Future<bool> sendMessageNotification({
    required String receiverUserId,
    required String messageText,
    required String chatId,
    String? senderId,
    String? senderName,
  }) async {
    try {
      final sId = senderId ?? _currentUserId;
      final name = senderName ?? _currentUserName ?? 'Someone';
      final title = _languageProvider?.trParams('new_message_from', category: 'disscussion', params: {'name': name}) ?? 'New message from $name';

      // 1. Push via Render
      await _sendPush(receiverUserId, title, messageText, {
        'type': 'message',
        'chatId': chatId,
        'senderId': sId,
        'senderName': name,
      });

      // 2. Save to DB
      await _saveToFirestore(
        receiverUserId: receiverUserId,
        senderId: sId,
        senderName: name,
        title: title,
        body: messageText,
        type: 'message',
        data: {'chatId': chatId, 'senderId': sId, 'senderName': name},
      );

      return true;
    } catch (e) {
      debugPrint('❌ Message Notification Error: $e');
      return false;
    }
  }

  // --- Send Booking Notification ---
  Future<bool> sendBookingNotification({
    required String receiverUserId,
    required String bookingId,
    required String title,
    required String body,
    String? senderId,
    String? senderName,
    String? status,
  }) async {
    try {
      final sId = senderId ?? _currentUserId;
      final sName = senderName ?? _currentUserName;

      // 1. Push via Render
      await _sendPush(receiverUserId, title, body, {
        'type': 'booking',
        'bookingId': bookingId,
        'bookingStatus': status ?? 'pending',
      });

      // 2. Save to DB
      await _saveToFirestore(
        receiverUserId: receiverUserId,
        senderId: sId,
        senderName: sName,
        title: title,
        body: body,
        type: 'booking',
        data: {
          'bookingId': bookingId,
          'bookingStatus': status ?? 'pending',
          'senderId': sId,
          'senderName': sName,
        },
      );

      return true;
    } catch (e) {
      debugPrint('❌ Booking Notification Error: $e');
      return false;
    }
  }

  // --- Private Helpers ---
  Future<void> _sendPush(String receiverId, String title, String body, Map<String, dynamic> data) async {
    try {
      final senderId = data['senderId'] ?? _currentUserId;
      
      final response = await http.post(
        Uri.parse('$_renderServerUrl/send-notification'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'senderId': senderId,
          'receiverId': receiverId,
          'message': body,
          'title': title,
          ...data,
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        debugPrint('✅ Push Notification sent via Render: $receiverId');
      } else {
        debugPrint('⚠️ Push Notification failed (Status: ${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('⚠️ Push helper error: $e');
    }
  }

  Future<void> _saveToFirestore({
    required String receiverUserId,
    String? senderId,
    String? senderName,
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'receiverId': receiverUserId,
      'senderId': senderId ?? _currentUserId,
      'senderName': senderName ?? _currentUserName,
      'title': title,
      'body': body,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'lastMessageTime': FieldValue.serverTimestamp(),
      ...data,
    });
  }
}
