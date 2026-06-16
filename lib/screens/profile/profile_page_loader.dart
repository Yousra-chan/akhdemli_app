import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/screens/profile/profile_page.dart';
import '../../models/UserModel.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';

class ProfilePageLoader extends StatelessWidget {
  const ProfilePageLoader({super.key});

  @override
  Widget build(BuildContext context) {
    // Use AuthViewModel as the single source of truth
    final authViewModel = Provider.of<AuthViewModel>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final UserModel? userModel = authViewModel.currentUser;

    // 1. Initial Loading State (from ViewModel)
    if (authViewModel.isLoading) {
      return Scaffold(
        body: LoadingWidget(
          message: languageProvider.tr('loadingProfile', category: 'profile'),
        ),
      );
    }

    // 2. Not Authenticated or Missing Data
    if (userModel == null) {
      return _buildErrorOrUnauthenticatedState(
          authViewModel, languageProvider, context);
    }

    // 3. Success State: User is loaded by ViewModel
    return ProfilePage(user: userModel);
  }

  Widget _buildErrorOrUnauthenticatedState(AuthViewModel authViewModel,
      LanguageProvider languageProvider, BuildContext context) {
    // Show error if it exists
    if (authViewModel.error != null) {
      return Scaffold(
        body: ErrorStateWidget(
          message: authViewModel.error!,
          onRetry: () => authViewModel.clearError(),
        ),
      );
    }

    // Otherwise, indicate authentication is required
    return Scaffold(
      body: EmptyStateWidget(
        icon: Icons.person_outline,
        message:
            languageProvider.tr('authenticationRequired', category: 'profile'),
        subtitle: languageProvider.tr('pleaseSignIn', category: 'profile'),
        action: ElevatedButton(
          onPressed: () {
            // Navigate to login screen
            Navigator.pushNamed(context, '/login');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF143EAE),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(languageProvider.tr('signIn', category: 'profile')),
        ),
      ),
    );
  }
}
