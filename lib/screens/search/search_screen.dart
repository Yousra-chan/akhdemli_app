import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/ViewModel/search_view_model.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_page.dart';
import 'package:service_app/screens/profile/provider_profile/provider_profile_page.dart';
import 'package:service_app/screens/search/search_filter_dialog.dart';
import 'search_constants.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/Services/location_service.dart';
import 'package:service_app/Services/geocoding_service.dart';
import 'package:service_app/Services/wilaya_service.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:service_app/screens/home/home_screen/home_constants.dart';
import 'package:latlong2/latlong.dart';

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

const LinearGradient kPrimaryGradient = LinearGradient(
  colors: [Color(0xFF6C63FF), Color(0xFF4A90E2)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class MapSearchPage extends StatefulWidget {
  final String? initialQuery;
  const MapSearchPage({super.key, this.initialQuery});

  @override
  State<MapSearchPage> createState() => _MapSearchPageState();
}

class _MapSearchPageState extends State<MapSearchPage> {
  late MapController _mapController;
  LatLng? _initialCenter;
  double _initialZoom = 13.5;
  List<Marker> _markers = [];

  late SearchViewModel _searchViewModel;
  final TextEditingController _textController = TextEditingController();
  Timer? _debounce;

  final LocationService _locationService = LocationService();

  Map<String, dynamic> _currentFilters = {};
  String? _searchTextQuery;
  LatLng? _userLocation;
  bool _isLoadingLocation = false;

  // ─────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _searchViewModel = SearchViewModel();
    _initializeMap();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _textController.text = widget.initialQuery!;
      _searchTextQuery = widget.initialQuery;
      _executeInitialTextSearch(widget.initialQuery!);
    } else {
      _loadInitialData();
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() {
        _searchTextQuery = query;
      });
      if (query.isNotEmpty) {
        await _executeInitialTextSearch(query);
      } else {
        await _loadInitialData();
      }
    });
  }

  Future<void> _executeInitialTextSearch(String query) async {
    try {
      // Don't use _isLoadingLocation for subsequent searches to avoid hiding the map
      // SearchViewModel.isLoading will show a smaller overlay instead
      await _searchViewModel.executeSearch(query);
      if (mounted) {
        if (_searchViewModel.providerResults.isNotEmpty) {
          await _createMarkersFromProviders(_searchViewModel.providerResults);
          // Small delay to ensure markers are laid out
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _centerMapOnMarkers();
          });
        } else {
          setState(() => _markers = []);
        }
      }
    } catch (e) {
      debugPrint('Error executing initial text search: $e');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    _clearResources();
    super.dispose();
  }

  void _clearResources() {
    _markers.clear();
  }

  // ─────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────

  Future<void> _initializeMap() async {
    try {
      setState(() => _isLoadingLocation = true);

      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        _userLocation = LatLng(position.latitude, position.longitude);
        setState(() {
          _initialCenter = _userLocation!;
          _initialZoom = 13.5;
        });
      } else {
        setState(() {
          _initialCenter = LatLng(36.7525, 3.0420);
          _initialZoom = 13.5;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() {
        _initialCenter = LatLng(36.7525, 3.0420);
        _initialZoom = 13.5;
      });
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _loadInitialData() async {
    try {
      await _searchProvidersWithCurrentFilters();
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SEARCH & MARKERS
  // ─────────────────────────────────────────────────────────────

  Future<void> _searchProvidersWithCurrentFilters() async {
    try {
      setState(() {
        _searchViewModel.clearResults();
        _markers.clear();
      });

      await _searchViewModel.searchWithFilters(_currentFilters);
      
      if (!mounted) return;

      // Always center map according to selected location/wilaya or user location
      // This ensures map moves when filters are applied even if results are found
      _centerMapOnSelectedLocation();

      if (_searchViewModel.providerResults.isNotEmpty) {
        await _createMarkersFromProviders(_searchViewModel.providerResults);
      }
    } catch (e) {
      debugPrint('Error searching providers: $e');
      _centerMapOnSelectedLocation();
    }
  }

  Future<void> _createMarkersFromProviders(List<ProviderModel> providers) async {
    final List<Marker> newMarkers = [];

    for (var provider in providers) {
      if (provider.location == null) continue;

      newMarkers.add(
        Marker(
          point: provider.location!,
          width: 80,
          height: 104,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _handleMarkerTap(provider);
            },
            child: _buildCustomMarkerWidget(provider),
          ),
        ),
      );
    }

    if (mounted) {
      setState(() => _markers = newMarkers);
    }
  }

  Widget _buildCustomMarkerWidget(ProviderModel provider) {
    final profColor = _getProfessionColor(provider.profession);
    const double avatarR = 30.0;
    const double outerR = avatarR + 4;

    return SizedBox(
      width: 80,
      height: 104,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // ── Drop shadow ──
          Positioned(
            top: 6,
            child: Container(
              width: outerR * 2,
              height: outerR * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),

          // ── Pin tail ──
          Positioned(
            top: outerR * 2 - 2,
            child: CustomPaint(
              size: const Size(20, 36),
              painter: _PinTailPainter(color: profColor),
            ),
          ),

          // ── White outer ring & Gradient fill circle ──
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: outerR * 2,
            height: outerR * 2,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Container(
              width: avatarR * 2,
              height: avatarR * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [profColor, Color.lerp(profColor, Colors.black, 0.18)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: _buildMarkerAvatar(provider),
            ),
          ),

          // ── Verified badge ──
          if (provider.subscriptionActive)
            Positioned(
              top: 2,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: kSuccessColor,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarkerAvatar(ProviderModel provider) {
    bool hasImage = provider.photoUrl.startsWith('data:image');
    if (hasImage) {
      try {
        final bytes = base64.decode(provider.photoUrl.split(',').last);
        return ClipOval(
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: 60,
            height: 60,
          ),
        );
      } catch (_) {}
    }

    return Center(
      child: Text(
        _getProfessionInitial(provider.profession),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
          fontFamily: 'Exo2',
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FILTERS
  // ─────────────────────────────────────────────────────────────

  void _applyFilters(Map<String, dynamic> filters) async {
    // Create a copy to avoid side effects
    final Map<String, dynamic> updatedFilters = Map<String, dynamic>.from(filters);
    
    LatLng? searchCenter;
    
    // Determine the search center: Prioritize explicitly selected Wilaya coordinates
    if (filters['wilayaCoordinates'] != null) {
      searchCenter = filters['wilayaCoordinates'] as LatLng;
    } 
    // Fallback to user location if available
    else if (_userLocation != null) {
      searchCenter = _userLocation;
    }

    // If we have a center, set it in the filters for the ViewModel
    if (searchCenter != null) {
      updatedFilters['userLat'] = searchCenter.latitude;
      updatedFilters['userLng'] = searchCenter.longitude;
      
      // Ensure maxDistanceKm is set if useDistanceFilter is true
      if (filters['useDistanceFilter'] == true) {
        updatedFilters['maxDistanceKm'] = filters['maxDistance'] ?? 20.0;
      }
    }

    setState(() {
      _currentFilters = updatedFilters;
      _searchTextQuery = null; // Reset text search when applying structured filters
      _markers.clear();
    });

    await _searchProvidersWithCurrentFilters();
  }

  void _clearFilters() {
    setState(() {
      _textController.clear();
      _currentFilters = {};
      _searchTextQuery = null;
      _markers.clear();
    });
    _searchProvidersWithCurrentFilters();
  }

  // ─────────────────────────────────────────────────────────────
  // MAP NAVIGATION
  // ─────────────────────────────────────────────────────────────

  double _getZoomLevelForRadius(double radiusKm) {
    if (radiusKm <= 5) return 14.0;
    if (radiusKm <= 10) return 13.0;
    if (radiusKm <= 25) return 11.5;
    if (radiusKm <= 50) return 10.0;
    if (radiusKm <= 100) return 8.5;
    if (radiusKm <= 200) return 7.5;
    return 6.0;
  }

  void _centerMapOnSelectedLocation() {
    final wilayaCoordinates = _currentFilters['wilayaCoordinates'] as LatLng?;
    final wilayaName = _currentFilters['wilaya'] as String?;
    final maxDistance = _currentFilters['maxDistanceKm'] as double?;
    final useDistance = _currentFilters['useDistanceFilter'] as bool? ?? false;
    
    double zoom = 13.0;
    if (useDistance && maxDistance != null && maxDistance.isFinite && maxDistance > 0) {
      zoom = _getZoomLevelForRadius(maxDistance);
    }

    if (wilayaCoordinates != null && 
        wilayaCoordinates.latitude.isFinite && 
        wilayaCoordinates.longitude.isFinite) {
      _mapController.move(wilayaCoordinates, zoom);
      if (_searchViewModel.providerResults.isEmpty) {
        _showNoProvidersMessage(wilayaName ?? '');
      }
    } else if (wilayaName != null) {
      _getAndCenterWilaya(wilayaName, zoom: zoom);
    } else if (_userLocation != null && 
               _userLocation!.latitude.isFinite && 
               _userLocation!.longitude.isFinite) {
      _mapController.move(_userLocation!, zoom);
    }
  }

  Future<void> _getAndCenterWilaya(String wilayaName, {double zoom = 13.0}) async {
    try {
      final coordinates = await GeocodingService.getWilayaCoordinates(wilayaName);
      if (coordinates != null) {
        _mapController.move(coordinates, zoom);
        if (_searchViewModel.providerResults.isEmpty) {
          _showNoProvidersMessage(wilayaName);
        }
      } else {
        _showNoCoordinatesMessage(wilayaName);
      }
    } catch (e) {
      _showNoCoordinatesMessage(wilayaName);
    }
  }

  void _centerMapOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 14);
    }
  }

  void _centerMapOnMarkers() {
    if (_markers.isNotEmpty) {
      try {
        final validPoints = _markers
            .map((m) => m.point)
            .where((p) =>
                p.latitude.isFinite &&
                p.longitude.isFinite &&
                !p.latitude.isNaN &&
                !p.longitude.isNaN)
            .toList();

        if (validPoints.isEmpty) return;

        if (validPoints.length == 1) {
          _mapController.move(validPoints.first, 14.0);
          return;
        }

        final bounds = LatLngBounds.fromPoints(validPoints);
        
        // Ensure bounds are not zero-size (which can cause NaN in fitCamera)
        if (bounds.north == bounds.south && bounds.east == bounds.west) {
          _mapController.move(validPoints.first, 14.0);
        } else {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds, 
              padding: const EdgeInsets.all(100),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error centering map on markers: $e');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DIALOGS / SHEETS
  // ─────────────────────────────────────────────────────────────

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

  void _handleMarkerTap(ProviderModel provider) => _showProviderInfoSheet(provider);

  void _showProviderInfoSheet(ProviderModel provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildProviderInfoSheet(provider),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PROVIDER INFO BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────

  Widget _buildProviderInfoSheet(ProviderModel provider) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final theme = Theme.of(context);
    final profColor = _getProfessionColor(provider.profession);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection:
      languageProvider.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.45 : 0.15),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Hero header ──
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Gradient background
                    Container(
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            profColor,
                            Color.lerp(profColor, Colors.black, 0.25)!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    // Subtle pattern overlay
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.06,
                        child: CustomPaint(painter: _DotPatternPainter()),
                      ),
                    ),
                    // Drag handle
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Verified chip
                    if (provider.subscriptionActive)
                      Positioned(
                        top: 26,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.45)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                languageProvider.tr('verified',
                                    category: 'search'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Avatar (overlapping)
                    Positioned(
                      bottom: -34,
                      left: 20,
                      child: _buildAvatar(provider, profColor, theme),
                    ),
                  ],
                ),

                // ── Name / profession ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Exo2',
                                color: theme.textTheme.titleLarge?.color ??
                                    kDarkText,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: profColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  provider.profession,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: profColor,
                                    fontFamily: 'Exo2',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (provider.rating > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFFFA000), size: 18),
                              const SizedBox(width: 4),
                              Text(
                                provider.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6D4C41),
                                  fontFamily: 'Exo2',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Divider ──
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Divider(height: 1, color: theme.dividerColor),
                ),

                // ── Info rows ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      if (provider.wilaya.isNotEmpty ||
                          provider.commune.isNotEmpty)
                        _InfoRow(
                          icon: Icons.location_on_rounded,
                          iconColor: profColor,
                          label: languageProvider.tr('location',
                              category: 'search'),
                          value: provider.getLocalizedLocation(languageProvider),
                          theme: theme,
                        ),
                      if (provider.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.info_outline_rounded,
                          iconColor: profColor,
                          label: languageProvider.tr('description',
                              category: 'search'),
                          value: provider.description,
                          maxLines: 2,
                          theme: theme,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Action buttons ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _OutlineButton(
                              icon: Icons.person_outline_rounded,
                              label: languageProvider.tr('view_profile',
                                  category: 'search'),
                              color: profColor,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ProviderProfileScreen(
                                    provider: provider,
                                    serviceCategory: provider.profession,
                                  ),
                                ));
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _FilledButton(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: languageProvider.tr('contact',
                                  category: 'search'),
                              color: profColor,
                              onTap: () async {
                                Navigator.pop(context);
                                await _startChatWithProvider(provider);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            languageProvider.tr('close', category: 'search'),
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Exo2',
                              color: theme.textTheme.bodySmall?.color ??
                                  kMediumText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ProviderModel provider, Color profColor, ThemeData theme) {
    final bool hasBase64 = provider.photoUrl.startsWith('data:image');

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.cardColor, width: 3.5),
        boxShadow: [
          BoxShadow(
            color: profColor.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        color: profColor,
        image: hasBase64
            ? DecorationImage(
          image: MemoryImage(
            base64.decode(provider.photoUrl.split(',').last),
          ),
          fit: BoxFit.cover,
        )
            : null,
      ),
      child: !hasBase64
          ? Center(
        child: Text(
          _getProfessionInitial(provider.profession),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'Exo2',
          ),
        ),
      )
          : null,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CHAT
  // ─────────────────────────────────────────────────────────────

  Future<void> _startChatWithProvider(ProviderModel provider) async {
    final languageProvider =
    Provider.of<LanguageProvider>(context, listen: false);

    try {
      final authProvider = Provider.of<AuthViewModel>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        AppSnackBar.showWarning(
          context,
          languageProvider.tr('login_required_chat', category: 'search'),
        );
        return;
      }

      final currentUserId = currentUser.uid;
      final providerId = provider.uid ?? '';

      if (currentUserId.isEmpty) {
        throw Exception(
            languageProvider.tr('invalid_user_id', category: 'search'));
      }
      if (providerId.isEmpty) {
        throw Exception(
            languageProvider.tr('invalid_provider_id', category: 'search'));
      }
      if (currentUserId == providerId) {
        throw Exception(
            languageProvider.tr('cannot_chat_self', category: 'search'));
      }

      final theme = Theme.of(context);

      // Show a smaller, non-blocking toast or a subtle overlay instead of a dialog if possible,
      // but since we need to wait for chatId, we'll keep the dialog but make it more responsive.
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  languageProvider.tr('creating_discussion', category: 'search'),
                  style: const TextStyle(fontFamily: 'Exo2'),
                ),
              ],
            ),
          ),
        ),
      );

      try {
        final chatViewModel = ChatViewModel(userId: currentUserId);
        final chatId = await chatViewModel.createChat(
          clientId: currentUserId,
          providerId: providerId,
        );

        if (Navigator.canPop(context)) Navigator.pop(context);

        if (chatId != null && chatId.isNotEmpty) {
          AppSnackBar.showSuccess(
            context,
            languageProvider.tr('chat_created', category: 'search'),
          );
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DiscussionPage(
                contactName: provider.name,
                isOnline: true,
                chatId: chatId,
                currentUserId: currentUserId,
                chatViewModel: chatViewModel,
                profileImageUrl: provider.photoUrl,
                contactUserId: providerId,
              ),
            ),
          );
        } else {
          AppSnackBar.showError(
            context,
            languageProvider.tr('chat_start_failed', category: 'search'),
          );
        }
      } catch (e) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        AppSnackBar.showError(
          context,
          languageProvider.trParams('chat_error',
              category: 'search', params: {'error': e.toString()}),
        );
      }
    } catch (e) {
      AppSnackBar.showError(
        context,
        languageProvider.trParams('initial_error',
            category: 'search', params: {'error': e.toString()}),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  void _showNoProvidersMessage(String locationName) {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    AppSnackBar.showWarning(
      context,
      lp.trParams('no_providers_found',
          category: 'search', params: {'location': locationName}),
    );
  }

  void _showNoCoordinatesMessage(String locationName) {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    AppSnackBar.showError(
      context,
      lp.trParams('unable_to_locate',
          category: 'search', params: {'location': locationName}),
    );
  }

  Color _getProfessionColor(String profession) {
    return getMarkerColorForCategory(profession);
  }

  String _getProfessionInitial(String profession) =>
      profession.isEmpty ? '?' : profession.substring(0, 1).toUpperCase();

  String _buildSearchHint() {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    
    if (_searchTextQuery != null && _searchTextQuery!.isNotEmpty) {
      return _searchTextQuery!;
    }

    if (_currentFilters.isEmpty) return lp.tr('filter_hint', category: 'search');

    final wilaya = _currentFilters['wilaya'] ?? '';
    final categoryName = _currentFilters['category'] ?? '';
    final distance = _currentFilters['maxDistance'] ?? 20;

    // Use simple translation helper since we can't await here
    String category = categoryName;
    if (categoryName.isNotEmpty) {
      category = getTranslatedCategoryName(categoryName, lp);
    }

    final km = lp.tr('unit_km', category: 'search');

    if (category.isNotEmpty && wilaya.isNotEmpty) {
      return '$category • $wilaya • ${distance.toInt()}$km';
    }
    if (wilaya.isNotEmpty) return '$wilaya • ${distance.toInt()}$km';
    if (category.isNotEmpty) return '$category • ${distance.toInt()}$km';
    return lp.trParams('active_filters',
        category: 'search',
        params: {'distance': distance.toInt().toString()});
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;

    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: ChangeNotifierProvider.value(
        value: _searchViewModel,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            top: false,
            child: Stack(
              children: [
                // ── Map ──
                SizedBox.expand(
                  child: _isLoadingLocation || _initialCenter == null
                      ? _buildLoadingView(theme, cardColor)
                      : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _initialCenter!,
                      initialZoom: _initialZoom,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.service_app',
                      ),
                      MarkerLayer(markers: _markers),
                    ],
                  ),
                ),

                // ── Search bar ──
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildSearchBar(context),
                ),

                // ── Loading overlay ──
                Consumer<SearchViewModel>(
                  builder: (context, viewModel, child) {
                    if (!viewModel.isLoading) return const SizedBox.shrink();
                    final lp = Provider.of<LanguageProvider>(context);
                    return Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.18),
                        child: Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
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
                                    valueColor: AlwaysStoppedAnimation(
                                        theme.primaryColor),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  lp.tr('searching', category: 'search'),
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color ??
                                        kMediumText,
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
                  },
                ),

                // ── Map controls ──
                PositionedDirectional(
                  end: 16,
                  bottom: 120,
                  child: _buildMapControls(theme, cardColor),
                ),

                // ── Error banner ──
                Consumer<SearchViewModel>(
                  builder: (context, viewModel, child) {
                    if (viewModel.error == null || viewModel.error!.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final lp = Provider.of<LanguageProvider>(context);
                    return Positioned(
                      top: 100,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.3),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                lp.tr(viewModel.error!, category: 'common'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Exo2',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white, size: 18),
                              onPressed: () => viewModel.clearError(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // ── Result count badge ──
                if (_markers.isNotEmpty)
                  PositionedDirectional(
                    top: 100,
                    start: 16,
                    child: Consumer<LanguageProvider>(
                      builder: (context, lp, child) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              spreadRadius: 1,
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
                                color: theme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              lp.trParams('providers_found',
                                  category: 'search',
                                  params: {
                                    'count': _markers.length.toString()
                                  }),
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color ??
                                    kDarkText,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Exo2',
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
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

  // ── Loading view ──
  Widget _buildLoadingView(ThemeData theme, Color cardColor) {
    return Consumer<LanguageProvider>(
      builder: (context, lp, child) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
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
                valueColor: AlwaysStoppedAnimation(theme.primaryColor),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isLoadingLocation
                  ? lp.tr('loading_location', category: 'search')
                  : lp.tr('loading_map', category: 'search'),
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color ?? kMediumText,
                fontSize: 15,
                fontFamily: 'Exo2',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Map controls column ──
  Widget _buildMapControls(ThemeData theme, Color cardColor) {
    return Column(
      children: [
        _mapControlButton(
          theme,
          cardColor,
          icon: Icons.my_location_rounded,
          onTap: _centerMapOnUser,
        ),
        const SizedBox(height: 10),
        if (_markers.isNotEmpty) ...[
          _mapControlButton(
            theme,
            cardColor,
            icon: Icons.zoom_out_map_rounded,
            onTap: _centerMapOnMarkers,
          ),
          const SizedBox(height: 10),
        ],
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              IconButton(
                onPressed: () {
                  _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                },
                icon: Icon(Icons.add_rounded, color: theme.primaryColor, size: 22),
                padding: const EdgeInsets.all(10),
              ),
              Divider(height: 1, color: theme.dividerColor),
              IconButton(
                onPressed: () {
                  _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                },
                icon: Icon(Icons.remove_rounded,
                    color: theme.primaryColor, size: 22),
                padding: const EdgeInsets.all(10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mapControlButton(
      ThemeData theme,
      Color cardColor, {
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: theme.primaryColor, size: 22),
        padding: const EdgeInsets.all(10),
      ),
    );
  }

  // ── Search bar ──
  Widget _buildSearchBar(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context);

    return Consumer<LanguageProvider>(
      builder: (context, lp, child) => Container(
        padding: EdgeInsets.fromLTRB(16, statusBarH + 10, 16, 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor, width: 1.5),
                ),
                child: TextField(
                  controller: _textController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 14,
                    fontFamily: 'Exo2',
                  ),
                  decoration: InputDecoration(
                    hintText: lp.tr('filter_hint', category: 'search'),
                    hintStyle: TextStyle(
                      color: kMediumText.withOpacity(0.7),
                      fontSize: 14,
                      fontFamily: 'Exo2',
                    ),
                    prefixIcon: const Icon(CupertinoIcons.search, color: kMediumText, size: 19),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    suffixIcon: (_textController.text.isNotEmpty || _currentFilters.isNotEmpty)
                        ? Container(
                            margin: const EdgeInsets.all(10),
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              gradient: kPrimaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 10),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _searchBarIconButton(
              color: theme.primaryColor,
              icon: Icons.filter_alt_rounded,
              onTap: () {
                HapticFeedback.lightImpact();
                _showFilterDialog();
              },
            ),
            if (_currentFilters.isNotEmpty || (_searchTextQuery != null && _searchTextQuery!.isNotEmpty)) ...[
              const SizedBox(width: 8),
              _searchBarIconButton(
                color: kAccentColor.withOpacity(0.15),
                icon: Icons.close_rounded,
                iconColor: kAccentColor,
                onTap: _clearFilters,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _searchBarIconButton({
    required Color color,
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? Colors.white, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// EXTRACTED WIDGETS
// ─────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final int maxLines;
  final ThemeData theme;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.theme,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
      maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.textTheme.bodySmall?.color ?? kMediumText,
                  fontFamily: 'Exo2',
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Exo2',
                  color: theme.textTheme.bodyLarge?.color ?? kDarkText,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 13),
        side: BorderSide(color: color.withOpacity(0.45), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Exo2',
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilledButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FilledButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 13),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Exo2',
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(size.width / 2 - 10, 0)
      ..quadraticBezierTo(
        size.width / 2 - 5,
        size.height * 0.7,
        size.width / 2,
        size.height,
      )
      ..quadraticBezierTo(
        size.width / 2 + 5,
        size.height * 0.7,
        size.width / 2 + 10,
        0,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Subtle dot-grid pattern painted on the hero header
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 14.0;
    const radius = 1.5;
    final paint = Paint()..color = Colors.white;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
