import 'package:flutter/material.dart';

/// App-wide forward-navigation throttle.
///
/// Combines:
/// 1. An **in-flight lock** from acquire until the route finishes pushing + settle
/// 2. A **cooldown** so rapid taps cannot open two screens
/// 3. A **stuck timeout** so a failed push never permanently blocks navigation
///
/// Call [tryAcquire] only from [GuardedNavigator].
class NavigationTapGuard {
  NavigationTapGuard._();

  static const Duration defaultCooldown = Duration(milliseconds: 700);
  static const Duration settleDuration = Duration(milliseconds: 850);
  static const Duration stuckTimeout = Duration(seconds: 3);

  static DateTime? _lastAcceptedAt;
  static bool _inFlight = false;
  static DateTime? _inFlightSince;
  static int _settleGeneration = 0;

  /// True while a push is in flight or still inside the cooldown window.
  static bool get isBlocked {
    _selfHealIfStuck();
    if (_inFlight) return true;
    final last = _lastAcceptedAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < defaultCooldown;
  }

  /// Records a navigation attempt. Returns `true` if this tap may proceed.
  static bool tryAcquire({Duration cooldown = defaultCooldown}) {
    _selfHealIfStuck();
    if (_inFlight) return false;

    final now = DateTime.now();
    final last = _lastAcceptedAt;
    if (last != null && now.difference(last) < cooldown) {
      return false;
    }

    _inFlight = true;
    _inFlightSince = now;
    _lastAcceptedAt = now;
    return true;
  }

  /// Called from [NavigationTapGuardObserver.didPush] after Navigator accepts
  /// the route. Keeps the lock until the transition settle window ends.
  static void markPushCompleted() {
    final gen = ++_settleGeneration;
    Future<void>.delayed(settleDuration, () {
      if (gen != _settleGeneration) return;
      _inFlight = false;
      _inFlightSince = null;
    });
  }

  /// Runs [action] once per cooldown. Prefer [tryAcquire] + explicit navigation.
  static void run(
    VoidCallback action, {
    Duration cooldown = defaultCooldown,
  }) {
    if (!tryAcquire(cooldown: cooldown)) return;
    action();
  }

  /// Clears the throttle so the next tap can navigate immediately
  /// (e.g. after the user pops back to a list).
  static void reset() {
    _settleGeneration++;
    _inFlight = false;
    _inFlightSince = null;
    _lastAcceptedAt = null;
  }

  /// Release in-flight without clearing cooldown (failed push before route).
  static void releaseInFlight() {
    _settleGeneration++;
    _inFlight = false;
    _inFlightSince = null;
  }

  static void _selfHealIfStuck() {
    if (!_inFlight || _inFlightSince == null) return;
    if (DateTime.now().difference(_inFlightSince!) > stuckTimeout) {
      _inFlight = false;
      _inFlightSince = null;
    }
  }

  /// Returns a guarded callback suitable for [onTap] / [onPressed].
  static VoidCallback? wrap(
    VoidCallback? action, {
    Duration cooldown = defaultCooldown,
  }) {
    if (action == null) return null;
    return () => run(action, cooldown: cooldown);
  }
}

/// Lightweight tap wrapper for feed cards.
///
/// Does **not** touch [NavigationTapGuard] — navigation throttling belongs
/// solely in [GuardedNavigator]. This widget only prevents the same card from
/// firing its [onTap] twice in a short burst (local UI debounce).
class DebouncedTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Duration cooldown;
  final BorderRadius? borderRadius;
  final HitTestBehavior behavior;

  const DebouncedTap({
    super.key,
    required this.child,
    this.onTap,
    this.cooldown = NavigationTapGuard.defaultCooldown,
    this.borderRadius,
    this.behavior = HitTestBehavior.deferToChild,
  });

  @override
  State<DebouncedTap> createState() => _DebouncedTapState();
}

class _DebouncedTapState extends State<DebouncedTap> {
  DateTime? _lastTapAt;

  void _handleTap() {
    final action = widget.onTap;
    if (action == null) return;

    final now = DateTime.now();
    final last = _lastTapAt;
    if (last != null && now.difference(last) < widget.cooldown) {
      return;
    }
    _lastTapAt = now;
    action();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    if (widget.borderRadius != null) {
      return InkWell(
        onTap: _handleTap,
        borderRadius: widget.borderRadius,
        child: widget.child,
      );
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTap: _handleTap,
      child: widget.child,
    );
  }
}
