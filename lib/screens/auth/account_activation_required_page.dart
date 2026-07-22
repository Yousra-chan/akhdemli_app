import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/profile/subscription_page.dart';
import 'package:service_app/screens/auth/login/login_screen.dart';

// Modern Color Palette (Matching Admin and Search components)
const Color kPrimaryColor = Color(0xFF143EAE);
const Color kSecondaryColor = Color(0xFF2B3674);
const Color kBackgroundColor = Color(0xFFF4F7FE);
const Color kTextSecondary = Color(0xFF707EAE);

class AccountActivationRequiredPage extends StatelessWidget {
  const AccountActivationRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1437) : kBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Illustration Container
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        color: kPrimaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x40143EAE),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_person_rounded,
                        size: 42,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                
                // Title
                Text(
                  languageProvider.tr('account_not_activated', category: 'auth'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Exo2',
                    color: isDark ? Colors.white : kSecondaryColor,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Description Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    languageProvider.tr('activate_sub_instructions', category: 'auth'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'Exo2',
                      color: isDark ? Colors.white70 : kTextSecondary,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 56),

                // Main Action Button (Primary)
                _buildButton(
                  context: context,
                  label: languageProvider.tr('activate_subscription_btn', category: 'auth'),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                    );
                  },
                  isPrimary: true,
                ),
                const SizedBox(height: 16),
                
                // Secondary Action Button (Revert to Client)
                _buildButton(
                  context: context,
                  label: languageProvider.tr('become_client_instead', category: 'auth'),
                  onPressed: () => _handleRevertRole(context, authViewModel, languageProvider),
                  isPrimary: false,
                ),
                
                const SizedBox(height: 40),
                
                // Logout Link (Subtle)
                GestureDetector(
                  onTap: () => _handleLogout(context, authViewModel),
                  child: Text(
                    languageProvider.tr('logout', category: 'common'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Exo2',
                      color: isDark ? Colors.white54 : const Color(0xFFA3AED0),
                      decoration: TextDecoration.underline,
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

  Widget _buildButton({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? kPrimaryColor : Colors.transparent,
          foregroundColor: isPrimary ? Colors.white : kPrimaryColor,
          elevation: isPrimary ? 4 : 0,
          shadowColor: kPrimaryColor.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isPrimary ? BorderSide.none : const BorderSide(color: kPrimaryColor, width: 2),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'Exo2',
          ),
        ),
      ),
    );
  }

  Future<void> _handleRevertRole(BuildContext context, AuthViewModel vm, LanguageProvider lang) async {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final shouldRevert = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1B2559) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          lang.tr('revert_to_client', category: 'auth'), 
          style: TextStyle(
            fontFamily: 'Exo2', 
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : kSecondaryColor,
          )
        ),
        content: Text(
          lang.tr('revert_to_client_desc', category: 'auth'), 
          style: TextStyle(
            fontFamily: 'Exo2',
            color: isDark ? Colors.white70 : kTextSecondary,
          )
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              lang.tr('cancel', category: 'common'), 
              style: const TextStyle(color: Color(0xFFA3AED0), fontWeight: FontWeight.w600)
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              lang.tr('confirm', category: 'common'), 
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800)
            ),
          ),
        ],
      ),
    );

    if (shouldRevert == true) {
      try {
        await vm.updateUserRole('client');
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.redAccent,
            )
          );
        }
      }
    }
  }

  Future<void> _handleLogout(BuildContext context, AuthViewModel vm) async {
    HapticFeedback.selectionClick();
    await vm.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
