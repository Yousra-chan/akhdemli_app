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
import 'package:service_app/Services/http_polling_service.dart';

/// Global navigator key (used by NotificationService)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Handler pour les notifications en background (QUAND APP EST FERMÉE)
/// CE DOIT ÊTRE UNE FONCTION GLOBALE, PAS DANS UNE CLASSE
/// CE CODE S'EXÉCUTE QUAND L'APP EST FERMÉE ET QU'UNE NOTIFICATION ARRIVE
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 [BACKGROUND HANDLER] Notification reçue quand app est fermée');
  print('📨 Message ID: ${message.messageId}');
  print('📨 Données: ${message.data}');
  print('📨 Titre: ${message.notification?.title}');
  print('📨 Corps: ${message.notification?.body}');

  // 1. Initialiser Firebase (OBLIGATOIRE)
  await Firebase.initializeApp();

  // 2. Initialiser les notifications locales
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 3. Configurer le channel Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('notification'),
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 4. Afficher la notification
  const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    channelDescription: 'Your channel description',
    importance: Importance.high,
    priority: Priority.high,
    ticker: 'ticker',
    playSound: true,
    sound: RawResourceAndroidNotificationSound('notification'),
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidNotificationDetails);

  await flutterLocalNotificationsPlugin.show(
    0,
    message.notification?.title ?? 'Nouveau message',
    message.notification?.body ?? 'Vous avez un nouveau message',
    notificationDetails,
    payload: json.encode(message.data),
  );

  print('✅ Notification affichée en background');

  // 5. Sauvegarder le message pour traitement quand l'app se rouvre
  try {
    final prefs = await SharedPreferences.getInstance();
    final pendingMessages =
        prefs.getStringList('pending_background_messages') ?? [];
    pendingMessages.add(json.encode({
      'data': message.data,
      'notification': {
        'title': message.notification?.title,
        'body': message.notification?.body,
      },
      'timestamp': DateTime.now().toIso8601String(),
    }));

    // Garder seulement les 10 derniers messages
    if (pendingMessages.length > 10) {
      pendingMessages.removeAt(0);
    }

    await prefs.setStringList('pending_background_messages', pendingMessages);
    print('💾 Message sauvegardé pour traitement ultérieur');
  } catch (e) {
    print('❌ Erreur sauvegarde message background: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('🚀 App starting...');

    /// 1️⃣ Firebase init
    await Firebase.initializeApp();
    print('✅ Firebase initialized');

    /// 2️⃣ 🔥 CONFIGURER LE BACKGROUND HANDLER - TRÈS IMPORTANT
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print('✅ Background handler configured');

    /// 3️⃣ Notification service init (votre service existant)
    await NotificationService.initialize();
    print('✅ NotificationService initialized');

    runApp(const ServiceApp());
  } catch (e, s) {
    print('❌ Fatal init error: $e');
    print('Stack trace: $s');
    // Even if Firebase fails, we can still run the app in offline mode
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
  bool _initError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      await _checkOnboarding();

      // Handle terminated → opened by notification
      await _handleInitialNotification();

      // Traiter les messages reçus quand l'app était fermée
      await _processPendingBackgroundMessages();

      print('✅ App initialization complete');
    } catch (e, stackTrace) {
      print('❌ Error during app initialization: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _initError = true;
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleInitialNotification() async {
    try {
      // Cette méthode vérifie si l'app a été lancée depuis une notification
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        print('🚀 App lancée depuis une notification!');
        print('📨 Données: ${initialMessage.data}');

        // Vous pouvez naviguer vers un chat spécifique ici
        // Par exemple: navigatorKey.currentState?.pushNamed('/chat', arguments: {...});
      }
    } catch (e) {
      print('⚠️ Error handling initial notification: $e');
    }
  }

  Future<void> _processPendingBackgroundMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMessages =
          prefs.getStringList('pending_background_messages') ?? [];

      if (pendingMessages.isNotEmpty) {
        print(
            '📨 Traitement de ${pendingMessages.length} messages reçus en background');

        for (final messageJson in pendingMessages) {
          try {
            final message = json.decode(messageJson) as Map<String, dynamic>;
            print(
                '📨 Message reçu en background: ${message['notification']?['title']}');

            // Ici vous pouvez traiter le message (ex: mettre à jour Firestore, etc.)
            // Par exemple, si c'est un message de chat, marquer comme livré
            final data = message['data'] as Map<String, dynamic>?;
            if (data != null && data['type'] == 'message') {
              await _markMessageAsDelivered(data);
            }
          } catch (e) {
            print('⚠️ Erreur traitement message background: $e');
          }
        }

        // Nettoyer après traitement
        await prefs.remove('pending_background_messages');
        print('✅ Tous les messages background traités');
      }
    } catch (e) {
      print('⚠️ Erreur traitement messages background: $e');
    }
  }

  Future<void> _markMessageAsDelivered(Map<String, dynamic> data) async {
    try {
      final messageId = data['messageId'];
      final chatId = data['chatId'];

      if (messageId != null && chatId != null) {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId.toString())
            .set({
          'status': 'delivered',
          'deliveredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print('✅ Message $messageId marqué comme livré');
      }
    } catch (e) {
      print('⚠️ Erreur marquage message comme livré: $e');
    }
  }

  Future<void> _checkOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
      print('📱 Onboarding status: $_hasSeenOnboarding');
    } catch (e) {
      print('⚠️ Error checking onboarding: $e');
      _hasSeenOnboarding = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();

    if (_loading) return _loadingScreen('Initializing app...');

    if (_initError) {
      return _errorScreen();
    }

    if (!_hasSeenOnboarding) return const OnboardingScreen();

    if (authVM.isLoading && authVM.currentUser == null) {
      return _loadingScreen('Checking session...');
    }

    if (authVM.currentUser != null) {
      return _authenticatedApp(authVM.currentUser!);
    }

    return const LoginScreen();
  }

  Widget _authenticatedApp(UserModel user) {
    // Save FCM token and initialize user connection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserConnection(user);
    });

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

  Future<void> _initializeUserConnection(UserModel user) async {
    try {
      print('🔗 Initializing user connection for ${user.uid}');

      // 1. Get FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        // 🔥 CORRECTION ICI: Affichez le token sur plusieurs lignes
        print('📱 =============== TOKEN FCM COMPLET ===============');
        // Affichez par segments de 80 caractères
        for (var i = 0; i < fcmToken.length; i += 80) {
          final end = i + 80 < fcmToken.length ? i + 80 : fcmToken.length;
          print('📱 ${fcmToken.substring(i, end)}');
        }
        print('📱 ================================================');
        print('📱 Longueur du token: ${fcmToken.length} caractères');

        // 2. Save to Firestore
        await _saveUserFCMToken(user.uid, fcmToken);

        // 3. Register with HTTP polling server (VOTRE SERVEUR RENDER)
        await _registerWithHttpPollingServer(user.uid, user.name, fcmToken);

        // 4. Start HTTP polling
        await _startHttpPolling();
      } else {
        print('⚠️ No FCM token available');
      }

      print('✅ User connection initialized');
    } catch (e) {
      print('⚠️ Error initializing user connection: $e');
    }
  }

  Future<void> _saveUserFCMToken(String userId, String fcmToken) async {
    try {
      print('💾 Saving FCM token to Firestore for user $userId');

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmToken': fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ FCM token saved to Firestore');
    } catch (e) {
      print('❌ Token save error to Firestore: $e');
    }
  }

  Future<void> _registerWithHttpPollingServer(
      String userId, String userName, String fcmToken) async {
    try {
      print('🔗 Registering with HTTP polling server...');

      // Utiliser VOTRE HttpPollingService
      final httpService = HttpPollingService();
      final connected = await httpService.connect(
        userId: userId,
        userName: userName,
        fcmToken: fcmToken,
      );

      if (connected) {
        print('✅ Registered with HTTP polling server');

        // Enregistrer aussi le token FCM sur le serveur Render
        await _registerFCMTokenOnRenderServer(userId, fcmToken);
      } else {
        print('❌ Failed to register with HTTP polling server');
      }
    } catch (e) {
      print('❌ Error registering with HTTP polling server: $e');
    }
  }

  Future<void> _registerFCMTokenOnRenderServer(
      String userId, String fcmToken) async {
    try {
      print('📤 Sending FCM token to Render server...');

      final response = await HttpPollingService().sendFCMTokenToServer(
        userId: userId,
        fcmToken: fcmToken,
      );

      if (response) {
        print('✅ FCM token sent to Render server');
      } else {
        print('❌ Failed to send FCM token to Render server');
      }
    } catch (e) {
      print('❌ Error sending FCM token to Render server: $e');
    }
  }

  Future<void> _startHttpPolling() async {
    try {
      print('🔄 Starting HTTP polling...');
      await HttpPollingService().startPolling();
      print('✅ HTTP polling started');
    } catch (e) {
      print('⚠️ Error starting HTTP polling: $e');
    }
  }

  Widget _loadingScreen(String text) {
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
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please wait...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 20),
              const Text(
                'Initialization Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage ?? 'Unknown error occurred',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _retryApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  // Continue without some features
                  setState(() {
                    _initError = false;
                    _loading = false;
                  });
                },
                child: const Text(
                  'Continue anyway',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _retryApp() {
    setState(() {
      _loading = true;
      _initError = false;
      _errorMessage = null;
    });
    _initApp();
  }
}
