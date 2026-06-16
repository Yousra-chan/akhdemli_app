import 'dart:async';
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
    // Return fallback English messages if provider not set
    return _getFallbackEnglish(key, params);
  }

  /// Fallback English messages
  String _getFallbackEnglish(String key, Map<String, String>? params) {
    final Map<String, String> fallback = {
      'log_booking_created': '✅ Booking created with ID: {bookingId}',
      'log_attempting_notification':
          '📤 Attempting to send booking notification...',
      'log_notification_sent':
          '✅ Booking notification sent successfully to provider',
      'log_notification_failed': '⚠️ Booking notification failed to send',
      'log_notification_error':
          '⚠️ Error sending booking notification: {error}',
      'log_error_creating_booking': '❌ Error creating booking: {error}',
      'log_error_getting_bookings': 'Error getting bookings: {error}',
      'log_error_updating_status': 'Error updating booking status: {error}',
      'log_error_deleting_booking': 'Error deleting booking: {error}',
      'error_booking_creation_failed': 'Failed to create booking',
      'error_status_update_failed': 'Failed to update booking status',
      'error_booking_deletion_failed': 'Failed to delete booking',
      'status_pending': 'pending',
      'status_accepted': 'accepted',
      'status_confirmed': 'confirmed',
      'status_completed': 'completed',
      'status_cancelled': 'cancelled',
      'status_rejected': 'rejected',
    };

    String text = fallback[key] ?? key;
    if (params != null) {
      params.forEach((key, value) {
        text = text.replaceAll('{$key}', value);
      });
    }
    return text;
  }

  /// Get translated status value for consistent status strings
  String getStatus(String statusKey) {
    return _tr(statusKey);
  }

  // Create a new booking
  Future<bool> createBooking(BookingModel booking) async {
    try {
      // 1. Create booking in Firestore
      final docRef =
          await _firestore.collection('bookings').add(booking.toMap());

      // 2. Update the booking ID
      await _firestore.collection('bookings').doc(docRef.id).update({
        'id': docRef.id,
      });

      print(_tr('log_booking_created', params: {'bookingId': docRef.id}));

      // ⭐ 3. SEND NOTIFICATION TO PROVIDER
      try {
        print(_tr('log_attempting_notification'));

        final notificationSent =
            await BookingNotificationService.sendNewBookingNotification(
          clientId: booking.clientId,
          clientName: booking.clientName,
          providerId: booking.providerId,
          providerName: booking.providerName,
          serviceName: booking.serviceTitle,
          bookingId: docRef.id,
          appointmentDate: booking.appointmentDate,
        );

        if (notificationSent) {
          print(_tr('log_notification_sent'));
        } else {
          print(_tr('log_notification_failed'));
        }
      } catch (notificationError) {
        // Don't fail the entire booking if notification fails
        print(_tr('log_notification_error',
            params: {'error': notificationError.toString()}));
        // Booking is still created, just notification failed
      }

      return true;
    } catch (e) {
      print(_tr('log_error_creating_booking', params: {'error': e.toString()}));
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
      print(_tr('log_error_getting_bookings', params: {'error': e.toString()}));
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
      print(_tr('log_error_updating_status', params: {'error': e.toString()}));
      throw Exception(_tr('error_status_update_failed'));
    }
  }

  // Delete booking
  Future<void> deleteBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).delete();
    } catch (e) {
      print(_tr('log_error_deleting_booking', params: {'error': e.toString()}));
      throw Exception(_tr('error_booking_deletion_failed'));
    }
  }
}
