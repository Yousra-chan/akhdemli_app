import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/Services/subscription_service.dart';
import 'package:service_app/Services/auth_service.dart';
import 'package:service_app/Services/user_service.dart';

/// Custom exception for auth view model operations
class AuthViewModelException implements Exception {
  final String message;
  final String? code;

  AuthViewModelException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Authentication ViewModel managing auth state and user operations
///
/// Handles:
/// - User authentication (login, signup, OAuth)
/// - Auth state management
/// - User profile management
/// - Image selection and encoding
/// - Error handling and state notifications
class AuthViewModel with ChangeNotifier {
  // Services
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  // State variables
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;

  // Getters
  UserModel? get currentUser => _currentUser;

  bool get isLoading => _isLoading;

  String? get error => _error;

  bool get isAuthenticated => _currentUser != null;

  bool get isInitialized => _initialized;

  bool get isEmailVerified {
    final user = FirebaseAuth.instance.currentUser;
    return user?.emailVerified ?? false;
  }

  // Constants
  static const int _imageSizeMaxHeight = 400;
  static const int _imageSizeMaxWidth = 400;
  static const int _imageQuality = 75;
  static const int _maxImageFileSizeBytes = 5242880; // 5MB

  AuthViewModel() {
    debugPrint('🔄 [AuthViewModel] Initializing...');
    _initializeAuthState();
  }

  // ============================================================================
  // PUBLIC AUTH METHODS
  // ============================================================================

