import 'dart:async';
import 'dart:convert';
import 'dart:typed_data'; // ✅ FIXED: Added missing import for Int64List
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_app/Services/http_polling_service.dart';

/// Notification Service Complet
/// Ce service gère:
/// 1. Les notifications FCM (Firebase Cloud Messaging)
/// 2. Les notifications locales
/// 3. La communication avec votre serveur Render
class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  // Firebase
  late FirebaseMessaging _firebaseMessaging;
  late FlutterLocalNotificationsPlugin _localNotifications;

  // Services
  final HttpPollingService _httpPollingService = HttpPollingService();

  // Stream controllers
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<String> _notificationController =
      StreamController<String>.broadcast();

  // State
  bool _initialized = false;
  String? _currentUserId;
  String? _currentUserName;

  /// Constructor privé
  NotificationService._internal();

  /// ==========================================================================
  /// INITIALIZATION
  /// ==========================================================================

  /// Initialize the notification service
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

      // 3. Initialize local notifications
      await _initializeLocalNotifications();

      // 4. Setup Android channel
      await _setupAndroidChannel();

      // 5. Request permissions
      await _requestPermissions();

      // 6. Configure message handlers
      await _configureMessageHandlers();

      // 7. Setup HTTP polling listener
      _setupHttpPollingListener();

      _initialized = true;
      print('✅ NotificationService initialized successfully');
    } catch (e, stackTrace) {
      print('❌ NotificationService init error: $e');
      print('Stack trace: $stackTrace');
      _initialized = false;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse notificationResponse) {
          // Quand l'utilisateur clique sur une notification
          print('👆 Notification clicked: ${notificationResponse.payload}');

          if (notificationResponse.payload != null) {
            try {
              final data = json.decode(notificationResponse.payload!)
                  as Map<String, dynamic>;
              _handleNotificationClick(data);
            } catch (e) {
              print('❌ Error parsing notification payload: $e');
            }
          }
        },
      );

      print('✅ Local notifications initialized');
    } catch (e) {
      print('❌ Error initializing local notifications: $e');
    }
  }

  Future<void> _setupAndroidChannel() async {
    try {
      // ✅ FIXED: Removed 'const' because vibrationPattern uses non-const Int64List.fromList()
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 1000, 500]),
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      print('✅ Android notification channel created');
    } catch (e) {
      print('❌ Error creating Android notification channel: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('🔔 Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Notifications authorized');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print('⚠️ Notifications provisionally authorized');
      } else {
        print('❌ Notifications not authorized');
      }
    } catch (e) {
      print('❌ Permission request error: $e');
    }
  }

  Future<void> _configureMessageHandlers() async {
    try {
      // 1. Message reçu quand l'app est au premier plan (ouverte)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📨 [FOREGROUND] Message received');
        print('📨 Data: ${message.data}');
        print(
            '📨 Notification: ${message.notification?.title} - ${message.notification?.body}');

        _handleIncomingMessage(message, fromBackground: false);
      });

      // 2. App ouverte depuis une notification (quand app était en background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('👆 [OPENED FROM BACKGROUND] App opened from notification');
        print('📨 Data: ${message.data}');

        _handleIncomingMessage(message, fromBackground: true);
        _handleNotificationClick(message.data);
      });

      // 3. Configurer le token refresh
      _firebaseMessaging.onTokenRefresh.listen((String newToken) {
        print('🔄 FCM token refreshed: ${newToken.substring(0, 30)}...');
        _onTokenRefresh(newToken);
      });

      print('✅ Firebase message handlers configured');
    } catch (e) {
      print('❌ Error configuring message handlers: $e');
    }
  }

  void _setupHttpPollingListener() {
    // Écouter les messages du HTTP Polling
    _httpPollingService.onMessage.listen((Map<String, dynamic> message) {
      print('📡 [HTTP POLLING] Message received: ${message['message']}');

      // ✅ NEW: Save to Firestore so it appears in notifications page
      _saveReceivedMessageNotificationToFirestore(message);

      // Créer un RemoteMessage factice pour utiliser les mêmes handlers
      final remoteMessage = RemoteMessage(
        data: Map<String, String>.from(message),
        notification: RemoteNotification(
          title: message['senderName']?.toString() ?? 'Nouveau message',
          body: message['message']?.toString() ?? '',
        ),
      );

      _handleIncomingMessage(remoteMessage, fromBackground: false);
    });

    // Écouter les erreurs du HTTP Polling
    _httpPollingService.onError.listen((String error) {
      print('❌ [HTTP POLLING ERROR] $error');
      _notificationController.add('HTTP Polling Error: $error');
    });
  }

  /// ✅ NEW: Save received notification to Firestore for notifications page
  Future<void> _saveReceivedMessageNotificationToFirestore(
      Map<String, dynamic> messageData) async {
    try {
      if (_currentUserId == null) return;

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': _currentUserId, // Current user (receiver)
        'senderId': messageData['senderId'],
        'senderName': messageData['senderName'] ?? 'Unknown',
        'message': messageData['message'],
        'title': '${messageData['senderName'] ?? "Unknown"} sent a message',
        'type': 'message',
        'chatId': messageData['chatId'],
        'time': Timestamp.now(),
        'isRead': false,
        'messageCount': 1,
        'lastMessageTime': Timestamp.now(),
      });

      print('✅ Received notification saved to Firestore');
    } catch (e) {
      print('⚠️ Error saving received notification: $e');
    }
  }

  /// ==========================================================================
  /// MESSAGE HANDLING
  /// ==========================================================================

  Future<void> _handleIncomingMessage(
    RemoteMessage message, {
    required bool fromBackground,
  }) async {
    try {
      final data = message.data;
      final notification = message.notification;

      print('📨 Handling incoming message');
      print('📨 Type: ${data['type']}');
      print('📨 From background: $fromBackground');

      // Émettre sur le stream pour que d'autres parties de l'app puissent réagir
      _messageController.add(data);
      _notificationController.add('New message received');

      // Afficher une notification locale
      await _showLocalNotification(message);

      // Si c'est un message de chat, mettre à jour Firestore
      if (data['type'] == 'message') {
        await _updateMessageStatus(data);
      }

      // Si c'est une notification système
      if (data['type'] == 'system') {
        print('🔔 System notification: ${data['message']}');
      }

      // Si c'est une notification de test
      if (data['type'] == 'test') {
        print('🧪 Test notification received');
      }
    } catch (e, stackTrace) {
      print('❌ Error handling incoming message: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final data = message.data;
      final notification = message.notification;

      // Convertir data en JSON string pour le payload
      final payload = json.encode(data);

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await _localNotifications.show(
        notification.hashCode,
        notification?.title ?? 'New Notification',
        notification?.body ?? '',
        platformChannelSpecifics,
        payload: payload,
      );

      print('✅ Local notification shown');
    } catch (e) {
      print('❌ Error showing local notification: $e');
    }
  }

  Future<void> _updateMessageStatus(Map<String, dynamic> data) async {
    try {
      final messageId = data['messageId'];
      final chatId = data['chatId'];

      if (messageId != null && chatId != null) {
        print('📝 Updating message status for $messageId');

        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId.toString())
            .set({
          'status': 'delivered',
          'deliveredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print('✅ Message status updated');
      }
    } catch (e) {
      print('⚠️ Error updating message status: $e');
    }
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    print('🎯 Notification clicked');
    print('🎯 Data: $data');

    // Extraire les informations
    final chatId = data['chatId'];
    final senderId = data['senderId'];
    final senderName = data['senderName'];
    final message = data['message'];

    print('🎯 Chat ID: $chatId');
    print('🎯 Sender: $senderName ($senderId)');
    print('🎯 Message: $message');

    // Ici vous pouvez naviguer vers le chat approprié
    // Cette logique dépend de votre architecture de navigation
    // Exemple: navigatorKey.currentState?.pushNamed('/chat', arguments: {...});

    // Émettre un événement pour que l'UI réagisse
    _notificationController.add('notification_clicked:$chatId');
  }

  void _onTokenRefresh(String newToken) {
    print('🔄 Processing token refresh');

    // Sauvegarder le nouveau token
    _saveFCMTokenToFirestore(newToken);

    // Mettre à jour sur le serveur Render
    _updateTokenOnRenderServer(newToken);
  }

  Future<void> _saveFCMTokenToFirestore(String token) async {
    try {
      if (_currentUserId == null) {
        print('⚠️ Cannot save token: no user logged in');
        return;
      }

      print('💾 Saving new FCM token to Firestore for user $_currentUserId');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ New FCM token saved to Firestore');
    } catch (e) {
      print('❌ Error saving FCM token to Firestore: $e');
    }
  }

  Future<void> _updateTokenOnRenderServer(String token) async {
    try {
      if (_currentUserId == null) {
        print('⚠️ Cannot update token on server: no user logged in');
        return;
      }

      print('📤 Updating FCM token on Render server...');

      final success = await _httpPollingService.sendFCMTokenToServer(
        userId: _currentUserId!,
        fcmToken: token,
      );

      if (success) {
        print('✅ FCM token updated on Render server');
      } else {
        print('❌ Failed to update FCM token on Render server');
      }
    } catch (e) {
      print('❌ Error updating FCM token on Render server: $e');
    }
  }

  /// ==========================================================================
  /// PUBLIC API
  /// ==========================================================================

  /// Register user with the notification system
  Future<void> registerUser({
    required String userId,
    required String userName,
  }) async {
    try {
      _currentUserId = userId;
      _currentUserName = userName;

      print('👤 Registering user $userName ($userId) for notifications');

      // 1. Get FCM token
      final token = await getFCMToken();

      if (token == null) {
        print('⚠️ No FCM token available');
        return;
      }

      print('📱 FCM Token: ${token.substring(0, 30)}...');

      // 2. Save to Firestore
      await _saveFCMTokenToFirestore(token);

      // 3. Register with HTTP polling service
      final connected = await _httpPollingService.connect(
        userId: userId,
        userName: userName,
        fcmToken: token,
      );

      if (connected) {
        // 4. Start polling for messages
        await _httpPollingService.startPolling();
        print('✅ User registered and polling started');
      } else {
        print('❌ Failed to connect to HTTP polling service');
      }
    } catch (e, stackTrace) {
      print('❌ Error registering user: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Unregister user from notifications
  Future<void> unregisterUser() async {
    try {
      print('👋 Unregistering user $_currentUserName ($_currentUserId)');

      await _httpPollingService.disconnect();

      _currentUserId = null;
      _currentUserName = null;

      print('✅ User unregistered from notifications');
    } catch (e) {
      print('❌ Error unregistering user: $e');
    }
  }

  /// Get FCM token
  Future<String?> getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      return token;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Send a test notification
  Future<void> sendTestNotification() async {
    try {
      print('🧪 Sending test notification...');

      final token = await getFCMToken();
      if (token == null) {
        print('❌ Cannot send test: no FCM token');
        return;
      }

      // Créer un message de test
      final testMessage = RemoteMessage(
        data: {
          'type': 'test',
          'testId': DateTime.now().millisecondsSinceEpoch.toString(),
          'message': 'This is a test notification',
          'timestamp': DateTime.now().toIso8601String(),
        },
        notification: RemoteNotification(
          title: 'Test Notification',
          body: 'This is a test notification from your app',
        ),
      );

      await _showLocalNotification(testMessage);
      print('✅ Test notification sent');
    } catch (e) {
      print('❌ Error sending test notification: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      print('🗑️ All notifications cleared');
    } catch (e) {
      print('❌ Error clearing notifications: $e');
    }
  }

  /// ==========================================================================
  /// STREAMS
  /// ==========================================================================

  /// Stream for incoming messages
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  /// Stream for notification events
  Stream<String> get onNotification => _notificationController.stream;

  /// ==========================================================================
  /// GETTERS
  /// ==========================================================================

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Get current user ID
  String? get currentUserId => _currentUserId;

  /// Get current user name
  String? get currentUserName => _currentUserName;

  /// Get HTTP polling service instance
  HttpPollingService get httpPollingService => _httpPollingService;

  /// ==========================================================================
  /// CLEANUP
  /// ==========================================================================

  /// Dispose all resources
  void dispose() {
    _messageController.close();
    _notificationController.close();
    _httpPollingService.dispose();
    print('♻️ NotificationService disposed');
  }
}
