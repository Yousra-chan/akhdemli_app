import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _users = 'users';
  final String _codes = 'generated_codes'; // Updated collection name

  String _generateCodeString() {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rand = Random.secure();
    String part(int n) =>
        List.generate(n, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'SUB-${part(4)}-${part(4)}';
  }

  Future<String> generateSubscriptionCode({
    required int months,
    required String assignedEmail,
  }) async {
    final now = DateTime.now();
    final validDays = months * 30;
    final expiresAt = Timestamp.fromDate(now.add(Duration(days: validDays)));
    String code = _generateCodeString();

    final docRef = _firestore.collection(_codes).doc(code);
    await docRef.set({
      'code': code,
      'assignedEmail': assignedEmail.toLowerCase().trim(),
      'duration': months,
      'isUsed': false,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
    });

    return code;
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

  Future<void> deleteCode(String codeId) async {
    await _firestore.collection(_codes).doc(codeId).delete();
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

  Future<bool> activateSubscription({
    required String email,
    required String code,
  }) async {
    final codeRef = _firestore.collection(_codes).doc(code);
    final userQuery = _firestore.collection(_users).where('email', isEqualTo: email.toLowerCase().trim()).limit(1);

    return _firestore.runTransaction((tx) async {
      final codeSnap = await tx.get(codeRef);
      if (!codeSnap.exists) throw Exception('Code not found');
      final codeData = codeSnap.data() as Map<String, dynamic>;

      final isUsed = codeData['isUsed'] ?? false;
      final expiresAt = codeData['expiresAt'] as Timestamp?;
      final assignedEmail = codeData['assignedEmail'] as String?;

      if (isUsed) throw Exception('Code already used');
      if (expiresAt == null || expiresAt.toDate().isBefore(DateTime.now())) {
        throw Exception('Code expired');
      }

      // STRICT VALIDATION: Must match assignedEmail
      if (assignedEmail != email.toLowerCase().trim()) {
        throw Exception('This code was not generated for your account');
      }

      final userSnap = await userQuery.get();
      if (userSnap.docs.isEmpty) throw Exception('User not found');
      final userRef = userSnap.docs.first.reference;

      tx.update(userRef, {
        'subscriptionActive': true,
        'subscriptionExpiresAt': expiresAt,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(codeRef, {
        'isUsed': true,
        'usedAt': FieldValue.serverTimestamp(),
      });

      return true;
    }).catchError((e) {
      throw e;
    });
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
}
