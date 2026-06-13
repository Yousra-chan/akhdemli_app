import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:service_app/providers/language_provider.dart';

/// Custom exception for notification-related errors
class NotificationException implements Exception {
  final String message;
  final String? code;

  NotificationException(this.message, {this.code});

  @override
  String toString() => message;
}

/// 🔔 Booking Notification Service
///
/// Manages all notifications related to booking lifecycle events including:
/// - New booking requests
/// - Status changes (acceptance, rejection, completion, cancellation)
/// - Appointment reminders
/// - Notification history and persistence
class BookingNotificationService {
  // Add LanguageProvider as a static instance
  static LanguageProvider? _languageProvider;

  // Method to set the language provider (call this when app starts)
  static void setLanguageProvider(LanguageProvider provider) {
    _languageProvider = provider;
  }

  // Configuration
  static const String _renderServerUrl =
      'https://notifications-f7n2.onrender.com';
  static const Duration _httpTimeout = Duration(seconds: 15);
  static const int _maxRetries = 3;

  // Firestore collection constants
  static const String _usersCollection = 'users';
  static const String _notificationsCollection = 'notifications';
  static const String _bookingsCollection = 'bookings';

  // Firestore field constants
  static const String _fcmTokenField = 'fcmToken';
  static const String _receiverIdField = 'receiverId';
  static const String _typeField = 'type';
  static const String _readField = 'read';
  static const String _timestampField = 'timestamp';
  static const String _bookingIdField = 'bookingId';

  // Notification types
  static String get _notificationTypeBookingCreated =>
      _tr('notification_type_booking_created');
  static String get _notificationTypeStatusChanged =>
      _tr('notification_type_status_changed');
  static String get _notificationTypeReminder =>
      _tr('notification_type_reminder');

  // Notification status constants
  static String get _statusAccepted => _tr('status_accepted');
  static String get _statusRejected => _tr('status_rejected');
  static String get _statusCompleted => _tr('status_completed');
  static String get _statusCancelled => _tr('status_cancelled');

  static Set<String> get _validStatuses => {
        _statusAccepted,
        _statusRejected,
        _statusCompleted,
        _statusCancelled,
      };

  /// Helper method to get translated strings
  static String _tr(String key, {Map<String, String>? params}) {
    if (_languageProvider != null) {
      if (params != null) {
        return _languageProvider!.trParams(key,
            category: 'booking_notification_service', params: params);
      }
      return _languageProvider!
          .tr(key, category: 'booking_notification_service');
    }
    // Return fallback English messages if provider not set
    return _getFallbackEnglish(key, params);
  }

