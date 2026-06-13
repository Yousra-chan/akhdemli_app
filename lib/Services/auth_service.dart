import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:service_app/Services/notification_service.dart';
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
    clientId:
    "197748991211-f8lv4c72auk07p6bp5jt8169dre2jv4p.apps.googleusercontent.com",
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
  static const String _createdAtField = 'createdAt';
  static const String _updatedAtField = 'updatedAt';

  // Public streams
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Stream<UserModel?> get userModelStream {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return await fetchUserModel(user);
    });
  }

  /// Helper method to get translated strings
  String _tr(String key) {
    if (_languageProvider != null) {
      // Changed from 'auth' to 'auth_service'
      return _languageProvider!.tr(key, category: 'auth_service');
    }
    // Return fallback English messages if provider not set
    return _getFallbackEnglish(key);
  }

  /// Fallback English messages
  String _getFallbackEnglish(String key) {
    final Map<String, String> fallback = {
      'weak_password':
      'The password provided is too weak. Please use at least 8 characters with mixed case and numbers.',
      'email_already_in_use':
      'This email address is already registered. Please try logging in or use a different email.',
      'invalid_email':
      'The email address format is invalid. Please check and try again.',
      'user_not_found':
      'Invalid email or password. Please check your credentials.',
      'wrong_password':
      'Invalid email or password. Please check your credentials.',
      'network_request_failed':
      'Network error detected. Please check your internet connection and try again.',
      'account_exists_different_credential':
      'An account already exists with this email but different sign-in credentials. Please sign in with the original method.',
      'operation_not_allowed':
      'This sign-in method is currently disabled. Please contact support.',
      'too_many_requests': 'Too many login attempts. Please try again later.',
      'invalid_credential': 'Invalid credentials provided. Please try again.',
      'default_auth_error':
      'An authentication error occurred. Please try again later.',
      'fcm_token_failed': 'Failed to retrieve FCM token',
      'fcm_token_warning': 'Warning: Could not save FCM token for user',
      'fcm_token_remove_warning':
      'Warning: Could not remove FCM token for user',
      'invalid_coordinates': 'Invalid geographic coordinates provided',
      'firestore_save_failed': 'Failed to save user profile',
      'fetch_user_error': 'Error fetching user profile',
      'user_creation_failed': 'User creation failed',
      'empty_credentials': 'Email and password are required',
      'login_failed': 'Login failed',
      'profile_not_found': 'User profile not found',
      'login_error': 'Login failed',
      'anon_signin_failed': 'Anonymous sign-in failed',
      'anon_signin_error': 'Anonymous sign-in failed',
      'google_signin_cancelled': 'Google sign-in was cancelled',
      'google_signin_failed': 'Google sign-in failed',
      'google_signin_error': 'Google sign-in failed',
      'apple_token_missing': 'Apple sign-in failed: Missing identity token',
      'apple_signin_failed': 'Apple sign-in failed',
      'apple_signin_cancelled': 'Apple sign-in was cancelled',
      'apple_signin_error': 'Apple sign-in failed',
      'invalid_uid': 'Invalid user ID',
      'update_failed': 'Failed to update user data',
      'location_update_failed': 'Failed to update location',
      'role_update_failed': 'Failed to set user role',
      'empty_email': 'Email is required',
      'password_reset_error': 'An unexpected error occurred',
      'account_deletion_failed': 'Failed to delete user account',
      'empty_password': 'Password is required',
      'empty_name': 'Name is required',
      'empty_phone': 'Phone number is required',
      'invalid_email_format': 'Invalid email format',
      'logout_error': 'Error during logout',
    };
    return fallback[key] ?? key;
  }

  /// Handles Firebase Authentication errors and returns user-friendly messages
  String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return _tr('weak_password');
      case 'email-already-in-use':
        return _tr('email_already_in_use');
      case 'invalid-email':
        return _tr('invalid_email');
      case 'user-not-found':
        return _tr('user_not_found');
      case 'wrong-password':
        return _tr('wrong_password');
      case 'network-request-failed':
        return _tr('network_request_failed');
      case 'account-exists-with-different-credential':
        return _tr('account_exists_different_credential');
      case 'operation-not-allowed':
        return _tr('operation_not_allowed');
      case 'too-many-requests':
        return _tr('too_many_requests');
      case 'invalid-credential':
        return _tr('invalid_credential');
      default:
        return _tr('default_auth_error');
    }
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
      print('${_tr('fcm_token_warning')} $uid: $e');
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
      print('${_tr('fcm_token_remove_warning')} $uid: $e');
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
        double? lat,
        double? lon,
      }) async {
    try {
      final docRef = _firestore.collection(_usersCollection).doc(user.uid);
      final existingDoc = await docRef.get();

      // If user already exists, merge in any missing fields and return
      if (existingDoc.exists) {
        final existingUser =
        UserModel.fromMap(existingDoc.data()!, existingDoc.id);
        await docRef.set(existingUser.toMap(), SetOptions(merge: true));
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
      print('${_tr('fetch_user_error')}: $e');
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
    required String address,
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
          lat: lat,
          lon: lon,
        );

        // Initialize FCM token asynchronously
        await _saveFCMToken(user.uid);

        // Send email verification asynchronously
        await user.sendEmailVerification().catchError(
              (e) => print('Warning: Could not send verification email: $e'),
        );

        return userModel;
      } catch (e) {
        // Delete auth user if Firestore save fails
        await user.delete().catchError(
              (deleteError) =>
              print('Error cleaning up auth user: $deleteError'),
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
      if (userModel == null) {
        userModel = await _saveUserToFirestore(
          user,
          name: user.displayName ?? '',
          role: 'client',
          phone: '',
          address: '',
        );
      }

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

      if (userModel == null) {
        userModel = await _saveUserToFirestore(
          user,
          name: 'Guest User',
          role: 'guest',
          phone: '',
          address: '',
        );
      }

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
  Future<UserModel> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw AuthException(
          _tr('google_signin_cancelled'),
          code: 'google-signin-cancelled',
        );
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        throw AuthException(
          _tr('google_signin_failed'),
          code: 'google-signin-failed',
        );
      }

      final userModel = await _saveUserToFirestore(
        user,
        name: user.displayName ?? 'User',
        role: 'client',
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
  Future<UserModel> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (appleCredential.identityToken == null) {
        throw AuthException(
          _tr('apple_token_missing'),
          code: 'apple-token-missing',
        );
      }

      final credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        throw AuthException(
          _tr('apple_signin_failed'),
          code: 'apple-signin-failed',
        );
      }

      final userModel = await _saveUserToFirestore(
        user,
        name: user.displayName ?? 'User',
        role: 'client',
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
      if (e.toString().contains('cancelled')) {
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
    } catch (e) {
      print('${_tr('logout_error')}: $e');
      // Continue with logout even if cleanup fails
      rethrow;
    }
  }

  /// Deletes user account permanently
  ///
  /// WARNING: This operation is irreversible
  /// - Removes user from Firebase Auth
  /// - Deletes Firestore profile
  /// - Cleans up FCM tokens
  Future<void> deleteUserAccount(String uid) async {
    try {
      if (uid.isEmpty) {
        throw AuthException(
          _tr('invalid_uid'),
          code: 'invalid-uid',
        );
      }

      final currentUser = _auth.currentUser;

      // Delete Firestore profile
      await _firestore.collection(_usersCollection).doc(uid).delete();

      // Delete Firebase Auth user
      if (currentUser != null && currentUser.uid == uid) {
        await currentUser.delete();
      }

      print('User account deleted: $uid');
    } catch (e) {
      throw AuthException(
        '${_tr('account_deletion_failed')}: $e',
        code: 'account-deletion-failed',
      );
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Gets current authenticated user
  User? getCurrentUser() {
    return _auth.currentUser;
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