  /// Reloads user to check for updated verification status
  Future<void> checkEmailVerificationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      debugPrint('🔍 [AuthViewModel] Checked email verification: ${user.emailVerified}');
      notifyListeners();
    }
  }

  /// Resends verification email
  Future<void> resendVerificationEmail() async {
    return _executeOperation(() async {
      await _authService.sendEmailVerification();
      debugPrint('📧 [AuthViewModel] Verification email sent');
    }, 'Resend verification');
  }

  /// Logs in user with email and password
  Future<UserModel?> login(String email, String password) async {
    debugPrint('🔑 [AuthViewModel] Attempting email login for: $email');
    return _executeAuthOperation(() async {
      _validateLoginInputs(email, password);

      final userModel = await _authService.login(email, password);
      _setUser(userModel);
      debugPrint('✅ [AuthViewModel] Login successful for: $email');
      return userModel;
    }, 'Login');
  }

  /// Signs in user with Google account
  Future<UserModel?> signInWithGoogle() async {
    debugPrint('🌐 [AuthViewModel] Attempting Google Sign-In');
    return _executeAuthOperation(() async {
      final userModel = await _authService.signInWithGoogle();
      _setUser(userModel);
      debugPrint('✅ [AuthViewModel] Google Sign-In successful');
      return userModel;
    }, 'Google sign-in');
  }

  /// Signs in user with Apple account
  Future<UserModel?> signInWithApple() async {
    debugPrint('🍎 [AuthViewModel] Attempting Apple Sign-In');
    return _executeAuthOperation(() async {
      final userModel = await _authService.signInWithApple();
      _setUser(userModel);
      debugPrint('✅ [AuthViewModel] Apple Sign-In successful');
      return userModel;
    }, 'Apple sign-in');
  }

  /// Registers new user with email and password
  ///
  /// Parameters:
  /// - name: User's full name
  /// - email: Email address
  /// - password: Password
  /// - role: User role (client, provider)
  /// - phone: Phone number
  /// - address: User's address
  /// - lat, lon: Optional geographic coordinates
  ///
  /// Returns: UserModel if successful, null otherwise
  /// Throws: AuthViewModelException on validation failure
  Future<UserModel?> signup({
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
    return _executeAuthOperation(() async {
      _validateSignupInputs(
        name: name,
        email: email,
        password: password,
        role: role,
        phone: phone,
        wilaya: wilaya,
        commune: commune,
      );

      final userModel = await _authService.signup(
        name: name,
        email: email,
        password: password,
        role: role,
        phone: phone,
        address: address,
        wilaya: wilaya,
        commune: commune,
        lat: lat,
        lon: lon,
      );

      _setUser(userModel);
      return userModel;
    }, 'Sign up');
  }

  /// Logs out current user
  ///
  /// Throws: Exception if logout fails
  Future<void> logout() async {
    return _executeOperation(() async {
      await _authService.logout();
      _clearUser();
    }, 'Logout');
  }

  /// Sends password reset email
  ///
  /// Parameters:
  /// - email: Email address to send reset link to
  ///
  /// Throws: Exception on failure
  Future<void> sendPasswordResetEmail(String email) async {
    return _executeOperation(
      () {
        _validateEmail(email);
        return _authService.sendPasswordResetEmail(email);
      },
      'Password reset',
    );
  }

  /// Updates user profile
  ///
  /// Parameters:
  /// - updatedUser: Updated UserModel
  ///
  /// Throws: Exception on failure
  Future<void> updateUserProfile(UserModel updatedUser) async {
    return _executeOperation(() async {
      _validateUserModel(updatedUser);

      await _userService.updateUser(updatedUser);
      _setUser(updatedUser);
    }, 'Profile update');
  }

  /// Updates user role
  ///
  /// Parameters:
  /// - newRole: New role value (must be valid role)
  ///
  /// Throws: AuthViewModelException on validation failure or update failure
  Future<void> updateUserRole(String newRole) async {
    return _executeOperation(() async {
      _validateUserRole(newRole);

      if (_currentUser == null) {
        throw AuthViewModelException(
          'No user logged in',
          code: 'no-current-user',
        );
      }

      print('🔄 Updating user role from ${_currentUser!.role} to $newRole');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({
        'role': newRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Firestore role update completed');

      _currentUser = _currentUser!.copyWith(role: newRole);
      debugPrint('✅ Local user updated to: ${_currentUser!.role}');
      notifyListeners();
    }, 'Role update');
  }

  /// Completes user profile with additional information
  /// 
  /// Parameters:
  /// - wilaya: Selected wilaya
  /// - commune: Selected commune
  /// - phone: User's phone number
  /// - lat, lon: Optional geographic coordinates
  Future<void> completeProfile({
    required String wilaya,
    required String commune,
    required String phone,
    double? lat,
    double? lon,
  }) async {
    return _executeOperation(() async {
      if (_currentUser == null) {
        throw AuthViewModelException(
          'No user logged in',
          code: 'no-current-user',
        );
      }

      GeoPoint? location;
      if (lat != null && lon != null) {
        location = GeoPoint(lat, lon);
      }

      final updatedUser = _currentUser!.copyWith(
        wilaya: wilaya,
        commune: commune,
        phone: phone,
        location: location,
        profileCompleted: true,
      );

      await _userService.updateUser(updatedUser);
      _setUser(updatedUser);
    }, 'Complete profile');
  }

  // ============================================================================
  // IMAGE HANDLING
  // ============================================================================

  /// Picks image from gallery and encodes to base64
  ///
  /// Returns: Base64 encoded image string with MIME type, or null if cancelled
  /// Throws: AuthViewModelException on encoding failure
  Future<String?> pickImageAndEncode() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxHeight: _imageSizeMaxHeight.toDouble(),
        maxWidth: _imageSizeMaxWidth.toDouble(),
        imageQuality: _imageQuality,
      );

      if (pickedFile == null) {
        debugPrint('ℹ️ Image selection cancelled by user');
        return null;
      }

      return await _encodeImageToBase64(pickedFile);
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      _setError('error_image_pick_failed');
      rethrow;
    }
  }

  /// Encodes image file to base64 string
  ///
  /// Parameters:
  /// - pickedFile: XFile from image picker
  ///
  /// Returns: Base64 encoded image with MIME type prefix
  /// Throws: AuthViewModelException on encoding failure
  Future<String> _encodeImageToBase64(XFile pickedFile) async {
    try {
      final file = File(pickedFile.path);

      // Validate file exists
      if (!await file.exists()) {
        throw AuthViewModelException(
          'Image file not found',
          code: 'file-not-found',
        );
      }

      // Validate file size
      final fileSize = await file.length();
      if (fileSize > _maxImageFileSizeBytes) {
        throw AuthViewModelException(
          'Image file too large (max 5MB)',
          code: 'file-too-large',
        );
      }

      // Read and encode
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      debugPrint('❌ Error encoding image: $e');
      _setError('error_image_encode_failed');
      rethrow;
    }
  }

  // ============================================================================
  // PRIVATE INITIALIZATION METHODS
  // ============================================================================

  /// Initializes authentication state on app startup
  Future<void> _initializeAuthState() async {
    debugPrint('🔄 [AuthViewModel] Starting auth initialization');

    try {
      _authService.authStateChanges.listen(_handleAuthStateChange);
      
      final firebaseUser = _authService.getCurrentUser();
      if (firebaseUser != null) {
        debugPrint('🔍 [AuthViewModel] Found existing Firebase user: ${firebaseUser.uid}');
        await _fetchCurrentUser(firebaseUser.uid);
      } else {
        debugPrint('ℹ️ [AuthViewModel] No existing session found');
        _setUser(null);
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [AuthViewModel] Error during initialization: $e');
      _setError('error_initialization_failed');
      _initialized = true; 
      notifyListeners();
    }
  }

  /// Handles Firebase authentication state changes
  void _handleAuthStateChange(User? firebaseUser) async {
    debugPrint('🔄 [AuthViewModel] Firebase Auth State Change: ${firebaseUser?.uid ?? "Logged Out"}');

    if (firebaseUser != null) {
      await _fetchCurrentUser(firebaseUser.uid);
    } else {
      _clearUser();
    }
  }

  /// Fetches current user profile from Firestore
  ///
  /// Parameters:
  /// - uid: User ID to fetch
  /// Gets the user profile, auto-creating a default one if missing
  Future<UserModel?> _getOrCreateUser(String uid) async {
    var userModel = await _userService.getUserById(uid);

    if (userModel == null) {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        userModel = UserModel(
          uid: uid,
          name: firebaseUser.displayName ?? '',
          email: firebaseUser.email ?? '',
          phone: firebaseUser.phoneNumber ?? '',
          role: 'client',
          photoUrl: firebaseUser.photoURL ?? '',
          createdAt: Timestamp.now(),
          address: '',
        );
        await _userService.createUser(userModel);
      }
    }

    return userModel;
  }

  Future<void> _fetchCurrentUser(String uid) async {
    try {
      _validateUserId(uid);

      debugPrint('🔄 Fetching user profile for uid: $uid');
      // Ensure subscription expiry is enforced before returning the user
      try {
        final subService = SubscriptionService();
        await subService.checkAndUpdateExpiryForProvider(uid);
      } catch (e) {
        debugPrint('❌ Error checking subscription expiry: $e');
      }

      final userModel = await _getOrCreateUser(uid);
      if (userModel != null) {
        debugPrint('✅ UserModel loaded: ${userModel.name} (${userModel.role})');
        _setUser(userModel);
      } else {
        debugPrint('❌ User profile not found in Firestore');
        _setError('error_user_not_found');
      }
    } catch (e) {
      debugPrint('❌ Error loading user profile: $e');
      _setError('error_loading_profile');
    }
  }

  /// Public method to refresh the current user from Firestore
  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;
    await _fetchCurrentUser(_currentUser!.uid);
  }

  /// Fetches user and sets current user
  ///
  /// Parameters:
  /// - uid: User ID to fetch
  ///
  /// Returns: UserModel if found, null otherwise
  Future<UserModel?> _fetchAndSetUser(String uid) async {
    try {
      _validateUserId(uid);

      final userModel = await _getOrCreateUser(uid);
      _setUser(userModel);
      return userModel;
    } catch (e) {
      debugPrint('❌ Failed to load user profile: $e');
      _setError('error_loading_profile');
      return null;
    }
  }

  // ============================================================================
  // EXECUTION HELPERS
  // ============================================================================

  /// Executes authentication operation with error handling
  ///
  /// Parameters:
  /// - operation: Async operation to execute
  /// - operationName: Name for logging
  ///
  /// Returns: Result of operation, or null on failure
  Future<UserModel?> _executeAuthOperation(
    Future<UserModel?> Function() operation,
    String operationName,
  ) async {
    try {
      _setLoading(true);
      _setError(null);
      return await operation();
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getFirebaseAuthErrorMessage(e);
      _setError('$operationName failed: $errorMessage');
      return null;
    } on AuthViewModelException catch (e) {
      _setError('$operationName failed: ${e.message}');
      return null;
    } catch (e) {
      _setError('$operationName failed: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Executes operation with error handling
  ///
  /// Parameters:
  /// - operation: Async operation to execute
  /// - operationName: Name for logging
  ///
  /// Throws: Exception on failure after setting error state
  Future<void> _executeOperation(
    Future<void> Function() operation,
    String operationName,
  ) async {
    try {
      _setLoading(true);
      _setError(null);
      await operation();
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getFirebaseAuthErrorMessage(e);
      _setError('$operationName failed: $errorMessage');
      rethrow;
    } on AuthViewModelException catch (e) {
      _setError('$operationName failed: ${e.message}');
      rethrow;
    } catch (e) {
      _setError('$operationName failed: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // STATE MANAGEMENT
  // ============================================================================

  /// Sets current user and clears error
  void _setUser(UserModel? user) {
    debugPrint('🔄 [AuthViewModel] Setting user: ${user?.uid ?? "null"}');
    _currentUser = user;
    _error = null;
    notifyListeners();
  }

  /// Clears current user
  void _clearUser() {
    debugPrint('🔄 [AuthViewModel] Clearing user');
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  /// Sets loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Sets error message
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Clears error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ============================================================================
  // ERROR MAPPING
  // ============================================================================

  /// Maps Firebase auth exceptions to user-friendly messages
  ///
  /// Parameters:
  /// - e: FirebaseAuthException
  ///
  /// Returns: User-friendly error message
  String _getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    const errorMessages = {
      'user-not-found': 'No user found with this email address',
      'wrong-password': 'Incorrect password',
      'invalid-email': 'Invalid email address',
      'user-disabled': 'This account has been disabled',
      'email-already-in-use': 'An account already exists with this email',
      'weak-password': 'Password is too weak',
      'network-request-failed': 'Network error. Please check your connection',
      'too-many-requests': 'Too many login attempts. Please try again later.',
      'operation-not-allowed': 'This operation is not allowed',
      'account-exists-with-different-credential':
          'This email is already registered with a different method',
    };

    return errorMessages[e.code] ?? 'Authentication failed: ${e.message}';
  }

  // ============================================================================
  // INPUT VALIDATION METHODS
  // ============================================================================

  /// Validates login inputs
  ///
  /// Throws: AuthViewModelException on validation failure
  void _validateLoginInputs(String email, String password) {
    _validateEmail(email);

    if (password.isEmpty) {
      throw AuthViewModelException(
        'Password cannot be empty',
        code: 'empty-password',
      );
    }

    if (password.length < 6) {
      throw AuthViewModelException(
        'Password must be at least 6 characters',
        code: 'password-too-short',
      );
    }
  }

  /// Validates signup inputs
  ///
  /// Throws: AuthViewModelException on validation failure
  void _validateSignupInputs({
    required String name,
    required String email,
    required String password,
    required String role,
    required String phone,
    String? wilaya,
    String? commune,
  }) {
    if (name.trim().isEmpty) {
      throw AuthViewModelException(
        'Name cannot be empty',
        code: 'empty-name',
      );
    }

    if (name.length > 100) {
      throw AuthViewModelException(
        'Name is too long (max 100 characters)',
        code: 'name-too-long',
      );
    }

    _validateEmail(email);

    if (password.isEmpty) {
      throw AuthViewModelException(
        'Password cannot be empty',
        code: 'empty-password',
      );
    }

    if (password.length < 6) {
      throw AuthViewModelException(
        'Password must be at least 6 characters',
        code: 'password-too-short',
      );
    }

    _validateUserRole(role);

    if (phone.trim().isEmpty) {
      throw AuthViewModelException(
        'Phone number cannot be empty',
        code: 'empty-phone',
      );
    }

    if (phone.length > 20) {
      throw AuthViewModelException(
        'Phone number is too long',
        code: 'phone-too-long',
      );
    }

    if (wilaya == null || wilaya.isEmpty) {
      throw AuthViewModelException(
        'Wilaya must be selected',
        code: 'empty-wilaya',
      );
    }

    if (commune == null || commune.isEmpty) {
      throw AuthViewModelException(
        'Commune must be selected',
        code: 'empty-commune',
      );
    }
  }

  /// Validates email format
  ///
  /// Throws: AuthViewModelException on validation failure
  void _validateEmail(String email) {
    if (email.trim().isEmpty) {
      throw AuthViewModelException(
        'Email cannot be empty',
        code: 'empty-email',
      );
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) {
      throw AuthViewModelException(
        'Invalid email address format',
        code: 'invalid-email-format',
      );
    }
  }

  /// Validates user ID
  ///
  /// Throws: AuthViewModelException on validation failure
  void _validateUserId(String uid) {
    if (uid.isEmpty) {
      throw AuthViewModelException(
        'User ID cannot be empty',
        code: 'empty-user-id',
      );
    }

    if (uid.length > 200) {
      throw AuthViewModelException(
        'User ID too long',
        code: 'user-id-too-long',
      );
    }
  }

  /// Validates user role
  ///
  /// Throws: AuthViewModelException if role is invalid
  void _validateUserRole(String role) {
    const validRoles = ['client', 'provider', 'admin'];

    if (role.isEmpty) {
      throw AuthViewModelException(
        'Role cannot be empty',
        code: 'empty-role',
      );
    }

    if (!validRoles.contains(role.toLowerCase())) {
      throw AuthViewModelException(
        'Invalid role: $role. Must be one of: ${validRoles.join(", ")}',
        code: 'invalid-role',
      );
    }
  }

  /// Validates UserModel
  ///
  /// Throws: AuthViewModelException on validation failure
  void _validateUserModel(UserModel user) {
    if (user.uid.isEmpty) {
      throw AuthViewModelException(
        'User ID cannot be empty',
        code: 'empty-user-id',
      );
    }

    if (user.name.isEmpty) {
      throw AuthViewModelException(
        'User name cannot be empty',
        code: 'empty-user-name',
      );
    }

    if (user.email.isEmpty) {
      throw AuthViewModelException(
        'User email cannot be empty',
        code: 'empty-user-email',
      );
    }
  }
}