  /// Fallback English messages
  static String _getFallbackEnglish(String key, Map<String, String>? params) {
    final Map<String, String> fallback = {
      'notification_type_booking_created': 'booking_created',
      'notification_type_status_changed': 'booking_status_changed',
      'notification_type_reminder': 'booking_reminder',
      'status_accepted': 'accepted',
      'status_rejected': 'rejected',
      'status_completed': 'completed',
      'status_cancelled': 'cancelled',
      'title_booking_created': '📅 New Booking Request',
      'body_booking_created':
          '{clientName} requested your {serviceName} service',
      'title_status_accepted': '✅ Booking Accepted',
      'body_status_accepted':
          '{providerName} accepted your booking for {serviceName}',
      'title_status_rejected': '❌ Booking Rejected',
      'body_status_rejected': '{providerName} rejected your booking request',
      'title_status_completed': '🎉 Booking Completed',
      'body_status_completed':
          'Your booking with {providerName} for {serviceName} is complete',
      'title_status_cancelled': '❌ Booking Cancelled',
      'body_status_cancelled':
          '{clientName} cancelled their booking for {serviceName}',
      'title_reminder_one_hour': '⏰ Appointment in 1 Hour',
      'body_reminder_one_hour':
          'Your appointment with {providerName} for {serviceName} starts in 1 hour',
      'title_reminder_one_day': '📅 Appointment Tomorrow',
      'body_reminder_one_day':
          'Reminder: You have an appointment with {providerName} tomorrow for {serviceName}',
      'error_client_id_required': 'Client ID is required',
      'error_client_name_required': 'Client name is required',
      'error_provider_id_required': 'Provider ID is required',
      'error_provider_name_required': 'Provider name is required',
      'error_service_name_required': 'Service name is required',
      'error_booking_id_required': 'Booking ID is required',
      'error_invalid_users': 'Client and provider cannot be the same user',
      'error_invalid_status':
          'Invalid booking status: {status}. Must be one of: {validStatuses}',
      'error_unknown_status': 'Unknown booking status: {status}',
      'error_invalid_reminder_type':
          'Invalid reminder type: {reminderType}. Must be one of: {validReminderTypes}',
      'error_unknown_reminder_type': 'Unknown reminder type: {reminderType}',
      'error_empty_user_id': 'User ID cannot be empty',
      'error_empty_notification_id': 'Notification ID cannot be empty',
      'error_invalid_ids': 'Invalid receiver or sender ID',
      'log_sending_new_booking':
          '📤 Sending new booking notification to provider: {providerId}',
      'log_sending_status_notification':
          '📤 Sending booking status notification: {status} for booking: {bookingId}',
      'log_sending_reminder_notification':
          '📤 Sending booking reminder notification ({reminderType}) for booking: {bookingId}',
      'log_provider_no_token': '⚠️ Provider has no FCM token: {providerId}',
      'log_receiver_no_token': '⚠️ Receiver has no FCM token: {receiverId}',
      'log_client_no_token': '⚠️ Client has no FCM token: {clientId}',
      'log_user_doc_not_found': '⚠️ User document not found: {userId}',
      'log_token_empty': '⚠️ FCM token is empty for user: {userId}',
      'log_sending_attempt':
          '📱 Sending notification (attempt {attempt}/{maxRetries})',
      'log_sent_success': '✅ Notification sent successfully',
      'log_invalid_response': '⚠️ Invalid response format: {error}',
      'log_server_error': '⚠️ Server error ({statusCode}) - retrying...',
      'log_client_error': '❌ Client error ({statusCode}): {body}',
      'log_network_error': '⚠️ Network error: {error} - retrying...',
      'log_unexpected_error':
          '❌ Unexpected error sending notification: {error}',
      'log_failed_after_retries':
          '❌ Failed to send notification after {maxRetries} attempts',
      'log_notification_persisted': '✅ Notification persisted to Firestore',
      'log_error_saving_notification':
          '❌ Error saving notification to Firestore: {error}',
      'log_error_sending_notification':
          '❌ Error sending {type} notification: {error}',
      'log_error_fetching_token':
          '❌ Error fetching FCM token for user {userId}: {error}',
      'log_error_marking_read': '❌ Error marking notification as read: {error}',
      'log_error_getting_count':
          '⚠️ Error getting notification count for user {userId}: {error}',
      'log_error_notifications_stream':
          '❌ Error in notifications stream for user {userId}: {error}'
    };

    String text = fallback[key] ?? key;
    if (params != null) {
      params.forEach((key, value) {
        text = text.replaceAll('{$key}', value);
      });
    }
    return text;
  }

