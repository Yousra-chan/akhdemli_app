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

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkModeEnabled = false;
  bool _sendReadReceipts = true;
  bool _offlineMode = false;

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: kLightBackgroundColor,
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
                    languageProvider.tr('accountSettings', category: 'profile'),
                    [
                      _buildSettingsItem(
                        icon: Icons.person_outline,
                        title: languageProvider.tr('editProfile',
                            category: 'profile'),
                        subtitle: languageProvider.tr('updatePersonalInfo',
                            category: 'profile'),
                        onTap: () => _navigateToEditProfile(context),
                      ),
                      _buildSettingsItem(
                        icon: Icons.lock_outline,
                        title: languageProvider.tr('changePassword',
                            category: 'profile'),
                        subtitle: languageProvider.tr('updatePassword',
                            category: 'profile'),
                        onTap: () => _navigateToChangePassword(context),
                      ),
                      _buildSettingsItem(
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
                    languageProvider.tr('general', category: 'common'),
                    [
                      _buildSettingsItem(
                        icon: Icons.language,
                        title: languageProvider.tr('language',
                            category: 'language'),
                        subtitle: _getCurrentLanguageName(languageProvider),
                        onTap: () => _navigateToLanguagePage(context),
                        showChevron: true,
                      ),
                      _buildSettingsItem(
                        icon: Icons.notifications_outlined,
                        title: languageProvider.tr('notifications',
                            category: 'profile'),
                        subtitle: languageProvider.tr('manageNotifications',
                            category: 'profile'),
                        hasSwitch: true,
                        switchValue: _sendReadReceipts,
                        onSwitchChanged: (value) {
                          setState(() {
                            _sendReadReceipts = value;
                          });
                        },
                      ),
                    ],
                  ),

                  // --- 3. Appearance Section ---
                  _buildSettingsSection(
                    languageProvider.tr('appearance', category: 'common'),
                    [
                      _buildSettingsItem(
                        icon: Icons.dark_mode_outlined,
                        title:
                            languageProvider.tr('darkMode', category: 'common'),
                        subtitle: languageProvider.tr('enableDarkTheme',
                            category: 'common'),
                        hasSwitch: true,
                        switchValue: _darkModeEnabled,
                        onSwitchChanged: (value) {
                          setState(() {
                            _darkModeEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),

                  // --- 4. Danger Zone ---
                  _buildSettingsSection(
                    languageProvider.tr('dangerZone', category: 'profile'),
                    [
                      _buildSettingsItem(
                        icon: Icons.logout,
                        title:
                            languageProvider.tr('logout', category: 'profile'),
                        subtitle: languageProvider.tr('signOutAccount',
                            category: 'profile'),
                        onTap: () =>
                            _showLogoutDialog(context, languageProvider),
                        isWarning: true,
                      ),
                      _buildSettingsItem(
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
            languageProvider.tr('accountSettings', category: 'profile'),
            style: const TextStyle(
              color: kDarkTextColor,
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

  Widget _buildSettingsSection(String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 12),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: kMutedTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                fontFamily: 'Exo2',
              ),
            ),
          ),
          Container(
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
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: kMutedTextColor.withOpacity(0.1),
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

  Widget _buildSettingsItem({
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
    final Color titleColor = isDestructive
        ? Colors.red
        : isWarning
            ? Colors.orange
            : kDarkTextColor;

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
                          : kPrimaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: titleColor,
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
                      style: const TextStyle(
                        color: kMutedTextColor,
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
                    activeColor: kPrimaryBlue,
                  ),
                )
              else if (showChevron)
                Icon(
                  Icons.chevron_right,
                  color: kMutedTextColor,
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

  void _showLogoutDialog(
      BuildContext context, LanguageProvider languageProvider) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: kCardBackgroundColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout,
                  color: Colors.orange,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                languageProvider.tr('logout', category: 'profile'),
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Exo2',
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                languageProvider.tr('logoutConfirm', category: 'profile'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kMutedTextColor,
                  fontSize: 14,
                  height: 1.4,
                  fontFamily: 'Exo2',
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kMutedTextColor,
                        side:
                            BorderSide(color: kMutedTextColor.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        languageProvider.tr('cancel', category: 'common'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Logout Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();

                        // Logout
                        final authViewModel = Provider.of<AuthViewModel>(
                          context,
                          listen: false,
                        );
                        await authViewModel.logout();

                        if (mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/login',
                            (route) => false,
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                languageProvider.tr('loggedOut',
                                    category: 'profile'),
                                style: const TextStyle(
                                  fontFamily: 'Exo2',
                                ),
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        languageProvider.tr('logout', category: 'profile'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
