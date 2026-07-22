import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../Services/subscription_service.dart';
import '../Services/notification_service.dart';
import '../models/CategoryModel.dart';
import '../models/UserModel.dart';
import '../models/ServicesModel.dart';

class AdminViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final SubscriptionService _subService = SubscriptionService();
  final NotificationService _notifService = NotificationService();
  final ImagePicker _picker = ImagePicker();

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

  // Services
  List<Service> paginatedServices = [];
  DocumentSnapshot? _lastServiceDoc;
  bool _hasMoreServices = true;
  bool _isLoadingMoreServices = false;
  String _serviceSearchQuery = '';
  String? _serviceStatusFilter;
  String? _serviceCategoryFilter;
  String? _serviceSubcategoryFilter;
  String _serviceSortField = 'createdAt';
  bool _serviceSortDescending = true;
  Set<String> selectedServiceIds = {};

  bool get hasMoreServices => _hasMoreServices;
  bool get isLoadingMoreServices => _isLoadingMoreServices;

  bool get serviceFiltersAreActive => 
    _serviceSearchQuery.isNotEmpty || 
    (_serviceStatusFilter != null && _serviceStatusFilter != 'all') || 
    (_serviceCategoryFilter != null && _serviceCategoryFilter != 'all');

  void clearAllServiceFilters() {
    _serviceSearchQuery = '';
    _serviceStatusFilter = 'all';
    _serviceCategoryFilter = 'all';
    _serviceSubcategoryFilter = 'all';
    _serviceSortField = 'createdAt';
    _serviceSortDescending = true;
    fetchServices(isRefresh: true);
  }

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
      await fetchServices(isRefresh: true);
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

  // --- IMAGE UPLOAD ---
  Future<String?> pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 30, // Higher compression
      maxWidth: 800,    // Resize down
      maxHeight: 800,
    );
    if (image == null) return null;
    
    final bytes = await image.readAsBytes();
    // Check if image is too large for Firestore (max 1MB)
    if (bytes.length > 800000) {
      // If still too large, we can't save it as Base64 safely
      debugPrint('Image too large even after compression: ${bytes.length} bytes');
    }

    final base64Image = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64Image';
  }

  Future<void> deleteImage(String url) async {
    // If it's a base64 string, nothing to delete from storage
    if (url.startsWith('data:image')) return;
    
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }

  // --- CATEGORIES MANAGEMENT ---
  Future<void> addCategory(CategoryModel category, {String? localImagePath}) async {
    // localImagePath here is actually the base64 string if coming from pickImage
    String? imageUrl = localImagePath ?? category.iconUrl;
    
    final docRef = await _db.collection('categories').add(category.copyWith(iconUrl: imageUrl).toMap());
    
    // Add subcategories if any
    for (var sub in category.subcategories) {
      await _db.collection('categories').doc(docRef.id).collection('subcategories').add(
        sub.copyWith(categoryId: docRef.id).toMap()
      );
    }
    await refreshCategories();
  }

  Future<void> updateCategory(CategoryModel category, {String? localImagePath}) async {
    // localImagePath is the base64 string
    String? imageUrl = localImagePath ?? category.iconUrl;

    await _db.collection('categories').doc(category.id).update(
      category.copyWith(iconUrl: imageUrl).toMap()
    );
    
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
    // Also delete images
    final doc = await _db.collection('categories').doc(id).get();
    final data = doc.data();
    if (data?['iconUrl'] != null) await deleteImage(data!['iconUrl']);

    // Also delete subcategories and their images
    final subs = await _db.collection('categories').doc(id).collection('subcategories').get();
    for (var subDoc in subs.docs) {
      final subData = subDoc.data();
      if (subData['imageUrl'] != null) await deleteImage(subData['imageUrl']);
      await subDoc.reference.delete();
    }
    await _db.collection('categories').doc(id).delete();
    await refreshCategories();
  }

  Future<void> addSubcategory(String categoryId, SubcategoryModel sub, {String? localImagePath}) async {
    String? imageUrl = localImagePath ?? sub.imageUrl;
    await _db.collection('categories').doc(categoryId).collection('subcategories').add(
      sub.copyWith(categoryId: categoryId, imageUrl: imageUrl).toMap()
    );
    await refreshCategories();
  }

  Future<void> updateSubcategory(String categoryId, SubcategoryModel sub, {String? localImagePath}) async {
    String? imageUrl = localImagePath ?? sub.imageUrl;

    await _db.collection('categories').doc(categoryId).collection('subcategories').doc(sub.id).update(
      sub.copyWith(categoryId: categoryId, imageUrl: imageUrl).toMap()
    );
    await refreshCategories();
  }

  Future<void> deleteSubcategory(String categoryId, String subId) async {
    final doc = await _db.collection('categories').doc(categoryId).collection('subcategories').doc(subId).get();
    final data = doc.data();
    if (data?['imageUrl'] != null) await deleteImage(data!['imageUrl']);

    await _db.collection('categories').doc(categoryId).collection('subcategories').doc(subId).delete();
    await refreshCategories();
  }

  // --- USER MANAGEMENT ---
  Future<void> updateUserStatus(String uid, {bool? isSuspended, bool? isBanned, String? role}) async {
    final Map<String, dynamic> updates = {};
    if (isSuspended != null) updates['isSuspended'] = isSuspended;
    if (isBanned != null) updates['isBanned'] = isBanned;
    if (role != null) {
      updates['role'] = role;
      updates['isAdmin'] = role == 'admin';
    }
    
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

  Future<UserModel?> findUser(String query) async {
    final search = query.trim();
    if (search.isEmpty) return null;

    final isEmail = search.contains('@');

    try {
      if (isEmail) {
        final snap = await _db
            .collection('users')
            .where('email', isEqualTo: search.toLowerCase())
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          return UserModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
        }
      } else {
        // Try as UID
        final doc = await _db.collection('users').doc(search).get();
        if (doc.exists) {
          return UserModel.fromMap(doc.data()!, doc.id);
        }

        // If not found by UID, maybe it's an email without @ (unlikely but possible search)
        // or just search by name? The requirement said UID or Email.
      }
    } catch (e) {
      debugPrint('Error searching for user: $e');
    }
    return null;
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

  // --- SERVICE MANAGEMENT (ENHANCED) ---
  Future<void> fetchServices({bool isRefresh = false}) async {
    if (isRefresh) {
      _lastServiceDoc = null;
      _hasMoreServices = true;
      paginatedServices = [];
    }

    if (!_hasMoreServices) return;
    if (_isLoadingMoreServices && !isRefresh) return;

    if (!isRefresh) {
      _isLoadingMoreServices = true;
      notifyListeners();
    }

    try {
      Query query = _db.collection('services');

      if (_serviceStatusFilter != null && _serviceStatusFilter != 'all') {
        query = query.where('isActive', isEqualTo: _serviceStatusFilter == 'active');
      }

      if (_serviceCategoryFilter != null) {
        query = query.where('category', isEqualTo: _serviceCategoryFilter);
      }

      if (_serviceSubcategoryFilter != null) {
        query = query.where('subcategory', isEqualTo: _serviceSubcategoryFilter);
      }

      // Sorting
      query = query.orderBy(_serviceSortField, descending: _serviceSortDescending);

      if (_lastServiceDoc != null) {
        query = query.startAfterDocument(_lastServiceDoc!);
      }

      final snapshot = await query.limit(20).get();
      
      final List<Service> newServices = snapshot.docs.map((d) => Service.fromFirestore(d)).toList();

      // Client-side search if needed (Firestore doesn't support partial match well without extra setup)
      // For now, let's assume search is handled by query or simple contains if small dataset
      // If search query is present, we might need a different approach or filter locally
      List<Service> filtered = newServices;
      if (_serviceSearchQuery.isNotEmpty) {
        final q = _serviceSearchQuery.toLowerCase();
        filtered = newServices.where((s) => s.title.toLowerCase().contains(q) || s.category.toLowerCase().contains(q) || s.subcategory.toLowerCase().contains(q)).toList();
      }

      if (isRefresh) {
        paginatedServices = filtered;
      } else {
        paginatedServices.addAll(filtered);
      }

      if (snapshot.docs.isNotEmpty) {
        _lastServiceDoc = snapshot.docs.last;
      }

      _hasMoreServices = snapshot.docs.length == 20;
    } catch (e) {
      debugPrint('Error fetching services: $e');
    } finally {
      _isLoadingMoreServices = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreServices() async {
    await fetchServices(isRefresh: false);
  }

  void setServiceFilters({String? status, String? category, String? subcategory, String? sortField, bool? descending, String? search}) {
    if (status != null) _serviceStatusFilter = status;
    if (category != null) {
      _serviceCategoryFilter = category == 'all' ? null : category;
      _serviceSubcategoryFilter = null; // Reset sub when category changes
    }
    if (subcategory != null) _serviceSubcategoryFilter = subcategory == 'all' ? null : subcategory;
    if (sortField != null) _serviceSortField = sortField;
    if (descending != null) _serviceSortDescending = descending;
    if (search != null) _serviceSearchQuery = search;
    
    fetchServices(isRefresh: true);
  }

  void toggleServiceSelection(String serviceId) {
    if (selectedServiceIds.contains(serviceId)) {
      selectedServiceIds.remove(serviceId);
    } else {
      selectedServiceIds.add(serviceId);
    }
    notifyListeners();
  }

  void clearServiceSelection() {
    selectedServiceIds.clear();
    notifyListeners();
  }

  Future<void> batchUpdateServicesStatus(bool isActive) async {
    if (selectedServiceIds.isEmpty) return;
    _isLoading = true;
    notifyListeners();

    try {
      final batch = _db.batch();
      for (var id in selectedServiceIds) {
        batch.update(_db.collection('services').doc(id), {'isActive': isActive, 'updatedAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
      await fetchServices(isRefresh: true);
      clearServiceSelection();
    } catch (e) {
      debugPrint('Error batch updating services: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> batchDeleteServices() async {
    if (selectedServiceIds.isEmpty) return;
    _isLoading = true;
    notifyListeners();

    try {
      final batch = _db.batch();
      for (var id in selectedServiceIds) {
        batch.delete(_db.collection('services').doc(id));
      }
      await batch.commit();
      await fetchServices(isRefresh: true);
      clearServiceSelection();
    } catch (e) {
      debugPrint('Error batch deleting services: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> duplicateService(Service service) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = service.toMap();
      data.remove('id');
      data['title'] = '${service.title} (Copy)';
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['isActive'] = false; // Duplicated service starts as inactive

      await _db.collection('services').add(data);
      await fetchServices(isRefresh: true);
    } catch (e) {
      debugPrint('Error duplicating service: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