  /// Sends notification when a new booking is created
  ///
  /// This method:
  /// 1. Validates all input parameters
  /// 2. Retrieves provider's FCM token from Firestore
  /// 3. Sends notification via notification server
  /// 4. Saves notification record for history
  ///
  /// Parameters:
  /// - clientId: Unique identifier of booking client
  /// - clientName: Full name of client
  /// - providerId: Unique identifier of service provider
  /// - providerName: Full name of provider
  /// - serviceName: Name of the service being booked
  /// - bookingId: Unique booking reference
  /// - appointmentDate: Scheduled appointment date and time
  ///
  /// Returns: true if notification sent successfully, false otherwise
  /// Throws: NotificationException on validation failure
  static Future<bool> sendNewBookingNotification({
    required String clientId,
    required String clientName,
    required String providerId,
    required String providerName,
    required String serviceName,
    required String bookingId,
    required DateTime appointmentDate,
  }) async {
    try {
      // Validate inputs
      _validateBookingNotificationInputs(
        clientId: clientId,
        clientName: clientName,
        providerId: providerId,
        providerName: providerName,
        serviceName: serviceName,
        bookingId: bookingId,
      );

      print(_tr('log_sending_new_booking', params: {'providerId': providerId}));

      // Retrieve provider's FCM token
      final providerToken = await _fetchUserFCMToken(providerId);
      if (providerToken == null) {
        print(_tr('log_provider_no_token', params: {'providerId': providerId}));
        return false;
      }

      // Format appointment date
      final formattedDate = _formatDateTime(appointmentDate);

      final title = _tr('title_booking_created');
      final body = _tr('body_booking_created',
          params: {'clientName': clientName, 'serviceName': serviceName});

      // Send notification via HTTP with retry logic
      final success = await _sendNotificationWithRetry(
        recipientToken: providerToken,
        payload: {
          'senderId': clientId,
          'receiverId': providerId,
          'message': body,
          'senderName': clientName,
          'chatId': bookingId,
          'title': title,
          'body': body,
          'notificationType': _notificationTypeBookingCreated,
          'bookingId': bookingId,
          'appointmentDate': formattedDate,
          'serviceName': serviceName,
        },
      );

      if (success) {
        // Persist notification record asynchronously
        await _saveNotificationToFirestore(
          bookingId: bookingId,
          receiverId: providerId,
          senderId: clientId,
          senderName: clientName,
          title: title,
          body: body,
          notificationType: _notificationTypeBookingCreated,
        ).catchError((e) => print(_tr('log_error_saving_notification',
            params: {'error': e.toString()})));

        return true;
      }

      return false;
    } catch (e) {
      print(_tr('log_error_sending_notification',
          params: {'type': 'new booking', 'error': e.toString()}));
      return false;
    }
  }

  /// Sends notification when booking status changes
  ///
  /// Handles status transitions:
  /// - 'accepted': Notifies client that provider accepted
  /// - 'rejected': Notifies client that provider rejected
  /// - 'completed': Notifies client that booking is complete
  /// - 'cancelled': Notifies provider that client cancelled
  ///
  /// Parameters:
  /// - bookingId: Unique booking identifier
  /// - newStatus: New booking status (must be one of: accepted, rejected, completed, cancelled)
  /// - providerId: Provider's unique identifier
  /// - clientId: Client's unique identifier
  /// - providerName: Provider's full name
  /// - clientName: Client's full name
  /// - serviceName: Service name
  ///
  /// Returns: true if notification sent successfully, false otherwise
  /// Throws: NotificationException on validation failure
  static Future<bool> sendBookingStatusNotification({
    required String bookingId,
    required String newStatus,
    required String providerId,
    required String clientId,
    required String providerName,
    required String clientName,
    required String serviceName,
  }) async {
    try {
      // Validate inputs
      _validateStatusNotificationInputs(
        bookingId: bookingId,
        newStatus: newStatus,
        providerId: providerId,
        clientId: clientId,
        providerName: providerName,
        clientName: clientName,
        serviceName: serviceName,
      );

      final normalizedStatus = newStatus.toLowerCase();

      print(_tr('log_sending_status_notification',
          params: {'status': normalizedStatus, 'bookingId': bookingId}));

      // Determine notification recipient and content
      final contentMap = _getStatusNotificationContent(
        status: normalizedStatus,
        clientId: clientId,
        clientName: clientName,
        providerId: providerId,
        providerName: providerName,
        serviceName: serviceName,
      );
      final receiverId = contentMap['receiverId']!;
      final title = contentMap['title']!;
      final body = contentMap['body']!;
      final senderId = contentMap['senderId']!;
      final senderName = contentMap['senderName']!;

      // Retrieve receiver's FCM token
      final receiverToken = await _fetchUserFCMToken(receiverId);
      if (receiverToken == null) {
        print(_tr('log_receiver_no_token', params: {'receiverId': receiverId}));
        return false;
      }

      // Send notification with retry logic
      final success = await _sendNotificationWithRetry(
        recipientToken: receiverToken,
        payload: {
          'senderId': senderId,
          'receiverId': receiverId,
          'message': body,
          'senderName': senderName,
          'chatId': bookingId,
          'title': title,
          'body': body,
          'notificationType': _notificationTypeStatusChanged,
          'bookingId': bookingId,
          'bookingStatus': normalizedStatus,
          'serviceName': serviceName,
        },
      );

      if (success) {
        // Persist notification record asynchronously
        await _saveNotificationToFirestore(
          bookingId: bookingId,
          receiverId: receiverId,
          senderId: senderId,
          senderName: senderName,
          title: title,
          body: body,
          notificationType: _notificationTypeStatusChanged,
          status: normalizedStatus,
        ).catchError((e) => print(_tr('log_error_saving_notification',
            params: {'error': e.toString()})));

        return true;
      }

      return false;
    } catch (e) {
      print(_tr('log_error_sending_notification',
          params: {'type': 'status', 'error': e.toString()}));
      return false;
    }
  }

