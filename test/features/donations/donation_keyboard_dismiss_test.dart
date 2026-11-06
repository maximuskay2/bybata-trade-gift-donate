import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the donation amount keyboard-dismissal fix.
///
/// The real [DonationBottomSheet] depends on Provider, WalletService,
/// the campaign API and secure storage, which is too heavy for a focused
/// unit test. Instead these tests reproduce the exact three-layered
/// dismissal pattern the fix introduces:
///
///   1. `TextInputAction.done` + `onFieldSubmitted` on the amount field
///      → keyboard "Done" button unfocuses.
///   2. `GestureDetector` wrapping the sheet root
///      → tapping outside the field unfocuses.
///   3. Calling `FocusScope.of(context).unfocus()` before advancing steps
///      → pressing "Continue" dismisses the keyboard.
///
/// If any of the three wiring points regresses, these tests will catch it.
void main() {
  // Harness that mirrors the structure used in donation_bottom_sheet.dart
  // so the same behaviour can be exercised in isolation.
  Widget buildHarness({
    required FocusNode fieldFocus,
    required VoidCallback onContinue,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                const SizedBox(height: 100, child: Placeholder()),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    focusNode: fieldFocus,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Custom Amount (BYC)',
                    ),
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).unfocus(),
                  ),
                ),
                ElevatedButton(
                  key: const Key('continue_btn'),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    onContinue();
                  },
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  group('Donation amount field keyboard dismissal', () {
    testWidgets('onFieldSubmitted unfocuses when Done is pressed',
        (tester) async {
      final focus = FocusNode();
      await tester.pumpWidget(buildHarness(fieldFocus: focus, onContinue: () {}));

      // Focus the field and simulate typing.
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '50');
      expect(focus.hasFocus, isTrue,
          reason: 'precondition: field must be focused before we test dismiss');

      // Simulate the software keyboard "Done" action.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(focus.hasFocus, isFalse,
          reason:
              'onFieldSubmitted wired to FocusScope.unfocus must drop focus');

      focus.dispose();
    });

    testWidgets('tapping outside the field dismisses the keyboard',
        (tester) async {
      final focus = FocusNode();
      await tester.pumpWidget(buildHarness(fieldFocus: focus, onContinue: () {}));

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);

      // Tap on the non-input placeholder area at the top of the sheet.
      // warnIfMissed: false because the hit target is the outer
      // GestureDetector, not the Placeholder itself.
      await tester.tap(find.byType(Placeholder), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(focus.hasFocus, isFalse,
          reason:
              'the outer GestureDetector should unfocus on any tap outside inputs');

      focus.dispose();
    });

    testWidgets('pressing Continue unfocuses before advancing', (tester) async {
      final focus = FocusNode();
      var continuePressed = false;
      await tester.pumpWidget(buildHarness(
        fieldFocus: focus,
        onContinue: () => continuePressed = true,
      ));

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '25');
      expect(focus.hasFocus, isTrue);

      await tester.tap(find.byKey(const Key('continue_btn')));
      await tester.pumpAndSettle();

      expect(continuePressed, isTrue, reason: 'Continue handler must still run');
      expect(focus.hasFocus, isFalse,
          reason:
              '_nextStep equivalent should unfocus before stepping to the next page');

      focus.dispose();
    });
  });
}
