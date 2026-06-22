import 'package:flutter/material.dart';

// --- Global Constants (Consistent with previous screens) ---
const Color kPrimaryBlue = Color.fromARGB(255, 87, 101, 240);
const Color kLightBackgroundColor = Color.fromARGB(255, 248, 249, 255);
const Color kCardBackgroundColor = Colors.white;
const Color kDarkTextColor = Color.fromARGB(255, 50, 50, 50);
const Color kMutedTextColor = Color.fromARGB(255, 150, 150, 150);
const Color kSoftShadowColor = Color.fromARGB(50, 87, 101, 240);
const Color kSelectedFilterColor = Color.fromARGB(255, 200, 205, 255);

// Generic marker colors
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
];

// --- Combined Search Options ---
final List<FilterOption> allSearchOptions = [
  ...cityFilters,
  ...otherFilters,
];

// --- Helper function to get marker color by category ---
Color getMarkerColorForCategory(String categoryName) {
  // Use a generic color palette based on string hash for consistency
  final colors = [
    const Color(0xFF667EEA),
    const Color(0xFF764BA2),
    const Color(0xFF4FACFE),
    const Color(0xFF43E97B),
    const Color(0xFFFA709A),
    const Color(0xFFF093FB),
    const Color(0xFF38F9D7),
    const Color(0xFFFF9068),
    const Color(0xFF00F2FE),
    const Color(0xFF38C97B),
    const Color(0xFFF5576C),
    const Color(0xFFFFC107),
  ];
  
  if (categoryName.isEmpty) return kMarkerOther;
  final index = categoryName.length + categoryName.codeUnitAt(0);
  return colors[index % colors.length];
}
