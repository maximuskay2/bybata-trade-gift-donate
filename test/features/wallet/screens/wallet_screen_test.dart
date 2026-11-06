import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bybata/features/wallet/screens/wallet_screen.dart';
import 'package:bybata/features/wallet/services/wallet_service.dart';

void main() {
  testWidgets('WalletScreen renders core sections', (WidgetTester tester) async {
    // Arrange
    final walletService = WalletService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: walletService),
        ],
        child: const MaterialApp(
          home: WalletScreen(),
        ),
      ),
    );

    // Initial frame
    await tester.pumpAndSettle();

    // Assert: AppBar and title
    expect(find.text('BYC Wallet'), findsOneWidget);

    // Assert: Quick Actions and tabs (may need additional pumping depending on init)
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Promotions'), findsOneWidget);
    expect(find.text('Rates'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
  });
}
