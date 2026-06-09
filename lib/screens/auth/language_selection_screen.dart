import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/auth/login/login_screen.dart';
import 'package:service_app/screens/auth/constants.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  final List<Map<String, dynamic>> _languages = [
    {
      'code': 'en',
      'name': 'English',
      'nativeName': 'English',
      'flag': '🇺🇸',
      'locale': const Locale('en'),
    },
    {
      'code': 'fr',
      'name': 'French',
      'nativeName': 'Français',
      'flag': '🇫🇷',
      'locale': const Locale('fr'),
    },
    {
      'code': 'ar',
      'name': 'Arabic',
      'nativeName': 'العربية',
      'flag': '🇸🇦',
      'locale': const Locale('ar'),
    },
  ];

  Future<void> _selectLanguage(Locale locale, String code) async {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    // Set the language - provider automatically sets the completion flag
    await languageProvider.setLanguage(locale);

    print('✅ Language selected: $code');

    // Navigate to login screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/images/logo.png',
                width: 120,
                height: 120,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: kPrimaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.language,
                      size: 60,
                      color: kPrimaryBlue,
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),

              // Title
              const Text(
                'Welcome to Akhdem Li',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryBlue,
                  fontFamily: kAppFont,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Subtitle
              const Text(
                'Choose your preferred language',
                style: TextStyle(
                  fontSize: 16,
                  color: kMutedTextColor,
                  fontFamily: kAppFont,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Language Options
              Expanded(
                child: ListView.separated(
                  itemCount: _languages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final language = _languages[index];
                    return _buildLanguageCard(
                      flag: language['flag'],
                      name: language['name'],
                      nativeName: language['nativeName'],
                      onTap: () => _selectLanguage(
                        language['locale'],
                        language['code'],
                      ),
                    );
                  },
                ),
              ),

              // Skip for now - sets English as default
              TextButton(
                onPressed: () {
                  _selectLanguage(const Locale('en'), 'en');
                },
                child: const Text(
                  'Skip for now',
                  style: TextStyle(
                    color: kMutedTextColor,
                    fontSize: 14,
                    fontFamily: kAppFont,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard({
    required String flag,
    required String name,
    required String nativeName,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Flag
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: kPrimaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    flag,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Language Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kDarkTextColor,
                        fontFamily: kAppFont,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nativeName,
                      style: TextStyle(
                        fontSize: 14,
                        color: kMutedTextColor,
                        fontFamily: kAppFont,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: kMutedTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
