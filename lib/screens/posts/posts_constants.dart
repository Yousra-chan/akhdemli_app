import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Colors (Consistent with previous screens) ---
const Color kPrimaryBlue = Color.fromARGB(255, 12, 94, 153);
const Color kLightBackgroundColor = Color.fromARGB(255, 248, 249, 255);
const Color kCardBackgroundColor = Colors.white;
const Color kDarkTextColor = Color.fromARGB(255, 50, 50, 50);
const Color kMutedTextColor = Color.fromARGB(255, 150, 150, 150);
const Color kSoftShadowColor = Color.fromARGB(50, 87, 101, 240);

// --- Post Type Colors ---
const Color kSeekingColor = Color.fromARGB(255, 255, 100, 100);
const Color kOfferingColor = Color.fromARGB(255, 100, 200, 100);
const Color kAccentColor = Color(0xFFFFB300);

const double kDummyPriceEstimate = 5000.00;
const List<String> kDummyWorkImages = [];

enum PostType { seeking, offering }

// --- Service Category Translation Helper ---
class ServiceCategoryTranslator {
  static const Map<String, String> _categoryKeys = {
    "Electrician": "electrician",
    "Plumbing": "plumbing",
    "Tutoring": "tutoring",
    "Handyman": "handyman",
    "Cleaning": "cleaning",
    "Other": "other",
    "General": "general",
  };

  static String getTranslationKey(String category) {
    return _categoryKeys[category] ?? 'other';
  }
}

// --- Post Type Translation Helper ---
extension PostTypeTranslation on PostType {
  String get translationKey {
    switch (this) {
      case PostType.seeking:
        return 'looking_for';
      case PostType.offering:
        return 'offering';
    }
  }
}

class Post {
  final String id;
  final String title;
  final String body;
  final String user;
  final String userId;
  final PostType type;
  final String serviceCategory;
  final DateTime timestamp;
  final List<String> imageUrls;

  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.user,
    required this.userId,
    required this.type,
    required this.serviceCategory,
    required this.timestamp,
    this.imageUrls = const [],
  });

  // Get translation key for service category
  String get categoryTranslationKey {
    return ServiceCategoryTranslator.getTranslationKey(serviceCategory);
  }

  // Convert Post object to Map (for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'user': user,
      'userId': userId,
      'type': type == PostType.seeking ? 'seeking' : 'offering',
      'serviceCategory': serviceCategory,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrls': imageUrls,
    };
  }

  // Create Post object from Map (from Firestore)
  factory Post.fromMap(Map<String, dynamic> map, String docId) {
    return Post(
      id: docId,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      user: map['user'] ?? 'Anonymous',
      userId: map['userId'] ?? 'unknown_user_id',
      type: map['type'] == 'seeking' ? PostType.seeking : PostType.offering,
      serviceCategory: map['serviceCategory'] ?? 'General',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
    );
  }
}
