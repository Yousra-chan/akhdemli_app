// utils/image_optimizer.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

class ImageOptimizer {
  static Future<Uint8List> compressImage(
    File file, {
    int maxSizeKB = 50,
    int maxWidth = 800,
    int maxHeight = 800,
  }) async {
    try {
      final originalBytes = await file.readAsBytes();
      final originalSizeKB = originalBytes.length / 1024;

      print('📏 Original image: ${originalSizeKB.toStringAsFixed(1)}KB');

      // If already small enough, return as is
      if (originalSizeKB <= maxSizeKB) {
        return originalBytes;
      }

      // Decode and resize image
      final codec = await ui.instantiateImageCodec(
        originalBytes,
        targetWidth: maxWidth,
        targetHeight: maxHeight,
      );
      final frame = await codec.getNextFrame();

      // Convert to byte data
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        return originalBytes;
      }

      final compressedBytes = byteData.buffer.asUint8List();
      final compressedSizeKB = compressedBytes.length / 1024;

      print('✅ Compressed to: ${compressedSizeKB.toStringAsFixed(1)}KB');

      return compressedBytes;
    } catch (e) {
      print('❌ Error compressing image: $e');
      // Return original if compression fails
      return await file.readAsBytes();
    }
  }
}
