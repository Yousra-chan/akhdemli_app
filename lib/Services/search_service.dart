import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/models/ServicesModel.dart';
import 'package:service_app/Services/categories_service.dart';
import 'dart:math';

/// Custom exception for search-related errors
class SearchException implements Exception {
  final String message;
  final String? code;

  SearchException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Search Service for providers and services
///
/// Handles all search operations including:
/// - Provider search by name/profession
/// - Service search by title/description/category
/// - Filtered searches with multiple criteria
/// - Category and location-based searches
/// - Distance calculations
class SearchService {
  // Firestore instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CategoriesService _categoriesService = CategoriesService();

  // Firestore collection and field constants
  static const String _usersCollection = 'users';
  static const String _servicesCollection = 'services';

  // User fields
  static const String _roleField = 'role';
  static const String _roleProvider = 'provider';
  static const String _nameField = 'name';
  static const String _professionField = 'profession';
  static const String _wilayaField = 'wilaya';
  static const String _communeField = 'commune';
  static const String _ratingField = 'rating';
  static const String _subscriptionActiveField = 'subscriptionActive';
  static const String _isActiveField = 'isActive';

  // Service fields
  static const String _titleField = 'title';
  static const String _descriptionField = 'description';
  static const String _categoryField = 'category';
  static const String _subcategoryField = 'subcategory';
  static const String _providerIdField = 'providerId';
  static const String _createdAtField = 'createdAt';

  // Constants
  static const double _earthRadiusKm = 6371.0;
  static const int _maxSearchResults = 100;
  static const String _allCategoriesValue = 'All';
  static const String _allServicesValue = 'All Services';

  /// Searches providers by profession or name
  ///
  /// Parameters:
  /// - query: Search term (name or profession)
  ///
  /// Returns: List of matching providers
  /// Throws: SearchException on invalid input
  Future<List<ProviderModel>> searchProvidersByProfessionOrName(
    String query,
  ) async {
    try {
      _validateSearchQuery(query);

      final lowerQuery = query.trim().toLowerCase();

      // Query users collection for providers
      final snapshot = await _firestore
          .collection(_usersCollection)
          .where(_roleField, isEqualTo: _roleProvider)
          .get();

      final results = <ProviderModel>[];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final name = data[_nameField]?.toString().toLowerCase() ?? '';
        final profession =
            data[_professionField]?.toString().toLowerCase() ?? '';

        // Match if query found in name or profession
        if (name.contains(lowerQuery) || profession.contains(lowerQuery)) {
          try {
            results.add(ProviderModel.fromFirestore(data, doc.id));
          } catch (e) {
            print('Warning: Could not parse provider ${doc.id}: $e');
          }
        }
      }

      return results;
    } on SearchException {
      rethrow;
    } catch (e) {
      print('Error searching providers by profession/name: $e');
      return [];
    }
  }

