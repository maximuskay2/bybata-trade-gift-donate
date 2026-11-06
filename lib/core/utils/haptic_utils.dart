import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Types of haptic feedback available
enum HapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
  success,
  error,
  warning,
  notification,
}

/// Comprehensive haptic feedback utility class
class HapticUtils {
  static bool _isEnabled = true;

  /// Enable or disable haptic feedback globally
  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Check if haptic feedback is enabled
  static bool get isEnabled => _isEnabled;

  /// Basic haptic feedback methods
  
  /// Light impact feedback
  /// Used for: UI element selection, light interactions
  static void light() {
    if (!_isEnabled || kIsWeb) return;
    HapticFeedback.lightImpact();
  }

  /// Medium impact feedback
  /// Used for: button presses, toggle switches
  static void medium() {
    if (!_isEnabled || kIsWeb) return;
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact feedback
  /// Used for: significant actions, alerts, errors
  static void heavy() {
    if (!_isEnabled || kIsWeb) return;
    HapticFeedback.heavyImpact();
  }

  /// Selection feedback
  /// Used for: picker wheels, selections
  static void selection() {
    if (!_isEnabled || kIsWeb) return;
    HapticFeedback.selectionClick();
  }

  /// Contextual feedback methods
  
  /// Success feedback pattern
  /// Used for: successful operations, confirmations
  static void success() {
    if (!_isEnabled || kIsWeb) return;
    light();
  }

  /// Error feedback pattern
  /// Used for: errors, failures, invalid input
  static void error() {
    if (!_isEnabled || kIsWeb) return;
    heavy();
  }

  /// Warning feedback pattern
  /// Used for: warnings, cautions, alerts
  static void warning() {
    if (!_isEnabled || kIsWeb) return;
    medium();
  }

  /// Notification feedback
  /// Used for: incoming notifications, messages
  static void notification() {
    if (!_isEnabled || kIsWeb) return;
    light();
  }

  /// Long press feedback
  /// Used for: long press detection, context menus
  static void longPress() {
    if (!_isEnabled || kIsWeb) return;
    heavy();
  }

  /// Swipe feedback
  /// Used for: card swipes, page changes, dismissals
  static void swipe() {
    if (!_isEnabled || kIsWeb) return;
    light();
  }

  /// Toggle feedback
  /// Used for: switches, checkboxes, toggles
  static void toggle() {
    if (!_isEnabled || kIsWeb) return;
    light();
  }

  /// Button press feedback
  /// Used for: primary buttons, action buttons
  static void buttonPress() {
    if (!_isEnabled || kIsWeb) return;
    medium();
  }

  /// Tab selection feedback
  /// Used for: tab bars, navigation switches
  static void tabSelection() {
    if (!_isEnabled || kIsWeb) return;
    selection();
  }

  /// Pull to refresh feedback
  /// Used for: refresh triggers, reload actions
  static void refresh() {
    if (!_isEnabled || kIsWeb) return;
    medium();
  }

  /// Delete/destructive action feedback
  /// Used for: delete actions, destructive operations
  static void destructive() {
    if (!_isEnabled || kIsWeb) return;
    heavy();
  }

  /// Trigger haptic feedback based on type
  static void trigger(HapticFeedbackType type) {
    switch (type) {
      case HapticFeedbackType.light:
        light();
        break;
      case HapticFeedbackType.medium:
        medium();
        break;
      case HapticFeedbackType.heavy:
        heavy();
        break;
      case HapticFeedbackType.selection:
        selection();
        break;
      case HapticFeedbackType.success:
        success();
        break;
      case HapticFeedbackType.error:
        error();
        break;
      case HapticFeedbackType.warning:
        warning();
        break;
      case HapticFeedbackType.notification:
        notification();
        break;
    }
  }
}

/// Haptic feedback mixin for widgets
mixin HapticFeedbackMixin {
  void hapticLight() => HapticUtils.light();
  void hapticMedium() => HapticUtils.medium();
  void hapticHeavy() => HapticUtils.heavy();
  void hapticSelection() => HapticUtils.selection();
  void hapticSuccess() => HapticUtils.success();
  void hapticError() => HapticUtils.error();
  void hapticWarning() => HapticUtils.warning();
  void hapticNotification() => HapticUtils.notification();
  void hapticLongPress() => HapticUtils.longPress();
  void hapticSwipe() => HapticUtils.swipe();
  void hapticToggle() => HapticUtils.toggle();
  void hapticButtonPress() => HapticUtils.buttonPress();
  void hapticTabSelection() => HapticUtils.tabSelection();
  void hapticRefresh() => HapticUtils.refresh();
  void hapticDestructive() => HapticUtils.destructive();
}

/// Enhanced button with automatic haptic feedback
class HapticButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final HapticFeedbackType hapticType;
  final bool enableHaptic;

  const HapticButton({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.hapticType = HapticFeedbackType.light,
    this.enableHaptic = true,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed != null
          ? () {
              if (enableHaptic) {
                HapticUtils.trigger(hapticType);
              }
              onPressed!();
            }
          : null,
      onLongPress: onLongPress != null
          ? () {
              if (enableHaptic) {
                HapticUtils.longPress();
              }
              onLongPress!();
            }
          : null,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// Haptic gesture detector
class HapticGestureDetector extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final VoidCallback? onTapCancel;
  final bool enableHaptic;
  final HapticFeedbackType tapHapticType;
  final HapticFeedbackType longPressHapticType;

  const HapticGestureDetector({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.enableHaptic = true,
    this.tapHapticType = HapticFeedbackType.light,
    this.longPressHapticType = HapticFeedbackType.heavy,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap != null
          ? () {
              if (enableHaptic) {
                HapticUtils.trigger(tapHapticType);
              }
              onTap!();
            }
          : null,
      onLongPress: onLongPress != null
          ? () {
              if (enableHaptic) {
                HapticUtils.trigger(longPressHapticType);
              }
              onLongPress!();
            }
          : null,
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onTapCancel: onTapCancel,
      child: child,
    );
  }
}

/// Haptic switch
class HapticSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enableHaptic;
  final HapticFeedbackType hapticType;

  const HapticSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.enableHaptic = true,
    this.hapticType = HapticFeedbackType.light,
  });

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged != null
          ? (bool newValue) {
              if (enableHaptic) {
                HapticUtils.trigger(hapticType);
              }
              onChanged!(newValue);
            }
          : null,
    );
  }
}

/// Haptic checkbox
class HapticCheckbox extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool enableHaptic;
  final HapticFeedbackType hapticType;

  const HapticCheckbox({
    super.key,
    this.value,
    this.onChanged,
    this.enableHaptic = true,
    this.hapticType = HapticFeedbackType.light,
  });

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      onChanged: onChanged != null
          ? (bool? newValue) {
              if (enableHaptic) {
                HapticUtils.trigger(hapticType);
              }
              onChanged!(newValue);
            }
          : null,
    );
  }
}