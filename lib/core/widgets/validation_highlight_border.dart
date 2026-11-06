import 'package:flutter/material.dart';

/// Wraps non-text controls (media picker, category, deadline) with a red
/// highlight when a required value is missing after submit validation.
class ValidationHighlightBorder extends StatelessWidget {
  final bool highlight;
  final Widget child;
  final String? message;
  final bool isDark;

  const ValidationHighlightBorder({
    super.key,
    required this.highlight,
    required this.child,
    this.message,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!highlight) return child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red, width: 2),
          ),
          padding: const EdgeInsets.all(2),
          child: child,
        ),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline, size: 14, color: Colors.red),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
