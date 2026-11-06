import 'package:flutter/material.dart';

/// True when the chat list is already near the bottom (user is "following"
/// the thread). Used to avoid yanking the scroll position when older messages
/// load or the provider rebuilds while the user is reading history.
bool isChatNearBottom(
  ScrollController controller, {
  double threshold = 140,
}) {
  if (!controller.hasClients) return true;
  final pos = controller.position;
  if (!pos.hasPixels || !pos.hasContentDimensions) return true;
  return (pos.maxScrollExtent - pos.pixels) <= threshold;
}

/// Scroll to the latest message — only if [force] or the user is near bottom.
///
/// Defers one frame so keyboard / reply / new-bubble layout can settle first
/// (WhatsApp / Messenger behavior).
void scrollChatToBottom(
  ScrollController controller, {
  bool force = false,
  double threshold = 140,
}) {
  void run() {
    if (!controller.hasClients) return;
    if (!force && !isChatNearBottom(controller, threshold: threshold)) return;
    final max = controller.position.maxScrollExtent;
    controller.animateTo(
      max,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  WidgetsBinding.instance.addPostFrameCallback((_) => run());
}
