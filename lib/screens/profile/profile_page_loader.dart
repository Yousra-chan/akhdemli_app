import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/screens/profile/profile_page.dart';
import '../../models/UserModel.dart';
import 'package:service_app/screens/profile/profile_constants.dart';

class ProfilePageLoader extends StatelessWidget {
  const ProfilePageLoader({super.key});

  @override
  Widget build(BuildContext context) {
    // Use AuthViewModel as the single source of truth
    final authViewModel = Provider.of<AuthViewModel>(context);
    final UserModel? userModel = authViewModel.currentUser;

    // 1. Initial Loading State (from ViewModel)
    if (authViewModel.isLoading) {
      return _buildLoadingState();
    }

    // 2. Not Authenticated or Missing Data
    if (userModel == null) {
      return _buildErrorOrUnauthenticatedState(authViewModel, context);
    }

    // 3. Success State: User is loaded by ViewModel
    return ProfilePage(user: userModel);
  }

  Widget _buildLoadingState() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: kPrimaryBlue),
            SizedBox(height: 16),
            Text(
              'Loading your profile...',
              style: TextStyle(
                color: kDarkTextColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOrUnauthenticatedState(
      AuthViewModel authViewModel, BuildContext context) {
    // Show error if it exists
    if (authViewModel.error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Profile Loading Error',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kDarkTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  authViewModel.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: kMutedTextColor,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  authViewModel.clearError();
                  // Optionally trigger a refresh
                  // You could add a refresh method to your AuthViewModel
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    // Otherwise, indicate authentication is required
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 64,
              color: kMutedTextColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Authentication Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kDarkTextColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please sign in to view your profile',
              style: TextStyle(
                color: kMutedTextColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Navigate to login screen
                Navigator.pushNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
