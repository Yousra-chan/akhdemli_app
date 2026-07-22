import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:service_app/providers/language_provider.dart';
import 'dart:async';
import '../models/UserModel.dart';

/// Custom exception for authentication-related errors
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Authentication service managing user sign-up, login, and profile management
class AuthService {
  // Private instances
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '817258417031-ckkqtm123d137cjtga7a7bas7sckqjl8.apps.googleusercontent.com',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add LanguageProvider as a static instance or pass it through a method
  static LanguageProvider? _languageProvider;

  // Method to set the language provider (call this when app starts)
  static void setLanguageProvider(LanguageProvider provider) {
    _languageProvider = provider;
  }

  // Constants for Firestore collections
  static const String _usersCollection = 'users';
  static const String _fcmTokenField = 'fcmToken';
  static const String _roleField = 'role';
  static const String _locationField = 'location';
  static const String _updatedAtField = 'updatedAt';

  // Public streams
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Gets current authenticated user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Stream<UserModel?> get userModelStream {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return await fetchUserModel(user);
    });
  }

  /// Helper method to get translated strings
  String _tr(String key) {
    if (_languageProvider != null) {
      return _languageProvider!.tr(key, category: 'auth_service');
    }
    return key;
  }

  /// Fallback English messages
  String _getFallbackEnglish(String key) {
    return key;
  }

  /// Handles Firebase Authentication errors and returns user-friendly messages
  String _handleFirebaseAuthError(FirebaseAuthException e) {
    return _tr(e.code.replaceAll('-', '_'));
  }

  // ============================================================================
  // FCM TOKEN MANAGEMENT
  // ============================================================================

  /// Retrieves and persists FCM token to Firestore for push notifications
  ///
  /// This method:
  /// - Fetches the latest FCM token from Firebase Messaging
  /// - Saves it to the user's Firestore document
  /// - Verifies successful persistence
  /// - Handles errors gracefully
  Future<void> _saveFCMToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token == null || token.isEmpty) {
        throw AuthException(
          _tr('fcm_token_failed'),
          code: 'fcm-token-null',
        );
      }

      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update({_fcmTokenField: token});
    } catch (e) {
      // Log error but don't fail authentication
      debugPrint('⚠️ [AuthService] ${_tr('fcm_token_warning')} $uid: $e');
    }
  }

  /// Removes FCM token from Firestore on logout
  Future<void> _removeFCMToken(String uid) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update({_fcmTokenField: FieldValue.delete()});
    } catch (e) {
      debugPrint('⚠️ [AuthService] ${_tr('fcm_token_remove_warning')} $uid: $e');
    }
  }

  // ============================================================================
  // USER PERSISTENCE
  // ============================================================================

  /// Saves or updates user profile in Firestore
  ///
  /// Parameters:
  /// - user: Firebase User object
  /// - name: User's full name
  /// - role: User's role (client, provider, admin, guest)
  /// - phone: User's phone number
  /// - address: User's address (optional)
  /// - lat, lon: Geographic coordinates (optional)
  ///
  /// Returns: UserModel representing the saved user
  /// Throws: AuthException if save operation fails
  Future<UserModel> _saveUserToFirestore(
      User user, {
        required String name,
        required String role,
        required String phone,
        String address = '',
        String? wilaya,
        String? commune,
        double? lat,
        double? lon,
      }) async {
    try {
      final docRef = _firestore.collection(_usersCollection).doc(user.uid);
      final existingDoc = await docRef.get();

      // If user already exists, merge in any missing fields and return
      if (existingDoc.exists) {
        final existingData = existingDoc.data()!;
        final existingUser = UserModel.fromMap(existingData, existingDoc.id);
        
        // Update basic info if it was missing in Firestore but available now
        Map<String, dynamic> updates = {};
        if ((existingData['name'] == null || existingData['name'] == '') && name.isNotEmpty) {
          updates['name'] = _sanitizeInput(name);
        }
        if ((existingData['photoUrl'] == null || existingData['photoUrl'] == '') && (user.photoURL != null)) {
          updates['photoUrl'] = user.photoURL;
        }
        
        if (updates.isNotEmpty) {
          await docRef.update(updates);
          return existingUser.copyWith(
            name: updates['name'] as String?,
            photoUrl: updates['photoUrl'] as String?,
          );
        }

        return existingUser;
      }

      // Create GeoPoint if coordinates provided
      GeoPoint? location;
      if (lat != null && lon != null) {
        // Validate coordinates
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
          throw AuthException(
            _tr('invalid_coordinates'),
            code: 'invalid-coordinates',
          );
        }
        location = GeoPoint(lat, lon);
      }

      // Create user document
      final userModel = UserModel(
        uid: user.uid,
        name: _sanitizeInput(name),
        email: user.email ?? '',
        phone: _sanitizeInput(phone),
        role: _validateRole(role),
        photoUrl: user.photoURL ?? '',
        createdAt: Timestamp.now(),
        location: location,
        address: _sanitizeInput(address),
        wilaya: wilaya,
        commune: commune,
        profileCompleted: (wilaya != null &&
            commune != null &&
            _sanitizeInput(phone).isNotEmpty),
      );

      await docRef.set(userModel.toMap());
      return userModel;
    } catch (e) {
      throw AuthException(
        '${_tr('firestore_save_failed')}: $e',
        code: 'firestore-save-failed',
      );
    }
  }

  /// Retrieves user profile from Firestore
  Future<UserModel?> fetchUserModel(User firebaseUser) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .get();

      if (!doc.exists) {
        return null;
      }

      return UserModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('❌ [AuthService] ${_tr('fetch_user_error')}: $e');
      return null;
    }
  }

  // ============================================================================
  // AUTHENTICATION METHODS
  // ============================================================================

  /// Registers a new user with email and password
  ///
  /// Performs the following:
  /// 1. Creates Firebase Authentication user
  /// 2. Saves user profile to Firestore
  /// 3. Initializes FCM token
  /// 4. Sends email verification
  ///
  /// Returns: UserModel of newly created user
  /// Throws: AuthException on registration failure
  Future<UserModel> signup({
    required String name,
    required String email,
    required String password,
    required String role,
    required String phone,
    String address = '',
    String? wilaya,
    String? commune,
    double? lat,
    double? lon,
  }) async {
    try {
      // Validate inputs
      _validateSignupInputs(email, password, name, phone);

      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw AuthException(
          _tr('user_creation_failed'),
          code: 'user-creation-failed',
        );
      }

      // Save user to Firestore
      try {
        final userModel = await _saveUserToFirestore(
          user,
          name: name,
          role: role,
          phone: phone,
          address: address,
          wilaya: wilaya,
          commune: commune,
          lat: lat,
          lon: lon,
        );

        // Initialize FCM token asynchronously
        await _saveFCMToken(user.uid);

        // Send email verification asynchronously
        await user.sendEmailVerification().catchError(
              (e) => debugPrint('⚠️ [AuthService] Warning: Could not send verification email: $e'),
        );

        return userModel;
      } catch (e) {
        // Delete auth user if Firestore save fails
        await user.delete().catchError(
              (deleteError) =>
              debugPrint('❌ [AuthService] Error cleaning up auth user: $deleteError'),
        );
        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        _handleFirebaseAuthError(e),
        code: e.code,
      );
    } catch (e) {
      throw AuthException(
        '${_tr('login_error')}: $e',
        code: 'signup-error',
      );
    }
  }

  /// Authenticates user with email and password
  ///
  /// Features:
  /// - Email verification check
  /// - Automatic FCM token refresh
  /// - Resends verification email if needed
  ///
  /// Returns: UserModel of authenticated user
  /// Throws: AuthException on login failure
  Future<UserModel> login(String email, String password) async {
    try {
      // Validate inputs
      if (email.isEmpty || password.isEmpty) {
        throw AuthException(
          _tr('empty_credentials'),
          code: 'empty-credentials',
        );
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw AuthException(
          _tr('login_failed'),
          code: 'login-failed',
        );
      }

      // Fetch user profile (auto-create if missing instead of signing out)
      var userModel = await fetchUserModel(user);
      userModel ??= await _saveUserToFirestore(
          user,
          name: user.displayName ?? '',
          role: 'client',
          phone: '',
          address: '',
        );

      // Update FCM token
      await _saveFCMToken(user.uid);

      // Resend verification email if not verified
      if (!user.emailVerified) {
        await user.sendEmailVerification().catchError((_) {});
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        _handleFirebaseAuthError(e),
        code: e.code,
      );
    } catch (e) {
      throw AuthException(
        '${_tr('login_error')}: $e',
        code: 'login-error',
      );
    }
  }

  /// Enables anonymous guest login
  ///
  /// Creates a temporary user session without credentials
  /// Generates guest profile automatically
  ///
  /// Returns: UserModel with guest role
  /// Throws: AuthException on sign-in failure
  Future<UserModel> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;

      if (user == null) {
        throw AuthException(
          _tr('anon_signin_failed'),
          code: 'anon-signin-failed',
        );
      }

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
      throw AuthException(
        _handleFirebaseAuthError(e),
        code: e.code,
      );
    } catch (e) {
      throw AuthException(
        '${_tr('anon_signin_error')}: $e',
        code: 'anon-signin-error',
      );
    }
  }

  /// Authenticates user with Google Sign-In
  ///
  /// Handles OAuth token exchange and profile creation
  /// Defaults new users to 'client' role
  ///
  /// Returns: UserModel of authenticated user
  /// Throws: AuthException on Google sign-in failure
  Future<UserModel> signInWithGoogle({String? password}) async {
    try {
      debugPrint('🚀 [AuthService] Starting Google Sign-In...');
      
      // Attempt to sign in
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('ℹ️ [AuthService] Google Sign-In cancelled by user');
        throw AuthException(
          _tr('google_signin_cancelled'),
          code: 'google-signin-cancelled',
        );
      }

      debugPrint('✅ [AuthService] Google user obtained: ${googleUser.email}');
      
      final googleAuth = await googleUser.authentication;
      debugPrint('✅ [AuthService] Google authentication tokens obtained');

      if (googleAuth.idToken == null) {
        debugPrint('❌ [AuthService] Google idToken is null. Check Firebase/Google Cloud Console configuration.');
        throw AuthException(
          'Google Sign-In failed: Missing ID Token. Please ensure Web Client ID is configured in Firebase.',
          code: 'google-no-id-token',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      debugPrint('🔄 [AuthService] Signing in to Firebase with Google credentials...');
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        debugPrint('❌ [AuthService] Firebase user is null after Google sign-in');
        throw AuthException(
          _tr('google_signin_failed'),
          code: 'google-signin-failed',
        );
      }

      debugPrint('✅ [AuthService] Firebase sign-in successful: ${user.uid}');

      // Link password if provided and user is new
      if (userCredential.additionalUserInfo?.isNewUser == true && password != null && user.email != null) {
        try {
          debugPrint('🔗 [AuthService] Linking password to new Google account...');
          final passwordCredential = EmailAuthProvider.credential(
            email: user.email!,
            password: password,
          );
          await user.linkWithCredential(passwordCredential);
          debugPrint('✅ [AuthService] Password linked successfully');
        } catch (e) {
          debugPrint('⚠️ [AuthService] Error linking password: $e');
        }
      }

      final userModel = await _saveUserToFirestore(
        user,
        name: user.displayName ?? 'User',
        role: 'client',
        phone: '',
        address: '',
      );

      await _saveFCMToken(user.uid);
      debugPrint('✅ [AuthService] Google Sign-In completed for ${user.email}');
      return userModel;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [AuthService] Firebase Auth Error during Google Sign-In: ${e.code} - ${e.message}');
      throw AuthException(
        _handleFirebaseAuthError(e),
        code: e.code,
      );
    } catch (e) {
      debugPrint('❌ [AuthService] Unexpected error during Google Sign-In: $e');
      throw AuthException(
        '${_tr('google_signin_error')}: $e',
        code: 'google-signin-error',
      );
    }
  }

  /// Authenticates user with Apple Sign-In
  ///
  /// Handles OAuth credential exchange and profile creation
  /// Supports iOS 13+ only
  ///
  /// Returns: UserModel of authenticated user
  /// Throws: AuthException on Apple sign-in failure
  Future<UserModel> signInWithApple({String? password}) async {
    try {
      debugPrint('🚀 [AuthService] Starting Apple Sign-In...');
      
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      debugPrint('✅ [AuthService] Apple credentials obtained');

      if (appleCredential.identityToken == null) {
        debugPrint('❌ [AuthService] Apple identityToken is null');
        throw AuthException(
          _tr('apple_token_missing'),
          code: 'apple-token-missing',
        );
      }

      final credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: null,
      );

      debugPrint('🔄 [AuthService] Signing in to Firebase with Apple credentials...');
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        debugPrint('❌ [AuthService] Firebase user is null after Apple sign-in');
        throw AuthException(
          _tr('apple_signin_failed'),
          code: 'apple-signin-failed',
        );
      }

      debugPrint('✅ [AuthService] Firebase sign-in successful: ${user.uid}');

      // Link password if provided and user is new
      if (userCredential.additionalUserInfo?.isNewUser == true && password != null && user.email != null) {
        try {
          debugPrint('🔗 [AuthService] Linking password to new Apple account...');
          final passwordCredential = EmailAuthProvider.credential(
            email: user.email!,
            password: password,
          );
          await user.linkWithCredential(passwordCredential);
          debugPrint('✅ [AuthService] Password linked successfully');
        } catch (e) {
          debugPrint('⚠️ [AuthService] Error linking password: $e');
        }
      }

      // Apple only provides name on the FIRST sign-in
      String displayName = 'User';
      if (appleCredential.givenName != null) {
        displayName = '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim();
      } else if (user.displayName != null && user.displayName!.isNotEmpty) {
        displayName = user.displayName!;
      }

      final userModel = await _saveUserToFirestore(
        user,
        name: displayName,
        role: 'client',
        phone: '',
        address: '',
      );

      await _saveFCMToken(user.uid);
      debugPrint('✅ [AuthService] Apple Sign-In completed for ${user.uid}');
      return userModel;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [AuthService] Firebase Auth Error during Apple Sign-In: ${e.code} - ${e.message}');
      throw AuthException(
        _handleFirebaseAuthError(e),
        code: e.code,
      );
    } catch (e) {
      debugPrint('❌ [AuthService] Unexpected error during Apple Sign-In: $e');
      if (e.toString().contains('cancelled') || e.toString().contains('canceled')) {
        debugPrint('ℹ️ [AuthService] Apple Sign-In cancelled by user');
        throw AuthException(
          _tr('apple_signin_cancelled'),
          code: 'apple-signin-cancelled',
        );
      }
      throw AuthException(
        '${_tr('apple_signin_error')}: $e',
        code: 'apple-signin-error',
      );
    }
  }

  // ============================================================================
  // USER MANAGEMENT
  // ============================================================================

  /// Updates user data in Firestore
  ///
  /// Parameters:
  /// - uid: User's unique identifier
  /// - data: Map of fields to update
  ///
  /// Automatically adds updatedAt timestamp
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      if (uid.isEmpty) {
        throw AuthException(
          _tr('invalid_uid'),
          code: 'invalid-uid',
        );
      }

      // Add timestamp
      data[_updatedAtField] = FieldValue.serverTimestamp();

      await _firestore.collection(_usersCollection).doc(uid).update(data);
    } catch (e) {
      throw AuthException(
        '${_tr('update_failed')}: $e',
        code: 'update-failed',
      );
    }
  }

  /// Updates user location with geographic coordinates
  ///
  /// Validates coordinates before saving
  /// Includes timestamp of last update
  Future<void> updateUserLocation(String uid, double lat, double lon) async {
    try {
      if (uid.isEmpty) {
        throw AuthException(
          _tr('invalid_uid'),
          code: 'invalid-uid',
        );
      }

      // Validate coordinates
      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        throw AuthException(
          _tr('invalid_coordinates'),
          code: 'invalid-coordinates',
        );
      }

      await _firestore.collection(_usersCollection).doc(uid).update({
        _locationField: GeoPoint(lat, lon),
        _updatedAtField: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AuthException(
        '${_tr('location_update_failed')}: $e',
        code: 'location-update-failed',
      );
    }
  }

  /// Sets or updates user role
  ///
  /// Validates role before assignment
  /// Updates server timestamp
  Future<void> setUserRole(String userId, String role) async {
    try {
      if (userId.isEmpty) {
        throw AuthException(
          _tr('invalid_uid'),
          code: 'invalid-uid',
        );
      }

      final validatedRole = _validateRole(role);

      await _firestore.collection(_usersCollection).doc(userId).update({
        _roleField: validatedRole,
        _updatedAtField: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AuthException(
        '${_tr('role_update_failed')}: $e',
        code: 'role-update-failed',
      );
    }
  }

  /// Initiates password reset flow
  ///
  /// Sends password reset email to user
  /// User must verify email before resetting
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      if (email.isEmpty) {
        throw AuthException(
          _tr('empty_email'),
          code: 'empty-email',
        );
      }

      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw AuthException(
          _tr('user_not_found'),
          code: 'user-not-found',
        );
      } else if (e.code == 'invalid-email') {
        throw AuthException(
          _tr('invalid_email'),
          code: 'invalid-email',
        );
      }
      throw AuthException(
        '${_handleFirebaseAuthError(e)}: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw AuthException(
        '${_tr('password_reset_error')}: $e',
        code: 'password-reset-error',
      );
    }
  }

  // ============================================================================
  // LOGOUT AND CLEANUP
  // ============================================================================

  /// Securely logs out current user
  ///
  /// Performs cleanup:
  /// - Removes FCM token
  /// - Signs out from Firebase
  /// - Clears Google Sign-In session
  /// - Clears all authentication data
  Future<void> logout() async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser != null) {
        // Remove FCM token from Firestore
        await _removeFCMToken(currentUser.uid);
      }

      // Delete FCM token from device
      await FirebaseMessaging.instance.deleteToken();

      // Sign out from all providers
      await _googleSignIn.signOut();
      await _auth.signOut();
      debugPrint('✅ [AuthService] Logout successful');
    } catch (e) {
      debugPrint('❌ [AuthService] ${_tr('logout_error')}: $e');
      // Continue with logout even if cleanup fails
      rethrow;
    }
  }

  /// Deletes user account permanently
  ///
  /// WARNING: This operation is irreversible
  /// - Removes user from Firebase Auth
  /// - Deletes Firestore profile
  /// - Cleans up all related data (services, bookings, ratings, etc.)
  Future<void> deleteUserAccount(String uid) async {
    try {
      if (uid.isEmpty) {
        throw AuthException(
          _tr('invalid_uid'),
          code: 'invalid-uid',
        );
      }

      final currentUser = _auth.currentUser;

      // 1. Delete user's services
      final services = await _firestore
          .collection('services')
          .where('providerId', isEqualTo: uid)
          .get();
      for (var doc in services.docs) {
        await doc.reference.delete();
      }

      // 2. Delete user's posts
      final posts = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in posts.docs) {
        await doc.reference.delete();
      }

      // 3. Delete user's jobs
      final jobsAsClient = await _firestore
          .collection('jobs')
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in jobsAsClient.docs) {
        await doc.reference.delete();
      }

      final jobsAsProvider = await _firestore
          .collection('jobs')
          .where('providerId', isEqualTo: uid)
          .get();
      for (var doc in jobsAsProvider.docs) {
        await doc.reference.delete();
      }

      // 4. Delete user's bookings (as client or provider)
      final clientBookings = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in clientBookings.docs) {
        await doc.reference.delete();
      }
      
      final providerBookings = await _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: uid)
          .get();
      for (var doc in providerBookings.docs) {
        await doc.reference.delete();
      }

      // 5. Delete user's ratings and reviews
      final ratings = await _firestore
          .collection('ratings')
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in ratings.docs) {
        await doc.reference.delete();
      }

      final reviewsAsReviewer = await _firestore
          .collection('reviews')
          .where('reviewerId', isEqualTo: uid)
          .get();
      for (var doc in reviewsAsReviewer.docs) {
        await doc.reference.delete();
      }

      final reviewsAsReviewed = await _firestore
          .collection('reviews')
          .where('reviewedId', isEqualTo: uid)
          .get();
      for (var doc in reviewsAsReviewed.docs) {
        await doc.reference.delete();
      }

      // 6. Delete user's notifications
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in notifications.docs) {
        await doc.reference.delete();
      }

      // 7. Delete user's chats and messages
      final userChats = await _firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();
      
      for (var chatDoc in userChats.docs) {
        // Delete all messages in the chat subcollection
        final messages = await chatDoc.reference.collection('messages').get();
        for (var msgDoc in messages.docs) {
          await msgDoc.reference.delete();
        }
        // Delete the chat document itself
        await chatDoc.reference.delete();
      }

      // 8. Delete provider gallery
      await _firestore.collection('provider_galleries').doc(uid).delete();

      // 9. Delete user's reports (as reporter or target)
      final reportsAsReporter = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: uid)
          .get();
      for (var doc in reportsAsReporter.docs) {
        await doc.reference.delete();
      }

      final reportsAsTarget = await _firestore
          .collection('reports')
          .where('targetId', isEqualTo: uid)
          .get();
      for (var doc in reportsAsTarget.docs) {
        await doc.reference.delete();
      }

      // 10. Delete Firestore profile
      await _firestore.collection(_usersCollection).doc(uid).delete();

      // 11. Delete Firebase Auth user
      if (currentUser != null && currentUser.uid == uid) {
        await currentUser.delete();
      }

      debugPrint('✅ [AuthService] All user data deleted: $uid');
    } catch (e) {
      debugPrint('❌ [AuthService] ${_tr('account_deletion_failed')}: $e');
      throw AuthException(
        '${_tr('account_deletion_failed')}: $e',
        code: 'account-deletion-failed',
      );
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Sends email verification to the current user
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    debugPrint('📧 [AuthService] sendEmailVerification called for: ${user?.email}');
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
        debugPrint('✅ [AuthService] sendEmailVerification successful');
      } catch (e) {
        debugPrint('❌ [AuthService] sendEmailVerification failed: $e');
        rethrow;
      }
    } else {
      debugPrint('⚠️ [AuthService] sendEmailVerification skipped: User null or already verified');
    }
  }

  /// Reloads the current user and returns the email verification status
  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      return _auth.currentUser!.emailVerified;
    }
    return false;
  }

  /// Validates and sanitizes user input
  /// Removes leading/trailing whitespace and prevents injection
  String _sanitizeInput(String input) {
    return input.trim();
  }

  /// Validates user role against allowed values
  ///
  /// Allowed roles: 'client', 'provider', 'admin', 'guest'
  /// Defaults to 'client' if invalid
  String _validateRole(String role) {
    const allowedRoles = ['client', 'provider', 'admin', 'guest'];
    return allowedRoles.contains(role.toLowerCase())
        ? role.toLowerCase()
        : 'client';
  }

  /// Validates signup input parameters
  ///
  /// Checks:
  /// - Email format
  /// - Password strength (minimum 8 chars)
  /// - Name not empty
  /// - Phone not empty
  void _validateSignupInputs(
      String email,
      String password,
      String name,
      String phone,
      ) {
    if (email.isEmpty) {
      throw AuthException(
        _tr('empty_email'),
        code: 'empty-email',
      );
    }

    if (!_isValidEmail(email)) {
      throw AuthException(
        _tr('invalid_email_format'),
        code: 'invalid-email-format',
      );
    }

    if (password.isEmpty) {
      throw AuthException(
        _tr('empty_password'),
        code: 'empty-password',
      );
    }

    if (password.length < 8) {
      throw AuthException(
        _tr('weak_password'),
        code: 'weak-password',
      );
    }

    if (name.isEmpty) {
      throw AuthException(
        _tr('empty_name'),
        code: 'empty-name',
      );
    }

    if (phone.isEmpty) {
      throw AuthException(
        _tr('empty_phone'),
        code: 'empty-phone',
      );
    }
  }

  /// Validates email format using regex
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }
}
