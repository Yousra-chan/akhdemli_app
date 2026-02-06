import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_app/models/ServicesModel.dart';

class ServiceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'services';

  Future<Service?> createService({
    required String providerId,
    required String title,
    required String description,
    required String category,
    required String subcategory,
    required double price,
    required String priceUnit,
    required String location,
    double? latitude,
    double? longitude,
    List<String> images = const [],
    List<String> tags = const [],
  }) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc();
      final service = Service(
        id: docRef.id,
        providerId: providerId,
        title: title,
        description: description,
        category: category,
        subcategory: subcategory,
        price: price,
        priceUnit: priceUnit,
        images: images,
        location: location,
        latitude: latitude,
        longitude: longitude,
        tags: tags,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await docRef.set(service.toMap());
      return service;
    } catch (e) {
      throw Exception('Failed to create service: $e');
    }
  }

  Future<List<Service>> getServicesByProvider(String providerId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Service.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get services: $e');
    }
  }

  Future<bool> updateService(Service service) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(service.id)
          .update(service.toMap());
      return true;
    } catch (e) {
      throw Exception('Failed to update service: $e');
    }
  }

  Future<bool> deleteService(String serviceId) async {
    try {
      await _firestore.collection(_collectionName).doc(serviceId).delete();
      return true;
    } catch (e) {
      throw Exception('Failed to delete service: $e');
    }
  }
}
