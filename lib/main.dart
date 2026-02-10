import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/ViewModel/unread_message_view_model.dart';
import 'package:service_app/ViewModel/search_view_model.dart';
import 'package:service_app/ViewModel/service_view_model.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/screens/auth/login/login_screen.dart';
import 'package:service_app/screens/navigator_bottom.dart';
import 'package:service_app/screens/onboarding/onboarding_screen.dart';
import 'package:service_app/Services/notification_service.dart';

/// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Background handler (when app is closed)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 [BACKGROUND] Notification received');

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize local notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Create notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
    playSound: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Show notification
  const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    channelDescription: 'Your channel description',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidNotificationDetails);

  await flutterLocalNotificationsPlugin.show(
    0,
    message.notification?.title ?? 'New Message',
    message.notification?.body ?? 'You have a new message',
    notificationDetails,
    payload: json.encode(message.data),
  );

  print('✅ Background notification shown');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('🚀 App starting...');

    /// 1. Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized');

    /// 2. Configure background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print('✅ Background handler configured');

    /// 3. Initialize Notification Service
    await NotificationService.initialize();
    print('✅ NotificationService initialized');

    runApp(const ServiceApp());
  } catch (e, s) {
    print('❌ Fatal init error: $e');
    print('Stack trace: $s');
    // Run app anyway (offline mode)
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
        ChangeNotifierProvider(create: (_) => ServiceViewModel()),
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
/// AUTH WRAPPER (SIMPLIFIED)
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
    try {
      // Check onboarding status
      final prefs = await SharedPreferences.getInstance();
      _hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

      // Handle notification if app opened from notification
      await _handleInitialNotification();

      print('✅ App initialization complete');
    } catch (e) {
      print('⚠️ Error during app initialization: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleInitialNotification() async {
    try {
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        print('🚀 App opened from notification');
        print('📨 Data: ${initialMessage.data}');
        // You can navigate to specific screen here
      }
    } catch (e) {
      print('⚠️ Error handling initial notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();

    if (_loading) {
      return _loadingScreen();
    }

    if (!_hasSeenOnboarding) {
      return const OnboardingScreen();
    }

    if (authVM.isLoading && authVM.currentUser == null) {
      return _loadingScreen();
    }

    if (authVM.currentUser != null) {
      return _authenticatedApp(authVM.currentUser!);
    }

    return const LoginScreen();
  }

  Widget _authenticatedApp(UserModel user) {
    // Initialize user notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserNotifications(user);
    });

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ChatViewModel(userId: user.uid),
        ),
      ],
      child: const NavigatorBottom(),
    );
  }

  Future<void> _initializeUserNotifications(UserModel user) async {
    try {
      print('🔔 Initializing notifications for ${user.name}');

      // Register user with NotificationService
      await NotificationService().registerUser(
        userId: user.uid,
        userName: user.name,
      );

      print('✅ User notifications initialized');
    } catch (e) {
      print('⚠️ Error initializing notifications: $e');
    }
  }

  Widget _loadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 20),
            const Text(
              'Loading...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
