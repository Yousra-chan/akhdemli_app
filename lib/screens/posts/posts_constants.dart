import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Colors ---
const Color kPrimaryBlue = Color.fromARGB(255, 12, 94, 153);
const Color kLightBackgroundColor = Color.fromARGB(255, 248, 249, 255);
const Color kCardBackgroundColor = Colors.white;
const Color kDarkTextColor = Color.fromARGB(255, 50, 50, 50);
const Color kMutedTextColor = Color.fromARGB(255, 150, 150, 150);
const Color kSoftShadowColor = Color.fromARGB(50, 87, 101, 240);
const Color kSuccessGreen = Color.fromARGB(255, 76, 175, 80);

// --- Post Type Colors ---
const Color kSeekingColor = Color.fromARGB(255, 255, 100, 100);
const Color kOfferingColor = Color.fromARGB(255, 100, 200, 100);
const Color kAccentColor = Color(0xFFFFB300);

const double kDummyPriceEstimate = 5000.00;
const List<String> kDummyWorkImages = [];

enum PostType { seeking, offering }

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

// ---------------------------------------------------------------------------
// Service Category Translator
// Dynamically maps category/subcategory names to translation keys.
// ---------------------------------------------------------------------------
class ServiceCategoryTranslator {
  static String getCategoryKey(String category) {
    if (category.isEmpty) return 'category_other';
    return 'category_${category.toLowerCase().replaceAll(' ', '_')}';
  }

  /// Returns the translation nameKey for a subcategory.
  static String getSubcategoryKey(String subcategory, {String? category}) {
    if (subcategory.isEmpty) return 'subcategory_general';
    
    // Handle ambiguous names if necessary, but ideally these come from Firestore
    if (category == 'Electrical' && subcategory == 'Fixture Installation') {
      return 'subcategory_electrical_fixture';
    }
    
    return 'subcategory_${subcategory.toLowerCase().replaceAll(' ', '_').replaceAll('&', 'and')}';
  }

  /// All valid category names.
  /// Note: This is now driven by Firestore, this list is only for legacy fallback.
  static List<String> get categoryNames => [
    'Cleaning', 'Plumbing', 'Electrical', 'Carpentry', 'Painting', 
    'Gardening', 'Moving', 'Repair', 'Installation', 'Tutoring', 
    'Health', 'Beauty', 'Tech', 'Food', 'Home', 'Other'
  ];
}

// ---------------------------------------------------------------------------
// Post model — now stores both category and subcategory.
// ---------------------------------------------------------------------------
class Post {
  final String id;
  final String title;
  final String body;
  final String user;
  final String userId;
  final String userPhotoUrl;
  final PostType type;

  /// Top-level category name, e.g. "Electrical". Matches CategoryModel.name.
  final String serviceCategory;

  /// Translation key for the category, e.g. "category_electrical".
  final String serviceCategoryKey;

  /// Subcategory name, e.g. "Wiring". Matches SubcategoryModel.name.
  final String serviceSubcategory;

  /// Translation key for the subcategory, e.g. "subcategory_wiring".
  final String serviceSubcategoryKey;

  final DateTime timestamp;
  final List<String> imageUrls;

  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.user,
    required this.userId,
    this.userPhotoUrl = '',
    required this.type,
    required this.serviceCategory,
    this.serviceCategoryKey = '',
    this.serviceSubcategory = '',
    this.serviceSubcategoryKey = '',
    required this.timestamp,
    this.imageUrls = const [],
  });

  // --- Translation key helpers ---

  String get categoryTranslationKey => serviceCategoryKey.isNotEmpty
      ? serviceCategoryKey
      : ServiceCategoryTranslator.getCategoryKey(serviceCategory);

  String get subcategoryTranslationKey => serviceSubcategoryKey.isNotEmpty
      ? serviceSubcategoryKey
      : ServiceCategoryTranslator.getSubcategoryKey(
          serviceSubcategory,
          category: serviceCategory,
        );

  bool get hasSubcategory => serviceSubcategory.isNotEmpty;

  // --- Firestore serialisation ---

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'user': user,
      'userId': userId,
      'userPhotoUrl': userPhotoUrl,
      'type': type == PostType.seeking ? 'seeking' : 'offering',
      'serviceCategory': serviceCategory,
      'serviceCategoryKey': serviceCategoryKey,
      'serviceSubcategory': serviceSubcategory,
      'serviceSubcategoryKey': serviceSubcategoryKey,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrls': imageUrls,
    };
  }

  factory Post.fromMap(Map<String, dynamic> map, String docId) {
    final timestampData = map['timestamp'];
    final DateTime timestamp = timestampData is Timestamp 
        ? timestampData.toDate() 
        : DateTime.now();

    return Post(
      id: docId,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      user: map['user'] ?? 'Anonymous',
      userId: map['userId'] ?? 'unknown_user_id',
      userPhotoUrl: map['userPhotoUrl'] ?? '',
      type: map['type'] == 'seeking' ? PostType.seeking : PostType.offering,
      serviceCategory: map['serviceCategory'] ?? 'Other',
      serviceCategoryKey: map['serviceCategoryKey'] ?? '',
      serviceSubcategory: map['serviceSubcategory'] ?? '',
      serviceSubcategoryKey: map['serviceSubcategoryKey'] ?? '',
      timestamp: timestamp,
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
    );
  }

  Post copyWith({
    String? id,
    String? title,
    String? body,
    String? user,
    String? userId,
    String? userPhotoUrl,
    PostType? type,
    String? serviceCategory,
    String? serviceCategoryKey,
    String? serviceSubcategory,
    String? serviceSubcategoryKey,
    DateTime? timestamp,
    List<String>? imageUrls,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      user: user ?? this.user,
      userId: userId ?? this.userId,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      type: type ?? this.type,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      serviceCategoryKey: serviceCategoryKey ?? this.serviceCategoryKey,
      serviceSubcategory: serviceSubcategory ?? this.serviceSubcategory,
      serviceSubcategoryKey: serviceSubcategoryKey ?? this.serviceSubcategoryKey,
      timestamp: timestamp ?? this.timestamp,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }
}
