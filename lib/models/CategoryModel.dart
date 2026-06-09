import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_app/providers/language_provider.dart';

class SubcategoryModel {
  final String id;
  final String name;
  final String nameKey; // Translation key
  final String description;
  final String descriptionKey; // Translation key
  final IconData icon;
  final String iconCode;
  final bool isActive;

  SubcategoryModel({
    required this.id,
    required this.name,
    required this.nameKey,
    required this.description,
    required this.descriptionKey,
    required this.icon,
    required this.iconCode,
    this.isActive = true,
  });

  // Get translated name
  String getTranslatedName(LanguageProvider lang) {
    return nameKey.isNotEmpty ? lang.tr(nameKey, category: 'categories') : name;
  }

  // Get translated description
  String getTranslatedDescription(LanguageProvider lang) {
    return descriptionKey.isNotEmpty
        ? lang.tr(descriptionKey, category: 'categories')
        : description;
  }

  factory SubcategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return SubcategoryModel(
      id: id,
      name: map['name'] ?? '',
      nameKey: map['nameKey'] ?? '',
      description: map['description'] ?? '',
      descriptionKey: map['descriptionKey'] ?? '',
      icon: CategoryModel.getIconFromCode(map['iconCode'] ?? ''),
      iconCode: map['iconCode'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nameKey': nameKey,
      'description': description,
      'descriptionKey': descriptionKey,
      'iconCode': iconCode,
      'isActive': isActive,
    };
  }
}

class CategoryModel {
  final String id;
  final String name;
  final String nameKey; // Translation key
  final String description;
  final String descriptionKey; // Translation key
  final String? iconUrl;
  final Timestamp? createdAt;
  final IconData icon;
  final String iconCode;
  final bool isActive;
  final List<SubcategoryModel> subcategories;

  CategoryModel({
    required this.id,
    required this.name,
    required this.nameKey,
    required this.description,
    required this.descriptionKey,
    this.iconUrl,
    this.createdAt,
    required this.icon,
    required this.iconCode,
    this.isActive = true,
    required this.subcategories,
  });

  // Get translated name
  String getTranslatedName(LanguageProvider lang) {
    return nameKey.isNotEmpty ? lang.tr(nameKey, category: 'categories') : name;
  }

  // Get translated description
  String getTranslatedDescription(LanguageProvider lang) {
    return descriptionKey.isNotEmpty
        ? lang.tr(descriptionKey, category: 'categories')
        : description;
  }

