import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../Services/subscription_service.dart';
import '../Services/notification_service.dart';
import '../models/CategoryModel.dart';

class AdminViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SubscriptionService _subService = SubscriptionService();
  final NotificationService _notifService = NotificationService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Real-time Stats
  int totalUsers = 0;

  List<Map<String, dynamic>> subscriptionCodes = [];
  List<CategoryModel> categories = [];
  
  StreamSubscription? _usersSubscription;
  StreamSubscription? _categoriesSubscription;

  AdminViewModel() {
    init();
  }

  Future<void> init() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      // Setup Real-time listeners
      _setupListeners();
      await fetchCodes();
    } catch (e) {
      debugPrint('Error during admin init: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupListeners() {
    _usersSubscription?.cancel();
    _usersSubscription = _db.collection('users').snapshots().listen((snapshot) {
      totalUsers = snapshot.docs.length;
      notifyListeners();
    });

    _categoriesSubscription?.cancel();
    _categoriesSubscription = _db.collection('categories').snapshots().listen((snapshot) {
      _loadCategoriesWithSubcategories();
    });
  }

  Future<void> _loadCategoriesWithSubcategories() async {
    try {
      final snapshot = await _db.collection('categories').get();
      final List<CategoryModel> fetchedCategories = [];
      
      for (var doc in snapshot.docs) {
        final category = CategoryModel.fromFirestore(doc);
        
        // Fetch subcategories
        final subsSnapshot = await _db.collection('categories').doc(doc.id).collection('subcategories').get();
        final subcategories = subsSnapshot.docs.map((d) => SubcategoryModel.fromMap(d.data(), d.id)).toList();
        
        fetchedCategories.add(category.copyWith(subcategories: subcategories));
      }
      categories = fetchedCategories;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading categories hierarchy: $e');
    }
  }

  Future<void> refreshCategories() async {
    await _loadCategoriesWithSubcategories();
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    _categoriesSubscription?.cancel();
    super.dispose();
  }

  // --- CATEGORIES MANAGEMENT ---
  Future<void> addCategory(CategoryModel category) async {
    final docRef = await _db.collection('categories').add(category.toMap());
    
    // Add subcategories if any
    for (var sub in category.subcategories) {
      await _db.collection('categories').doc(docRef.id).collection('subcategories').add(
        sub.copyWith(categoryId: docRef.id).toMap()
      );
    }
    await refreshCategories();
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _db.collection('categories').doc(category.id).update(category.toMap());
    
    // Sync subcategories from the model if any
    for (var sub in category.subcategories) {
      if (sub.id.isEmpty) {
        await addSubcategory(category.id, sub);
      } else {
        await updateSubcategory(category.id, sub);
      }
    }
    await refreshCategories();
  }

  Future<void> deleteCategory(String id) async {
    // Also delete subcategories
    final subs = await _db.collection('categories').doc(id).collection('subcategories').get();
    for (var doc in subs.docs) {
      await doc.reference.delete();
    }
    await _db.collection('categories').doc(id).delete();
    await refreshCategories();
  }

  Future<void> addSubcategory(String categoryId, SubcategoryModel sub) async {
    await _db.collection('categories').doc(categoryId).collection('subcategories').add(
      sub.copyWith(categoryId: categoryId).toMap()
    );
    await refreshCategories();
  }

  Future<void> updateSubcategory(String categoryId, SubcategoryModel sub) async {
    await _db.collection('categories').doc(categoryId).collection('subcategories').doc(sub.id).update(
      sub.copyWith(categoryId: categoryId).toMap()
    );
    await refreshCategories();
  }

  Future<void> deleteSubcategory(String categoryId, String subId) async {
    await _db.collection('categories').doc(categoryId).collection('subcategories').doc(subId).delete();
    await refreshCategories();
  }

  // --- USER MANAGEMENT ---
  Future<void> updateUserStatus(String uid, {bool? isSuspended, bool? isBanned, String? role}) async {
    final Map<String, dynamic> updates = {};
    if (isSuspended != null) updates['isSuspended'] = isSuspended;
    if (isBanned != null) updates['isBanned'] = isBanned;
    if (role != null) updates['role'] = role;
    
    await _db.collection('users').doc(uid).update(updates);
  }

  Future<void> deleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  // --- SERVICE MANAGEMENT ---
  Future<void> updateServiceStatus(String serviceId, {bool? isActive, String? status}) async {
    final Map<String, dynamic> updates = {};
    if (isActive != null) updates['isActive'] = isActive;
    if (status != null) updates['status'] = status;
    
    await _db.collection('services').doc(serviceId).update(updates);
  }

  Future<void> toggleFeaturedService(String serviceId, bool isFeatured) async {
    await _db.collection('services').doc(serviceId).update({'isFeatured': isFeatured});
  }

  Future<void> deleteService(String serviceId) async {
    await _db.collection('services').doc(serviceId).delete();
  }

  // --- REPORT MANAGEMENT ---
  Future<void> resolveReport(String reportId) async {
    await _db.collection('reports').doc(reportId).update({'status': 'resolved'});
  }

  Future<void> ignoreReport(String reportId) async {
    await _db.collection('reports').doc(reportId).update({'status': 'ignored'});
  }

  // --- NOTIFICATIONS ---
  Future<void> broadcastNotification({
    required String title,
    required String body,
    String? targetRole,
    String? specificUserId,
  }) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      List<String> userIds = [];
      if (specificUserId != null) {
        userIds = [specificUserId];
      } else {
        Query query = _db.collection('users');
        if (targetRole != null && targetRole != 'all') {
          query = query.where('role', isEqualTo: targetRole);
        }
        final snapshot = await query.get();
        userIds = snapshot.docs.map((d) => d.id).toList();
      }

      for (var uid in userIds) {
        await _notifService.sendBookingNotification(
          receiverUserId: uid,
          bookingId: 'admin_broadcast',
          title: title,
          body: body,
          status: 'info',
        );
      }
    } catch (e) {
      debugPrint('Error broadcasting: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- SUBSCRIPTION CODES ---
  Future<void> fetchCodes() async {
    try {
      subscriptionCodes = await _subService.getSubscriptionCodes();
      notifyListeners();
    } catch (e) {
      debugPrint('Error codes: $e');
    }
  }

  Future<String> generateNewCode({required String email, required int months}) async {
    final code = await _subService.generateSubscriptionCode(
      assignedEmail: email,
      months: months,
    );
    await fetchCodes();
    return code;
  }

  Future<void> deleteCode(String codeId) async {
    await _subService.deleteCode(codeId);
    await fetchCodes();
  }
}
