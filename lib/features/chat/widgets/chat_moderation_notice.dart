import 'package:flutter/material.dart';

/// Subtle disclaimer shown at the top of every chat thread.
class ChatModerationNotice extends StatelessWidget {
  const ChatModerationNotice({super.key});

  static const String message =
      'Messages may be scanned and reviewed to help prevent fraud and policy violations.';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          height: 1.35,
          letterSpacing: 0.1,
          color: scheme.onSurface.withValues(alpha: 0.42),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
