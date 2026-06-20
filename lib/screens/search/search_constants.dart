import 'package:flutter/material.dart';

// --- Global Constants (Consistent with previous screens) ---
const Color kPrimaryBlue = Color.fromARGB(255, 87, 101, 240);
const Color kLightBackgroundColor = Color.fromARGB(255, 248, 249, 255);
const Color kCardBackgroundColor = Colors.white;
const Color kDarkTextColor = Color.fromARGB(255, 50, 50, 50);
const Color kMutedTextColor = Color.fromARGB(255, 150, 150, 150);
const Color kSoftShadowColor = Color.fromARGB(50, 87, 101, 240);
const Color kSelectedFilterColor = Color.fromARGB(255, 200, 205, 255);

// Additional colors for markers - MATCHING HOME CONSTANTS CATEGORIES
const Color kMarkerCleaning = Color(0xFF667EEA);
const Color kMarkerPlumber = Color(0xFF4FACFE);
const Color kMarkerElectric = Color(0xFF43E97B);
const Color kMarkerCarpenter = Color(0xFFFA709A);
const Color kMarkerPainter = Color(0xFFF093FB);
const Color kMarkerGardener = Color(0xFF38F9D7);
const Color kMarkerMover = Color(0xFFFF9068);
const Color kMarkerRepair = Color(0xFF764BA2);
const Color kMarkerInstaller = Color(0xFF00F2FE);
const Color kMarkerTutor = Color(0xFF38C97B);
const Color kMarkerHealth = Color(0xFFF5576C);
const Color kMarkerBeauty = Color(0xFFFFC107);
const Color kMarkerHome = Color(0xFF667EEA);
const Color kMarkerTech = Color(0xFF4CAF50);
const Color kMarkerFood = Color(0xFFFF9800);
const Color kMarkerOther = Color(0xFF969696);

// --- Data Models ---
class FilterOption {
  final String label;
  final String labelKey; // Translation key
  final String value;
  final IconData? icon;

  const FilterOption({
    required this.label,
    required this.labelKey,
    required this.value,
    this.icon,
  });
}

// --- SERVICE FILTERS - MATCHING CATEGORY MODEL ---
const List<FilterOption> serviceFilters = [
  FilterOption(
    label: "Cleaning Services",
    labelKey: "category_cleaning",
    value: "cleaning",
    icon: Icons.cleaning_services,
  ),
  FilterOption(
    label: "Plumbing Services",
    labelKey: "category_plumbing",
    value: "plumbing",
    icon: Icons.plumbing,
  ),
  FilterOption(
    label: "Electrical Services",
    labelKey: "category_electrical",
    value: "electrical",
    icon: Icons.electrical_services,
  ),
  FilterOption(
    label: "Carpentry Services",
    labelKey: "category_carpentry",
    value: "carpentry",
    icon: Icons.handyman,
  ),
  FilterOption(
    label: "Painting Services",
    labelKey: "category_painting",
    value: "painting",
    icon: Icons.format_paint,
  ),
  FilterOption(
    label: "Gardening Services",
    labelKey: "category_gardening",
    value: "gardening",
    icon: Icons.grass,
  ),
  FilterOption(
    label: "Moving Services",
    labelKey: "category_moving",
    value: "moving",
    icon: Icons.local_shipping,
  ),
  FilterOption(
    label: "Repair Services",
    labelKey: "category_repair",
    value: "repair",
    icon: Icons.build,
  ),
  FilterOption(
    label: "Installation Services",
    labelKey: "category_installation",
    value: "installation",
    icon: Icons.settings,
  ),
  FilterOption(
    label: "Tutoring Services",
    labelKey: "category_tutoring",
    value: "tutoring",
    icon: Icons.school,
  ),
  FilterOption(
    label: "Health Services",
    labelKey: "category_health",
    value: "health",
    icon: Icons.medical_services,
  ),
  FilterOption(
    label: "Beauty Services",
    labelKey: "category_beauty",
    value: "beauty",
    icon: Icons.spa,
  ),
  FilterOption(
    label: "Home Services",
    labelKey: "category_home",
    value: "home",
    icon: Icons.home,
  ),
  FilterOption(
    label: "Tech Services",
    labelKey: "category_tech",
    value: "tech",
    icon: Icons.computer,
  ),
  FilterOption(
    label: "Food Services",
    labelKey: "category_food",
    value: "food",
    icon: Icons.restaurant,
  ),
  FilterOption(
    label: "Other Services",
    labelKey: "category_other",
    value: "other",
    icon: Icons.more_horiz,
  ),
];