  /// Sends appointment reminder notification to client
  ///
  /// Supports different reminder types:
  /// - 'one_hour': Reminder 1 hour before appointment
  /// - 'one_day': Reminder 1 day before appointment
  ///
  /// Parameters:
  /// - clientId: Client's unique identifier
  /// - clientName: Client's full name
  /// - providerId: Provider's unique identifier
  /// - providerName: Provider's full name
  /// - serviceName: Service name
  /// - bookingId: Booking identifier
  /// - appointmentDate: Scheduled appointment date/time
  /// - reminderType: Type of reminder (default: 'one_hour')
  ///
  /// Returns: true if notification sent successfully, false otherwise
  /// Throws: NotificationException on validation failure
  static Future<bool> sendBookingReminderNotification({
    required String clientId,
    required String clientName,
    required String providerId,
    required String providerName,
    required String serviceName,
    required String bookingId,
    required DateTime appointmentDate,
    String reminderType = 'one_hour',
  }) async {
    try {
      // Validate inputs
      _validateReminderNotificationInputs(
        clientId: clientId,
        clientName: clientName,
        providerId: providerId,
        providerName: providerName,
        serviceName: serviceName,
        bookingId: bookingId,
        reminderType: reminderType,
      );

      print(_tr('log_sending_reminder_notification',
          params: {'reminderType': reminderType, 'bookingId': bookingId}));

      // Retrieve client's FCM token
      final clientToken = await _fetchUserFCMToken(clientId);
      if (clientToken == null) {
        print(_tr('log_client_no_token', params: {'clientId': clientId}));
        return false;
      }

      // Generate reminder message
      final messageMap = _getReminderMessageContent(
        reminderType: reminderType,
        providerName: providerName,
        serviceName: serviceName,
      );
      final title = messageMap['title']!;
      final body = messageMap['body']!;

      // Send notification with retry logic
      final success = await _sendNotificationWithRetry(
        recipientToken: clientToken,
        payload: {
          'senderId': providerId,
          'receiverId': clientId,
          'message': body,
          'senderName': providerName,
          'chatId': bookingId,
          'title': title,
          'body': body,
          'notificationType': _notificationTypeReminder,
          'bookingId': bookingId,
          'reminderType': reminderType,
          'serviceName': serviceName,
        },
      );

      if (success) {
        // Persist notification record asynchronously
        await _saveNotificationToFirestore(
          bookingId: bookingId,
          receiverId: clientId,
          senderId: providerId,
          senderName: providerName,
          title: title,
          body: body,
          notificationType: _notificationTypeReminder,
        ).catchError((e) => print(_tr('log_error_saving_notification',
            params: {'error': e.toString()})));

        return true;
      }

      return false;
    } catch (e) {
      print(_tr('log_error_sending_notification',
          params: {'type': 'reminder', 'error': e.toString()}));
      return false;
    }
  }

