import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/ViewModel/search_view_model.dart';
import 'package:service_app/ViewModel/service_view_model.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/screens/auth/login/login_screen.dart';
import 'package:service_app/screens/navigator_bottom.dart';
import 'package:service_app/screens/onboarding/onboarding_screen.dart';
import 'package:service_app/screens/auth/language_selection_screen.dart';
import 'package:service_app/Services/notification_service.dart';
import 'package:service_app/providers/language_provider.dart';

import 'package:service_app/providers/theme_provider.dart';

import 'package:service_app/Services/auth_service.dart';
import 'package:service_app/Services/booking_notification_service.dart';

import 'package:service_app/screens/chat/disscussion/disscussion_page.dart';

/// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void setupNotificationTapHandler() {
  NotificationService.onNotificationTap = (data) {
    print('🎯 Notification Tapped Handler: $data');
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('⚠️ Navigator context is null');
      return;
    }

    final type = data['type'] ?? data['notificationType'];

    if (type == 'message') {
      final chatId = data['chatId'];
      final senderName = data['senderName'] ?? 'Chat';
      final senderId = data['senderId'];

      if (chatId != null && senderId != null) {
        try {
          final authVM = Provider.of<AuthViewModel>(context, listen: false);
          final chatVM = Provider.of<ChatViewModel?>(context, listen: false);

          if (authVM.currentUser != null && chatVM != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DiscussionPage(
                  contactName: senderName,
                  isOnline: true,
                  chatId: chatId,
                  currentUserId: authVM.currentUser!.uid,
                  chatViewModel: chatVM,
                ),
              ),
            );
          } else {
            print('⚠️ User not logged in or ChatVM not ready');
          }
        } catch (e) {
          print('❌ Error navigating from notification: $e');
        }
      }
    }
  };
}

/// Background handler (when app is closed)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔨 [BACKGROUND] Notification received');

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

    /// 4. Setup Notification Tap Handler
    setupNotificationTapHandler();
    print('✅ Notification tap handler configured');

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
        ChangeNotifierProxyProvider<AuthViewModel, ChatViewModel?>(
          create: (_) => null,
          update: (_, auth, previous) {
            if (auth.currentUser == null) return null;
            if (previous != null) {
              previous.updateUser(auth.currentUser!.uid);
              return previous;
            }
            return ChatViewModel(userId: auth.currentUser!.uid);
          },
        ),
        ChangeNotifierProvider(create: (_) => ServiceViewModel()),
        ChangeNotifierProvider(create: (_) => SearchViewModel()),
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..init(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<LanguageProvider, ThemeProvider>(
        builder: (context, languageProvider, themeProvider, child) {
          // Sync language provider with services
          AuthService.setLanguageProvider(languageProvider);
          NotificationService.setLanguageProvider(languageProvider);
          BookingNotificationService.setLanguageProvider(languageProvider);

          return MaterialApp(
            title: 'Akhdem-Li',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.currentTheme,

            /// Set locale from LanguageProvider
            locale: languageProvider.locale,

            /// Define supported locales
            supportedLocales: const [
              Locale('en'),
              Locale('fr'),
              Locale('ar'),
            ],

            /// IMPORTANT: Keep these localization delegates!
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            routes: {
              '/home': (_) => const NavigatorBottom(),
              '/login': (_) => const LoginScreen(),
              '/onboarding': (_) => const OnboardingScreen(),
              '/language': (_) => const LanguageSelectionScreen(),
            },
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

/// ============================================================================
/// AUTH WRAPPER WITH INTELLIGENT LANGUAGE FLOW
/// ============================================================================

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

      print('✅ App initialization complete');
      print('📱 Has seen onboarding: $_hasSeenOnboarding');
      print('⚙️ Has completed initial setup: $_hasCompletedInitialSetup');
    } catch (e) {
      print('⚠️ Error during app initialization: $e');
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
    // Only show if user has NOT completed initial setup AND is NOT logged in
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
      return _authenticatedApp(authVM.currentUser!);
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
