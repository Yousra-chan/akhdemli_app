import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:service_app/Services/notification_service.dart';

class HttpPollingService {
  // Singleton instance
  static final HttpPollingService _instance = HttpPollingService._internal();
  factory HttpPollingService() => _instance;
  HttpPollingService._internal();

  // Server URL - UPDATE THIS AFTER DEPLOYMENT
  static const String _serverUrl =
      'https://notifications-server-66y2.onrender.com';

  // User data
  String? _currentUserId;
  String? _currentUserName;

  // Polling control
  Timer? _pollingTimer;
  bool _isPolling = false;
  bool _isConnected = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;

  // Stream controllers
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  final StreamController<int> _pendingMessagesController =
      StreamController<int>.broadcast();

  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Public getters
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<bool> get onConnectionChange => _connectionController.stream;
  Stream<int> get onPendingMessagesChange => _pendingMessagesController.stream;
  Stream<String> get onError => _errorController.stream;

  bool get isConnected => _isConnected;
  bool get isPolling => _isPolling;
  String? get currentUserId => _currentUserId;
  String? get currentUserName => _currentUserName;
  String get serverUrl => _serverUrl;

  // ==================== CONNECTION METHODS ====================

  /// Initialize the service (call this in app startup)
  Future<void> initialize() async {
    developer.log('🔄 Initializing HttpPollingService...',
        name: 'HttpPollingService');

    // Check server health
    final health = await checkServerHealth();
    if (health['status'] == 'healthy') {
      developer.log('✅ Server is healthy', name: 'HttpPollingService');
    } else {
      developer.log('⚠️ Server health check failed: $health',
          name: 'HttpPollingService');
      _errorController.add('Server is not healthy: ${health['status']}');
    }
  }

  /// Connect user to the notification server
  Future<bool> connect({
    required String userId,
    required String userName,
    String? fcmToken,
  }) async {
    try {
      developer.log(
          '🔗 Connecting to notification server as $userName ($userId)...',
          name: 'HttpPollingService');

      final response = await http
          .post(
            Uri.parse('$_serverUrl/connect'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'userId': userId,
              'userName': userName,
              'fcmToken': fcmToken,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _currentUserId = userId;
        _currentUserName = userName;
        _isConnected = true;
        _reconnectAttempts =
            0; // Reset reconnect attempts on successful connection

        _connectionController.add(true);
        developer.log('✅ Connected to notification server',
            name: 'HttpPollingService');

        return true;
      } else {
        developer.log(
            '❌ Connection failed: ${response.statusCode} - ${response.body}',
            name: 'HttpPollingService');
        _errorController.add('Connection failed: ${response.statusCode}');
        return false;
      }
    } catch (e, stackTrace) {
      developer.log('❌ Connection error: $e',
          name: 'HttpPollingService', error: e, stackTrace: stackTrace);
      _errorController.add('Connection error: ${e.toString()}');
      return false;
    }
  }

  /// Start polling for messages
  Future<void> startPolling() async {
    if (_currentUserId == null) {
      developer.log('⚠️ Cannot start polling: No user connected',
          name: 'HttpPollingService');
      return;
    }

    if (_isPolling) {
      developer.log('⚠️ Polling already started', name: 'HttpPollingService');
      return;
    }

    _isPolling = true;
    _shouldReconnect = true;
    developer.log('🔄 Starting message polling for $_currentUserId',
        name: 'HttpPollingService');

    // Start polling immediately
    await _pollForMessages();
  }

  /// Stop polling for messages
  void stopPolling() {
    if (!_isPolling) return;

    _isPolling = false;
    _shouldReconnect = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;

    developer.log('⏹️ Stopped message polling', name: 'HttpPollingService');
  }

  /// Internal method to poll for messages
  Future<void> _pollForMessages() async {
    if (!_isPolling || _currentUserId == null || !_shouldReconnect) return;

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/poll/$_currentUserId'),
        headers: {'Accept': 'application/json'},
      ).timeout(
          const Duration(seconds: 35)); // Slightly longer than server timeout

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['type'] == 'message') {
          // 🚨 IMPORTANT: Only forward message to stream
          // NotificationService will handle notification creation
          _messageController.add(data);
          developer.log(
              '📨 Message received via HTTP polling: ${data['message']}',
              name: 'HttpPollingService');

          // 🚨 REMOVED: Don't show notification here!
          // NotificationService handles it via the stream listener
        } else if (data['type'] == 'timeout') {
          // Timeout is normal, continue polling
          developer.log('⏳ Polling timeout, continuing...',
              name: 'HttpPollingService');
        }

