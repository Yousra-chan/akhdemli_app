import 'package:flutter/material.dart';

// --- Global Constants (Consistent with previous screens) ---
const Color kPrimaryBlue = Color.fromARGB(255, 87, 101, 240);
const Color kLightBackgroundColor = Color.fromARGB(255, 248, 249, 255);
const Color kCardBackgroundColor = Colors.white;
const Color kDarkTextColor = Color.fromARGB(255, 50, 50, 50);
const Color kMutedTextColor = Color.fromARGB(255, 150, 150, 150);
const Color kSoftShadowColor = Color.fromARGB(50, 87, 101, 240);
const Color kSelectedFilterColor = Color.fromARGB(255, 200, 205, 255);

// Additional colors for markers
const Color kMarkerElectric = Colors.amber;
const Color kMarkerMedical = Colors.red;
const Color kMarkerPlumber = Colors.blue;
const Color kMarkerTeacher = Colors.green;
const Color kMarkerHandyman = Colors.orange;
const Color kMarkerCleaning = Colors.lightBlue;
const Color kMarkerCarpenter = Colors.brown;
const Color kMarkerPainter = Colors.purple;
const Color kMarkerGardener = Colors.lightGreen;
const Color kMarkerMover = Colors.deepOrange;

// --- Data Models ---
class FilterOption {
  final String label;
  final String value;

  const FilterOption({required this.label, required this.value});
}

// --- Dummy Filter Data ---
const List<FilterOption> serviceFilters = [
  FilterOption(label: "Electrician", value: "electrician"),
  FilterOption(label: "Doctor (GP)", value: "doctor"),
  FilterOption(label: "Plumber", value: "plumber"),
  FilterOption(label: "Tutor", value: "tutor"),
  FilterOption(label: "Handyman", value: "handyman"),
];

const List<FilterOption> cityFilters = [
  FilterOption(label: "My Location", value: "my_location"),
  FilterOption(label: "City Center", value: "city_center"),
  FilterOption(label: "West Side", value: "west_side"),
  FilterOption(label: "North District", value: "north_district"),
];
// Add "Near Me" to your filters
final List<FilterOption> otherFilters = [
  FilterOption(label: "Near Me", value: "near_me"), // Add this
  FilterOption(label: "4+ Rating", value: "rating_4_plus"),
  FilterOption(label: "Open Now", value: "open_now"),
  FilterOption(label: "Verified Only", value: "verified_only"),
];

// --- Combined Search Options ---
final List<FilterOption> allSearchOptions = [
  ...serviceFilters,
  ...cityFilters,
  ...otherFilters,
];
