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
    // ✅ FIXED: Use receiverId instead of userId
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: userId) // ✅ FIXED
        .orderBy('timestamp', descending: true) // ✅ FIXED: use timestamp
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

  // ✅ FIXED: Get unread notification count - WORKS WITH YOUR FIREBASE!
  static Stream<int> getUnreadNotificationCount(String userId) {
    if (userId.isEmpty) {
      print('⚠️ Empty userId provided');
      return Stream.value(0);
    }

    print('🔍 Setting up unread count stream for: $userId');

    // Try to get from notifications collection first
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: userId) // ✅ FIXED: receiverId
        .where('read', isEqualTo: false) // ✅ FIXED: read
        .snapshots()
        .map((snapshot) {
      // Filter out self-notifications
      final validNotifications = snapshot.docs.where((doc) {
        final data = doc.data();
        final senderId = data['senderId'] as String?;
        return senderId != userId;
      }).toList();

      final count = validNotifications.length;
      print('📊 Notification count from collection: $count');
      return count;
    }).handleError((error) {
      print('⚠️ Error querying notifications (may need index): $error');
      // Fallback to user's unreadCount field
      return _getUserUnreadCount(userId);
    });
  }

  // ✅ FALLBACK: Get unread count from user document
  static Stream<int> _getUserUnreadCount(String userId) {
    print('📊 Using fallback: reading unreadCount from user document');
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        print('⚠️ User document does not exist');
        return 0;
      }
      final unreadCount = snapshot.data()?['unreadCount'] as int? ?? 0;
      print('📊 User unreadCount: $unreadCount');
      return unreadCount;
    }).handleError((error) {
      print('❌ Error reading user unreadCount: $error');
      return 0;
    });
  }

  // ✅ NEW: Increment unread count in user document
  static Future<void> incrementUnreadCount(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'unreadCount': FieldValue.increment(1),
      });
      print('✅ Incremented unreadCount for $userId');
    } catch (e) {
      print('❌ Error incrementing unreadCount: $e');
    }
  }

  // ✅ NEW: Clear unread count in user document
  static Future<void> clearUnreadCount(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'unreadCount': 0,
      });
      print('✅ Cleared unreadCount for $userId');
    } catch (e) {
      print('❌ Error clearing unreadCount: $e');
    }
  }

  // ✅ FIXED: Mark notification as read
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
        // ✅ FIXED: Use 'read' instead of 'isRead'
        await _firestore
            .collection('notifications')
            .doc(notificationId)
            .update({'read': true, 'readAt': FieldValue.serverTimestamp()});
        print('✅ Notification marked as read: $notificationId');
      }
    } catch (e) {
      print('❌ Error handling notification: $e');
    }
  }

  // ✅ FIXED: Delete all notifications for a specific chat
  static Future<void> deleteNotificationsForChat(
      String userId, String chatId) async {
    try {
      // ✅ FIXED: Use receiverId and read
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
      print(
          '🗑️ Deleted ${notifications.docs.length} notifications for chat: $chatId');
    } catch (e) {
      print('❌ Error deleting notifications for chat: $e');
    }
  }

  // ✅ FIXED: Create a notification (matches your notification_service.dart)
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
      // ✅ FIXED: Use receiverId and read to match your structure
      await _firestore.collection('notifications').add({
        'receiverId': userId, // ✅ FIXED
        'senderId': senderId,
        'senderName': senderName,
        'title': title,
        'body': message, // ✅ FIXED: use 'body' to match notification_service
        'type': type.toString().split('.').last,
        'chatId': chatId,
        'actionText': actionText,
        'read': false, // ✅ FIXED
        'timestamp': FieldValue.serverTimestamp(), // ✅ FIXED
        'messageCount': messageCount,
        'lastMessageTime': lastMessageTime != null
            ? Timestamp.fromDate(lastMessageTime)
            : FieldValue.serverTimestamp(),
        'data': {
          'chatId': chatId,
          'senderId': senderId,
        },
      });
      print('✅ Notification created for user: $userId');

      // Also increment user's unreadCount
      await incrementUnreadCount(userId);
    } catch (e) {
      print('❌ Error creating notification: $e');
    }
  }

  // ✅ FIXED: Create or update message notification with grouping
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

      // ✅ FIXED: Use receiverId, senderId, and read
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
        // UPDATE EXISTING NOTIFICATION
        final existingDoc = existingNotifications.docs.first;
        final existingData = existingDoc.data();
        final currentCount =
            (existingData['messageCount'] as num?)?.toInt() ?? 1;

        await _firestore
            .collection('notifications')
            .doc(existingDoc.id)
            .update({
          'body': truncatedMessage, // ✅ FIXED
          'lastMessageTime': now,
          'messageCount': currentCount + 1,
          'read': false, // ✅ FIXED
          'chatId': chatId,
        });

        print('✅ Updated existing notification: ${existingDoc.id}');
        print('✅ Message count: ${currentCount + 1}');
      } else {
        // CREATE NEW NOTIFICATION
        final notificationData = {
          'receiverId': userId, // ✅ FIXED
          'senderId': senderId,
          'senderName': senderName,
          'title': 'New Message from $senderName',
          'body': truncatedMessage, // ✅ FIXED
          'timestamp': now, // ✅ FIXED
          'lastMessageTime': now,
          'read': false, // ✅ FIXED
          'type': 'message',
          'chatId': chatId,
          'actionText': 'Reply',
          'messageCount': 1,
          'data': {
            'chatId': chatId,
            'senderId': senderId,
          },
        };

        final docRef =
            await _firestore.collection('notifications').add(notificationData);
        print('✅ Created new notification: ${docRef.id}');

        // Increment user's unreadCount
        await incrementUnreadCount(userId);
      }
    } catch (e) {
      print('❌ Error in createOrUpdateMessageNotification: $e');
    }
  }

  // ✅ FIXED: Mark all notifications from a specific sender as read
  static Future<void> markSenderNotificationsAsRead(
      String userId, String senderId) async {
    try {
      // ✅ FIXED: Use receiverId and read
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
      print(
          '✅ Marked ${notifications.docs.length} notifications from $senderId as read');

      // Recalculate unread count
      await _recalculateUnreadCount(userId);
    } catch (e) {
      print('❌ Error marking sender notifications as read: $e');
    }
  }

  // ✅ NEW: Recalculate user's unread count
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
      print('❌ Error recalculating unread count: $e');
    }
  }

  // ✅ FIXED: Clear message count when user reads the chat
  static Future<void> resetMessageCount(String userId, String senderId) async {
    try {
      // ✅ FIXED: Use receiverId and read
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

      print('✅ Reset message count for notifications from $senderId');

      // Recalculate unread count
      await _recalculateUnreadCount(userId);
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
