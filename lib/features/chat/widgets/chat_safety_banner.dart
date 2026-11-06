import 'dart:ui';

import 'package:flutter/material.dart';

/// Amber warning shown when outgoing chat text matches leak patterns.
class ChatSafetyBanner extends StatelessWidget {
  const ChatSafetyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.health_and_safety_rounded, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Keep your transaction inside ByBata. Moving to WhatsApp or '
                    'direct bank rails breaks your escrow protection guarantees.',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
