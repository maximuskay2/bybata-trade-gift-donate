import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Friendly bottom sheet when leaving an edit screen with unsaved changes.
///
/// Returns `true` if the user chooses to discard and leave,
/// `false` if they keep editing (including dismiss via drag or tap outside).
class DiscardChangesSheet extends StatelessWidget {
  /// Optional noun for copy, e.g. "gift", "trade", "donation".
  final String? itemLabel;

  const DiscardChangesSheet({super.key, this.itemLabel});

  static Future<bool> show(
    BuildContext context, {
    String? itemLabel,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => DiscardChangesSheet(itemLabel: itemLabel),
    );
    return result ?? false;
  }

  String get _headline => 'Leave without saving?';

  String get _body {
    if (itemLabel != null && itemLabel!.isNotEmpty) {
      return 'Your $itemLabel edits are only on this screen until you tap Save changes.';
    }
    return 'Your edits are only saved when you tap Save changes.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final primary = AppColors.primary;
    final onSurface = isDark ? Colors.white : const Color(0xFF1C1B1F);
    final muted = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: muted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primary.withValues(alpha: 0.18),
                      primary.withValues(alpha: 0.06),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primary.withValues(alpha: 0.22),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  size: 36,
                  color: primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _headline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: onSurface,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: muted,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context, false);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Keep editing',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context, true);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Discard changes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