  /// Searches services by title, description, category, or subcategory
  ///
  /// Parameters:
  /// - query: Search term
  ///
  /// Returns: List of matching active services
  /// Throws: SearchException on invalid input
  Future<List<Service>> searchServices(String query) async {
    try {
      _validateSearchQuery(query);

      final lowerQuery = query.trim().toLowerCase();

      final snapshot = await _firestore
          .collection(_servicesCollection)
          .where(_isActiveField, isEqualTo: true)
          .get();

      final results = <Service>[];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final title = data[_titleField]?.toString().toLowerCase() ?? '';
        final description =
            data[_descriptionField]?.toString().toLowerCase() ?? '';
        final category = data[_categoryField]?.toString().toLowerCase() ?? '';
        final subcategory =
            data[_subcategoryField]?.toString().toLowerCase() ?? '';

        // Match if query found in any field
        if (title.contains(lowerQuery) ||
            description.contains(lowerQuery) ||
            category.contains(lowerQuery) ||
            subcategory.contains(lowerQuery)) {
          try {
            results.add(Service.fromMap({...data, 'id': doc.id}));
          } catch (e) {
            print('Warning: Could not parse service ${doc.id}: $e');
          }
        }
      }

      return results;
    } on SearchException {
      rethrow;
    } catch (e) {
      print('Error searching services: $e');
      return [];
    }
  }

  /// Searches providers with multiple filter criteria
  ///
  /// Supported filters:
  /// - wilaya: Location (state/province)
  /// - commune: Location (city/district)
  /// - category: Service category (handled separately via provider services)
  /// - minRating: Minimum provider rating
  /// - subscriptionActive: Active subscription status
  ///
  /// Parameters:
  /// - filters: Map of filter criteria
  ///
  /// Returns: List of providers matching all filters
  Future<List<ProviderModel>> searchProvidersWithFilters(
    Map<String, dynamic> filters,
  ) async {
    try {
      _validateFiltersMap(filters);

      // Handle category filter separately as it requires service lookup
      if (filters.containsKey(_categoryField) &&
          filters[_categoryField] != null) {
        return await searchProvidersByCategoryWithFilters(filters);
      }

      Query query = _firestore
          .collection(_usersCollection)
          .where(_roleField, isEqualTo: _roleProvider);

      // Apply wilaya filter
      if (filters.containsKey(_wilayaField) && filters[_wilayaField] != null) {
        query = query.where(_wilayaField, isEqualTo: filters[_wilayaField]);
      }

      // Apply commune filter
      if (filters.containsKey(_communeField) &&
          filters[_communeField] != null) {
        query = query.where(_communeField, isEqualTo: filters[_communeField]);
      }

      // Apply minimum rating filter
      if (filters.containsKey(_ratingField) && filters[_ratingField] != null) {
        final minRating = _parseNumericValue(filters[_ratingField]);
        query = query.where(_ratingField, isGreaterThanOrEqualTo: minRating);
      }

      // Apply subscription filter
      if (filters.containsKey(_subscriptionActiveField) &&
          filters[_subscriptionActiveField] != null) {
        query = query.where(
          _subscriptionActiveField,
          isEqualTo: filters[_subscriptionActiveField],
        );
      }

      final snapshot = await query.get();

      final providers = <ProviderModel>[];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        try {
          providers.add(ProviderModel.fromFirestore(data, doc.id));
        } catch (e) {
          print('Warning: Could not parse provider ${doc.id}: $e');
        }
      }

      return providers;
    } catch (e) {
      print('Error searching providers with filters: $e');
      return [];
    }
  }

  /// Searches providers by category with additional filters
  ///
  /// Parameters:
  /// - filters: Map containing category and optional subcategory, location, rating filters
  ///
  /// Returns: List of providers in the specified category
  Future<List<ProviderModel>> searchProvidersByCategoryWithFilters(
    Map<String, dynamic> filters,
  ) async {
    try {
      _validateFiltersMap(filters);

      final category = filters[_categoryField] as String?;
      if (category == null || category.isEmpty) {
        throw SearchException('Category is required', code: 'empty-category');
      }

      // Build services query
      Query servicesQuery = _firestore
          .collection(_servicesCollection)
          .where(_categoryField, isEqualTo: category)
          .where(_isActiveField, isEqualTo: true);

      // Apply subcategory filter if provided
      if (filters.containsKey(_subcategoryField) &&
          filters[_subcategoryField] != null) {
        servicesQuery = servicesQuery.where(
          _subcategoryField,
          isEqualTo: filters[_subcategoryField],
        );
      }

      final servicesSnapshot = await servicesQuery.get();

      if (servicesSnapshot.docs.isEmpty) {
        return [];
      }

      // Extract unique provider IDs from services
      final providerIds = _extractProviderIds(servicesSnapshot.docs);

      if (providerIds.isEmpty) {
        return [];
      }

      // Fetch providers and apply additional filters
      final providers = <ProviderModel>[];

      for (var providerId in providerIds) {
        try {
          final providerDoc = await _firestore
              .collection(_usersCollection)
              .doc(providerId)
              .get();

          if (!providerDoc.exists) continue;

          final data = providerDoc.data();
          if (data == null) continue;

          // Verify is provider
          if (data[_roleField] != _roleProvider) continue;

          // Apply additional filters
          if (_passesLocationFilters(data, filters) &&
              _passesRatingFilter(data, filters) &&
              _passesSubscriptionFilter(data, filters)) {
            providers.add(ProviderModel.fromFirestore(data, providerId));
          }
        } catch (e) {
          print('Warning: Error fetching provider $providerId: $e');
        }
      }

      return providers;
    } catch (e) {
      print('Error in searchProvidersByCategoryWithFilters: $e');
      return [];
    }
  }

  /// Retrieves available categories and subcategories
  ///
  /// Returns: Map of categories to their subcategories
  Future<Map<String, List<String>>> getAvailableCategories() async {
    try {
      return await _categoriesService.getCategoriesForFilter();
    } catch (e) {
      print('Error getting available categories: $e');
      return {};
    }
  }

  /// Retrieves all available wilayas (locations) from active providers
  ///
  /// Returns: Sorted list of unique wilaya names
  Future<List<String>> getAvailableWilayas() async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .where(_roleField, isEqualTo: _roleProvider)
          .where(_wilayaField, isNotEqualTo: null)
          .get();

      final wilayas = <String>{};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final wilaya = data[_wilayaField] as String?;
        if (wilaya != null && wilaya.isNotEmpty) {
          wilayas.add(wilaya);
        }
      }

      return wilayas.toList()..sort();
    } catch (e) {
      print('Error getting available wilayas: $e');
      return [];
    }
  }

  /// Retrieves all services offered by a specific provider
  ///
  /// Parameters:
  /// - providerId: Unique provider identifier
  ///
  /// Returns: List of active services by provider, ordered by creation date
  /// Throws: SearchException on invalid provider ID
  Future<List<Service>> getServicesByProvider(String providerId) async {
    try {
      _validateProviderId(providerId);

      final snapshot = await _firestore
          .collection(_servicesCollection)
          .where(_providerIdField, isEqualTo: providerId)
          .where(_isActiveField, isEqualTo: true)
          .orderBy(_createdAtField, descending: true)
          .get();

      final services = <Service>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        try {
          services.add(Service.fromMap({...data, 'id': doc.id}));
        } catch (e) {
          print('Warning: Could not parse service ${doc.id}: $e');
        }
      }

      return services;
    } on SearchException {
      rethrow;
    } catch (e) {
      print('Error getting services by provider: $e');
      return [];
    }
  }

  /// Searches providers by single category
  ///
  /// Parameters:
  /// - category: Service category (use 'All' for all categories)
  ///
  /// Returns: List of active providers offering services in category
  /// Throws: SearchException on invalid input
  Future<List<ProviderModel>> searchProvidersByCategory(String category) async {
    try {
      _validateCategoryValue(category);

      // Return all providers if 'All' category selected
      if (category == _allCategoriesValue) {
        return getAllActiveProviders();
      }

      // Query services by category
      final servicesSnapshot = await _firestore
          .collection(_servicesCollection)
          .where(_categoryField, isEqualTo: category)
          .where(_isActiveField, isEqualTo: true)
          .get();

      if (servicesSnapshot.docs.isEmpty) {
        return [];
      }

      // Extract provider IDs
      final providerIds = _extractProviderIds(servicesSnapshot.docs);

      if (providerIds.isEmpty) {
        return [];
      }

      // Fetch provider details
      final providers = <ProviderModel>[];

      for (var providerId in providerIds) {
        try {
          final providerDoc = await _firestore
              .collection(_usersCollection)
              .doc(providerId)
              .get();

          if (!providerDoc.exists) continue;

          final data = providerDoc.data();
          if (data == null) continue;

          // Verify is active provider
          final role = data[_roleField] as String?;
          final isActive = data[_isActiveField] as bool? ?? true;

          if (role == _roleProvider && isActive) {
            providers.add(ProviderModel.fromFirestore(data, providerId));
          }
        } catch (e) {
          print('Warning: Error fetching provider $providerId: $e');
        }
      }

      return providers;
    } on SearchException {
      rethrow;
    } catch (e) {
      print('Error in searchProvidersByCategory: $e');
      return [];
    }
  }

  /// Searches providers by category and subcategory
  ///
  /// Parameters:
  /// - category: Service category (use 'All' for all)
  /// - subcategory: Service subcategory (use 'All Services' for all)
  ///
  /// Returns: List of active providers in specified category/subcategory
  /// Throws: SearchException on invalid input
  Future<List<ProviderModel>> searchProvidersByCategoryAndSubcategory(
    String category,
    String subcategory,
  ) async {
    try {
      _validateCategoryValue(category);
      _validateSubcategoryValue(subcategory);

      // Build services query
      Query servicesQuery = _firestore.collection(_servicesCollection);

      // Apply category filter
      if (category != _allCategoriesValue) {
        servicesQuery =
            servicesQuery.where(_categoryField, isEqualTo: category);
      }

      // Apply subcategory filter
      if (subcategory != _allServicesValue) {
        servicesQuery =
            servicesQuery.where(_subcategoryField, isEqualTo: subcategory);
      }

      // Filter active services
      servicesQuery = servicesQuery.where(_isActiveField, isEqualTo: true);

      final servicesSnapshot = await servicesQuery.get();

      if (servicesSnapshot.docs.isEmpty) {
        return [];
      }

      // Extract provider IDs
      final providerIds = _extractProviderIds(servicesSnapshot.docs);

      if (providerIds.isEmpty) {
        return [];
      }

      // Fetch providers
      final providers = <ProviderModel>[];

      for (var providerId in providerIds) {
        try {
          final providerDoc = await _firestore
              .collection(_usersCollection)
              .doc(providerId)
              .get();

          if (!providerDoc.exists) continue;

          final data = providerDoc.data();
          if (data == null) continue;

          // Verify is active provider
          final role = data[_roleField] as String?;
          final isActive = data[_isActiveField] as bool? ?? true;

          if (role == _roleProvider && isActive) {
            providers.add(ProviderModel.fromFirestore(data, providerId));
          }
        } catch (e) {
          print('Warning: Error fetching provider $providerId: $e');
        }
      }

      return providers;
    } on SearchException {
      rethrow;
    } catch (e) {
      print('Error in searchProvidersByCategoryAndSubcategory: $e');
      return [];
    }
  }

  /// Retrieves all active providers
  ///
  /// Returns: List of all active providers
  Future<List<ProviderModel>> getAllActiveProviders() async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .where(_roleField, isEqualTo: _roleProvider)
          .where(_isActiveField, isEqualTo: true)
          .get();

      final providers = <ProviderModel>[];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        try {
          providers.add(ProviderModel.fromFirestore(data, doc.id));
        } catch (e) {
          print('Warning: Could not parse provider ${doc.id}: $e');
        }
      }

      return providers;
    } catch (e) {
      print('Error getting all active providers: $e');
      return [];
    }
  }

  /// Comprehensive provider search across multiple fields
  ///
  /// Searches by:
  /// - Provider name and profession
  /// - Service title, category, and subcategory
  ///
  /// Parameters:
  /// - query: Search term
  ///
  /// Returns: List of unique providers matching search criteria
  /// Throws: SearchException on invalid input
  Future<List<ProviderModel>> searchProvidersComprehensive(String query) async {
    try {
      _validateSearchQuery(query);

      final lowerQuery = query.trim().toLowerCase();
      final providerIds = <String>{};

      // Search 1: Providers by name/profession
      final usersSnapshot = await _firestore
          .collection(_usersCollection)
          .where(_roleField, isEqualTo: _roleProvider)
          .where(_isActiveField, isEqualTo: true)
          .get();

      for (var doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final name = data[_nameField]?.toString().toLowerCase() ?? '';
        final profession =
            data[_professionField]?.toString().toLowerCase() ?? '';

        if (name.contains(lowerQuery) || profession.contains(lowerQuery)) {
          providerIds.add(doc.id);
        }
      }

      // Search 2: Providers by services offered
      final servicesSnapshot = await _firestore
          .collection(_servicesCollection)
          .where(_isActiveField, isEqualTo: true)
          .get();

      for (var doc in servicesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final category = data[_categoryField]?.toString().toLowerCase() ?? '';
        final subcategory =
            data[_subcategoryField]?.toString().toLowerCase() ?? '';
        final title = data[_titleField]?.toString().toLowerCase() ?? '';
        final providerId = data[_providerIdField] as String?;

        if ((category.contains(lowerQuery) ||
                subcategory.contains(lowerQuery) ||
                title.contains(lowerQuery)) &&
            providerId != null &&
            providerId.isNotEmpty) {
          providerIds.add(providerId);
        }
      }

      // Fetch all found providers
      final providers = <ProviderModel>[];

      for (var providerId in providerIds) {
        try {
          final providerDoc = await _firestore
              .collection(_usersCollection)
              .doc(providerId)
              .get();

          if (!providerDoc.exists) continue;

          final data = providerDoc.data();
          if (data == null) continue;

          if (data[_roleField] == _roleProvider) {
            providers.add(ProviderModel.fromFirestore(data, providerId));
          }
        } catch (e) {
          print('Warning: Error fetching provider $providerId: $e');
        }
      }

      return providers;
    } on SearchException {
      rethrow;
    } catch (e) {
      print('Error in comprehensive search: $e');
      return [];
    }
  }

  /// Calculates distance between two geographic coordinates using Haversine formula
  ///
  /// Parameters:
  /// - lat1, lon1: First coordinate (latitude, longitude)
  /// - lat2, lon2: Second coordinate (latitude, longitude)
  ///
  /// Returns: Distance in kilometers
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  /// Debug method to inspect Firestore data structure
  ///
  /// Logs sample data from services and providers collections
  Future<void> debugDataStructure() async {
    try {
      print('🔍 Checking Firestore data structure...');

      // Check services
      final services =
          await _firestore.collection(_servicesCollection).limit(5).get();

      print('📊 Found ${services.docs.length} services');
      for (var doc in services.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final title = data[_titleField] ?? 'Unknown';
        final providerId = data[_providerIdField] ?? 'Unknown';
        final category = data[_categoryField] ?? 'Unknown';
        final subcategory = data[_subcategoryField] ?? 'Unknown';

        print('   📝 ID: ${doc.id} | Title: $title | '
            'Provider: $providerId | Category: $category / $subcategory');
      }

      // Check providers
      final providers = await _firestore
          .collection(_usersCollection)
          .where(_roleField, isEqualTo: _roleProvider)
          .limit(5)
          .get();

      print('👤 Found ${providers.docs.length} providers');
      for (var doc in providers.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final name = data[_nameField] ?? 'Unknown';
        final profession = data[_professionField] ?? 'Unknown';
        final isActive = data[_isActiveField] ?? false;

        print('   👤 ID: ${doc.id} | Name: $name | '
            'Profession: $profession | Active: $isActive');
      }
    } catch (e) {
      print('Error debugging data structure: $e');
    }
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Converts degrees to radians
  double _toRadians(double degrees) => degrees * (pi / 180);

  /// Extracts unique provider IDs from service documents
  List<String> _extractProviderIds(List<QueryDocumentSnapshot> docs) {
    final providerIds = <String>{};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final providerId = data[_providerIdField] as String?;
      if (providerId != null && providerId.isNotEmpty) {
        providerIds.add(providerId);
      }
    }

    return providerIds.toList();
  }

  /// Checks if provider passes location filters
  bool _passesLocationFilters(
      Map<String, dynamic> data, Map<String, dynamic> filters) {
    if (filters.containsKey(_wilayaField) && filters[_wilayaField] != null) {
      final wilaya = data[_wilayaField] as String?;
      if (wilaya != filters[_wilayaField]) return false;
    }

    if (filters.containsKey(_communeField) && filters[_communeField] != null) {
      final commune = data[_communeField] as String?;
      if (commune != filters[_communeField]) return false;
    }

    return true;
  }

  /// Checks if provider passes rating filter
  bool _passesRatingFilter(
      Map<String, dynamic> data, Map<String, dynamic> filters) {
    if (filters.containsKey(_ratingField) && filters[_ratingField] != null) {
      final rating = (data[_ratingField] as num?)?.toDouble() ?? 0.0;
      final minRating = _parseNumericValue(filters[_ratingField]);
      if (rating < minRating) return false;
    }

    return true;
  }

  /// Checks if provider passes subscription filter
  bool _passesSubscriptionFilter(
      Map<String, dynamic> data, Map<String, dynamic> filters) {
    if (filters.containsKey(_subscriptionActiveField) &&
        filters[_subscriptionActiveField] != null) {
      final subscriptionActive = data[_subscriptionActiveField] as bool?;
      if (subscriptionActive != filters[_subscriptionActiveField]) return false;
    }

    return true;
  }

  /// Safely parses numeric values from filters
  double _parseNumericValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // ============================================================================
  // INPUT VALIDATION METHODS
  // ============================================================================

  /// Validates search query string
  void _validateSearchQuery(String query) {
    if (query.trim().isEmpty) {
      throw SearchException('Search query cannot be empty',
          code: 'empty-query');
    }

    if (query.length > 200) {
      throw SearchException('Search query too long (max 200 characters)',
          code: 'query-too-long');
    }
  }

  /// Validates provider ID
  void _validateProviderId(String providerId) {
    if (providerId.trim().isEmpty) {
      throw SearchException('Provider ID cannot be empty',
          code: 'empty-provider-id');
    }
  }

  /// Validates category value
  void _validateCategoryValue(String category) {
    if (category.trim().isEmpty) {
      throw SearchException('Category cannot be empty', code: 'empty-category');
    }
  }

  /// Validates subcategory value
  void _validateSubcategoryValue(String subcategory) {
    if (subcategory.trim().isEmpty) {
      throw SearchException('Subcategory cannot be empty',
          code: 'empty-subcategory');
    }
  }

  /// Validates filters map
  void _validateFiltersMap(Map<String, dynamic> filters) {
    if (filters.isEmpty) {
      throw SearchException('Filters cannot be empty', code: 'empty-filters');
    }

    if (filters.length > 10) {
      throw SearchException('Too many filter criteria (max 10)',
          code: 'too-many-filters');
    }
  }
}
