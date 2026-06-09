// services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/models/NotificationsModel.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // ==================== CATEGORIES ====================

  // Fetch categories from Firestore
  static Stream<List<CategoryModel>> getCategories() {
    return _firestore
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .handleError((error) {
      print('❌ Error fetching categories: $error');
      return Stream.value(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    }).map((snapshot) => snapshot.docs
            .map((doc) => CategoryModel.fromFirestore(doc))
            .toList());
  }

  // Get subcategories for a category
  static Stream<List<CategoryModel>> getSubCategories(String categoryId) {
    return _firestore
        .collection('categories')
        .where('parentId', isEqualTo: categoryId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .handleError((error) {
      print('❌ Error fetching subcategories: $error');
      return Stream.value([]);
    }).map((snapshot) => snapshot.docs
            .map((doc) => CategoryModel.fromFirestore(doc))
            .toList());
  }

  // Get categories as List (non-stream)
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
      print('❌ Error fetching categories list: $e');
      return CategoryModel.defaultCategories;
    }
  }

  static Stream<List<ProviderModel>> getProviders() {
    return _firestore
        .collection('providers')
        .where('subscriptionActive', isEqualTo: true)
        .snapshots()
        .handleError((error) {
      print('❌ Error fetching providers: $error');
      return Stream.value([]);
    }).map((snapshot) {
      return snapshot.docs.map((doc) {
        return ProviderModel.fromFirestore(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Get user notifications
  static Stream<List<NotificationItem>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('time', descending: true)
        .snapshots()
        .handleError((error) {
      print('❌ Error fetching notifications: $error');
      return Stream.value([]);
    }).map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationItem.fromFirestore(doc))
          .toList();
    });
  }

  // ✅ FIXED: Get unread notification count - Changed 'userId' to 'receiverId'
  static Stream<int> getUnreadNotificationCount(String userId) {
    print('🔔 Querying unread notifications for user: $userId');
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      print('🔔 Found ${snapshot.docs.length} unread notifications');
      return snapshot.docs.length;
    });
  }

  // Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId,
      {bool deleteAfterRead = true}) async {
    try {
      if (deleteAfterRead) {
        await _firestore
            .collection('notifications')
            .doc(notificationId)
            .delete();
        print('🗑️ Notification deleted: $notificationId');
      } else {
        await _firestore
            .collection('notifications')
            .doc(notificationId)
            .update({'isRead': true});
        print('✅ Notification marked as read: $notificationId');
      }
    } catch (e) {
      print('❌ Error handling notification: $e');
    }
  }

  // Delete all notifications for a specific chat
  static Future<void> deleteNotificationsForChat(
      String userId, String chatId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('chatId', isEqualTo: chatId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print(
          '🗑️ Deleted ${notifications.docs.length} notifications for chat: $chatId');
    } catch (e) {
      print('❌ Error deleting notifications for chat: $e');
    }
  }

  // Create a notification
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
        'userId': userId,
        'title': title,
        'message': message,
        'type': type.toString().split('.').last,
        'chatId': chatId,
        'senderId': senderId,
        'senderName': senderName,
        'actionText': actionText,
        'isRead': false,
        'time': FieldValue.serverTimestamp(),
        'messageCount': messageCount,
        'lastMessageTime': lastMessageTime != null
            ? Timestamp.fromDate(lastMessageTime)
            : FieldValue.serverTimestamp(),
      });
      print('✅ Notification created for user: $userId');
    } catch (e) {
      print('❌ Error creating notification: $e');
    }
  }

  // Create or update message notification with grouping
  static Future<void> createOrUpdateMessageNotification({
    required String userId,
    required String senderId,
    required String senderName,
    required String messageText,
    required String chatId,
  }) async {
    try {
      print('🔔 Creating/updating message notification');
      print('🔔 User: $userId, Sender: $senderName');

      // Check if there's already an unread notification from this sender
      final existingNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('senderId', isEqualTo: senderId)
          .where('type', isEqualTo: 'message')
          .where('isRead', isEqualTo: false)
          .limit(1)
          .get();

      final now = Timestamp.now();
      final truncatedMessage = messageText.length > 50
          ? '${messageText.substring(0, 50)}...'
          : messageText;

      if (existingNotifications.docs.isNotEmpty) {
        // UPDATE EXISTING NOTIFICATION
        final existingDoc = existingNotifications.docs.first;
        final existingData = existingDoc.data();
        final currentCount =
            (existingData['messageCount'] as num?)?.toInt() ?? 1;

        await _firestore
            .collection('notifications')
            .doc(existingDoc.id)
            .update({
          'message': truncatedMessage,
          'lastMessageTime': now,
          'messageCount': currentCount + 1,
          'isRead': false,
          'chatId': chatId,
        });

        print('✅ Updated existing notification: ${existingDoc.id}');
        print('✅ Message count: ${currentCount + 1}');
      } else {
        // CREATE NEW NOTIFICATION
        final notificationData = {
          'userId': userId,
          'title': 'New Message from $senderName',
          'message': truncatedMessage,
          'time': now,
          'lastMessageTime': now,
          'isRead': false,
          'type': 'message',
          'chatId': chatId,
          'senderId': senderId,
          'senderName': senderName,
          'actionText': 'Reply',
          'messageCount': 1,
        };

        final docRef =
            await _firestore.collection('notifications').add(notificationData);
        print('✅ Created new notification: ${docRef.id}');
      }
    } catch (e) {
      print('❌ Error in createOrUpdateMessageNotification: $e');
    }
  }

  // Mark all notifications from a specific sender as read
  static Future<void> markSenderNotificationsAsRead(
      String userId, String senderId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('senderId', isEqualTo: senderId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      print(
          '✅ Marked ${notifications.docs.length} notifications from $senderId as read');
    } catch (e) {
      print('❌ Error marking sender notifications as read: $e');
    }
  }

  // Clear message count when user reads the chat
  static Future<void> resetMessageCount(String userId, String senderId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('senderId', isEqualTo: senderId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        await doc.reference.update({
          'messageCount': 1,
          'isRead': true,
        });
      }

      print('✅ Reset message count for notifications from $senderId');
    } catch (e) {
      print('❌ Error resetting message count: $e');
    }
  }

  // Test method to verify everything works
  static Future<void> createTestNotification(String userId) async {
    try {
      print('🔔 Creating test notification...');
      await createNotification(
        userId: userId,
        title: 'Test Notification 🔔',
        message:
            'This is a test notification to verify everything works correctly',
        type: NotificationType.system,
        actionText: 'View Test',
      );
      print('✅ Test notification created successfully');
    } catch (e) {
      print('❌ Error creating test notification: $e');
    }
  }

  // ==================== USER DATA ====================

  // Get user data
  static Stream<DocumentSnapshot> getUserData(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // Helper method for notification type conversion
  static String _notificationTypeToString(NotificationType type) {
    return type.toString().split('.').last;
  }

  // Add this to your FirebaseService class
  Future<List<SubcategoryModel>> getSubcategoriesForCategory(
      String categoryId) async {
    try {
      print('📥 Fetching subcategories for category: $categoryId');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('subcategories')
          .where('categoryId', isEqualTo: categoryId)
          .where('isActive', isEqualTo: true)
          .get();

      List<SubcategoryModel> subcategories = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        subcategories.add(SubcategoryModel.fromMap(data, doc.id));
      }

      print('✅ Found ${subcategories.length} subcategories in Firestore');
      return subcategories;
    } catch (e) {
      print('❌ Error fetching subcategories: $e');
      return [];
    }
  }
}
