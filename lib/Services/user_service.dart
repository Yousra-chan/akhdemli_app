import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/UserModel.dart';
import '../models/ServicesModel.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new user
  Future<void> createUser(UserModel user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    await docRef.set(user.toMap());
  }

  /// Update user profile
  Future<void> updateUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).update(user.toMap());
  }

  /// Fetch user by ID
  Future<UserModel?> getUserById(String id) async {
    final doc = await _firestore.collection('users').doc(id).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  /// Fetch all users (optional: by role)
  Future<List<UserModel>> getUsers({String? role}) async {
    Query query = _firestore.collection('users');
    if (role != null) {
      query = query.where('role', isEqualTo: role);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) =>
            UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  /// Update user's location and address
  Future<void> updateUserLocation(
    String userId,
    double lat,
    double lng,
    String address,
    String wilaya,
    String commune,
  ) async {
    await _firestore.collection('users').doc(userId).update({
      'location': GeoPoint(lat, lng),
      'address': address,
      'wilaya': wilaya,
      'commune': commune,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update user's service IDs
  Future<void> updateUserServiceIds(
    String userId,
    List<String> serviceIds,
  ) async {
    await _firestore.collection('users').doc(userId).update({
      'serviceIds': serviceIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update subscription status
  Future<void> updateSubscriptionStatus(
    String userId,
    bool isActive,
  ) async {
    await _firestore.collection('users').doc(userId).update({
      'subscriptionActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Listen to user updates in real-time
  Stream<UserModel> listenUser(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => UserModel.fromMap(doc.data()!, doc.id));
  }

  /// Get user stats
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) return {};

      final userData = userDoc.data()!;

      // Get services by this provider
      final servicesQuery = await _firestore
          .collection('services')
          .where('providerId', isEqualTo: userId)
          .get();

      // Calculate average rating
      double totalRating = 0;
      int validRatings = 0;

      for (final doc in servicesQuery.docs) {
        final data = doc.data();
        final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
        if (rating > 0) {
          totalRating += rating;
          validRatings++;
        }
      }

      final averageRating = validRatings > 0 ? totalRating / validRatings : 0.0;

      return {
        'address': userData['address'] ?? '',
        'wilaya': userData['wilaya'] ?? '',
        'commune': userData['commune'] ?? '',
        'profession': userData['profession'] ?? '',
        'serviceIds': List<String>.from(userData['serviceIds'] ?? []),
        'totalJobs': servicesQuery.docs.length,
        'rating': averageRating,
        'name': userData['name'] ?? '',
        'email': userData['email'] ?? '',
        'photoUrl': userData['photoUrl'] ?? '',
        'role': userData['role'] ?? 'client',
        'subscriptionActive': userData['subscriptionActive'] ?? false,
      };
    } catch (e) {
      print('Error getting user stats: $e');
      rethrow;
    }
  }

  /// Update user role
  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': newRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user role: $e');
      rethrow;
    }
  }

  /// Get provider services - FIXED VERSION
  Future<List<Service>> getProviderServices(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('services')
          .where('providerId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Service.fromFirestore(doc)) // Use fromFirestore instead
          .toList();
    } catch (e) {
      print('Error getting provider services: $e');
      rethrow;
    }
  }

  /// Add new service - FIXED VERSION
  Future<void> addService(Service service) async {
    try {
      // Generate a new document ID
      final docRef = _firestore.collection('services').doc();
      final serviceId = docRef.id;

      // Create service with the generated ID
      final serviceWithId = service.copyWith(id: serviceId);

      // Add to services collection
      await docRef.set(serviceWithId.toMap());

      // Update user's serviceIds array
      await _firestore.collection('users').doc(service.providerId).update({
        'serviceIds': FieldValue.arrayUnion([serviceId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding service: $e');
      rethrow;
    }
  }

  /// Update service - FIXED VERSION
  Future<void> updateService(Service service) async {
    try {
      if (service.id.isEmpty) {
        throw Exception('Service ID is required for update');
      }

      await _firestore.collection('services').doc(service.id).update({
        'title': service.title,
        'description': service.description,
        'category': service.category,
        'subcategory': service.subcategory,
        'price': service.price,
        'priceUnit': service.priceUnit,
        'location': service.location,
        'latitude': service.latitude,
        'longitude': service.longitude,
        'tags': service.tags,
        'images': service.images,
        'isActive': service.isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating service: $e');
      rethrow;
    }
  }

  /// Delete service - FIXED VERSION
  Future<void> deleteService(String serviceId, String userId) async {
    try {
      // Delete from services collection
      await _firestore.collection('services').doc(serviceId).delete();

      // Remove from user's serviceIds array
      await _firestore.collection('users').doc(userId).update({
        'serviceIds': FieldValue.arrayRemove([serviceId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error deleting service: $e');
      rethrow;
    }
  }

  /// Get service by ID
  Future<Service?> getServiceById(String serviceId) async {
    try {
      final doc = await _firestore.collection('services').doc(serviceId).get();
      if (!doc.exists) return null;
      return Service.fromFirestore(doc);
    } catch (e) {
      print('Error getting service by ID: $e');
      return null;
    }
  }
}
