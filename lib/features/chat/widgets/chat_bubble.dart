import 'package:flutter/material.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import '../models/chat_message.dart';
import '../models/chat_conversation.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showTimestamp;
  final ChatType chatType;

  const ChatBubble({
    super.key,
    required this.message,
    this.showTimestamp = false,
    required this.chatType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: message.isFromCurrentUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (showTimestamp) ...[
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatTimestamp(message.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
        Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: message.isFromCurrentUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Other user's avatar (left side)
              if (!message.isFromCurrentUser) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: _getChatTypeColor(context).withValues(alpha: 0.1),
                  child: Icon(
                    _getChatTypeIcon(),
                    color: _getChatTypeColor(context),
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              
              // Message bubble
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  child: ShadowCard(
                    shadowIntensity: ShadowIntensity.light,
                    borderRadius: 16,
                    color: message.isFromCurrentUser
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sender name for group chats or other users
                          if (!message.isFromCurrentUser && chatType == ChatType.community) ...[
                            Text(
                              message.senderName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _getChatTypeColor(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          
                          // Message content
                          Text(
                            message.message,
                            style: TextStyle(
                              fontSize: 14,
                              color: message.isFromCurrentUser
                                  ? Colors.white
                                  : Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          
                          // Message time
                          const SizedBox(height: 4),
                          Text(
                            _formatMessageTime(message.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: message.isFromCurrentUser
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Current user's avatar (right side)
              if (message.isFromCurrentUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                    size: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Color _getChatTypeColor(BuildContext context) {
    switch (chatType) {
      case ChatType.trade:
        return Theme.of(context).primaryColor;
      case ChatType.donation:
        return Colors.green;
      case ChatType.community:
        return Colors.orange;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  IconData _getChatTypeIcon() {
    switch (chatType) {
      case ChatType.trade:
        return Icons.swap_horiz;
      case ChatType.donation:
        return Icons.volunteer_activism;
      case ChatType.community:
        return Icons.groups;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '$displayHour:$minute $period';
  }
}