import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/auth_wrapper.dart';
import 'package:service_app/screens/auth/login/login_screen.dart';
import 'package:service_app/screens/navigator_bottom.dart';
import 'package:service_app/screens/auth/constants.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:service_app/Services/wilaya_service.dart';
import 'package:dzair_data_usage/langs.dart';
import 'package:service_app/screens/profile/terms_conditions_page.dart';
import 'package:service_app/screens/auth/register/registration_widget.dart'
    hide
        kAppFont,
        kDarkTextColor,
        kMutedTextColor,
        kInputFillColor,
        kLightBackgroundColor,
        kHorizontalPadding,
        kPrimaryBlue;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();

  // Form fields state
  String _name = '';
  String _email = '';
  String _password = '';
  String _role = 'client';
  String _phone = '';
  bool _termsAccepted = false;
  
  String? _selectedWilaya;
  String? _selectedCommune;
  Map<String, String> _wilayasMap = {};
  Map<String, String> _communesMap = {};

  // Geolocation state variables
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
    });
  }

  Language _getDzairLanguage(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'ar':
        return Language.AR;
      case 'fr':
        return Language.FR;
      case 'en':
        return Language.FR;
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

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    try {
      final user = await authViewModel.signInWithGoogle();
      if (!mounted) return;

      if (user != null) {
        AppSnackBar.showSuccess(
            context, lang.tr('google_sign_in_success', category: 'auth'));
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
          (route) => false,
        );
      } else {
        AppSnackBar.showError(
            context,
            authViewModel.error ??
                lang.tr('google_sign_in_failed', category: 'auth'));
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
          context, lang.tr('google_sign_in_failed', category: 'auth'));
    }
  }

  Future<void> _signInWithApple() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    try {
      final user = await authViewModel.signInWithApple();
      if (!mounted) return;

      if (user != null) {
        AppSnackBar.showSuccess(
            context, lang.tr('apple_sign_in_success', category: 'auth'));
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
          (route) => false,
        );
      } else {
        AppSnackBar.showError(
            context,
            authViewModel.error ??
                lang.tr('apple_sign_in_failed', category: 'auth'));
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
          context, lang.tr('apple_sign_in_failed', category: 'auth'));
    }
  }

  /// Determine the current position of the device.
  Future<void> _determinePosition() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    setState(() {
      _locationMessage = lang.tr('gps_requesting', category: 'auth');
    });

    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
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

    // Check current permission status.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission if denied once.
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

    // Permissions are granted, now fetch the position.
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Update state upon success
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _latitude = position.latitude;
          _longitude = position.longitude;
          _locationMessage = lang.tr('gps_success', category: 'auth');
        });
      }
    } catch (e) {
      // Update state upon error
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

  void _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    try {
      debugPrint('📱 Starting registration process...');

      final user = await authViewModel.signup(
        name: _name,
        email: _email,
        password: _password,
        role: _role,
        phone: _phone,
        wilaya: _selectedWilaya,
        commune: _selectedCommune,
        lat: _latitude,
        lon: _longitude,
      );

      if (!mounted) return;

      if (user != null) {
        AppSnackBar.showSuccess(
            context,
            lang.trParams('register_success',
                category: 'auth', params: {'name': user.name ?? ''}));

        // Reset to AuthWrapper with a smooth transition
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
          (route) => false,
        );
      } else {
        AppSnackBar.showError(context,
            authViewModel.error ?? lang.tr('register_error', category: 'auth'));
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
          context,
          authViewModel.error ??
              lang.tr('register_unexpected_error', category: 'auth'));
    }
  }

  Widget _buildTopBar(BuildContext context, LanguageProvider lang) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: Icon(
          CupertinoIcons.arrow_left,
          color: theme.textTheme.bodySmall?.color ?? kMutedTextColor,
          size: 24,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildTermsCheckbox(LanguageProvider lang) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _termsAccepted,
            activeColor: theme.primaryColor,
            onChanged: (val) => setState(() => _termsAccepted = val ?? false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsConditionsPage()),
              );
            },
            child: Text.rich(
              TextSpan(
                text: lang.tr('accept_terms', category: 'terms'),
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: kAppFont,
                  color: theme.textTheme.bodyMedium?.color ?? kDarkTextColor,
                ),
                children: const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeolocationSection(LanguageProvider lang) {
    final theme = Theme.of(context);
    Color statusColor = theme.brightness == Brightness.dark ? Colors.grey[400]! : Colors.grey;
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
        _locationMessage
            .contains(lang.tr('gps_requesting', category: 'auth'))) {
      statusColor = theme.primaryColor;
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
              backgroundColor: theme.primaryColor,
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

  Widget _buildRoleSelection(LanguageProvider lang) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.tr('role_title', category: 'auth'),
          style: TextStyle(
            fontFamily: kAppFont,
            color: theme.textTheme.titleMedium?.color ?? kDarkTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RoleOption(
                title: lang.tr('role_client', category: 'auth'),
                subtitle: lang.tr('role_client_desc', category: 'auth'),
                icon: Icons.person_outline,
                isSelected: _role == 'client',
                onTap: () {
                  setState(() {
                    _role = 'client';
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RoleOption(
                title: lang.tr('role_provider', category: 'auth'),
                subtitle: lang.tr('role_provider_desc', category: 'auth'),
                icon: Icons.business_center_outlined,
                isSelected: _role == 'provider',
                onTap: () {
                  setState(() {
                    _role = 'provider';
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _buildAestheticInputDecoration(
      String hint, LanguageProvider lang) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: theme.textTheme.bodySmall?.color ?? kMutedTextColor, 
        fontFamily: kAppFont
      ),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : kInputFillColor.withOpacity(0.5),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primaryColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the real AuthViewModel to access isLoading state
    final authViewModel = Provider.of<AuthViewModel>(context);
    final theme = Theme.of(context);

    return Consumer<LanguageProvider>(
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kHorizontalPadding,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Top Bar (Back Button)
                    _buildTopBar(context, lang),

                    // 2. Logo Placement (Centered and separate)
                    const SizedBox(height: 100),
                    Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 150,
                        height: 150,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 3. Main Content Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            spreadRadius: 5,
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            lang.tr('register_title', category: 'auth'),
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: theme.textTheme.titleLarge?.color ?? kDarkTextColor,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              fontFamily: kAppFont,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lang.tr('register_subtitle', category: 'auth'),
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color ?? kMutedTextColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              fontFamily: kAppFont,
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Registration Form
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Name Field
                                TextFormField(
                                  decoration: _buildAestheticInputDecoration(
                                    lang.tr('full_name_hint', category: 'auth'),
                                    lang,
                                  ),
                                  keyboardType: TextInputType.name,
                                  textCapitalization: TextCapitalization.words,
                                  style: TextStyle(
                                    fontFamily: kAppFont,
                                    color: theme.textTheme.bodyLarge?.color ?? kDarkTextColor,
                                  ),
                                  validator: (value) => value!.isEmpty
                                      ? lang.tr('validation_name_required',
                                          category: 'auth')
                                      : null,
                                  onSaved: (value) => _name = value!,
                                ),
                                const SizedBox(height: 16),

                                // Email Field
                                TextFormField(
                                  decoration: _buildAestheticInputDecoration(
                                    lang.tr('email_hint_login',
                                        category: 'auth'),
                                    lang,
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  style: TextStyle(
                                    fontFamily: kAppFont,
                                    color: theme.textTheme.bodyLarge?.color ?? kDarkTextColor,
                                  ),
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return lang.tr(
                                          'validation_email_required',
                                          category: 'auth');
                                    }
                                    if (!value.contains('@') ||
                                        !value.contains('.')) {
                                      return lang.tr('validation_email_invalid',
                                          category: 'auth');
                                    }
                                    return null;
                                  },
                                  onSaved: (value) => _email = value!,
                                ),
                                const SizedBox(height: 16),

                                // Phone Field
                                TextFormField(
                                  decoration: _buildAestheticInputDecoration(
                                    lang.tr('phone_number_hint',
                                        category: 'auth'),
                                    lang,
                                  ),
                                  keyboardType: TextInputType.phone,
                                  style: TextStyle(
                                    fontFamily: kAppFont,
                                    color: theme.textTheme.bodyLarge?.color ?? kDarkTextColor,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return lang.tr('validation_phone_required',
                                          category: 'auth');
                                    }
                                    // Algeria Phone Pattern: 05/06/07 followed by 8 digits
                                    // Support for +213 or 00213 prefix too
                                    final phoneRegex = RegExp(r'^(\+213|00213|0)[567][0-9]{8}$');
                                    if (!phoneRegex.hasMatch(value.replaceAll(' ', ''))) {
                                      return lang.tr('validation_phone_invalid',
                                          category: 'auth');
                                    }
                                    return null;
                                  },
                                  onSaved: (value) => _phone = value!,
                                ),
                                const SizedBox(height: 16),

                                // Wilaya Dropdown
                                DropdownButtonFormField<String>(
                                  value: _selectedWilaya,
                                  decoration: _buildAestheticInputDecoration(
                                    lang.tr('wilaya_label', category: 'auth'),
                                    lang,
                                  ),
                                  items: _wilayasMap.entries.map((entry) {
                                    return DropdownMenuItem<String>(
                                      value: entry.key,
                                      child: Text(entry.value, style: const TextStyle(fontFamily: kAppFont)),
                                    );
                                  }).toList(),
                                  onChanged: _onWilayaChanged,
                                  validator: (value) => value == null ? lang.tr('validation_wilaya_required', category: 'auth') : null,
                                  icon: Icon(Icons.arrow_drop_down, color: theme.primaryColor),
                                  dropdownColor: theme.cardColor,
                                ),
                                const SizedBox(height: 16),

                                // Commune Dropdown
                                DropdownButtonFormField<String>(
                                  value: _selectedCommune,
                                  decoration: _buildAestheticInputDecoration(
                                    lang.tr('commune_label', category: 'auth'),
                                    lang,
                                  ),
                                  items: _communesMap.entries.map((entry) {
                                    return DropdownMenuItem<String>(
                                      value: entry.key,
                                      child: Text(entry.value, style: const TextStyle(fontFamily: kAppFont)),
                                    );
                                  }).toList(),
                                  onChanged: (value) => setState(() => _selectedCommune = value),
                                  validator: (value) => value == null ? lang.tr('validation_commune_required', category: 'auth') : null,
                                  icon: Icon(Icons.arrow_drop_down, color: theme.primaryColor),
                                  dropdownColor: theme.cardColor,
                                ),
                                const SizedBox(height: 16),

                                // GPS Location Section
                                _buildGeolocationSection(lang),
                                const SizedBox(height: 16),

                                // Role Selection
                                _buildRoleSelection(lang),
                                const SizedBox(height: 16),

                                // Password Field
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: _buildAestheticInputDecoration(
                                    lang.tr('password_hint', category: 'auth'),
                                    lang,
                                  ),
                                  obscureText: true,
                                  style: TextStyle(
                                    fontFamily: kAppFont,
                                    color: theme.textTheme.bodyLarge?.color ?? kDarkTextColor,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return lang.tr(
                                          'validation_password_required',
                                          category: 'auth');
                                    }
                                    if (value.length < 8) {
                                      return lang.tr(
                                          'validation_password_min_length',
                                          category: 'auth');
                                    }
                                    // Strong password: at least one letter and one number
                                    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$').hasMatch(value)) {
                                      return lang.tr(
                                          'validation_password_weak',
                                          category: 'auth');
                                    }
                                    return null;
                                  },
                                  onSaved: (value) => _password = value!,
                                ),
                                const SizedBox(height: 16),

                                // Confirm Password Field
                                TextFormField(
                                  decoration: _buildAestheticInputDecoration(
                                    lang.tr('confirm_password_hint',
                                        category: 'auth'),
                                    lang,
                                  ),
                                  obscureText: true,
                                  style: TextStyle(
                                    fontFamily: kAppFont,
                                    color: theme.textTheme.bodyLarge?.color ?? kDarkTextColor,
                                  ),
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return lang.tr(
                                          'validation_password_confirm_required',
                                          category: 'auth');
                                    }
                                    if (value != _passwordController.text) {
                                      return lang.tr(
                                          'validation_password_mismatch',
                                          category: 'auth');
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 16),
                                _buildTermsCheckbox(lang),

                                const SizedBox(height: 24),

                                // Register Button
                                RegisterButton(
                                  isLoading: authViewModel.isLoading,
                                  onPressed: _termsAccepted ? () => _submitRegistration() : null,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),
                          const OrDivider(),

                          const SizedBox(height: 20),
                          SocialSignInRow(
                            onGooglePressed: _termsAccepted ? () => _signInWithGoogle() : null,
                            onApplePressed: _termsAccepted ? () => _signInWithApple() : null,
                            isLoading: authViewModel.isLoading,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Sign In Link
                    SignInLink(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(-1, 0),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOutCubic,
                                )),
                                child: child,
                              );
                            },
                            transitionDuration: const Duration(milliseconds: 500),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
