import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Services/subscription_service.dart';

class SubscriptionCodeViewModel extends ChangeNotifier {
  final SubscriptionService _service = SubscriptionService();
  final String adminId;

  SubscriptionCodeViewModel({required this.adminId}) {
    loadStats();
    loadCodes();
  }

  // --- STATE ---
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  List<Map<String, dynamic>> codes = [];
  DocumentSnapshot? _lastDocument;

  // Stats
  Map<String, int> stats = {
    'total': 0,
    'used': 0,
    'active': 0,
    'expired': 0,
    'activated': 0,
  };

  // Selection
  Set<String> selectedCodes = {};
  bool get isMultiSelectMode => selectedCodes.isNotEmpty;

  // Filters & Sorting
  String? statusFilter;
  String sortField = 'createdAt';
  bool descending = true;
  String searchQuery = '';

  // Analytics
  List<Map<String, dynamic>> redemptionHistory = [];
  List<Map<String, dynamic>> expiringSoon = [];

  // --- METHODS ---

  Future<void> loadStats() async {
    try {
      stats = await _service.getSubscriptionStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> loadCodes({bool refresh = true}) async {
    if (refresh) {
      _isLoading = true;
      codes = [];
      _lastDocument = null;
      _hasMore = true;
      selectedCodes.clear();
    } else {
      if (!_hasMore || _isLoadingMore) return;
      _isLoadingMore = true;
    }
    notifyListeners();

    try {
      final snap = await _service.getSubscriptionCodesQuery(
        limit: 20,
        startAfter: _lastDocument,
        statusFilter: statusFilter,
        sortField: sortField,
        descending: descending,
        searchQuery: searchQuery,
      );

      final newCodes = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        data['id'] = d.id;
        return data;
      }).toList();

      if (refresh) {
        codes = newCodes;
      } else {
        codes.addAll(newCodes);
      }

      _hasMore = snap.docs.length == 20;
      if (snap.docs.isNotEmpty) {
        _lastDocument = snap.docs.last;
      }
    } catch (e) {
      debugPrint('Error loading codes: $e');
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> generateCode(String email, int months) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.generateSubscriptionCode(
        months: months,
        assignedEmail: email,
        createdByAdminId: adminId,
      );
      await loadStats();
      await loadCodes(refresh: true);
    } catch (e) {
      debugPrint('Error generating code: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleSelection(String codeId) {
    if (selectedCodes.contains(codeId)) {
      selectedCodes.remove(codeId);
    } else {
      selectedCodes.add(codeId);
    }
    notifyListeners();
  }

  void clearSelection() {
    selectedCodes.clear();
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    if (selectedCodes.isEmpty) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _service.batchDeleteCodes(selectedCodes.toList(), adminId);
      await loadStats();
      await loadCodes(refresh: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStatusSelected(bool isEnabled) async {
    if (selectedCodes.isEmpty) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _service.batchUpdateStatus(selectedCodes.toList(), isEnabled, adminId);
      await loadCodes(refresh: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSingle(String codeId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.deleteCode(codeId, adminId);
      await loadStats();
      await loadCodes(refresh: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String? status) {
    statusFilter = status;
    loadCodes(refresh: true);
  }

  void setSort(String field, bool desc) {
    sortField = field;
    descending = desc;
    loadCodes(refresh: true);
  }

  void search(String query) {
    searchQuery = query;
    loadCodes(refresh: true);
  }

  Future<void> loadAnalytics() async {
    _isLoading = true;
    notifyListeners();
    try {
      redemptionHistory = await _service.getRedemptionAnalytics();
      expiringSoon = await _service.getExpiringSoonCodes();
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String getSelectedCodesCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Code,Email,Duration,ExpiresAt,Status');
    for (var codeId in selectedCodes) {
      final data = codes.firstWhere((c) => c['id'] == codeId);
      final status = (data['isUsed'] ?? false) ? 'Used' : (data['isEnabled'] ?? true ? 'Active' : 'Disabled');
      buffer.writeln('${data['code']},${data['assignedEmail']},${data['duration']},${data['expiresAt'].toDate()}, $status');
    }
    return buffer.toString();
  }

  void copySelectedToClipboard() {
    final csv = getSelectedCodesCsv();
    Clipboard.setData(ClipboardData(text: csv));
  }
}