// --- CITY FILTERS ---
const List<FilterOption> cityFilters = [
  FilterOption(
    label: "My Location",
    labelKey: "filter_my_location",
    value: "my_location",
    icon: Icons.my_location,
  ),
  FilterOption(
    label: "City Center",
    labelKey: "filter_city_center",
    value: "city_center",
    icon: Icons.location_city,
  ),
  FilterOption(
    label: "West Side",
    labelKey: "filter_west_side",
    value: "west_side",
    icon: Icons.west,
  ),
  FilterOption(
    label: "North District",
    labelKey: "filter_north_district",
    value: "north_district",
    icon: Icons.north,
  ),
  FilterOption(
    label: "South District",
    labelKey: "filter_south_district",
    value: "south_district",
    icon: Icons.south,
  ),
  FilterOption(
    label: "East District",
    labelKey: "filter_east_district",
    value: "east_district",
    icon: Icons.east,
  ),
];

// --- OTHER FILTERS ---
final List<FilterOption> otherFilters = [
  const FilterOption(
    label: "Near Me",
    labelKey: "filter_near_me",
    value: "near_me",
    icon: Icons.near_me,
  ),
  const FilterOption(
    label: "4+ Rating",
    labelKey: "filter_rating_4_plus",
    value: "rating_4_plus",
    icon: Icons.star,
  ),
  const FilterOption(
    label: "Open Now",
    labelKey: "filter_open_now",
    value: "open_now",
    icon: Icons.access_time,
  ),
  const FilterOption(
    label: "Verified Only",
    labelKey: "filter_verified_only",
    value: "verified_only",
    icon: Icons.verified,
  ),
  const FilterOption(
    label: "Available Today",
    labelKey: "filter_available_today",
    value: "available_today",
    icon: Icons.today,
  ),
  const FilterOption(
    label: "Best Match",
    labelKey: "filter_best_match",
    value: "best_match",
    icon: Icons.thumb_up,
  ),
  const FilterOption(
    label: "Price: Low to High",
    labelKey: "filter_price_low_high",
    value: "price_low_high",
    icon: Icons.arrow_upward,
  ),
  const FilterOption(
    label: "Price: High to Low",
    labelKey: "filter_price_high_low",
    value: "price_high_low",
    icon: Icons.arrow_downward,
  ),
  const FilterOption(
    label: "Newest First",
    labelKey: "filter_newest",
    value: "newest",
    icon: Icons.fiber_new,
  ),
];

// --- Combined Search Options ---
final List<FilterOption> allSearchOptions = [
  ...serviceFilters,
  ...cityFilters,
  ...otherFilters,
];

// --- Single source of truth for category keyword matching ---
// Both color and icon lookups used to duplicate this exact keyword list
// in two separate if/else chains (and could drift out of sync). Now both
// derive from one ordered table, evaluated once per call.
class _CategoryStyle {
  final List<String> keywords;
  final Color color;
  final IconData icon;
  const _CategoryStyle(this.keywords, this.color, this.icon);
}

const List<_CategoryStyle> _categoryStyles = [
  _CategoryStyle(['clean'], kMarkerCleaning, Icons.cleaning_services),
  _CategoryStyle(['plumb'], kMarkerPlumber, Icons.plumbing),
  _CategoryStyle(['electric'], kMarkerElectric, Icons.electrical_services),
  _CategoryStyle(['carpent'], kMarkerCarpenter, Icons.handyman),
  _CategoryStyle(['paint'], kMarkerPainter, Icons.format_paint),
  _CategoryStyle(['garden'], kMarkerGardener, Icons.grass),
  _CategoryStyle(['mov', 'transport'], kMarkerMover, Icons.local_shipping),
  _CategoryStyle(['repair'], kMarkerRepair, Icons.build),
  _CategoryStyle(['install'], kMarkerInstaller, Icons.settings),
  _CategoryStyle(['teach', 'tutor'], kMarkerTutor, Icons.school),
  _CategoryStyle(['health', 'medical'], kMarkerHealth, Icons.medical_services),
  _CategoryStyle(['beauty'], kMarkerBeauty, Icons.spa),
  _CategoryStyle(['home'], kMarkerHome, Icons.home),
  _CategoryStyle(['tech', 'computer'], kMarkerTech, Icons.computer),
  _CategoryStyle(['food'], kMarkerFood, Icons.restaurant),
];

