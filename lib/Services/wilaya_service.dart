import 'package:dzair_data_usage/dzair.dart';
import 'package:dzair_data_usage/wilaya.dart';
import 'package:dzair_data_usage/commune.dart';
import 'package:dzair_data_usage/langs.dart';

/// Custom exception for wilaya-related errors
class WilayaException implements Exception {
  final String message;
  final String? code;

  WilayaException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Wilaya Service for Algerian location data
///
/// Provides access to:
/// - All wilayas (states/provinces) in Algeria
/// - Communes (cities/districts) within each wilaya
/// - Localized names in French
/// - Sorted lists for UI display
class WilayaService {
  // Singleton instance
  static final WilayaService _instance = WilayaService._internal();

  factory WilayaService() => _instance;

  WilayaService._internal();

  // Dzair instance for accessing location data
  static final Dzair _dzair = Dzair();

  // Cache for wilayas to avoid repeated queries
  static List<Wilaya>? _wilayasCache;
  static Map<String, List<String>>? _communesCache;

  // Constants
  static const String _defaultLanguage = 'FR';
  static const String _unknownLabel = 'Unknown';
  static const int _maxNameLength = 100;

  // ============================================================================
  // WILAYA OPERATIONS
  // ============================================================================

  /// Retrieves all wilayas (states/provinces) in Algeria
  ///
  /// Returns: List of Wilaya objects
  /// Throws: WilayaException if data cannot be retrieved
  static List<Wilaya> getAllWilayas() {
    try {
      // Return cached data if available
      if (_wilayasCache != null && _wilayasCache!.isNotEmpty) {
        return _wilayasCache!;
      }

      final wilayas = _dzair.getWilayat();
      if (wilayas == null) {
        throw WilayaException(
          'Could not retrieve wilayas from data source',
          code: 'wilayas-null',
        );
      }

      final wilayaList = wilayas.whereType<Wilaya>().toList();
      if (wilayaList.isEmpty) {
        throw WilayaException(
          'No wilayas found in data source',
          code: 'wilayas-empty',
        );
      }

      // Cache the result
      _wilayasCache = wilayaList;
      return wilayaList;
    } catch (e) {
      throw WilayaException(
        'Error retrieving wilayas: $e',
        code: 'wilayas-retrieval-failed',
      );
    }
  }

  /// Retrieves all wilaya names sorted alphabetically
  ///
  /// Returns: Sorted list of wilaya names in French
  /// Throws: WilayaException if data cannot be retrieved
  static List<String> getAllWilayaNames() {
    try {
      final wilayas = getAllWilayas();

      final wilayaNames =
          wilayas.map(_getWilayaName).where((name) => name.isNotEmpty).toList();

      // Sort alphabetically
      wilayaNames.sort((a, b) => a.compareTo(b));

      return wilayaNames;
    } on WilayaException {
      rethrow;
    } catch (e) {
      throw WilayaException(
        'Error retrieving wilaya names: $e',
        code: 'wilaya-names-failed',
      );
    }
  }

