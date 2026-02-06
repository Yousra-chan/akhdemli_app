// screens/debug/spark_debug_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class SparkDebugScreen extends StatefulWidget {
  @override
  _SparkDebugScreenState createState() => _SparkDebugScreenState();
}

class _SparkDebugScreenState extends State<SparkDebugScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  String _userId = '';
  String _fcmToken = '';
  int _unreadCount = 0;
  List<Map<String, dynamic>> _notifications = [];
  String _log = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _setupListeners();
  }

  Future<void> _loadUserInfo() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });

      // Get FCM token
      final token = await _fcm.getToken();
      setState(() {
        _fcmToken = token?.substring(0, 30) ?? 'No token';
      });

      // Get unread count
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _unreadCount = userDoc.data()?['unreadCount'] ?? 0;
        });
      }
    }
  }

  void _setupListeners() {
    // Listen for new notifications in real-time
    final user = _auth.currentUser;
    if (user != null) {
      _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        setState(() {
          _notifications = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'title': data['title'],
              'sender': data['senderId'],
              'time': data['lastMessageTime']?.toString(),
            };
          }).toList();
        });

        _addLog('📱 Real-time update: ${snapshot.docs.length} unread');
      });
    }
  }

  Future<void> _createTestChat() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Create a test chat with another user
      final chatId = 'test_chat_${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.collection('chats').doc(chatId).set({
        'participants': [user.uid, 'test_receiver_id'],
        'participantNames': {
          user.uid: 'You',
          'test_receiver_id': 'Test User',
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send a test message
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': user.uid,
        'content': 'This is a test message from debug screen',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
      });

      _addLog('✅ Test chat created and message sent');
      _addLog('   Chat ID: $chatId');
      _addLog('   This should trigger the Cloud Function');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _checkNotifications() async {
    if (_userId.isEmpty) return;

    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: _userId)
        .orderBy('lastMessageTime', descending: true)
        .limit(10)
        .get();

    _addLog('🔍 Found ${snapshot.docs.length} notifications');

    for (var doc in snapshot.docs) {
      final data = doc.data();
      _addLog('   - ${data['title']} (from: ${data['senderId']})');
    }
  }

  Future<void> _clearAllNotifications() async {
    if (_userId.isEmpty) return;

    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: _userId)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();

    // Reset unread count
    await _firestore.collection('users').doc(_userId).update({
      'unreadCount': 0,
    });

    _addLog('✅ Cleared all notifications');
  }

  void _addLog(String message) {
    setState(() {
      _log = '${DateTime.now().toString().split(' ')[1]} $message\n$_log';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Spark Plan Debug'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📊 STATUS',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text('User ID: $_userId'),
                    Text('FCM Token: $_fcmToken...'),
                    Text('Unread Count: $_unreadCount'),
                    Text('Live Notifications: ${_notifications.length}'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Actions
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🛠️ ACTIONS',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _createTestChat,
                          child: Text('Send Test Message'),
                        ),
                        ElevatedButton(
                          onPressed: _checkNotifications,
                          child: Text('Check Notifications'),
                        ),
                        ElevatedButton(
                          onPressed: _clearAllNotifications,
                          child: Text('Clear All'),
                        ),
                        ElevatedButton(
                          onPressed: _loadUserInfo,
                          child: Text('Refresh'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Live Notifications
            if (_notifications.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📱 LIVE NOTIFICATIONS',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      ..._notifications
                          .map((notif) => ListTile(
                                title: Text(notif['title']),
                                subtitle: Text('From: ${notif['sender']}'),
                              ))
                          .toList(),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 16),

            // Log
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '📝 LOG',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () => setState(() => _log = ''),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 200,
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        reverse: true,
                        child: Text(
                          _log,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