        _reconnectAttempts = 0; // Reset on successful poll
      } else {
        developer.log('⚠️ Polling failed: ${response.statusCode}',
            name: 'HttpPollingService');
        _handlePollingError('HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Polling error: $e',
          name: 'HttpPollingService', error: e, stackTrace: stackTrace);
      _handlePollingError(e.toString());
    }

    // Continue polling if still active
    if (_isPolling && _shouldReconnect) {
      _pollingTimer =
          Timer(const Duration(milliseconds: 100), _pollForMessages);
    }
  }

  /// Handle polling errors with exponential backoff
  void _handlePollingError(String error) {
    _reconnectAttempts++;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      developer.log('❌ Max reconnect attempts reached, stopping polling',
          name: 'HttpPollingService');
      _errorController.add('Max reconnect attempts reached');
      stopPolling();
      return;
    }

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s
    final backoffDelay = Duration(seconds: 1 << (_reconnectAttempts - 1));

    developer.log(
        '⏰ Reconnecting in ${backoffDelay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)',
        name: 'HttpPollingService');

    _pollingTimer = Timer(backoffDelay, () {
      if (_isPolling && _shouldReconnect) {
        _pollForMessages();
      }
    });
  }

  // 🚨 REMOVED: _showNotificationForMessage method - NotificationService handles it

  // ==================== MESSAGE METHODS ====================

  /// Send a message to another user
  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String message,
    required String chatId,
    String? senderName,
    String? messageId,
  }) async {
    try {
      if (_currentUserId == null) {
        return {'success': false, 'error': 'Not connected', 'delivered': false};
      }

      developer.log('📤 Sending message to $receiverId: $message',
          name: 'HttpPollingService');

      final response = await http
          .post(
            Uri.parse('$_serverUrl/send'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'senderId': _currentUserId,
              'receiverId': receiverId,
              'message': message,
              'chatId': chatId,
              'senderName': senderName ?? _currentUserName,
              'messageId': messageId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        developer.log('✅ Message sent: ${data['message']}',
            name: 'HttpPollingService');
        return {
          'success': true,
          'delivered': data['delivered'] ?? false,
          'message': data['message'] ?? 'Sent',
          'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
        };
      } else {
        developer.log('❌ Send failed: ${response.statusCode}',
            name: 'HttpPollingService');
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}',
          'delivered': false
        };
      }
    } catch (e, stackTrace) {
      developer.log('❌ Send error: $e',
          name: 'HttpPollingService', error: e, stackTrace: stackTrace);
      return {'success': false, 'error': e.toString(), 'delivered': false};
    }
  }

  /// Send typing indicator
  Future<void> sendTypingIndicator({
    required String receiverId,
    required String chatId,
    required bool isTyping,
  }) async {
    try {
      if (_currentUserId == null) return;

      // We'll use a simple message to indicate typing
      if (isTyping) {
        await sendMessage(
          receiverId: receiverId,
          message: '...typing...',
          chatId: chatId,
          senderName: _currentUserName,
          messageId: 'typing_${DateTime.now().millisecondsSinceEpoch}',
        );
      }
    } catch (e) {
      developer.log('⚠️ Typing indicator error: $e',
          name: 'HttpPollingService');
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Check if a user is online
  Future<Map<String, dynamic>> checkUserOnline(String userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_serverUrl/online/$userId'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'isOnline': false,
          'error': 'HTTP ${response.statusCode}'
        };
      }
    } catch (e) {
      developer.log('❌ Online check error: $e', name: 'HttpPollingService');
      return {'success': false, 'isOnline': false, 'error': e.toString()};
    }
  }

  /// Get count of pending messages
  Future<int> getPendingMessagesCount() async {
    if (_currentUserId == null) return 0;

    try {
      final response = await http
          .get(
            Uri.parse('$_serverUrl/pending/$_currentUserId'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final count = data['pendingCount'] as int? ?? 0;
        _pendingMessagesController.add(count);
        return count;
      }
      return 0;
    } catch (e) {
      developer.log('❌ Pending check error: $e', name: 'HttpPollingService');
      return 0;
    }
  }

  /// Check server health
  Future<Map<String, dynamic>> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        return {'status': 'unhealthy', 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      developer.log('❌ Health check error: $e', name: 'HttpPollingService');
      return {'status': 'offline', 'error': e.toString()};
    }
  }

  /// Ping server
  Future<bool> pingServer() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_serverUrl/ping'),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Disconnect from server
  Future<void> disconnect() async {
    developer.log('👋 Disconnecting from notification server...',
        name: 'HttpPollingService');

    // Stop polling first
    stopPolling();

    // Notify server if user is connected
    if (_currentUserId != null && _isConnected) {
      try {
        await http
            .post(
              Uri.parse('$_serverUrl/disconnect'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'userId': _currentUserId}),
            )
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        developer.log('⚠️ Disconnect request failed: $e',
            name: 'HttpPollingService');
      }
    }

    // Reset state
    _currentUserId = null;
    _currentUserName = null;
    _isConnected = false;
    _reconnectAttempts = 0;

    // Notify listeners
    _connectionController.add(false);

    developer.log('✅ Disconnected successfully', name: 'HttpPollingService');
  }

  /// Reconnect to server
  Future<bool> reconnect() async {
    if (_currentUserId == null || _currentUserName == null) {
      developer.log('⚠️ Cannot reconnect: No user data',
          name: 'HttpPollingService');
      return false;
    }

    developer.log('🔄 Reconnecting to server...', name: 'HttpPollingService');

    // Disconnect first
    await disconnect();

    // Reconnect
    final success = await connect(
      userId: _currentUserId!,
      userName: _currentUserName!,
    );

    if (success) {
      // Restart polling if it was active
      if (_isPolling) {
        startPolling();
      }
      developer.log('✅ Reconnected successfully', name: 'HttpPollingService');
    } else {
      developer.log('❌ Reconnect failed', name: 'HttpPollingService');
    }

    return success;
  }

  /// Get user info for debugging
  Map<String, dynamic> getUserInfo() {
    return {
      'userId': _currentUserId,
      'userName': _currentUserName,
      'isConnected': _isConnected,
      'isPolling': _isPolling,
      'serverUrl': _serverUrl,
      'reconnectAttempts': _reconnectAttempts,
    };
  }

  // ==================== CLEANUP ====================

  /// Dispose all resources
  void dispose() {
    developer.log('♻️ Disposing HttpPollingService...',
        name: 'HttpPollingService');

    stopPolling();
    disconnect();

    _messageController.close();
    _connectionController.close();
    _pendingMessagesController.close();
    _errorController.close();

    developer.log('✅ HttpPollingService disposed', name: 'HttpPollingService');
  }

  /// ✅ FIXED: Send FCM token to server (uses developer.log instead of debugPrint)
  Future<bool> sendFCMTokenToServer({
    required String userId,
    required String fcmToken,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_serverUrl/fcm-register'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'userId': userId,
              'fcmToken': fcmToken,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      // ✅ FIXED: Changed from debugPrint to developer.log
      developer.log('❌ Error sending FCM token to server: $e',
          name: 'HttpPollingService');
      return false;
    }
  }
}
