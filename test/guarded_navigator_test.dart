import 'package:bybata/core/widgets/debounced_tap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(NavigationTapGuard.reset);

  test('GuardedNavigator-compatible guard returns completed future semantics',
      () {
    expect(NavigationTapGuard.tryAcquire(), isTrue);
    expect(NavigationTapGuard.tryAcquire(), isFalse);
    NavigationTapGuard.reset();
    expect(NavigationTapGuard.isBlocked, isFalse);
  });
}
