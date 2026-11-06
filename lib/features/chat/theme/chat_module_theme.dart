import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/chat_conversation.dart';

/// Outgoing (sender) bubble and chat chrome accent — unified app theme purple.
class ChatModuleTheme {
  ChatModuleTheme._();

  static Color bubbleColor(ChatType type) => AppColors.primary;

  /// Trade / gift / donation screens that are not opened via [ChatScreen].
  static Color forTrade() => AppColors.primary;
  static Color forGift() => AppColors.primary;
  static Color forDonation() => AppColors.primary;
}
