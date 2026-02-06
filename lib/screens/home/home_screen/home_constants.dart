// constants/home_constants.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:service_app/models/CategoryModel.dart';

// Colors
const Color kPrimaryBlue = Color.fromARGB(255, 12, 94, 153);
const Color kLightBackgroundColor = Color.fromARGB(255, 248, 249, 255);
const Color kCardBackgroundColor = Colors.white;
const Color kDarkTextColor = Color.fromARGB(255, 50, 50, 50);
const Color kMutedTextColor = Color.fromARGB(255, 150, 150, 150);
const Color kSoftShadowColor = Color.fromARGB(50, 87, 101, 240);
const Color kRatingYellow = Color.fromARGB(255, 255, 193, 7);
const Color kSuccessGreen = Color.fromARGB(255, 76, 175, 80);
const Color kWarningOrange = Color.fromARGB(255, 255, 152, 0);
const Color kErrorRed = Color.fromARGB(255, 244, 67, 54);
const Color kUnreadNotificationColor = Color.fromARGB(255, 236, 245, 255);

// Text Styles
const TextStyle kHeaderTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 24,
  fontWeight: FontWeight.w800,
  fontFamily: 'Exo2',
);

const TextStyle kSubHeaderTextStyle = TextStyle(
  color: Colors.white70,
  fontSize: 16,
  fontFamily: 'Exo2',
);

const TextStyle kSectionTitleTextStyle = TextStyle(
  color: kDarkTextColor,
  fontSize: 20,
  fontWeight: FontWeight.w700,
  fontFamily: 'Exo2',
);

const TextStyle kCardTitleTextStyle = TextStyle(
  color: kDarkTextColor,
  fontSize: 17,
  fontWeight: FontWeight.w700,
  fontFamily: 'Exo2',
);

const TextStyle kCardSubtitleTextStyle = TextStyle(
  color: kMutedTextColor,
  fontSize: 13,
  fontFamily: 'Exo2',
);

const TextStyle kBodyTextStyle = TextStyle(
  color: kDarkTextColor,
  fontSize: 14,
  fontFamily: 'Exo2',
);

const TextStyle kCaptionTextStyle = TextStyle(
  color: kMutedTextColor,
  fontSize: 12,
  fontFamily: 'Exo2',
);

// App Constants
const double kDefaultPadding = 16.0;
const double kDefaultBorderRadius = 15.0;
const double kCardElevation = 4.0;
const Duration kAnimationDuration = Duration(milliseconds: 300);

// Default categories - UPDATED to use CategoryModel.defaultCategories
final List<CategoryModel> defaultCategories = CategoryModel.defaultCategories;

// Helper Methods for Icons
IconData getIconForCategory(String categoryName) {
  final name = categoryName.toLowerCase();

  if (name.contains('clean')) {
    return CupertinoIcons.house_fill;
  } else if (name.contains('plumb')) {
    return CupertinoIcons.wrench_fill;
  } else if (name.contains('electric')) {
    return CupertinoIcons.bolt_fill;
  } else if (name.contains('carpent')) {
    return CupertinoIcons.hammer_fill;
  } else if (name.contains('paint')) {
    return CupertinoIcons.paintbrush_fill;
  } else if (name.contains('garden')) {
    return CupertinoIcons.clear_fill;
  } else if (name.contains('mov') || name.contains('transport')) {
    return CupertinoIcons.car_fill;
  } else if (name.contains('repair')) {
    return CupertinoIcons.wrench_fill;
  } else if (name.contains('install')) {
    return CupertinoIcons.settings;
  } else if (name.contains('teach') || name.contains('tutor')) {
    return CupertinoIcons.pencil;
  } else if (name.contains('health') || name.contains('medical')) {
    return CupertinoIcons.heart_fill;
  } else if (name.contains('beauty')) {
    return CupertinoIcons.scissors;
  } else if (name.contains('home')) {
    return CupertinoIcons.house_fill;
  } else if (name.contains('tech') || name.contains('computer')) {
    return CupertinoIcons.desktopcomputer;
  } else if (name.contains('food')) {
    return CupertinoIcons.cart_fill;
  } else {
    return CupertinoIcons.circle_fill;
  }
}

// Helper method to get CategoryModel from category name - FIXED
CategoryModel? getCategoryByName(String categoryName) {
  try {
    return CategoryModel.defaultCategories.firstWhere(
      (category) => category.name.toLowerCase() == categoryName.toLowerCase(),
    );
  } catch (e) {
    // If category not found, return null or create a fallback
    return null;
  }
}

// Alternative method that creates a fallback category - FIXED
CategoryModel getCategoryByNameOrCreate(String categoryName) {
  try {
    return CategoryModel.defaultCategories.firstWhere(
      (category) => category.name.toLowerCase() == categoryName.toLowerCase(),
    );
  } catch (e) {
    // Create a fallback category with proper constructor
    return CategoryModel(
      id: '0',
      name: categoryName,
      description: '$categoryName Services',
      icon: getIconForCategory(categoryName),
      iconCode: categoryName.toLowerCase(),
      subcategories: [], // ADDED: required parameter
    );
  }
}

// Helper method to get category icon
IconData getCategoryIcon(String categoryName) {
  final category = getCategoryByName(categoryName);
  return category?.icon ?? CupertinoIcons.circle_fill;
}

Color getColorForCategory(String categoryName, int index) {
  final colors = [
    const Color(0xFF667EEA),
    const Color(0xFF764BA2),
    const Color(0xFFF093FB),
    const Color(0xFFF5576C),
    const Color(0xFF4FACFE),
    const Color(0xFF00F2FE),
    const Color(0xFF43E97B),
    const Color(0xFF38F9D7),
    const Color(0xFFFA709A),
    const Color(0xFFFEE140),
    const Color(0xFFA8C0FF),
    const Color(0xFF3EECAC),
  ];
  return colors[index % colors.length];
}

// Input decoration for forms
InputDecoration buildAestheticInputDecoration(String labelText,
    {String? hintText}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kDefaultBorderRadius),
      borderSide: const BorderSide(color: kMutedTextColor, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kDefaultBorderRadius),
      borderSide: const BorderSide(color: kMutedTextColor, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kDefaultBorderRadius),
      borderSide: const BorderSide(color: kPrimaryBlue, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kDefaultBorderRadius),
      borderSide: const BorderSide(color: kErrorRed, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kDefaultBorderRadius),
      borderSide: const BorderSide(color: kErrorRed, width: 2),
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    labelStyle: const TextStyle(
      color: kMutedTextColor,
      fontSize: 16,
    ),
    hintStyle: const TextStyle(
      color: kMutedTextColor,
      fontSize: 14,
    ),
  );
}

// Category card widget helper - THIS IS OK (doesn't create new CategoryModel instances)
Widget buildCategoryCard(
    CategoryModel category, int index, VoidCallback onTap) {
  return Card(
    elevation: kCardElevation,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kDefaultBorderRadius),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(kDefaultBorderRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    getColorForCategory(category.name, index).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                category.icon,
                color: getColorForCategory(category.name, index),
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: kCardTitleTextStyle.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}
