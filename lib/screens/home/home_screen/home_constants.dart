// constants/home_constants.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/providers/language_provider.dart';

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

// Icons are now handled by CategoryModel using iconCode from Firestore.

// Helper method to get translated category name
String getTranslatedCategoryName(String categoryName, LanguageProvider lang) {
  // We prefer to use CategoryModel.getTranslatedName, but for legacy cases:
  final key = 'category_${categoryName.toLowerCase().replaceAll(' ', '_')}';
  return lang.tr(key, category: 'categories');
}

// Helper method to get translated category description
String getTranslatedCategoryDescription(
    String categoryName, LanguageProvider lang) {
  final key = 'category_${categoryName.toLowerCase().replaceAll(' ', '_')}_desc';
  return lang.tr(key, category: 'categories');
}

// Updated color schemes to match all 16 categories
Color getColorForCategory(String categoryName, int index) {
  final colors = [
    const Color(0xFF667EEA), // Cleaning
    const Color(0xFF764BA2), // Plumbing
    const Color(0xFF4FACFE), // Electrical
    const Color(0xFF43E97B), // Carpentry
    const Color(0xFFFA709A), // Painting
    const Color(0xFFF093FB), // Gardening
    const Color(0xFF38F9D7), // Moving
    const Color(0xFFFF9068), // Repair
    const Color(0xFF00F2FE), // Installation
    const Color(0xFF38C97B), // Tutoring
    const Color(0xFFF5576C), // Health
    const Color(0xFFFFC107), // Beauty
    const Color(0xFFA8C0FF), // Home
    const Color(0xFF4CAF50), // Tech
    const Color(0xFFFF9800), // Food
    const Color(0xFF969696), // Other
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

// Category card widget helper
Widget buildCategoryCard(CategoryModel category, int index, VoidCallback onTap,
    LanguageProvider lang) {
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
              category.getTranslatedName(lang),
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
