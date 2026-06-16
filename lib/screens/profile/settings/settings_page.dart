import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/profile/profile_constants.dart';
import 'package:service_app/screens/profile/settings/change_language_page.dart';
import 'package:service_app/screens/profile/settings/change_password_page.dart';
import 'package:service_app/screens/profile/settings/edit_profile_page.dart';
import 'package:service_app/screens/profile/settings/update_email_page.dart';
import 'package:service_app/screens/profile/settings/delete_account.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';

import 'package:service_app/providers/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  bool _sendReadReceipts = true;
  bool _offlineMode = false;

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Simple App Bar
          _buildAppBar(context, languageProvider),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. Account Settings Section ---
                  _buildSettingsSection(
                    context,
                    languageProvider.tr('accountSettings', category: 'profile'),
                    [
                      _buildSettingsItem(
                        context,
                        icon: Icons.person_outline,
                        title: languageProvider.tr('editProfile',
                            category: 'profile'),
                        subtitle: languageProvider.tr('updatePersonalInfo',
                            category: 'profile'),
                        onTap: () => _navigateToEditProfile(context),
                      ),
                      _buildSettingsItem(
                        context,
                        icon: Icons.lock_outline,
                        title: languageProvider.tr('changePassword',
                            category: 'profile'),
                        subtitle: languageProvider.tr('updatePassword',
                            category: 'profile'),
                        onTap: () => _navigateToChangePassword(context),
                      ),
                      _buildSettingsItem(
                        context,
                        icon: Icons.email_outlined,
                        title: languageProvider.tr('updateEmail',
                            category: 'profile'),
                        subtitle: languageProvider.tr('changeEmail',
                            category: 'profile'),
                        onTap: () => _navigateToUpdateEmail(context),
                      ),
                    ],
                  ),

                  // --- 2. General Settings Section ---
                  _buildSettingsSection(
                    context,
                    languageProvider.tr('general', category: 'common'),
                    [
                      _buildSettingsItem(
                        context,
                        icon: Icons.language,
                        title: languageProvider.tr('language',
                            category: 'language'),
                        subtitle: _getCurrentLanguageName(languageProvider),
                        onTap: () => _navigateToLanguagePage(context),
                        showChevron: true,
                      ),

                    ],
                  ),

                  // --- 3. Appearance Section ---
                  _buildSettingsSection(
                    context,
                    languageProvider.tr('appearance', category: 'common'),
                    [
                      _buildSettingsItem(
                        context,
                        icon: Icons.dark_mode_outlined,
                        title: languageProvider.tr('darkMode', category: 'common'),
                        subtitle: languageProvider.tr('enableDarkTheme',
                            category: 'common'),
                        hasSwitch: true,
                        switchValue: context.watch<ThemeProvider>().isDarkMode,
                        onSwitchChanged: (value) {
                          context.read<ThemeProvider>().toggleTheme();
                        },
                      ),
                    ],
                  ),

                  // --- 4. Danger Zone ---
                  _buildSettingsSection(
                    context,
                    languageProvider.tr('dangerZone', category: 'profile'),
                    [

                      _buildSettingsItem(
                        context,
                        icon: Icons.delete_outline,
                        title: languageProvider.tr('deleteAccount',
                            category: 'profile'),
                        subtitle: languageProvider.tr('permanentlyDelete',
                            category: 'profile'),
                        onTap: () => _navigateToDeleteAccount(context),
                        isDestructive: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, LanguageProvider languageProvider) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 15,
      ),
      color: theme.appBarTheme.backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back,
                color: theme.appBarTheme.foregroundColor,
                size: 24,
              ),
            ),
          ),
          Text(
            languageProvider.tr('accountSettings', category: 'profile'),
            style: TextStyle(
              color: theme.appBarTheme.foregroundColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2',
            ),
          ),
          Container(
            width: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, String title, List<Widget> items) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 10, bottom: 12),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: isDark ? Colors.white54 : kMutedTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                fontFamily: 'Exo2',
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: theme.dividerColor,
                      indent: 16,
                      endIndent: 16,
                    ),
                  items[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool hasSwitch = false,
    bool switchValue = false,
    Function(bool)? onSwitchChanged,
    bool showChevron = false,
    bool isWarning = false,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color titleColor = isDestructive
        ? Colors.red
        : isWarning
            ? Colors.orange
            : theme.textTheme.bodyLarge?.color ?? Colors.black;

    return Container(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasSwitch ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? Colors.red.withOpacity(0.1)
                      : isWarning
                          ? Colors.orange.withOpacity(0.1)
                          : theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? Colors.red : (isWarning ? Colors.orange : theme.primaryColor),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Exo2',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white38 : kMutedTextColor,
                        fontSize: 13,
                        fontFamily: 'Exo2',
                      ),
                    ),
                  ],
                ),
              ),
              if (hasSwitch)
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: switchValue,
                    onChanged: onSwitchChanged,
                    activeColor: theme.primaryColor,
                  ),
                )
              else if (showChevron)
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white24 : kMutedTextColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCurrentLanguageName(LanguageProvider languageProvider) {
    final code = languageProvider.locale.languageCode;
    switch (code) {
      case 'en':
        return languageProvider.tr('english', category: 'language');
      case 'fr':
        return languageProvider.tr('french', category: 'language');
      case 'ar':
        return languageProvider.tr('arabic', category: 'language');
      default:
        return languageProvider.tr('english', category: 'language');
    }
  }

  void _navigateToEditProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    );
  }

  void _navigateToChangePassword(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChangePasswordPage()),
    );
  }

  void _navigateToUpdateEmail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UpdateEmailPage()),
    );
  }

  void _navigateToLanguagePage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LanguagePage()),
    );
  }

  void _navigateToDeleteAccount(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeleteAccountPage()),
    );
  }


  }

