import 'dart:io';
import 'package:flutter/foundation.dart';
import '../utils/client_hash_utils.dart';

/// Represents an image with its computed hash
class HashedImage {
  final File file;
  final String hash;
  final DateTime computedAt;

  HashedImage({
    required this.file,
    required this.hash,
    DateTime? computedAt,
  }) : computedAt = computedAt ?? DateTime.now();
}

/// Service for client-side duplicate image detection
/// Maintains a cache of image hashes to quickly detect duplicates
/// before uploading to the server
class ImageDeduplicationService with ChangeNotifier {
  final List<HashedImage> _cachedImages = [];
  int _duplicatesDetected = 0;

  /// Get list of cached image hashes
  List<HashedImage> get cachedImages => List.unmodifiable(_cachedImages);

  /// Get count of duplicates detected in current session
  int get duplicatesDetected => _duplicatesDetected;

  /// Clear all cached hashes
  void clearCache() {
    _cachedImages.clear();
    _duplicatesDetected = 0;
    notifyListeners();
  }

  /// Add an image hash to the cache
  /// Returns true if image is not a duplicate, false if it is
  bool addImage(HashedImage image, {int threshold = 4}) {
    // Check against existing cached images
    for (final cached in _cachedImages) {
      if (ClientHashUtils.areSimilar(image.hash, cached.hash, threshold: threshold)) {
        _duplicatesDetected++;
        notifyListeners();
        return false; // Duplicate detected
      }
    }

    // Not a duplicate, add to cache
    _cachedImages.add(image);
    notifyListeners();
    return true; // Image added successfully
  }

  /// Check if file is likely a duplicate (fast check using hash)
  /// Returns null if hash computation fails
  Future<bool?> isDuplicate(File file, {int threshold = 4}) async {
    try {
      final bytes = await file.readAsBytes();
      final hash = ClientHashUtils.computeHash(bytes);
      if (hash.isEmpty) return null; // Hash computation failed

      for (final cached in _cachedImages) {
        if (ClientHashUtils.areSimilar(hash, cached.hash, threshold: threshold)) {
          return true; // Duplicate found
        }
      }
      return false; // Not a duplicate
    } catch (e) {
      return null; // Error during computation
    }
  }

  /// Get similarity score between two cached images (0-64, lower = more similar)
  /// Returns null if hashes are invalid
  int? getSimilarityScore(int index1, int index2) {
    if (index1 < 0 || index1 >= _cachedImages.length ||
        index2 < 0 || index2 >= _cachedImages.length) {
      return null;
    }

    return ClientHashUtils.hammingDistance(
      _cachedImages[index1].hash,
      _cachedImages[index2].hash,
    );
  }

  /// Remove an image from cache by file path
  void removeImage(String filePath) {
    _cachedImages.removeWhere((img) => img.file.path == filePath);
    notifyListeners();
  }

  /// Reset duplicate counter
  void resetDuplicateCounter() {
    _duplicatesDetected = 0;
    notifyListeners();
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'cachedImages': _cachedImages.length,
      'duplicatesDetected': _duplicatesDetected,
      'cacheSize': _cachedImages.fold<int>(0, (sum, img) => sum + img.file.lengthSync()),
    };
  }
}
