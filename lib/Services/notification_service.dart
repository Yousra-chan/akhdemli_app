import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ✅ Notification Service using YOUR Render FCM Server
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  late FirebaseMessaging _firebaseMessaging;
  late FlutterLocalNotificationsPlugin _localNotifications;

  // 🔥 YOUR RENDER SERVER URL
  static const String _renderServerUrl =
      'https://your-server-name.onrender.com';

  bool _initialized = false;
  String? _currentUserId;
  String? _currentUserName;

  NotificationService._internal();

  /// ==========================================================================
  /// INITIALIZATION
  /// ==========================================================================

  static Future<void> initialize() async {
    await _instance._initialize();
  }

  Future<void> _initialize() async {
    if (_initialized) return;

    try {
      print('🔔 Initializing NotificationService...');

      // 1. Firebase Messaging
      _firebaseMessaging = FirebaseMessaging.instance;

      // 2. Local Notifications
      _localNotifications = FlutterLocalNotificationsPlugin();

      // 3. Request permissions
      await _requestPermissions();

      // 4. Initialize local notifications
      await _initializeLocalNotifications();

      // 5. Setup message handlers
      await _configureMessageHandlers();

      _initialized = true;
      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ NotificationService init error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('📱 Notification permission: ${settings.authorizationStatus}');
    } catch (e) {
      print('❌ Permission error: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings settings =
          InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          print('👆 Notification tapped: ${response.payload}');
          if (response.payload != null) {
            try {
              final data =
                  json.decode(response.payload!) as Map<String, dynamic>;
              _handleNotificationTap(data);
            } catch (e) {
              print('❌ Error parsing payload: $e');
            }
          }
        },
      );

      // Create notification channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Important notifications',
        importance: Importance.high,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      print('✅ Local notifications initialized');
    } catch (e) {
      print('❌ Local notifications error: $e');
    }
  }

  Future<void> _configureMessageHandlers() async {
    try {
      // Foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📨 [FOREGROUND] Message received');
        _showLocalNotification(message);
      });

      // Background/terminated messages
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('👆 App opened from notification');
        _handleNotificationTap(message.data);
      });

      // Token refresh
      _firebaseMessaging.onTokenRefresh.listen((String newToken) {
        print('🔄 FCM token refreshed');
        if (_currentUserId != null) {
          _saveFCMTokenToFirestore(newToken);
        }
      });

      print('✅ Message handlers configured');
    } catch (e) {
      print('❌ Message handlers error: $e');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    print('🎯 Notification tapped: $data');
    final chatId = data['chatId'];
    final senderId = data['senderId'];

    if (chatId != null) {
      // Navigate to chat screen
      // You can use a stream or method channel here
      print('📍 Navigate to chat: $chatId from $senderId');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'Important notifications',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );

      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        message.hashCode,
        notification.title ?? 'New Message',
        notification.body ?? '',
        platformDetails,
        payload: json.encode(message.data),
      );

      print('✅ Local notification shown');
    } catch (e) {
      print('❌ Local notification error: $e');
    }
  }

  /// ==========================================================================
  /// 🔥 RENDER SERVER COMMUNICATION
  /// ==========================================================================

  /// Send notification via YOUR Render server
  Future<bool> sendNotificationViaRenderServer({
    required String receiverToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      print(
          '📤 Sending via Render server to: ${receiverToken.substring(0, 30)}...');

      final response = await http.post(
        Uri.parse('$_renderServerUrl/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': receiverToken,
          'title': title,
          'body': body,
          'data': data ?? {},
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Notification sent via Render server');
        return true;
      } else {
        print('❌ Render server error: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Render server connection error: $e');
      return false;
    }
  }

  /// Send message notification to specific user
  Future<bool> sendMessageNotification({
    required String receiverUserId,
    required String messageText,
    required String chatId,
    String? senderName,
  }) async {
    try {
      print('📤 Sending message notification to user: $receiverUserId');

      // 1. Get receiver's FCM token from Firestore
      final receiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverUserId)
          .get();

      if (!receiverDoc.exists) {
        print('❌ Receiver not found');
        return false;
      }

      final receiverData = receiverDoc.data();
      final receiverToken = receiverData?['fcmToken'] as String?;

      if (receiverToken == null) {
        print('❌ Receiver has no FCM token');
        return false;
      }

      // 2. Use current user info if senderName not provided
      String finalSenderName = senderName ?? _currentUserName ?? 'Someone';

      // 3. Send via Render server
      final success = await sendNotificationViaRenderServer(
        receiverToken: receiverToken,
        title: 'New message from $finalSenderName',
        body: messageText.length > 100
            ? '${messageText.substring(0, 100)}...'
            : messageText,
        data: {
          'type': 'message',
          'chatId': chatId,
          'senderId': _currentUserId,
          'senderName': finalSenderName,
          'message': messageText,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (success) {
        // 4. Save notification to Firestore for history
        await _saveNotificationToFirestore(
          receiverUserId: receiverUserId,
          type: 'message',
          title: 'New message from $finalSenderName',
          body: messageText,
          data: {
            'chatId': chatId,
            'senderId': _currentUserId,
          },
        );
      }

      return success;
    } catch (e) {
      print('❌ Error sending message notification: $e');
      return false;
    }
  }

  /// Send booking notification
  Future<bool> sendBookingNotification({
    required String receiverUserId,
    required String bookingId,
    required String serviceName,
    required String status, // confirmed, cancelled, reminder
    DateTime? date,
  }) async {
    try {
      // Get receiver's token
      final receiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverUserId)
          .get();

      final receiverToken = receiverDoc.data()?['fcmToken'] as String?;
      if (receiverToken == null) return false;

      // Determine message based on status
      String title, body;
      switch (status) {
        case 'confirmed':
          title = 'Booking Confirmed!';
          body = 'Your booking for $serviceName has been confirmed';
          break;
        case 'cancelled':
          title = 'Booking Cancelled';
          body = 'Your booking for $serviceName has been cancelled';
          break;
        case 'reminder':
          title = 'Booking Reminder';
          body = 'Reminder: Your $serviceName is tomorrow';
          break;
        default:
          title = 'Booking Update';
          body = 'Update for your $serviceName booking';
      }

      // Send via Render server
      return await sendNotificationViaRenderServer(
        receiverToken: receiverToken,
        title: title,
        body: body,
        data: {
          'type': 'booking',
          'bookingId': bookingId,
          'serviceName': serviceName,
          'status': status,
          'date': date?.toIso8601String(),
        },
      );
    } catch (e) {
      print('❌ Booking notification error: $e');
      return false;
    }
  }

  /// ==========================================================================
  /// PUBLIC API
  /// ==========================================================================

  /// Register user with notification system
  Future<void> registerUser({
    required String userId,
    required String userName,
  }) async {
    try {
      _currentUserId = userId;
      _currentUserName = userName;

      print('👤 Registering user $userName ($userId)');

      // Get and save FCM token
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('📱 FCM Token obtained');
        await _saveFCMTokenToFirestore(token);

        // Optional: Register token with Render server
        await _registerTokenWithRenderServer(userId, token);
      }

      print('✅ User registered for notifications');
    } catch (e) {
      print('❌ User registration error: $e');
    }
  }

  /// Get FCM token
  Future<String?> getFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('❌ Get token error: $e');
      return null;
    }
  }

  /// ==========================================================================
  /// PRIVATE HELPERS
  /// ==========================================================================

  Future<void> _saveFCMTokenToFirestore(String token) async {
    try {
      if (_currentUserId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ FCM token saved to Firestore');
    } catch (e) {
      print('❌ Token save error: $e');
    }
  }

  Future<void> _registerTokenWithRenderServer(
      String userId, String token) async {
    try {
      // Optional: Send token to your Render server for registration
      final response = await http.post(
        Uri.parse('$_renderServerUrl/register-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'token': token,
          'userName': _currentUserName,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Token registered with Render server');
      }
    } catch (e) {
      print('⚠️ Render server registration error: $e');
    }
  }

  Future<void> _saveNotificationToFirestore({
    required String receiverUserId,
    required String type,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': receiverUserId,
        'senderId': _currentUserId,
        'senderName': _currentUserName,
        'type': type,
        'title': title,
        'body': body,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('⚠️ Save notification error: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      print('🗑️ All notifications cleared');
    } catch (e) {
      print('❌ Clear notifications error: $e');
    }
  }

  /// Test notification
  Future<void> sendTestNotification() async {
    try {
      final token = await getFCMToken();
      if (token == null) return;

      await sendNotificationViaRenderServer(
        receiverToken: token,
        title: 'Test Notification',
        body: 'Your notifications are working! 🎉',
        data: {'type': 'test'},
      );
    } catch (e) {
      print('❌ Test notification error: $e');
    }
  }
}
