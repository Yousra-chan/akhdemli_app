import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/profile/profile_constants.dart';
import 'package:service_app/utils/ui_widgets.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  bool _isLoading = false;

  final List<Map<String, String>> _languages = [
    {
      'code': 'en',
      'name': 'English',
      'nativeName': 'English',
      'flag': '🇺🇸',
    },
    {
      'code': 'fr',
      'name': 'French',
      'nativeName': 'Français',
      'flag': '🇫🇷',
    },
    {
      'code': 'ar',
      'name': 'Arabic',
      'nativeName': 'العربية',
      'flag': '🇩🇿',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final currentLocale = languageProvider.locale.languageCode;

        return Scaffold(
          backgroundColor: kLightBackgroundColor,
          body: Column(
            children: [
              // Custom App Bar matching SettingsPage
              _buildCustomAppBar(context, languageProvider),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(kPrimaryBlue),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        children: _languages.map((language) {
                          final isSelected = currentLocale == language['code'];

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
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
                              border: isSelected
                                  ? Border.all(
                                      color: kPrimaryBlue,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? kPrimaryBlue.withOpacity(0.15)
                                      : kPrimaryBlue.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    language['flag']!,
                                    style: const TextStyle(
                                      fontSize: 28,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                language['name']!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? kPrimaryBlue
                                      : kDarkTextColor,
                                  fontSize: 16,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                              subtitle: Text(
                                language['nativeName']!,
                                style: const TextStyle(
                                  color: kMutedTextColor,
                                  fontSize: 14,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                              trailing: isSelected
                                  ? Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: kPrimaryBlue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    )
                                  : null,
                              onTap: isSelected
                                  ? null
                                  : () => _changeLanguage(
                                        context,
                                        language['code']!,
                                        languageProvider,
                                      ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomAppBar(
      BuildContext context, LanguageProvider languageProvider) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 15,
      ),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kLightBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: kDarkTextColor,
                size: 24,
              ),
            ),
          ),
          Text(
            languageProvider.tr('language', category: 'language'),
            style: const TextStyle(
              color: kDarkTextColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2',
            ),
          ),
          Container(
            width: 40, // Placeholder for spacing
          ),
        ],
      ),
    );
  }

  Future<void> _changeLanguage(
    BuildContext context,
    String languageCode,
    LanguageProvider languageProvider,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newLocale = Locale(languageCode);

      // Update provider
      await languageProvider.setLanguage(newLocale);

      // Show success message
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          languageProvider.tr(
            'language_changed_success',
            category: 'language',
          ),
        );
      }

      // Add a small delay for smooth transition
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate back
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          '${languageProvider.tr('error_occurred', category: 'common')}: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
