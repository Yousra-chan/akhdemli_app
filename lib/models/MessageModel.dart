import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  String? id;
  final String senderId;
  final String text;
  final Timestamp timestamp; // Changed back to Timestamp for consistency
  final String type;
  final bool isRead;

  MessageModel({
    this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.type,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'type': type,
      'isRead': isRead,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> data) {
    return MessageModel(
      id: data['id'],
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      type: data['type'] ?? 'text',
      isRead: data['isRead'] ?? false,
    );
  }

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel.fromMap({...data, 'id': doc.id});
  }

  // Helper method to convert to DateTime if needed
  DateTime get timestampDate => timestamp.toDate();
}
