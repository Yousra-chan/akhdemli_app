import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:flutter/services.dart'; // Add this for Clipboard

class LocationSection extends StatefulWidget {
  final Function(String, double?, double?)? onLocationUpdated;
  final bool showCoordinates;
  final bool autoDetectOnInit;

  const LocationSection({
    super.key,
    this.onLocationUpdated,
    this.showCoordinates = true,
    this.autoDetectOnInit = true,
  });

  @override
  State<LocationSection> createState() => _LocationSectionState();
}

class _LocationSectionState extends State<LocationSection> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  bool _isGettingLocation = false;
  Position? _currentPosition;
  Placemark? _currentPlacemark;

  // Colors
  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _successColor = Color(0xFF059669);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    if (widget.autoDetectOnInit) {
      _getCurrentLocation();
    }
  }

  // Getters
  String get address => _locationController.text;
  double? get latitude => _currentPosition?.latitude;
  double? get longitude => _currentPosition?.longitude;
  bool get hasLocation => _currentPosition != null;
  bool get isLoading => _isGettingLocation;

  Future<bool> getCurrentLocation() => _getCurrentLocation();

  // Location Logic
  Future<bool> _getCurrentLocation() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    if (!await _checkLocationPermission()) {
      _showLocationPermissionDialog();
      return false;
    }

    setState(() => _isGettingLocation = true);

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        await _updateLocationData(position, placemarks.first);
        return true;
      }
    } catch (e) {
      _showErrorSnackBar(lang.tr('location_error', category: 'service'));
    } finally {
      setState(() => _isGettingLocation = false);
    }
    return false;
  }

  void _showLocationPermissionDialog() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.tr('location_permission_title', category: 'service')),
        content:
            Text(lang.tr('location_permission_message', category: 'service')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
                lang.tr('location_permission_cancel', category: 'service')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
            ),
            child: Text(
              lang.tr('location_permission_enable', category: 'service'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    AppSnackBar.showError(context, message);
  }

  Future<void> _updateLocationData(
      Position position, Placemark placemark) async {
    final address = _buildAddress(placemark);

    setState(() {
      _currentPosition = position;
      _latitudeController.text = position.latitude.toStringAsFixed(6);
      _longitudeController.text = position.longitude.toStringAsFixed(6);
      _locationController.text = address;
    });

    widget.onLocationUpdated
        ?.call(address, position.latitude, position.longitude);
  }

  Future<bool> _checkLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      _showErrorSnackBar(
          lang.tr('location_service_disabled', category: 'service'));
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        _showErrorSnackBar(
            lang.tr('location_permission_denied', category: 'service'));
        return false;
      }
    }

    return permission != LocationPermission.deniedForever;
  }

  String _buildAddress(Placemark placemark) {
    final parts = [
      placemark.street,
      placemark.locality,
      placemark.administrativeArea,
    ].where((p) => p?.isNotEmpty ?? false).toList();

    return parts.join(', ');
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));

    final lang = Provider.of<LanguageProvider>(context, listen: false);

    AppSnackBar.showSuccess(context, lang.tr('location_copied', category: 'service'));
  }

  // UI Components
  Widget _buildHeader(ThemeData theme) {
    final lang = Provider.of<LanguageProvider>(context);

    return Row(
      children: [
        Icon(
          Icons.location_on,
          color: theme.primaryColor,
          size: 24,
        ),
        const SizedBox(width: 12),
        Text(
          lang.tr('location_section_title', category: 'service'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationButton(ThemeData theme) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: _isGettingLocation ? null : _getCurrentLocation,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _currentPosition != null
                    ? Colors.green.withOpacity(0.1)
                    : theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: _isGettingLocation
                  ? Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.primaryColor,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        _currentPosition != null
                            ? Icons.check
                            : Icons.my_location,
                        size: 18,
                        color: _currentPosition != null
                            ? Colors.green
                            : theme.primaryColor,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isGettingLocation
                        ? lang.tr('location_getting', category: 'service')
                        : _currentPosition != null
                            ? lang.tr('location_found', category: 'service')
                            : lang.tr('location_detect', category: 'service'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressField(ThemeData theme) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.place,
            color: isDark ? Colors.white38 : Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _locationController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: lang.tr('location_address_hint', category: 'service'),
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
          if (_locationController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.copy, size: 18, color: theme.primaryColor),
              onPressed: () => _copyToClipboard(_locationController.text),
              tooltip: lang.tr('location_copy', category: 'service'),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildCoordinates(ThemeData theme) {
    final lang = Provider.of<LanguageProvider>(context);

    if (!widget.showCoordinates) return const SizedBox.shrink();

    return Row(
      children: [
        _buildCoordinateItem(
          theme,
          lang.tr('location_coordinate_lat', category: 'service'),
          _latitudeController.text,
          lang,
        ),
        const SizedBox(width: 8),
        _buildCoordinateItem(
          theme,
          lang.tr('location_coordinate_lng', category: 'service'),
          _longitudeController.text,
          lang,
        ),
      ],
    );
  }

  Widget _buildCoordinateItem(
      ThemeData theme, String label, String value, LanguageProvider lang) {
    final isDark = theme.brightness == Brightness.dark;
    return Expanded(
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Text(
              '$label: ',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey.shade600,
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty
                    ? lang.tr('location_coordinate_empty', category: 'service')
                    : value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<LanguageProvider>(
      builder: (context, lang, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 16),
            _buildLocationButton(theme),
            const SizedBox(height: 12),
            _buildAddressField(theme),
            if (widget.showCoordinates) ...[
              const SizedBox(height: 12),
              _buildCoordinates(theme),
            ],
          ],
        );
      },
    );
  }
}
