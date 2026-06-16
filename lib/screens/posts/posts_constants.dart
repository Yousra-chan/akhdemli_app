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
// Matches CategoryModel.defaultCategories exactly (16 categories, all subs).
// ---------------------------------------------------------------------------
class ServiceCategoryTranslator {
  // category name → nameKey (matches CategoryModel.nameKey)
  static const Map<String, String> _categoryKeys = {
    'Cleaning':     'category_cleaning',
    'Plumbing':     'category_plumbing',
    'Electrical':   'category_electrical',
    'Carpentry':    'category_carpentry',
    'Painting':     'category_painting',
    'Gardening':    'category_gardening',
    'Moving':       'category_moving',
    'Repair':       'category_repair',
    'Installation': 'category_installation',
    'Tutoring':     'category_tutoring',
    'Health':       'category_health',
    'Beauty':       'category_beauty',
    'Tech':         'category_tech',
    'Food':         'category_food',
    'Home':         'category_home',
    'Other':        'category_other',
  };

  // subcategory name → nameKey (matches SubcategoryModel.nameKey)
  static const Map<String, String> _subcategoryKeys = {
    // Cleaning
    'Home Cleaning':    'subcategory_home_cleaning',
    'Office Cleaning':  'subcategory_office_cleaning',
    'Deep Cleaning':    'subcategory_deep_cleaning',
    'Carpet Cleaning':  'subcategory_carpet_cleaning',
    // Plumbing
    'Pipe Repair':          'subcategory_pipe_repair',
    'Leak Fixing':          'subcategory_leak_fixing',
    'Fixture Installation': 'subcategory_fixture_installation',
    // Electrical
    'Wiring':  'subcategory_wiring',
    // 'Fixture Installation' already in plumbing — use category-qualified lookup below
    'Repair':  'subcategory_electrical_repair',   // Electrical > Repair
    // Carpentry
    'Furniture Making': 'subcategory_furniture_making',
    // 'Repair' (carpentry) handled below
    'Installation':     'subcategory_carpentry_installation',
    // Painting
    'Interior Painting': 'subcategory_interior_painting',
    'Exterior Painting': 'subcategory_exterior_painting',
    'Decorative':        'subcategory_decorative_painting',
    // Gardening
    'Lawn Care':    'subcategory_lawn_care',
    'Landscaping':  'subcategory_landscaping',
    'Planting':     'subcategory_planting',
    // Moving
    'Local Moving':  'subcategory_local_moving',
    'Long Distance': 'subcategory_long_distance',
    'Packing':       'subcategory_packing',
    // Repair
    'Appliance Repair':   'subcategory_appliance_repair',
    'General Maintenance':'subcategory_general_maintenance',
    'Emergency Repair':   'subcategory_emergency_repair',
    // Installation
    'Appliance Installation': 'subcategory_appliance_installation',
    'Furniture Assembly':     'subcategory_furniture_assembly',
    'Equipment Setup':        'subcategory_equipment_setup',
    // Tutoring
    'Academic Tutoring': 'subcategory_academic_tutoring',
    'Language Tutoring': 'subcategory_language_tutoring',
    'Test Preparation':  'subcategory_test_prep',
    // Health
    'Medical Consultation': 'subcategory_medical_consultation',
    'Therapy':              'subcategory_therapy',
    'Nursing Care':         'subcategory_nursing',
    // Beauty
    'Hair Styling': 'subcategory_hair_styling',
    'Makeup':       'subcategory_makeup',
    'Spa & Massage':'subcategory_spa',
    // Tech
    'Computer Repair': 'subcategory_computer_repair',
    'Mobile Repair':   'subcategory_mobile_repair',
    'IT Support':      'subcategory_it_support',
    // Food
    'Catering':     'subcategory_catering',
    'Private Chef': 'subcategory_private_chef',
    'Meal Prep':    'subcategory_meal_prep',
    // Home
    'Home Maintenance': 'subcategory_home_maintenance',
    'Smart Home':       'subcategory_smart_home',
    'Renovation':       'subcategory_renovation',
    // Other
    'General Service': 'subcategory_general',
  };

  // Subcategory names that are ambiguous across categories — resolved per-category.
  static const Map<String, Map<String, String>> _ambiguousSubcategoryKeys = {
    'Electrical': {
      'Fixture Installation': 'subcategory_electrical_fixture',
      'Repair':               'subcategory_electrical_repair',
    },
    'Carpentry': {
      'Repair': 'subcategory_carpentry_repair',
    },
  };

  static String getCategoryKey(String category) {
    return _categoryKeys[category] ?? 'category_other';
  }

  /// Returns the translation nameKey for a subcategory.
  /// Pass [category] to resolve ambiguous names (e.g. "Repair" in Electrical vs Carpentry).
  static String getSubcategoryKey(String subcategory, {String? category}) {
    if (category != null) {
      final resolved = _ambiguousSubcategoryKeys[category]?[subcategory];
      if (resolved != null) return resolved;
    }
    return _subcategoryKeys[subcategory] ?? 'subcategory_general';
  }

  /// All valid category names.
  static List<String> get categoryNames => _categoryKeys.keys.toList();
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
  final PostType type;

  /// Top-level category name, e.g. "Electrical". Matches CategoryModel.name.
  final String serviceCategory;

  /// Subcategory name, e.g. "Wiring". Matches SubcategoryModel.name.
  /// May be empty if the user didn't pick one.
  final String serviceSubcategory;

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
    this.serviceSubcategory = '',
    required this.timestamp,
    this.imageUrls = const [],
  });

  // --- Translation key helpers ---

  String get categoryTranslationKey =>
      ServiceCategoryTranslator.getCategoryKey(serviceCategory);

  String get subcategoryTranslationKey =>
      ServiceCategoryTranslator.getSubcategoryKey(
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
      'type': type == PostType.seeking ? 'seeking' : 'offering',
      'serviceCategory': serviceCategory,
      'serviceSubcategory': serviceSubcategory,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrls': imageUrls,
    };
  }

  factory Post.fromMap(Map<String, dynamic> map, String docId) {
    return Post(
      id: docId,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      user: map['user'] ?? 'Anonymous',
      userId: map['userId'] ?? 'unknown_user_id',
      type: map['type'] == 'seeking' ? PostType.seeking : PostType.offering,
      serviceCategory: map['serviceCategory'] ?? 'Other',
      serviceSubcategory: map['serviceSubcategory'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
    );
  }

  Post copyWith({
    String? id,
    String? title,
    String? body,
    String? user,
    String? userId,
    PostType? type,
    String? serviceCategory,
    String? serviceSubcategory,
    DateTime? timestamp,
    List<String>? imageUrls,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      user: user ?? this.user,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      serviceSubcategory: serviceSubcategory ?? this.serviceSubcategory,
      timestamp: timestamp ?? this.timestamp,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }
}