  /// Retrieves count of unread booking notifications for user
  ///
  /// Parameters:
  /// - userId: User's unique identifier
  ///
  /// Returns: Count of unread notifications (0 if error or no notifications)
  static Future<int> getUnreadBookingNotificationCount(String userId) async {
    try {
      if (userId.isEmpty) {
        throw NotificationException(
          _tr('error_empty_user_id'),
          code: 'empty-user-id',
        );
      }

      final snapshot = await FirebaseFirestore.instance
          .collection(_notificationsCollection)
          .where(_receiverIdField, isEqualTo: userId)
          .where(_typeField, isEqualTo: 'booking')
          .where(_readField, isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print(_tr('log_error_getting_count',
          params: {'userId': userId, 'error': e.toString()}));
      return 0;
    }
  }

  /// Marks a notification as read
  ///
  /// Parameters:
  /// - notificationId: Document ID of notification in Firestore
  ///
  /// Throws: NotificationException on failure
  static Future<void> markBookingNotificationAsRead(
      String notificationId) async {
    try {
      if (notificationId.isEmpty) {
        throw NotificationException(
          _tr('error_empty_notification_id'),
          code: 'empty-notification-id',
        );
      }

      await FirebaseFirestore.instance
          .collection(_notificationsCollection)
          .doc(notificationId)
          .update({
        _readField: true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print(_tr('log_error_marking_read', params: {'error': e.toString()}));
      rethrow;
    }
  }

  /// Provides real-time stream of booking notifications for user
  ///
  /// Parameters:
  /// - userId: User's unique identifier
  ///
  /// Returns: Stream of notification documents ordered by timestamp (newest first)
  /// Each notification includes its Firestore document ID
  static Stream<List<Map<String, dynamic>>> getBookingNotificationsStream(
      String userId) {
    if (userId.isEmpty) {
      return Stream.error(
        NotificationException(
          _tr('error_empty_user_id'),
          code: 'empty-user-id',
        ),
      );
    }

    return FirebaseFirestore.instance
        .collection(_notificationsCollection)
        .where(_receiverIdField, isEqualTo: userId)
        .where(_typeField, isEqualTo: 'booking')
        .orderBy(_timestampField, descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    }).handleError((error) {
      print(_tr('log_error_notifications_stream',
          params: {'userId': userId, 'error': error.toString()}));
    });
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Fetches FCM token for a user from Firestore
  ///
  /// Returns: FCM token string if found and not empty, null otherwise
  static Future<String?> _fetchUserFCMToken(String userId) async {
    try {
      if (userId.isEmpty) {
        return null;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        print(_tr('log_user_doc_not_found', params: {'userId': userId}));
        return null;
      }

      final userData = userDoc.data();
      final token = userData?[_fcmTokenField] as String?;

      if (token == null || token.isEmpty) {
        print(_tr('log_token_empty', params: {'userId': userId}));
        return null;
      }

      return token;
    } catch (e) {
      print(_tr('log_error_fetching_token',
          params: {'userId': userId, 'error': e.toString()}));
      return null;
    }
  }

  /// Sends notification via HTTP to notification server with automatic retry logic
  ///
  /// Implements exponential backoff retry strategy:
  /// - Maximum 3 attempts
  /// - 1 second delay between retries
  /// - 15 second timeout per request
  static Future<bool> _sendNotificationWithRetry({
    required String recipientToken,
    required Map<String, dynamic> payload,
  }) async {
    int attemptCount = 0;

    while (attemptCount < _maxRetries) {
      try {
        print(_tr('log_sending_attempt', params: {
          'attempt': (attemptCount + 1).toString(),
          'maxRetries': _maxRetries.toString()
        }));

        final response = await http
            .post(
              Uri.parse('$_renderServerUrl/send-notification'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'User-Agent': 'BookingNotificationService/1.0',
              },
              body: json.encode(payload),
            )
            .timeout(_httpTimeout);

        if (response.statusCode == 200) {
          try {
            final result = json.decode(response.body);
            if (result['success'] == true) {
              print(_tr('log_sent_success'));
              return true;
            }
          } catch (e) {
            print(_tr('log_invalid_response', params: {'error': e.toString()}));
          }
        } else if (response.statusCode >= 500) {
          // Server error - retry
          print(_tr('log_server_error', params: {
            'statusCode': response.statusCode.toString(),
            'body': response.body
          }));
          attemptCount++;
          if (attemptCount < _maxRetries) {
            await Future.delayed(Duration(seconds: attemptCount));
          }
          continue;
        } else {
          // Client error - don't retry
          print(_tr('log_client_error', params: {
            'statusCode': response.statusCode.toString(),
            'body': response.body
          }));
          return false;
        }
      } on http.ClientException catch (e) {
        print(_tr('log_network_error', params: {'error': e.toString()}));
        attemptCount++;
        if (attemptCount < _maxRetries) {
          await Future.delayed(Duration(seconds: attemptCount));
        }
      } catch (e) {
        print(_tr('log_unexpected_error', params: {'error': e.toString()}));
        return false;
      }
    }

    print(_tr('log_failed_after_retries',
        params: {'maxRetries': _maxRetries.toString()}));
    return false;
  }

  /// Saves notification record to Firestore for history and audit trail
  static Future<void> _saveNotificationToFirestore({
    required String bookingId,
    required String receiverId,
    required String senderId,
    required String senderName,
    required String title,
    required String body,
    required String notificationType,
    String? status,
  }) async {
    try {
      if (receiverId.isEmpty || senderId.isEmpty) {
        throw NotificationException(
          _tr('error_invalid_ids'),
          code: 'invalid-ids',
        );
      }

      final data = {
        _bookingIdField: bookingId,
        _receiverIdField: receiverId,
        'senderId': senderId,
        'senderName': senderName,
        _typeField: 'booking',
        'title': title,
        'body': body,
        'notificationType': notificationType,
        _readField: false,
        _timestampField: FieldValue.serverTimestamp(),
      };

      if (status != null) {
        data['bookingStatus'] = status;
      }

      await FirebaseFirestore.instance
          .collection(_notificationsCollection)
          .add(data);

      print(_tr('log_notification_persisted'));
    } catch (e) {
      print(_tr('log_error_saving_notification',
          params: {'error': e.toString()}));
      rethrow;
    }
  }

  /// Determines notification recipient and message content based on status change
  static Map<String, String> _getStatusNotificationContent({
    required String status,
    required String clientId,
    required String clientName,
    required String providerId,
    required String providerName,
    required String serviceName,
  }) {
    switch (status) {
      case 'accepted':
        return {
          'receiverId': clientId,
          'title': _tr('title_status_accepted'),
          'body': _tr('body_status_accepted', params: {
            'providerName': providerName,
            'serviceName': serviceName
          }),
          'senderId': providerId,
          'senderName': providerName,
        };
      case 'rejected':
        return {
          'receiverId': clientId,
          'title': _tr('title_status_rejected'),
          'body': _tr('body_status_rejected',
              params: {'providerName': providerName}),
          'senderId': providerId,
          'senderName': providerName,
        };
      case 'completed':
        return {
          'receiverId': clientId,
          'title': _tr('title_status_completed'),
          'body': _tr('body_status_completed', params: {
            'providerName': providerName,
            'serviceName': serviceName
          }),
          'senderId': providerId,
          'senderName': providerName,
        };
      case 'cancelled':
        return {
          'receiverId': providerId,
          'title': _tr('title_status_cancelled'),
          'body': _tr('body_status_cancelled',
              params: {'clientName': clientName, 'serviceName': serviceName}),
          'senderId': clientId,
          'senderName': clientName,
        };
      default:
        throw NotificationException(
          _tr('error_unknown_status', params: {'status': status}),
          code: 'unknown-status',
        );
    }
  }

  /// Generates reminder message content based on reminder type
  static Map<String, String> _getReminderMessageContent({
    required String reminderType,
    required String providerName,
    required String serviceName,
  }) {
    if (reminderType == 'one_hour') {
      return {
        'title': _tr('title_reminder_one_hour'),
        'body': _tr('body_reminder_one_hour',
            params: {'providerName': providerName, 'serviceName': serviceName}),
      };
    } else if (reminderType == 'one_day') {
      return {
        'title': _tr('title_reminder_one_day'),
        'body': _tr('body_reminder_one_day',
            params: {'providerName': providerName, 'serviceName': serviceName}),
      };
    } else {
      throw NotificationException(
        _tr('error_unknown_reminder_type',
            params: {'reminderType': reminderType}),
        code: 'unknown-reminder-type',
      );
    }
  }

  /// Formats DateTime to readable string format
  static String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year at $hour:$minute';
  }

  // ============================================================================
  // INPUT VALIDATION METHODS
  // ============================================================================

  /// Validates booking notification input parameters
  static void _validateBookingNotificationInputs({
    required String clientId,
    required String clientName,
    required String providerId,
    required String providerName,
    required String serviceName,
    required String bookingId,
  }) {
    if (clientId.isEmpty) {
      throw NotificationException(
        _tr('error_client_id_required'),
        code: 'empty-client-id',
      );
    }

    if (clientName.isEmpty) {
      throw NotificationException(
        _tr('error_client_name_required'),
        code: 'empty-client-name',
      );
    }

    if (providerId.isEmpty) {
      throw NotificationException(
        _tr('error_provider_id_required'),
        code: 'empty-provider-id',
      );
    }

    if (providerName.isEmpty) {
      throw NotificationException(
        _tr('error_provider_name_required'),
        code: 'empty-provider-name',
      );
    }

    if (serviceName.isEmpty) {
      throw NotificationException(
        _tr('error_service_name_required'),
        code: 'empty-service-name',
      );
    }

    if (bookingId.isEmpty) {
      throw NotificationException(
        _tr('error_booking_id_required'),
        code: 'empty-booking-id',
      );
    }

    if (clientId == providerId) {
      throw NotificationException(
        _tr('error_invalid_users'),
        code: 'invalid-users',
      );
    }
  }

  /// Validates status notification input parameters
  static void _validateStatusNotificationInputs({
    required String bookingId,
    required String newStatus,
    required String providerId,
    required String clientId,
    required String providerName,
    required String clientName,
    required String serviceName,
  }) {
    if (bookingId.isEmpty) {
      throw NotificationException(
        _tr('error_booking_id_required'),
        code: 'empty-booking-id',
      );
    }

    if (!_validStatuses.contains(newStatus.toLowerCase())) {
      throw NotificationException(
        _tr('error_invalid_status', params: {
          'status': newStatus,
          'validStatuses': _validStatuses.join(", ")
        }),
        code: 'invalid-status',
      );
    }

    if (providerId.isEmpty) {
      throw NotificationException(
        _tr('error_provider_id_required'),
        code: 'empty-provider-id',
      );
    }

    if (clientId.isEmpty) {
      throw NotificationException(
        _tr('error_client_id_required'),
        code: 'empty-client-id',
      );
    }

    if (providerName.isEmpty) {
      throw NotificationException(
        _tr('error_provider_name_required'),
        code: 'empty-provider-name',
      );
    }

    if (clientName.isEmpty) {
      throw NotificationException(
        _tr('error_client_name_required'),
        code: 'empty-client-name',
      );
    }

    if (serviceName.isEmpty) {
      throw NotificationException(
        _tr('error_service_name_required'),
        code: 'empty-service-name',
      );
    }
  }

  /// Validates reminder notification input parameters
  static void _validateReminderNotificationInputs({
    required String clientId,
    required String clientName,
    required String providerId,
    required String providerName,
    required String serviceName,
    required String bookingId,
    required String reminderType,
  }) {
    _validateBookingNotificationInputs(
      clientId: clientId,
      clientName: clientName,
      providerId: providerId,
      providerName: providerName,
      serviceName: serviceName,
      bookingId: bookingId,
    );

    const validReminderTypes = ['one_hour', 'one_day'];
    if (!validReminderTypes.contains(reminderType)) {
      throw NotificationException(
        _tr('error_invalid_reminder_type', params: {
          'reminderType': reminderType,
          'validReminderTypes': validReminderTypes.join(", ")
        }),
        code: 'invalid-reminder-type',
      );
    }
  }
}
