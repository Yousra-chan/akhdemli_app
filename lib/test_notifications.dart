import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../main.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static String? _currentUserId;
  static bool _isInitialized = false;

  // Garde en mémoire les derniers messages traités
  static final Map<String, DateTime> _processedMessages = {};

  // ============================
  // INITIALISATION
  // ============================

  static Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🔔 Initializing NotificationService...');

    try {
      await _requestPermissions();
      await _initializeLocalNotifications();
      await _configureFCM();
      _setupAuthListener();

      _isInitialized = true;
      debugPrint('✅ NotificationService initialized');
    } catch (e) {
      debugPrint('❌ NotificationService init error: $e');
    }
  }

  static Future<void> handleInitialMessage() async {
    try {
      final RemoteMessage? message =
          await _firebaseMessaging.getInitialMessage();
      if (message != null) {
        debugPrint('📱 App opened by notification');
        _handleNavigation(message.data);
      }
    } catch (e) {
      debugPrint('❌ handleInitialMessage error: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    try {
      await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        sound: true,
      );
    } catch (e) {
      debugPrint('⚠️ Permission request error: $e');
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null) {
            try {
              final data =
                  json.decode(details.payload!) as Map<String, dynamic>;
              _handleNavigation(data);
            } catch (e) {
              debugPrint('❌ Notification tap error: $e');
            }
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Local notifications init error: $e');
    }
  }

  static Future<void> _configureFCM() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('✅ FCM Token: ${token.substring(0, 30)}...');
        _saveFCMToken(token);
      }

      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM token refreshed');
        _saveFCMToken(newToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📨 Foreground FCM: ${message.notification?.title}');
        _handleForegroundMessage(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('📱 App opened from background by notification');
        _handleNavigation(message.data);
      });

      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('⚠️ FCM config error: $e');
    }
  }

  static void _setupAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _currentUserId = user.uid;
        debugPrint('👤 User logged in: ${user.uid}');

        // Démarrer l'écoute des messages
        _startMessageListener(user.uid);

        _firebaseMessaging.getToken().then((token) {
          if (token != null) _saveFCMToken(token);
        });
      } else {
        debugPrint('👤 User logged out');
        _currentUserId = null;
        _stopMessageListener();
      }
    });
  }

  // ============================
  // ÉCOUTE DES MESSAGES - SOLUTION DÉFINITIVE
  // ============================

  static StreamSubscription<QuerySnapshot>? _messageListener;

  static void _startMessageListener(String userId) {
    _stopMessageListener();

    debugPrint('👂 Starting message listener for user: $userId');

    _messageListener = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen((snapshot) {
      debugPrint('📊 Chats updated: ${snapshot.docChanges.length} changes');

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final chatId = change.doc.id;
          final chatData = change.doc.data() as Map<String, dynamic>;

          // Vérifier si c'est un nouveau message
          _processChatUpdate(chatId, chatData, userId);
        }
      }
    }, onError: (error) {
      debugPrint('❌ Message listener error: $error');
    });
  }

  static void _stopMessageListener() {
    if (_messageListener != null) {
      _messageListener!.cancel();
      _messageListener = null;
    }
    debugPrint('🔇 Message listener stopped');
  }

  static Future<void> _processChatUpdate(
      String chatId, Map<String, dynamic> chatData, String userId) async {
    try {
      debugPrint('\n🔍 PROCESSING CHAT UPDATE:');
      debugPrint('  Chat ID: $chatId');
      debugPrint('  Current User ID: $userId');

      final lastMessageSender = chatData['lastMessageSender'] as String?;
      final lastMessage = chatData['lastMessage'] as String?;
      final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;

      debugPrint('  Last Message Sender: $lastMessageSender');
      debugPrint('  Last Message: $lastMessage');

      // CRITIQUE: Vérifier si le message vient de l'utilisateur courant
      if (lastMessageSender == null ||
          lastMessage == null ||
          lastMessageTime == null) {
        debugPrint('⚠️ Missing message data');
        return;
      }

      // Éviter les doublons - créer une clé unique
      final messageKey = '$chatId-${lastMessageTime.millisecondsSinceEpoch}';

      if (_processedMessages.containsKey(messageKey)) {
        debugPrint('⏭️ Already processed this message: $messageKey');
        return;
      }

      // Marquer comme traité (expire après 30 secondes)
      _processedMessages[messageKey] = DateTime.now();

      // Nettoyer les anciennes entrées
      final now = DateTime.now();
      _processedMessages.removeWhere((key, time) {
        return now.difference(time).inSeconds > 30;
      });

      // LA CONDITION CRITIQUE
      if (lastMessageSender == userId) {
        debugPrint('🚫 BLOCKED: Message from current user ($userId)');
        debugPrint('  Sender ID: $lastMessageSender');
        debugPrint('  Current User ID: $userId');
        debugPrint('  They are EQUAL - NO NOTIFICATION');
        return;
      }

      debugPrint('✅ APPROVED: Message from other user');

      // Vérifier que l'utilisateur courant est bien le receiver
      final participants =
          (chatData['participants'] as List<dynamic>?)?.cast<String>() ?? [];
      final participantNames =
          (chatData['participantNames'] as Map<String, dynamic>?)
                  ?.cast<String, String>() ??
              {};

      // Trouver qui est le receiver (celui qui n'est pas le sender)
      String? receiverId;
      for (var participantId in participants) {
        if (participantId != lastMessageSender) {
          receiverId = participantId;
          break;
        }
      }

      if (receiverId != userId) {
        debugPrint('⚠️ Message not for current user');
        debugPrint('  Receiver should be: $receiverId');
        debugPrint('  Current user is: $userId');
        return;
      }

      debugPrint('✅ CONFIRMED: Message is for current user');

      // Créer la notification
      await _createNotification(
        chatId: chatId,
        chatData: chatData,
        senderId: lastMessageSender!,
        receiverId: userId,
        message: lastMessage!,
        messageTime: lastMessageTime!,
      );
    } catch (e) {
      debugPrint('❌ Error processing chat update: $e');
    }
  }

  static Future<void> _createNotification({
    required String chatId,
    required Map<String, dynamic> chatData,
    required String senderId,
    required String receiverId,
    required String message,
    required Timestamp messageTime,
  }) async {
    try {
      debugPrint('🎯 CREATING NOTIFICATION:');
      debugPrint('  Chat: $chatId');
      debugPrint('  Sender: $senderId');
      debugPrint('  Receiver: $receiverId');

      final participantNames =
          (chatData['participantNames'] as Map<String, dynamic>?)
                  ?.cast<String, String>() ??
              {};
      final senderName = participantNames[senderId] ?? 'Someone';

      // Vérifier notification existante
      final notificationId = '${receiverId}_$chatId';
      final existingDoc = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .get();

      int messageCount = 1;
      if (existingDoc.exists) {
        final existingData = existingDoc.data();
        messageCount = (existingData?['messageCount'] as int? ?? 0) + 1;
        debugPrint('  Updating existing notification. Count: $messageCount');
      } else {
        debugPrint('  Creating new notification');
      }

      // Préparer données
      final notificationData = {
        'userId': receiverId,
        'type': 'message',
        'title': messageCount > 1
            ? 'New messages from $senderName ($messageCount)'
            : 'New message from $senderName',
        'message':
            message.length > 100 ? '${message.substring(0, 100)}...' : message,
        'chatId': chatId,
        'senderId': senderId,
        'senderName': senderName,
        'time': FieldValue.serverTimestamp(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'isRead': false,
        'messageCount': messageCount,
        'actionText': 'Reply',
      };

      // Sauvegarder
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .set(notificationData, SetOptions(merge: true));

      debugPrint('✅ Notification saved: $notificationId');

      // Afficher notification locale
      await showLocalNotification(
        title: messageCount > 1
            ? '$senderName ($messageCount new messages)'
            : 'New message from $senderName',
        body:
            message.length > 100 ? '${message.substring(0, 100)}...' : message,
        payload: json.encode({
          ...notificationData,
          'notificationId': notificationId,
        }),
      );

      // Mettre à jour compteur
      await _updateUnreadCount(receiverId, 1);
    } catch (e) {
      debugPrint('❌ Error creating notification: $e');
    }
  }

  // ============================
  // AFFICHAGE NOTIFICATIONS
  // ============================

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      debugPrint('🔔 SHOWING LOCAL NOTIFICATION: $title');

      final androidDetails = AndroidNotificationDetails(
        'service_app_channel',
        'Service App Notifications',
        channelDescription: 'Important notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        color: Colors.blue,
        styleInformation: BigTextStyleInformation(body),
      );

      final details = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('✅ Notification displayed');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;

    // Bloquer si sender est utilisateur courant
    if (_currentUserId != null && data['senderId'] == _currentUserId) {
      debugPrint('🚫 BLOCKED FCM: Message from current user');
      return;
    }

    await showLocalNotification(
      title: message.notification?.title ?? data['title'] ?? 'New Message',
      body: message.notification?.body ?? data['message'] ?? '',
      payload: json.encode(data),
    );
  }

  // ============================
  // AUTRES MÉTHODES
  // ============================

  static Future<void> _saveFCMToken(String token) async {
    if (_currentUserId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId!)
          .set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  static Future<void> _updateUnreadCount(String userId, int increment) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'unreadCount': FieldValue.increment(increment),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Could not update unread count: $e');
    }
  }

  static void _handleNavigation(Map<String, dynamic> data) {
    final type = data['type'];
    final chatId = data['chatId'];

    if (type == 'message' && chatId != null) {
      _navigateToChat(chatId as String);
    }
  }

  static void _navigateToChat(String chatId) {
    if (navigatorKey.currentState == null) return;
    navigatorKey.currentState?.pushNamed('/chat', arguments: chatId);
  }

  static Future<void> markAsRead(String notificationId) async {
    if (_currentUserId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });

      await _updateUnreadCount(_currentUserId!, -1);
    } catch (e) {
      debugPrint('❌ Error marking as read: $e');
    }
  }

  static Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }

  static void dispose() {
    _stopMessageListener();
    _isInitialized = false;
    debugPrint('🔔 NotificationService disposed');
  }
}
