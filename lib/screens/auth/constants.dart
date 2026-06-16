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

const Color kSuccessColor = Color(0xFF2E7D32);

void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontFamily: kAppFont,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(16),
    ),
  );
}

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontFamily: kAppFont,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(16),
    ),
  );
}

