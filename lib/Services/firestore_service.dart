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

  // USER PROFILE METHODS

  // Get user stats including address, total jobs, rating, etc.
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      // Get user document
      final userDoc = await _usersCollection.doc(userId).get();

      Map<String, dynamic> userData = {};

      if (userDoc.exists) {
        userData = userDoc.data() as Map<String, dynamic>? ?? {};

        // Get jobs statistics
        final jobsQuery =
            await _jobsCollection.where('userId', isEqualTo: userId).get();

        final completedJobsQuery = await _jobsCollection
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'completed')
            .get();

        // Calculate rating from reviews
        final reviewsQuery = await _reviewsCollection
            .where('targetUserId', isEqualTo: userId)
            .get();

        double averageRating = 0.0;
        if (reviewsQuery.docs.isNotEmpty) {
          double totalRating = 0;
          int validReviews = 0;

          for (final doc in reviewsQuery.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null &&
                data.containsKey('rating') &&
                data['rating'] != null) {
              totalRating += (data['rating'] as num).toDouble();
              validReviews++;
            }
          }

          if (validReviews > 0) {
            averageRating = totalRating / validReviews;
          }
        }

        return {
          'address': userData['address'] ?? '',
          'totalJobs': jobsQuery.docs.length,
          'completedJobs': completedJobsQuery.docs.length,
          'rating': averageRating,
          'name': userData['name'] ?? '',
          'email': userData['email'] ?? '',
          'photoUrl': userData['photoUrl'] ?? '',
          'role': userData['role'] ?? 'client',
        };
      }

      return {};
    } catch (e) {
      print('Error getting user stats: $e');
      rethrow;
    }
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
}
