import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:service_app/providers/language_provider.dart';
import 'package:flutter/foundation.dart';

class BookingNotificationService {
  static LanguageProvider? _languageProvider;
  static const String _renderServerUrl = 'https://notifications-f7n2.onrender.com';

  static void setLanguageProvider(LanguageProvider provider) {
    _languageProvider = provider;
  }

  static String _tr(String key, {Map<String, String>? params}) {
    if (_languageProvider != null) {
      return params != null 
        ? _languageProvider!.trParams(key, category: 'booking_notification_service', params: params)
        : _languageProvider!.tr(key, category: 'booking_notification_service');
    }
    return key;
  }

  /// 📅 Notify Provider about a NEW booking
  static Future<bool> sendNewBookingNotification({
    required String providerId,
    required String providerName,
    required String clientName,
    required String serviceName,
    required String clientId,
    required String bookingId,
    required DateTime appointmentDate,
  }) async {
    final title = _tr('title_booking_created');
    final body = _tr('body_booking_created', params: {
      'clientName': clientName,
      'serviceName': serviceName
    });

    return _sendAndSave(
      receiverId: providerId,
      senderId: clientId,
      senderName: clientName,
      title: title,
      body: body,
      type: 'booking',
      data: {
        'bookingId': bookingId,
        'bookingStatus': 'pending',
        'serviceName': serviceName,
      }
    );
  }

  /// 🔄 Notify Client or Provider about a STATUS update
  static Future<bool> sendBookingStatusNotification({
    required String bookingId,
    required String newStatus,
    required String providerId,
    required String clientId,
    required String providerName,
    required String clientName,
    required String serviceName,
  }) async {
    String title = '';
    String body = '';
    String receiverId = '';
    String senderId = '';
    String senderName = '';

    switch (newStatus.toLowerCase()) {
      case 'accepted':
        title = _tr('title_status_accepted');
        body = _tr('body_status_accepted', params: {'providerName': providerName, 'serviceName': serviceName});
        receiverId = clientId;
        senderId = providerId;
        senderName = providerName;
        break;
      case 'rejected':
        title = _tr('title_status_rejected');
        body = _tr('body_status_rejected', params: {'providerName': providerName});
        receiverId = clientId;
        senderId = providerId;
        senderName = providerName;
        break;
      case 'completed':
        title = _tr('title_status_completed');
        body = _tr('body_status_completed', params: {'providerName': providerName, 'serviceName': serviceName});
        receiverId = clientId;
        senderId = providerId;
        senderName = providerName;
        break;
      case 'cancelled':
        title = _tr('title_status_cancelled');
        body = _tr('body_status_cancelled', params: {'clientName': clientName, 'serviceName': serviceName});
        receiverId = providerId;
        senderId = clientId;
        senderName = clientName;
        break;
    }

    if (title.isEmpty) return false;

    return _sendAndSave(
      receiverId: receiverId,
      senderId: senderId,
      senderName: senderName,
      title: title,
      body: body,
      type: 'booking',
      data: {
        'bookingId': bookingId,
        'bookingStatus': newStatus,
        'serviceName': serviceName,
      }
    );
  }

  /// 🚀 Core logic: Send Push + Save to Firestore
  static Future<bool> _sendAndSave({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      // 1. Send Push via Render
      final response = await http.post(
        Uri.parse('$_renderServerUrl/send-notification'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'senderId': senderId,
          'receiverId': receiverId,
          'message': body,
          'senderName': senderName,
          'title': title,
          ...data,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint('✅ Booking Push Sent via Render: $receiverId');
      } else {
        debugPrint('⚠️ Booking Push failed (Status: ${response.statusCode}): ${response.body}');
      }

      // 2. Save to Firestore for Notification Page
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': receiverId,
        'senderId': senderId,
        'senderName': senderName,
        'title': title,
        'body': body,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'lastMessageTime': FieldValue.serverTimestamp(),
        ...data,
      });

      debugPrint('✅ Booking Notification Saved to DB');
      return true;
    } catch (e) {
      debugPrint('❌ Booking Notification Error: $e');
      return false;
    }
  }
}
