import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Clean PIN entry shell: title, dots, keypad, optional footer.
class PinEntryLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final int pinLength;
  final int filledCount;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback? onBack;
  final IconData backIcon;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final Widget? footer;
  final Widget? belowKeypad;
  /// When true, the close/back control stays tappable during loading.
  final bool allowBackWhileLoading;
  /// Hide the numeric keypad (e.g. while choosing PIN length).
  final bool hideKeypad;

  const PinEntryLayout({
    super.key,
    required this.title,
    required this.subtitle,
    this.pinLength = 6,
    required this.filledCount,
    this.errorMessage,
    this.isLoading = false,
    this.onBack,
    this.backIcon = Icons.arrow_back_ios_new_rounded,
    required this.onDigit,
    required this.onBackspace,
    this.footer,
    this.belowKeypad,
    this.allowBackWhileLoading = false,
    this.hideKeypad = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backEnabled =
        onBack != null && (!isLoading || allowBackWhileLoading);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      onPressed: backEnabled ? onBack : null,
                      icon: Icon(backIcon, size: 20, color: scheme.onSurface),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (pinLength > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pinLength, (i) {
                  final filled = i < filledCount;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: filled ? 14 : 12,
                    height: filled ? 14 : 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? AppColors.primary
                          : scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  );
                }),
              ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (!hideKeypad)
              _PinKeypad(
                onDigit: onDigit,
                onBackspace: onBackspace,
              ),
            if (belowKeypad != null) ...[
              const SizedBox(height: 16),
              belowKeypad!,
            ],
            if (footer != null) ...[
              const SizedBox(height: 8),
              footer!,
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _PinKeypad({
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: child ??
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
            ),
          ),
        ),
      );
    }

    Widget row(List<Widget> keys) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: keys,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          row([
            key('1', onTap: () => onDigit('1')),
            key('2', onTap: () => onDigit('2')),
            key('3', onTap: () => onDigit('3')),
          ]),
          const SizedBox(height: 8),
          row([
            key('4', onTap: () => onDigit('4')),
            key('5', onTap: () => onDigit('5')),
            key('6', onTap: () => onDigit('6')),
          ]),
          const SizedBox(height: 8),
          row([
            key('7', onTap: () => onDigit('7')),
            key('8', onTap: () => onDigit('8')),
            key('9', onTap: () => onDigit('9')),
          ]),
          const SizedBox(height: 8),
          row([
            const SizedBox(width: 72, height: 72),
            key('0', onTap: () => onDigit('0')),
            key(
              '',
              onTap: onBackspace,
              child: Icon(
                Icons.backspace_outlined,
                size: 26,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
