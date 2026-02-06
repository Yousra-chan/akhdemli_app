import 'package:flutter/material.dart';

const Color kPrimaryBlue = Color(0xFF143EAE);
const Color kMutedTextColor = Color(0xFF5A6670);
const Color kLightBackgroundColor = Colors.white;
const Color kBorderColor = Color(0xFFE0E0E0);
const Color kDarkTextColor = Color(0xFF222222);
const Color kLinkColor = kPrimaryBlue;
const String kAppFont = 'Roboto';
const double kHorizontalPadding = 32.0;
const Color kInputFillColor = Color(0xFFE9ECEF);

/// Returns a common, clean Input Decoration style for forms.
InputDecoration buildInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: kMutedTextColor,
      fontFamily: kAppFont,
      fontSize: 14,
    ),
    floatingLabelBehavior:
        FloatingLabelBehavior.never, // Keeps the label inside
    filled: true,
    fillColor: Colors.transparent,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: kBorderColor, width: 1.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: kPrimaryBlue, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: kBorderColor, width: 1.0),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
  );
}
