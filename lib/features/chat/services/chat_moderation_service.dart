import 'package:flutter/material.dart';

/// Parses outgoing chat text for off-platform contact / payment leaks.
class ChatModerationService {
  ChatModerationService._();

  /// Captures phone arrays, blocked platforms, and call keywords.
  static final RegExp leakPattern = RegExp(
    r'(whatsapp|\bwa\.me\b|viber|telegram|digit|phone|call me|contact|0[789]0[0-9]{8}|\+?234[0-9]{10})',
    caseSensitive: false,
  );

  static bool evaluateMessageSecurity(String text) {
    if (text.trim().isEmpty) return false;
    return leakPattern.hasMatch(text);
  }

  /// Blocks send until the user acknowledges escrow risk.
  static Future<bool> confirmInAppEscrow(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Stay protected in ByBata',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            'Moving to WhatsApp, phone calls, or direct bank rails breaks your '
            'escrow protection guarantees. Disputes and trust scores may not apply '
            'outside the app.\n\n'
            'Keep this conversation inside ByBata to stay covered.',
            style: TextStyle(
              height: 1.45,
              color: scheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Edit message'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('I Understand, Keep It In-App'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }
}
