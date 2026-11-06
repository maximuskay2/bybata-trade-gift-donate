import 'package:flutter_test/flutter_test.dart';
import 'package:bybata/features/shared/services/image_deduplication_service.dart';
import 'dart:io';
import 'dart:typed_data';

void main() {
  group('ImageDeduplicationService', () => {
    late ImageDeduplicationService service;

    setUp(() {
      service = ImageDeduplicationService();
    });

    test('initializes with empty cache', () {
      expect(service.cachedImages, isEmpty);
      expect(service.duplicatesDetected, 0);
    });

    test('addImage returns true for new image', () {
      final hash = HashedImage(
        file: File('test_image_1.jpg'),
        hash: '0101010101010101',
      );

      final result = service.addImage(hash);

      expect(result, true);
      expect(service.cachedImages.length, 1);
    });

    test('addImage detects duplicate with threshold', () {
      final hash1 = HashedImage(
        file: File('test_image_1.jpg'),
        hash: '0' * 64, // All zeros
      );

      final hash2 = HashedImage(
        file: File('test_image_2.jpg'),
        hash: '0' * 63 + '1', // Only last bit different (distance = 1)
      );

      service.addImage(hash1);
      final result = service.addImage(hash2, threshold: 4);

      expect(result, false); // Should be detected as duplicate
      expect(service.cachedImages.length, 1); // Should not add
      expect(service.duplicatesDetected, 1);
    });

    test('addImage does not detect different image as duplicate', () {
      final hash1 = HashedImage(
        file: File('test_image_1.jpg'),
        hash: '0' * 64,
      );

      final hash2 = HashedImage(
        file: File('test_image_2.jpg'),
        hash: '1' * 64, // Completely different
      );

      service.addImage(hash1);
      final result = service.addImage(hash2, threshold: 4);

      expect(result, true); // Should not be detected as duplicate
      expect(service.cachedImages.length, 2);
      expect(service.duplicatesDetected, 0);
    });

    test('clearCache removes all images and resets counter', () {
      final hash = HashedImage(
        file: File('test_image_1.jpg'),
        hash: '0101010101010101',
      );

      service.addImage(hash);
      service.duplicatesDetected; // Access to increment counter
      service.clearCache();

      expect(service.cachedImages, isEmpty);
      expect(service.duplicatesDetected, 0);
    });

    test('removeImage removes by file path', () {
      final hash1 = HashedImage(
        file: File('/path/test_1.jpg'),
        hash: '0101010101010101',
      );

      final hash2 = HashedImage(
        file: File('/path/test_2.jpg'),
        hash: '1010101010101010',
      );

      service.addImage(hash1);
      service.addImage(hash2);

      service.removeImage('/path/test_1.jpg');

      expect(service.cachedImages.length, 1);
      expect(service.cachedImages.first.file.path, '/path/test_2.jpg');
    });

    test('getSimilarityScore returns correct distance', () {
      final hash1 = HashedImage(
        file: File('test_1.jpg'),
        hash: '0' * 64,
      );

      final hash2 = HashedImage(
        file: File('test_2.jpg'),
        hash: '0' * 60 + '1111', // 4 bits different
      );

      service.addImage(hash1);
      service.addImage(hash2);

      final similarity = service.getSimilarityScore(0, 1);

      expect(similarity, 4);
    });

    test('getSimilarityScore returns null for invalid indices', () {
      final hash = HashedImage(
        file: File('test_1.jpg'),
        hash: '0101010101010101',
      );

      service.addImage(hash);

      expect(service.getSimilarityScore(0, 5), isNull);
      expect(service.getSimilarityScore(-1, 0), isNull);
    });

    test('resetDuplicateCounter resets counter', () {
      final hash1 = HashedImage(
        file: File('test_1.jpg'),
        hash: '0' * 64,
      );

      final hash2 = HashedImage(
        file: File('test_2.jpg'),
        hash: '0' * 63 + '1',
      );

      service.addImage(hash1);
      service.addImage(hash2, threshold: 4); // Detects duplicate

      expect(service.duplicatesDetected, 1);

      service.resetDuplicateCounter();

      expect(service.duplicatesDetected, 0);
    });

    test('getStats returns correct information', () {
      final hash1 = HashedImage(
        file: File('test_1.jpg'),
        hash: '0101010101010101',
      );

      service.addImage(hash1);

      final stats = service.getStats();

      expect(stats['cachedImages'], 1);
      expect(stats['duplicatesDetected'], 0);
      expect(stats.containsKey('cacheSize'), true);
    });

    test('notifies listeners on changes', () {
      int notifyCount = 0;
      service.addListener(() {
        notifyCount++;
      });

      final hash = HashedImage(
        file: File('test_1.jpg'),
        hash: '0101010101010101',
      );

      service.addImage(hash);

      expect(notifyCount, 1);
    });

    test('respects threshold parameter in addImage', () {
      final hash1 = HashedImage(
        file: File('test_1.jpg'),
        hash: '0' * 64,
      );

      final hash2 = HashedImage(
        file: File('test_2.jpg'),
        hash: '0' * 59 + '11111', // 5 bits different
      );

      service.addImage(hash1);

      // With threshold 4, should be duplicate
      expect(
        service.addImage(hash2, threshold: 4),
        false,
      );

      service.clearCache();
      service.addImage(hash1);

      // With threshold 3, should not be duplicate
      expect(
        service.addImage(hash2, threshold: 3),
        true,
      );
    });

    test('handles multiple duplicates correctly', () {
      final baseHash = '0' * 64;

      // Add base image
      service.addImage(
        HashedImage(file: File('img_1.jpg'), hash: baseHash),
      );

      // Try to add duplicates
      service.addImage(
        HashedImage(file: File('img_2.jpg'), hash: baseHash),
        threshold: 4,
      );
      service.addImage(
        HashedImage(file: File('img_3.jpg'), hash: baseHash),
        threshold: 4,
      );

      expect(service.cachedImages.length, 1);
      expect(service.duplicatesDetected, 2);
    });
  });
}
