import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ChatModel.dart';
import '../models/MessageModel.dart';

String getCanonicalChatId(String id1, String id2) {
  final ids = [id1, id2]..sort();
  return '${ids[0]}_${ids[1]}';
}

/// ✅ UPDATED ChatService - Works with FREE Render.com server
/// ❌ NO Cloud Functions needed!
/// ✅ Just saves to Firestore, Render server detects changes automatically
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final CollectionReference<Map<String, dynamic>> _chatsRef;
  final CollectionReference<Map<String, dynamic>> _usersRef;

  ChatService()
      : _chatsRef = FirebaseFirestore.instance.collection('chats'),
        _usersRef = FirebaseFirestore.instance.collection('users');

  // ==================== CHAT MANAGEMENT ====================

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

      developer.log('✅ Chat created: $chatId', name: 'ChatService');
      return chatId;
    } catch (e, stackTrace) {
      developer.log('❌ Error creating chat: $e',
          name: 'ChatService', error: e, stackTrace: stackTrace);
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
    } catch (e, stackTrace) {
      developer.log('❌ Error getting chat: $e',
          name: 'ChatService', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getChatData(String chatId) async {
    try {
      final doc = await _chatsRef.doc(chatId).get();
      if (doc.exists) return doc.data();
      return null;
    } catch (e) {
      developer.log('❌ Error getting chat data: $e', name: 'ChatService');
      return null;
    }
  }

  // ==================== MESSAGE MANAGEMENT ====================

  /// ✅ SIMPLIFIED - Just save to Firestore
  /// ✅ Render.com server watches Firestore and sends notifications automatically!
  /// ❌ NO Cloud Functions needed!
  Future<void> sendMessage(String chatId, MessageModel message) async {
    developer.log('\n🚀 [ChatService] SENDING MESSAGE', name: 'ChatService');
    developer.log('  Chat ID: $chatId', name: 'ChatService');
    developer.log('  Sender ID: ${message.senderId}', name: 'ChatService');
    developer.log('  Message: ${message.text}', name: 'ChatService');

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

    developer.log('  Receiver ID: $otherUserId', name: 'ChatService');
    developer.log('  Sender Name: $senderName', name: 'ChatService');

    // 🔥 SIMPLIFIED: Just save to Firestore
    // Your Render.com server watches for this change and sends notification automatically!
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

    developer.log('✅ Message saved to Firestore', name: 'ChatService');
    developer.log(
        '📡 Render server will detect this change and send notification automatically!',
        name: 'ChatService');
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

        developer.log('✅ Marked ${unreadMessages.length} messages as read',
            name: 'ChatService');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error marking messages as read: $e',
          name: 'ChatService', error: e, stackTrace: stackTrace);
    }
  }

  // ==================== UNREAD COUNT MANAGEMENT ====================

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

  // ==================== CHAT CLEANUP ====================

  Future<void> deleteChat(String chatId, String userId) async {
    try {
      await _chatsRef.doc(chatId).update({
        'participants': FieldValue.arrayRemove([userId]),
      });

      await _usersRef.doc(userId).update({
        'chatIds': FieldValue.arrayRemove([chatId]),
      });

      developer.log('🗑️ Chat $chatId removed for user $userId',
          name: 'ChatService');
    } catch (e, stackTrace) {
      developer.log('❌ Error deleting chat: $e',
          name: 'ChatService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ==================== UTILITY METHODS ====================

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final userDoc = await _usersRef.doc(userId).get();
      return userDoc.data();
    } catch (e) {
      developer.log('❌ Error fetching user data: $e', name: 'ChatService');
      return null;
    }
  }

  Future<String?> getUserProfileImageUrl(String userId) async {
    try {
      final userDoc = await _usersRef.doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        return data['photoUrl'] ??
            data['profileImage'] ??
            data['imageUrl'] ??
            data['avatar'] ??
            '';
      }
      return '';
    } catch (e) {
      developer.log('❌ Error fetching user profile image: $e',
          name: 'ChatService');
      return '';
    }
  }

  /// Get the other participant in a chat
  Future<String?> getOtherParticipant(
      String chatId, String currentUserId) async {
    try {
      final chatData = await getChatData(chatId);
      if (chatData != null) {
        final participants = List<String>.from(chatData['participants'] ?? []);
        return participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );
      }
      return null;
    } catch (e) {
      developer.log('❌ Error getting other participant: $e',
          name: 'ChatService');
      return null;
    }
  }

  /// Get chat participant names
  Future<Map<String, String>> getParticipantNames(String chatId) async {
    try {
      final chatData = await getChatData(chatId);
      if (chatData != null) {
        final names = chatData['participantNames'] as Map<String, dynamic>?;
        return names?.cast<String, String>() ?? {};
      }
      return {};
    } catch (e) {
      developer.log('❌ Error getting participant names: $e',
          name: 'ChatService');
      return {};
    }
  }

  /// Get available providers for chat
  Future<List<Map<String, dynamic>>> getAvailableProviders() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUserId = currentUser?.uid;

      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final providerQuery =
          await _usersRef.where('role', isEqualTo: 'provider').limit(20).get();

      final providers =
          providerQuery.docs.where((doc) => doc.id != currentUserId).map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Provider',
          'email': data['email'] ?? '',
          'photoUrl': data['photoUrl'] ?? '',
          'role': data['role'] ?? 'provider',
        };
      }).toList();

      if (providers.isNotEmpty) {
        return providers;
      }

      final allUsers = await _usersRef.limit(20).get();

      final potentialProviders =
          allUsers.docs.where((doc) => doc.id != currentUserId).where((doc) {
        final data = doc.data();
        return data['name']?.isNotEmpty == true ||
            data['email']?.isNotEmpty == true;
      }).map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'User ${doc.id.substring(0, 6)}',
          'email': data['email'] ?? '',
          'photoUrl': data['photoUrl'] ?? '',
          'role': data['role'] ?? 'user',
        };
      }).toList();

      return potentialProviders;
    } catch (e) {
      developer.log('❌ Error getting providers: $e', name: 'ChatService');
      return [];
    }
  }
}
