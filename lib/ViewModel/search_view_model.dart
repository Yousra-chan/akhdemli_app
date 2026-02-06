import 'package:flutter/material.dart';
import '../Services/search_service.dart';
import '../models/ProviderModel.dart';
import '../models/ServicesModel.dart';

class SearchViewModel extends ChangeNotifier {
  final SearchService _searchService = SearchService();

  List<ProviderModel> _providerResults = [];
  List<Service> _serviceResults = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<ProviderModel> get providerResults => _providerResults;
  List<Service> get serviceResults => _serviceResults;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// NEW: Get providers by category and subcategory
  Future<void> getProvidersByCategoryAndSubcategory(
    String category,
    String subcategory,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (category == 'All' && subcategory == 'All Services') {
        _providerResults = await _searchService.getAllActiveProviders();
      } else if (subcategory == 'All Services') {
        _providerResults =
            await _searchService.searchProvidersByCategory(category);
      } else {
        _providerResults =
            await _searchService.searchProvidersByCategoryAndSubcategory(
          category,
          subcategory,
        );
      }
      _serviceResults = [];
    } catch (e) {
      _error = 'Failed to load providers: $e';
      _providerResults = [];
      _serviceResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// NEW: Get providers by category only
  Future<void> getProvidersByCategory(String category) async {
    await getProvidersByCategoryAndSubcategory(category, 'All Services');
  }

  /// Clears all current search results and error state.
  void clearResults() {
    _providerResults = [];
    _serviceResults = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Executes a search across both providers and services
  Future<void> executeSearch(String query) async {
    if (query.trim().isEmpty) {
      clearResults();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Execute both searches
      final providerResults =
          await _searchService.searchProvidersByProfessionOrName(query);
      final serviceResults = await _searchService.searchServices(query);

      _providerResults = providerResults;
      _serviceResults = serviceResults;
    } catch (e) {
      _error = 'Échec de la recherche: $e';
      _providerResults = [];
      _serviceResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Searches only for providers
  Future<void> searchProvidersOnly(String query) async {
    if (query.trim().isEmpty) {
      _providerResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _providerResults =
          await _searchService.searchProvidersByProfessionOrName(query);
      _serviceResults = [];
    } catch (e) {
      _error = 'Échec de la recherche de prestataires: $e';
      _providerResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// SEARCH WITH FILTERS - UPDATED
  Future<void> searchWithFilters(Map<String, dynamic> filters) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if we have category/subcategory filters
      if (filters.containsKey('category') ||
          filters.containsKey('subcategory')) {
        final category = filters['category']?.toString() ?? 'All';
        final subcategory =
            filters['subcategory']?.toString() ?? 'All Services';

        await getProvidersByCategoryAndSubcategory(category, subcategory);
      } else {
        // Use existing logic for other filters
        final Map<String, dynamic> convertedFilters = Map.from(filters);

        // Handle distance filter
        final hasDistanceFilter =
            convertedFilters.containsKey('useDistanceFilter') &&
                convertedFilters['useDistanceFilter'] == true &&
                convertedFilters.containsKey('userLat') &&
                convertedFilters.containsKey('userLng');

        if (hasDistanceFilter) {
          final userLat = convertedFilters['userLat'] as double;
          final userLng = convertedFilters['userLng'] as double;
          final maxDistance = convertedFilters['maxDistance'] ?? 20.0;

          // Remove distance filters for the search
          convertedFilters.remove('userLat');
          convertedFilters.remove('userLng');
          convertedFilters.remove('maxDistance');
          convertedFilters.remove('useDistanceFilter');

          // Get providers with other filters
          _providerResults =
              await _searchService.searchProvidersWithFilters(convertedFilters);

          // Apply distance filter
          _providerResults = _filterByDistance(
              _providerResults, userLat, userLng, maxDistance);
        } else {
          // No distance filter
          _providerResults =
              await _searchService.searchProvidersWithFilters(convertedFilters);
        }

        _serviceResults = [];
      }
    } catch (e) {
      _error = 'Échec de la recherche avec filtres: $e';
      _providerResults = [];
      _serviceResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filter providers by distance
  List<ProviderModel> _filterByDistance(
    List<ProviderModel> providers,
    double userLat,
    double userLng,
    double maxDistanceKm,
  ) {
    return providers.where((provider) {
      if (provider.location == null) return false;

      final distance = _searchService.calculateDistance(
        userLat,
        userLng,
        provider.location!.latitude,
        provider.location!.longitude,
      );

      return distance <= maxDistanceKm;
    }).toList();
  }

  // ... Keep all other existing methods below this line ...
  // Searches only for services
  Future<void> searchServicesOnly(String query) async {
    if (query.trim().isEmpty) {
      _serviceResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _serviceResults = await _searchService.searchServices(query);
      _providerResults = [];
    } catch (e) {
      _error = 'Échec de la recherche de services: $e';
      _serviceResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search services by category
  Future<void> searchServicesByCategory(String category) async {
    if (category.trim().isEmpty) {
      _serviceResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _serviceResults = await _searchService.searchServices(category);
      _providerResults = [];
    } catch (e) {
      _error = 'Échec de la recherche par catégorie: $e';
      _serviceResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get featured services for homepage (fallback to highly rated services)
  Future<void> loadFeaturedServices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get all active services
      _serviceResults = await _searchService.searchServices('');

      // Sort by rating and take top 10
      _serviceResults.sort((a, b) => b.rating.compareTo(a.rating));
      _serviceResults = _serviceResults.take(10).toList();

      _providerResults = [];
    } catch (e) {
      _error = 'Échec du chargement des services en vedette: $e';
      _serviceResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Format distance for display
  String formatDistance(double? meters) {
    if (meters == null) return 'Distance non disponible';

    try {
      if (meters < 1000) {
        return '${meters.toStringAsFixed(0)} m';
      } else {
        return '${(meters / 1000).toStringAsFixed(1)} km';
      }
    } catch (e) {
      return 'Distance non disponible';
    }
  }

  /// Calculate distance for a specific provider
  double? calculateDistanceForProvider(
    double userLat,
    double userLng,
    ProviderModel provider,
  ) {
    if (provider.location == null) return null;

    return _searchService.calculateDistance(
      userLat,
      userLng,
      provider.location!.latitude,
      provider.location!.longitude,
    );
  }

  /// Sort providers by distance from user location
  List<ProviderModel> sortProvidersByDistance(
    List<ProviderModel> providers,
    double userLat,
    double userLng,
  ) {
    final providersWithDistance = providers.map((provider) {
      final distance = provider.location != null
          ? _searchService.calculateDistance(
              userLat,
              userLng,
              provider.location!.latitude,
              provider.location!.longitude,
            )
          : double.infinity;
      return {
        'provider': provider,
        'distance': distance,
      };
    }).toList();

    providersWithDistance.sort((a, b) {
      return (a['distance'] as double).compareTo(b['distance'] as double);
    });

    return providersWithDistance
        .map((item) => item['provider'] as ProviderModel)
        .toList();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Check if there are any search results
  bool get hasResults {
    return _providerResults.isNotEmpty || _serviceResults.isNotEmpty;
  }

  /// Get total number of results
  int get totalResults {
    return _providerResults.length + _serviceResults.length;
  }

  /// Get search summary text
  String get searchSummary {
    if (_isLoading) return 'Recherche en cours...';
    if (_error != null) return _error!;
    if (!hasResults) return 'Aucun résultat trouvé';

    if (_providerResults.isNotEmpty && _serviceResults.isNotEmpty) {
      return '${_providerResults.length} prestataires et ${_serviceResults.length} services trouvés';
    } else if (_providerResults.isNotEmpty) {
      return '${_providerResults.length} prestataire${_providerResults.length > 1 ? 's' : ''} trouvé${_providerResults.length > 1 ? 's' : ''}';
    } else {
      return '${_serviceResults.length} service${_serviceResults.length > 1 ? 's' : ''} trouvé${_serviceResults.length > 1 ? 's' : ''}';
    }
  }

  /// Get providers by category with filters
  Future<void> searchProvidersByCategoryWithFilters(
      Map<String, dynamic> filters) async {
    await searchWithFilters(filters);
  }

  /// Get available categories for filters
  Future<Map<String, List<String>>> getAvailableCategories() async {
    try {
      return await _searchService.getAvailableCategories();
    } catch (e) {
      return {};
    }
  }

  /// Get available wilayas for filters
  Future<List<String>> getAvailableWilayas() async {
    try {
      return await _searchService.getAvailableWilayas();
    } catch (e) {
      return [];
    }
  }

  /// Get services by provider ID
  Future<List<Service>> getServicesByProvider(String providerId) async {
    try {
      return await _searchService.getServicesByProvider(providerId);
    } catch (e) {
      return [];
    }
  }
}
