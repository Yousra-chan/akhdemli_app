import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/screens/profile/profile_constants.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  String _selectedLanguage = 'en';
  bool _isLoading = false;

  final Map<String, Map<String, String>> _languages = {
    'en': {
      'name': 'English',
      'nativeName': 'English',
      'code': 'en',
    },
    'ar': {
      'name': 'Arabic',
      'nativeName': 'العربية',
      'code': 'ar',
    },
    'fr': {
      'name': 'French',
      'nativeName': 'Français',
      'code': 'fr',
    },
    'es': {
      'name': 'Spanish',
      'nativeName': 'Español',
      'code': 'es',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedLanguage = prefs.getString('selected_language') ?? 'en';
      });
    } catch (e) {
      print('Error loading language: $e');
    }
  }

  Future<void> _changeLanguage(String languageCode) async {
    setState(() {
      _selectedLanguage = languageCode;
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language', languageCode);

      // Simulate API call or app restart
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Language changed to ${_languages[languageCode]!['name']}'),
            backgroundColor: kSuccessColor,
          ),
        );

        // In a real app, you might want to restart the app or use a state management solution
        // to update the language across the entire app
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change language: $e'),
            backgroundColor: kDangerColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBackgroundColor,
      appBar: AppBar(
        backgroundColor: kPrimaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kLightTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Language",
          style: TextStyle(
            color: kLightTextColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFamily: 'Exo2',
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kPrimaryBlue),
              ),
            )
          : ListView(
              children: _languages.entries.map((entry) {
                final language = entry.value;
                final isSelected = _selectedLanguage == entry.key;

                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  decoration: BoxDecoration(
                    color: kCardBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: kSoftShadowColor.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: kPrimaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          language['code']!.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kPrimaryBlue,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      language['name']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: kDarkTextColor,
                        fontFamily: 'Exo2',
                      ),
                    ),
                    subtitle: Text(
                      language['nativeName']!,
                      style: TextStyle(
                        color: kMutedTextColor,
                        fontFamily: 'Exo2',
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: kPrimaryBlue,
                          )
                        : null,
                    onTap: () => _changeLanguage(entry.key),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