_CategoryStyle? _matchCategoryStyle(String categoryName) {
  final name = categoryName.toLowerCase();
  for (final style in _categoryStyles) {
    if (style.keywords.any(name.contains)) return style;
  }
  return null;
}

// --- Helper function to get marker color by category ---
Color getMarkerColorForCategory(String categoryName) {
  return _matchCategoryStyle(categoryName)?.color ?? kMarkerOther;
}

// --- Helper function to get icon for category ---
IconData getCategoryIcon(String categoryName) {
  return _matchCategoryStyle(categoryName)?.icon ?? Icons.more_horiz;
}

// --- Helper function to get filter option by value (O(1), no exceptions-as-control-flow) ---
Map<String, FilterOption>? _filterOptionsByValue;

FilterOption? getFilterOptionByValue(String value) {
  _filterOptionsByValue ??= {
    for (final option in allSearchOptions) option.value.toLowerCase(): option,
  };
  return _filterOptionsByValue![value.toLowerCase()];
}

// --- Helper function to get filter label by value ---
String getFilterLabelByValue(String value) {
  final option = getFilterOptionByValue(value);
  return option?.label ?? value;
}

// --- Helper function to get filter translation key by value ---
String getFilterKeyByValue(String value) {
  final option = getFilterOptionByValue(value);
  return option?.labelKey ?? '';
}

// --- Predefined service categories list (for quick access) ---
const List<Map<String, dynamic>> serviceCategories = [
  {
    'id': 'cleaning',
    'name': 'Cleaning Services',
    'nameKey': 'category_cleaning',
    'icon': Icons.cleaning_services,
    'color': Color(0xFF667EEA),
  },
  {
    'id': 'plumbing',
    'name': 'Plumbing Services',
    'nameKey': 'category_plumbing',
    'icon': Icons.plumbing,
    'color': Color(0xFF4FACFE),
  },
  {
    'id': 'electrical',
    'name': 'Electrical Services',
    'nameKey': 'category_electrical',
    'icon': Icons.electrical_services,
    'color': Color(0xFF43E97B),
  },
  {
    'id': 'carpentry',
    'name': 'Carpentry Services',
    'nameKey': 'category_carpentry',
    'icon': Icons.handyman,
    'color': Color(0xFFFA709A),
  },
  {
    'id': 'painting',
    'name': 'Painting Services',
    'nameKey': 'category_painting',
    'icon': Icons.format_paint,
    'color': Color(0xFFF093FB),
  },
  {
    'id': 'gardening',
    'name': 'Gardening Services',
    'nameKey': 'category_gardening',
    'icon': Icons.grass,
    'color': Color(0xFF38F9D7),
  },
  {
    'id': 'moving',
    'name': 'Moving Services',
    'nameKey': 'category_moving',
    'icon': Icons.local_shipping,
    'color': Color(0xFFFF9068),
  },
  {
    'id': 'repair',
    'name': 'Repair Services',
    'nameKey': 'category_repair',
    'icon': Icons.build,
    'color': Color(0xFF764BA2),
  },
  {
    'id': 'installation',
    'name': 'Installation Services',
    'nameKey': 'category_installation',
    'icon': Icons.settings,
    'color': Color(0xFF00F2FE),
  },
  {
    'id': 'tutoring',
    'name': 'Tutoring Services',
    'nameKey': 'category_tutoring',
    'icon': Icons.school,
    'color': Color(0xFF38C97B),
  },
  {
    'id': 'health',
    'name': 'Health Services',
    'nameKey': 'category_health',
    'icon': Icons.medical_services,
    'color': Color(0xFFF5576C),
  },
  {
    'id': 'beauty',
    'name': 'Beauty Services',
    'nameKey': 'category_beauty',
    'icon': Icons.spa,
    'color': Color(0xFFFFC107),
  },
  {
    'id': 'home',
    'name': 'Home Services',
    'nameKey': 'category_home',
    'icon': Icons.home,
    'color': Color(0xFF667EEA),
  },
  {
    'id': 'tech',
    'name': 'Tech Services',
    'nameKey': 'category_tech',
    'icon': Icons.computer,
    'color': Color(0xFF4CAF50),
  },
  {
    'id': 'food',
    'name': 'Food Services',
    'nameKey': 'category_food',
    'icon': Icons.restaurant,
    'color': Color(0xFFFF9800),
  },
  {
    'id': 'other',
    'name': 'Other Services',
    'nameKey': 'category_other',
    'icon': Icons.more_horiz,
    'color': Color(0xFF969696),
  },
];