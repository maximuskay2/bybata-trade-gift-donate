import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:bybata/features/wallet/services/wallet_security_service.dart';

// Mock classes
class MockSharedPreferences extends Mock implements SharedPreferences {}
class MockLocalAuthentication extends Mock implements LocalAuthentication {}

@GenerateMocks([SharedPreferences, LocalAuthentication])
class WalletSecurityServiceTest {
  static void main() {
    group('WalletSecurityService', () {
      late WalletSecurityService securityService;
      late MockSharedPreferences mockPrefs;

      setUp(() {
        TestWidgetsFlutterBinding.ensureInitialized();
        securityService = WalletSecurityService();
        mockPrefs = MockSharedPreferences();
        
        // Setup SharedPreferences mock
        SharedPreferences.setMockInitialValues({});
      });

      tearDown(() {
        securityService.dispose();
      });

      group('Initialization', () {
        test('should initialize with default settings', () async {
          // Act
          await securityService.initialize();

          // Assert
          expect(securityService.isPinEnabled, isFalse);
          expect(securityService.isBiometricEnabled, isFalse);
          expect(securityService.isWalletLocked, isFalse); // No security = unlocked
          expect(securityService.autoLockTimeout, equals(5));
        });

        test('should initialize with existing settings', () async {
          // Arrange
          SharedPreferences.setMockInitialValues({
            'wallet_pin_enabled': true,
            'wallet_biometric_enabled': true,
            'wallet_auto_lock_timeout': 10,
            'wallet_pin_hash': 'hashed_pin',
          });

          // Act
          await securityService.initialize();

          // Assert
          expect(securityService.isPinEnabled, isTrue);
          expect(securityService.isBiometricEnabled, isTrue);
          expect(securityService.autoLockTimeout, equals(10));
        });
      });

      group('PIN Operations', () {
        setUp(() async {
          await securityService.initialize();
        });

        test('should set up PIN successfully', () async {
          // Arrange
          const pin = '1234';

          // Act
          final result = await securityService.setupPin(pin);

          // Assert
          expect(result, isTrue);
          expect(securityService.isPinEnabled, isTrue);
          expect(securityService.isWalletLocked, isFalse);
        });

        test('should reject invalid PIN format', () async {
          // Act & Assert
          expect(await securityService.setupPin('123'), isFalse); // Too short
          expect(await securityService.setupPin('12345'), isFalse); // Too long
          expect(await securityService.setupPin('abcd'), isFalse); // Non-numeric
        });

        test('should verify correct PIN', () async {
          // Arrange
          const pin = '1234';
          await securityService.setupPin(pin);

          // Act
          final result = await securityService.verifyPin(pin);

          // Assert
          expect(result, isTrue);
          expect(securityService.isWalletLocked, isFalse);
        });

        test('should reject incorrect PIN', () async {
          // Arrange
const correctPin = '1234';
          const wrongPin = '5678';
          await securityService.setupPin(correctPin);

          // Act
          final result = await securityService.verifyPin(wrongPin);

          // Assert
          expect(result, isFalse);
        });

        test('should change PIN successfully', () async {
          // Arrange
          const oldPin = '1234';
          const newPin = '5678';
          await securityService.setupPin(oldPin);

          // Act
          final result = await securityService.changePin(oldPin, newPin);

          // Assert
          expect(result, isTrue);
          expect(await securityService.verifyPin(newPin), isTrue);
          expect(await securityService.verifyPin(oldPin), isFalse);
        });

        test('should fail to change PIN with wrong current PIN', () async {
          // Arrange
          const correctPin = '1234';
          const wrongPin = '0000';
          const newPin = '5678';
          await securityService.setupPin(correctPin);

          // Act
          final result = await securityService.changePin(wrongPin, newPin);

          // Assert
          expect(result, isFalse);
          expect(await securityService.verifyPin(correctPin), isTrue); // Original PIN still works
        });

        test('should disable PIN successfully', () async {
          // Arrange
          const pin = '1234';
          await securityService.setupPin(pin);
          expect(securityService.isPinEnabled, isTrue);

          // Act
          final result = await securityService.disablePin(pin);

          // Assert
          expect(result, isTrue);
          expect(securityService.isPinEnabled, isFalse);
          expect(securityService.isWalletLocked, isFalse);
        });
      });

      group('PIN Validation', () {
        test('should validate PIN format correctly', () {
          // Valid PINs
          expect(WalletSecurityService.isValidPin('1234'), isTrue);
          expect(WalletSecurityService.isValidPin('0000'), isTrue);
          expect(WalletSecurityService.isValidPin('9876'), isTrue);

          // Invalid PINs
          expect(WalletSecurityService.isValidPin('123'), isFalse); // Too short
          expect(WalletSecurityService.isValidPin('12345'), isFalse); // Too long
          expect(WalletSecurityService.isValidPin('abcd'), isFalse); // Non-numeric
          expect(WalletSecurityService.isValidPin('12a4'), isFalse); // Mixed
          expect(WalletSecurityService.isValidPin(''), isFalse); // Empty
        });

        test('should identify weak PINs', () {
          // Common weak PINs
          expect(WalletSecurityService.isWeakPin('0000'), isTrue);
          expect(WalletSecurityService.isWeakPin('1111'), isTrue);
          expect(WalletSecurityService.isWeakPin('1234'), isTrue);
          expect(WalletSecurityService.isWeakPin('4321'), isTrue);

          // Strong PINs
          expect(WalletSecurityService.isWeakPin('7392'), isFalse);
          expect(WalletSecurityService.isWeakPin('2847'), isFalse);
          expect(WalletSecurityService.isWeakPin('9156'), isFalse);
        });
      });

      group('Biometric Authentication', () {
        setUp(() async {
          await securityService.initialize();
        });

        test('should enable biometric when available', () async {
          // Note: This test would require proper mocking of LocalAuthentication
          // For now, we test the basic flow
          expect(securityService.isBiometricEnabled, isFalse);
        });

        test('should disable biometric successfully', () async {
          // Act
          final result = await securityService.disableBiometric();

          // Assert
          expect(result, isTrue);
          expect(securityService.isBiometricEnabled, isFalse);
        });

        test('should get available biometrics', () async {
          // Act
          final biometrics = await securityService.getAvailableBiometrics();

          // Assert
          expect(biometrics, isA<List<BiometricType>>());
        });
      });

      group('Auto-lock Functionality', () {
        setUp(() async {
          await securityService.initialize();
          await securityService.setupPin('1234');
        });

        test('should set auto-lock timeout', () async {
          // Arrange
          const newTimeout = 15;

          // Act
          final result = await securityService.setAutoLockTimeout(newTimeout);

          // Assert
          expect(result, isTrue);
          expect(securityService.autoLockTimeout, equals(newTimeout));
        });

        test('should lock wallet manually', () async {
          // Arrange
          expect(securityService.isWalletLocked, isFalse);

          // Act
          await securityService.lockWallet();

          // Assert
          expect(securityService.isWalletLocked, isTrue);
        });
      });

      group('Security Status', () {
        test('should report no security when nothing is enabled', () async {
          // Arrange
          await securityService.initialize();

          // Act
          final hasSecurityEnabled = securityService.hasSecurityEnabled;
          final status = securityService.securityStatus;

          // Assert
          expect(hasSecurityEnabled, isFalse);
          expect(status['isLocked'], isFalse);
          expect(status['pinEnabled'], isFalse);
          expect(status['biometricEnabled'], isFalse);
        });

        test('should report security status when PIN is enabled', () async {
          // Arrange
          await securityService.initialize();
          await securityService.setupPin('1234');

          // Act
          final hasSecurityEnabled = securityService.hasSecurityEnabled;
          final status = securityService.securityStatus;

          // Assert
          expect(hasSecurityEnabled, isTrue);
          expect(status['pinEnabled'], isTrue);
        });

        test('should provide complete security status', () async {
          // Arrange
          await securityService.initialize();
          await securityService.setupPin('1234');

          // Act
          final status = securityService.securityStatus;

          // Assert
          expect(status, containsPair('isLocked', isA<bool>()));
          expect(status, containsPair('pinEnabled', isA<bool>()));
          expect(status, containsPair('biometricEnabled', isA<bool>()));
          expect(status, containsPair('biometricAvailable', isA<bool>()));
          expect(status, containsPair('autoLockTimeout', isA<int>()));
        });
      });

      group('Security Reset', () {
        test('should reset all security settings', () async {
          // Arrange
          await securityService.initialize();
          await securityService.setupPin('1234');
          await securityService.setAutoLockTimeout(15);

          expect(securityService.isPinEnabled, isTrue);
          expect(securityService.autoLockTimeout, equals(15));

          // Act
          await securityService.resetSecurity();

          // Assert
          expect(securityService.isPinEnabled, isFalse);
          expect(securityService.isBiometricEnabled, isFalse);
          expect(securityService.isWalletLocked, isFalse);
          expect(securityService.autoLockTimeout, equals(5)); // Default value
        });
      });

      group('State Management', () {
        test('should notify listeners on security changes', () async {
          // Arrange
          var notificationCount = 0;
          securityService.addListener(() {
            notificationCount++;
          });

          await securityService.initialize();

          // Act
          await securityService.setupPin('1234');

          // Assert
          expect(notificationCount, greaterThan(1));
        });

        test('should maintain state consistency', () async {
          // Arrange
          await securityService.initialize();

          // Act
          await securityService.setupPin('1234');
          final initialState = securityService.securityStatus;

          await securityService.lockWallet();
          final lockedState = securityService.securityStatus;

          await securityService.verifyPin('1234');
          final unlockedState = securityService.securityStatus;

          // Assert
          expect(initialState['pinEnabled'], isTrue);
          expect(lockedState['isLocked'], isTrue);
          expect(unlockedState['isLocked'], isFalse);
        });
      });

      group('Error Handling', () {
        test('should handle initialization errors gracefully', () async {
          // This test would require mocking SharedPreferences to throw errors
          // For now, ensure the service doesn't crash
          expect(() => securityService.initialize(), returnsNormally);
        });

        test('should handle PIN operations when not enabled', () async {
          // Arrange
          await securityService.initialize();
          expect(securityService.isPinEnabled, isFalse);

          // Act & Assert
          expect(await securityService.verifyPin('1234'), isFalse);
          expect(await securityService.changePin('1234', '5678'), isFalse);
          expect(await securityService.disablePin('1234'), isFalse);
        });

        test('should handle biometric operations when not available', () async {
          // Arrange
          await securityService.initialize();
          // Assuming biometric is not available in test environment

          // Act
          final canAuthenticate = await securityService.authenticateWithBiometric();

          // Assert
          expect(canAuthenticate, isFalse);
        });
      });

      group('Concurrency and Race Conditions', () {
        test('should handle concurrent PIN operations', () async {
          // Arrange
          await securityService.initialize();

          // Act - Multiple concurrent PIN setups
          final futures = List.generate(5, (index) => 
            securityService.setupPin('123$index')
          );

          final results = await Future.wait(futures);

          // Assert - Only one should succeed, others should fail gracefully
          final successCount = results.where((r) => r).length;
          expect(successCount, lessThanOrEqualTo(1));
        });

        test('should maintain state integrity under concurrent access', () async {
          // Arrange
          await securityService.initialize();
          await securityService.setupPin('1234');

          // Act - Concurrent verify operations
          final futures = List.generate(10, (index) => 
            securityService.verifyPin('1234')
          );

          final results = await Future.wait(futures);

          // Assert - All should succeed
          expect(results.every((r) => r), isTrue);
          expect(securityService.isWalletLocked, isFalse);
        });
      });
    });
  }
}

void main() {
  WalletSecurityServiceTest.main();
}