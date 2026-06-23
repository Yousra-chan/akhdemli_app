import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/ViewModel/search_view_model.dart';
import 'package:service_app/ViewModel/service_view_model.dart';
import 'package:service_app/screens/auth/login/login_screen.dart';
import 'package:service_app/screens/navigator_bottom.dart';
import 'package:service_app/screens/onboarding/onboarding_screen.dart';
import 'package:service_app/screens/auth/language_selection_screen.dart';
import 'package:service_app/Services/notification_service.dart';
import 'package:service_app/providers/language_provider.dart';

import 'package:service_app/providers/theme_provider.dart';

import 'package:service_app/Services/auth_service.dart';
import 'package:service_app/Services/booking_notification_service.dart';

import 'package:service_app/auth_wrapper.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_page.dart';
import 'package:service_app/screens/Booking/my_booking_page.dart';

/// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void setupNotificationTapHandler() {
  NotificationService.onNotificationTap = (data) {
    debugPrint('🎯 Notification Tapped Handler: $data');
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('⚠️ Navigator context is null');
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
            debugPrint('⚠️ User not logged in or ChatVM not ready');
          }
        } catch (e) {
          debugPrint('❌ Error navigating from notification: $e');
        }
      }
    } else if (type == 'booking') {
      try {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
        );
      } catch (e) {
        debugPrint('❌ Error navigating to bookings: $e');
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    }
  };
}

/// Background handler (when app is closed)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // IMPORTANT: We only show a manual notification if message.notification is NULL.
  // If message.notification is NOT NULL, Firebase on Android will automatically
  // show the notification based on the notification object in the payload.
  // Showing it manually here would cause duplicates.
  
  debugPrint('🔨 [BACKGROUND] Message received: ${message.messageId}');

  if (message.notification != null) {
    debugPrint('ℹ️ Message has notification payload. OS will handle it.');
    return;
  }

  // Handle data-only message by showing a local notification
  debugPrint('ℹ️ Data-only message. Showing local notification.');

  try {
    await Firebase.initializeApp();
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

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

    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.data['title'] ?? 'New Alert',
      message.data['body'] ?? 'You have a new update',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: json.encode(message.data),
    );
  } catch (e) {
    debugPrint('❌ Error in background handler: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Flutter error handler
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🚨 FLUTTER ERROR: ${details.exception}');
    // TODO: Send to Crashlytics in production
  };

  try {
    debugPrint('🚀 App starting...');

    /// 1. Initialize Firebase
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');

    /// 2. Configure background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    debugPrint('✅ Background handler configured');

    /// 3. Initialize Notification Service
    await NotificationService.initialize();
    debugPrint('✅ NotificationService initialized');

    /// 4. Setup Notification Tap Handler
    setupNotificationTapHandler();
    debugPrint('✅ Notification tap handler configured');

    /// 5. Handle initial message (from terminated state)
    await NotificationService().handleInitialMessage();
    debugPrint('✅ Initial message handled');

    runApp(const ServiceApp());
  } catch (e, s) {
    debugPrint('❌ Fatal init error: $e');
    debugPrint('Stack trace: $s');
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
            title: languageProvider.tr('app_name', category: 'common'),
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

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
