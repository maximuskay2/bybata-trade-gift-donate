import 'package:flutter/material.dart';

import '../widgets/debounced_tap.dart';

/// Forward navigation helpers — every push is throttled by [NavigationTapGuard].
///
/// Pop / maybePop are intentionally unguarded.
class GuardedNavigator {
  GuardedNavigator._();

  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Route<T> route, {
    bool force = false,
  }) {
    if (!force && !NavigationTapGuard.tryAcquire()) {
      return Future<T?>.value(null);
    }
    try {
      return Navigator.of(context).push<T>(route);
    } catch (_) {
      NavigationTapGuard.releaseInFlight();
      rethrow;
    }
  }

  static Future<T?> pushNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    bool force = false,
  }) {
    if (!force && !NavigationTapGuard.tryAcquire()) {
      return Future<T?>.value(null);
    }
    try {
      return Navigator.of(context).pushNamed<T>(
        routeName,
        arguments: arguments,
      );
    } catch (_) {
      NavigationTapGuard.releaseInFlight();
      rethrow;
    }
  }

  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    BuildContext context,
    Route<T> route, {
    TO? result,
    bool force = false,
  }) {
    if (!force && !NavigationTapGuard.tryAcquire()) {
      return Future<T?>.value(null);
    }
    try {
      return Navigator.of(context).pushReplacement<T, TO>(
        route,
        result: result,
      );
    } catch (_) {
      NavigationTapGuard.releaseInFlight();
      rethrow;
    }
  }

  static Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    TO? result,
    Object? arguments,
    bool force = false,
  }) {
    if (!force && !NavigationTapGuard.tryAcquire()) {
      return Future<T?>.value(null);
    }
    try {
      return Navigator.of(context).pushReplacementNamed<T, TO>(
        routeName,
        result: result,
        arguments: arguments,
      );
    } catch (_) {
      NavigationTapGuard.releaseInFlight();
      rethrow;
    }
  }

  static Future<T?> pushAndRemoveUntil<T extends Object?>(
    BuildContext context,
    Route<T> newRoute,
    RoutePredicate predicate, {
    bool force = false,
  }) {
    if (!force && !NavigationTapGuard.tryAcquire()) {
      return Future<T?>.value(null);
    }
    try {
      return Navigator.of(context).pushAndRemoveUntil<T>(
        newRoute,
        predicate,
      );
    } catch (_) {
      NavigationTapGuard.releaseInFlight();
      rethrow;
    }
  }

  static Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    BuildContext context,
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
    bool force = false,
  }) {
    if (!force && !NavigationTapGuard.tryAcquire()) {
      return Future<T?>.value(null);
    }
    try {
      return Navigator.of(context).pushNamedAndRemoveUntil<T>(
        newRouteName,
        predicate,
        arguments: arguments,
      );
    } catch (_) {
      NavigationTapGuard.releaseInFlight();
      rethrow;
    }
  }
}

/// Clears / settles the navigation throttle with the navigator lifecycle.
class NavigationTapGuardObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Hold the lock through the transition so a second tap cannot stack routes.
    NavigationTapGuard.markPushCompleted();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    NavigationTapGuard.reset();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    NavigationTapGuard.reset();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    NavigationTapGuard.markPushCompleted();
  }
}
