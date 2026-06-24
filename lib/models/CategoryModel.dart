import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_app/providers/language_provider.dart';

class SubcategoryModel {
  final String id;
  final String categoryId; // Added for explicit linking
  final String name;
  final Map<String, String> nameTranslations;
  final String description;
  final Map<String, String> descriptionTranslations;
  final IconData icon;
  final String iconCode;
  final String? imageUrl;
  final bool isActive;

  SubcategoryModel({
    required this.id,
    required this.categoryId,
    required this.name,
    this.nameTranslations = const {},
    required this.description,
    this.descriptionTranslations = const {},
    required this.icon,
    required this.iconCode,
    this.imageUrl,
    this.isActive = true,
  });

  // Get translated name
  String getTranslatedName(LanguageProvider lang) {
    final locale = lang.locale.languageCode;
    if (nameTranslations.containsKey(locale) && nameTranslations[locale]!.isNotEmpty) {
      return nameTranslations[locale]!;
    }
    // Fallback to English
    if (nameTranslations.containsKey('en') && nameTranslations['en']!.isNotEmpty) {
      return nameTranslations['en']!;
    }
    return name;
  }

  // Get translated description
  String getTranslatedDescription(LanguageProvider lang) {
    final locale = lang.locale.languageCode;
    if (descriptionTranslations.containsKey(locale) && descriptionTranslations[locale]!.isNotEmpty) {
      return descriptionTranslations[locale]!;
    }
    // Fallback to English
    if (descriptionTranslations.containsKey('en') && descriptionTranslations['en']!.isNotEmpty) {
      return descriptionTranslations['en']!;
    }
    return description;
  }

  factory SubcategoryModel.fromMap(Map<String, dynamic> map, String id) {
    String? imgUrl = map['imageUrl'] ?? map['iconUrl'] ?? map['image'] ?? map['pic'] ?? map['url'];
    return SubcategoryModel(
      id: id,
      categoryId: map['categoryId'] ?? '',
      name: map['name'] ?? '',
      nameTranslations: Map<String, String>.from(map['nameTranslations'] ?? {}),
      description: map['description'] ?? '',
      descriptionTranslations: Map<String, String>.from(map['descriptionTranslations'] ?? {}),
      icon: CategoryModel.getIconFromCode(map['iconCode'] ?? ''),
      iconCode: map['iconCode'] ?? '',
      imageUrl: imgUrl,
      isActive: map['isActive'] ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubcategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'name': name,
      'nameTranslations': nameTranslations,
      'description': description,
      'descriptionTranslations': descriptionTranslations,
      'iconCode': iconCode,
      'imageUrl': imageUrl,
      'isActive': isActive,
    };
  }

  SubcategoryModel copyWith({
    String? id,
    String? categoryId,
    String? name,
    Map<String, String>? nameTranslations,
    String? description,
    Map<String, String>? descriptionTranslations,
    IconData? icon,
    String? iconCode,
    String? imageUrl,
    bool? isActive,
  }) {
    return SubcategoryModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      nameTranslations: nameTranslations ?? this.nameTranslations,
      description: description ?? this.description,
      descriptionTranslations: descriptionTranslations ?? this.descriptionTranslations,
      icon: icon ?? this.icon,
      iconCode: iconCode ?? this.iconCode,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
    );
  }
}

class CategoryModel {
  final String id;
  final String name;
  final Map<String, String> nameTranslations;
  final String description;
  final Map<String, String> descriptionTranslations;
  final String? iconUrl;
  final Timestamp? createdAt;
  final IconData icon;
  final String iconCode;
  final bool isActive;
  final List<SubcategoryModel> subcategories;

  CategoryModel({
    required this.id,
    required this.name,
    this.nameTranslations = const {},
    required this.description,
    this.descriptionTranslations = const {},
    this.iconUrl,
    this.createdAt,
    required this.icon,
    required this.iconCode,
    this.isActive = true,
    required this.subcategories,
  });

  // Get translated name
  String getTranslatedName(LanguageProvider lang) {
    final locale = lang.locale.languageCode;
    if (nameTranslations.containsKey(locale) && nameTranslations[locale]!.isNotEmpty) {
      return nameTranslations[locale]!;
    }
    // Fallback to English
    if (nameTranslations.containsKey('en') && nameTranslations['en']!.isNotEmpty) {
      return nameTranslations['en']!;
    }
    return name;
  }

