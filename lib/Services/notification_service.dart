import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Custom exception for notification-related errors
class NotificationException implements Exception {
  final String message;
  final String? code;

  NotificationException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Notification Service using Render FCM Server
///
/// Handles:
/// - Firebase Messaging configuration
/// - Local notification display
/// - Message delivery via external server
/// - Notification persistence
/// - User registration and token management
class NotificationService {
  // Singleton instance
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  // Firebase and local notification instances
  late FirebaseMessaging _firebaseMessaging;
  late FlutterLocalNotificationsPlugin _localNotifications;

  // Configuration constants
  static const String _renderServerUrl =
      'https://notifications-f7n2.onrender.com';
  static const Duration _httpTimeout = Duration(seconds: 15);
  static const int _maxRetries = 3;

  // Firestore collection and field constants
  static const String _usersCollection = 'users';
  static const String _notificationsCollection = 'notifications';
  static const String _fcmTokenField = 'fcmToken';
  static const String _fcmTokenUpdatedAtField = 'fcmTokenUpdatedAt';
  static const String _updatedAtField = 'updatedAt';

  // Notification channel constants
  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'High Importance Notifications';
  static const String _channelDescription = 'Important notifications';

  // Notification type constants
  static const String _notificationTypeMessage = 'message';
  static const String _notificationTypeBooking = 'booking';
  static const String _notificationTypeTest = 'test';

  // Booking status constants
  static const String _statusConfirmed = 'confirmed';
  static const String _statusCancelled = 'cancelled';
  static const String _statusReminder = 'reminder';

  // State management
  bool _initialized = false;
  String? _currentUserId;
  String? _currentUserName;

  // Navigation callback - Set in main app
  static Function(Map<String, dynamic>)? onNotificationTap;

  NotificationService._internal();

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  /// Initializes the notification service
  ///
  /// Must be called before using notification features.
  /// Handles:
  /// - Firebase Messaging setup
  /// - Local notifications configuration
  /// - Permission requests
  /// - Message handler configuration
  static Future<void> initialize() async {
    await _instance._initialize();
  }

  Future<void> _initialize() async {
    if (_initialized) return;

    try {
      print('🔔 Initializing NotificationService...');

      _firebaseMessaging = FirebaseMessaging.instance;
      _localNotifications = FlutterLocalNotificationsPlugin();

      // Initialize each component
      await _requestPermissions();
      await _initializeLocalNotifications();
      await _configureMessageHandlers();

      _initialized = true;
      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ NotificationService initialization error: $e');
      rethrow;
    }
  }

