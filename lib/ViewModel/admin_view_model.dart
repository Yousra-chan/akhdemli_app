import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  List<Map<String, dynamic>> paginatedCodes = [];
  DocumentSnapshot? _lastCodeDoc;
  bool _hasMoreCodes = true;
  bool _isLoadingMoreCodes = false;
  
  bool get hasMoreCodes => _hasMoreCodes;
  bool get isLoadingMoreCodes => _isLoadingMoreCodes;

  Map<String, int> codeStats = {
    'total': 0,
    'used': 0,
    'active': 0,
    'expired': 0,
    'activated': 0,
  };

  String _codeSearchQuery = '';
  String? _codeStatusFilter;
  String _codeSortField = 'createdAt';
  bool _codeSortDescending = true;
  Set<String> selectedCodeIds = {};

  List<Map<String, dynamic>> analyticsRedemptions = [];
  List<Map<String, dynamic>> expiringSoonCodes = [];

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
      await fetchCodeStats();
      await fetchCodes(isRefresh: true);
      await fetchAnalytics();
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
  Future<void> fetchCodes({bool isRefresh = false}) async {
    if (isRefresh) {
      _lastCodeDoc = null;
      _hasMoreCodes = true;
      paginatedCodes = [];
    }

    if (!_hasMoreCodes) return;

    try {
      final snapshot = await _subService.getSubscriptionCodesQuery(
        limit: 20,
        startAfter: _lastCodeDoc,
        statusFilter: _codeStatusFilter,
        sortField: _codeSortField,
        descending: _codeSortDescending,
        searchQuery: _codeSearchQuery.isEmpty ? null : _codeSearchQuery,
      );

      final List<Map<String, dynamic>> newCodes = snapshot.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        data['id'] = d.id;
        return data;
      }).toList();

      if (isRefresh) {
        paginatedCodes = newCodes;
        // Also update the simple list for backward compatibility if needed
        subscriptionCodes = newCodes;
      } else {
        paginatedCodes.addAll(newCodes);
      }

      if (snapshot.docs.isNotEmpty) {
        _lastCodeDoc = snapshot.docs.last;
      }

      _hasMoreCodes = newCodes.length == 20;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching paginated codes: $e');
    }
  }

  Future<void> loadMoreCodes() async {
    if (_isLoadingMoreCodes || !_hasMoreCodes) return;
    _isLoadingMoreCodes = true;
    notifyListeners();
    await fetchCodes(isRefresh: false);
    _isLoadingMoreCodes = false;
    notifyListeners();
  }

  Future<void> fetchCodeStats() async {
    try {
      codeStats = await _subService.getSubscriptionStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching code stats: $e');
    }
  }

  Future<void> fetchAnalytics() async {
    try {
      analyticsRedemptions = await _subService.getRedemptionAnalytics();
      expiringSoonCodes = await _subService.getExpiringSoonCodes();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
    }
  }

  void setCodeFilters({String? status, String? sortField, bool? descending, String? search}) {
    if (status != null) _codeStatusFilter = status == 'all' ? null : status;
    if (sortField != null) _codeSortField = sortField;
    if (descending != null) _codeSortDescending = descending;
    if (search != null) _codeSearchQuery = search;
    fetchCodes(isRefresh: true);
  }

  void toggleCodeSelection(String codeId) {
    if (selectedCodeIds.contains(codeId)) {
      selectedCodeIds.remove(codeId);
    } else {
      selectedCodeIds.add(codeId);
    }
    notifyListeners();
  }

  void clearSelection() {
    selectedCodeIds.clear();
    notifyListeners();
  }

  Future<void> batchDeleteSelectedCodes() async {
    if (selectedCodeIds.isEmpty) return;
    final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    await _subService.batchDeleteCodes(selectedCodeIds.toList(), adminId);
    selectedCodeIds.clear();
    await fetchCodes(isRefresh: true);
    await fetchCodeStats();
  }

  Future<void> batchUpdateSelectedCodesStatus(bool isEnabled) async {
    if (selectedCodeIds.isEmpty) return;
    final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    await _subService.batchUpdateStatus(selectedCodeIds.toList(), isEnabled, adminId);
    await fetchCodes(isRefresh: true);
  }

  Future<String> generateNewCode({required String email, required int months}) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final code = await _subService.generateSubscriptionCode(
      assignedEmail: email,
      months: months,
      createdByAdminId: adminId,
    );
    await fetchCodes(isRefresh: true);
    await fetchCodeStats();
    return code;
  }

  Future<void> deleteCode(String codeId) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    await _subService.deleteCode(codeId, adminId);
    await fetchCodes(isRefresh: true);
    await fetchCodeStats();
  }

  Future<void> toggleCodeStatus(String codeId, bool isEnabled) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    await _subService.updateCodeStatus(codeId, isEnabled, adminId);
    // Update local state to avoid full refresh
    final index = paginatedCodes.indexWhere((c) => c['id'] == codeId);
    if (index != -1) {
      paginatedCodes[index]['isEnabled'] = isEnabled;
      notifyListeners();
    }
  }

  Future<void> exportSelectedToCsv() async {
    if (selectedCodeIds.isEmpty) return;
    
    final selectedCodes = paginatedCodes.where((c) => selectedCodeIds.contains(c['id'])).toList();
    
    String csv = 'Code,Assigned Email,Months,Status,Created At,Expires At,Used By,Used At\n';
    for (var c in selectedCodes) {
      final status = (c['isUsed'] ?? false) ? 'Used' : (!(c['isEnabled'] ?? true) ? 'Disabled' : 'Active');
      csv += '${c['code']},${c['assignedEmail']},${c['duration']},$status,${c['createdAt']},${c['expiresAt']},${c['usedBy'] ?? ''},${c['usedAt'] ?? ''}\n';
    }
    
    await Clipboard.setData(ClipboardData(text: csv));
  }
}
