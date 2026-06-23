import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

      // 1. Request Permissions (Android 13+ and iOS)
      // For Android 13+, we use permission_handler for a more reliable prompt
      if (await _requestNotificationPermission()) {
        debugPrint('✅ Notification permission granted');
      } else {
        debugPrint('⚠️ Notification permission denied');
      }

      // FCM internal permission request (mostly for iOS/macOS)
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true,
      );

      // 2. Set foreground presentation options (Crucial for iOS banners)
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Initialize Local Notifications
      const androidSettings = AndroidInitializationSettings('ic_notification');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      );
      
      await _localNotifications.initialize(
        const InitializationSettings(android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null && onNotificationTap != null) {
            try {
              final data = json.decode(details.payload!);
              onNotificationTap!(data);
            } catch (e) {
              debugPrint('❌ Local Notification Tap Error: $e');
            }
          }
        },
      );

      // 4. Create "Heads-up" Android Notification Channel
      // This is what allows notifications to "pop up" as banners
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important real-time notifications.',
        importance: Importance.max, // MAX is required for heads-up banners
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 5. Setup Listeners
      // Foreground
      FirebaseMessaging.onMessage.listen((msg) {
        debugPrint('📩 Foreground Message: ${msg.messageId}');
        _showLocalNotification(msg);
      });

      // Background Tap
      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        debugPrint('🎯 Notification Tapped (App in background): ${msg.data}');
        onNotificationTap?.call(msg.data);
      });

      _initialized = true;
      debugPrint('✅ NotificationService initialized with Heads-up support');
    } catch (e) {
      debugPrint('❌ Notification Init Error: $e');
    }
  }

  Future<bool> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Handles the message that launched the app from a terminated state
  Future<void> handleInitialMessage() async {
    try {
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🎯 Initial Message Found: ${initialMessage.data}');
        // Delay slightly to ensure navigator is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          onNotificationTap?.call(initialMessage.data);
        });
      }
    } catch (e) {
      debugPrint('❌ Error handling initial message: $e');
    }
  }

  Future<void> registerUser({required String userId, required String userName}) async {
    _currentUserId = userId;
    _currentUserName = userName;
    
    // Save current token
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _updateTokenInFirestore(userId, token);
    }

    // Listen for token refreshes
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _updateTokenInFirestore(userId, newToken);
    });
  }

  Future<void> _updateTokenInFirestore(String userId, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ FCM token updated in Firestore for user $userId');
    } catch (e) {
      debugPrint('❌ Failed to update FCM token: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    // For "Heads-up" we prioritize the notification object if it exists
    final title = notification?.title ?? message.data['title'] ?? 'New Message';
    final body = notification?.body ?? message.data['body'] ?? '';

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.message,
          icon: 'ic_notification',
          playSound: true,
          enableVibration: true,
          fullScreenIntent: false, // Set to true only for calls
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
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

      // 1. Push via Render (The server will handle saving to Firestore history)
      await _sendPush(receiverUserId, title, messageText, {
        'type': 'message',
        'chatId': chatId,
        'senderId': sId,
        'senderName': name,
      });

      // 🛑 REMOVED: _saveToFirestore here. 
      // It was causing duplicates because the Render server also saves to Firestore.
      
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

      // 1. Push via Render (The server will handle saving to Firestore history)
      await _sendPush(receiverUserId, title, body, {
        'type': 'booking',
        'bookingId': bookingId,
        'bookingStatus': status ?? 'pending',
        'senderId': sId,
        'senderName': sName,
      });

      // 🛑 REMOVED: _saveToFirestore here.
      // It was causing duplicates because the Render server also saves to Firestore.

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
