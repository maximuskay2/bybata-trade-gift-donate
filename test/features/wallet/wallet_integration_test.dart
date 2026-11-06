import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bybata/features/wallet/services/wallet_service.dart';
import 'package:bybata/features/wallet/services/wallet_security_service.dart';
import 'package:bybata/features/wallet/models/wallet_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Wallet Integration Tests', () {
    late WalletService walletService;
    late WalletSecurityService securityService;

    setUp(() {
      walletService = WalletService();
      securityService = WalletSecurityService();
    });

    tearDown(() {
      walletService.dispose();
      securityService.dispose();
    });

    testWidgets('Complete wallet flow with security', (WidgetTester tester) async {
      // Step 1: Initialize services
      await securityService.initialize();
      await walletService.initializeWallet('integration_test_user');

      expect(walletService.isInitialized, isTrue);
      expect(walletService.currentBalance, isNotNull);

      // Step 2: Set up security
      final pinSetupResult = await securityService.setupPin('7890');
      expect(pinSetupResult, isTrue);
      expect(securityService.isPinEnabled, isTrue);

      // Step 3: Lock and unlock wallet
      await securityService.lockWallet();
      expect(securityService.isWalletLocked, isTrue);

      final unlockResult = await securityService.verifyPin('7890');
      expect(unlockResult, isTrue);
      expect(securityService.isWalletLocked, isFalse);

      // Step 4: Fund wallet
      final added = await walletService.addPaymentMethod(
        type: PaymentMethodType.creditCard,
        name: 'Test Payment Method',
        displayName: 'Test Payment Method ****4242',
        isDefault: true,
      );

      final initialBalance = walletService.currentBalance!.amount;
      final fundResult = await walletService.fundWallet(
        amount: 100.0,
        paymentMethodId: added!.id,
      );

      expect(fundResult, isNotNull);
      expect(walletService.currentBalance!.amount, greaterThan(initialBalance));

      // Step 5: Send BYC
      final balanceBeforeSend = walletService.currentBalance!.amount;
      final sendResult = await walletService.sendBYC(
        recipientId: 'test_recipient',
        recipientName: 'Recipient',
        amount: 25.0,
        note: 'Integration test transfer',
      );

      expect(sendResult, isNotNull);
      expect(walletService.currentBalance!.amount, lessThan(balanceBeforeSend));

      // Step 6: Check transaction history
      final transactions = walletService.allTransactions;
      expect(transactions.length, greaterThanOrEqualTo(2)); // Fund + Send

      final fundTransaction = transactions.firstWhere(
        (t) => t.type == TransactionType.fund,
      );
      expect(fundTransaction.amount, equals(100.0));

      final sendTransaction = transactions.firstWhere(
        (t) => t.type == TransactionType.send,
      );
      expect(sendTransaction.amount, equals(25.0));
      expect(sendTransaction.note, equals('Integration test transfer'));

      // Step 7: Check promotions
      final promotions = walletService.availablePromotions;
      expect(promotions, isNotNull);

      // Step 8: Check conversion rates
      final rates = walletService.conversionRates;
      expect(rates, isNotNull);
      expect(rates.isNotEmpty, isTrue);

      // Step 9: Test security reset
      await securityService.resetSecurity();
      expect(securityService.isPinEnabled, isFalse);
      expect(securityService.isWalletLocked, isFalse);
    });

    testWidgets('Wallet error handling and recovery', (WidgetTester tester) async {
      // Test initialization with invalid data
      try {
        await walletService.initializeWallet('');
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isException);
      }

      // Test recovery after error
      await walletService.initializeWallet('recovery_test_user');
      expect(walletService.isInitialized, isTrue);
      expect(walletService.error, isNull);

      // Test insufficient funds scenario
      await walletService.initializeWallet('low_balance_user');
      final balance = walletService.currentBalance!.amount;

      try {
        await walletService.sendBYC(
          recipientId: 'test_recipient',
          recipientName: 'Recipient',
          amount: balance + 1000, // More than available
        );
        fail('Should have thrown an exception for insufficient funds');
      } catch (e) {
        expect(e, isException);
      }

      // Ensure service is still functional after error
      expect(walletService.isInitialized, isTrue);
    });

    testWidgets('Security edge cases and recovery', (WidgetTester tester) async {
      await securityService.initialize();

      // Test multiple failed PIN attempts (but not enough to lock)
      await securityService.setupPin('1111');
      
      expect(await securityService.verifyPin('0000'), isFalse);
      expect(await securityService.verifyPin('2222'), isFalse);
      expect(await securityService.verifyPin('3333'), isFalse);
      
      // Correct PIN should still work
      expect(await securityService.verifyPin('1111'), isTrue);

      // Test PIN change with security enabled
      final changeResult = await securityService.changePin('1111', '4444');
      expect(changeResult, isTrue);
      
      expect(await securityService.verifyPin('1111'), isFalse);
      expect(await securityService.verifyPin('4444'), isTrue);

      // Test disable PIN
      final disableResult = await securityService.disablePin('4444');
      expect(disableResult, isTrue);
      expect(securityService.isPinEnabled, isFalse);
    });

    testWidgets('Concurrent operations handling', (WidgetTester tester) async {
      await securityService.initialize();
      await walletService.initializeWallet('concurrent_test_user');

      // Fund wallet first to have sufficient balance
      final added = await walletService.addPaymentMethod(
        type: PaymentMethodType.creditCard,
        name: 'Concurrent Test Payment',
        displayName: 'Concurrent Test Payment ****1111',
        isDefault: true,
      );

      await walletService.fundWallet(
        amount: 1000.0,
        paymentMethodId: added!.id,
      );

      // Test concurrent balance refresh
      final refreshFutures = List.generate(5, (index) => 
        walletService.refreshBalance()
      );

      await Future.wait(refreshFutures);
      expect(walletService.currentBalance, isNotNull);

      // Test concurrent conversion rate refresh
      final rateFutures = List.generate(3, (index) => 
        walletService.refreshConversionRates()
      );

      await Future.wait(rateFutures);
      expect(walletService.conversionRates, isNotNull);
    });

    testWidgets('Data persistence and recovery', (WidgetTester tester) async {
      // Set up initial state
      await securityService.initialize();
      await securityService.setupPin('5555');
      await securityService.setAutoLockTimeout(10);

      // Simulate app restart by creating new service instances
      final newSecurityService = WalletSecurityService();
      await newSecurityService.initialize();

      // Check that settings persisted
      expect(newSecurityService.isPinEnabled, isTrue);
      expect(newSecurityService.autoLockTimeout, equals(10));

      // Verify PIN still works
      expect(await newSecurityService.verifyPin('5555'), isTrue);

      // Clean up
      newSecurityService.dispose();
    });
  });
}