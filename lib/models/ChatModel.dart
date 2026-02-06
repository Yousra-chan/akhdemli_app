import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String chatId;
  final String clientId;
  final String providerId;
  final String lastMessage;
  final Timestamp lastMessageTime;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String> participantRoles;
  final Map<String, dynamic> unreadCount;
  final Timestamp createdAt;
  final String? lastMessageSender;
  final String? lastMessageType;

  ChatModel({
    required this.chatId,
    required this.clientId,
    required this.providerId,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.participants,
    required this.participantNames,
    required this.participantRoles,
    required this.unreadCount,
    required this.createdAt,
    this.lastMessageSender,
    this.lastMessageType,
  });

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'clientId': clientId,
      'providerId': providerId,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'participants': participants,
      'participantNames': participantNames,
      'participantRoles': participantRoles,
      'unreadCount': unreadCount,
      'createdAt': createdAt,
      'lastMessageSender': lastMessageSender,
      'lastMessageType': lastMessageType,
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> data) {
    return ChatModel(
      chatId: data['chatId'] ?? '',
      clientId: data['clientId'] ?? '',
      providerId: data['providerId'] ?? '',
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: data['lastMessageTime'] ?? Timestamp.now(),
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: Map<String, String>.from(
        data['participantNames'] ?? {},
      ),
      participantRoles: Map<String, String>.from(
        data['participantRoles'] ?? {},
      ),
      unreadCount: Map<String, dynamic>.from(data['unreadCount'] ?? {}),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      lastMessageSender: data['lastMessageSender'],
      lastMessageType: data['lastMessageType'],
    );
  }

  factory ChatModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModel.fromMap(data);
  }

  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere((id) => id != currentUserId);
  }

  String getOtherParticipantName(String currentUserId) {
    final otherId = getOtherParticipantId(currentUserId);
    return participantNames[otherId] ?? 'Unknown User';
  }

  int getUnreadCountForUser(String userId) {
    final count = unreadCount[userId];
    if (count is int) return count;
    if (count is num) return count.toInt();
    return 0;
  }
}
