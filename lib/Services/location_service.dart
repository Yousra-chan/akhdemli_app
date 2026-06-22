import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// Custom exception class for location-related errors
class LocationException implements Exception {
  final String message;
  final String code;

  LocationException(this.message, {this.code = 'LOCATION_ERROR'});

  @override
  String toString() => 'LocationException: $message';
}

class LocationService {
  static const int _locationTimeoutSeconds = 30;

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('Error checking location service status: $e');
      return false;
    }
  }

  /// Check and request location permission with enhanced error handling
  Future<bool> checkPermission() async {
    try {
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationException(
          'Location services are disabled. Please enable them to use this feature.',
          code: 'SERVICE_DISABLED',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('Current location permission: $permission');

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Requesting location permission...');
        permission = await Geolocator.requestPermission();
        debugPrint('Permission request result: $permission');
      }

      final bool hasPermission =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;

      if (!hasPermission) {
        throw LocationException(
          'Location permission denied. Please grant location access in app settings.',
          code: 'PERMISSION_DENIED',
        );
      }

      return hasPermission;
    } on LocationException {
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error in checkPermission: $e');
      throw LocationException(
        'Unable to check location permissions. Please try again.',
        code: 'PERMISSION_CHECK_FAILED',
      );
    }
  }

  /// Get current location (latitude & longitude) with timeout and error handling
  Future<Position?> getCurrentLocation() async {
    try {
      debugPrint('Starting location fetch...');

      bool hasPermission = await checkPermission();
      if (!hasPermission) {
        debugPrint('Location permission not granted');
        return null;
      }

      debugPrint('Fetching current position...');
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: _locationTimeoutSeconds),
        onTimeout: () {
          throw LocationException(
            'Location request timed out. Please check your connection and try again.',
            code: 'TIMEOUT',
          );
        },
      );

      debugPrint(
        'Location fetched successfully: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } on LocationException {
      rethrow;
    } on Exception catch (e) {
      debugPrint('Error getting current location: $e');
      throw LocationException(
        'Failed to get current location. Please ensure location services are enabled.',
        code: 'LOCATION_FETCH_FAILED',
      );
    }
  }

  /// Get formatted address from latitude & longitude with better formatting
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      debugPrint('Fetching address for coordinates: $lat, $lng');

      List<Placemark> placemarks = await placemarkFromCoordinates(
        lat,
        lng,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw LocationException(
            'Address lookup timed out',
            code: 'GEOCODING_TIMEOUT',
          );
        },
      );

      if (placemarks.isEmpty) {
        debugPrint('No address found for coordinates: $lat, $lng');
        return _getFallbackAddress(lat, lng);
      }

      final placemark = placemarks.first;
      final String formattedAddress = _formatAddress(placemark);

      debugPrint('Address found: $formattedAddress');
      return formattedAddress;
    } on LocationException {
      rethrow;
    } catch (e) {
      debugPrint('Error getting address from coordinates: $e');
      return _getFallbackAddress(lat, lng);
    }
  }

  /// Helper method to format address cleanly
  String _formatAddress(Placemark placemark) {
    final parts = <String>[];

    // Add street information
    if (placemark.street?.isNotEmpty == true) {
      parts.add(placemark.street!);
    }

    // Add locality/city
    if (placemark.locality?.isNotEmpty == true) {
      parts.add(placemark.locality!);
    } else if (placemark.subAdministrativeArea?.isNotEmpty == true) {
      parts.add(placemark.subAdministrativeArea!);
    }

    // Add administrative area (state/province)
    if (placemark.administrativeArea?.isNotEmpty == true) {
      parts.add(placemark.administrativeArea!);
    }

    // Add postal code if available
    if (placemark.postalCode?.isNotEmpty == true) {
      parts.add(placemark.postalCode!);
    }

    // Add country
    if (placemark.country?.isNotEmpty == true) {
      parts.add(placemark.country!);
    }

    // Fallback if no address parts found
    if (parts.isEmpty) {
      return 'unknown_location';
    }

    return parts.join(', ');
  }

  /// Fallback address when geocoding fails
  String _getFallbackAddress(double lat, double lng) {
    return 'location_coords'; // Plus params handled in UI
  }

  /// Helper method to get current address directly (simplifies UI usage)
  Future<String?> getCurrentAddress() async {
    try {
      debugPrint('Getting current address...');
      final Position? position = await getCurrentLocation();

      if (position == null) {
        debugPrint('No position available for address lookup');
        return null;
      }

      final String address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      debugPrint('Current address resolved: $address');
      return address;
    } on LocationException catch (e) {
      debugPrint('Error getting current address: ${e.message}');
      return 'error_determine_address';
    } catch (e) {
      debugPrint('Unexpected error in getCurrentAddress: $e');
      return 'error_determine_address';
    }
  }

  /// Listen to location changes in real-time with error handling
  Stream<Position> listenLocationChanges({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    ).handleError((error) {
      debugPrint('Error in location stream: $error');
      throw LocationException(
        'Failed to track location changes',
        code: 'STREAM_ERROR',
      );
    });
  }

  /// Calculate distance in meters between two coordinates
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    try {
      final double distance = Geolocator.distanceBetween(
        startLat,
        startLng,
        endLat,
        endLng,
      );

      debugPrint('Distance calculated: ${distance.toStringAsFixed(2)} meters');
      return distance;
    } catch (e) {
      debugPrint('Error calculating distance: $e');
      throw LocationException(
        'Failed to calculate distance between locations',
        code: 'DISTANCE_CALCULATION_FAILED',
      );
    }
  }

  /// Get location accuracy information
  Future<LocationAccuracyStatus> getLocationAccuracy() async {
    try {
      return await Geolocator.getLocationAccuracy();
    } catch (e) {
      debugPrint('Error getting location accuracy: $e');
      throw LocationException(
        'Unable to determine location accuracy',
        code: 'ACCURACY_CHECK_FAILED',
      );
    }
  }

  /// Check if we have precise location access
  Future<bool> hasPreciseLocation() async {
    try {
      final accuracy = await getLocationAccuracy();
      return accuracy == LocationAccuracyStatus.precise;
    } on LocationException {
      return false;
    } catch (e) {
      debugPrint('Error checking precise location: $e');
      return false;
    }
  }

  /// Debug method to log location status
  Future<void> debugLocationStatus() async {
    try {
      debugPrint('=== Location Service Debug ===');
      debugPrint('Location service enabled: ${await isLocationServiceEnabled()}');
      debugPrint('Location permission: ${await Geolocator.checkPermission()}');
      debugPrint('Has precise location: ${await hasPreciseLocation()}');

      final Position? position = await getCurrentLocation();
      if (position != null) {
        debugPrint('Current position: ${position.latitude}, ${position.longitude}');
        debugPrint('Accuracy: ${position.accuracy} meters');
        final address = await getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        debugPrint('Current address: $address');
      } else {
        debugPrint('No current position available');
      }
      debugPrint('=== End Debug ===');
    } catch (e) {
      debugPrint('Debug error: $e');
    }
  }
}
