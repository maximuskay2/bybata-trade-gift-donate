import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:bybata/core/utils/client_hash_utils.dart';

void main() {
  group('ClientHashUtils', () {
    group('computeHash', () {
      test('returns empty string for null image bytes', () {
        final hash = ClientHashUtils.computeHash(Uint8List(0));
        expect(hash, isEmpty);
      });

      test('returns hash of correct length (64 bits)', () {
        // Create a simple test image
        final image = img.Image(width: 100, height: 100);
        final encoded = img.encodePng(image);
        
        final hash = ClientHashUtils.computeHash(encoded);
        expect(hash.length, 64); // 8x8 = 64 bits
      });

      test('hash contains only 0s and 1s', () {
        final image = img.Image(width: 100, height: 100);
        final encoded = img.encodePng(image);
        
        final hash = ClientHashUtils.computeHash(encoded);
        expect(hash.replaceAll(RegExp('[01]'), ''), isEmpty);
      });

      test('same image produces same hash', () {
        final image = img.Image(width: 100, height: 100);
        final encoded = img.encodePng(image);
        
        final hash1 = ClientHashUtils.computeHash(encoded);
        final hash2 = ClientHashUtils.computeHash(encoded);
        
        expect(hash1, equals(hash2));
      });

      test('different images produce different hashes', () {
        final image1 = img.Image(width: 100, height: 100);
        for (int y = 0; y < 50; y++) {
          for (int x = 0; x < 100; x++) {
            image1.setPixelRgba(x, y, 255, 0, 0); // Red
          }
        }
        
        final image2 = img.Image(width: 100, height: 100);
        for (int y = 0; y < 50; y++) {
          for (int x = 0; x < 100; x++) {
            image2.setPixelRgba(x, y, 0, 0, 255); // Blue
          }
        }
        
        final hash1 = ClientHashUtils.computeHash(img.encodePng(image1));
        final hash2 = ClientHashUtils.computeHash(img.encodePng(image2));
        
        expect(hash1, isNot(equals(hash2)));
      });
    });

    group('hammingDistance', () {
      test('returns -1 for empty hashes', () {
        final distance = ClientHashUtils.hammingDistance('', '0101010101010101');
        expect(distance, -1);
      });

      test('returns -1 for different length hashes', () {
        final distance = ClientHashUtils.hammingDistance('0101', '01010101');
        expect(distance, -1);
      });

      test('returns 0 for identical hashes', () {
        final hash = '0101010101010101';
        final distance = ClientHashUtils.hammingDistance(hash, hash);
        expect(distance, 0);
      });

      test('calculates correct distance for different hashes', () {
        // 3 bits different
        final distance = ClientHashUtils.hammingDistance(
          '0101010101010101',
          '0101010101010100', // Last bit different
        );
        expect(distance, 1);
      });

      test('handles maximum distance (all bits different)', () {
        final hash1 = '0' * 64;
        final hash2 = '1' * 64;
        final distance = ClientHashUtils.hammingDistance(hash1, hash2);
        expect(distance, 64);
      });
    });

    group('areSimilar', () {
      test('returns true for identical hashes with default threshold', () {
        final hash = '0101010101010101';
        expect(
          ClientHashUtils.areSimilar(hash, hash),
          true,
        );
      });

      test('returns false for invalid hashes', () {
        expect(
          ClientHashUtils.areSimilar('', '0101010101010101'),
          false,
        );
      });

      test('respects threshold parameter', () {
        final hash1 = '0' * 64;
        final hash2 = '0' * 60 + '1' * 4; // 4 bits different

        // With threshold 3, should be false
        expect(
          ClientHashUtils.areSimilar(hash1, hash2, threshold: 3),
          false,
        );

        // With threshold 5, should be true
        expect(
          ClientHashUtils.areSimilar(hash1, hash2, threshold: 5),
          true,
        );
      });

      test('correctly identifies very similar images', () {
        // Both hashes mostly same (distance 2)
        final hash1 = '0' * 62 + '11';
        final hash2 = '0' * 62 + '10';
        
        expect(
          ClientHashUtils.areSimilar(hash1, hash2, threshold: 4),
          true,
        );
      });
    });
  });
}
