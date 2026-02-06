import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeocodingService {
  static Future<LatLng?> getCoordinates(String commune, String wilaya) async {
    try {
      final query = '$commune, $wilaya, Algeria';
      final encodedQuery = Uri.encodeComponent(query);

      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=1'),
        headers: {'User-Agent': 'YourAppName/1.0'}, // Required by Nominatim
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        }
      }
      return null;
    } catch (e) {
      print('Error geocoding $commune, $wilaya: $e');
      return null;
    }
  }

  // Optional: Get coordinates for just a wilaya (fallback)
  static Future<LatLng?> getWilayaCoordinates(String wilaya) async {
    try {
      final query = '$wilaya, Algeria';
      final encodedQuery = Uri.encodeComponent(query);

      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=1'),
        headers: {'User-Agent': 'AkhdemLi/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        }
      }
      return null;
    } catch (e) {
      print('Error geocoding $wilaya: $e');
      return null;
    }
  }
}
