import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../main.dart'; // pour navigatorKey

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

  // Stream pour les notifications
  static final StreamController<Map<String, dynamic>>
      _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Public getter
  static Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;

  // Écouteurs Firestore
  static StreamSubscription<QuerySnapshot>? _firestoreListener;

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
        provisional: false,
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
      // Obtenir et sauvegarder le token FCM
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('✅ FCM Token obtained: ${token.substring(0, 30)}...');
        _saveFCMToken(token);
      } else {
        debugPrint('⚠️ No FCM token available');
      }

      // Écouter le refresh du token
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM token refreshed');
        _saveFCMToken(newToken);
      });

      // Gérer les messages foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('\n📨 [FCM] Foreground message received:');
        debugPrint('  Title: ${message.notification?.title}');
        debugPrint('  Body: ${message.notification?.body}');
        debugPrint('  Data: ${message.data}');

        // Vérifier si c'est un message "Message sent"
        if (message.notification?.title?.contains('Message sent') == true ||
            message.notification?.body?.contains('Message sent') == true) {
          debugPrint('🚫 [FCM] BLOCKED: "Message sent" notification from FCM');
          return;
        }

        _handleForegroundMessage(message);
      });

      // Gérer les ouvertures depuis background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('📱 App opened from background by notification');
        _handleNavigation(message.data);
      });

      // Options de présentation
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
        debugPrint('👤 NotificationService: User logged in - ${user.uid}');

        // Démarrer l'écoute Firestore pour les notifications en temps réel
        _startFirestoreListener(user.uid);

        // Sauvegarder le token FCM pour l'utilisateur courant
        _firebaseMessaging.getToken().then((token) {
          if (token != null) _saveFCMToken(token);
        });
      } else {
        debugPrint('👤 NotificationService: User logged out');
        _currentUserId = null;
        _cleanupListeners();
      }
    });
  }

  // ============================
  // ÉCOUTE FIRESTORE EN TEMPS RÉEL
  // ============================

  static void _startFirestoreListener(String userId) {
    _cleanupListeners();

    debugPrint('👂 Starting Firestore listener for user: $userId');

    _firestoreListener = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen((chatsSnapshot) {
      debugPrint('📊 Chats update: ${chatsSnapshot.docs.length} chats');

      for (var change in chatsSnapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final chatId = change.doc.id;
          final chatData = change.doc.data() as Map<String, dynamic>;

          // Vérifier si c'est une mise à jour de dernier message
          if (chatData.containsKey('lastMessageTime')) {
            _checkForNewMessage(chatId, chatData, userId);
          }
        }
      }
    }, onError: (error) {
      debugPrint('❌ Firestore listener error: $error');
    });
  }

  static Future<void> _checkForNewMessage(
      String chatId, Map<String, dynamic> chatData, String userId) async {
    try {
      debugPrint('\n🔍 CHECKING NEW MESSAGE:');
      debugPrint('  Chat ID: $chatId');
      debugPrint('  Current User ID: $userId');

      final lastMessageSender = chatData['lastMessageSender'] as String?;
      final lastMessage = chatData['lastMessage'] as String?;
      final participantNames =
          (chatData['participantNames'] as Map<String, dynamic>?)
                  ?.cast<String, String>() ??
              {};

      debugPrint('  Last Message Sender: $lastMessageSender');
      debugPrint('  Last Message: $lastMessage');

      // BLOCKER CRITIQUE: Ne pas créer de notification pour ses propres messages
      if (lastMessageSender == userId) {
        debugPrint('🚫 BLOCKED: Message from current user ($userId)');
        debugPrint('  Sender ID: $lastMessageSender');
        debugPrint('  Current User ID: $userId');
        debugPrint('  They are EQUAL - NO NOTIFICATION');
        return;
      }

      // Vérifier si c'est un nouveau message
      if (lastMessageSender != null &&
          lastMessage != null &&
          lastMessage.isNotEmpty) {
        debugPrint('✅ APPROVED: Message from other user ($lastMessageSender)');

        final senderName = participantNames[lastMessageSender] ?? 'Someone';
        debugPrint('  Sender Name: $senderName');

        // Vérifier si notification existe déjà pour ce chat
        final notificationId = '${userId}_$chatId';
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

        // Créer les données de notification SANS FieldValue
        final now = DateTime.now();
        final notificationData = {
          'userId': userId,
          'type': 'message',
          'title': messageCount > 1
              ? 'New messages from $senderName ($messageCount)'
              : 'New message from $senderName',
          'message': lastMessage.length > 100
              ? '${lastMessage.substring(0, 100)}...'
              : lastMessage,
          'chatId': chatId,
          'senderId': lastMessageSender,
          'senderName': senderName,
          'time':
              now.toIso8601String(), // ← Utiliser String au lieu de FieldValue
          'lastMessageTime': now.toIso8601String(), // ← Utiliser String
          'isRead': false,
          'messageCount': messageCount,
          'actionText': 'Reply',
        };

        // Sauvegarder dans Firestore
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notificationId)
            .set(notificationData, SetOptions(merge: true));

        debugPrint('✅ Notification saved to Firestore: $notificationId');

        // Ajouter au stream
        _notificationStreamController.add({
          'id': notificationId,
          'title': notificationData['title'],
          'body': notificationData['message'],
          'data': notificationData,
          'type': 'message',
          'senderId': lastMessageSender,
          'chatId': chatId,
        });

        // Créer payload SÉRIALISABLE (sans FieldValue)
        final payloadData = {
          ...notificationData,
          'notificationId': notificationId,
        };

        // Afficher notification locale AVEC SON
        await showLocalNotification(
          title: messageCount > 1
              ? '$senderName ($messageCount new messages)'
              : 'New message from $senderName',
          body: lastMessage.length > 100
              ? '${lastMessage.substring(0, 100)}...'
              : lastMessage,
          payload: json.encode(payloadData),
        );

        // Mettre à jour le compteur de notifications non lues
        await _updateUnreadCount(userId, 1);
      }
    } catch (e) {
      debugPrint('❌ Error checking new message: $e');
      debugPrint('Stack trace: ${e.toString()}');
    }
  }

  static void _cleanupListeners() {
    if (_firestoreListener != null) {
      _firestoreListener!.cancel();
      _firestoreListener = null;
    }
    debugPrint('🔇 Firestore listener cleaned up');
  }

  // ============================
  // AFFICHAGE DES NOTIFICATIONS (CORRIGÉ)
  // ============================

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      // ⚠️ BLOCKER: Ne pas montrer les notifications "Message sent"
      if (title.contains('Message sent') || body.contains('Message sent')) {
        debugPrint('🚫 BLOCKED: Suppressing "Message sent" notification');
        return;
      }

      debugPrint('🔔 SHOWING LOCAL NOTIFICATION: $title');

      // Configuration Android AVEC SON
      final androidDetails = AndroidNotificationDetails(
        'service_app_channel',
        'Service App Notifications',
        channelDescription: 'Important notifications with sound',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        icon: '@mipmap/ic_launcher',
        color: Colors.blue,
        styleInformation: BigTextStyleInformation(body),
        timeoutAfter: 5000,
        autoCancel: true,
        showWhen: true,
      );

      final details = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('✅ Notification displayed with sound: $title');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  // MÉTHODE PUBLIQUE POUR LES AUTRES FICHIERS
  static Future<void> showNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    await showLocalNotification(
      title: title,
      body: body,
      payload: payload,
    );
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;

    // Sauter si sender est l'utilisateur courant
    if (_currentUserId != null && data['senderId'] == _currentUserId) {
      debugPrint('⏭️ Skipping own FCM message');
      return;
    }

    await showLocalNotification(
      title: notification?.title ?? data['title'] ?? 'New Message',
      body: notification?.body ?? data['message'] ?? '',
      payload: json.encode(data),
    );
  }

  // ============================
  // GESTION DES TOKENS
  // ============================

  static Future<void> _saveFCMToken(String token) async {
    if (_currentUserId == null) {
      debugPrint('⚠️ Cannot save token: No user logged in');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId!)
          .set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ FCM token saved for user $_currentUserId');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  // ============================
  // ACTIONS SUR LES NOTIFICATIONS
  // ============================

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

      debugPrint('✅ Notification $notificationId marked as read');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
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

  // ============================
  // NAVIGATION
  // ============================

  static void _handleNavigation(Map<String, dynamic> data) {
    final type = data['type'];
    final chatId = data['chatId'];
    final notificationId = data['notificationId'];

    // Marquer comme lu quand on clique
    if (notificationId != null) {
      markAsRead(notificationId as String);
    }

    if (type == 'message' && chatId != null) {
      _navigateToChat(chatId as String);
    }
  }

  static void _navigateToChat(String chatId) {
    if (navigatorKey.currentState == null) {
      debugPrint('⚠️ Navigator not ready');
      return;
    }

    // Naviguer vers la page de chat
    navigatorKey.currentState?.pushNamed('/chat', arguments: chatId);
  }

  // ============================
  // MÉTHODES PUBLIQUES
  // ============================

  static Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }

  static Future<void> refreshToken() async {
    final token = await _firebaseMessaging.getToken();
    if (token != null) _saveFCMToken(token);
  }

  static Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
    debugPrint('🔔 All notifications cleared');
  }

  // ============================
  // DISPOSE
  // ============================

  static void dispose() {
    _cleanupListeners();
    _notificationStreamController.close();
    _isInitialized = false;
    debugPrint('🔔 NotificationService disposed');
  }
}
