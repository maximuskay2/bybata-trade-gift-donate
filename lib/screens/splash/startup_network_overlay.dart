import 'package:flutter/material.dart';

import '../../core/widgets/bybata_loading_indicator.dart';

/// Shown on top of the branded splash when startup is blocked by connectivity.
class StartupNetworkOverlay extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onContinueOffline;
  final String continueOfflineLabel;
  final bool isRetrying;

  const StartupNetworkOverlay({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.onContinueOffline,
    this.continueOfflineLabel = 'Continue with saved account',
    this.isRetrying = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1230).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF7B2CBF).withValues(alpha: 0.22),
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: isRetrying ? null : onRetry,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7B2CBF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: isRetrying
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: BybataLoadingIndicator(
                                    size: BybataLoadingSize.compact,
                                    color: Colors.white,
                                    highlightColor: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.refresh_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Try again',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      if (onContinueOffline != null) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: isRetrying ? null : onContinueOffline,
                          child: Text(
                            continueOfflineLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
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
