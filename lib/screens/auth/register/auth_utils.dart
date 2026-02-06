import 'package:flutter/material.dart';
import 'package:service_app/screens/auth/constants.dart'; // Assuming this holds your constants

// Reusable function to build a consistent input decoration style
InputDecoration buildInputDecoration(String label) {
  return InputDecoration(
    hintText: label,
    hintStyle: const TextStyle(color: kMutedTextColor, fontFamily: kAppFont),
    filled: true,
    fillColor: kInputFillColor.withOpacity(0.5),
    contentPadding: const EdgeInsets.symmetric(
      vertical: 16.0,
      horizontal: 20.0,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kPrimaryBlue, width: 2),
    ),
  );
}
