import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _users = 'users';
  final String _codes = 'generated_codes';
  final String _auditLogs = 'admin_audit_logs';

  String _generateCodeString() {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rand = Random.secure();
    String part(int n) =>
        List.generate(n, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'SUB-${part(4)}-${part(4)}';
  }

  Future<void> _logAction({
    required String adminId,
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _firestore.collection(_auditLogs).add({
        'adminId': adminId,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Audit log failed: $e');
    }
  }

  Future<String> generateSubscriptionCode({
    required int months,
    required String assignedEmail,
    required String createdByAdminId,
  }) async {
    final now = DateTime.now();
    final validDays = months * 30;
    final expiresAt = Timestamp.fromDate(now.add(Duration(days: validDays)));
    String code = _generateCodeString();

    final docRef = _firestore.collection(_codes).doc(code);
    
    // Prevent duplicate codes by checking existence
    final existing = await docRef.get();
    if (existing.exists) {
      return generateSubscriptionCode(
        months: months,
        assignedEmail: assignedEmail,
        createdByAdminId: createdByAdminId,
      );
    }

    final data = {
      'code': code,
      'assignedEmail': assignedEmail.toLowerCase().trim(),
      'duration': months,
      'isUsed': false,
      'isEnabled': true,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdByAdminId,
      'expiresAt': expiresAt,
      'usedAt': null,
      'usedBy': null,
    };

    await docRef.set(data);
    
    await _logAction(
      adminId: createdByAdminId,
      action: 'generate_code',
      targetType: 'subscription_code',
      targetId: code,
      details: {'email': assignedEmail, 'months': months},
    );

    return code;
  }

  Future<QuerySnapshot> getSubscriptionCodesQuery({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? statusFilter, // 'active', 'used', 'expired'
    String? sortField = 'createdAt',
    bool descending = true,
    String? searchQuery,
  }) async {
    Query query = _firestore.collection(_codes);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Note: Search by exact code or assignedEmail (limited search capability without Algolia/etc)
      query = query.where('assignedEmail', isEqualTo: searchQuery.toLowerCase().trim());
    }

    if (statusFilter != null) {
      final now = Timestamp.now();
      if (statusFilter == 'used') {
        query = query.where('isUsed', isEqualTo: true);
      } else if (statusFilter == 'active') {
        query = query.where('isUsed', isEqualTo: false)
                     .where('isEnabled', isEqualTo: true)
                     .where('expiresAt', isGreaterThan: now);
      } else if (statusFilter == 'expired') {
        query = query.where('isUsed', isEqualTo: false)
                     .where('expiresAt', isLessThanOrEqualTo: now);
      }
    }

    query = query.orderBy(sortField ?? 'createdAt', descending: descending);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.limit(limit).get();
  }

  Future<Map<String, int>> getSubscriptionStats() async {
    final now = Timestamp.now();
    
    try {
      final allCount = await _firestore.collection(_codes).count().get()
          .then((v) => v.count ?? 0)
          .catchError((e) {
            print('Total codes count failed: $e');
            return 0;
          });
          
      final usedCount = await _firestore.collection(_codes).where('isUsed', isEqualTo: true).count().get()
          .then((v) => v.count ?? 0)
          .catchError((e) {
            print('Used codes count failed: $e');
            return 0;
          });
      
      int activeCount = 0;
      try {
        final active = await _firestore.collection(_codes)
            .where('isUsed', isEqualTo: false)
            .where('isEnabled', isEqualTo: true)
            .where('expiresAt', isGreaterThan: now)
            .count().get();
        activeCount = active.count ?? 0;
      } catch (e) {
        print('Active codes count failed (likely missing index): $e');
        activeCount = 0; // Fallback
      }

      int expiredCount = 0;
      try {
        final expired = await _firestore.collection(_codes)
            .where('isUsed', isEqualTo: false)
            .where('expiresAt', isLessThanOrEqualTo: now)
            .count().get();
        expiredCount = expired.count ?? 0;
      } catch (e) {
        print('Expired codes count failed (likely missing index): $e');
        expiredCount = 0; // Fallback
      }
          
      return {
        'total': allCount,
        'used': usedCount,
        'active': activeCount,
        'expired': expiredCount,
        'activated': usedCount,
      };
    } catch (e) {
      print('General stats fetch failed: $e');
      return {
        'total': 0, 'used': 0, 'active': 0, 'expired': 0, 'activated': 0,
      };
    }
  }

  Future<void> updateCodeStatus(String code, bool isEnabled, String adminId) async {
    await _firestore.collection(_codes).doc(code).update({'isEnabled': isEnabled});
    await _logAction(
      adminId: adminId,
      action: isEnabled ? 'enable_code' : 'disable_code',
      targetType: 'subscription_code',
      targetId: code,
    );
  }

  Future<void> deleteCode(String codeId, String adminId) async {
    await _firestore.collection(_codes).doc(codeId).delete();
    await _logAction(
      adminId: adminId,
      action: 'delete_code',
      targetType: 'subscription_code',
      targetId: codeId,
    );
  }

  Future<void> batchDeleteCodes(List<String> codes, String adminId) async {
    final batch = _firestore.batch();
    for (var code in codes) {
      batch.delete(_firestore.collection(_codes).doc(code));
    }
    await batch.commit();
    await _logAction(
      adminId: adminId,
      action: 'batch_delete_codes',
      targetType: 'subscription_code',
      targetId: 'multiple',
      details: {'count': codes.length, 'codes': codes},
    );
  }

  Future<void> batchUpdateStatus(List<String> codes, bool isEnabled, String adminId) async {
    final batch = _firestore.batch();
    for (var code in codes) {
      batch.update(_firestore.collection(_codes).doc(code), {'isEnabled': isEnabled});
    }
    await batch.commit();
    await _logAction(
      adminId: adminId,
      action: isEnabled ? 'batch_enable_codes' : 'batch_disable_codes',
      targetType: 'subscription_code',
      targetId: 'multiple',
      details: {'count': codes.length, 'codes': codes},
    );
  }

  Future<bool> activateSubscription({
    required String userId,
    required String email,
    required String code,
  }) async {
    final codeRef = _firestore.collection(_codes).doc(code);
    final userRef = _firestore.collection(_users).doc(userId);

    return _firestore.runTransaction((tx) async {
      final codeSnap = await tx.get(codeRef);
      if (!codeSnap.exists) throw Exception('Code not found');
      final codeData = codeSnap.data() as Map<String, dynamic>;

      final isUsed = codeData['isUsed'] ?? false;
      final isEnabled = codeData['isEnabled'] ?? true;
      final expiresAt = codeData['expiresAt'] as Timestamp?;
      final assignedEmail = codeData['assignedEmail'] as String?;

      if (isUsed) throw Exception('Code already used');
      if (!isEnabled) throw Exception('Code is disabled by administrator');
      if (expiresAt == null || expiresAt.toDate().isBefore(DateTime.now())) {
        throw Exception('Code expired');
      }

      if (assignedEmail != email.toLowerCase().trim()) {
        throw Exception('This code was not generated for your account');
      }

      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw Exception('User not found');

      tx.update(userRef, {
        'subscriptionActive': true,
        'subscriptionExpiresAt': expiresAt,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(codeRef, {
        'isUsed': true,
        'usedAt': FieldValue.serverTimestamp(),
        'usedBy': email.toLowerCase().trim(),
      });

      return true;
    });
  }

  Future<List<Map<String, dynamic>>> getRedemptionAnalytics({int days = 30}) async {
    try {
      final threshold = Timestamp.fromDate(DateTime.now().subtract(Duration(days: days)));
      // Note: threshold filter on usedAt implies isUsed is true since usedAt is null for unused codes.
      // Removing 'isUsed' filter to potentially avoid composite index requirement.
      final snap = await _firestore.collection(_codes)
          .where('usedAt', isGreaterThan: threshold)
          .orderBy('usedAt', descending: true)
          .get();
          
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('Redemption analytics failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getExpiringSoonCodes({int days = 7}) async {
    try {
      final now = Timestamp.now();
      final threshold = Timestamp.fromDate(DateTime.now().add(Duration(days: days)));
      
      final snap = await _firestore.collection(_codes)
          .where('isUsed', isEqualTo: false)
          .where('expiresAt', isGreaterThan: now)
          .where('expiresAt', isLessThanOrEqualTo: threshold)
          .orderBy('expiresAt')
          .limit(20)
          .get();
          
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('Expiring soon codes fetch failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSubscriptionCodes({int limit = 100}) async {
    final snap = await _firestore
        .collection(_codes)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snap = await _firestore.collection(_users).get();
    return snap.docs.map((d) {
      final data = d.data();
      data['uid'] = d.id;
      return data;
    }).toList();
  }

  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    final snap = await _firestore
        .collection(_users)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    data['uid'] = snap.docs.first.id;
    return data;
  }

  Future<void> checkAndUpdateExpiryForProvider(String userId) async {
    final ref = _firestore.collection(_users).doc(userId);
    final doc = await ref.get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final expiry = data['subscriptionExpiresAt'] ?? data['subscriptionExpiry'];
    if (expiry == null) return;
    final expiryTs = expiry is Timestamp ? expiry : null;
    if (expiryTs != null && expiryTs.toDate().isBefore(DateTime.now())) {
      await ref.update({'subscriptionActive': false});
    }
  }

  Future<void> deleteAllCodes({bool onlyUsed = false}) async {
    Query query = _firestore.collection(_codes);
    if (onlyUsed) {
      query = query.where('isUsed', isEqualTo: true);
    }
    final snap = await query.get();
    final batch = _firestore.batch();
    for (var doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
