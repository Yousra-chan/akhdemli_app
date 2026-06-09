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

  // Constants
  static const int _imageSizeMaxHeight = 400;
  static const int _imageSizeMaxWidth = 400;
  static const int _imageQuality = 75;
  static const int _maxImageFileSizeBytes = 5242880; // 5MB

  AuthViewModel() {
    print('🔄 AuthViewModel constructor called');
    _initializeAuthState();
  }

  // ============================================================================
  // PUBLIC AUTH METHODS
  // ============================================================================

  /// Logs in user with email and password
  ///
  /// Parameters:
  /// - email: User email address
  /// - password: User password
  ///
  /// Returns: UserModel if successful, null otherwise
  /// Updates state with error on failure
  Future<UserModel?> login(String email, String password) async {
    return _executeAuthOperation(() async {
      _validateLoginInputs(email, password);

      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final uid = userCredential.user?.uid;
      if (uid == null) {
        throw AuthViewModelException(
          'Failed to retrieve user ID after login',
          code: 'no-user-id',
        );
      }

      return await _fetchAndSetUser(uid);
    }, 'Login');
  }

  /// Signs in user with Google account
  ///
  /// Returns: UserModel if successful, null otherwise
  Future<UserModel?> signInWithGoogle() async {
    return _executeAuthOperation(() async {
      final userModel = await _authService.signInWithGoogle();
      _setUser(userModel);
      return userModel;
    }, 'Google sign-in');
  }

  /// Signs in user with Apple account
  ///
  /// Returns: UserModel if successful, null otherwise
  Future<UserModel?> signInWithApple() async {
    return _executeAuthOperation(() async {
      final userModel = await _authService.signInWithApple();
      _setUser(userModel);
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
    required String address,
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
        address: address,
      );

      final userModel = await _authService.signup(
        name: name,
        email: email,
        password: password,
        role: role,
        phone: phone,
        address: address,
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

      print('✅ Firestore role update completed');

      _currentUser = _currentUser!.copyWith(role: newRole);
      print('✅ Local user updated to: ${_currentUser!.role}');
      notifyListeners();
    }, 'Role update');
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
        print('ℹ️ Image selection cancelled by user');
        return null;
      }

      return await _encodeImageToBase64(pickedFile);
    } catch (e) {
      print('❌ Error picking image: $e');
      _setError('Failed to pick image. Please try again.');
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
      print('❌ Error encoding image: $e');
      _setError('Failed to encode image. Please try a smaller image.');
      rethrow;
    }
  }

  // ============================================================================
  // PRIVATE INITIALIZATION METHODS
  // ============================================================================

  /// Initializes authentication state on app startup
  ///
  /// 1. Attaches auth state listener
  /// 2. Checks for existing Firebase user
  /// 3. Loads user profile from Firestore
  Future<void> _initializeAuthState() async {
    print('🔄 AuthViewModel: Starting auth initialization');

    try {
      // Attach auth state listener
      _authService.authStateChanges.listen(_handleAuthStateChange);
      print('✅ Auth state listener attached');

      // Check for existing Firebase user
      final firebaseUser = _authService.getCurrentUser();
      print('🔍 Current Firebase user: ${firebaseUser?.uid}');

      if (firebaseUser != null) {
        print('🔄 Fetching user data for ${firebaseUser.uid}');
        await _fetchCurrentUser(firebaseUser.uid);
      } else {
        print('ℹ️ No Firebase user found on startup');
        _setUser(null);
      }

      _initialized = true;
      print('✅ Initialization completed');
      notifyListeners();
    } catch (e) {
      print('❌ Error during initialization: $e');
      _setError('Failed to initialize auth state');
      _initialized = true; // Mark as initialized even on error
      notifyListeners();
    }
  }

  /// Handles Firebase authentication state changes
  void _handleAuthStateChange(User? firebaseUser) async {
    print('🔄 Auth state changed. Firebase user: ${firebaseUser?.uid}');

    if (firebaseUser != null) {
      print('🔄 Fetching user profile for ${firebaseUser.uid}');
      await _fetchCurrentUser(firebaseUser.uid);
    } else {
      print('ℹ️ User signed out');
      _clearUser();
    }
  }

  /// Fetches current user profile from Firestore
  ///
  /// Parameters:
  /// - uid: User ID to fetch
  Future<void> _fetchCurrentUser(String uid) async {
    try {
      _validateUserId(uid);

      print('🔄 Fetching user profile for uid: $uid');
      // Ensure subscription expiry is enforced before returning the user
      try {
        final subService = SubscriptionService();
        await subService.checkAndUpdateExpiryForProvider(uid);
      } catch (e) {
        print('❌ Error checking subscription expiry: $e');
      }

      final userModel = await _userService.getUserById(uid);
      if (userModel != null) {
        print('✅ UserModel loaded: ${userModel.name} (${userModel.role})');
        _setUser(userModel);
      } else {
        print('❌ User profile not found in Firestore');
        _setError('User profile not found');
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
      _setError('Failed to load user profile');
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

      final userModel = await _userService.getUserById(uid);
      _setUser(userModel);
      return userModel;
    } catch (e) {
      print('❌ Failed to load user profile: $e');
      _setError('User profile not found');
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
    print('🔄 Setting user: ${user?.uid}');
    _currentUser = user;
    _error = null;
    notifyListeners();
    print('📢 notifyListeners() called');
  }

  /// Clears current user
  void _clearUser() {
    print('🔄 Clearing user');
    _currentUser = null;
    _error = null;
    notifyListeners();
    print('📢 notifyListeners() called');
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
    required String address,
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

    if (address.trim().isEmpty) {
      throw AuthViewModelException(
        'Address cannot be empty',
        code: 'empty-address',
      );
    }

    if (address.length > 200) {
      throw AuthViewModelException(
        'Address is too long (max 200 characters)',
        code: 'address-too-long',
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
