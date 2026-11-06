import 'package:flutter/widgets.dart';

// Deprecated overlay host: now a simple pass-through to render the child only
class FloatingChatHost extends StatelessWidget {
  final Widget? child;
  const FloatingChatHost({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}