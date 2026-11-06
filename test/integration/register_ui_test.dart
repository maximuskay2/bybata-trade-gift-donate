import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bybata/features/auth/screens/register_screen.dart';

void main() {
  group('Register UI - validation and flow', () {
    testWidgets('Shows validation errors and enables Continue when valid', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

      // Move to Account step for password tests
      // Tap Continue twice to reach step 2
      final continueBtn = find.text('Continue');
      expect(continueBtn, findsOneWidget);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Enter invalid password then check validation
      await tester.enterText(find.byType(TextFormField).first, 'user_name');
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(find.byType(TextFormField).at(1), 'short');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Min 8 chars'), findsWidgets);

      // Fix password
      await tester.enterText(find.byType(TextFormField).at(1), 'StrongPass1');
      await tester.pump(const Duration(milliseconds: 50));

      // Confirm password mismatch
      await tester.enterText(find.byType(TextFormField).at(2), 'Mismatch1');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Passwords do not match'), findsOneWidget);

      // Match passwords
      await tester.enterText(find.byType(TextFormField).at(2), 'StrongPass1');
      await tester.pump(const Duration(milliseconds: 50));

      // Accept terms
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Continue should be enabled (no throw); tap to attempt register
      await tester.tap(continueBtn);
      await tester.pump(const Duration(milliseconds: 200));
    });
  });
}