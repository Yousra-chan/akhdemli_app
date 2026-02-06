import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_app/models/ServicesModel.dart';

class ServiceViewModel with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'services';

  bool _isLoading = false;
  String? _error;
  List<Service> _userServices = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Service> get userServices => _userServices;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Create service with individual parameters - SIMPLIFIED VERSION
  Future<bool> createServiceFromData({
    required String providerId,
    required String title,
    required String description,
    required String category,
    required String subcategory,
    required double price,
    required String priceUnit,
    required String location,
    required double? latitude,
    required double? longitude,
    required List<String> tags,
    List<String> images = const [],
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      print('Creating service with providerId: $providerId');
      print('Title: $title');
      print('Category: $category');
      print('Price: $price');

      // Create document reference
      final docRef = _firestore.collection(_collectionName).doc();

      // Create the service object
      final service = Service(
        id: docRef.id,
        providerId: providerId,
        title: title,
        description: description,
        category: category,
        subcategory: subcategory,
        price: price,
        priceUnit: priceUnit,
        location: location,
        latitude: latitude,
        longitude: longitude,
        tags: tags,
        images: images,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        rating: 0.0,
        totalReviews: 0,
      );

      print('Service object created: ${service.toMap()}');

      // Save to Firestore
      await docRef.set(service.toMap());

      print('Service saved to Firestore successfully');

      // Add to local list
      _userServices.add(service);
      notifyListeners();

      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to create service: $e');
      print('❌ Error in createServiceFromData: $e');
      print('Stack trace: ${e.toString()}');
      return false;
    }
  }

  // Get services by provider ID
  Future<List<Service>> getServicesByProviderId(String providerId) async {
    try {
      _setLoading(true);
      _setError(null);

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .get();

      _userServices =
          querySnapshot.docs.map((doc) => Service.fromFirestore(doc)).toList();

      _setLoading(false);
      return _userServices;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to fetch services: $e');
      _userServices = [];
      return [];
    }
  }

  // Update service
  Future<bool> updateService(Service service) async {
    try {
      _setLoading(true);
      _setError(null);

      await _firestore
          .collection(_collectionName)
          .doc(service.id)
          .update(service.toMap());

      // Find and update local service
      final index = _userServices.indexWhere((s) => s.id == service.id);
      if (index != -1) {
        _userServices[index] = service;
        notifyListeners();
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to update service: $e');
      return false;
    }
  }

  // Delete service
  Future<bool> deleteService(String serviceId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _firestore.collection(_collectionName).doc(serviceId).delete();
      _userServices.removeWhere((service) => service.id == serviceId);
      notifyListeners();

      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to delete service: $e');
      return false;
    }
  }

  void clearError() {
    _setError(null);
  }

  void clearServices() {
    _userServices = [];
    notifyListeners();
  }
}
