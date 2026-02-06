import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/ViewModel/search_view_model.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_page.dart';
import 'package:service_app/screens/profile/provider_profile/provider_profile_page.dart';
import 'package:service_app/screens/search/search_filter_dialog.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/services/wilaya_service.dart';
import 'package:service_app/services/categories_service.dart';
import 'package:service_app/services/location_service.dart';
import 'package:service_app/services/geocoding_service.dart';

// Modern Color Palette
const Color kPrimaryColor = Color(0xFF6C63FF);
const Color kSecondaryColor = Color(0xFF4A90E2);
const Color kAccentColor = Color(0xFFFF6584);
const Color kSuccessColor = Color(0xFF4CAF50);
const Color kBackgroundColor = Color(0xFFF8F9FF);
const Color kCardColor = Color(0xFFFFFFFF);
const Color kDarkText = Color(0xFF2D3748);
const Color kMediumText = Color(0xFF718096);
const Color kLightText = Color(0xFFA0AEC0);
const Color kBorderColor = Color(0xFFE2E8F0);
const Color kShadowColor = Color(0x1A000000);

// Custom Gradients
const LinearGradient kPrimaryGradient = LinearGradient(
  colors: [Color(0xFF6C63FF), Color(0xFF4A90E2)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class MapSearchPage extends StatefulWidget {
  const MapSearchPage({super.key});

  @override
  State<MapSearchPage> createState() => _MapSearchPageState();
}

class _MapSearchPageState extends State<MapSearchPage> {
  late GoogleMapController _mapController;
  CameraPosition? _initialCameraPosition;
  Set<Marker> _markers = {};
  final Map<String, BitmapDescriptor> _markerCache = {};

  // ViewModel
  late SearchViewModel _searchViewModel;

  // Services
  final CategoriesService _categoriesService = CategoriesService();
  final LocationService _locationService = LocationService();

  // Current filters
  Map<String, dynamic> _currentFilters = {};
  LatLng? _userLocation;
  bool _isLoadingLocation = false;
  List<String> _wilayas = [];
  Map<String, List<String>> _categoriesWithSubcategories = {};

  @override
  void initState() {
    super.initState();
    _searchViewModel = SearchViewModel();
    _initializeMap();
    _loadInitialData();
  }

  @override
  void dispose() {
    _clearResources();
    super.dispose();
  }

  void _clearResources() {
    _markers.clear();
    _markerCache.clear();
    try {
      _mapController.dispose();
    } catch (e) {
      print('Error clearing map resources: $e');
    }
  }

  Future<void> _initializeMap() async {
    try {
      setState(() {
        _isLoadingLocation = true;
      });

      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        _userLocation = LatLng(position.latitude, position.longitude);
        setState(() {
          _initialCameraPosition = CameraPosition(
            target: _userLocation!,
            zoom: 13.5,
            tilt: 0,
            bearing: 0,
          );
        });
      } else {
        setState(() {
          _initialCameraPosition = const CameraPosition(
            target: LatLng(36.7525, 3.0420),
            zoom: 13.5,
          );
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _initialCameraPosition = const CameraPosition(
          target: LatLng(36.7525, 3.0420),
          zoom: 13.5,
        );
      });
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _loadInitialData() async {
    try {
      _wilayas = WilayaService.getAllWilayaNames();
      _categoriesWithSubcategories =
          await _categoriesService.getCategoriesForFilter();
      await _searchProvidersWithCurrentFilters();
    } catch (e) {
      print('Error loading initial data: $e');
    }
  }

  Future<void> _searchProvidersWithCurrentFilters() async {
    try {
      setState(() {
        _searchViewModel.clearResults();
        _markers.clear();
      });

      await _searchViewModel.searchWithFilters(_currentFilters);

      if (_searchViewModel.providerResults.isEmpty) {
        _centerMapOnSelectedLocation();
      } else {
        await _createMarkersFromProviders(_searchViewModel.providerResults);
      }
    } catch (e) {
      print('Error searching providers: $e');
      _centerMapOnSelectedLocation();
    }
  }

  Future<void> _createMarkersFromProviders(
    List<ProviderModel> providers,
  ) async {
    final Set<Marker> newMarkers = {};

    for (var provider in providers) {
      if (provider.location == null) continue;

      print(
          'Creating marker for ${provider.name} - Has photo: ${provider.photoUrl != null && provider.photoUrl!.isNotEmpty}');

      final marker = Marker(
        markerId: MarkerId(
          provider.uid ??
              '${provider.name}_${DateTime.now().millisecondsSinceEpoch}',
        ),
        position: provider.location!,
        infoWindow: InfoWindow(
          title: provider.name,
          snippet: '${provider.profession} • ${provider.wilaya}',
          onTap: () => _handleMarkerTap(provider),
        ),
        icon: await _createCustomMarkerIcon(provider),
        anchor: const Offset(0.5, 0.5),
        onTap: () => _handleMarkerTap(provider),
      );

      newMarkers.add(marker);
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  Future<BitmapDescriptor> _createCustomMarkerIcon(
    ProviderModel provider,
  ) async {
    try {
      const double markerSize = 70.0;
      const double borderWidth = 3.0;
      const double imageSize = markerSize - (borderWidth * 2);

      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      final paint = Paint();

      // Draw outer glow effect
      paint
        ..color = kPrimaryColor.withOpacity(0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(markerSize / 2, markerSize / 2),
        markerSize / 2,
        paint,
      );

      // Draw white border
      paint
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(markerSize / 2, markerSize / 2),
        markerSize / 2 - 1,
        paint,
      );

      // Draw inner circle background with gradient
      final gradient = LinearGradient(
        colors: [
          _getProfessionColor(provider.profession),
          _getProfessionColor(provider.profession).withOpacity(0.8),
        ],
      );
      paint.shader = gradient.createShader(
        Rect.fromCircle(
          center: Offset(markerSize / 2, markerSize / 2),
          radius: imageSize / 2,
        ),
      );
      canvas.drawCircle(
        Offset(markerSize / 2, markerSize / 2),
        imageSize / 2,
        paint,
      );

      // Check if provider has a base64 image
      bool hasImage = false;
      if (provider.photoUrl != null && provider.photoUrl!.isNotEmpty) {
        try {
          // Check if it's a base64 string (starts with data:image)
          if (provider.photoUrl!.startsWith('data:image')) {
            // Extract base64 data
            final base64String = provider.photoUrl!.split(',').last;

            // Decode base64 to bytes
            final bytes = base64Decode(base64String);

            // Decode the image
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            final image = frame.image;

            // Create circular clip path
            final Path clipPath = Path()
              ..addOval(Rect.fromCircle(
                center: Offset(markerSize / 2, markerSize / 2),
                radius: imageSize / 2 - 2,
              ));

            canvas.save();
            canvas.clipPath(clipPath);

            // Draw the image
            final src = Rect.fromLTWH(
                0, 0, image.width.toDouble(), image.height.toDouble());
            final dst = Rect.fromCircle(
              center: Offset(markerSize / 2, markerSize / 2),
              radius: imageSize / 2 - 2,
            );

            canvas.drawImageRect(image, src, dst, Paint());
            canvas.restore();

            hasImage = true;
            print('Successfully loaded base64 image for ${provider.name}');
          } else if (provider.photoUrl!.startsWith('http')) {
            // Handle URL images - you can implement network image loading here
            print(
                'Network image URL found for ${provider.name}: ${provider.photoUrl}');
          }
        } catch (e) {
          print('Error loading provider image for ${provider.name}: $e');
        }
      }

      // Draw profession initial if no image was loaded
      if (!hasImage) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: _getProfessionInitial(provider.profession),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Exo2',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            markerSize / 2 - textPainter.width / 2,
            markerSize / 2 - textPainter.height / 2,
          ),
        );
      }

      // Add verification badge if provider is verified
      if (provider.subscriptionActive) {
        paint
          ..color = kSuccessColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(markerSize - 12, 12),
          8,
          paint,
        );
        paint
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(markerSize - 12, 12),
          5,
          paint,
        );
      }

      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(
        markerSize.toInt(),
        markerSize.toInt(),
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final markerIcon = BitmapDescriptor.fromBytes(buffer);

      // Cache the marker
      final cacheKey =
          '${provider.uid}_${provider.photoUrl ?? provider.profession}';
      _markerCache[cacheKey] = markerIcon;

      return markerIcon;
    } catch (e) {
      print('Error creating custom marker for ${provider.name}: $e');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    }
  }

  // Helper function to decode base64
  Uint8List base64Decode(String base64String) {
    // Remove any whitespace and URL encoding
    final cleanString = base64String
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');

    return Uint8List.fromList(_base64Decode(cleanString));
  }

  List<int> _base64Decode(String input) {
    final output = <int>[];
    var chr1, chr2, chr3;
    var enc1, enc2, enc3, enc4;
    var i = 0;

    final keyStr =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

    input = input.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');

    while (i < input.length) {
      enc1 = keyStr.indexOf(input[i++]);
      enc2 = keyStr.indexOf(input[i++]);
      enc3 = keyStr.indexOf(input[i++]);
      enc4 = keyStr.indexOf(input[i++]);

      chr1 = (enc1 << 2) | (enc2 >> 4);
      chr2 = ((enc2 & 15) << 4) | (enc3 >> 2);
      chr3 = ((enc3 & 3) << 6) | enc4;

      output.add(chr1);
      if (enc3 != 64) output.add(chr2);
      if (enc4 != 64) output.add(chr3);
    }

    return output;
  }

  void _applyFilters(Map<String, dynamic> filters) async {
    setState(() {
      _currentFilters = filters;
      _markers.clear();
      _markerCache.clear();
    });

    if (filters['useDistanceFilter'] == true && _userLocation != null) {
      _currentFilters['userLat'] = _userLocation!.latitude;
      _currentFilters['userLng'] = _userLocation!.longitude;
      _currentFilters['maxDistanceKm'] = filters['maxDistance'] ?? 20.0;
    }

    await _searchProvidersWithCurrentFilters();
  }

  void _centerMapOnSelectedLocation() {
    final wilayaCoordinates = _currentFilters['wilayaCoordinates'] as LatLng?;
    final wilayaName = _currentFilters['wilaya'] as String?;

    if (wilayaCoordinates != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(wilayaCoordinates, 13),
      );
      _showNoProvidersMessage(wilayaName ?? 'cette région');
    } else if (wilayaName != null) {
      _getAndCenterWilaya(wilayaName);
    } else if (_userLocation != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 13),
      );
    }
  }

  Future<void> _getAndCenterWilaya(String wilayaName) async {
    try {
      final coordinates = await GeocodingService.getWilayaCoordinates(
        wilayaName,
      );
      if (coordinates != null) {
        _mapController.animateCamera(
          CameraUpdate.newLatLngZoom(coordinates, 13),
        );
        _showNoProvidersMessage(wilayaName);
      } else {
        _showNoCoordinatesMessage(wilayaName);
      }
    } catch (e) {
      print('Error getting coordinates for $wilayaName: $e');
      _showNoCoordinatesMessage(wilayaName);
    }
  }

  void _showNoProvidersMessage(String locationName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aucun prestataire trouvé pour $locationName avec ces critères',
                style: TextStyle(fontFamily: 'Exo2'),
              ),
            ),
          ],
        ),
        backgroundColor: kAccentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showNoCoordinatesMessage(String locationName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('Impossible de localiser $locationName'),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => SearchFilterDialog(
        onFiltersApplied: _applyFilters,
        initialWilaya: _currentFilters['wilaya'],
        initialCategory: _currentFilters['category'],
        initialSubcategory: _currentFilters['subcategory'],
      ),
    );
  }

  void _handleMarkerTap(ProviderModel provider) {
    _showProviderInfoSheet(provider);
  }

  void _showProviderInfoSheet(ProviderModel provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildProviderInfoSheet(provider),
    );
  }

  Widget _buildProviderInfoSheet(ProviderModel provider) {
    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                gradient: kPrimaryGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Provider avatar
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: kPrimaryGradient,
                          borderRadius: BorderRadius.circular(35),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: _getProfessionColor(provider.profession),
                            borderRadius: BorderRadius.circular(32),
                            image: provider.photoUrl != null &&
                                    provider.photoUrl!.startsWith('data:image')
                                ? DecorationImage(
                                    image: MemoryImage(
                                      base64Decode(
                                          provider.photoUrl!.split(',').last),
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: provider.photoUrl == null ||
                                  !provider.photoUrl!.startsWith('data:image')
                              ? Center(
                                  child: Text(
                                    _getProfessionInitial(provider.profession),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Exo2',
                                color: kDarkText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              provider.profession,
                              style: TextStyle(
                                fontSize: 16,
                                color: _getProfessionColor(provider.profession),
                                fontFamily: 'Exo2',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (provider.rating > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.star,
                                      color: Colors.amber, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    provider.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: kDarkText,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (provider.subscriptionActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: kPrimaryGradient,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Vérifié',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (provider.wilaya.isNotEmpty || provider.commune.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: kBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: kPrimaryColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Localisation',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: kMediumText,
                                    fontFamily: 'Exo2',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${provider.commune.isNotEmpty ? "${provider.commune}, " : ""}${provider.wilaya}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Exo2',
                                    color: kDarkText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (provider.description.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: kBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 13,
                              color: kMediumText,
                              fontFamily: 'Exo2',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.description,
                            style: TextStyle(
                              color: kDarkText,
                              fontSize: 15,
                              fontFamily: 'Exo2',
                              height: 1.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ProviderProfileScreen(
                                  provider: provider,
                                  serviceCategory: provider.profession,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kCardColor,
                            foregroundColor: kPrimaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: kBorderColor, width: 2),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_outline, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Voir profil',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            // First close the bottom sheet
                            Navigator.pop(context);

                            // Then start the chat with proper implementation
                            await _startChatWithProvider(provider);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                            shadowColor: kPrimaryColor.withOpacity(0.3),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_outlined, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Contacter',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: kMediumText,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: kBorderColor, width: 1.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Fermer',
                          style: TextStyle(
                            fontFamily: 'Exo2',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Updated method to actually create a chat and navigate
  Future<void> _startChatWithProvider(ProviderModel provider) async {
    try {
      // Get current user ID from AuthViewModel
      final authProvider = Provider.of<AuthViewModel>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Veuillez vous connecter pour discuter'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      final currentUserId = currentUser.uid;
      final providerId = provider.uid ?? '';

      // Validate IDs
      if (currentUserId.isEmpty) {
        throw Exception('ID utilisateur invalide');
      }

      if (providerId.isEmpty) {
        throw Exception('ID prestataire invalide');
      }

      // Don't allow chatting with yourself
      if (currentUserId == providerId) {
        throw Exception('Vous ne pouvez pas discuter avec vous-même');
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(kPrimaryColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Création de la discussion...',
                  style: TextStyle(
                    fontSize: 12,
                    color: kMediumText,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      try {
        // Initialize chat view model
        final chatViewModel = ChatViewModel(userId: currentUserId);

        // Create or get chat with provider
        final chatId = await chatViewModel.createChat(
          clientId: currentUserId,
          providerId: providerId,
        );

        // Close loading dialog
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (chatId != null && chatId.isNotEmpty) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
              ]),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );

          // Navigate to discussion page
          await Future.delayed(const Duration(milliseconds: 500));

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DiscussionPage(
                contactName: provider.name,
                isOnline: true,
                chatId: chatId,
                currentUserId: currentUserId,
                chatViewModel: chatViewModel,
                profileImageUrl: provider.photoUrl,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text('Impossible de démarrer la discussion'),
                ],
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        print('Error creating chat: $e');

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Erreur: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      print('Initial error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Text('Erreur initiale: ${e.toString()}'),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Color _getProfessionColor(String profession) {
    final lowerProfession = profession.toLowerCase();

    if (lowerProfession.contains('électr') ||
        lowerProfession.contains('electric')) {
      return Color(0xFFFFB74D);
    } else if (lowerProfession.contains('médec') ||
        lowerProfession.contains('doctor')) {
      return Color(0xFFEF5350);
    } else if (lowerProfession.contains('plomb') ||
        lowerProfession.contains('plumb')) {
      return Color(0xFF42A5F5);
    } else if (lowerProfession.contains('profess') ||
        lowerProfession.contains('teacher') ||
        lowerProfession.contains('tutor')) {
      return Color(0xFF66BB6A);
    } else if (lowerProfession.contains('menuis') ||
        lowerProfession.contains('carpent')) {
      return Color(0xFF8D6E63);
    } else if (lowerProfession.contains('peint') ||
        lowerProfession.contains('paint')) {
      return Color(0xFFAB47BC);
    } else if (lowerProfession.contains('jardin') ||
        lowerProfession.contains('garden')) {
      return Color(0xFF9CCC65);
    } else if (lowerProfession.contains('déménag') ||
        lowerProfession.contains('move')) {
      return Color(0xFFFF7043);
    } else if (lowerProfession.contains('nettoy') ||
        lowerProfession.contains('clean')) {
      return Color(0xFF29B6F6);
    } else if (lowerProfession.contains('répar') ||
        lowerProfession.contains('repair') ||
        lowerProfession.contains('handyman')) {
      return Color(0xFFFFA726);
    } else if (lowerProfession.contains('install')) {
      return Color(0xFF26C6DA);
    }

    return kPrimaryColor;
  }

  String _getProfessionInitial(String profession) {
    if (profession.isEmpty) return "?";
    return profession.substring(0, 1).toUpperCase();
  }

  String _buildSearchHint() {
    if (_currentFilters.isEmpty) {
      return "Filtrer par wilaya, catégorie...";
    }

    final wilaya = _currentFilters['wilaya'] ?? '';
    final category = _currentFilters['category'] ?? '';
    final distance = _currentFilters['maxDistance'] ?? 20;

    if (category.isNotEmpty && wilaya.isNotEmpty) {
      return "$category • $wilaya • ${distance.toInt()}km";
    } else if (wilaya.isNotEmpty) {
      return "$wilaya • ${distance.toInt()}km";
    } else if (category.isNotEmpty) {
      return "$category • ${distance.toInt()}km";
    } else {
      return "Filtres actifs • ${distance.toInt()}km";
    }
  }

  void _clearFilters() {
    setState(() {
      _currentFilters = {};
      _markers.clear();
      _markerCache.clear();
    });

    _searchProvidersWithCurrentFilters();
  }

  void _centerMapOnUser() {
    if (_userLocation != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 14),
      );
    }
  }

  void _centerMapOnMarkers() {
    if (_markers.isNotEmpty) {
      final bounds = _calculateBounds(_markers.map((m) => m.position).toList());
      _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> positions) {
    double? minLat, maxLat, minLng, maxLng;

    for (var pos in positions) {
      minLat = minLat != null
          ? (pos.latitude < minLat ? pos.latitude : minLat)
          : pos.latitude;
      maxLat = maxLat != null
          ? (pos.latitude > maxLat ? pos.latitude : maxLat)
          : pos.latitude;
      minLng = minLng != null
          ? (pos.longitude < minLng ? pos.longitude : minLng)
          : pos.longitude;
      maxLng = maxLng != null
          ? (pos.longitude > maxLng ? pos.longitude : maxLng)
          : pos.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat ?? 0, minLng ?? 0),
      northeast: LatLng(maxLat ?? 0, maxLng ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _clearResources();
        return true;
      },
      child: ChangeNotifierProvider.value(
        value: _searchViewModel,
        child: Scaffold(
          backgroundColor: kBackgroundColor,
          body: SafeArea(
            top: false,
            child: Stack(
              children: [
                SizedBox.expand(
                  child: _isLoadingLocation || _initialCameraPosition == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: kCardColor,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor:
                                      AlwaysStoppedAnimation(kPrimaryColor),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _isLoadingLocation
                                    ? "Chargement de la position..."
                                    : "Chargement de la carte...",
                                style: TextStyle(
                                  color: kMediumText,
                                  fontSize: 16,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                            ],
                          ),
                        )
                      : GoogleMap(
                          mapType: MapType.normal,
                          initialCameraPosition: _initialCameraPosition!,
                          onMapCreated: (controller) {
                            _mapController = controller;
                          },
                          markers: _markers,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          zoomGesturesEnabled: true,
                          scrollGesturesEnabled: true,
                          rotateGesturesEnabled: true,
                          tiltGesturesEnabled: false,
                          compassEnabled: true,
                          mapToolbarEnabled: false,
                        ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildSearchBar(context),
                ),
                Consumer<SearchViewModel>(
                  builder: (context, viewModel, child) {
                    if (viewModel.isLoading) {
                      return Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.2),
                          child: Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: kCardColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(kPrimaryColor),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Recherche...',
                                    style: TextStyle(
                                      color: kMediumText,
                                      fontSize: 12,
                                      fontFamily: 'Exo2',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                Positioned(
                  right: 20,
                  bottom: 140,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: kCardColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _centerMapOnUser,
                          icon: Icon(Icons.my_location,
                              color: kPrimaryColor, size: 24),
                          style: IconButton.styleFrom(
                            backgroundColor: kCardColor,
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_markers.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            color: kCardColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: _centerMapOnMarkers,
                            icon: Icon(Icons.zoom_out_map,
                                color: kPrimaryColor, size: 24),
                            style: IconButton.styleFrom(
                              backgroundColor: kCardColor,
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: kCardColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            IconButton(
                              onPressed: () {
                                _mapController
                                    .animateCamera(CameraUpdate.zoomIn());
                              },
                              icon: Icon(Icons.add,
                                  color: kPrimaryColor, size: 24),
                              style: IconButton.styleFrom(
                                backgroundColor: kCardColor,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                            Container(
                              height: 1,
                              color: kBorderColor.withOpacity(0.5),
                            ),
                            IconButton(
                              onPressed: () {
                                _mapController
                                    .animateCamera(CameraUpdate.zoomOut());
                              },
                              icon: Icon(Icons.remove,
                                  color: kPrimaryColor, size: 24),
                              style: IconButton.styleFrom(
                                backgroundColor: kCardColor,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Consumer<SearchViewModel>(
                  builder: (context, viewModel, child) {
                    if (viewModel.error != null &&
                        viewModel.error!.isNotEmpty) {
                      return Positioned(
                        top: 100,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.3),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  viewModel.error!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Exo2',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () => viewModel.clearError(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                if (_markers.isNotEmpty)
                  Positioned(
                    top: 120,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: kCardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: kPrimaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_markers.length} prestataire${_markers.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: kDarkText,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Exo2',
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(20, statusBarHeight + 10, 20, 14),
      decoration: BoxDecoration(
        color: kCardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {
                _clearResources();
                Navigator.of(context).pop();
              },
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: kPrimaryColor,
                size: 20,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _showFilterDialog,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: kBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorderColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.search,
                      color: kMediumText,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Consumer<SearchViewModel>(
                        builder: (context, viewModel, child) {
                          return Text(
                            _buildSearchHint(),
                            style: TextStyle(
                              color: kMediumText,
                              fontSize: 15,
                              fontFamily: 'Exo2',
                            ),
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    if (_currentFilters.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: kPrimaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _showFilterDialog,
              icon: const Icon(
                Icons.filter_alt,
                color: Colors.white,
                size: 20,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
          if (_currentFilters.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kAccentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: _clearFilters,
                icon: Icon(
                  Icons.close,
                  color: kAccentColor,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
