import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:service_app/models/CategoryModel.dart';

class CategoriesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all categories from Firestore services
  Future<List<CategoryModel>> getAllCategories() async {
    try {
      // Get all active services from Firestore
      final servicesSnapshot = await _firestore
          .collection('services')
          .where('isActive', isEqualTo: true)
          .get();

      // Map to store categories and their subcategories
      final categoryMap = <String, Map<String, SubcategoryModel>>{};

      // Process services to extract categories and subcategories
      for (var doc in servicesSnapshot.docs) {
        final data = doc.data();
        final serviceCategory = data['category']?.toString().trim() ?? '';
        final serviceSubcategory = data['subcategory']?.toString().trim() ?? '';

        if (serviceCategory.isNotEmpty) {
          // Initialize category if not exists
          categoryMap[serviceCategory] ??= {};

          // Add subcategory if exists
          if (serviceSubcategory.isNotEmpty) {
            categoryMap[serviceCategory]![serviceSubcategory] =
                SubcategoryModel(
              id: '${serviceCategory}_$serviceSubcategory'.replaceAll(' ', '_'),
              name: serviceSubcategory,
              description: '$serviceSubcategory under $serviceCategory',
              icon: _getIconForSubcategory(serviceSubcategory), // Fixed
              iconCode: _getIconCodeForSubcategory(serviceSubcategory), // Fixed
            );
          }
        }
      }

      // Convert map to CategoryModel list
      final categories = <CategoryModel>[];
      categoryMap.forEach((categoryName, subcategoriesMap) {
        categories.add(CategoryModel(
          id: categoryName.toLowerCase().replaceAll(' ', '_'),
          name: categoryName,
          description: '$categoryName Services',
          icon: _getIconForCategory(categoryName), // Fixed
          iconCode: _getIconCodeForCategory(categoryName), // Fixed
          subcategories: subcategoriesMap.values.toList(),
        ));
      });

      // Merge with default categories
      final defaultCategories = CategoryModel.defaultCategories;
      final mergedCategories = <CategoryModel>[];

      // Add all default categories first
      for (var defaultCat in defaultCategories) {
        final existingCat = categories.firstWhere(
          (cat) => cat.name.toLowerCase() == defaultCat.name.toLowerCase(),
          orElse: () => defaultCat,
        );

        // Merge subcategories
        final defaultSubs = defaultCat.subcategories.map((e) => e.name).toSet();
        final existingSubs =
            existingCat.subcategories.map((e) => e.name).toSet();

        if (defaultSubs.isNotEmpty) {
          for (var sub in defaultCat.subcategories) {
            if (!existingSubs.contains(sub.name)) {
              existingCat.subcategories.add(sub);
            }
          }
        }

        mergedCategories.add(existingCat);
      }

      // Add categories from Firestore not in defaults
      for (var firestoreCat in categories) {
        if (!mergedCategories.any((cat) => cat.name == firestoreCat.name)) {
          mergedCategories.add(firestoreCat);
        }
      }

      return mergedCategories;
    } catch (e) {
      print('❌ Error getting categories: $e');
      return CategoryModel.defaultCategories;
    }
  }

// Helper methods for icon mapping
  IconData _getIconForCategory(String categoryName) {
    final name = categoryName.toLowerCase();

    if (name.contains('clean')) return CupertinoIcons.house_fill;
    if (name.contains('plumb')) return CupertinoIcons.wrench_fill;
    if (name.contains('electric')) return CupertinoIcons.bolt_fill;
    if (name.contains('carpent')) return CupertinoIcons.hammer_fill;
    if (name.contains('paint')) return CupertinoIcons.paintbrush_fill;
    if (name.contains('garden')) return CupertinoIcons.clear_fill;
    if (name.contains('mov') || name.contains('transport'))
      return CupertinoIcons.car_fill;
    if (name.contains('repair')) return CupertinoIcons.wrench_fill;
    if (name.contains('install')) return CupertinoIcons.settings;
    if (name.contains('teach') || name.contains('tutor'))
      return CupertinoIcons.pencil;
    if (name.contains('health') || name.contains('medical'))
      return CupertinoIcons.heart_fill;
    if (name.contains('beauty')) return CupertinoIcons.scissors;
    if (name.contains('home')) return CupertinoIcons.house_fill;
    if (name.contains('tech') || name.contains('computer'))
      return CupertinoIcons.desktopcomputer;
    if (name.contains('food')) return CupertinoIcons.cart_fill;

    return CupertinoIcons.circle_fill;
  }

  String _getIconCodeForCategory(String categoryName) {
    final name = categoryName.toLowerCase();

    if (name.contains('clean')) return 'house_fill';
    if (name.contains('plumb')) return 'wrench_fill';
    if (name.contains('electric')) return 'bolt_fill';
    if (name.contains('carpent')) return 'hammer_fill';
    if (name.contains('paint')) return 'paintbrush_fill';
    if (name.contains('garden')) return 'clear_fill';
    if (name.contains('mov') || name.contains('transport')) return 'car_fill';
    if (name.contains('repair')) return 'wrench_fill';
    if (name.contains('install')) return 'settings';
    if (name.contains('teach') || name.contains('tutor')) return 'pencil';
    if (name.contains('health') || name.contains('medical'))
      return 'heart_fill';
    if (name.contains('beauty')) return 'scissors';
    if (name.contains('home')) return 'house_fill';
    if (name.contains('tech') || name.contains('computer'))
      return 'desktopcomputer';
    if (name.contains('food')) return 'cart_fill';

    return 'circle_fill';
  }

  IconData _getIconForSubcategory(String subcategoryName) {
    // Use similar logic or default to circle
    return CupertinoIcons.circle_fill;
  }

  String _getIconCodeForSubcategory(String subcategoryName) {
    return 'circle_fill';
  }

  // Get categories as map for dropdowns
  Future<Map<String, List<String>>> getCategoriesForFilter() async {
    final categories = await getAllCategories();
    final result = <String, List<String>>{};

    for (var category in categories) {
      result[category.name] =
          category.subcategories.map((sub) => sub.name).toList();
    }

    return result;
  }

  // Get category by name
  CategoryModel? getCategoryByName(String name) {
    try {
      final defaultCategories = CategoryModel.defaultCategories;
      final lowerName = name.toLowerCase();

      for (var category in defaultCategories) {
        if (category.name.toLowerCase() == lowerName) {
          return category;
        }
      }

      // If not found, create a simple category
      return CategoryModel(
        id: lowerName.replaceAll(' ', '_'),
        name: name,
        description: '$name Services',
        icon: CupertinoIcons.circle_fill,
        iconCode: 'circle_fill',
        subcategories: [],
      );
    } catch (e) {
      print('❌ Error in getCategoryByName for "$name": $e');
      return null;
    }
  }

  // Get subcategory by name within a category
  Future<SubcategoryModel?> getSubcategoryByName(
      String categoryName, String subcategoryName) async {
    final category = getCategoryByName(categoryName);
    if (category == null) return null;

    return category.subcategories.firstWhere(
      (sub) => sub.name.toLowerCase() == subcategoryName.toLowerCase(),
      orElse: () => SubcategoryModel(
        id: '${categoryName}_$subcategoryName'.replaceAll(' ', '_'),
        name: subcategoryName,
        description: '$subcategoryName under $categoryName',
        icon: CupertinoIcons.circle_fill,
        iconCode: 'circle_fill',
      ),
    );
  }
}
