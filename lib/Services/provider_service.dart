import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/models/ProviderModel.dart';

class ProviderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'users';

  /// Get all active providers
  Future<List<ProviderModel>> getAllProviders() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('role', isEqualTo: 'provider')
          .where('subscriptionActive', isEqualTo: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final user = UserModel.fromMap(doc.data(), doc.id);
        return ProviderModel.fromUser(user);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get all providers: $e');
    }
  }

  // Get provider by ID
  Future<ProviderModel?> getProviderById(String providerId) async {
    try {
      final doc =
          await _firestore.collection(_collectionName).doc(providerId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;

      // Check if user is actually a provider
      if (data['role'] != 'provider') {
        return null;
      }

      final user = UserModel.fromMap(data, doc.id);
      return ProviderModel.fromUser(user);
    } catch (e) {
      throw Exception('Failed to get provider: $e');
    }
  }

  // Get provider gallery images
  Future<List<String>> getProviderGallery(String providerId) async {
    try {
      final doc = await _firestore
          .collection('provider_galleries')
          .doc(providerId)
          .get();

      if (!doc.exists) {
        return [];
      }

      final data = doc.data() as Map<String, dynamic>;
      final images = data['images'] as List<dynamic>?;

      return images?.cast<String>() ?? [];
    } catch (e) {
      return [];
    }
  }

  // Get featured providers
  Future<List<ProviderModel>> getFeaturedProviders({int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('role', isEqualTo: 'provider')
          .where('subscriptionActive', isEqualTo: true)
          .where('rating', isGreaterThan: 4.0)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) {
        final user = UserModel.fromMap(doc.data(), doc.id);
        return ProviderModel.fromUser(user);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get featured providers: $e');
    }
  }

  // Get providers by category
  Future<List<ProviderModel>> getProvidersByCategory(String category) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('role', isEqualTo: 'provider')
          .where('subscriptionActive', isEqualTo: true)
          .where('serviceCategories', arrayContains: category)
          .get();

      return querySnapshot.docs.map((doc) {
        final user = UserModel.fromMap(doc.data(), doc.id);
        return ProviderModel.fromUser(user);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get providers by category: $e');
    }
  }

  // Update provider rating
  Future<void> updateProviderRating(String providerId, double newRating) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(providerId)
          .update({'rating': newRating});
    } catch (e) {
      throw Exception('Failed to update provider rating: $e');
    }
  }

  // Check if provider exists and is active
  Future<bool> isProviderActive(String providerId) async {
    try {
      final doc =
          await _firestore.collection(_collectionName).doc(providerId).get();

      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      return data['role'] == 'provider' &&
          (data['subscriptionActive'] ?? false);
    } catch (e) {
      throw Exception('Failed to check provider status: $e');
    }
  }
}