  /// Retrieves communes for a specific wilaya
  ///
  /// Parameters:
  /// - wilayaName: Name of the wilaya
  ///
  /// Returns: Sorted list of commune names within the wilaya
  /// Throws: WilayaException on validation failure
  static List<String> getCommunesForWilaya(String wilayaName) {
    try {
      _validateWilayaName(wilayaName);

      // Check cache first
      if (_communesCache != null && _communesCache!.containsKey(wilayaName)) {
        return _communesCache![wilayaName]!;
      }

      // Find the wilaya
      final wilaya = _findWilayaByName(wilayaName);
      if (wilaya == null) {
        throw WilayaException(
          'Wilaya not found: $wilayaName',
          code: 'wilaya-not-found',
        );
      }

      // Get and sort communes
      final communes = wilaya.getCommunes();
      if (communes == null) {
        return [];
      }

      final communeList = communes.whereType<Commune>().toList();
      if (communeList.isEmpty) {
        return [];
      }

      // Sort alphabetically
      communeList
          .sort((a, b) => _getCommuneName(a).compareTo(_getCommuneName(b)));

      final communeNames = communeList
          .map(_getCommuneName)
          .where((name) => name.isNotEmpty)
          .toList();

      // Cache the result
      _communesCache ??= {};
      _communesCache![wilayaName] = communeNames;

      return communeNames;
    } on WilayaException {
      rethrow;
    } catch (e) {
      throw WilayaException(
        'Error retrieving communes for wilaya: $e',
        code: 'communes-retrieval-failed',
      );
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Validates if a wilaya name exists
  ///
  /// Parameters:
  /// - wilayaName: Name to validate
  ///
  /// Returns: true if wilaya exists, false otherwise
  static bool wilayaExists(String wilayaName) {
    try {
      _validateWilayaName(wilayaName);
      return _findWilayaByName(wilayaName) != null;
    } catch (e) {
      return false;
    }
  }

  /// Validates if a commune exists in a specific wilaya
  ///
  /// Parameters:
  /// - wilayaName: Name of the wilaya
  /// - communeName: Name of the commune to validate
  ///
  /// Returns: true if commune exists in wilaya, false otherwise
  static bool communeExists(String wilayaName, String communeName) {
    try {
      _validateWilayaName(wilayaName);
      _validateCommuneName(communeName);

      final communes = getCommunesForWilaya(wilayaName);
      return communes.contains(communeName);
    } catch (e) {
      return false;
    }
  }

  /// Gets count of all wilayas
  ///
  /// Returns: Number of wilayas
  static int getWilayaCount() {
    try {
      return getAllWilayas().length;
    } catch (e) {
      return 0;
    }
  }

  /// Gets count of communes in a specific wilaya
  ///
  /// Parameters:
  /// - wilayaName: Name of the wilaya
  ///
  /// Returns: Number of communes in the wilaya
  static int getCommuneCountForWilaya(String wilayaName) {
    try {
      return getCommunesForWilaya(wilayaName).length;
    } catch (e) {
      return 0;
    }
  }

  /// Gets wilaya by its name (case-insensitive)
  ///
  /// Parameters:
  /// - wilayaName: Name of the wilaya to retrieve
  ///
  /// Returns: Wilaya object if found, null otherwise
  static Wilaya? getWilayaByName(String wilayaName) {
    try {
      _validateWilayaName(wilayaName);
      return _findWilayaByName(wilayaName);
    } catch (e) {
      return null;
    }
  }

  /// Clears the internal cache
  ///
  /// Useful for refreshing data or testing
  static void clearCache() {
    _wilayasCache = null;
    _communesCache = null;
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Safely retrieves wilaya name in French
  ///
  /// Parameters:
  /// - wilaya: Wilaya object
  ///
  /// Returns: Wilaya name in French, or 'Unknown' if not available
  static String _getWilayaName(Wilaya wilaya) {
    try {
      final name = wilaya.getWilayaName(Language.FR);

      if (name == null || name.isEmpty) {
        return _unknownLabel;
      }

      // Sanitize the name
      return _sanitizeName(name);
    } catch (e) {
      return _unknownLabel;
    }
  }

  /// Safely retrieves commune name in French
  ///
  /// Parameters:
  /// - commune: Commune object
  ///
  /// Returns: Commune name in French, or 'Unknown' if not available
  static String _getCommuneName(Commune commune) {
    try {
      final name = commune.getCommuneName(Language.FR);

      if (name == null || name.isEmpty) {
        return _unknownLabel;
      }

      // Sanitize the name
      return _sanitizeName(name);
    } catch (e) {
      return _unknownLabel;
    }
  }

  /// Finds wilaya by name (case-insensitive)
  ///
  /// Parameters:
  /// - wilayaName: Name to search for
  ///
  /// Returns: Wilaya if found, null otherwise
  static Wilaya? _findWilayaByName(String wilayaName) {
    try {
      final normalizedSearchName = wilayaName.trim().toLowerCase();

      final wilayas = getAllWilayas();

      // First try exact match (ignoring case)
      for (final wilaya in wilayas) {
        final wilayaNameStr = _getWilayaName(wilaya);
        if (wilayaNameStr.toLowerCase() == normalizedSearchName) {
          return wilaya;
        }
      }

      // Return null if not found (don't return first as fallback)
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Sanitizes location names
  ///
  /// Removes extra whitespace and validates length
  static String _sanitizeName(String name) {
    try {
      // Trim whitespace
      final trimmed = name.trim();

      // Validate length
      if (trimmed.length > _maxNameLength) {
        return trimmed.substring(0, _maxNameLength);
      }

      return trimmed;
    } catch (e) {
      return _unknownLabel;
    }
  }

  // ============================================================================
  // INPUT VALIDATION METHODS
  // ============================================================================

  /// Validates wilaya name input
  ///
  /// Throws: WilayaException on validation failure
  static void _validateWilayaName(String wilayaName) {
    if (wilayaName.isEmpty) {
      throw WilayaException(
        'Wilaya name cannot be empty',
        code: 'empty-wilaya-name',
      );
    }

    if (wilayaName.trim().isEmpty) {
      throw WilayaException(
        'Wilaya name cannot be only whitespace',
        code: 'whitespace-wilaya-name',
      );
    }

    if (wilayaName.length > _maxNameLength) {
      throw WilayaException(
        'Wilaya name too long (max $_maxNameLength characters)',
        code: 'wilaya-name-too-long',
      );
    }
  }

  /// Validates commune name input
  ///
  /// Throws: WilayaException on validation failure
  static void _validateCommuneName(String communeName) {
    if (communeName.isEmpty) {
      throw WilayaException(
        'Commune name cannot be empty',
        code: 'empty-commune-name',
      );
    }

    if (communeName.trim().isEmpty) {
      throw WilayaException(
        'Commune name cannot be only whitespace',
        code: 'whitespace-commune-name',
      );
    }

    if (communeName.length > _maxNameLength) {
      throw WilayaException(
        'Commune name too long (max $_maxNameLength characters)',
        code: 'commune-name-too-long',
      );
    }
  }
}
