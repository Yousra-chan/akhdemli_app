import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ChatModel.dart';
import '../models/MessageModel.dart';

/// Custom exception for chat-related errors
class ChatException implements Exception {
  final String message;
  final String? code;

  ChatException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Generates canonical chat ID from two user IDs
/// Ensures consistent chat identification regardless of parameter order
String getCanonicalChatId(String id1, String id2) {
  final ids = [id1, id2]..sort();
  return '${ids[0]}_${ids[1]}';
}

/// Chat Service for managing conversations between users
///
/// Handles:
/// - Chat creation and management
/// - Message sending and retrieval
/// - Read status tracking
/// - Unread count management
/// - User lookups
class ChatService {
  // Firestore references
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference<Map<String, dynamic>> _chatsRef;
  final CollectionReference<Map<String, dynamic>> _usersRef;

  // Firestore collection and field constants
  static const String _chatsCollection = 'chats';
  static const String _usersCollection = 'users';
  static const String _messagesSubcollection = 'messages';

  // Chat field constants
  static const String _chatIdField = 'chatId';
  static const String _clientIdField = 'clientId';
  static const String _providerIdField = 'providerId';
  static const String _participantsField = 'participants';
  static const String _participantNamesField = 'participantNames';
  static const String _participantRolesField = 'participantRoles';
  static const String _lastMessageField = 'lastMessage';
  static const String _lastMessageTimeField = 'lastMessageTime';
  static const String _lastMessageSenderField = 'lastMessageSender';
  static const String _lastMessageTypeField = 'lastMessageType';
  static const String _unreadCountField = 'unreadCount';
  static const String _createdAtField = 'createdAt';
  static const String _chatIdsField = 'chatIds';

  // User field constants
  static const String _roleField = 'role';
  static const String _nameField = 'name';
  static const String _photoUrlField = 'photoUrl';
  static const String _roleProvider = 'provider';
  static const String _roleClient = 'client';

  // Message field constants
  static const String _isReadField = 'isRead';
  static const String _timestampField = 'timestamp';
  static const String _senderIdField = 'senderId';

  // Constants
  static const int _defaultChatLimit = 20;
  static const int _defaultMessageLimit = 50;

  ChatService()
      : _chatsRef = FirebaseFirestore.instance.collection(_chatsCollection),
        _usersRef = FirebaseFirestore.instance.collection(_usersCollection);

  // ============================================================================
  // CHAT MANAGEMENT
  // ============================================================================

  /// Creates a new chat between two users
  ///
  /// Parameters:
  /// - clientId: ID of the client user
  /// - providerId: ID of the provider user
  ///
  /// Returns: Chat ID if created successfully, or existing chat ID if already exists
  /// Throws: ChatException on validation failure or if users don't exist
  Future<String?> createChat({
    required String clientId,
    required String providerId,
  }) async {
    try {
      _validateCreateChatInputs(clientId, providerId);

      developer.log('🔄 Creating chat between $clientId and $providerId',
          name: 'ChatService');

      final chatId = getCanonicalChatId(clientId, providerId);
      final docRef = _chatsRef.doc(chatId);

      // Check if chat already exists
      final existingChat = await docRef.get();
      if (existingChat.exists) {
        developer.log('ℹ️ Chat already exists: $chatId', name: 'ChatService');
        return chatId;
      }

      // Fetch user data
      final clientDoc = await _usersRef.doc(clientId).get();
      final providerDoc = await _usersRef.doc(providerId).get();

      final clientData = clientDoc.data();
      final providerData = providerDoc.data();

      // Create chat document
      final chatData = {
        _chatIdField: chatId,
        _clientIdField: clientId,
        _providerIdField: providerId,
        _lastMessageField: '',
        _lastMessageTimeField: Timestamp.now(),
        _participantsField: [clientId, providerId],
        _participantNamesField: {
          clientId: clientData?[_nameField] ?? 'User',
          providerId: providerData?[_nameField] ?? 'Contact'
        },
        _participantRolesField: {
          clientId: clientData?[_roleField] ?? _roleClient,
          providerId: providerData?[_roleField] ?? _roleProvider
        },
        _unreadCountField: {clientId: 0, providerId: 0},
        _createdAtField: FieldValue.serverTimestamp(),
      };

      // Create chat document
      // We use set() directly instead of a transaction to avoid Permission Denied 
      // when trying to update the other user's document.
      // The chat participants are already stored in the 'participants' array in the chat document,
      // which is what we use for querying.
      await docRef.set(chatData);

      developer.log('✅ Chat created successfully: $chatId',
          name: 'ChatService');
      return chatId;
    } on ChatException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('❌ Error creating chat: $e',
          name: 'ChatService', error: e, stackTrace: stackTrace);
      
      // If it's a permission error, it might be due to the users not existing or rules
      if (e.toString().contains('permission-denied')) {
        throw ChatException(
          'Permission denied. Please check your Firestore rules.',
          code: 'permission-denied',
        );
      }

      rethrow;
    }
  }

