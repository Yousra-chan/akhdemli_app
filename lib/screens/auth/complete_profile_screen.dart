import 'package:dzair_data_usage/langs.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/Services/wilaya_service.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/auth/constants.dart';
import 'package:service_app/utils/ui_widgets.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  
  String? _selectedWilaya;
  String? _selectedCommune;
  Map<String, String> _wilayasMap = {};
  Map<String, String> _communesMap = {};

  // Geolocation state
  Position? _currentPosition;
  String _locationMessage = '';
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWilayas();
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      setState(() {
        _locationMessage = lang.tr('gps_button', category: 'auth');
      });
      
      final user = Provider.of<AuthViewModel>(context, listen: false).currentUser;
      if (user != null && user.phone.isNotEmpty) {
        _phoneController.text = user.phone;
      }
    });
  }

  Language _getDzairLanguage(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'ar':
        return Language.AR;
      case 'fr':
        return Language.FR;
      case 'en':
        return Language.FR; // Fallback to French for English users as EN might not be supported in data source
      default:
        return Language.FR;
    }
  }

  void _loadWilayas() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    setState(() {
      _wilayasMap = WilayaService.getWilayasLocalizedMap(
        languageProvider.locale.languageCode,
      );
    });
  }

  void _onWilayaChanged(String? newValue) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    setState(() {
      _selectedWilaya = newValue;
      _selectedCommune = null;
      if (newValue != null) {
        _communesMap = WilayaService.getCommunesLocalizedMap(
          newValue,
          languageProvider.locale.languageCode,
        );
      } else {
        _communesMap = {};
      }
    });
  }

  Future<void> _determinePosition() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    setState(() {
      _locationMessage = lang.tr('gps_requesting', category: 'auth');
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _currentPosition = null;
          _locationMessage = lang.tr('gps_disabled', category: 'auth');
        });
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _currentPosition = null;
            _locationMessage = lang.tr('gps_denied', category: 'auth');
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _currentPosition = null;
          _locationMessage = lang.tr('gps_denied_forever', category: 'auth');
        });
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _latitude = position.latitude;
          _longitude = position.longitude;
          _locationMessage = lang.tr('gps_success', category: 'auth');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentPosition = null;
          _latitude = null;
          _longitude = null;
          _locationMessage = lang.trParams('gps_error',
              category: 'auth',
              params: {'error': e.toString().split('\n').first});
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    
    if (_selectedWilaya == null || _selectedCommune == null) {
      AppSnackBar.showError(context, lang.tr('select_wilaya_commune', category: 'auth'));
      return;
    }

    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    try {
      await authVM.completeProfile(
        wilaya: _selectedWilaya!,
        commune: _selectedCommune!,
        phone: _phoneController.text.trim(),
        lat: _latitude,
        lon: _longitude,
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, e.toString());
      }
    }
  }

  Widget _buildGeolocationSection(LanguageProvider lang) {
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.location_off;

    if (_currentPosition != null) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (_locationMessage.contains('Error') ||
        _locationMessage.contains('denied') ||
        _locationMessage.contains('disabled')) {
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
    } else if (_locationMessage.contains('Requesting') ||
        _locationMessage.contains(lang.tr('gps_requesting', category: 'auth'))) {
      statusColor = kPrimaryBlue;
      statusIcon = Icons.info_outline;
    }

    String displayCoordinates = _currentPosition != null
        ? lang.trParams('gps_coordinates', category: 'auth', params: {
            'lat': _currentPosition!.latitude.toStringAsFixed(6),
            'lon': _currentPosition!.longitude.toStringAsFixed(6),
          })
        : _locationMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _determinePosition,
            icon: const Icon(Icons.gps_fixed, color: Colors.white, size: 20),
            label: Text(
              lang.tr('gps_button', category: 'auth'),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayCoordinates,
                style: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 14,
                  color: statusColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final authVM = Provider.of<AuthViewModel>(context);

    return Scaffold(
      backgroundColor: kLightBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: kHorizontalPadding, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 120,
                    height: 120,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  lang.tr('complete_profile_title', category: 'auth'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: kDarkTextColor,
                    fontFamily: kAppFont,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  lang.tr('complete_profile_subtitle', category: 'auth'),
                  style: const TextStyle(
                    fontSize: 16,
                    color: kMutedTextColor,
                    fontFamily: kAppFont,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // Wilaya Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedWilaya,
                  decoration: buildInputDecoration(lang.tr('wilaya_label', category: 'auth')),
                  items: _wilayasMap.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value, style: const TextStyle(fontFamily: kAppFont)),
                    );
                  }).toList(),
                  onChanged: _onWilayaChanged,
                  validator: (value) => value == null ? lang.tr('validation_wilaya_required', category: 'auth') : null,
                  icon: const Icon(Icons.arrow_drop_down, color: kPrimaryBlue),
                  dropdownColor: Colors.white,
                ),
                const SizedBox(height: 20),

                // Commune Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCommune,
                  decoration: buildInputDecoration(lang.tr('commune_label', category: 'auth')),
                  items: _communesMap.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value, style: const TextStyle(fontFamily: kAppFont)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedCommune = value),
                  validator: (value) => value == null ? lang.tr('validation_commune_required', category: 'auth') : null,
                  icon: const Icon(Icons.arrow_drop_down, color: kPrimaryBlue),
                  dropdownColor: Colors.white,
                ),
                const SizedBox(height: 20),

                // Phone Field
                TextFormField(
                  controller: _phoneController,
                  decoration: buildInputDecoration(lang.tr('phone_number_hint', category: 'auth')),
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontFamily: kAppFont),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return lang.tr('validation_phone_required', category: 'auth');
                    }
                    final phoneRegex = RegExp(r'^(\+213|00213|0)[567][0-9]{8}$');
                    if (!phoneRegex.hasMatch(value.replaceAll(' ', ''))) {
                      return lang.tr('validation_phone_invalid', category: 'auth');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // GPS Location Section
                _buildGeolocationSection(lang),
                const SizedBox(height: 50),

                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: authVM.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: authVM.isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            lang.tr('save_and_continue', category: 'auth'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
                TextButton(
                  onPressed: () => authVM.logout(),
                  child: Text(
                    lang.tr('logout', category: 'auth'),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                      fontFamily: kAppFont,
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
}
