import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ImageUtils {
  /// Decodes base64 image string to bytes
  static Uint8List? decodeBase64Image(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return null;
    }

    try {
      // Handle different base64 formats
      String data = base64String;

      // Remove data URL prefix if present
      if (base64String.startsWith('data:image')) {
        final parts = base64String.split(',');
        if (parts.length > 1) {
          data = parts[1];
        }
      }

      // Decode base64 to bytes
      return base64Decode(data);
    } catch (e) {
      print('❌ Error decoding base64 image: $e');
      print('📸 Problematic string: ${base64String.substring(0, 100)}...');
      return null;
    }
  }

  /// Checks if a string is a valid base64 image
  static bool isBase64Image(String? str) {
    if (str == null || str.isEmpty) return false;
    return str.startsWith('data:image') ||
        (str.length % 4 == 0 &&
            RegExp(r'^[a-zA-Z0-9+/]*={0,2}$').hasMatch(str));
  }

  /// Checks if a string is a network image URL
  static bool isNetworkImage(String? str) {
    if (str == null || str.isEmpty) return false;
    return str.startsWith('http://') || str.startsWith('https://');
  }

  /// Gets image provider for any type of image string
  static ImageProvider? getImageProvider(String? imageString) {
    if (imageString == null || imageString.isEmpty) return null;

    if (isNetworkImage(imageString)) {
      return NetworkImage(imageString);
    }

    if (isBase64Image(imageString)) {
      final bytes = decodeBase64Image(imageString);
      return bytes != null ? MemoryImage(bytes) : null;
    }

    // If it's neither network nor base64, try to use it as a network image
    // or return a placeholder
    return NetworkImage(imageString);
  }

  /// Enhanced method to get image URL with fallback
  static String getImageUrl(String? imageString, {String fallbackUrl = ''}) {
    if (imageString == null || imageString.isEmpty) {
      return fallbackUrl.isNotEmpty
          ? fallbackUrl
          : 'https://media.sproutsocial.com/uploads/2022/06/profile-picture.jpeg';
    }

    // If it's already a network URL, use it directly
    if (isNetworkImage(imageString)) {
      return imageString;
    }

    // If it's base64, we can't use it directly as URL, return fallback
    if (isBase64Image(imageString)) {
      return fallbackUrl.isNotEmpty
          ? fallbackUrl
          : 'https://media.sproutsocial.com/uploads/2022/06/profile-picture.jpeg';
    }

    // For other cases, try to use it as network URL
    return imageString;
  }
}
