import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:service_app/Services/notification_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:async';
import '../models/UserModel.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        "197748991211-f8lv4c72auk07p6bp5jt8169dre2jv4p.apps.googleusercontent.com",
  );

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Stream<UserModel?> get userModelStream {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return await fetchUserModel(user);
    });
  }

  String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'This email address is already in use.';
      case 'invalid-email':
        return 'The email address format is invalid.';
      case 'user-not-found':
      case 'wrong-password':
        return 'Invalid email or password.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email address but different sign-in credentials.';
      case 'operation-not-allowed':
        return 'Sign-in method is not enabled. Please check Firebase console.';
      default:
        return 'An unknown authentication error occurred.';
    }
  }

  // --- FCM TOKEN MANAGEMENT ---
  /// Fetches the latest FCM token and saves it to the user's Firestore document.
  Future<void> _saveFCMToken(String uid) async {
    try {
      print('🔄 Getting FCM token for user: $uid');
      final token = await FirebaseMessaging.instance.getToken();
      print('📱 FCM Token: $token');

      if (token != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcmToken': token,
        });
        print('✅ FCM token saved to Firestore for user: $uid');

        // Verify it was saved
        final doc = await _firestore.collection('users').doc(uid).get();
        print('📋 Verified FCM token in Firestore: ${doc.data()?['fcmToken']}');
      } else {
        print('❌ FCM token is null - this is the problem!');
      }
    } catch (e) {
      print('❌ Error saving FCM token for $uid: $e');
    }
  }
  // -----------------------------

  Future<UserModel> _saveUserToFirestore(
    User user, {
    required String name,
    required String role,
    required String phone,
    String address = '',
    double? lat,
    double? lon,
  }) async {
    try {
      print('🔄 _saveUserToFirestore called for user: ${user.uid}');
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();

      print('📄 Firestore document exists: ${doc.exists}');

      if (doc.exists) {
        print('ℹ️ User already exists in Firestore, returning existing data');
        final existingUser = UserModel.fromMap(doc.data()!, doc.id);
        print('📋 Existing user data: ${existingUser.toMap()}');
        return existingUser;
      }

      print('➕ Creating new user document in Firestore');

      // Create GeoPoint if both lat and lon are provided
      GeoPoint? location;
      if (lat != null && lon != null) {
        location = GeoPoint(lat, lon);
        print('📍 Location set: $location');
      }

      final userDoc = UserModel(
        uid: user.uid,
        name: name,
        email: user.email ?? '',
        phone: phone,
        role: role,
        photoUrl: user.photoURL ?? '',
        createdAt: Timestamp.now(),
        location: location,
        address: address,
      );

      print('💾 User data to save: ${userDoc.toMap()}');

      await docRef.set(userDoc.toMap());
      print('✅ User successfully saved to Firestore: ${user.uid}');

      return userDoc;
    } catch (e) {
      print('❌ CRITICAL ERROR saving user to Firestore: $e');
      print('📋 Error details: ${e.toString()}');
      rethrow;
    }
  }

  Future<UserModel> signup({
    required String name,
    required String email,
    required String password,
    required String role,
    required String phone,
    required String address,
    double? lat,
    double? lon,
  }) async {
    try {
      print('Starting registration for: $email');

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw AuthException("User registration failed.");
      }

      print('Firebase Auth user created: ${user.uid}');

      try {
        final userModel = await _saveUserToFirestore(
          user,
          name: name,
          role: role,
          phone: phone,
          address: address, // This must be passed
          lat: lat,
          lon: lon,
        );

        print('User saved to Firestore: ${userModel.uid}');

        user.sendEmailVerification().catchError(
              (e) => print('Could not send verification email: $e'),
            );

        await _saveFCMToken(user.uid);
        return userModel;
      } catch (e) {
        print('Firestore save failed, deleting auth user: $e');
        try {
          await user.delete();
        } catch (deleteError) {
          print('Error deleting Firebase user: $deleteError');
        }
        throw AuthException('Registration failed while saving user data: $e');
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth error during signup: ${e.code}');
      throw AuthException(_handleFirebaseAuthError(e));
    } catch (e) {
      print('General signup error: $e');
      throw AuthException("Registration failed: $e");
    }
  }

  Future<UserModel> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw AuthException("Login failed.");

      final userModel = await fetchUserModel(user);
      if (userModel == null) {
        await _auth.signOut();
        throw AuthException("User profile not found.");
      }

      await _saveFCMToken(user.uid);

      if (!user.emailVerified) {
        // Resend verification email if not verified
        user.sendEmailVerification().catchError((_) {});
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleFirebaseAuthError(e));
    } catch (e) {
      throw AuthException("Login failed.");
    }
  }

  /// Allows a user to sign in anonymously (as a guest).
  Future<UserModel> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      if (user == null) throw AuthException("Anonymous sign-in failed.");

      var userModel = await fetchUserModel(user);

      userModel ??= await _saveUserToFirestore(
        user,
        name: 'Guest User',
        role: 'guest',
        phone: '',
        address: '',
      );

      await _saveFCMToken(user.uid);
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleFirebaseAuthError(e));
    } catch (e) {
      throw AuthException("Anonymous sign-in failed: $e");
    }
  }

  Future<UserModel?> fetchUserModel(User firebaseUser) async {
    try {
      final doc =
          await _firestore.collection('users').doc(firebaseUser.uid).get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error in fetchUserModel: $e');
      return null;
    }
  }

  Future<UserModel> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthException('Google sign-in was cancelled.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final user = userCredential.user;
      if (user == null) throw AuthException("Google Sign-in failed.");

      final userModel = await _saveUserToFirestore(
        user,
        name: user.displayName ?? 'New User',
        role: 'client',
        phone: '',
        address: '',
      );

      await _saveFCMToken(user.uid);
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleFirebaseAuthError(e));
    } catch (e) {
      throw AuthException("Google Sign-in failed.");
    }
  }

  Future<UserModel> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (appleCredential.identityToken == null) {
        throw AuthException("Apple Sign-in failed: Missing identity token.");
      }

      final AuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final user = userCredential.user;
      if (user == null) throw AuthException("Apple Sign-in failed.");

      final userModel = await _saveUserToFirestore(
        user,
        name: user.displayName ?? 'New User',
        role: 'client',
        phone: '',
        address: '',
      );

      await _saveFCMToken(user.uid);

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleFirebaseAuthError(e));
    } catch (e) {
      if (e.toString().contains('cancelled')) {
        throw AuthException('Apple sign-in was cancelled.');
      }
      throw AuthException("Apple Sign-in failed.");
    }
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  /// Update user location with latitude and longitude
  Future<void> updateUserLocation(String uid, double lat, double lon) async {
    await _firestore.collection('users').doc(uid).update({
      'location': GeoPoint(lat, lon),
    });
  }

  Future<void> logout() async {
    try {
      final notificationService = NotificationService();

      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Remove FCM token on logout
        await _firestore.collection('users').doc(currentUser.uid).update({
          'fcmToken': FieldValue.delete(),
        });
      }

      await FirebaseMessaging.instance.deleteToken();

      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('لا يوجد حساب مرتبط بهذا البريد الإلكتروني.');
      } else if (e.code == 'invalid-email') {
        throw Exception('البريد الإلكتروني غير صالح.');
      } else {
        throw Exception('حدث خطأ أثناء إرسال الرابط: ${e.message}');
      }
    } catch (e) {
      throw Exception('حدث خطأ غير متوقع: $e');
    }
  }
}

// Add this to your auth service or user management
Future<void> setUserRole(String userId, String role) async {
  try {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    print('✅ User $userId role set to: $role');
  } catch (e) {
    print('❌ Error setting user role: $e');
  }
}

// Call this when users register or in your admin panel
Future<void> initializeUserRoles() async {
  // Get all users and set default roles
  final users = await FirebaseFirestore.instance.collection('users').get();

  for (final userDoc in users.docs) {
    final userData = userDoc.data();
    if (userData['role'] == null) {
      // Set default role based on some logic
      // For example, set first user as provider, others as clients
      await setUserRole(userDoc.id, 'client');
    }
  }
}
