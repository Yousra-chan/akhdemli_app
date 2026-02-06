import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_app/models/BookingModel.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new booking
  Future<bool> createBooking(BookingModel booking) async {
    try {
      final docRef =
          await _firestore.collection('bookings').add(booking.toMap());

      // Update the booking ID
      await _firestore.collection('bookings').doc(docRef.id).update({
        'id': docRef.id,
      });

      return true;
    } catch (e) {
      print('Error creating booking: $e');
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
      if (filterType == 'active') {
        query = query
            .where('status', whereIn: ['pending', 'accepted', 'confirmed']);
      } else if (filterType == 'upcoming') {
        query = query
            .where('appointmentDate', isGreaterThan: DateTime.now())
            .where('status', whereIn: ['accepted', 'confirmed']);
      } else if (filterType == 'history') {
        query = query
            .where('status', whereIn: ['completed', 'cancelled', 'rejected']);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return BookingModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
    } catch (e) {
      print('Error getting bookings: $e');
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
      print('Error updating booking status: $e');
      throw e;
    }
  }

  // Delete booking
  Future<void> deleteBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).delete();
    } catch (e) {
      print('Error deleting booking: $e');
      throw e;
    }
  }
}
