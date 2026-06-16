import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_app/models/ServicesModel.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';

class ServiceViewModel with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'services';

  bool _isLoading = false;
  String? _error;
  List<Service> _services = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Service> get services => _services;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
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
      setLoading(true);
      setError(null);

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
      _services.add(service);
      notifyListeners();

      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      setError('error_create_failed');
      print('❌ Error in createServiceFromData: $e');
      print('Stack trace: ${e.toString()}');
      return false;
    }
  }

  // Get services by provider ID
  Future<List<Service>> getServicesByProviderId(String providerId) async {
    try {
      setLoading(true);
      setError(null);

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .get();

      _services =
          querySnapshot.docs.map((doc) => Service.fromFirestore(doc)).toList();

      setLoading(false);
      return _services;
    } catch (e) {
      setLoading(false);
      setError('error_loading_services');
      _services = [];
      return [];
    }
  }

  // Get a specific service by ID
  Future<Service?> getServiceById(String serviceId) async {
    try {
      setLoading(true);
      setError(null);

      final docSnapshot =
          await _firestore.collection(_collectionName).doc(serviceId).get();

      if (docSnapshot.exists) {
        final service = Service.fromFirestore(docSnapshot);
        setLoading(false);
        return service;
      } else {
        setLoading(false);
        setError('error_service_not_found');
        return null;
      }
    } catch (e) {
      setLoading(false);
      setError('error_loading_services');
      return null;
    }
  }

// Update service with individual parameters
  Future<bool> updateService({
    required String serviceId,
    required String providerId, // Add providerId parameter
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
  }) async {
    try {
      setLoading(true);
      setError(null);

      // Get the existing service first to preserve some fields
      final existingService = await getServiceById(serviceId);
      if (existingService == null) {
        setError('error_service_not_found');
        setLoading(false);
        return false;
      }

      // Create updated service data - preserve existing fields
      final serviceData = {
        'title': title,
        'description': description,
        'category': category,
        'subcategory': subcategory,
        'price': price,
        'priceUnit': priceUnit,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'tags': tags,
        'updatedAt': DateTime.now(),
        'isActive': existingService.isActive, // Preserve existing status
        'rating': existingService.rating, // Preserve rating
        'totalReviews': existingService.totalReviews, // Preserve reviews
        'providerId': providerId, // Use provided providerId
        'createdAt': existingService.createdAt, // Preserve creation date
        'images': existingService.images, // Preserve images
      };

      // Update in Firestore
      await _firestore
          .collection(_collectionName)
          .doc(serviceId)
          .update(serviceData);

      // Update local state
      final index = _services.indexWhere((s) => s.id == serviceId);
      if (index != -1) {
        _services[index] = Service(
          id: serviceId,
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
          images: existingService.images,
          isActive: existingService.isActive,
          createdAt: existingService.createdAt,
          updatedAt: DateTime.now(),
          rating: existingService.rating,
          totalReviews: existingService.totalReviews,
        );
        notifyListeners();
      }

      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      setError('error_update_failed');
      print('❌ Error in updateService: $e');
      return false;
    }
  }

  // Delete service
  Future<bool> deleteService(String serviceId) async {
    try {
      setLoading(true);
      setError(null);

      await _firestore.collection(_collectionName).doc(serviceId).delete();
      _services.removeWhere((service) => service.id == serviceId);
      notifyListeners();

      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      setError('error_delete_failed');
      return false;
    }
  }

  // Toggle service active status
  Future<bool> toggleServiceStatus(String serviceId, bool isActive) async {
    try {
      setLoading(true);
      setError(null);

      await _firestore.collection(_collectionName).doc(serviceId).update({
        'isActive': isActive,
        'updatedAt': DateTime.now(),
      });

      // Update local state
      final index = _services.indexWhere((s) => s.id == serviceId);
      if (index != -1) {
        _services[index] = _services[index].copyWith(isActive: isActive);
        notifyListeners();
      }

      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      setError('error_update_failed');
      return false;
    }
  }

  void clearError() {
    setError(null);
  }

  void clearServices() {
    _services = [];
    notifyListeners();
  }
}
