import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/Services/auth_service.dart';
import 'package:service_app/Services/user_service.dart';

class AuthViewModel with ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _initialized = false; // Track initialization status

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _initialized; // New getter

  AuthViewModel() {
    print('🔄 AuthViewModel constructor called');
    _initializeAuthState();
  }

  // ============ PUBLIC AUTH METHODS ============

  Future<UserModel?> login(String email, String password) async {
    return _executeAuthOperation(() async {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return await _fetchAndSetUser(userCredential.user!.uid);
    }, 'Login');
  }

  Future<UserModel?> signInWithGoogle() async {
    return _executeAuthOperation(() async {
      final userModel = await _authService.signInWithGoogle();
      _setUser(userModel);
      return userModel;
    }, 'Google sign-in');
  }

  Future<UserModel?> signInWithApple() async {
    return _executeAuthOperation(() async {
      final userModel = await _authService.signInWithApple();
      _setUser(userModel);
      return userModel;
    }, 'Apple sign-in');
  }

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

  Future<void> logout() async {
    return _executeOperation(() async {
      await _authService.logout();
      _clearUser();
    }, 'Logout');
  }

  Future<void> sendPasswordResetEmail(String email) async {
    return _executeOperation(
      () => _authService.sendPasswordResetEmail(email),
      'Password reset',
    );
  }

  Future<void> updateUserProfile(UserModel updatedUser) async {
    return _executeOperation(() async {
      await _userService.updateUser(updatedUser);
      _currentUser = updatedUser;
      notifyListeners();
    }, 'Profile update');
  }

  // =======================================================
  // 📸 IMAGE HANDLING METHOD
  // =======================================================

  Future<String?> pickImageAndEncode() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxHeight: 400,
      maxWidth: 400,
      imageQuality: 75,
    );

    if (pickedFile == null) {
      return null;
    }

    try {
      final bytes = await File(pickedFile.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      debugPrint('Error encoding image: $e');
      _setError(
          'Failed to encode image for storage. Please try a smaller image.');
      return null;
    }
  }

  // ============ PRIVATE METHODS ============

  Future<void> _initializeAuthState() async {
    print('🔄 AuthViewModel: Starting auth initialization');

    try {
      // 1. Listen to auth state changes FIRST
      _authService.authStateChanges.listen(_handleAuthStateChange);
      print('✅ AuthViewModel: Auth state listener attached');

      // 2. Check for existing user immediately
      final firebaseUser = _authService.getCurrentUser();
      print('🔍 AuthViewModel: Current Firebase user: ${firebaseUser?.uid}');

      if (firebaseUser != null) {
        print('🔄 AuthViewModel: Fetching user data for ${firebaseUser.uid}');
        await _fetchCurrentUser(firebaseUser.uid);
      } else {
        print('ℹ️ AuthViewModel: No Firebase user found on startup');
        _setUser(null);
      }

      _initialized = true;
      print('✅ AuthViewModel: Initialization completed');
      notifyListeners();
    } catch (e) {
      print('❌ AuthViewModel: Error during initialization: $e');
      _setError('Failed to initialize auth state: $e');
      _initialized = true; // Still mark as initialized even on error
      notifyListeners();
    }
  }

  void _handleAuthStateChange(User? firebaseUser) async {
    print(
        '🔄 AuthViewModel: Auth state changed. Firebase user: ${firebaseUser?.uid}');

    if (firebaseUser != null) {
      print('🔄 AuthViewModel: Fetching user data for ${firebaseUser.uid}');
      await _fetchCurrentUser(firebaseUser.uid);
    } else {
      print('ℹ️ AuthViewModel: User signed out or no user');
      _clearUser();
    }
  }

  Future<void> _fetchCurrentUser(String uid) async {
    print('🔄 AuthViewModel: _fetchCurrentUser for uid: $uid');

    try {
      final userModel = await _userService.getUserById(uid);
      if (userModel != null) {
        print(
            '✅ AuthViewModel: UserModel loaded: ${userModel.name} (${userModel.role})');
        _setUser(userModel);
      } else {
        print('❌ AuthViewModel: User profile not found in Firestore');
        _setError('User profile not found');
        // Don't clear user here - Firebase user exists but no Firestore doc
      }
    } catch (e) {
      print('❌ AuthViewModel: Error loading user profile: $e');
      _setError('Failed to load user profile: $e');
    }
  }

  Future<UserModel?> _fetchAndSetUser(String uid) async {
    try {
      final userModel = await _userService.getUserById(uid);
      _setUser(userModel);
      return userModel;
    } catch (e) {
      debugPrint('Warning: Failed to load UserModel profile: $e');
      _setError('User profile not found');
      return null;
    }
  }

  // ============ EXECUTION HELPERS ============

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
    } catch (e) {
      _setError('$operationName failed: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

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
    } catch (e) {
      _setError('$operationName failed: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ============ STATE MANAGEMENT ============

  void _setUser(UserModel? user) {
    print('🔄 AuthViewModel: Setting user: ${user?.uid}');
    _currentUser = user;
    _error = null;
    notifyListeners();
    print('📢 AuthViewModel: notifyListeners() called');
  }

  void _clearUser() {
    print('🔄 AuthViewModel: Clearing user');
    _currentUser = null;
    _error = null;
    notifyListeners();
    print('📢 AuthViewModel: notifyListeners() called');
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ============ ERROR MAPPING ============

  String _getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    const errorMessages = {
      'user-not-found': 'No user found with this email address',
      'wrong-password': 'Incorrect password',
      'invalid-email': 'Invalid email address',
      'user-disabled': 'This account has been disabled',
      'email-already-in-use': 'An account already exists with this email',
      'weak-password': 'Password is too weak',
      'network-request-failed': 'Network error. Please check your connection',
    };

    return errorMessages[e.code] ?? 'Authentication failed: ${e.message}';
  }

  Future<void> updateUserRole(String newRole) async {
    if (_currentUser != null) {
      try {
        print(
            '🔄 [AuthViewModel] Updating user role from ${_currentUser!.role} to $newRole');

        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .update({
          'role': newRole,
          'updatedAt': Timestamp.now(),
        });

        print('✅ [AuthViewModel] Firestore update completed');

        _currentUser = _currentUser!.copyWith(role: newRole);

        print('✅ [AuthViewModel] Local user updated to: ${_currentUser!.role}');
        print('📢 [AuthViewModel] Calling notifyListeners()');

        notifyListeners();

        print('✅ [AuthViewModel] notifyListeners() completed');
      } catch (e) {
        print('❌ [AuthViewModel] Error updating user role: $e');
        rethrow;
      }
    } else {
      print('❌ [AuthViewModel] _currentUser is null - cannot update role');
    }
  }
}
