import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:service_app/screens/profile/profile_constants.dart';

// --- Reusable Tile Widgets (Common to Profile & Settings) ---

// Builds a single action item (e.g., Settings, Privacy). Copied from profile_widgets.dart
Widget buildActionTile(IconData icon, String title, bool isLast,
    {VoidCallback? onTap}) {
  return Padding(
    padding: const EdgeInsets.only(left: 20, right: 20, top: 2),
    child: Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kPrimaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kPrimaryBlue, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: kDarkTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Exo2',
            ),
          ),
          trailing: const Icon(CupertinoIcons.forward, color: kMutedTextColor),
          onTap: onTap, // Use the provided onTap callback
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: 75, // Aligns with the title text
            color: Color.fromARGB(255, 230, 230, 230),
          ),
      ],
    ),
  );
}

// Builds an action item with a Cupertino Switch for toggling settings
Widget buildSwitchTile(
  IconData icon,
  String title,
  bool value,
  Function(bool) onChanged,
  bool isLast,
) {
  return Padding(
    padding: const EdgeInsets.only(left: 20, right: 20, top: 2),
    child: Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kPrimaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kPrimaryBlue, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: kDarkTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Exo2',
            ),
          ),
          trailing: CupertinoSwitch(
            value: value,
            activeTrackColor: kPrimaryBlue,
            onChanged: onChanged,
          ),
          onTap: () =>
              onChanged(!value), // Allows tapping the whole tile to toggle
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: 75, // Aligns with the title text
            color: Color.fromARGB(255, 230, 230, 230),
          ),
      ],
    ),
  );
}

// Builds a standard section title for the settings page
Widget buildSettingsSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 25, bottom: 10, left: 30, right: 20),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: kMutedTextColor,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'Exo2',
          letterSpacing: 0.8,
        ),
      ),
    ),
  );
}

// Reusable card container for action/switch groups
Widget buildActionCard({required List<Widget> children}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: kCardBackgroundColor,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: kSoftShadowColor.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(children: children),
  );
}
