import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:service_app/Services/notification_service.dart';
import '../models/ChatModel.dart';
import '../models/MessageModel.dart';

String getCanonicalChatId(String id1, String id2) {
  final ids = [id1, id2]..sort();
  return '${ids[0]}_${ids[1]}';
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final CollectionReference<Map<String, dynamic>> _chatsRef;
  final CollectionReference<Map<String, dynamic>> _usersRef;

  ChatService()
      : _chatsRef = FirebaseFirestore.instance.collection('chats'),
        _usersRef = FirebaseFirestore.instance.collection('users');

  // === CRÉATION ET RÉCUPÉRATION DES CHATS ===

  Future<String?> createChat({
    required String clientId,
    required String providerId,
  }) async {
    try {
      if (clientId == providerId) {
        throw Exception(
            'Vous ne pouvez pas créer une discussion avec vous-même');
      }

      final chatId = getCanonicalChatId(clientId, providerId);
      final docRef = _chatsRef.doc(chatId);
      final existingChat = await docRef.get();

      if (existingChat.exists) return chatId;

      final clientDoc = await _usersRef.doc(clientId).get();
      final providerDoc = await _usersRef.doc(providerId).get();

      if (!clientDoc.exists || !providerDoc.exists) {
        throw Exception('Un des utilisateurs n\'existe pas');
      }

      final clientData = clientDoc.data()!;
      final providerData = providerDoc.data()!;

      final chatData = {
        'chatId': chatId,
        'clientId': clientId,
        'providerId': providerId,
        'lastMessage': '',
        'lastMessageTime': Timestamp.now(),
        'participants': [clientId, providerId],
        'participantNames': {
          clientId: clientData['name'] ?? 'Client',
          providerId: providerData['name'] ?? 'Prestataire'
        },
        'participantRoles': {
          clientId: clientData['role'] ?? 'client',
          providerId: providerData['role'] ?? 'provider'
        },
        'unreadCount': {clientId: 0, providerId: 0},
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(chatData);

      await _usersRef.doc(clientId).update({
        'chatIds': FieldValue.arrayUnion([chatId]),
      });
      await _usersRef.doc(providerId).update({
        'chatIds': FieldValue.arrayUnion([chatId]),
      });

      return chatId;
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<ChatModel>> getUserChatsStream(String userId, {int limit = 20}) {
    return _chatsRef
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatModel.fromDoc(doc)).toList());
  }

  Future<ChatModel?> getChatById(String chatId) async {
    try {
      final doc = await _chatsRef.doc(chatId).get();
      if (doc.exists) return ChatModel.fromDoc(doc);
      return null;
    } catch (_) {
      return null;
    }
  }

  // === GESTION DES MESSAGES ===

  Future<void> sendMessage(String chatId, MessageModel message) async {
    debugPrint('\n🚀 [ChatService] SENDING MESSAGE');
    debugPrint('  Chat ID: $chatId');
    debugPrint('  Sender ID: ${message.senderId}');
    debugPrint('  Message: ${message.text}');

    final chatDocRef = _chatsRef.doc(chatId);
    final messagesRef = chatDocRef.collection('messages');

    final chatDoc = await chatDocRef.get();
    if (!chatDoc.exists) throw Exception('Le chat n\'existe pas');

    final participants =
        List<String>.from(chatDoc.data()?['participants'] ?? []);
    final otherUserId = participants.firstWhere((id) => id != message.senderId);

    final participantNames = chatDoc.data()?['participantNames'] ?? {};
    final senderName = participantNames[message.senderId] ?? 'Someone';

    final messageDoc = messagesRef.doc();
    final messageData = {
      ...message.toMap(),
      'id': messageDoc.id,
      'timestamp': FieldValue.serverTimestamp(),
    };

    debugPrint('  Receiver ID: $otherUserId');
    debugPrint('  Sender Name: $senderName');

    await _firestore.runTransaction((transaction) async {
      transaction.set(messageDoc, messageData);
      transaction.update(chatDocRef, {
        'lastMessage': message.text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': message.senderId,
        'lastMessageType': message.type,
        'unreadCount.$otherUserId': FieldValue.increment(1),
      });
    });

    debugPrint('✅ Message saved to Firestore.');

    // IMPORTANT: NE PAS appeler NotificationService.showLocalNotification ici!
    // La notification sera gérée AUTOMATIQUEMENT par NotificationService
    // qui écoute les changements dans Firestore

    // Seulement un log de confirmation
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && message.senderId == currentUser.uid) {
      debugPrint('📤 Message sent successfully.');
      debugPrint('   Notification will be sent to RECEIVER only.');
    }
  }

  Stream<List<MessageModel>> listenMessages(
    String chatId, {
    int limit = 50,
    String? currentUserId,
  }) {
    return _chatsRef
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs.map((doc) {
        final data = doc.data();
        return MessageModel.fromMap({...data, 'id': doc.id});
      }).toList();

      if (currentUserId != null && messages.isNotEmpty) {
        _markMessagesAsRead(chatId, currentUserId, messages);
      }

      return messages;
    });
  }

  Future<void> _markMessagesAsRead(
    String chatId,
    String userId,
    List<MessageModel> messages,
  ) async {
    try {
      final unreadMessages = messages
          .where((msg) => msg.senderId != userId && !msg.isRead)
          .toList();

      if (unreadMessages.isNotEmpty) {
        final batch = _firestore.batch();
        final chatRef = _chatsRef.doc(chatId);

        for (final message in unreadMessages) {
          if (message.id != null) {
            final messageRef =
                _chatsRef.doc(chatId).collection('messages').doc(message.id!);
            batch.update(messageRef, {'isRead': true});
          }
        }

        batch.update(chatRef, {'unreadCount.$userId': 0});
        await batch.commit();
      }
    } catch (_) {}
  }

  Stream<int> getUnreadCount(String chatId, String userId) {
    return _chatsRef.doc(chatId).snapshots().map((snapshot) {
      final data = snapshot.data();
      final unreadCount = data?['unreadCount'] ?? {};
      final count = unreadCount[userId];
      if (count is int) return count;
      if (count is num) return count.toInt();
      return 0;
    });
  }

  Stream<int> getTotalUnreadCount(String userId) {
    return _chatsRef
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final unreadCount = doc.data()['unreadCount'] ?? {};
        final count = unreadCount[userId];
        if (count is int) total += count;
        if (count is num) total += count.toInt();
      }
      return total;
    });
  }

  Future<void> deleteChat(String chatId, String userId) async {
    try {
      await _chatsRef.doc(chatId).update({
        'participants': FieldValue.arrayRemove([userId]),
      });

      await _usersRef.doc(userId).update({
        'chatIds': FieldValue.arrayRemove([chatId]),
      });
    } catch (e) {
      rethrow;
    }
  }
}
