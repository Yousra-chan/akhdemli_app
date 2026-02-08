// test-notification.js
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function testNotification() {
  try {
    // Simulate updating a chat document
    const chatId = "test_chat_123";
    const senderId = "test_sender_456";
    const receiverId = "test_receiver_789";
    
    // First, create test users
    await admin.firestore().collection('users').doc(senderId).set({
      name: "Test Sender",
      fcmToken: "test_fcm_token_sender",
    });
    
    await admin.firestore().collection('users').doc(receiverId).set({
      name: "Test Receiver",
      fcmToken: "test_fcm_token_receiver",
    });
    
    // Create test chat
    await admin.firestore().collection('chats').doc(chatId).set({
      participants: [senderId, receiverId],
      participantNames: {
        [senderId]: "Test Sender",
        [receiverId]: "Test Receiver"
      },
      lastMessageSender: senderId,
      lastMessage: "Hello from test!",
      lastMessageType: "text",
      lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log('✅ Test data created');
    console.log('Function should trigger automatically!');
    
  } catch (error) {
    console.error('❌ Test error:', error);
  }
}

testNotification();