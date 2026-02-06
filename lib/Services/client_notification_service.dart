import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ClientNotificationService {
  // Singleton instance
  static final ClientNotificationService _instance =
      ClientNotificationService._internal();
  factory ClientNotificationService() => _instance;
  ClientNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Garder une référence aux listeners
  StreamSubscription<QuerySnapshot>? _chatsListener;
  final Map<String, StreamSubscription<QuerySnapshot>> _messageListeners = {};

  // ============================
  // INITIALISATION
  // ============================

  Future<void> initialize() async {
    print('🔔 Initializing ClientNotificationService...');

    try {
      // Initialiser les notifications locales
      await _initializeLocalNotifications();

      // Démarrer l'écoute des messages
      _startListeningToMessages();

      print('✅ ClientNotificationService initialized');
    } catch (e) {
      print('❌ Error initializing ClientNotificationService: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notifications.initialize(initializationSettings);
  }

  // ============================
  // ÉCOUTE DES MESSAGES
  // ============================

  void _startListeningToMessages() {
    print('👂 Starting to listen for messages...');

    // Écouter les changements d'authentification
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        print('👤 User logged in: ${user.uid}');
        _setupChatListeners(user.uid);
      } else {
        print('👤 User logged out');
        _cleanupListeners();
      }
    });
  }

  void _setupChatListeners(String userId) {
    print('🔍 Setting up chat listeners for user: $userId');

    // Nettoyer les anciens listeners
    _cleanupListeners();

    // Écouter tous les chats où l'utilisateur est participant
    _chatsListener = _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen((chatsSnapshot) {
      print('📊 Chats update: ${chatsSnapshot.docs.length} chats');

      for (var chatDoc in chatsSnapshot.docs) {
        final chatId = chatDoc.id;
        final chatData = chatDoc.data();

        // Si on n'a pas déjà un listener pour ce chat
        if (!_messageListeners.containsKey(chatId)) {
          _setupMessageListener(chatId, chatData, userId);
        }
      }

      // Nettoyer les listeners des chats qui n'existent plus
      _cleanupOldListeners(chatsSnapshot.docs.map((d) => d.id).toList());
    }, onError: (error) {
      print('❌ Error in chats listener: $error');
    });
  }

  void _setupMessageListener(
      String chatId, Map<String, dynamic> chatData, String userId) {
    print('🔍 Setting up message listener for chat: $chatId');

    final participants =
        (chatData['participants'] as List<dynamic>?)?.cast<String>() ?? [];
    final participantNames =
        (chatData['participantNames'] as Map<String, dynamic>?)
                ?.cast<String, String>() ??
            {};

    // Écouter le dernier message de ce chat
    final messageListener = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((messagesSnapshot) {
      if (messagesSnapshot.docs.isNotEmpty) {
        final messageDoc = messagesSnapshot.docs.first;
        final message = messageDoc.data();
        final senderId = message['senderId'] as String?;

        print('📨 New message in chat $chatId from $senderId');

        // Vérifier si c'est un nouveau message
        if (messageDoc.metadata.hasPendingWrites) {
          print('⏳ Message has pending writes, waiting...');
          return;
        }

        // Ne pas créer de notification pour ses propres messages
        if (senderId != null && senderId != userId) {
          _handleNewMessage(
            chatId: chatId,
            message: message,
            senderId: senderId,
            participants: participants,
            participantNames: participantNames,
            userId: userId,
          );
        } else {
          print('⏭️ Skipping own message from $senderId');
        }
      }
    }, onError: (error) {
      print('❌ Error in message listener for chat $chatId: $error');
    });

    _messageListeners[chatId] = messageListener;
  }

  // ============================
  // GESTION DES NOUVEAUX MESSAGES
  // ============================

  Future<void> _handleNewMessage({
    required String chatId,
    required Map<String, dynamic> message,
    required String senderId,
    required List<String> participants,
    required Map<String, String> participantNames,
    required String userId,
  }) async {
    print('🎯 Handling new message from $senderId to $userId');

    // Vérifier si le receiver est bien l'utilisateur courant
    String? receiverId;
    for (var participantId in participants) {
      if (participantId != senderId) {
        receiverId = participantId;
        break;
      }
    }

    if (receiverId != userId) {
      print(
          '⚠️ Message not for current user. Receiver: $receiverId, Current: $userId');
      return;
    }

    // Préparer le texte du message
    String messageText = message['content'] as String? ??
        message['text'] as String? ??
        'New message';

    if (message['type'] == 'image') {
      messageText = '📷 Sent a photo';
    } else if (message['type'] == 'file') {
      messageText = '📎 Sent a file';
    }

    if (messageText.length > 100) {
      messageText = messageText.substring(0, 100) + '...';
    }

    final senderName = participantNames[senderId] ?? 'Someone';
    print('  Sender: $senderName');
    print('  Message: $messageText');

    // Vérifier si notification existe déjà
    final notificationId = '${userId}_$chatId';
    final existingDoc =
        await _firestore.collection('notifications').doc(notificationId).get();

    int messageCount = 1;
    if (existingDoc.exists) {
      final existingData = existingDoc.data();
      messageCount = (existingData?['messageCount'] as int? ?? 0) + 1;
      print('  Updating existing notification. Count: $messageCount');
    } else {
      print('  Creating new notification');
    }

    // Préparer les données de notification
    final notificationData = {
      'userId': userId,
      'type': 'message',
      'title': messageCount > 1
          ? 'New messages from $senderName ($messageCount)'
          : 'New message from $senderName',
      'message': messageText,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'time': FieldValue.serverTimestamp(),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'isRead': false,
      'messageCount': messageCount,
      'actionText': 'Reply',
    };

    // Sauvegarder dans Firestore
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .set(notificationData, SetOptions(merge: true));

    print('✅ Notification saved to Firestore: $notificationId');

    // Mettre à jour le compteur de notifications non lues
    await _updateUnreadCount(userId, 1);

    // Afficher notification locale
    await _showLocalNotification(
      title: messageCount > 1
          ? '$senderName ($messageCount new messages)'
          : 'New message from $senderName',
      body: messageText,
      payload: chatId,
    );
  }

  // ============================
  // NOTIFICATIONS LOCALES
  // ============================

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'messages_channel',
        'Messages',
        channelDescription: 'New message notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails details =
          NotificationDetails(android: androidDetails);

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: payload,
      );

      print('🔔 Local notification shown: $title');
    } catch (e) {
      print('❌ Error showing local notification: $e');
    }
  }

  // ============================
  // COMPTEUR NON LUS
  // ============================

  Future<void> _updateUnreadCount(String userId, int increment) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'unreadCount': FieldValue.increment(increment),
        'lastNotification': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('📊 Unread count updated: +$increment for user $userId');
    } catch (e) {
      print('⚠️ Could not update unread count: $e');
    }
  }

  // ============================
  // NETTOYAGE
  // ============================

  void _cleanupOldListeners(List<String> activeChatIds) {
    final List<String> toRemove = [];

    for (var chatId in _messageListeners.keys) {
      if (!activeChatIds.contains(chatId)) {
        toRemove.add(chatId);
      }
    }

    for (var chatId in toRemove) {
      _messageListeners[chatId]?.cancel();
      _messageListeners.remove(chatId);
      print('🗑️ Removed listener for chat: $chatId');
    }
  }

  void _cleanupListeners() {
    print('🧹 Cleaning up all listeners...');

    // Annuler l'écoute des chats
    _chatsListener?.cancel();
    _chatsListener = null;

    // Annuler toutes les écoutes de messages
    for (var listener in _messageListeners.values) {
      listener.cancel();
    }
    _messageListeners.clear();
  }

  // ============================
  // MÉTHODES PUBLIQUES
  // ============================

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });

      // Décrémenter le compteur
      final user = _auth.currentUser;
      if (user != null) {
        await _updateUnreadCount(user.uid, -1);
      }

      print('📖 Notification marked as read: $notificationId');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      print('🗑️ Notification deleted: $notificationId');
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Supprimer toutes les notifications de l'utilisateur
        final snapshot = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: user.uid)
            .get();

        final batch = _firestore.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();

        // Réinitialiser le compteur
        await _firestore.collection('users').doc(user.uid).update({
          'unreadCount': 0,
        });

        print('✅ All notifications cleared for user ${user.uid}');
      }
    } catch (e) {
      print('❌ Error clearing notifications: $e');
    }
  }

  // ============================
  // DISPOSE
  // ============================

  void dispose() {
    print('🔔 Disposing ClientNotificationService');
    _cleanupListeners();
  }
}
