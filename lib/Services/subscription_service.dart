import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _users = 'users';
  final String _codes = 'subscription_codes';

  String _generateCodeString() {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rand = Random.secure();
    String part(int n) =>
        List.generate(n, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'SUB-${part(4)}-${part(4)}';
  }

  Future<String> generateSubscriptionCode(
      {int validDays = 30, String? providerId, String? note}) async {
    final now = DateTime.now();
    final validUntil = Timestamp.fromDate(now.add(Duration(days: validDays)));
    String code = _generateCodeString();

    final docRef = _firestore.collection(_codes).doc(code);
    await docRef.set({
      'code': code,
      'providerId': providerId,
      'used': false,
      'createdAt': FieldValue.serverTimestamp(),
      'validUntil': validUntil,
      'validDays': validDays,
      if (note != null) 'note': note,
    });

    return code;
  }

  Future<List<Map<String, dynamic>>> getSubscriptionCodes(
      {int limit = 100}) async {
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

  Future<void> deleteCode(String code) async {
    await _firestore.collection(_codes).doc(code).delete();
  }

  Future<bool> activateSubscription(
      {required String providerId, required String code}) async {
    final codeRef = _firestore.collection(_codes).doc(code);
    final userRef = _firestore.collection(_users).doc(providerId);

    return _firestore.runTransaction((tx) async {
      final codeSnap = await tx.get(codeRef);
      if (!codeSnap.exists) throw Exception('Code not found');
      final codeData = codeSnap.data() as Map<String, dynamic>;

      final used = codeData['used'] ?? false;
      final validUntil = codeData['validUntil'] as Timestamp?;
      final assignedTo = codeData['providerId'] as String?;

      if (used) throw Exception('Code already used');
      if (validUntil == null || validUntil.toDate().isBefore(DateTime.now()))
        throw Exception('Code expired');

      // Only check if code was assigned to a specific user
      // No role validation - any user can activate if code matches
      if (assignedTo != null &&
          assignedTo.isNotEmpty &&
          assignedTo != providerId) {
        throw Exception('This code was not generated for your account');
      }

      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw Exception('User not found');

      // Update user subscription - no role requirement
      tx.update(userRef, {
        'subscriptionActive': true,
        'subscriptionExpiresAt': validUntil,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(codeRef, {
        'used': true,
        'usedBy': providerId,
        'usedAt': FieldValue.serverTimestamp(),
      });

      return true;
    }).catchError((e) {
      return Future.error(e);
    });
  }

  Future<void> checkAndUpdateExpiryForProvider(String providerId) async {
    final ref = _firestore.collection(_users).doc(providerId);
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

  Future<void> checkAndUpdateAllExpired() async {
    final now = Timestamp.fromDate(DateTime.now());
    final q = await _firestore
        .collection(_users)
        .where('subscriptionActive', isEqualTo: true)
        .get();
    final batch = _firestore.batch();
    for (final d in q.docs) {
      final data = d.data();
      final expiry =
          data['subscriptionExpiresAt'] ?? data['subscriptionExpiry'];
      if (expiry is Timestamp && expiry.compareTo(now) <= 0) {
        batch.update(d.reference, {'subscriptionActive': false});
      }
    }
    await batch.commit();
  }
}