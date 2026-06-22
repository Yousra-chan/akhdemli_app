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
/// - Localized names in French
/// - Sorted lists for UI display
class WilayaService {
  // Singleton instance (kept for parity with previous API surface;
  // all real work happens through the static members below).
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

  /// Clears every cached wilaya/commune lookup, forcing the next call to
  /// re-read from the underlying data source. Useful for tests or after a
  /// locale change.
  static void refreshCache() {
    _wilayasCache = null;
    _communesCache = null;
  }

  // ============================================================================
  // WILAYA OPERATIONS
  // ============================================================================

  /// Retrieves all wilayas (states/provinces) in Algeria.
  ///
  /// Returns: List of Wilaya objects
  /// Throws: WilayaException if data cannot be retrieved
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

  /// Retrieves all wilaya names sorted alphabetically.
  /// Throws: WilayaException if data cannot be retrieved.
  static List<String> getAllWilayaNames() {
    final wilayas = getAllWilayas();
    final names = wilayas.map(_getWilayaName).where((n) => n.isNotEmpty).toList()..sort();
    return names;
  }

  /// Safe variant — never throws. Returns an empty list on failure so UI
  /// dropdowns always have something to render instead of crashing the
  /// widget tree.
  static List<String> getAllWilayaNamesSafe() {
    try {
      return getAllWilayaNames();
    } catch (e) {
      debugPrint('WilayaService: getAllWilayaNamesSafe falling back to []: $e');
      return const [];
    }
  }

  /// Retrieves communes for a specific wilaya.
  /// Throws: WilayaException on validation failure or if not found.
  static List<String> getCommunesForWilaya(String wilayaName) {
    _validateWilayaName(wilayaName);

    if (_communesCache != null && _communesCache!.containsKey(wilayaName)) {
      return _communesCache![wilayaName]!;
    }

    final wilaya = _findWilayaByName(wilayaName);
    if (wilaya == null) {
      throw WilayaException(
        'Wilaya not found: $wilayaName',
        code: 'wilaya-not-found',
      );
    }

    final communes = wilaya.getCommunes();
    final communeList = (communes ?? const []).whereType<Commune>().toList()
      ..sort((a, b) => _getCommuneName(a).compareTo(_getCommuneName(b)));

    final communeNames =
    communeList.map(_getCommuneName).where((n) => n.isNotEmpty).toList();

    _communesCache ??= {};
    _communesCache![wilayaName] = communeNames;

    return communeNames;
  }

  /// Safe variant — never throws. Returns an empty list on any failure.
  static List<String> getCommunesForWilayaSafe(String wilayaName) {
    try {
      return getCommunesForWilaya(wilayaName);
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

  /// Clears the internal cache. Kept as an alias of [refreshCache] for
  /// backward compatibility with any existing call sites.
  static void clearCache() => refreshCache();

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  static String _getWilayaName(Wilaya wilaya) {
    try {
      final name = wilaya.getWilayaName(Language.FR);
      if (name == null || name.isEmpty) return _unknownLabel;
      return _sanitizeName(name);
    } catch (e) {
      return _unknownLabel;
    }
  }

  static String _getCommuneName(Commune commune) {
    try {
      final name = commune.getCommuneName(Language.FR);
      if (name == null || name.isEmpty) return _unknownLabel;
      return _sanitizeName(name);
    } catch (e) {
      return _unknownLabel;
    }
  }

  static Wilaya? _findWilayaByName(String wilayaName) {
    try {
      final normalizedSearchName = wilayaName.trim().toLowerCase();
      for (final wilaya in getAllWilayas()) {
        if (_getWilayaName(wilaya).toLowerCase() == normalizedSearchName) {
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