  // Get translated description
  String getTranslatedDescription(LanguageProvider lang) {
    final locale = lang.locale.languageCode;
    if (descriptionTranslations.containsKey(locale) && descriptionTranslations[locale]!.isNotEmpty) {
      return descriptionTranslations[locale]!;
    }
    // Fallback to English
    if (descriptionTranslations.containsKey('en') && descriptionTranslations['en']!.isNotEmpty) {
      return descriptionTranslations['en']!;
    }
    return description;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel.fromMap(data, doc.id);
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    String? imgUrl = map['iconUrl'] ?? map['imageUrl'] ?? map['image'] ?? map['pic'] ?? map['url'];
    return CategoryModel(
      id: id,
      name: map['name'] ?? '',
      nameTranslations: Map<String, String>.from(map['nameTranslations'] ?? {}),
      description: map['description'] ?? '',
      descriptionTranslations: Map<String, String>.from(map['descriptionTranslations'] ?? {}),
      iconUrl: imgUrl,
      createdAt: map['createdAt'],
      icon: getIconFromCode(map['iconCode'] ?? ''),
      iconCode: map['iconCode'] ?? '',
      isActive: map['isActive'] ?? true,
      subcategories: [], // Subcategories are usually fetched separately or as a subcollection
    );
  }

  static IconData getIconFromCode(String iconCode) {
    switch (iconCode) {
      case 'house_fill':
        return CupertinoIcons.house_fill;
      case 'briefcase_fill':
        return CupertinoIcons.briefcase_fill;
      case 'sparkles':
        return CupertinoIcons.sparkles;
      case 'rectangle_fill':
        return CupertinoIcons.rectangle_fill;
      case 'wrench_fill':
        return CupertinoIcons.wrench_fill;
      case 'drop_fill':
        return CupertinoIcons.drop_fill;
      case 'settings':
        return CupertinoIcons.settings;
      case 'bolt_fill':
        return CupertinoIcons.bolt_fill;
      case 'lightbulb_fill':
        return CupertinoIcons.lightbulb_fill;
      case 'hammer_fill':
        return CupertinoIcons.hammer_fill;
      case 'paintbrush_fill':
        return CupertinoIcons.paintbrush_fill;
      case 'leaf_fill':
        return CupertinoIcons.wrench_fill;
      case 'tree_fill':
        return CupertinoIcons.cloud_fill;
      case 'car_fill':
        return CupertinoIcons.car_fill;
      case 'road_fill':
        return CupertinoIcons.location_fill;
      case 'cube_fill':
        return CupertinoIcons.cube_fill;
      case 'exclamationmark_triangle_fill':
        return CupertinoIcons.exclamationmark_triangle_fill;
      case 'gear_alt_fill':
        return CupertinoIcons.gear_alt_fill;
      case 'pencil':
        return CupertinoIcons.pencil;
      case 'text_bubble_fill':
        return CupertinoIcons.text_bubble_fill;
      case 'number_square_fill':
        return CupertinoIcons.number_square_fill;
      case 'heart_fill':
        return CupertinoIcons.heart_fill;
      case 'lab_flask':
        return CupertinoIcons.lab_flask;
      case 'scissors':
        return CupertinoIcons.scissors;
      case 'leaf_arrow_circlepath':
        return CupertinoIcons.leaf_arrow_circlepath;
      case 'desktopcomputer':
        return CupertinoIcons.desktopcomputer;
      case 'device_phone_portrait':
        return CupertinoIcons.device_phone_portrait;
      case 'cart_fill':
        return CupertinoIcons.cart_fill;
      case 'tray_fill':
        return CupertinoIcons.tray_fill;
      case 'plus_circle_fill':
        return CupertinoIcons.plus_circle_fill;
      case 'circle_fill':
      default:
        return CupertinoIcons.circle_fill;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nameTranslations': nameTranslations,
      'description': description,
      'descriptionTranslations': descriptionTranslations,
      'iconUrl': iconUrl,
      'createdAt': createdAt,
      'iconCode': iconCode,
      'isActive': isActive,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    Map<String, String>? nameTranslations,
    String? description,
    Map<String, String>? descriptionTranslations,
    String? iconUrl,
    Timestamp? createdAt,
    IconData? icon,
    String? iconCode,
    bool? isActive,
    List<SubcategoryModel>? subcategories,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      nameTranslations: nameTranslations ?? this.nameTranslations,
      description: description ?? this.description,
      descriptionTranslations: descriptionTranslations ?? this.descriptionTranslations,
      iconUrl: iconUrl ?? this.iconUrl,
      createdAt: createdAt ?? this.createdAt,
      icon: icon ?? this.icon,
      iconCode: iconCode ?? this.iconCode,
      isActive: isActive ?? this.isActive,
      subcategories: subcategories ?? this.subcategories,
    );
  }
}
