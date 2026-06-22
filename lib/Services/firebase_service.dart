import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/models/NotificationsModel.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  // ==================== CATEGORIES ====================

  static Stream<List<CategoryModel>> getCategories() {
    return _firestore
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((QuerySnapshot snapshot) {
      return snapshot.docs
          .map((DocumentSnapshot doc) => CategoryModel.fromFirestore(doc))
          .toList();
    });
  }

  static Stream<List<SubcategoryModel>> getSubCategories(String categoryId) {
    return _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('subcategories')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((QuerySnapshot snapshot) {
      return snapshot.docs
          .map((DocumentSnapshot doc) => SubcategoryModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  static Future<List<CategoryModel>> getCategoriesList() async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching categories list: $e');
      return [];
    }
  }

  static Future<CategoryModel?> getCategoryByName(String name) async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
          
      if (snapshot.docs.isEmpty) return null;
      return CategoryModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      debugPrint('❌ Error in getCategoryByName: $e');
      return null;
    }
  }

  static Future<SubcategoryModel?> getSubcategoryByName(String categoryId, String subName) async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('subcategories')
          .where('name', isEqualTo: subName)
          .limit(1)
          .get();
          
      if (snapshot.docs.isEmpty) return null;
      return SubcategoryModel.fromMap(snapshot.docs.first.data() as Map<String, dynamic>, snapshot.docs.first.id);
    } catch (e) {
      debugPrint('❌ Error in getSubcategoryByName: $e');
      return null;
    }
  }

  static Future<List<SubcategoryModel>> getSubcategoriesForCategory(
      String categoryId) async {
    try {
      final querySnapshot = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('subcategories')
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => SubcategoryModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching subcategories: $e');
      return [];
    }
  }

  // ==================== PROVIDERS ====================

  static Stream<List<ProviderModel>> getProviders() {
    return _firestore
        .collection('providers')
        .where('subscriptionActive', isEqualTo: true)
        .snapshots()
        .map((QuerySnapshot snapshot) {
      return snapshot.docs.map((doc) {
        return ProviderModel.fromFirestore(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // ==================== NOTIFICATIONS ====================

  static Stream<List<NotificationItem>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((QuerySnapshot snapshot) {
      return snapshot.docs
          .map((doc) => NotificationItem.fromFirestore(doc))
          .toList();
    });
  }

  static Stream<int> getUnreadNotificationCount(String userId) {
    if (userId.isEmpty) return Stream.value(0);

    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((QuerySnapshot snapshot) {
      final validNotifications = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final senderId = data['senderId'] as String?;
        return senderId != userId;
      }).toList();

      return validNotifications.length;
    });
  }

  static Stream<int> _getUserUnreadCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((DocumentSnapshot snapshot) {
      if (!snapshot.exists) return 0;
      final data = snapshot.data() as Map<String, dynamic>?;
      return data?['unreadCount'] as int? ?? 0;
    });
  }

  static Future<void> incrementUnreadCount(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'unreadCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('❌ Error incrementing unreadCount: $e');
    }
  }

  static Future<void> clearUnreadCount(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'unreadCount': 0,
      });
    } catch (e) {
      debugPrint('❌ Error clearing unreadCount: $e');
    }
  }

  static Future<void> markNotificationAsRead(String notificationId,
      {bool deleteAfterRead = true}) async {
    try {
      if (deleteAfterRead) {
        await _firestore
            .collection('notifications')
            .doc(notificationId)
            .delete();
      } else {
        await _firestore
            .collection('notifications')
            .doc(notificationId)
            .update({'read': true, 'readAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      debugPrint('❌ Error handling notification: $e');
    }
  }

  static Future<void> deleteNotificationsForChat(
      String userId, String chatId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .where('chatId', isEqualTo: chatId)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ Error deleting notifications for chat: $e');
    }
  }

  static Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    String? chatId,
    String? senderId,
    String? senderName,
    String actionText = '',
    int messageCount = 1,
    DateTime? lastMessageTime,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'receiverId': userId,
        'senderId': senderId,
        'senderName': senderName,
        'title': title,
        'body': message,
        'type': type.toString().split('.').last,
        'chatId': chatId,
        'actionText': actionText,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'messageCount': messageCount,
        'lastMessageTime': lastMessageTime != null
            ? Timestamp.fromDate(lastMessageTime)
            : FieldValue.serverTimestamp(),
        'data': {
          'chatId': chatId,
          'senderId': senderId,
        },
      });
      await incrementUnreadCount(userId);
    } catch (e) {
      debugPrint('❌ Error creating notification: $e');
    }
  }

  static Future<void> createOrUpdateMessageNotification({
    required String userId,
    required String senderId,
    required String senderName,
    required String messageText,
    required String chatId,
  }) async {
    try {
      final existingNotifications = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .where('senderId', isEqualTo: senderId)
          .where('type', isEqualTo: 'message')
          .where('read', isEqualTo: false)
          .limit(1)
          .get();

      final now = Timestamp.now();
      final truncatedMessage = messageText.length > 50
          ? '${messageText.substring(0, 50)}...'
          : messageText;

      if (existingNotifications.docs.isNotEmpty) {
        final existingDoc = existingNotifications.docs.first;
        final currentCount =
            ((existingDoc.data() as Map<String, dynamic>)['messageCount'] as num?)?.toInt() ?? 1;

        await _firestore
            .collection('notifications')
            .doc(existingDoc.id)
            .update({
          'body': truncatedMessage,
          'lastMessageTime': now,
          'messageCount': currentCount + 1,
          'read': false,
          'chatId': chatId,
        });
      } else {
        final notificationData = {
          'receiverId': userId,
          'senderId': senderId,
          'senderName': senderName,
          'title': 'New Message from $senderName',
          'body': truncatedMessage,
          'timestamp': now,
          'lastMessageTime': now,
          'read': false,
          'type': 'message',
          'chatId': chatId,
          'actionText': 'Reply',
          'messageCount': 1,
          'data': {
            'chatId': chatId,
            'senderId': senderId,
          },
        };

        await _firestore.collection('notifications').add(notificationData);
        await incrementUnreadCount(userId);
      }
    } catch (e) {
      debugPrint('❌ Error in createOrUpdateMessageNotification: $e');
    }
  }

  static Future<void> markSenderNotificationsAsRead(
      String userId, String senderId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .where('senderId', isEqualTo: senderId)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      await _recalculateUnreadCount(userId);
    } catch (e) {
      debugPrint('❌ Error marking sender notifications as read: $e');
    }
  }

  static Future<void> _recalculateUnreadCount(String userId) async {
    try {
      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      await _firestore.collection('users').doc(userId).update({
        'unreadCount': unreadNotifications.docs.length,
      });
    } catch (e) {
      debugPrint('❌ Error recalculating unread count: $e');
    }
  }

  static Future<void> resetMessageCount(String userId, String senderId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .where('senderId', isEqualTo: senderId)
          .where('read', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        await doc.reference.update({
          'messageCount': 1,
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await _recalculateUnreadCount(userId);
    } catch (e) {
      debugPrint('❌ Error resetting message count: $e');
    }
  }

  static Stream<DocumentSnapshot> getUserData(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }
}
