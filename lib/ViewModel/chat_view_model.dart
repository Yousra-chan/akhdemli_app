import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../Services/chat_service.dart';
import '../models/ChatModel.dart';
import '../models/MessageModel.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  late Stream<List<ChatModel>> _userChatsStream;
  Stream<List<ChatModel>> get userChatsStream => _userChatsStream;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  String? _currentUserId;

  ChatViewModel({required String userId}) {
    _currentUserId = userId;
    _initializeStream(userId);
  }

  void _initializeStream(String userId) {
    _userChatsStream = _chatService.getUserChatsStream(userId);
    notifyListeners();
  }

  void updateUser(String newUserId) {
    _currentUserId = newUserId;
    _initializeStream(newUserId);
  }

  Stream<List<MessageModel>> listenMessages(String chatId) {
    if (_currentUserId == null) {
      throw Exception('User ID not defined');
    }
    return _chatService.listenMessages(chatId, currentUserId: _currentUserId!);
  }

  Future<bool> sendMessage(String chatId, MessageModel message) async {
    _setLoading(true);
    _setError(null);

    try {
      await _chatService.sendMessage(chatId, message);
      return true;
    } catch (e) {
      _setError('failed_to_send_message');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> createChat({
    required String clientId,
    required String providerId,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final chatId = await _chatService.createChat(
        clientId: clientId,
        providerId: providerId,
      );
      return chatId;
    } catch (e) {
      debugPrint('❌ ChatViewModel.createChat error: $e');
      _setError(e.toString());
      rethrow; // Rethrow to let the UI handle specific errors
    } finally {
      _setLoading(false);
    }
  }

  Stream<int> getUnreadCount(String chatId) {
    if (_currentUserId == null) {
      throw Exception('User ID not defined');
    }
    return _chatService.getUnreadCount(chatId, _currentUserId!);
  }

  Stream<int> getTotalUnreadCount() {
    if (_currentUserId == null) {
      throw Exception('User ID not defined');
    }
    return _chatService.getTotalUnreadCount(_currentUserId!);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Add to ChatViewModel
  Future<String?> getUserProfileImageUrl(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        return data?['photoUrl'] ??
            data?['profileImage'] ??
            data?['imageUrl'] ??
            data?['avatar'] ??
            '';
      }
      return '';
    } catch (e) {
      print('❌ Error fetching user profile image: $e');
      return '';
    }
  }

// Add method to get user data by ID
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      return userDoc.data();
    } catch (e) {
      print('❌ Error fetching user data: $e');
      return null;
    }
  }

  // Add to ChatViewModel if not already present
  Future<ChatModel?> getChatById(String chatId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();
      if (doc.exists) {
        return ChatModel.fromDoc(doc);
      }
      return null;
    } catch (e) {
      print('Error getting chat: $e');
      return null;
    }
  }
}
