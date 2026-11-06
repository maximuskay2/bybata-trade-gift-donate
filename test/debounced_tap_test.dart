import 'package:bybata/core/navigation/guarded_navigator.dart';
import 'package:bybata/core/widgets/debounced_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(NavigationTapGuard.reset);

  test('NavigationTapGuard allows only one acquire per cooldown', () {
    expect(NavigationTapGuard.tryAcquire(), isTrue);
    expect(NavigationTapGuard.tryAcquire(), isFalse);
    expect(NavigationTapGuard.isBlocked, isTrue);
  });

  test('NavigationTapGuard.reset clears block immediately', () {
    expect(NavigationTapGuard.tryAcquire(), isTrue);
    expect(NavigationTapGuard.tryAcquire(), isFalse);
    NavigationTapGuard.reset();
    expect(NavigationTapGuard.tryAcquire(), isTrue);
  });

  test('NavigationTapGuard.wrap ignores duplicate taps', () {
    var count = 0;
    final wrapped = NavigationTapGuard.wrap(() => count++)!;

    wrapped();
    wrapped();
    expect(count, 1);
  });

  test('NavigationTapGuard self-heals after cooldown', () async {
    expect(NavigationTapGuard.tryAcquire(), isTrue);
    expect(NavigationTapGuard.tryAcquire(), isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(NavigationTapGuard.tryAcquire(), isTrue);
  });

  testWidgets('GuardedNavigator blocks duplicate pushes within cooldown',
      (tester) async {
    var pushCount = 0;
    late BuildContext hostContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    void openDetail() {
      GuardedNavigator.push<void>(
        hostContext,
        MaterialPageRoute<void>(
          builder: (_) {
            pushCount++;
            return const Scaffold(body: Text('Detail'));
          },
        ),
      );
    }

    openDetail();
    openDetail();
    await tester.pumpAndSettle();

    expect(pushCount, 1);
  });

  testWidgets('DebouncedTap + GuardedNavigator still navigates on first tap',
      (tester) async {
    var opened = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DebouncedTap(
            onTap: () {
              // Mimic feed cards: DebouncedTap wraps a GuardedNavigator push.
              final ctx = tester.element(find.byType(DebouncedTap));
              GuardedNavigator.push<void>(
                ctx,
                MaterialPageRoute<void>(
                  builder: (_) {
                    opened++;
                    return const Scaffold(body: Text('Opened'));
                  },
                ),
              );
            },
            child: const Text('Card'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Card'));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.text('Opened'), findsOneWidget);
  });

  testWidgets('pop resets guard so next tap works immediately', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [NavigationTapGuardObserver()],
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                GuardedNavigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(),
                      body: const Text('Detail'),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);
  });
}