  /// Requests notification permissions from user
  Future<void> _requestPermissions() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('📱 Notification permission granted: '
          '${settings.authorizationStatus.name}');
    } catch (e) {
      print('❌ Permission request error: $e');
    }
  }

  /// Initializes local notification plugin and channel
  Future<void> _initializeLocalNotifications() async {
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings settings =
          InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          _handleLocalNotificationTap(response);
        },
      );

      // Create notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      print('✅ Local notifications initialized');
    } catch (e) {
      print('❌ Local notifications initialization error: $e');
    }
  }

  /// Configures Firebase message handlers
  ///
  /// Handles:
  /// - Foreground messages
  /// - Background messages
  /// - Terminated state messages
  /// - Token refresh
  Future<void> _configureMessageHandlers() async {
    try {
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📨 Foreground message received');
        _showLocalNotification(message);
      });

      // Handle background message tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('👆 App opened from notification');
        _handleNotificationTap(message.data);
      });

      // Handle terminated state notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print('👆 App launched from notification (terminated state)');
        Future.delayed(const Duration(seconds: 1), () {
          _handleNotificationTap(initialMessage.data);
        });
      }

      // Handle token refresh
      _firebaseMessaging.onTokenRefresh.listen((String newToken) {
        print('🔄 FCM token refreshed');
        if (_currentUserId != null) {
          _saveFCMTokenToFirestore(newToken).catchError(
            (e) => print('Warning: Could not save new token: $e'),
          );
        }
      });

      print('✅ Message handlers configured');
    } catch (e) {
      print('❌ Message handlers configuration error: $e');
    }
  }

  /// Handles local notification tap
  void _handleLocalNotificationTap(NotificationResponse response) {
    try {
      if (response.payload == null || response.payload!.isEmpty) {
        return;
      }

      final data = json.decode(response.payload!) as Map<String, dynamic>;
      _handleNotificationTap(data);
    } catch (e) {
      print('❌ Error parsing notification payload: $e');
    }
  }

  /// Handles notification tap routing
  void _handleNotificationTap(Map<String, dynamic> data) {
    try {
      _validateNotificationData(data);

      final notificationType =
          data['notificationType'] ?? data['type'] ?? 'unknown';

      print('🎯 Notification tapped - Type: $notificationType');

      if (onNotificationTap != null) {
        onNotificationTap!(data);
      } else {
        print('⚠️ No navigation callback registered');
      }
    } catch (e) {
      print('❌ Error handling notification tap: $e');
    }
  }

  /// Displays local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) {
        print('⚠️ Notification has no content');
        return;
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );

      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        message.hashCode,
        notification.title ?? 'New Message',
        notification.body ?? 'You have a new notification',
        platformDetails,
        payload: json.encode(message.data),
      );

      print('✅ Local notification displayed');
    } catch (e) {
      print('❌ Error displaying local notification: $e');
    }
  }

  // ============================================================================
  // PUBLIC API - NOTIFICATION SENDING
  // ============================================================================

  /// Sends notification via Render server
  ///
  /// Parameters:
  /// - receiverToken: FCM token of recipient
  /// - title: Notification title
  /// - body: Notification message body
  /// - data: Optional data payload
  ///
  /// Returns: true if sent successfully, false otherwise
  /// Throws: NotificationException on validation failure
  Future<bool> sendNotificationViaRenderServer({
    required String receiverToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      _validateSendNotificationInputs(
        token: receiverToken,
        title: title,
        body: body,
      );

      print('📤 Sending notification via Render server...');

      final success = await _sendHttpRequestWithRetry(
        url: '$_renderServerUrl/send',
        payload: {
          'token': receiverToken,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );

      if (success) {
        print('✅ Notification sent successfully');
      } else {
        print('❌ Failed to send notification');
      }

      return success;
    } on NotificationException {
      rethrow;
    } catch (e) {
      print('❌ Error sending notification: $e');
      return false;
    }
  }

  /// Sends message notification to user
  ///
  /// Parameters:
  /// - receiverUserId: Recipient user ID
  /// - messageText: Message content
  /// - chatId: Chat/conversation ID
  /// - senderName: Optional sender name (uses current user if not provided)
  ///
  /// Returns: true if sent successfully, false otherwise
  /// Throws: NotificationException on validation failure
  Future<bool> sendMessageNotification({
    required String receiverUserId,
    required String messageText,
    required String chatId,
    String? senderName,
  }) async {
    try {
      _validateMessageNotificationInputs(
        receiverUserId: receiverUserId,
        messageText: messageText,
        chatId: chatId,
      );

      print('📤 Sending message notification to user: $receiverUserId');

      // Fetch receiver's FCM token
      final receiverToken = await _fetchUserFCMToken(receiverUserId);
      if (receiverToken == null) {
        print('⚠️ Receiver has no FCM token');
        return false;
      }

      final finalSenderName = senderName ?? _currentUserName ?? 'Someone';
      final truncatedMessage = _truncateMessage(messageText, 100);

      // Send notification
      final success = await sendNotificationViaRenderServer(
        receiverToken: receiverToken,
        title: 'New message from $finalSenderName',
        body: truncatedMessage,
        data: {
          'type': _notificationTypeMessage,
          'notificationType': _notificationTypeMessage,
          'chatId': chatId,
          'senderId': _currentUserId,
          'senderName': finalSenderName,
          'message': messageText,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Persist notification to Firestore
      if (success) {
        await _saveNotificationToFirestore(
          receiverUserId: receiverUserId,
          type: _notificationTypeMessage,
          title: 'New message from $finalSenderName',
          body: truncatedMessage,
          data: {
            'chatId': chatId,
            'senderId': _currentUserId,
          },
        ).catchError(
          (e) => print('Warning: Could not persist notification: $e'),
        );
      }

      return success;
    } on NotificationException {
      rethrow;
    } catch (e) {
      print('❌ Error sending message notification: $e');
      return false;
    }
  }

  /// Sends booking notification to user
  ///
  /// Parameters:
  /// - receiverUserId: Recipient user ID
  /// - bookingId: Booking reference ID
  /// - serviceName: Name of the service
  /// - status: Booking status (confirmed, cancelled, reminder)
  /// - date: Optional appointment date
  ///
  /// Returns: true if sent successfully, false otherwise
  /// Throws: NotificationException on validation failure
  Future<bool> sendBookingNotification({
    required String receiverUserId,
    required String bookingId,
    required String serviceName,
    required String status,
    DateTime? date,
  }) async {
    try {
      _validateBookingNotificationInputs(
        receiverUserId: receiverUserId,
        bookingId: bookingId,
        serviceName: serviceName,
        status: status,
      );

      print('📤 Sending booking notification - Status: $status');

      // Fetch receiver's FCM token
      final receiverToken = await _fetchUserFCMToken(receiverUserId);
      if (receiverToken == null) {
        print('⚠️ Receiver has no FCM token');
        return false;
      }

      // Generate message content
      final (title, body) = _getBookingMessageContent(status, serviceName);

      // Send notification
      final success = await sendNotificationViaRenderServer(
        receiverToken: receiverToken,
        title: title,
        body: body,
        data: {
          'type': _notificationTypeBooking,
          'notificationType': _notificationTypeBooking,
          'bookingId': bookingId,
          'serviceName': serviceName,
          'status': status,
          'date': date?.toIso8601String(),
        },
      );

      return success;
    } on NotificationException {
      rethrow;
    } catch (e) {
      print('❌ Error sending booking notification: $e');
      return false;
    }
  }

  // ============================================================================
  // PUBLIC API - USER MANAGEMENT
  // ============================================================================

  /// Registers user with notification system
  ///
  /// Parameters:
  /// - userId: User's unique identifier
  /// - userName: User's display name
  ///
  /// Performs:
  /// 1. Stores current user context
  /// 2. Retrieves FCM token
  /// 3. Saves token to Firestore
  /// 4. Optionally registers with Render server
  Future<void> registerUser({
    required String userId,
    required String userName,
  }) async {
    try {
      _validateUserInputs(userId: userId, userName: userName);

      print('👤 Registering user: $userName ($userId)');

      _currentUserId = userId;
      _currentUserName = userName;

      final token = await getFCMToken();
      if (token == null) {
        throw NotificationException(
          'Could not retrieve FCM token',
          code: 'fcm-token-null',
        );
      }

      // Save token to Firestore
      await _saveFCMTokenToFirestore(token);

      // Register with Render server
      await _registerTokenWithRenderServer(userId, token).catchError(
        (e) => print('Warning: Could not register with Render server: $e'),
      );

      print('✅ User registered successfully');
    } on NotificationException {
      rethrow;
    } catch (e) {
      print('❌ User registration error: $e');
      rethrow;
    }
  }

  /// Retrieves current FCM token
  ///
  /// Returns: FCM token string, or null if unavailable
  Future<String?> getFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('❌ Error retrieving FCM token: $e');
      return null;
    }
  }

  /// Clears all local notifications
  Future<void> clearAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      print('🗑️ All local notifications cleared');
    } catch (e) {
      print('❌ Error clearing notifications: $e');
    }
  }

  /// Sends test notification to verify setup
  Future<void> sendTestNotification() async {
    try {
      final token = await getFCMToken();
      if (token == null) {
        throw NotificationException(
          'Cannot send test notification without FCM token',
          code: 'no-fcm-token',
        );
      }

      final success = await sendNotificationViaRenderServer(
        receiverToken: token,
        title: 'Test Notification',
        body: 'Your notifications are working correctly! 🎉',
        data: {
          'type': _notificationTypeTest,
          'notificationType': _notificationTypeTest,
        },
      );

      if (success) {
        print('✅ Test notification sent');
      }
    } catch (e) {
      print('❌ Error sending test notification: $e');
    }
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Fetches user's FCM token from Firestore
  Future<String?> _fetchUserFCMToken(String userId) async {
    try {
      if (userId.isEmpty) {
        return null;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        print('⚠️ User not found: $userId');
        return null;
      }

      final token = userDoc.data()?[_fcmTokenField] as String?;

      if (token == null || token.isEmpty) {
        print('⚠️ FCM token not found for user: $userId');
        return null;
      }

      return token;
    } catch (e) {
      print('❌ Error fetching FCM token: $e');
      return null;
    }
  }

  /// Saves FCM token to Firestore
  Future<void> _saveFCMTokenToFirestore(String token) async {
    try {
      if (_currentUserId == null) {
        throw NotificationException(
          'Current user ID not set',
          code: 'no-current-user',
        );
      }

      if (token.isEmpty) {
        throw NotificationException(
          'FCM token cannot be empty',
          code: 'empty-token',
        );
      }

      await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(_currentUserId!)
          .set(
        {
          _fcmTokenField: token,
          _fcmTokenUpdatedAtField: FieldValue.serverTimestamp(),
          _updatedAtField: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      print('✅ FCM token saved to Firestore');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
      rethrow;
    }
  }

  /// Registers token with Render server
  Future<void> _registerTokenWithRenderServer(
      String userId, String token) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_renderServerUrl/register-token'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'userId': userId,
              'token': token,
              'userName': _currentUserName,
            }),
          )
          .timeout(_httpTimeout);

      if (response.statusCode == 200) {
        print('✅ Token registered with Render server');
      } else {
        print('⚠️ Render server registration returned: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Render server registration error: $e');
    }
  }

  /// Saves notification to Firestore for history/audit trail
  Future<void> _saveNotificationToFirestore({
    required String receiverUserId,
    required String type,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      if (receiverUserId.isEmpty || type.isEmpty) {
        throw NotificationException(
          'Invalid notification parameters',
          code: 'invalid-notification-params',
        );
      }

      await FirebaseFirestore.instance
          .collection(_notificationsCollection)
          .add({
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

      print('✅ Notification persisted to Firestore');
    } catch (e) {
      print('❌ Error saving notification: $e');
      rethrow;
    }
  }

  /// Sends HTTP request with retry logic
  Future<bool> _sendHttpRequestWithRetry({
    required String url,
    required Map<String, dynamic> payload,
  }) async {
    int attemptCount = 0;

    while (attemptCount < _maxRetries) {
      try {
        print('📡 HTTP request attempt ${attemptCount + 1}/$_maxRetries');

        final response = await http
            .post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'NotificationService/1.0',
              },
              body: json.encode(payload),
            )
            .timeout(_httpTimeout);

        if (response.statusCode == 200) {
          try {
            final result = json.decode(response.body);
            if (result['success'] == true) {
              return true;
            }
          } catch (e) {
            print('⚠️ Invalid response format: $e');
          }
        } else if (response.statusCode >= 500) {
          // Server error - retry
          print('⚠️ Server error (${response.statusCode}) - retrying...');
          attemptCount++;
          if (attemptCount < _maxRetries) {
            await Future.delayed(Duration(seconds: attemptCount));
          }
          continue;
        } else {
          // Client error - don't retry
          print('❌ Client error (${response.statusCode})');
          return false;
        }
      } on http.ClientException catch (e) {
        print('⚠️ Network error: $e - retrying...');
        attemptCount++;
        if (attemptCount < _maxRetries) {
          await Future.delayed(Duration(seconds: attemptCount));
        }
      } catch (e) {
        print('❌ Unexpected error: $e');
        return false;
      }
    }

    print('❌ Failed after $_maxRetries attempts');
    return false;
  }

  /// Generates booking notification message content
  static (String title, String body) _getBookingMessageContent(
    String status,
    String serviceName,
  ) {
    switch (status.toLowerCase()) {
      case _statusConfirmed:
        return (
          'Booking Confirmed!',
          'Your booking for $serviceName has been confirmed',
        );
      case _statusCancelled:
        return (
          'Booking Cancelled',
          'Your booking for $serviceName has been cancelled',
        );
      case _statusReminder:
        return (
          'Booking Reminder',
          'Reminder: Your $serviceName is tomorrow',
        );
      default:
        return (
          'Booking Update',
          'Update for your $serviceName booking',
        );
    }
  }

  /// Truncates message to specified length
  static String _truncateMessage(String message, int maxLength) {
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength)}...';
  }

  // ============================================================================
  // INPUT VALIDATION METHODS
  // ============================================================================

  /// Validates send notification inputs
  void _validateSendNotificationInputs({
    required String token,
    required String title,
    required String body,
  }) {
    if (token.isEmpty) {
      throw NotificationException(
        'FCM token cannot be empty',
        code: 'empty-token',
      );
    }

    if (token.length < 100) {
      throw NotificationException(
        'Invalid FCM token format',
        code: 'invalid-token',
      );
    }

    if (title.isEmpty) {
      throw NotificationException(
        'Notification title cannot be empty',
        code: 'empty-title',
      );
    }

    if (title.length > 200) {
      throw NotificationException(
        'Notification title too long (max 200 characters)',
        code: 'title-too-long',
      );
    }

    if (body.isEmpty) {
      throw NotificationException(
        'Notification body cannot be empty',
        code: 'empty-body',
      );
    }

    if (body.length > 500) {
      throw NotificationException(
        'Notification body too long (max 500 characters)',
        code: 'body-too-long',
      );
    }
  }

  /// Validates message notification inputs
  void _validateMessageNotificationInputs({
    required String receiverUserId,
    required String messageText,
    required String chatId,
  }) {
    if (receiverUserId.isEmpty) {
      throw NotificationException(
        'Receiver user ID cannot be empty',
        code: 'empty-receiver-id',
      );
    }

    if (messageText.isEmpty) {
      throw NotificationException(
        'Message text cannot be empty',
        code: 'empty-message',
      );
    }

    if (messageText.length > 2000) {
      throw NotificationException(
        'Message too long (max 2000 characters)',
        code: 'message-too-long',
      );
    }

    if (chatId.isEmpty) {
      throw NotificationException(
        'Chat ID cannot be empty',
        code: 'empty-chat-id',
      );
    }
  }

  /// Validates booking notification inputs
  void _validateBookingNotificationInputs({
    required String receiverUserId,
    required String bookingId,
    required String serviceName,
    required String status,
  }) {
    if (receiverUserId.isEmpty) {
      throw NotificationException(
        'Receiver user ID cannot be empty',
        code: 'empty-receiver-id',
      );
    }

    if (bookingId.isEmpty) {
      throw NotificationException(
        'Booking ID cannot be empty',
        code: 'empty-booking-id',
      );
    }

    if (serviceName.isEmpty) {
      throw NotificationException(
        'Service name cannot be empty',
        code: 'empty-service-name',
      );
    }

    const validStatuses = [_statusConfirmed, _statusCancelled, _statusReminder];
    if (!validStatuses.contains(status.toLowerCase())) {
      throw NotificationException(
        'Invalid booking status: $status. '
        'Must be one of: ${validStatuses.join(", ")}',
        code: 'invalid-status',
      );
    }
  }

  /// Validates user inputs
  void _validateUserInputs({
    required String userId,
    required String userName,
  }) {
    if (userId.isEmpty) {
      throw NotificationException(
        'User ID cannot be empty',
        code: 'empty-user-id',
      );
    }

    if (userName.isEmpty) {
      throw NotificationException(
        'User name cannot be empty',
        code: 'empty-user-name',
      );
    }

    if (userId.length > 200) {
      throw NotificationException(
        'User ID too long',
        code: 'user-id-too-long',
      );
    }

    if (userName.length > 200) {
      throw NotificationException(
        'User name too long',
        code: 'user-name-too-long',
      );
    }
  }

  /// Validates notification data
  void _validateNotificationData(Map<String, dynamic> data) {
    if (data.isEmpty) {
      throw NotificationException(
        'Notification data cannot be empty',
        code: 'empty-notification-data',
      );
    }
  }
}
