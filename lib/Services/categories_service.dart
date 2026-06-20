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
            final subcategoryKey =
                '${serviceCategory}_$serviceSubcategory'.replaceAll(' ', '_');
            final subcategoryId = subcategoryKey.toLowerCase();

            categoryMap[serviceCategory]![serviceSubcategory] =
                SubcategoryModel(
              id: subcategoryId,
              name: serviceSubcategory,
              nameKey:
                  _generateSubcategoryKey(serviceCategory, serviceSubcategory),
              description: '$serviceSubcategory under $serviceCategory',
              descriptionKey:
                  '${_generateSubcategoryKey(serviceCategory, serviceSubcategory)}_desc',
              icon: _getIconForSubcategory(serviceSubcategory),
              iconCode: _getIconCodeForSubcategory(serviceSubcategory),
            );
          }
        }
      }

      // Convert map to CategoryModel list
      final categories = <CategoryModel>[];
      categoryMap.forEach((categoryName, subcategoriesMap) {
        final categoryKey = _generateCategoryKey(categoryName);

        categories.add(CategoryModel(
          id: categoryName.toLowerCase().replaceAll(' ', '_'),
          name: categoryName,
          nameKey: categoryKey,
          description: '$categoryName Services',
          descriptionKey: '${categoryKey}_desc',
          icon: _getIconForCategory(categoryName),
          iconCode: _getIconCodeForCategory(categoryName),
          subcategories: subcategoriesMap.values.toList(),
        ));
      });

      // Merge with default categories (which already have translation keys)
      final defaultCategories = CategoryModel.defaultCategories;
      final mergedCategories = <CategoryModel>[];

      // Add all default categories first (preserve their translation keys)
      for (var defaultCat in defaultCategories) {
        final existingCat = categories.firstWhere(
          (cat) => cat.name.toLowerCase() == defaultCat.name.toLowerCase(),
          orElse: () => defaultCat,
        );

        // Use the default category's translation keys if available
        if (existingCat != defaultCat) {
          // Preserve Firestore subcategories but keep default translation keys
          final mergedCat = CategoryModel(
            id: existingCat.id,
            name: existingCat.name,
            nameKey: defaultCat.nameKey, // Keep default translation key
            description: existingCat.description,
            descriptionKey:
                defaultCat.descriptionKey, // Keep default description key
            icon: existingCat.icon,
            iconCode: existingCat.iconCode,
            subcategories: existingCat.subcategories,
          );

          // Merge subcategories
          final defaultSubs =
              defaultCat.subcategories.map((e) => e.name).toSet();
          final existingSubs =
              existingCat.subcategories.map((e) => e.name).toSet();

          if (defaultSubs.isNotEmpty) {
            for (var sub in defaultCat.subcategories) {
              if (!existingSubs.contains(sub.name)) {
                mergedCat.subcategories.add(sub);
              }
            }
          }

          mergedCategories.add(mergedCat);
        } else {
          mergedCategories.add(defaultCat);
        }
      }

      // Add categories from Firestore not in defaults (generate translation keys for them)
      for (var firestoreCat in categories) {
        if (!mergedCategories.any((cat) => cat.name == firestoreCat.name)) {
          final categoryKey = _generateCategoryKey(firestoreCat.name);

          final newCategory = CategoryModel(
            id: firestoreCat.id,
            name: firestoreCat.name,
            nameKey: categoryKey,
            description: firestoreCat.description,
            descriptionKey: '${categoryKey}_desc',
            icon: firestoreCat.icon,
            iconCode: firestoreCat.iconCode,
            subcategories: firestoreCat.subcategories.map((sub) {
              final subKey =
                  _generateSubcategoryKey(firestoreCat.name, sub.name);
              return SubcategoryModel(
                id: sub.id,
                name: sub.name,
                nameKey: subKey,
                description: sub.description,
                descriptionKey: '${subKey}_desc',
                icon: sub.icon,
                iconCode: sub.iconCode,
              );
            }).toList(),
          );
          mergedCategories.add(newCategory);
        }
      }

      return mergedCategories;
    } catch (e) {
      print('❌ Error getting categories: $e');
      return CategoryModel.defaultCategories;
    }
  }

  // Generate translation key for category
  String _generateCategoryKey(String categoryName) {
    final name = categoryName.toLowerCase().trim().replaceAll(' ', '_');

    if (name.contains('clean')) return 'category_cleaning';
    if (name.contains('plumb')) return 'category_plumbing';
    if (name.contains('electric')) return 'category_electrical';
    if (name.contains('carpent')) return 'category_carpentry';
    if (name.contains('paint')) return 'category_painting';
    if (name.contains('garden')) return 'category_gardening';
    if (name.contains('mov') || name.contains('transport')) {
      return 'category_moving';
    }
    if (name.contains('repair')) return 'category_repair';
    if (name.contains('install')) return 'category_installation';
    if (name.contains('teach') || name.contains('tutor')) {
      return 'category_tutoring';
    }
    if (name.contains('health') || name.contains('medical')) {
      return 'category_health';
    }
    if (name.contains('beauty')) return 'category_beauty';
    if (name.contains('home')) return 'category_home';
    if (name.contains('tech') || name.contains('computer')) {
      return 'category_tech';
    }
    if (name.contains('food')) return 'category_food';

    return 'category_other';
  }

  // Generate translation key for subcategory
  String _generateSubcategoryKey(String categoryName, String subcategoryName) {
    final cat = categoryName.toLowerCase().trim();
    final sub = subcategoryName.toLowerCase().trim().replaceAll(' ', '_');

    // Cleaning subcategories
    if (cat.contains('clean')) {
      if (sub.contains('home')) return 'subcategory_home_cleaning';
      if (sub.contains('office')) return 'subcategory_office_cleaning';
      if (sub.contains('deep')) return 'subcategory_deep_cleaning';
      if (sub.contains('carpet')) return 'subcategory_carpet_cleaning';
    }

    // Plumbing subcategories
    if (cat.contains('plumb')) {
      if (sub.contains('pipe')) return 'subcategory_pipe_repair';
      if (sub.contains('leak')) return 'subcategory_leak_fixing';
      if (sub.contains('fixture') ||
          sub.contains('sink') ||
          sub.contains('toilet')) {
        return 'subcategory_fixture_installation';
      }
    }

    // Electrical subcategories
    if (cat.contains('electric')) {
      if (sub.contains('wiring')) return 'subcategory_wiring';
      if (sub.contains('fixture') ||
          sub.contains('light') ||
          sub.contains('switch')) {
        return 'subcategory_electrical_fixture';
      }
      if (sub.contains('repair')) return 'subcategory_electrical_repair';
    }

    // Carpentry subcategories
    if (cat.contains('carpent')) {
      if (sub.contains('furniture') && sub.contains('making')) {
        return 'subcategory_furniture_making';
      }
      if (sub.contains('repair')) return 'subcategory_carpentry_repair';
      if (sub.contains('install') || sub.contains('assembly')) {
        return 'subcategory_carpentry_installation';
      }
    }

    // Painting subcategories
    if (cat.contains('paint')) {
      if (sub.contains('interior')) return 'subcategory_interior_painting';
      if (sub.contains('exterior')) return 'subcategory_exterior_painting';
      if (sub.contains('decorative')) return 'subcategory_decorative_painting';
    }

    // Gardening subcategories
    if (cat.contains('garden')) {
      if (sub.contains('lawn')) return 'subcategory_lawn_care';
      if (sub.contains('landscap')) return 'subcategory_landscaping';
      if (sub.contains('plant')) return 'subcategory_planting';
    }

    // Moving subcategories
    if (cat.contains('mov') || cat.contains('transport')) {
      if (sub.contains('local')) return 'subcategory_local_moving';
      if (sub.contains('long') || sub.contains('distance')) {
        return 'subcategory_long_distance';
      }
      if (sub.contains('pack')) return 'subcategory_packing';
    }

    // Repair subcategories
    if (cat.contains('repair')) {
      if (sub.contains('appliance')) return 'subcategory_appliance_repair';
      if (sub.contains('maintenance')) return 'subcategory_general_maintenance';
      if (sub.contains('emergency')) return 'subcategory_emergency_repair';
    }

    // Installation subcategories
    if (cat.contains('install')) {
      if (sub.contains('appliance')) {
        return 'subcategory_appliance_installation';
      }
      if (sub.contains('furniture')) return 'subcategory_furniture_assembly';
      if (sub.contains('equipment')) return 'subcategory_equipment_setup';
    }

    // Tutoring subcategories
    if (cat.contains('teach') || cat.contains('tutor')) {
      if (sub.contains('academic')) return 'subcategory_academic_tutoring';
      if (sub.contains('language')) return 'subcategory_language_tutoring';
      if (sub.contains('test') || sub.contains('exam')) {
        return 'subcategory_test_prep';
      }
    }

    // Health subcategories
    if (cat.contains('health') || cat.contains('medical')) {
      if (sub.contains('consult')) return 'subcategory_medical_consultation';
      if (sub.contains('therapy')) return 'subcategory_therapy';
      if (sub.contains('nursing')) return 'subcategory_nursing';
    }

    // Beauty subcategories
    if (cat.contains('beauty')) {
      if (sub.contains('hair')) return 'subcategory_hair_styling';
      if (sub.contains('makeup')) return 'subcategory_makeup';
      if (sub.contains('spa') || sub.contains('massage')) {
        return 'subcategory_spa';
      }
    }

    // Home subcategories
    if (cat.contains('home')) {
      if (sub.contains('maintenance')) return 'subcategory_home_maintenance';
      if (sub.contains('smart')) return 'subcategory_smart_home';
      if (sub.contains('renovation')) return 'subcategory_renovation';
    }

    // Tech subcategories
    if (cat.contains('tech') || cat.contains('computer')) {
      if (sub.contains('computer') ||
          sub.contains('pc') ||
          sub.contains('laptop')) {
        return 'subcategory_computer_repair';
      }
      if (sub.contains('mobile') || sub.contains('phone')) {
        return 'subcategory_mobile_repair';
      }
      if (sub.contains('it') || sub.contains('support')) {
        return 'subcategory_it_support';
      }
    }

    // Food subcategories
    if (cat.contains('food')) {
      if (sub.contains('cater')) return 'subcategory_catering';
      if (sub.contains('chef')) return 'subcategory_private_chef';
      if (sub.contains('meal') || sub.contains('prep')) {
        return 'subcategory_meal_prep';
      }
    }

    return 'subcategory_general';
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
    if (name.contains('mov') || name.contains('transport')) {
      return CupertinoIcons.car_fill;
    }
    if (name.contains('repair')) return CupertinoIcons.wrench_fill;
    if (name.contains('install')) return CupertinoIcons.settings;
    if (name.contains('teach') || name.contains('tutor')) {
      return CupertinoIcons.pencil;
    }
    if (name.contains('health') || name.contains('medical')) {
      return CupertinoIcons.heart_fill;
    }
    if (name.contains('beauty')) return CupertinoIcons.scissors;
    if (name.contains('home')) return CupertinoIcons.house_fill;
    if (name.contains('tech') || name.contains('computer')) {
      return CupertinoIcons.desktopcomputer;
    }
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
    if (name.contains('health') || name.contains('medical')) {
      return 'heart_fill';
    }
    if (name.contains('beauty')) return 'scissors';
    if (name.contains('home')) return 'house_fill';
    if (name.contains('tech') || name.contains('computer')) {
      return 'desktopcomputer';
    }
    if (name.contains('food')) return 'cart_fill';

    return 'circle_fill';
  }

  IconData _getIconForSubcategory(String subcategoryName) {
    final name = subcategoryName.toLowerCase();

    if (name.contains('home') || name.contains('house')) {
      return CupertinoIcons.house_fill;
    }
    if (name.contains('office')) return CupertinoIcons.briefcase_fill;
    if (name.contains('deep')) return CupertinoIcons.sparkles;
    if (name.contains('carpet')) return CupertinoIcons.rectangle_fill;
    if (name.contains('pipe')) return CupertinoIcons.wrench_fill;
    if (name.contains('leak')) return CupertinoIcons.drop_fill;
    if (name.contains('fixture') ||
        name.contains('sink') ||
        name.contains('toilet')) {
      return CupertinoIcons.settings;
    }
    if (name.contains('wiring')) return CupertinoIcons.bolt_fill;
    if (name.contains('light')) return CupertinoIcons.lightbulb_fill;
    if (name.contains('furniture') && name.contains('making')) {
      return CupertinoIcons.hammer_fill;
    }
    if (name.contains('assembly')) return CupertinoIcons.hammer_fill;
    if (name.contains('interior') || name.contains('exterior')) {
      return CupertinoIcons.paintbrush_fill;
    }
    if (name.contains('lawn')) return CupertinoIcons.clear_fill;
    if (name.contains('landscap')) return CupertinoIcons.tram_fill;
    if (name.contains('plant')) return CupertinoIcons.plus_circle_fill;
    if (name.contains('local') || name.contains('long')) {
      return CupertinoIcons.car_fill;
    }
    if (name.contains('pack')) return CupertinoIcons.cube_fill;
    if (name.contains('appliance')) return CupertinoIcons.wrench_fill;
    if (name.contains('emergency')) {
      return CupertinoIcons.exclamationmark_triangle_fill;
    }
    if (name.contains('computer') || name.contains('pc')) {
      return CupertinoIcons.desktopcomputer;
    }
    if (name.contains('mobile') || name.contains('phone')) {
      return CupertinoIcons.device_phone_portrait;
    }
    if (name.contains('cater')) return CupertinoIcons.cart_fill;
    if (name.contains('chef')) return CupertinoIcons.house_fill;
    if (name.contains('meal')) return CupertinoIcons.tray_fill;
    if (name.contains('academic') || name.contains('test')) {
      return CupertinoIcons.number_square_fill;
    }
    if (name.contains('language')) return CupertinoIcons.text_bubble_fill;
    if (name.contains('consult') || name.contains('therapy')) {
      return CupertinoIcons.heart_fill;
    }
    if (name.contains('hair')) return CupertinoIcons.scissors;
    if (name.contains('makeup')) return CupertinoIcons.sparkles;
    if (name.contains('spa')) return CupertinoIcons.leaf_arrow_circlepath;

    return CupertinoIcons.circle_fill;
  }

  String _getIconCodeForSubcategory(String subcategoryName) {
    final name = subcategoryName.toLowerCase();

    if (name.contains('home') || name.contains('house')) return 'house_fill';
    if (name.contains('office')) return 'briefcase_fill';
    if (name.contains('deep')) return 'sparkles';
    if (name.contains('carpet')) return 'rectangle_fill';
    if (name.contains('pipe')) return 'wrench_fill';
    if (name.contains('leak')) return 'drop_fill';
    if (name.contains('fixture') ||
        name.contains('sink') ||
        name.contains('toilet')) {
      return 'settings';
    }
    if (name.contains('wiring')) return 'bolt_fill';
    if (name.contains('light')) return 'lightbulb_fill';
    if (name.contains('furniture') && name.contains('making')) {
      return 'hammer_fill';
    }
    if (name.contains('assembly')) return 'hammer_fill';
    if (name.contains('interior') || name.contains('exterior')) {
      return 'paintbrush_fill';
    }
    if (name.contains('lawn')) return 'clear_fill';
    if (name.contains('landscap')) return 'tram_fill';
    if (name.contains('plant')) return 'plus_circle_fill';
    if (name.contains('local') || name.contains('long')) return 'car_fill';
    if (name.contains('pack')) return 'cube_fill';
    if (name.contains('appliance')) return 'wrench_fill';
    if (name.contains('emergency')) return 'exclamationmark_triangle_fill';
    if (name.contains('computer') || name.contains('pc')) {
      return 'desktopcomputer';
    }
    if (name.contains('mobile') || name.contains('phone')) {
      return 'device_phone_portrait';
    }
    if (name.contains('cater')) return 'cart_fill';
    if (name.contains('chef')) return 'house_fill';
    if (name.contains('meal')) return 'tray_fill';
    if (name.contains('academic') || name.contains('test')) {
      return 'number_square_fill';
    }
    if (name.contains('language')) return 'text_bubble_fill';
    if (name.contains('consult') || name.contains('therapy')) {
      return 'heart_fill';
    }
    if (name.contains('hair')) return 'scissors';
    if (name.contains('makeup')) return 'sparkles';
    if (name.contains('spa')) return 'leaf_arrow_circlepath';

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

  // Get category by name with translation keys
  CategoryModel? getCategoryByName(String name) {
    try {
      final defaultCategories = CategoryModel.defaultCategories;
      final lowerName = name.toLowerCase();

      for (var category in defaultCategories) {
        if (category.name.toLowerCase() == lowerName) {
          return category;
        }
      }

      // If not found, create a simple category with translation key
      final categoryKey = _generateCategoryKey(name);

      return CategoryModel(
        id: lowerName.replaceAll(' ', '_'),
        name: name,
        nameKey: categoryKey,
        description: '$name Services',
        descriptionKey: '${categoryKey}_desc',
        icon: _getIconForCategory(name),
        iconCode: _getIconCodeForCategory(name),
        subcategories: [],
      );
    } catch (e) {
      print('❌ Error in getCategoryByName for "$name": $e');
      return null;
    }
  }

  // Get subcategory by name within a category with translation keys
  Future<SubcategoryModel?> getSubcategoryByName(
      String categoryName, String subcategoryName) async {
    final category = getCategoryByName(categoryName);
    if (category == null) return null;

    final existingSub = category.subcategories.firstWhere(
      (sub) => sub.name.toLowerCase() == subcategoryName.toLowerCase(),
      orElse: () => SubcategoryModel(
        id: '${categoryName}_$subcategoryName'.replaceAll(' ', '_'),
        name: subcategoryName,
        nameKey: _generateSubcategoryKey(categoryName, subcategoryName),
        description: '$subcategoryName under $categoryName',
        descriptionKey:
            '${_generateSubcategoryKey(categoryName, subcategoryName)}_desc',
        icon: _getIconForSubcategory(subcategoryName),
        iconCode: _getIconCodeForSubcategory(subcategoryName),
      ),
    );

    return existingSub;
  }
}