  static List<CategoryModel> get defaultCategories {
    return [
      CategoryModel(
        id: '1',
        name: 'Cleaning',
        nameKey: 'category_cleaning',
        description: 'House cleaning and maintenance services',
        descriptionKey: 'category_cleaning_desc',
        icon: CupertinoIcons.house_fill,
        iconCode: 'house_fill',
        subcategories: [
          SubcategoryModel(
            id: '1-1',
            name: 'Home Cleaning',
            nameKey: 'subcategory_home_cleaning',
            description: 'General house cleaning services',
            descriptionKey: 'subcategory_home_cleaning_desc',
            icon: CupertinoIcons.house_fill,
            iconCode: 'house_fill',
          ),
          SubcategoryModel(
            id: '1-2',
            name: 'Office Cleaning',
            nameKey: 'subcategory_office_cleaning',
            description: 'Office and commercial cleaning',
            descriptionKey: 'subcategory_office_cleaning_desc',
            icon: CupertinoIcons.briefcase_fill,
            iconCode: 'briefcase_fill',
          ),
          SubcategoryModel(
            id: '1-3',
            name: 'Deep Cleaning',
            nameKey: 'subcategory_deep_cleaning',
            description: 'Thorough deep cleaning services',
            descriptionKey: 'subcategory_deep_cleaning_desc',
            icon: CupertinoIcons.sparkles,
            iconCode: 'sparkles',
          ),
          SubcategoryModel(
            id: '1-4',
            name: 'Carpet Cleaning',
            nameKey: 'subcategory_carpet_cleaning',
            description: 'Professional carpet cleaning',
            descriptionKey: 'subcategory_carpet_cleaning_desc',
            icon: CupertinoIcons.rectangle_fill,
            iconCode: 'rectangle_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '2',
        name: 'Plumbing',
        nameKey: 'category_plumbing',
        description: 'Plumbing and pipe repair services',
        descriptionKey: 'category_plumbing_desc',
        icon: CupertinoIcons.wrench_fill,
        iconCode: 'wrench_fill',
        subcategories: [
          SubcategoryModel(
            id: '2-1',
            name: 'Pipe Repair',
            nameKey: 'subcategory_pipe_repair',
            description: 'Pipe fixing and replacement',
            descriptionKey: 'subcategory_pipe_repair_desc',
            icon: CupertinoIcons.wrench_fill,
            iconCode: 'wrench_fill',
          ),
          SubcategoryModel(
            id: '2-2',
            name: 'Leak Fixing',
            nameKey: 'subcategory_leak_fixing',
            description: 'Water leak detection and repair',
            descriptionKey: 'subcategory_leak_fixing_desc',
            icon: CupertinoIcons.drop_fill,
            iconCode: 'drop_fill',
          ),
          SubcategoryModel(
            id: '2-3',
            name: 'Fixture Installation',
            nameKey: 'subcategory_fixture_installation',
            description: 'Sink, toilet, and shower installation',
            descriptionKey: 'subcategory_fixture_installation_desc',
            icon: CupertinoIcons.settings,
            iconCode: 'settings',
          ),
        ],
      ),
      CategoryModel(
        id: '3',
        name: 'Electrical',
        nameKey: 'category_electrical',
        description: 'Electrical installation and repair',
        descriptionKey: 'category_electrical_desc',
        icon: CupertinoIcons.bolt_fill,
        iconCode: 'bolt_fill',
        subcategories: [
          SubcategoryModel(
            id: '3-1',
            name: 'Wiring',
            nameKey: 'subcategory_wiring',
            description: 'Electrical wiring services',
            descriptionKey: 'subcategory_wiring_desc',
            icon: CupertinoIcons.bolt_fill,
            iconCode: 'bolt_fill',
          ),
          SubcategoryModel(
            id: '3-2',
            name: 'Fixture Installation',
            nameKey: 'subcategory_electrical_fixture',
            description: 'Light and switch installation',
            descriptionKey: 'subcategory_electrical_fixture_desc',
            icon: CupertinoIcons.lightbulb_fill,
            iconCode: 'lightbulb_fill',
          ),
          SubcategoryModel(
            id: '3-3',
            name: 'Repair',
            nameKey: 'subcategory_electrical_repair',
            description: 'Electrical repair services',
            descriptionKey: 'subcategory_electrical_repair_desc',
            icon: CupertinoIcons.wrench_fill,
            iconCode: 'wrench_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '4',
        name: 'Carpentry',
        nameKey: 'category_carpentry',
        description: 'Woodwork and furniture services',
        descriptionKey: 'category_carpentry_desc',
        icon: CupertinoIcons.hammer_fill,
        iconCode: 'hammer_fill',
        subcategories: [
          SubcategoryModel(
            id: '4-1',
            name: 'Furniture Making',
            nameKey: 'subcategory_furniture_making',
            description: 'Custom furniture creation',
            descriptionKey: 'subcategory_furniture_making_desc',
            icon: CupertinoIcons.hammer_fill,
            iconCode: 'hammer_fill',
          ),
          SubcategoryModel(
            id: '4-2',
            name: 'Repair',
            nameKey: 'subcategory_carpentry_repair',
            description: 'Furniture repair services',
            descriptionKey: 'subcategory_carpentry_repair_desc',
            icon: CupertinoIcons.wrench_fill,
            iconCode: 'wrench_fill',
          ),
          SubcategoryModel(
            id: '4-3',
            name: 'Installation',
            nameKey: 'subcategory_carpentry_installation',
            description: 'Furniture assembly and installation',
            descriptionKey: 'subcategory_carpentry_installation_desc',
            icon: CupertinoIcons.settings,
            iconCode: 'settings',
          ),
        ],
      ),
      CategoryModel(
        id: '5',
        name: 'Painting',
        nameKey: 'category_painting',
        description: 'Painting and decoration services',
        descriptionKey: 'category_painting_desc',
        icon: CupertinoIcons.paintbrush_fill,
        iconCode: 'paintbrush_fill',
        subcategories: [
          SubcategoryModel(
            id: '5-1',
            name: 'Interior Painting',
            nameKey: 'subcategory_interior_painting',
            description: 'Indoor wall painting',
            descriptionKey: 'subcategory_interior_painting_desc',
            icon: CupertinoIcons.paintbrush_fill,
            iconCode: 'paintbrush_fill',
          ),
          SubcategoryModel(
            id: '5-2',
            name: 'Exterior Painting',
            nameKey: 'subcategory_exterior_painting',
            description: 'Outdoor wall painting',
            descriptionKey: 'subcategory_exterior_painting_desc',
            icon: CupertinoIcons.house_fill,
            iconCode: 'house_fill',
          ),
          SubcategoryModel(
            id: '5-3',
            name: 'Decorative',
            nameKey: 'subcategory_decorative_painting',
            description: 'Special decorative painting',
            descriptionKey: 'subcategory_decorative_painting_desc',
            icon: CupertinoIcons.sparkles,
            iconCode: 'sparkles',
          ),
        ],
      ),
      CategoryModel(
        id: '6',
        name: 'Gardening',
        nameKey: 'category_gardening',
        description: 'Gardening and landscaping services',
        descriptionKey: 'category_gardening_desc',
        icon: CupertinoIcons.compass_fill,
        iconCode: 'compass_fill',
        subcategories: [
          SubcategoryModel(
            id: '6-1',
            name: 'Lawn Care',
            nameKey: 'subcategory_lawn_care',
            description: 'Lawn maintenance and care',
            descriptionKey: 'subcategory_lawn_care_desc',
            icon: CupertinoIcons.clear_fill,
            iconCode: 'leaf_fill',
          ),
          SubcategoryModel(
            id: '6-2',
            name: 'Landscaping',
            nameKey: 'subcategory_landscaping',
            description: 'Garden design and landscaping',
            descriptionKey: 'subcategory_landscaping_desc',
            icon: CupertinoIcons.tram_fill,
            iconCode: 'tree_fill',
          ),
          SubcategoryModel(
            id: '6-3',
            name: 'Planting',
            nameKey: 'subcategory_planting',
            description: 'Plant installation and care',
            descriptionKey: 'subcategory_planting_desc',
            icon: CupertinoIcons.plus_circle_fill,
            iconCode: 'plus_circle_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '7',
        name: 'Moving',
        nameKey: 'category_moving',
        description: 'Moving and transportation services',
        descriptionKey: 'category_moving_desc',
        icon: CupertinoIcons.car_fill,
        iconCode: 'car_fill',
        subcategories: [
          SubcategoryModel(
            id: '7-1',
            name: 'Local Moving',
            nameKey: 'subcategory_local_moving',
            description: 'Local relocation services',
            descriptionKey: 'subcategory_local_moving_desc',
            icon: CupertinoIcons.car_fill,
            iconCode: 'car_fill',
          ),
          SubcategoryModel(
            id: '7-2',
            name: 'Long Distance',
            nameKey: 'subcategory_long_distance',
            description: 'Long distance moving',
            descriptionKey: 'subcategory_long_distance_desc',
            icon: CupertinoIcons.home,
            iconCode: 'road_fill',
          ),
          SubcategoryModel(
            id: '7-3',
            name: 'Packing',
            nameKey: 'subcategory_packing',
            description: 'Packing and unpacking services',
            descriptionKey: 'subcategory_packing_desc',
            icon: CupertinoIcons.cube_fill,
            iconCode: 'cube_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '8',
        name: 'Repair',
        nameKey: 'category_repair',
        description: 'General repair and maintenance',
        descriptionKey: 'category_repair_desc',
        icon: CupertinoIcons.wrench_fill,
        iconCode: 'wrench_fill',
        subcategories: [
          SubcategoryModel(
            id: '8-1',
            name: 'Appliance Repair',
            nameKey: 'subcategory_appliance_repair',
            description: 'Home appliance repair',
            descriptionKey: 'subcategory_appliance_repair_desc',
            icon: CupertinoIcons.wrench_fill,
            iconCode: 'wrench_fill',
          ),
          SubcategoryModel(
            id: '8-2',
            name: 'General Maintenance',
            nameKey: 'subcategory_general_maintenance',
            description: 'General home maintenance',
            descriptionKey: 'subcategory_general_maintenance_desc',
            icon: CupertinoIcons.hammer_fill,
            iconCode: 'hammer_fill',
          ),
          SubcategoryModel(
            id: '8-3',
            name: 'Emergency Repair',
            nameKey: 'subcategory_emergency_repair',
            description: 'Urgent repair services',
            descriptionKey: 'subcategory_emergency_repair_desc',
            icon: CupertinoIcons.exclamationmark_triangle_fill,
            iconCode: 'exclamationmark_triangle_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '9',
        name: 'Installation',
        nameKey: 'category_installation',
        description: 'Equipment and appliance installation',
        descriptionKey: 'category_installation_desc',
        icon: CupertinoIcons.settings,
        iconCode: 'settings',
        subcategories: [
          SubcategoryModel(
            id: '9-1',
            name: 'Appliance Installation',
            nameKey: 'subcategory_appliance_installation',
            description: 'Home appliance setup',
            descriptionKey: 'subcategory_appliance_installation_desc',
            icon: CupertinoIcons.settings,
            iconCode: 'settings',
          ),
          SubcategoryModel(
            id: '9-2',
            name: 'Furniture Assembly',
            nameKey: 'subcategory_furniture_assembly',
            description: 'Furniture setup and assembly',
            descriptionKey: 'subcategory_furniture_assembly_desc',
            icon: CupertinoIcons.hammer_fill,
            iconCode: 'hammer_fill',
          ),
          SubcategoryModel(
            id: '9-3',
            name: 'Equipment Setup',
            nameKey: 'subcategory_equipment_setup',
            description: 'Equipment installation',
            descriptionKey: 'subcategory_equipment_setup_desc',
            icon: CupertinoIcons.gear_alt_fill,
            iconCode: 'gear_alt_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '10',
        name: 'Tutoring',
        nameKey: 'category_tutoring',
        description: 'Educational and tutoring services',
        descriptionKey: 'category_tutoring_desc',
        icon: CupertinoIcons.pencil,
        iconCode: 'pencil',
        subcategories: [
          SubcategoryModel(
            id: '10-1',
            name: 'Academic Tutoring',
            nameKey: 'subcategory_academic_tutoring',
            description: 'School subject tutoring',
            descriptionKey: 'subcategory_academic_tutoring_desc',
            icon: CupertinoIcons.pencil,
            iconCode: 'pencil',
          ),
          SubcategoryModel(
            id: '10-2',
            name: 'Language Tutoring',
            nameKey: 'subcategory_language_tutoring',
            description: 'Language learning',
            descriptionKey: 'subcategory_language_tutoring_desc',
            icon: CupertinoIcons.text_bubble_fill,
            iconCode: 'text_bubble_fill',
          ),
          SubcategoryModel(
            id: '10-3',
            name: 'Test Preparation',
            nameKey: 'subcategory_test_prep',
            description: 'Exam preparation',
            descriptionKey: 'subcategory_test_prep_desc',
            icon: CupertinoIcons.number_square_fill,
            iconCode: 'number_square_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '11',
        name: 'Health',
        nameKey: 'category_health',
        description: 'Health and wellness services',
        descriptionKey: 'category_health_desc',
        icon: CupertinoIcons.heart_fill,
        iconCode: 'heart_fill',
        subcategories: [
          SubcategoryModel(
            id: '11-1',
            name: 'Medical Consultation',
            nameKey: 'subcategory_medical_consultation',
            description: 'General medical advice',
            descriptionKey: 'subcategory_medical_consultation_desc',
            icon: CupertinoIcons.heart_fill,
            iconCode: 'heart_fill',
          ),
          SubcategoryModel(
            id: '11-2',
            name: 'Therapy',
            nameKey: 'subcategory_therapy',
            description: 'Physical or mental therapy',
            descriptionKey: 'subcategory_therapy_desc',
            icon: CupertinoIcons.lab_flask,
            iconCode: 'lab_flask',
          ),
          SubcategoryModel(
            id: '11-3',
            name: 'Nursing Care',
            nameKey: 'subcategory_nursing',
            description: 'Professional nursing services',
            descriptionKey: 'subcategory_nursing_desc',
            icon: CupertinoIcons.heart_fill,
            iconCode: 'heart_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '12',
        name: 'Beauty',
        nameKey: 'category_beauty',
        description: 'Beauty and personal care',
        descriptionKey: 'category_beauty_desc',
        icon: CupertinoIcons.scissors,
        iconCode: 'scissors',
        subcategories: [
          SubcategoryModel(
            id: '12-1',
            name: 'Hair Styling',
            nameKey: 'subcategory_hair_styling',
            description: 'Haircut and styling',
            descriptionKey: 'subcategory_hair_styling_desc',
            icon: CupertinoIcons.scissors,
            iconCode: 'scissors',
          ),
          SubcategoryModel(
            id: '12-2',
            name: 'Makeup',
            nameKey: 'subcategory_makeup',
            description: 'Makeup application',
            descriptionKey: 'subcategory_makeup_desc',
            icon: CupertinoIcons.sparkles,
            iconCode: 'sparkles',
          ),
          SubcategoryModel(
            id: '12-3',
            name: 'Spa & Massage',
            nameKey: 'subcategory_spa',
            description: 'Relaxation and wellness',
            descriptionKey: 'subcategory_spa_desc',
            icon: CupertinoIcons.leaf_arrow_circlepath,
            iconCode: 'leaf_arrow_circlepath',
          ),
        ],
      ),
      CategoryModel(
        id: '13',
        name: 'Tech',
        nameKey: 'category_tech',
        description: 'Technology and IT services',
        descriptionKey: 'category_tech_desc',
        icon: CupertinoIcons.desktopcomputer,
        iconCode: 'desktopcomputer',
        subcategories: [
          SubcategoryModel(
            id: '13-1',
            name: 'Computer Repair',
            nameKey: 'subcategory_computer_repair',
            description: 'PC and laptop repair',
            descriptionKey: 'subcategory_computer_repair_desc',
            icon: CupertinoIcons.desktopcomputer,
            iconCode: 'desktopcomputer',
          ),
          SubcategoryModel(
            id: '13-2',
            name: 'Mobile Repair',
            nameKey: 'subcategory_mobile_repair',
            description: 'Smartphone repair',
            descriptionKey: 'subcategory_mobile_repair_desc',
            icon: CupertinoIcons.device_phone_portrait,
            iconCode: 'device_phone_portrait',
          ),
          SubcategoryModel(
            id: '13-3',
            name: 'IT Support',
            nameKey: 'subcategory_it_support',
            description: 'Technical support',
            descriptionKey: 'subcategory_it_support_desc',
            icon: CupertinoIcons.gear_alt_fill,
            iconCode: 'gear_alt_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '14',
        name: 'Food',
        nameKey: 'category_food',
        description: 'Food and catering services',
        descriptionKey: 'category_food_desc',
        icon: CupertinoIcons.cart_fill,
        iconCode: 'cart_fill',
        subcategories: [
          SubcategoryModel(
            id: '14-1',
            name: 'Catering',
            nameKey: 'subcategory_catering',
            description: 'Event food services',
            descriptionKey: 'subcategory_catering_desc',
            icon: CupertinoIcons.cart_fill,
            iconCode: 'cart_fill',
          ),
          SubcategoryModel(
            id: '14-2',
            name: 'Private Chef',
            nameKey: 'subcategory_private_chef',
            description: 'Personal chef services',
            descriptionKey: 'subcategory_private_chef_desc',
            icon: CupertinoIcons.house_fill,
            iconCode: 'house_fill',
          ),
          SubcategoryModel(
            id: '14-3',
            name: 'Meal Prep',
            nameKey: 'subcategory_meal_prep',
            description: 'Meal preparation',
            descriptionKey: 'subcategory_meal_prep_desc',
            icon: CupertinoIcons.tray_fill,
            iconCode: 'tray_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '15',
        name: 'Home',
        nameKey: 'category_home',
        description: 'General home services',
        descriptionKey: 'category_home_desc',
        icon: CupertinoIcons.house_fill,
        iconCode: 'house_fill',
        subcategories: [
          SubcategoryModel(
            id: '15-1',
            name: 'Home Maintenance',
            nameKey: 'subcategory_home_maintenance',
            description: 'General home upkeep',
            descriptionKey: 'subcategory_home_maintenance_desc',
            icon: CupertinoIcons.house_fill,
            iconCode: 'house_fill',
          ),
          SubcategoryModel(
            id: '15-2',
            name: 'Smart Home',
            nameKey: 'subcategory_smart_home',
            description: 'Smart device installation',
            descriptionKey: 'subcategory_smart_home_desc',
            icon: CupertinoIcons.lightbulb_fill,
            iconCode: 'lightbulb_fill',
          ),
          SubcategoryModel(
            id: '15-3',
            name: 'Renovation',
            nameKey: 'subcategory_renovation',
            description: 'Home renovation',
            descriptionKey: 'subcategory_renovation_desc',
            icon: CupertinoIcons.hammer_fill,
            iconCode: 'hammer_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '16',
        name: 'Other',
        nameKey: 'category_other',
        description: 'Other services',
        descriptionKey: 'category_other_desc',
        icon: CupertinoIcons.circle_fill,
        iconCode: 'circle_fill',
        subcategories: [
          SubcategoryModel(
            id: '16-1',
            name: 'General Service',
            nameKey: 'subcategory_general',
            description: 'General service category',
            descriptionKey: 'subcategory_general_desc',
            icon: CupertinoIcons.circle_fill,
            iconCode: 'circle_fill',
          ),
        ],
      ),
    ];
  }

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      name: data['name'] ?? '',
      nameKey: data['nameKey'] ?? '',
      description: data['description'] ?? '',
      descriptionKey: data['descriptionKey'] ?? '',
      iconUrl: data['iconUrl'],
      createdAt: data['createdAt'],
      icon: getIconFromCode(data['iconCode'] ?? ''),
      iconCode: data['iconCode'] ?? '',
      isActive: data['isActive'] ?? true,
      subcategories: [],
    );
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CategoryModel(
      id: id,
      name: map['name'] ?? '',
      nameKey: map['nameKey'] ?? '',
      description: map['description'] ?? '',
      descriptionKey: map['descriptionKey'] ?? '',
      iconUrl: map['iconUrl'],
      createdAt: map['createdAt'],
      icon: getIconFromCode(map['iconCode'] ?? ''),
      iconCode: map['iconCode'] ?? '',
      isActive: map['isActive'] ?? true,
      subcategories: [],
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
      'nameKey': nameKey,
      'description': description,
      'descriptionKey': descriptionKey,
      'iconUrl': iconUrl,
      'createdAt': createdAt,
      'iconCode': iconCode,
      'isActive': isActive,
    };
  }
}
