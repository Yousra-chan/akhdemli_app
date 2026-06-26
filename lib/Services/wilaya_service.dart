import 'package:flutter/foundation.dart';
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

/// Wilaya Service for Algerian location data — pure, static, data-only.
///
/// Provides access to:
/// - All wilayas (states/provinces) in Algeria
/// - Communes (cities/districts) within each wilaya
/// - Localized names in French/Arabic
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
  static const String _unknownLabel = 'Unknown';
  static const int _maxNameLength = 100;

  // ============================================================================
  // CACHE MANAGEMENT
  // ============================================================================

  /// Clears every cached wilaya/commune lookup.
  static void refreshCache() {
    _wilayasCache = null;
    _communesCache = null;
  }

  // ============================================================================
  // WILAYA OPERATIONS
  // ============================================================================

  /// Retrieves all wilayas (states/provinces) in Algeria.
  static List<Wilaya> getAllWilayas() {
    if (_wilayasCache != null && _wilayasCache!.isNotEmpty) {
      return _wilayasCache!;
    }

    try {
      final wilayas = _dzair.getWilayat();
      final wilayaList = (wilayas ?? const []).whereType<Wilaya>().toList();

      if (wilayaList.isEmpty) {
        throw WilayaException(
          'No wilayas found in data source',
          code: 'wilayas-empty',
        );
      }

      _wilayasCache = wilayaList;
      return wilayaList;
    } on WilayaException {
      rethrow;
    } catch (e) {
      throw WilayaException(
        'Error retrieving wilayas: $e',
        code: 'wilayas-retrieval-failed',
      );
    }
  }

  /// Retrieves all wilaya names sorted alphabetically in specified language.
  static List<String> getAllWilayaNames({Language? language}) {
    final wilayas = getAllWilayas();
    final names = wilayas
        .map((w) => _getWilayaName(w, language: language))
        .where((n) => n.isNotEmpty)
        .toList()
      ..sort();
    return names;
  }

  /// Safe variant — never throws.
  static List<String> getAllWilayaNamesSafe({Language? language}) {
    try {
      return getAllWilayaNames(language: language);
    } catch (e) {
      debugPrint('WilayaService: getAllWilayaNamesSafe falling back to []: $e');
      return const [];
    }
  }

  /// Retrieves communes for a specific wilaya.
  static List<String> getCommunesForWilaya(String wilayaName, {Language? language}) {
    _validateWilayaName(wilayaName);

    // We don't cache by language yet, so we refresh if needed or just don't cache for localized names
    // if we expect frequent language changes. For now, simple implementation.
    
    final wilaya = _findWilayaByName(wilayaName);
    if (wilaya == null) {
      throw WilayaException(
        'Wilaya not found: $wilayaName',
        code: 'wilaya-not-found',
      );
    }

    final communes = wilaya.getCommunes();
    final communeList = (communes ?? const []).whereType<Commune>().toList()
      ..sort((a, b) => _getCommuneName(a, language: language).compareTo(_getCommuneName(b, language: language)));

    final communeNames = communeList
        .map((c) => _getCommuneName(c, language: language))
        .where((n) => n.isNotEmpty)
        .toList();

    return communeNames;
  }

  /// Safe variant — never throws.
  static List<String> getCommunesForWilayaSafe(String wilayaName, {Language? language}) {
    try {
      return getCommunesForWilaya(wilayaName, language: language);
    } catch (e) {
      debugPrint('WilayaService: getCommunesForWilayaSafe($wilayaName) falling back to []: $e');
      return const [];
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  static bool wilayaExists(String wilayaName) {
    try {
      _validateWilayaName(wilayaName);
      return _findWilayaByName(wilayaName) != null;
    } catch (e) {
      return false;
    }
  }

  static bool communeExists(String wilayaName, String communeName) {
    try {
      _validateWilayaName(wilayaName);
      _validateCommuneName(communeName);
      return getCommunesForWilaya(wilayaName).contains(communeName);
    } catch (e) {
      return false;
    }
  }

  static int getWilayaCount() {
    try {
      return getAllWilayas().length;
    } catch (e) {
      return 0;
    }
  }

  static int getCommuneCountForWilaya(String wilayaName) {
    try {
      return getCommunesForWilaya(wilayaName).length;
    } catch (e) {
      return 0;
    }
  }

  static Wilaya? getWilayaByName(String wilayaName) {
    try {
      _validateWilayaName(wilayaName);
      return _findWilayaByName(wilayaName);
    } catch (e) {
      return null;
    }
  }

  /// NEW: Localizes a wilaya name from any supported language to the target language.
  static String localizeWilayaName(String storedName, String targetLocale) {
    final language = _getDzairLanguage(targetLocale);
    final wilaya = _findWilayaByName(storedName);
    if (wilaya == null) return storedName;
    return _getWilayaName(wilaya, language: language);
  }

  /// NEW: Localizes a commune name within a wilaya.
  static String localizeCommuneName(String wilayaName, String storedCommuneName, String targetLocale) {
    final language = _getDzairLanguage(targetLocale);
    final wilaya = _findWilayaByName(wilayaName);
    if (wilaya == null) return storedCommuneName;
    
    final commune = _findCommuneByName(wilaya, storedCommuneName);
    if (commune == null) return storedCommuneName;
    
    return _getCommuneName(commune, language: language);
  }

  /// NEW: Localizes a "Wilaya, Commune" or "Commune, Wilaya" string if possible.
  static String localizeLocationString(String locationString, String targetLocale) {
    if (locationString.isEmpty) return locationString;
    
    // Check for "Commune, Wilaya" pattern
    final parts = locationString.split(',').map((e) => e.trim()).toList();
    if (parts.length == 2) {
      // It's likely "Commune, Wilaya" (as seen in provider cards)
      final communePart = parts[0];
      final wilayaPart = parts[1];
      
      final localizedWilaya = localizeWilayaName(wilayaPart, targetLocale);
      final localizedCommune = localizeCommuneName(wilayaPart, communePart, targetLocale);
      
      return '$localizedCommune, $localizedWilaya';
    }
    
    // Try as just a Wilaya
    return localizeWilayaName(locationString, targetLocale);
  }

  /// NEW: Returns a map of Canonical Name -> Localized Name for dropdowns.
  static Map<String, String> getWilayasLocalizedMap(String targetLocale) {
    final language = _getDzairLanguage(targetLocale);
    final Map<String, String> map = {};
    
    for (final wilaya in getAllWilayas()) {
      final canonical = _getWilayaName(wilaya, language: Language.FR);
      final localized = _getWilayaName(wilaya, language: language);
      map[canonical] = localized;
    }
    return map;
  }

  /// NEW: Returns a map of Canonical Name -> Localized Name for communes.
  static Map<String, String> getCommunesLocalizedMap(String wilayaName, String targetLocale) {
    final language = _getDzairLanguage(targetLocale);
    final wilaya = _findWilayaByName(wilayaName);
    if (wilaya == null) return {};

    final Map<String, String> map = {};
    final communes = wilaya.getCommunes();
    if (communes == null) return {};

    for (final commune in communes.whereType<Commune>()) {
      final canonical = _getCommuneName(commune, language: Language.FR);
      final localized = _getCommuneName(commune, language: language);
      map[canonical] = localized;
    }
    return map;
  }

  static Language _getDzairLanguage(String localeCode) {
    if (localeCode.toLowerCase() == 'ar') return Language.AR;
    return Language.FR; // Default for FR and EN
  }

  /// Clears the internal cache.
  static void clearCache() => refreshCache();

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  static String _getWilayaName(Wilaya wilaya, {Language? language}) {
    try {
      final name = wilaya.getWilayaName(language ?? Language.FR);
      if (name == null || name.isEmpty) return _unknownLabel;
      return _sanitizeName(name);
    } catch (e) {
      return _unknownLabel;
    }
  }

  static String _getCommuneName(Commune commune, {Language? language}) {
    try {
      final name = commune.getCommuneName(language ?? Language.FR);
      if (name == null || name.isEmpty) return _unknownLabel;
      return _sanitizeName(name);
    } catch (e) {
      return _unknownLabel;
    }
  }

  static Commune? _findCommuneByName(Wilaya wilaya, String communeName) {
    try {
      final normalizedSearchName = communeName.trim().toLowerCase();
      final communes = wilaya.getCommunes();
      if (communes == null) return null;
      
      for (final commune in communes.whereType<Commune>()) {
        // Try multiple languages to find the commune object
        if (_getCommuneName(commune, language: Language.FR).toLowerCase() == normalizedSearchName ||
            _getCommuneName(commune, language: Language.AR).toLowerCase() == normalizedSearchName) {
          return commune;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Wilaya? _findWilayaByName(String wilayaName) {
    try {
      final normalizedSearchName = wilayaName.trim().toLowerCase();
      for (final wilaya in getAllWilayas()) {
        // Try multiple languages to find the wilaya object
        if (_getWilayaName(wilaya, language: Language.FR).toLowerCase() == normalizedSearchName ||
            _getWilayaName(wilaya, language: Language.AR).toLowerCase() == normalizedSearchName) {
          return wilaya;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static String _sanitizeName(String name) {
    try {
      final trimmed = name.trim();
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

  static void _validateWilayaName(String wilayaName) {
    if (wilayaName.trim().isEmpty) {
      throw WilayaException(
        'Wilaya name cannot be empty or whitespace',
        code: 'empty-wilaya-name',
      );
    }
    if (wilayaName.length > _maxNameLength) {
      throw WilayaException(
        'Wilaya name too long (max $_maxNameLength characters)',
        code: 'wilaya-name-too-long',
      );
    }
  }

  static void _validateCommuneName(String communeName) {
    if (communeName.trim().isEmpty) {
      throw WilayaException(
        'Commune name cannot be empty or whitespace',
        code: 'empty-commune-name',
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
