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
      print('Error checking location service status: $e');
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
      print('Current location permission: $permission');

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('Requesting location permission...');
        permission = await Geolocator.requestPermission();
        print('Permission request result: $permission');
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
      print('Unexpected error in checkPermission: $e');
      throw LocationException(
        'Unable to check location permissions. Please try again.',
        code: 'PERMISSION_CHECK_FAILED',
      );
    }
  }

  /// Get current location (latitude & longitude) with timeout and error handling
  Future<Position?> getCurrentLocation() async {
    try {
      print('Starting location fetch...');

      bool hasPermission = await checkPermission();
      if (!hasPermission) {
        print('Location permission not granted');
        return null;
      }

      print('Fetching current position...');
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

      print(
        'Location fetched successfully: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } on LocationException {
      rethrow;
    } on Exception catch (e) {
      print('Error getting current location: $e');
      throw LocationException(
        'Failed to get current location. Please ensure location services are enabled.',
        code: 'LOCATION_FETCH_FAILED',
      );
    }
  }

  /// Get formatted address from latitude & longitude with better formatting
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      print('Fetching address for coordinates: $lat, $lng');

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
        print('No address found for coordinates: $lat, $lng');
        return _getFallbackAddress(lat, lng);
      }

      final placemark = placemarks.first;
      final String formattedAddress = _formatAddress(placemark);

      print('Address found: $formattedAddress');
      return formattedAddress;
    } on LocationException {
      rethrow;
    } catch (e) {
      print('Error getting address from coordinates: $e');
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
      return 'Unknown Location';
    }

    return parts.join(', ');
  }

  /// Fallback address when geocoding fails
  String _getFallbackAddress(double lat, double lng) {
    return 'Location: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  /// Helper method to get current address directly (simplifies UI usage)
  Future<String?> getCurrentAddress() async {
    try {
      print('Getting current address...');
      final Position? position = await getCurrentLocation();

      if (position == null) {
        print('No position available for address lookup');
        return null;
      }

      final String address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      print('Current address resolved: $address');
      return address;
    } on LocationException catch (e) {
      print('Error getting current address: ${e.message}');
      return 'Unable to determine address: ${e.message}';
    } catch (e) {
      print('Unexpected error in getCurrentAddress: $e');
      return 'Unable to determine current address';
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
      print('Error in location stream: $error');
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

      print('Distance calculated: ${distance.toStringAsFixed(2)} meters');
      return distance;
    } catch (e) {
      print('Error calculating distance: $e');
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
      print('Error getting location accuracy: $e');
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
      print('Error checking precise location: $e');
      return false;
    }
  }

  /// Debug method to log location status
  Future<void> debugLocationStatus() async {
    try {
      print('=== Location Service Debug ===');
      print('Location service enabled: ${await isLocationServiceEnabled()}');
      print('Location permission: ${await Geolocator.checkPermission()}');
      print('Has precise location: ${await hasPreciseLocation()}');

      final Position? position = await getCurrentLocation();
      if (position != null) {
        print('Current position: ${position.latitude}, ${position.longitude}');
        print('Accuracy: ${position.accuracy} meters');
        final address = await getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        print('Current address: $address');
      } else {
        print('No current position available');
      }
      print('=== End Debug ===');
    } catch (e) {
      print('Debug error: $e');
    }
  }
}
