// firestore_service.dart - This should be in your services folder
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_app/screens/posts/posts_constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Reference to collections
  final CollectionReference _postsCollection =
      FirebaseFirestore.instance.collection('posts');
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference _jobsCollection =
      FirebaseFirestore.instance.collection('jobs');
  final CollectionReference _reviewsCollection =
      FirebaseFirestore.instance.collection('reviews');
  final CollectionReference _servicesCollection =
      FirebaseFirestore.instance.collection('services');

  // 1. CREATE: Add a new post
  Future<void> addPost(Post post) async {
    try {
      await _postsCollection.add(post.toMap());
    } catch (e) {
      print("Error adding post: $e");
      rethrow;
    }
  }

  // 2. READ: Get a Stream of Posts (Real-time updates)
  Stream<List<Post>> getPostsStream() {
    return _postsCollection
        .orderBy('timestamp', descending: true) // Newest first
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return Post.fromMap(data, doc.id);
      }).toList();
    });
  }

  // Update user address
  Future<void> updateUserAddress(String userId, String address) async {
    try {
      await _usersCollection.doc(userId).update({
        'address': address,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user address: $e');
      rethrow;
    }
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting user profile: $e');
      rethrow;
    }
  }

  // Update user role
  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      await _usersCollection.doc(userId).update({
        'role': newRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user role: $e');
      rethrow;
    }
  }

  // Get provider services
  Future<List<Map<String, dynamic>>> getProviderServices(String userId) async {
    try {
      final querySnapshot = await _servicesCollection
          .where('providerId', isEqualTo: userId)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error getting provider services: $e');
      rethrow;
    }
  }

  // Add new service
  Future<void> addService(
      String userId, Map<String, dynamic> serviceData) async {
    try {
      await _servicesCollection.add({
        'providerId': userId,
        ...serviceData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding service: $e');
      rethrow;
    }
  }

  // Update service
  Future<void> updateService(
      String serviceId, Map<String, dynamic> serviceData) async {
    try {
      await _servicesCollection.doc(serviceId).update({
        ...serviceData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating service: $e');
      rethrow;
    }
  }

  // Delete service
  Future<void> deleteService(String serviceId) async {
    try {
      await _servicesCollection.doc(serviceId).delete();
    } catch (e) {
      print('Error deleting service: $e');
      rethrow;
    }
  }

  // Create or update user profile
  Future<void> createOrUpdateUserProfile(
      String userId, Map<String, dynamic> userData) async {
    try {
      await _usersCollection.doc(userId).set({
        ...userData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error creating/updating user profile: $e');
      rethrow;
    }
  }

  // Get ratings for a user (provider)
  Future<List<Map<String, dynamic>>> getUserRatings(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('ratings')
          .where('providerId', isEqualTo: userId)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting user ratings: $e');
      return [];
    }
  }

  // Get bookings where user is the provider
  Future<List<Map<String, dynamic>>> getBookingsByProvider(
      String providerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting bookings by provider: $e');
      return [];
    }
  }

  // Get bookings where user is the client
  Future<List<Map<String, dynamic>>> getBookingsByClient(
      String clientId) async {
    try {
      final querySnapshot = await _firestore
          .collection('bookings')
          .where('clientId', isEqualTo: clientId)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting bookings by client: $e');
      return [];
    }
  }

  // Get user services count (for providers)
  Future<int> getUserServicesCount(String providerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('services')
          .where('providerId', isEqualTo: providerId)
          .get();

      return querySnapshot.size;
    } catch (e) {
      print('Error getting user services count: $e');
      return 0;
    }
  }

  // Get original getUserStats method (if you still need it)
  Future<Map<String, dynamic>> getUserStats(String uid) async {
    try {
      // This is your original method - keep it if needed elsewhere
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      print('Error getting user stats: $e');
      return {};
    }
  }
}
