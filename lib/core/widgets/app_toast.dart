import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_messenger.dart';
import '../utils/haptic_utils.dart';
import '../utils/network_error_message.dart';

enum ToastType { success, error, info, warning }

/// Unified in-app feedback banner — use instead of raw [SnackBar] for consistent UX.
class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;
  static bool _visible = false;

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final safeMessage = type == ToastType.error
        ? NetworkErrorMessage.sanitize(message)
        : message;
    _present(
      overlay: overlay,
      message: safeMessage,
      type: type,
      title: title,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  static void showGlobal(
    String message, {
    ToastType type = ToastType.info,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final navContext = appNavigatorKey.currentContext;
    if (navContext == null) return;
    show(
      navContext,
      message,
      type: type,
      title: title,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  static void success(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) =>
      show(
        context,
        message,
        type: ToastType.success,
        title: title ?? 'Success',
        duration: duration,
      );

  static void error(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) =>
      show(
        context,
        message,
        type: ToastType.error,
        title: title ?? 'Error',
        duration: duration,
      );

  static void info(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) =>
      show(
        context,
        message,
        type: ToastType.info,
        title: title,
        duration: duration,
      );

  static void warning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) =>
      show(
        context,
        message,
        type: ToastType.warning,
        title: title ?? 'Notice',
        duration: duration,
      );

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
    _visible = false;
  }

  static void _present({
    required OverlayState overlay,
    required String message,
    required ToastType type,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    required Duration duration,
    required bool isDark,
  }) {
    dismiss();
    _hapticFor(type);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AppFeedbackToast(
        message: message,
        type: type,
        title: title,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                dismiss();
                onAction();
              },
        onDismiss: dismiss,
        isDark: isDark,
      ),
    );

    overlay.insert(entry);
    _entry = entry;
    _visible = true;
    _timer = Timer(duration, dismiss);
  }

  static void _hapticFor(ToastType type) {
    switch (type) {
      case ToastType.success:
        HapticUtils.success();
      case ToastType.error:
        HapticUtils.error();
      case ToastType.warning:
        HapticUtils.warning();
      case ToastType.info:
        HapticUtils.light();
    }
  }
}

extension AppFeedbackContext on BuildContext {
  void showFeedback(
    String message, {
    ToastType type = ToastType.info,
    String? title,
  }) =>
      AppToast.show(this, message, type: type, title: title);

  void showSuccess(String message, {String? title}) =>
      AppToast.success(this, message, title: title);

  void showError(String message, {String? title}) =>
      AppToast.error(this, message, title: title);

  void showWarning(String message, {String? title}) =>
      AppToast.warning(this, message, title: title);

  void showInfo(String message, {String? title}) =>
      AppToast.info(this, message, title: title);
}

class _AppFeedbackToast extends StatefulWidget {
  final String message;
  final ToastType type;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;
  final bool isDark;

  const _AppFeedbackToast({
    required this.message,
    required this.type,
    this.title,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
    required this.isDark,
  });

  @override
  State<_AppFeedbackToast> createState() => _AppFeedbackToastState();
}

class _AppFeedbackToastState extends State<_AppFeedbackToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _slide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismissAnimated() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  _FeedbackStyle get _style => _FeedbackStyle.forType(widget.type, widget.isDark);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 12;

    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! < -120) {
                  _dismissAnimated();
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF1E1E24).withValues(alpha: 0.94)
                          : Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _style.accent.withValues(alpha: 0.28),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _style.accent.withValues(alpha: 0.16),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: widget.isDark ? 0.35 : 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _style.accent,
                                  _style.accent.withValues(alpha: 0.78),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: _style.accent.withValues(alpha: 0.28),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(_style.icon, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.title != null && widget.title!.trim().isNotEmpty)
                                  Text(
                                    widget.title!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: widget.isDark ? Colors.white : const Color(0xFF1C1921),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                if (widget.title != null && widget.title!.trim().isNotEmpty)
                                  const SizedBox(height: 2),
                                Text(
                                  widget.message,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    height: 1.35,
                                    color: widget.isDark
                                        ? Colors.white.withValues(alpha: 0.82)
                                        : const Color(0xFF4B4A4F),
                                  ),
                                ),
                                if (widget.actionLabel != null && widget.onAction != null) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: widget.onAction,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      foregroundColor: _style.accent,
                                    ),
                                    child: Text(
                                      widget.actionLabel!,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: _dismissAnimated,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: widget.isDark
                                  ? Colors.white.withValues(alpha: 0.55)
                                  : Colors.black.withValues(alpha: 0.38),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackStyle {
  final Color accent;
  final IconData icon;

  const _FeedbackStyle({required this.accent, required this.icon});

  static _FeedbackStyle forType(ToastType type, bool isDark) {
    switch (type) {
      case ToastType.success:
        return const _FeedbackStyle(
          accent: AppColors.success,
          icon: Icons.check_rounded,
        );
      case ToastType.error:
        return const _FeedbackStyle(
          accent: AppColors.error,
          icon: Icons.close_rounded,
        );
      case ToastType.warning:
        return const _FeedbackStyle(
          accent: AppColors.warning,
          icon: Icons.priority_high_rounded,
        );
      case ToastType.info:
        return _FeedbackStyle(
          accent: isDark ? AppColors.primaryLight : AppColors.primary,
          icon: Icons.info_outline_rounded,
        );
    }
  }
}
