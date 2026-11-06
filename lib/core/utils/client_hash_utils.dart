import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Utility for computing perceptual hashes of images on the client side.
/// 
/// This allows for fast duplicate detection before uploading to the server,
/// improving UX and reducing bandwidth usage.
class ClientHashUtils {
  /// Compute perceptual hash for an image file/bytes
  /// Uses a simplified version of pHash algorithm
  static String computeHash(Uint8List imageBytes) {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return '';

      // Resize to 8x8 for hash computation (standard pHash approach)
      final resized = img.copyResize(decoded, width: 8, height: 8);

      // Convert to grayscale
      final gray = _toGrayscale(resized);

      // Compute average pixel value
      int sum = 0;
      for (int i = 0; i < gray.length; i++) {
        sum += gray[i];
      }
      final average = sum ~/ gray.length;

      // Generate hash string (1 bit per pixel: '0' if below average, '1' if above)
      final buffer = StringBuffer();
      for (int i = 0; i < gray.length; i++) {
        buffer.write(gray[i] >= average ? '1' : '0');
      }

      return buffer.toString();
    } catch (e) {
      // Return empty hash if computation fails
      return '';
    }
  }

  /// Calculate Hamming distance between two hashes
  /// Lower distance = more similar images
  static int hammingDistance(String hash1, String hash2) {
    if (hash1.isEmpty || hash2.isEmpty) return -1; // Invalid hashes

    final len = hash1.length;
    if (hash2.length != len) return -1; // Different lengths

    int distance = 0;
    for (int i = 0; i < len; i++) {
      if (hash1[i] != hash2[i]) {
        distance++;
      }
    }
    return distance;
  }

  /// Check if two images are similar based on hash distance
  /// [threshold] default is 4, lower threshold = stricter matching
  static bool areSimilar(String hash1, String hash2, {int threshold = 4}) {
    final distance = hammingDistance(hash1, hash2);
    if (distance < 0) return false; // Invalid hashes
    return distance <= threshold;
  }

  /// Convert image to grayscale as list of pixel values (0-255)
  static List<int> _toGrayscale(img.Image image) {
    final grayscale = <int>[];
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixelSafe(x, y);
        // Standard grayscale formula: 0.299*R + 0.587*G + 0.114*B
        final r = pixel.rInt;
        final g = pixel.gInt;
        final b = pixel.bInt;
        final gray = (0.299 * r + 0.587 * g + 0.114 * b).toInt();
        grayscale.add(gray);
      }
    }
    return grayscale;
  }
}
