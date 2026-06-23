import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_app/models/BookingModel.dart';
import 'package:service_app/Services/booking_notification_service.dart';
import 'package:service_app/providers/language_provider.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add LanguageProvider as a static instance
  static LanguageProvider? _languageProvider;

  // Method to set the language provider (call this when app starts)
  static void setLanguageProvider(LanguageProvider provider) {
    _languageProvider = provider;
  }

  /// Helper method to get translated strings
  String _tr(String key, {Map<String, String>? params}) {
    if (_languageProvider != null) {
      if (params != null) {
        return _languageProvider!
            .trParams(key, category: 'booking_service', params: params);
      }
      return _languageProvider!.tr(key, category: 'booking_service');
    }
    return key;
  }

  /// Get translated status value for consistent status strings
  String getStatus(String statusKey) {
    return _tr(statusKey);
  }

  // Create a new booking
  Future<bool> createBooking(BookingModel booking) async {
    try {
      // 1. Create booking in Firestore with a pre-generated ID for speed
      final docRef = _firestore.collection('bookings').doc();
      final bookingWithId = booking.copyWith(id: docRef.id);
      
      await docRef.set(bookingWithId.toMap());

      debugPrint(_tr('log_booking_created', params: {'bookingId': docRef.id}));

      // ⭐ 3. SEND NOTIFICATION TO PROVIDER (Non-blocking)
      // We don't await this to keep the UI responsive
      BookingNotificationService.sendNewBookingNotification(
        clientId: booking.clientId,
        clientName: booking.clientName,
        providerId: booking.providerId,
        providerName: booking.providerName,
        serviceName: booking.serviceTitle,
        bookingId: docRef.id,
        appointmentDate: booking.appointmentDate,
      ).catchError((e) {
        debugPrint('⚠️ Non-blocking notification error: $e');
        return false;
      });

      return true;
    } catch (e) {
      debugPrint(_tr('log_error_creating_booking', params: {'error': e.toString()}));
      return false;
    }
  }

  // Get user bookings
  Stream<List<BookingModel>> getUserBookings(
      String userId, bool isProvider, String filterType) {
    try {
      Query query = _firestore
          .collection('bookings')
          .where(isProvider ? 'providerId' : 'clientId', isEqualTo: userId)
          .orderBy('appointmentDate', descending: true);

      // Apply filters based on filterType
      // We use literal strings for Firestore status values to ensure queries work across all languages
      if (filterType == 'active') {
        query = query.where('status', whereIn: [
          'pending',
          'accepted',
          'confirmed'
        ]);
      } else if (filterType == 'upcoming') {
        query = query
            .where('appointmentDate', isGreaterThan: DateTime.now())
            .where('status', whereIn: [
          'accepted',
          'confirmed'
        ]);
      } else if (filterType == 'history') {
        query = query.where('status', whereIn: [
          'completed',
          'cancelled',
          'rejected'
        ]);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return BookingModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
    } catch (e) {
      debugPrint(_tr('log_error_getting_bookings', params: {'error': e.toString()}));
      return Stream.value([]);
    }
  }

  // Update booking status
  Future<void> updateBookingStatus(String bookingId, String status) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': status,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint(_tr('log_error_updating_status', params: {'error': e.toString()}));
      throw Exception(_tr('error_status_update_failed'));
    }
  }

  // Delete booking
  Future<void> deleteBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).delete();
    } catch (e) {
      debugPrint(_tr('log_error_deleting_booking', params: {'error': e.toString()}));
      throw Exception(_tr('error_booking_deletion_failed'));
    }
  }
}
