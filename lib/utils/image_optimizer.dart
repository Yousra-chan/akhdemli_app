import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageOptimizer {
  /// Compresses and resizes an image to reduce size while maintaining quality
  static Future<Uint8List> compressImage(
      File file, {
        int maxSizeKB = 100,
        int maxWidth = 1024,
        int maxHeight = 1024,
      }) async {
    try {
      final Uint8List originalBytes = await file.readAsBytes();
      final double originalSizeKB = originalBytes.length / 1024;
      debugPrint('📏 Original image: ${originalSizeKB.toStringAsFixed(1)}KB');

      // If already small enough, return original
      if (originalSizeKB <= maxSizeKB) {
        return originalBytes;
      }

      // Decode image
      img.Image? image = img.decodeImage(originalBytes);
      if (image == null) return originalBytes;

      // Resize if needed
      if (image.width > maxWidth || image.height > maxHeight) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? maxWidth : null,
          height: image.height > image.width ? maxHeight : null,
        );
      }

      // Compress with decreasing quality until size target is met
      int quality = 85;
      Uint8List compressedBytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));

      while (compressedBytes.length / 1024 > maxSizeKB && quality > 20) {
        quality -= 10;
        compressedBytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      }

      final double compressedSizeKB = compressedBytes.length / 1024;
      debugPrint('✅ Compressed to: ${compressedSizeKB.toStringAsFixed(1)}KB');

      return compressedBytes;
    } catch (e) {
      debugPrint('❌ Error compressing image: $e');
      return await file.readAsBytes();
    }
  }
}
