import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/ViewModel/unread_message_view_model.dart';
import 'package:service_app/ViewModel/search_view_model.dart';
import 'package:service_app/ViewModel/service_view_model.dart'; // Add this import
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/screens/auth/login/login_screen.dart';
import 'package:service_app/screens/navigator_bottom.dart';
import 'package:service_app/screens/onboarding/onboarding_screen.dart';
import 'package:service_app/Services/notification_service.dart';

/// Global navigator key (used by NotificationService)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('🚀 App starting...');

    /// 1️⃣ Firebase init
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');

    /// 2️⃣ Notification service init (FCM + Local + Firestore)
    await NotificationService.initialize();
    debugPrint('✅ NotificationService initialized');

    runApp(const ServiceApp());
  } catch (e, s) {
    debugPrint('❌ Fatal init error: $e');
    debugPrintStack(stackTrace: s);
    runApp(const ServiceApp());
  }
}

/// ============================================================================
/// APP ROOT
/// ============================================================================

class ServiceApp extends StatelessWidget {
  const ServiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(
            create: (_) => ServiceViewModel()), // Added ServiceViewModel
        ChangeNotifierProvider(create: (_) => UnreadMessagesViewModel()),
        ChangeNotifierProvider(create: (_) => SearchViewModel()),
      ],
      child: MaterialApp(
        title: 'Akhdem-Li',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        routes: {
          '/home': (_) => const NavigatorBottom(),
          '/login': (_) => const LoginScreen(),
          '/onboarding': (_) => const OnboardingScreen(),
        },
        home: const AuthWrapper(),
      ),
    );
  }
}

/// ============================================================================
/// AUTH WRAPPER
/// ============================================================================

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _loading = true;
  bool _hasSeenOnboarding = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _checkOnboarding();

    /// Handle terminated → opened by notification
    await NotificationService.handleInitialMessage();

    /// Listen to foreground notifications
    NotificationService.notificationStream.listen((data) {
      final type = data['type'];
      final chatId = data['chatId'];
      final senderId = data['senderId'];

      // Do not show notification if sender is current user
      final authVM = context.read<AuthViewModel>();
      if (authVM.currentUser?.uid == senderId) return;

      if (type == 'message' && chatId != null) {
        debugPrint('📩 New message in chat $chatId');
        // Optionally show snackbar or any UI update
      }
    });

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    _hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();

    if (_loading) return _loadingScreen('Loading app...');

    if (!_hasSeenOnboarding) return const OnboardingScreen();

    if (authVM.isLoading && authVM.currentUser == null)
      return _loadingScreen('Checking session...');

    if (authVM.currentUser != null) {
      return _authenticatedApp(authVM.currentUser!);
    }

    return const LoginScreen();
  }

  Widget _authenticatedApp(UserModel user) {
    _saveUserFCMToken(user.uid);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ChatViewModel(userId: user.uid),
          lazy: false,
        ),
      ],
      child: const NavigatorBottom(),
    );
  }

  Future<void> _saveUserFCMToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('🔑 Saving FCM token for user $userId');
        debugPrint('  Token: ${token.substring(0, 30)}...');

        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint('✅ FCM token saved successfully');
      } else {
        debugPrint('⚠️ No FCM token available');
      }
    } catch (e) {
      debugPrint('❌ Token save error: $e');
    }
  }

  Widget _loadingScreen(String text) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              text,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
