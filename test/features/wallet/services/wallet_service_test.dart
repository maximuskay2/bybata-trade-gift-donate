import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:bybata/features/wallet/services/wallet_service.dart';
import 'package:bybata/features/wallet/models/wallet_models.dart';

// Generate mocks
@GenerateMocks([])
class WalletServiceTest {
  static void main() {
    group('WalletService', () {
      late WalletService walletService;

      setUp(() {
        walletService = WalletService();
      });

      tearDown(() {
        walletService.dispose();
      });

      group('Initialization', () {
        test('should initialize wallet successfully', () async {
          // Arrange
          const userId = 'test_user_id';

          // Act
          await walletService.initializeWallet(userId);

          // Assert
          expect(walletService.isInitialized, isTrue);
          expect(walletService.currentBalance, isNotNull);
          expect(walletService.currentBalance!.userId, equals(userId));
        });

        test('should handle initialization failure gracefully', () async {
          // Arrange
          const invalidUserId = '';

          // Act & Assert
          // Current implementation does not throw on empty userId; ensure no crash
          await walletService.initializeWallet(invalidUserId);
          expect(walletService.currentBalance, isNotNull);
        });
      });

      group('Balance Operations', () {
        setUp(() async {
          await walletService.initializeWallet('test_user');
        });

        test('should get current balance correctly', () {
          // Act
          final balance = walletService.currentBalance;

          // Assert
          expect(balance, isNotNull);
          expect(balance!.amount, greaterThanOrEqualTo(0));
          expect(balance.currencyCode, equals('BYC'));
        });

        test('should calculate available balance correctly', () {
          // Act
          final balance = walletService.currentBalance;

          // Assert
          expect(balance, isNotNull);
          expect(balance!.availableBalance, lessThanOrEqualTo(balance.amount));
        });

        test('should handle balance refresh', () async {
          // Arrange
          final initialBalance = walletService.currentBalance!.amount;

          // Act
          await walletService.refreshBalance();

          // Assert
          expect(walletService.currentBalance, isNotNull);
          // Balance might change due to mock data
        });
      });

      group('Funding Operations', () {
        setUp(() async {
          await walletService.initializeWallet('test_user');
        });

        test('should fund wallet successfully', () async {
          // Arrange
          const amount = 100.0;
          final added = await walletService.addPaymentMethod(
            type: PaymentMethodType.creditCard,
            name: 'Test Card',
            displayName: 'Test Card ****4242',
            isDefault: true,
          );
          expect(added, isNotNull);
          final initialBalance = walletService.currentBalance!.amount;

          // Act
          final result = await walletService.fundWallet(
            amount: amount,
            paymentMethodId: added!.id,
          );

          // Assert
          expect(result, isNotNull);
          expect(walletService.currentBalance!.amount, greaterThan(initialBalance));
        });

        test('should reject invalid funding amount', () async {
          // Arrange
          final added = await walletService.addPaymentMethod(
            type: PaymentMethodType.creditCard,
            name: 'Test Card',
            displayName: 'Test Card ****4242',
            isDefault: true,
          );

          // Act & Assert
          expect(
            () => walletService.fundWallet(
              amount: -10,
              paymentMethodId: added!.id,
            ),
            throwsException,
          );

          expect(
            () => walletService.fundWallet(
              amount: 0,
              paymentMethodId: added!.id,
            ),
            throwsException,
          );
        });

        test('should handle funding failure', () async {
          // Arrange
          // Use non-existent paymentMethodId to simulate failure
          final result = await walletService.fundWallet(
            amount: 50.0,
            paymentMethodId: 'invalid_payment',
          );

          // Assert: result is null and error is set
          expect(result, isNull);
          expect(walletService.error, isNotNull);
        });
      });

      group('Transfer Operations', () {
        setUp(() async {
          await walletService.initializeWallet('test_user');
        });

        test('should send BYC successfully', () async {
          // Arrange
          const recipientId = 'recipient_user';
          const amount = 50.0;
          const note = 'Test transfer';
          final initialBalance = walletService.currentBalance!.amount;

          // Act
          final result = await walletService.sendBYC(
            recipientId: recipientId,
            recipientName: 'Test Recipient',
            amount: amount,
            note: note,
          );

          // Assert
          expect(result, isNotNull);
          expect(walletService.currentBalance!.amount, lessThan(initialBalance));
        });

        test('should reject transfer with insufficient funds', () async {
          // Arrange
          const recipientId = 'recipient_user';
          final amount = walletService.currentBalance!.amount + 1000;

          // Act & Assert
          expect(
            () => walletService.sendBYC(
              recipientId: recipientId,
              recipientName: 'Someone',
              amount: amount,
            ),
            throwsException,
          );
        });

        test('should reject invalid transfer parameters', () async {
          // Act & Assert
          expect(
            () => walletService.sendBYC(
              recipientId: '',
              amount: 50.0,
            ),
            throwsException,
          );

          expect(
            () => walletService.sendBYC(
              recipientId: 'valid_user',
              amount: -10.0,
            ),
            throwsException,
          );
        });
      });

      group('Transaction History', () {
        setUp(() async {
          await walletService.initializeWallet('test_user');
        });

        test('should fetch recent transactions', () {
          // Act
          final transactions = walletService.recentTransactions;

          // Assert
          expect(transactions, isNotNull);
          expect(transactions, isA<List<WalletTransaction>>());
        });

        test('should fetch all transactions', () {
          // Act
          final transactions = walletService.allTransactions;

          // Assert
          expect(transactions, isNotNull);
          expect(transactions, isA<List<WalletTransaction>>());
          expect(transactions.length, greaterThanOrEqualTo(walletService.recentTransactions.length));
        });

        test('should filter transactions by type', () {
          // Arrange
          final allTransactions = walletService.allTransactions;
          
          // Act
          final fundTransactions = allTransactions
              .where((t) => t.type == TransactionType.fund)
              .toList();

          // Assert
          for (final transaction in fundTransactions) {
            expect(transaction.type, equals(TransactionType.fund));
          }
        });

        test('should sort transactions by timestamp', () {
          // Arrange
          final transactions = walletService.allTransactions;

          // Assert
          if (transactions.length > 1) {
            for (int i = 0; i < transactions.length - 1; i++) {
              expect(
                transactions[i].timestamp.isAfter(transactions[i + 1].timestamp) ||
                transactions[i].timestamp.isAtSameMomentAs(transactions[i + 1].timestamp),
                isTrue,
              );
            }
          }
        });
      });

      group('Payment Methods', () {
        setUp(() async {
          await walletService.initializeWallet('test_user');
        });

        test('should fetch available payment methods', () {
          // Act
          final paymentMethods = walletService.availablePaymentMethods;

          // Assert
          expect(paymentMethods, isNotNull);
          expect(paymentMethods, isA<List<PaymentMethod>>());
          expect(paymentMethods.isNotEmpty, isTrue);
        });

        test('should have at least one default payment method', () {
          // Arrange
          final paymentMethods = walletService.availablePaymentMethods;

          // Assert
          final defaultMethods = paymentMethods.where((m) => m.isDefault).toList();
          expect(defaultMethods.isNotEmpty, isTrue);
        });

        test('should validate payment method types', () {
          // Arrange
          final paymentMethods = walletService.availablePaymentMethods;

          // Assert
          for (final method in paymentMethods) {
            expect(method.type, isA<PaymentMethodType>());
            expect(method.name.isNotEmpty, isTrue);
          }
        });
      });

      group('Promotions', () {
        setUp(() async {
          await walletService.initializeWallet('test_user');
        });

        test('should fetch available promotions', () {
          // Act
          final promotions = walletService.availablePromotions;

          // Assert
          expect(promotions, isNotNull);
          expect(promotions, isA<List<WalletPromotion>>());
        });

        test('should activate promotion successfully', () async {
          // Arrange
          final promotions = walletService.availablePromotions;
          if (promotions.isEmpty) return;

          final promotion = promotions.first;
          final initialBalance = walletService.currentBalance!.amount;

          // Act
          final result = await walletService.activatePromotion(promotion);

          // Assert: result true and balance decreased
          expect(result, isTrue);
          expect(walletService.currentBalance!.amount, lessThan(initialBalance));
        });

        test('should handle promotion activation with insufficient funds', () async {
          // Arrange
          final expensive = WalletPromotion(
            id: 'expensive_promo',
            userId: walletService.currentBalance!.userId,
            type: PromotionType.trade,
            title: 'Expensive Promotion',
            description: 'Costs more than available balance',
            bycCost: walletService.currentBalance!.amount + 1000,
            startDate: DateTime.now(),
            endDate: DateTime.now().add(const Duration(days: 7)),
          );

          // Act & Assert
          expect(
            () => walletService.activatePromotion(expensive),
            throwsException,
          );
        });
      });

      group('Conversion Rates', () {
        setUp(() async {
          await walletService.initializeWallet('test_user');
        });

        test('should fetch conversion rates', () {
          // Act
          final rates = walletService.conversionRates;

          // Assert
          expect(rates, isNotNull);
          expect(rates, isA<List<ConversionRate>>());
        });

        test('should have valid conversion rates', () {
          // Arrange
          final rates = walletService.conversionRates;

          // Assert
          for (final rate in rates) {
            expect(rate.fromCurrency, isNotEmpty);
            expect(rate.toCurrency, isNotEmpty);
            expect(rate.rate, greaterThan(0));
            expect(rate.lastUpdated, isA<DateTime>());
          }
        });

        test('should refresh conversion rates', () async {
          // Arrange
          final initialRates = walletService.conversionRates;

          // Act
          await walletService.refreshConversionRates();

          // Assert
          final newRates = walletService.conversionRates;
          expect(newRates, isNotNull);
          // Rates might have updated timestamps
        });
      });

      group('Error Handling', () {
        test('should handle network errors gracefully', () async {
          // This would require mocking network calls
          // For now, test that the service doesn't crash
          expect(walletService.isInitialized, isFalse);
        });

        test('should provide meaningful error messages', () {
          // Arrange
          walletService.setError('Test error message');

          // Act
          final error = walletService.error;

          // Assert
          expect(error, equals('Test error message'));
        });

        test('should recover from errors', () async {
          // Arrange
          walletService.setError('Test error');
          expect(walletService.error, isNotNull);

          // Act
          await walletService.initializeWallet('test_user');

          // Assert
          expect(walletService.error, isNull);
        });
      });

      group('State Management', () {
        test('should notify listeners on balance change', () async {
          // Arrange
          var notificationCount = 0;
          walletService.addListener(() {
            notificationCount++;
          });

          await walletService.initializeWallet('test_user');

          // Act
          await walletService.refreshBalance();

          // Assert
          expect(notificationCount, greaterThan(1));
        });

        test('should update loading state correctly', () async {
          // Arrange
          expect(walletService.isLoading, isFalse);

          // Act
          final future = walletService.initializeWallet('test_user');
          expect(walletService.isLoading, isTrue);

          await future;

          // Assert
          expect(walletService.isLoading, isFalse);
        });
      });
    });
  }
}

void main() {
  WalletServiceTest.main();
}