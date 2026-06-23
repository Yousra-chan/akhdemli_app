import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/screens/auth/login/login_screen.dart';
import 'package:service_app/screens/auth/email_verification_screen.dart';
import 'package:service_app/screens/auth/complete_profile_screen.dart';
import 'package:service_app/screens/auth/account_activation_required_page.dart';
import 'package:service_app/screens/navigator_bottom.dart';
import 'package:service_app/screens/onboarding/onboarding_screen.dart';
import 'package:service_app/screens/auth/language_selection_screen.dart';
import 'package:service_app/Services/notification_service.dart';
import 'package:service_app/providers/language_provider.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _loading = true;
  bool _hasSeenOnboarding = false;
  bool _hasCompletedInitialSetup = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if user has seen onboarding
      _hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

      // Check if user has completed initial setup (language selection)
      _hasCompletedInitialSetup =
          prefs.getBool('hasCompletedInitialSetup') ?? false;

      debugPrint('✅ App initialization complete');
      debugPrint('📱 Has seen onboarding: $_hasSeenOnboarding');
      debugPrint('⚙️ Has completed initial setup: $_hasCompletedInitialSetup');
    } catch (e) {
      debugPrint('⚠️ Error during app initialization: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();

    if (_loading) {
      return _loadingScreen(context);
    }

    // 1. FIRST: Show Language Selection ONLY ONCE in entire app lifetime
    if (!_hasCompletedInitialSetup && authVM.currentUser == null) {
      return const LanguageSelectionScreen();
    }

    // 2. SECOND: Show Onboarding if not seen
    if (!_hasSeenOnboarding) {
      return const OnboardingScreen();
    }

    // 3. THIRD: Handle authentication
    if (authVM.isLoading && authVM.currentUser == null) {
      return _loadingScreen(context);
    }

    if (authVM.currentUser != null) {
      final user = authVM.currentUser!;
      
      // 3.1 Check Email Verification (Exclude Guests)
      if (!user.isGuest && !authVM.isEmailVerified) {
        return const EmailVerificationScreen();
      }

      // 3.1.5 Check Profile Completion (Exclude Guests)
      if (!user.isGuest && !user.profileCompleted) {
        return CompleteProfileScreen();
      }

      // 3.2 Check Subscription Activation (Exclude Admins and Guests)
      if (!user.isAdmin && !user.isGuest && !user.subscriptionActive) {
        return const AccountActivationRequiredPage();
      }
      
      return _authenticatedApp(user);
    }

    // 4. FINALLY: Show Login screen
    return const LoginScreen();
  }

  Widget _authenticatedApp(UserModel user) {
    // Initialize user notifications after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserNotifications(user);
    });

    return const NavigatorBottom();
  }

  Future<void> _initializeUserNotifications(UserModel user) async {
    try {
      print('🔔 Initializing notifications for ${user.name}');
      await NotificationService().registerUser(
        userId: user.uid,
        userName: user.name,
      );
      print('✅ User notifications initialized');
    } catch (e) {
      print('⚠️ Error initializing notifications: $e');
    }
  }

  Widget _loadingScreen(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
            ),
            const SizedBox(height: 20),
            Text(
              languageProvider.tr('loading', category: 'common'),
              style: TextStyle(
                fontSize: 16,
                color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
