import 'package:flutter/material.dart';

/// Bottom inset for chat message lists when the composer participates in
/// layout (WhatsApp / Messenger style [ChatComposerStack] Column).
///
/// Only a small breathing gap is needed — do NOT reserve composer height here.
abstract final class ChatComposerOverlay {
  /// Aesthetic gap between the last bubble and the composer / footer.
  static const double listBreathingRoom = 10;

  static double listBottomPadding(
    BuildContext context, {
    double extra = 0,
  }) {
    return listBreathingRoom + extra;
  }
}

/// WhatsApp / Facebook Marketplace layout:
/// message list fills remaining space; typing footer + composer sit below
/// and never overlay bubbles. Keyboard resize is handled by Scaffold.
class ChatComposerStack extends StatelessWidget {
  const ChatComposerStack({
    super.key,
    required this.body,
    required this.composer,
    this.footer = const [],
  });

  final Widget body;
  final Widget composer;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: body),
        ...footer,
        composer,
      ],
    );
  }
}
