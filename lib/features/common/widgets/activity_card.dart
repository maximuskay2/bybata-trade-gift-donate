import 'package:flutter/material.dart';
import 'user_avatar.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// Activity card for feed items
class ActivityCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? content;
  final DateTime timestamp;
  final String? userImageUrl;
  final String? userName;
  final ActivityType type;
  final List<String>? images;
  final Map<String, dynamic>? metadata;
  final VoidCallback? onTap;
  final VoidCallback? onUserTap;
  final List<ActivityAction>? actions;
  final bool showActions;

  const ActivityCard({
    Key? key,
    required this.title,
    this.subtitle,
    this.content,
    required this.timestamp,
    this.userImageUrl,
    this.userName,
    required this.type,
    this.images,
    this.metadata,
    this.onTap,
    this.onUserTap,
    this.actions,
    this.showActions = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildContent(),
              if (images != null && images!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildImageGallery(),
              ],
              if (metadata != null && metadata!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildMetadata(),
              ],
              if (showActions && actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildActions(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _buildActivityIcon(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTimestamp(timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            if (userName != null) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onUserTap,
                child: UserAvatar(
                  imageUrl: userImageUrl,
                  name: userName,
                  size: 24,
                  showStatusIndicator: false,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildActivityIcon() {
    IconData icon;
    Color color;

    switch (type) {
      case ActivityType.trade:
        icon = Icons.swap_horiz;
        color = AppColors.primary;
        break;
      case ActivityType.gift:
        icon = Icons.card_giftcard;
        color = const Color(0xFF4CAF50);
        break;
      case ActivityType.campaign:
        icon = Icons.campaign;
        color = const Color(0xFFFF9800);
        break;
      case ActivityType.community:
        icon = Icons.groups;
        color = const Color(0xFF9C27B0);
        break;
      case ActivityType.karma:
        icon = Icons.star;
        color = const Color(0xFFFFB300);
        break;
      case ActivityType.achievement:
        icon = Icons.emoji_events;
        color = const Color(0xFFFFD700);
        break;
      case ActivityType.system:
        icon = Icons.info;
        color = Colors.grey.shade600;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }

  Widget _buildContent() {
    if (content == null || content!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      content!,
      style: const TextStyle(
        fontSize: 14,
        height: 1.4,
      ),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildImageGallery() {
    if (images == null || images!.isEmpty) {
      return const SizedBox.shrink();
    }

    if (images!.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            images!.first,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade300,
                child: const Center(
                  child: Icon(Icons.image_not_supported),
                ),
              );
            },
          ),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images!.length,
        itemBuilder: (context, index) {
          return Container(
            margin: EdgeInsets.only(right: index < images!.length - 1 ? 8 : 0),
            width: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                images![index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade300,
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 20),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetadata() {
    if (metadata == null || metadata!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: metadata!.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.key}: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActions() {
    if (actions == null || actions!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: actions!.map((action) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton.icon(
              onPressed: action.onTap,
              icon: Icon(action.icon, size: 16),
              label: Text(
                action.label,
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Compact activity card for lists
class ActivityCardCompact extends StatelessWidget {
  final String title;
  final DateTime timestamp;
  final ActivityType type;
  final String? subtitle;
  final VoidCallback? onTap;

  const ActivityCardCompact({
    Key? key,
    required this.title,
    required this.timestamp,
    required this.type,
    this.subtitle,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildActivityIcon(),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Text(
        _formatTimestamp(timestamp),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }

  Widget _buildActivityIcon() {
    IconData icon;
    Color color;

    switch (type) {
      case ActivityType.trade:
        icon = Icons.swap_horiz;
        color = AppColors.primary;
        break;
      case ActivityType.gift:
        icon = Icons.card_giftcard;
        color = const Color(0xFF4CAF50);
        break;
      case ActivityType.campaign:
        icon = Icons.campaign;
        color = const Color(0xFFFF9800);
        break;
      case ActivityType.community:
        icon = Icons.groups;
        color = const Color(0xFF9C27B0);
        break;
      case ActivityType.karma:
        icon = Icons.star;
        color = const Color(0xFFFFB300);
        break;
      case ActivityType.achievement:
        icon = Icons.emoji_events;
        color = const Color(0xFFFFD700);
        break;
      case ActivityType.system:
        icon = Icons.info;
        color = Colors.grey.shade600;
        break;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 16,
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}

/// Activity notification card
class ActivityNotificationCard extends StatelessWidget {
  final String title;
  final String message;
  final DateTime timestamp;
  final ActivityType type;
  final bool isRead;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const ActivityNotificationCard({
    Key? key,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.onTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('${title}_${timestamp.millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isRead ? null : AppColors.primary.withValues(alpha: 0.08),
          border: Border(
            left: BorderSide(
              color: isRead ? Colors.transparent : AppColors.primary,
              width: 4,
            ),
          ),
        ),
        child: ListTile(
          leading: _buildNotificationIcon(),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          trailing: !isRead
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    IconData icon;
    Color color;

    switch (type) {
      case ActivityType.trade:
        icon = Icons.swap_horiz;
        color = AppColors.primary;
        break;
      case ActivityType.gift:
        icon = Icons.card_giftcard;
        color = const Color(0xFF4CAF50);
        break;
      case ActivityType.campaign:
        icon = Icons.campaign;
        color = const Color(0xFFFF9800);
        break;
      case ActivityType.community:
        icon = Icons.groups;
        color = const Color(0xFF9C27B0);
        break;
      case ActivityType.karma:
        icon = Icons.star;
        color = const Color(0xFFFFB300);
        break;
      case ActivityType.achievement:
        icon = Icons.emoji_events;
        color = const Color(0xFFFFD700);
        break;
      case ActivityType.system:
        icon = Icons.info;
        color = Colors.grey.shade600;
        break;
    }

    return Icon(
      icon,
      color: color,
      size: 24,
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Activity type enumeration
enum ActivityType {
  trade,
  gift,
  campaign,
  community,
  karma,
  achievement,
  system,
}

/// Activity action data class
class ActivityAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  ActivityAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}