  /// Retrieves chat stream for a specific user
  ///
  /// Parameters:
  /// - userId: User ID to fetch chats for
  /// - limit: Maximum number of chats to retrieve (default: 20)
  ///
  /// Returns: Stream of chat list ordered by last message time
  Stream<List<ChatModel>> getUserChatsStream(String userId,
      {int limit = _defaultChatLimit}) {
    try {
      _validateUserId(userId);

      return _chatsRef
          .where(_participantsField, arrayContains: userId)
          .orderBy(_lastMessageTimeField, descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          try {
            return ChatModel.fromDoc(doc);
          } catch (e) {
            developer.log('Warning: Could not parse chat ${doc.id}: $e',
                name: 'ChatService');
            rethrow;
          }
        }).toList();
      }).handleError((error) {
        developer.log('❌ Error in getUserChatsStream: $error',
            name: 'ChatService');
      });
    } catch (e) {
      developer.log('❌ Error setting up chats stream: $e', name: 'ChatService');
      return Stream.error(e);
    }
  }

  /// Retrieves a specific chat by ID
  ///
  /// Parameters:
  /// - chatId: ID of the chat to retrieve
  ///
  /// Returns: ChatModel if found, null otherwise
  Future<ChatModel?> getChatById(String chatId) async {
    try {
      _validateChatId(chatId);

      final doc = await _chatsRef.doc(chatId).get();
      if (doc.exists) {
        return ChatModel.fromDoc(doc);
      }
      return null;
    } catch (e, stackTrace) {
      developer.log('❌ Error getting chat: $e',
          name: 'ChatService', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Retrieves raw chat data by ID
  ///
  /// Parameters:
  /// - chatId: ID of the chat
  ///
  /// Returns: Chat data as map, or null if not found
  Future<Map<String, dynamic>?> getChatData(String chatId) async {
    try {
      _validateChatId(chatId);

      final doc = await _chatsRef.doc(chatId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      developer.log('❌ Error getting chat data: $e', name: 'ChatService');
      return null;
    }
  }

  // ============================================================================
  // MESSAGE MANAGEMENT
  // ============================================================================

  /// Sends a message in a chat
  ///
  /// Parameters:
  /// - chatId: ID of the chat
  /// - message: MessageModel containing message data
  ///
  /// Performs:
  /// 1. Validates chat exists
  /// 2. Saves message to database
  /// 3. Updates chat's last message info
  /// 4. Increments unread count for recipient
  /// 5. Uses transaction for consistency
  ///
  /// Throws: ChatException if chat doesn't exist
  Future<void> sendMessage(String chatId, MessageModel message) async {
    try {
      _validateSendMessageInputs(chatId, message);

      developer.log('\n🚀 Sending message in chat: $chatId',
          name: 'ChatService');
      developer.log('  Sender ID: ${message.senderId}', name: 'ChatService');
      developer.log('  Message: ${message.text}', name: 'ChatService');

      final chatDocRef = _chatsRef.doc(chatId);
      final messagesRef = chatDocRef.collection(_messagesSubcollection);

      // Verify chat exists
      final chatDoc = await chatDocRef.get();
      if (!chatDoc.exists) {
        throw ChatException('Chat does not exist', code: 'chat-not-found');
      }

      final chatData = chatDoc.data();
      if (chatData == null) {
        throw ChatException('Chat data is invalid', code: 'invalid-chat-data');
      }

      // Get other participant
      final participants =
          List<String>.from(chatData[_participantsField] ?? []);
      final otherUserId = _getOtherUserId(participants, message.senderId);

      if (otherUserId == null) {
        throw ChatException(
          'Could not determine other participant',
          code: 'invalid-participants',
        );
      }

      // Get sender name
      final participantNames = chatData[_participantNamesField] ?? {};
      final senderName = participantNames[message.senderId] ?? 'Someone';

      developer.log('  Receiver ID: $otherUserId', name: 'ChatService');
      developer.log('  Sender Name: $senderName', name: 'ChatService');

      // Save message and update chat in transaction
      final messageDoc = messagesRef.doc();
      final messageData = {
        ...message.toMap(),
        'id': messageDoc.id,
        _timestampField: FieldValue.serverTimestamp(),
      };

      await _firestore.runTransaction((transaction) async {
        transaction.set(messageDoc, messageData);
        transaction.update(chatDocRef, {
          _lastMessageField: message.text,
          _lastMessageTimeField: FieldValue.serverTimestamp(),
          _lastMessageSenderField: message.senderId,
          _lastMessageTypeField: message.type,
          '$_unreadCountField.$otherUserId': FieldValue.increment(1),
        });
      });

      developer.log('✅ Message saved successfully', name: 'ChatService');
    } on ChatException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('❌ Error sending message: $e',
          name: 'ChatService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Listens to messages in a chat
  ///
  /// Parameters:
  /// - chatId: ID of the chat
  /// - limit: Maximum messages to retrieve (default: 50)
  /// - currentUserId: ID of current user (for marking as read)
  ///
  /// Returns: Stream of message list
  /// Auto-marks messages as read when current user is viewing
  Stream<List<MessageModel>> listenMessages(
    String chatId, {
    int limit = _defaultMessageLimit,
    String? currentUserId,
  }) {
    try {
      _validateChatId(chatId);

      return _chatsRef
          .doc(chatId)
          .collection(_messagesSubcollection)
          .orderBy(_timestampField, descending: false)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        final messages = <MessageModel>[];

        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            messages.add(MessageModel.fromMap({...data, 'id': doc.id}));
          } catch (e) {
            developer.log('Warning: Could not parse message ${doc.id}: $e',
                name: 'ChatService');
          }
        }

        // Mark as read if current user specified
        if (currentUserId != null && messages.isNotEmpty) {
          _markMessagesAsRead(chatId, currentUserId, messages).catchError(
            (e) => developer.log(
              'Warning: Could not mark messages as read: $e',
              name: 'ChatService',
            ),
          );
        }

        return messages;
      }).handleError((error) {
        developer.log('❌ Error in listenMessages: $error', name: 'ChatService');
      });
    } catch (e) {
      developer.log('❌ Error setting up messages stream: $e',
          name: 'ChatService');
      return Stream.error(e);
    }
  }

  /// Marks messages as read for a user
  ///
  /// Parameters:
  /// - chatId: ID of the chat
  /// - userId: User ID marking messages as read
  /// - messages: List of messages to process
  Future<void> _markMessagesAsRead(
    String chatId,
    String userId,
    List<MessageModel> messages,
  ) async {
    try {
      final unreadMessages = messages
          .where((msg) => msg.senderId != userId && !msg.isRead)
          .toList();

      final chatRef = _chatsRef.doc(chatId);

      if (unreadMessages.isEmpty) {
        // Even if no messages were in the provided list, ensure the count is 0 in Firestore
        await chatRef.update({'$_unreadCountField.$userId': 0});
        return;
      }

      final batch = _firestore.batch();

      for (final message in unreadMessages) {
        if (message.id != null && message.id!.isNotEmpty) {
          final messageRef = _chatsRef
              .doc(chatId)
              .collection(_messagesSubcollection)
              .doc(message.id!);
          batch.update(messageRef, {_isReadField: true});
        }
      }

      batch.update(chatRef, {'$_unreadCountField.$userId': 0});
      await batch.commit();

      developer.log('✅ Marked ${unreadMessages.length} messages as read',
          name: 'ChatService');
    } catch (e, stackTrace) {
      developer.log('❌ Error marking messages as read: $e',
          name: 'ChatService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // UNREAD COUNT MANAGEMENT
  // ============================================================================

  /// Gets unread message count for a specific chat
  ///
  /// Parameters:
  /// - chatId: ID of the chat
  /// - userId: User ID to get count for
  ///
  /// Returns: Stream of unread count
  Stream<int> getUnreadCount(String chatId, String userId) {
    try {
      _validateChatId(chatId);
      _validateUserId(userId);

      return _chatsRef.doc(chatId).snapshots().map((snapshot) {
        final data = snapshot.data();
        final unreadCount = data?[_unreadCountField] ?? {};
        final count = unreadCount[userId];

        if (count is int) return count;
        if (count is num) return count.toInt();
        return 0;
      }).handleError((error) {
        developer.log('❌ Error in getUnreadCount: $error', name: 'ChatService');
      });
    } catch (e) {
      developer.log('❌ Error setting up unread count stream: $e',
          name: 'ChatService');
      return Stream.error(e);
    }
  }

  /// Gets total unread count across all chats for a user
  ///
  /// Parameters:
  /// - userId: User ID to get total count for
  ///
  /// Returns: Stream of total unread count
  Stream<int> getTotalUnreadCount(String userId) {
    try {
      _validateUserId(userId);

      return _chatsRef
          .where(_participantsField, arrayContains: userId)
          .snapshots()
          .map((snapshot) {
        int total = 0;

        for (final doc in snapshot.docs) {
          final unreadCount = doc.data()[_unreadCountField] ?? {};
          final count = unreadCount[userId];

          if (count is int) {
            total += count;
          } else if (count is num) {
            total += count.toInt();
          }
        }

        return total;
      }).handleError((error) {
        developer.log('❌ Error in getTotalUnreadCount: $error',
            name: 'ChatService');
      });
    } catch (e) {
      developer.log('❌ Error setting up total unread count stream: $e',
          name: 'ChatService');
      return Stream.error(e);
    }
  }

  // ============================================================================
  // CHAT CLEANUP
  // ============================================================================

  /// Deletes a chat for a specific user
  ///
  /// Parameters:
  /// - chatId: ID of the chat
  /// - userId: User ID to remove from chat
  ///
  /// Throws: ChatException on failure
  Future<void> deleteChat(String chatId, String userId) async {
    try {
      _validateChatId(chatId);
      _validateUserId(userId);

      developer.log('🗑️ Deleting chat $chatId for user $userId',
          name: 'ChatService');

      await _firestore.runTransaction((transaction) async {
        transaction.update(_chatsRef.doc(chatId), {
          _participantsField: FieldValue.arrayRemove([userId]),
        });

        transaction.update(_usersRef.doc(userId), {
          _chatIdsField: FieldValue.arrayRemove([chatId]),
        });
      });

      developer.log('✅ Chat deleted successfully', name: 'ChatService');
    } on ChatException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('❌ Error deleting chat: $e',
          name: 'ChatService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Retrieves user data by ID
  ///
  /// Parameters:
  /// - userId: User ID to fetch data for
  ///
  /// Returns: User data as map, or null if not found
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      _validateUserId(userId);

      final userDoc = await _usersRef.doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      developer.log('❌ Error fetching user data: $e', name: 'ChatService');
      return null;
    }
  }

  /// Retrieves user's profile image URL
  ///
  /// Parameters:
  /// - userId: User ID
  ///
  /// Returns: Profile image URL, or empty string if not found
  Future<String> getUserProfileImageUrl(String userId) async {
    try {
      _validateUserId(userId);

      final userDoc = await _usersRef.doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          // Try multiple field names for profile image
          return data[_photoUrlField] ??
              data['profileImage'] ??
              data['imageUrl'] ??
              data['avatar'] ??
              '';
        }
      }
      return '';
    } catch (e) {
      developer.log('❌ Error fetching user profile image: $e',
          name: 'ChatService');
      return '';
    }
  }

  /// Gets the other participant in a chat
  ///
  /// Parameters:
  /// - chatId: ID of the chat
  /// - currentUserId: Current user's ID
  ///
  /// Returns: Other participant's user ID, or null if not found
  Future<String?> getOtherParticipant(
      String chatId, String currentUserId) async {
    try {
      _validateChatId(chatId);
      _validateUserId(currentUserId);

      final chatData = await getChatData(chatId);
      if (chatData != null) {
        final participants =
            List<String>.from(chatData[_participantsField] ?? []);
        return _getOtherUserId(participants, currentUserId);
      }
      return null;
    } catch (e) {
      developer.log('❌ Error getting other participant: $e',
          name: 'ChatService');
      return null;
    }
  }

  /// Gets participant names for a chat
  ///
  /// Parameters:
  /// - chatId: ID of the chat
  ///
  /// Returns: Map of user IDs to names
  Future<Map<String, String>> getParticipantNames(String chatId) async {
    try {
      _validateChatId(chatId);

      final chatData = await getChatData(chatId);
      if (chatData != null) {
        final names = chatData[_participantNamesField] as Map<String, dynamic>?;
        return names?.cast<String, String>() ?? {};
      }
      return {};
    } catch (e) {
      developer.log('❌ Error getting participant names: $e',
          name: 'ChatService');
      return {};
    }
  }

  /// Gets available providers for chatting
  ///
  /// Returns: List of provider data with id, name, email, photoUrl, role
  Future<List<Map<String, dynamic>>> getAvailableProviders() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUserId = currentUser?.uid;

      if (currentUserId == null) {
        throw ChatException('User not authenticated',
            code: 'not-authenticated');
      }

      // Query providers first
      final providerQuery = await _usersRef
          .where(_roleField, isEqualTo: _roleProvider)
          .limit(_defaultChatLimit)
          .get();

      final providers = _buildProviderList(
        providerQuery.docs,
        currentUserId,
        isProvider: true,
      );

      if (providers.isNotEmpty) {
        return providers;
      }

      // Fallback: get all users if no providers found
      final allUsers = await _usersRef.limit(_defaultChatLimit).get();

      return _buildProviderList(
        allUsers.docs,
        currentUserId,
        isProvider: false,
      );
    } catch (e, stackTrace) {
      developer.log('❌ Error getting providers: $e',
          name: 'ChatService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Builds provider list from documents
  List<Map<String, dynamic>> _buildProviderList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String currentUserId, {
    required bool isProvider,
  }) {
    return docs.where((doc) => doc.id != currentUserId).where((doc) {
      final data = doc.data();
      return data[_nameField]?.isNotEmpty == true ||
          data['email']?.isNotEmpty == true;
    }).map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data[_nameField] ?? 'User ${doc.id.substring(0, 6)}',
        'email': data['email'] ?? '',
        'photoUrl': data[_photoUrlField] ?? '',
        'role': data[_roleField] ?? (isProvider ? _roleProvider : 'user'),
      };
    }).toList();
  }

  /// Gets other user ID from participants list
  String? _getOtherUserId(List<String> participants, String currentUserId) {
    try {
      return participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
    } catch (e) {
      return null;
    }
  }

  // ============================================================================
  // INPUT VALIDATION METHODS
  // ============================================================================

  /// Validates create chat inputs
  void _validateCreateChatInputs(String clientId, String providerId) {
    if (clientId.isEmpty) {
      throw ChatException('Client ID cannot be empty', code: 'empty-client-id');
    }

    if (providerId.isEmpty) {
      throw ChatException('Provider ID cannot be empty',
          code: 'empty-provider-id');
    }

    if (clientId == providerId) {
      throw ChatException(
        'Cannot create chat with yourself',
        code: 'same-user-chat',
      );
    }

    if (clientId.length > 200 || providerId.length > 200) {
      throw ChatException('User ID too long', code: 'id-too-long');
    }
  }

  /// Validates user ID
  void _validateUserId(String userId) {
    if (userId.isEmpty) {
      throw ChatException('User ID cannot be empty', code: 'empty-user-id');
    }

    if (userId.length > 200) {
      throw ChatException('User ID too long', code: 'user-id-too-long');
    }
  }

  /// Validates chat ID
  void _validateChatId(String chatId) {
    if (chatId.isEmpty) {
      throw ChatException('Chat ID cannot be empty', code: 'empty-chat-id');
    }

    if (chatId.length > 300) {
      throw ChatException('Chat ID too long', code: 'chat-id-too-long');
    }
  }

  /// Validates send message inputs
  void _validateSendMessageInputs(String chatId, MessageModel message) {
    _validateChatId(chatId);

    if (message.senderId.isEmpty) {
      throw ChatException('Sender ID cannot be empty', code: 'empty-sender-id');
    }

    if (message.text.isEmpty) {
      throw ChatException('Message text cannot be empty',
          code: 'empty-message');
    }

    if (message.text.length > 2000) {
      throw ChatException('Message too long (max 2000 characters)',
          code: 'message-too-long');
    }

    if (message.type.isEmpty) {
      throw ChatException('Message type cannot be empty', code: 'empty-type');
    }
  }
}
