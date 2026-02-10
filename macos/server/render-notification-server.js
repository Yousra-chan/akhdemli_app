// render-notification-server.js
import express from 'express';
import http from 'http';
import cors from 'cors';
import fetch from 'node-fetch'; // pour les requêtes FCM

const app = express();
app.use(cors());
app.use(express.json());

// 🔥 CLÉ FCM SERVER (ajoute-la dans Render ou en local)
const FCM_SERVER_KEY = process.env.FCM_SERVER_KEY || 'ta_clé_FCM_ici';

// Stockages
const userConnections = new Map(); // userId -> {userName, fcmToken, lastPing}
const pendingMessages = new Map(); // userId -> [messages]
const fcmTokens = new Map(); // userId -> fcmToken (cache)

// 🔥 FONCTION POUR ENVOYER NOTIFICATIONS FCM
async function sendFCMNotification(fcmToken, title, body, data = {}) {
  if (!fcmToken || !FCM_SERVER_KEY) {
    console.log('❌ FCM non configuré ou token manquant');
    return false;
  }

  try {
    const response = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Authorization': `key=${FCM_SERVER_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: fcmToken,
        priority: 'high',
        content_available: true,
        notification: { title, body, sound: 'default', android_channel_id: 'high_importance_channel', icon: 'ic_launcher' },
        data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK', sound: 'default' },
        android: { priority: 'high', notification: { channel_id: 'high_importance_channel', sound: 'default' } },
        apns: { payload: { aps: { sound: 'default', badge: 1 } } },
      }),
    });

    const result = await response.json();
    console.log(`📤 Réponse FCM: ${JSON.stringify(result)}`);
    return result.success === 1 || !!result.message_id;
  } catch (error) {
    console.error(`❌ Erreur FCM: ${error.message}`);
    return false;
  }
}

// ==================== ENDPOINTS ====================

// CONNECT
app.post('/connect', (req, res) => {
  const { userId, userName, fcmToken } = req.body;
  if (!userId) return res.status(400).json({ success: false, error: 'userId is required' });

  if (fcmToken && fcmToken.length > 50) fcmTokens.set(userId, fcmToken);

  userConnections.set(userId, { userName: userName || 'Anonymous', fcmToken, connectedAt: new Date().toISOString(), lastPing: Date.now(), isOnline: true });

  res.json({ success: true, message: `Welcome ${userName || 'User'}!`, userId, hasFCM: !!fcmToken, fcmConfigured: !!FCM_SERVER_KEY, timestamp: new Date().toISOString() });
});

// SEND
app.post('/send', async (req, res) => {
  const { senderId, receiverId, message, chatId, senderName } = req.body;
  if (!senderId || !receiverId || !message) return res.status(400).json({ success: false, error: 'senderId, receiverId, and message are required' });

  const messageObj = { type: 'message', senderId, senderName: senderName || 'Unknown', message, chatId: chatId || 'general', timestamp: new Date().toISOString(), messageId: 'msg_' + Date.now(), click_action: 'FLUTTER_NOTIFICATION_CLICK' };

  const receiverOnline = userConnections.has(receiverId);
  const receiverFCMToken = fcmTokens.get(receiverId);
  let fcmSent = false, methodUsed = 'none';

  if (receiverFCMToken && FCM_SERVER_KEY) {
    fcmSent = await sendFCMNotification(receiverFCMToken, `${senderName || 'Nouveau message'}`, message.length > 100 ? message.substring(0, 100) + '...' : message, messageObj);
    if (fcmSent) methodUsed = 'FCM';
  }

  if (!fcmSent) {
    if (!pendingMessages.has(receiverId)) pendingMessages.set(receiverId, []);
    pendingMessages.get(receiverId).push(messageObj);
    methodUsed = 'POLLING';
  }

  res.json({ success: true, delivered: fcmSent || receiverOnline, fcmSent, method: methodUsed, receiverOnline, hasFCMToken: !!receiverFCMToken, pendingCount: pendingMessages.get(receiverId)?.length || 0, message: fcmSent ? 'Notification envoyée' : receiverOnline ? 'Message délivré (online)' : 'Message en attente', timestamp: new Date().toISOString() });
});

// POLL
app.get('/poll/:userId', (req, res) => {
  const userId = req.params.userId;
  if (userConnections.has(userId)) userConnections.get(userId).lastPing = Date.now();

  if (pendingMessages.has(userId) && pendingMessages.get(userId).length > 0) {
    const messages = pendingMessages.get(userId);
    const message = messages.shift();
    if (messages.length === 0) pendingMessages.delete(userId);
    return res.json({ success: true, ...message, fromPolling: true, pendingRemaining: messages.length });
  }

  res.setTimeout(30000, () => res.json({ success: true, type: 'timeout', message: 'No messages available', timestamp: new Date().toISOString() }));
});

// FCM REGISTER
app.post('/fcm-register', (req, res) => {
  const { userId, fcmToken } = req.body;
  if (!userId || !fcmToken) return res.status(400).json({ success: false, error: 'userId and fcmToken required' });
  fcmTokens.set(userId, fcmToken);
  res.json({ success: true, message: 'FCM token registered', timestamp: new Date().toISOString() });
});

// DISCONNECT
app.post('/disconnect', (req, res) => {
  const { userId } = req.body;
  if (!userId) return res.status(400).json({ success: false, error: 'userId is required' });
  userConnections.delete(userId);
  res.json({ success: true, message: 'Disconnected successfully', timestamp: new Date().toISOString() });
});

// ONLINE
app.get('/online/:userId', (req, res) => {
  const userId = req.params.userId;
  const isOnline = userConnections.has(userId);
  if (isOnline) {
    const userInfo = userConnections.get(userId);
    return res.json({ success: true, isOnline: true, userId, userName: userInfo.userName, connectedAt: userInfo.connectedAt, timestamp: new Date().toISOString() });
  }
  res.json({ success: true, isOnline: false, userId, timestamp: new Date().toISOString() });
});

// PENDING
app.get('/pending/:userId', (req, res) => {
  const userId = req.params.userId;
  const pendingCount = pendingMessages.get(userId)?.length || 0;
  res.json({ success: true, userId, pendingCount, timestamp: new Date().toISOString() });
});

// HEALTH
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', server: 'Notification Server', fcmConfigured: !!FCM_SERVER_KEY, connectedUsers: userConnections.size, pendingMessages: Array.from(pendingMessages.values()).reduce((sum, msgs) => sum + msgs.length, 0), timestamp: new Date().toISOString() });
});

// ==================== START SERVER ====================
const PORT = process.env.PORT || 3001;
const server = http.createServer(app);
server.listen(PORT, '0.0.0.0', () => console.log(`✅ Server running on port ${PORT}\n🔥 FCM configured: ${!!FCM_SERVER_KEY}`));

// Cleanup inactives
setInterval(() => {
  const now = Date.now();
  let cleaned = 0;
  for (const [userId, conn] of userConnections.entries()) {
    if (now - conn.lastPing > 10 * 60 * 1000) { // 10 minutes
      userConnections.delete(userId);
      cleaned++;
    }
  }
  if (cleaned > 0) console.log(`🧹 Nettoyé ${cleaned} connexions inactives`);
}, 5 * 60 * 1000); // every 5 min
