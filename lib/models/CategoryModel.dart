import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubcategoryModel {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String iconCode;
  final bool isActive;

  SubcategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.iconCode,
    this.isActive = true,
  });

  factory SubcategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return SubcategoryModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      icon: CategoryModel.getIconFromCode(map['iconCode'] ?? ''),
      iconCode: map['iconCode'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'iconCode': iconCode,
      'isActive': isActive,
    };
  }
}

class CategoryModel {
  final String id;
  final String name;
  final String description;
  final String? iconUrl;
  final Timestamp? createdAt;
  final IconData icon;
  final String iconCode;
  final bool isActive;
  final List<SubcategoryModel> subcategories;

  CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    this.iconUrl,
    this.createdAt,
    required this.icon,
    required this.iconCode,
    this.isActive = true,
    required this.subcategories,
  });

  static List<CategoryModel> get defaultCategories {
    return [
      CategoryModel(
        id: '1',
        name: 'Cleaning',
        description: 'House cleaning and maintenance services',
        icon: CupertinoIcons.house_fill,
        iconCode: 'cleaning',
        subcategories: [
          SubcategoryModel(
            id: '1-1',
            name: 'Home Cleaning',
            description: 'General house cleaning services',
            icon: CupertinoIcons.house_fill,
            iconCode: 'house_fill',
          ),
          SubcategoryModel(
            id: '1-2',
            name: 'Office Cleaning',
            description: 'Office and commercial cleaning',
            icon: CupertinoIcons.briefcase_fill,
            iconCode: 'briefcase_fill',
          ),
          SubcategoryModel(
            id: '1-3',
            name: 'Deep Cleaning',
            description: 'Thorough deep cleaning services',
            icon: CupertinoIcons.sparkles,
            iconCode: 'sparkles',
          ),
          SubcategoryModel(
            id: '1-4',
            name: 'Carpet Cleaning',
            description: 'Professional carpet cleaning',
            icon: CupertinoIcons.rectangle_fill,
            iconCode: 'rectangle_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '2',
        name: 'Plumbing',
        description: 'Plumbing and pipe repair services',
        icon: CupertinoIcons.wrench_fill,
        iconCode: 'plumbing',
        subcategories: [
          SubcategoryModel(
            id: '2-1',
            name: 'Pipe Repair',
            description: 'Pipe fixing and replacement',
            icon: CupertinoIcons.wrench_fill,
            iconCode: 'wrench_fill',
          ),
          SubcategoryModel(
            id: '2-2',
            name: 'Leak Fixing',
            description: 'Water leak detection and repair',
            icon: CupertinoIcons.drop_fill,
            iconCode: 'drop_fill',
          ),
          SubcategoryModel(
            id: '2-3',
            name: 'Fixture Installation',
            description: 'Sink, toilet, and shower installation',
            icon: CupertinoIcons.settings,
            iconCode: 'settings',
          ),
        ],
      ),
      CategoryModel(
        id: '3',
        name: 'Electrical',
        description: 'Electrical installation and repair',
        icon: CupertinoIcons.bolt_fill,
        iconCode: 'electrical',
        subcategories: [
          SubcategoryModel(
            id: '3-1',
            name: 'Wiring',
            description: 'Electrical wiring services',
            icon: CupertinoIcons.bolt_fill,
            iconCode: 'bolt_fill',
          ),
          SubcategoryModel(
            id: '3-2',
            name: 'Fixture Installation',
            description: 'Light and switch installation',
            icon: CupertinoIcons.lightbulb_fill,
            iconCode: 'lightbulb_fill',
          ),
          SubcategoryModel(
            id: '3-3',
            name: 'Repair',
            description: 'Electrical repair services',
            icon: CupertinoIcons.wrench_fill,
            iconCode: 'wrench_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '4',
        name: 'Carpentry',
        description: 'Woodwork and furniture services',
        icon: CupertinoIcons.hammer_fill,
        iconCode: 'carpentry',
        subcategories: [
          SubcategoryModel(
            id: '4-1',
            name: 'Furniture Making',
            description: 'Custom furniture creation',
            icon: CupertinoIcons.hammer_fill,
            iconCode: 'hammer_fill',
          ),
          SubcategoryModel(
            id: '4-2',
            name: 'Repair',
            description: 'Furniture repair services',
            icon: CupertinoIcons.wrench_fill,
            iconCode: 'wrench_fill',
          ),
          SubcategoryModel(
            id: '4-3',
            name: 'Installation',
            description: 'Furniture assembly and installation',
            icon: CupertinoIcons.settings,
            iconCode: 'settings',
          ),
        ],
      ),
      CategoryModel(
        id: '5',
        name: 'Painting',
        description: 'Painting and decoration services',
        icon: CupertinoIcons.paintbrush_fill,
        iconCode: 'painting',
        subcategories: [
          SubcategoryModel(
            id: '5-1',
            name: 'Interior Painting',
            description: 'Indoor wall painting',
            icon: CupertinoIcons.paintbrush_fill,
            iconCode: 'paintbrush_fill',
          ),
          SubcategoryModel(
            id: '5-2',
            name: 'Exterior Painting',
            description: 'Outdoor wall painting',
            icon: CupertinoIcons.house_fill,
            iconCode: 'house_fill',
          ),
          SubcategoryModel(
            id: '5-3',
            name: 'Decorative',
            description: 'Special decorative painting',
            icon: CupertinoIcons.sparkles,
            iconCode: 'sparkles',
          ),
        ],
      ),
      CategoryModel(
        id: '6',
        name: 'Gardening',
        description: 'Gardening and landscaping services',
        icon: CupertinoIcons.clear_fill,
        iconCode: 'gardening',
        subcategories: [
          SubcategoryModel(
            id: '6-1',
            name: 'Lawn Care',
            description: 'Lawn maintenance and care',
            icon: CupertinoIcons.clear_fill,
            iconCode: 'leaf_fill',
          ),
          SubcategoryModel(
            id: '6-2',
            name: 'Landscaping',
            description: 'Garden design and landscaping',
            icon: CupertinoIcons.tram_fill,
            iconCode: 'tree_fill',
          ),
          SubcategoryModel(
            id: '6-3',
            name: 'Planting',
            description: 'Plant installation and care',
            icon: CupertinoIcons.plus_circle_fill,
            iconCode: 'plus_circle_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '7',
        name: 'Moving',
        description: 'Moving and transportation services',
        icon: CupertinoIcons.car_fill,
        iconCode: 'moving',
        subcategories: [
          SubcategoryModel(
            id: '7-1',
            name: 'Local Moving',
            description: 'Local relocation services',
            icon: CupertinoIcons.car_fill,
            iconCode: 'car_fill',
          ),
          SubcategoryModel(
            id: '7-2',
            name: 'Long Distance',
            description: 'Long distance moving',
            icon: CupertinoIcons.location,
            iconCode: 'road_fill',
          ),
          SubcategoryModel(
            id: '7-3',
            name: 'Packing',
            description: 'Packing and unpacking services',
            icon: CupertinoIcons.cube_fill,
            iconCode: 'cube_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '8',
        name: 'Repair',
        description: 'General repair and maintenance',
        icon: CupertinoIcons.wrench_fill,
        iconCode: 'repair',
        subcategories: [
          SubcategoryModel(
            id: '8-1',
            name: 'Appliance Repair',
            description: 'Home appliance repair',
            icon: CupertinoIcons.wrench_fill,
            iconCode: 'wrench_fill',
          ),
          SubcategoryModel(
            id: '8-2',
            name: 'General Maintenance',
            description: 'General home maintenance',
            icon: CupertinoIcons.hammer_fill,
            iconCode: 'hammer_fill',
          ),
          SubcategoryModel(
            id: '8-3',
            name: 'Emergency Repair',
            description: 'Urgent repair services',
            icon: CupertinoIcons.exclamationmark_triangle_fill,
            iconCode: 'exclamationmark_triangle_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '9',
        name: 'Installation',
        description: 'Equipment and appliance installation',
        icon: CupertinoIcons.settings,
        iconCode: 'installation',
        subcategories: [
          SubcategoryModel(
            id: '9-1',
            name: 'Appliance Installation',
            description: 'Home appliance setup',
            icon: CupertinoIcons.settings,
            iconCode: 'settings',
          ),
          SubcategoryModel(
            id: '9-2',
            name: 'Furniture Assembly',
            description: 'Furniture setup and assembly',
            icon: CupertinoIcons.hammer_fill,
            iconCode: 'hammer_fill',
          ),
          SubcategoryModel(
            id: '9-3',
            name: 'Equipment Setup',
            description: 'Equipment installation',
            icon: CupertinoIcons.gear_alt_fill,
            iconCode: 'gear_alt_fill',
          ),
        ],
      ),
      CategoryModel(
        id: '10',
        name: 'Other',
        description: 'Other services',
        icon: CupertinoIcons.circle_fill,
        iconCode: 'other',
        subcategories: [
          SubcategoryModel(
            id: '10-1',
            name: 'General Service',
            description: 'General service category',
            icon: CupertinoIcons.circle_fill,
            iconCode: 'circle_fill',
          ),
        ],
      ),
    ];
  }

  // Add these methods to CategoryModel class in CategoryModel.dart
  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
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
      description: map['description'] ?? '',
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
      case 'wrench_fill':
        return CupertinoIcons.wrench_fill;
      case 'bolt_fill':
        return CupertinoIcons.bolt_fill;
      case 'hammer_fill':
        return CupertinoIcons.hammer_fill;
      case 'paintbrush_fill':
        return CupertinoIcons.paintbrush_fill;
      case 'clear_fill':
        return CupertinoIcons.clear_fill;
      case 'car_fill':
        return CupertinoIcons.car_fill;
      case 'settings':
        return CupertinoIcons.settings;
      case 'pencil':
        return CupertinoIcons.pencil;
      case 'heart_fill':
        return CupertinoIcons.heart_fill;
      case 'scissors':
        return CupertinoIcons.scissors;
      case 'briefcase_fill':
        return CupertinoIcons.briefcase_fill;
      case 'sparkles':
        return CupertinoIcons.sparkles;
      case 'rectangle_fill':
        return CupertinoIcons.rectangle_fill;
      case 'drop_fill':
        return CupertinoIcons.drop_fill;
      case 'lightbulb_fill':
        return CupertinoIcons.lightbulb_fill;
      case 'exclamationmark_triangle_fill':
        return CupertinoIcons.exclamationmark_triangle_fill;
      case 'number_square_fill':
        return CupertinoIcons.number_square_fill;
      case 'text_bubble_fill':
        return CupertinoIcons.text_bubble_fill;
      case 'lab_flask':
        return CupertinoIcons.lab_flask;
      case 'music_note_2':
        return CupertinoIcons.music_note_2;
      case 'desktopcomputer':
        return CupertinoIcons.desktopcomputer;
      case 'gear_alt_fill':
        return CupertinoIcons.gear_alt_fill;
      case 'cube_fill':
        return CupertinoIcons.cube_fill;
      case 'location':
        return CupertinoIcons.location;
      case 'tram_fill':
        return CupertinoIcons.tram_fill;
      case 'plus_circle_fill':
        return CupertinoIcons.plus_circle_fill;
      default:
        return CupertinoIcons.circle_fill;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'createdAt': createdAt,
      'iconCode': iconCode,
      'isActive': isActive,
    };
  }
}
