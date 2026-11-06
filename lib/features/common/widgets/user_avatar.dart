import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bybata/core/utils/media_utils.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// User avatar component with status indicators
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final UserStatus? status;
  final bool showStatusIndicator;
  final bool isVerified;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;

  const UserAvatar({
    Key? key,
    this.imageUrl,
    this.name,
    this.size = 40,
    this.status,
    this.showStatusIndicator = true,
    this.isVerified = false,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: borderColor != null
                  ? Border.all(color: borderColor!, width: 2)
                  : null,
            ),
            child: FutureBuilder<String?>(
              future: MediaResolver.resolveUrl(imageUrl),
              builder: (context, snapshot) {
                final resolved = snapshot.data;
                final bg = backgroundColor ?? _getBackgroundColor();
                final showImage = resolved != null &&
                    (resolved.startsWith('http://') ||
                        resolved.startsWith('https://')) &&
                    MediaResolver.isDecodableImageUrl(resolved);
                return CircleAvatar(
                  radius: size / 2,
                  backgroundColor: bg,
                  child: showImage
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: resolved,
                            fit: BoxFit.cover,
                            width: size,
                            height: size,
                            errorWidget: (context, url, error) =>
                                _buildInitials(),
                          ),
                        )
                      : _buildInitials(),
                );
              },
            ),
          ),
          
          // Status indicator
          if (showStatusIndicator && status != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.25,
                height: size * 0.25,
                decoration: BoxDecoration(
                  color: _getStatusColor(status!),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
          
          // Verification badge
          if (isVerified)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: size * 0.2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    return _getInitialsStatic(name);
  }

  Widget _buildInitials() {
    return Text(
      _getInitials(name ?? 'U'),
      style: TextStyle(
        fontSize: size * 0.4,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  static String _getInitialsStatic(String name) {
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return 'U';
  }

  Color _getBackgroundColor() {
    // Generate color based on name hash for consistency
    if (name != null) {
      final hash = name.hashCode;
      final colors = [
        AppColors.primary, // Blue
        const Color(0xFF4CAF50), // Green
        const Color(0xFFFF9800), // Orange
        const Color(0xFF9C27B0), // Purple
        const Color(0xFFF44336), // Red
        AppColors.primaryLight, // Cyan
        const Color(0xFF795548), // Brown
        AppColors.primaryMuted, // Blue Grey
      ];
      return colors[hash.abs() % colors.length];
    }
    return const Color(0xFF9E9E9E);
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return const Color(0xFF4CAF50); // Green
      case UserStatus.away:
        return const Color(0xFFFF9800); // Orange
      case UserStatus.busy:
        return const Color(0xFFF44336); // Red
      case UserStatus.offline:
        return const Color(0xFF9E9E9E); // Grey
    }
  }
}

/// Avatar group for displaying multiple users
class UserAvatarGroup extends StatelessWidget {
  final List<UserAvatarData> users;
  final double avatarSize;
  final int maxVisible;
  final double overlap;
  final VoidCallback? onMoreTap;

  const UserAvatarGroup({
    Key? key,
    required this.users,
    this.avatarSize = 32,
    this.maxVisible = 5,
    this.overlap = 8,
    this.onMoreTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final visibleUsers = users.take(maxVisible).toList();
    final remainingCount = users.length - maxVisible;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visibleUsers.asMap().entries.map((entry) {
          final index = entry.key;
          final user = entry.value;
          
          return Container(
            margin: EdgeInsets.only(left: index > 0 ? -overlap : 0),
            child: UserAvatar(
              imageUrl: user.imageUrl,
              name: user.name,
              size: avatarSize,
              status: user.status,
              isVerified: user.isVerified,
              borderColor: Colors.white,
              onTap: user.onTap,
            ),
          );
        }),
        
        if (remainingCount > 0)
          Container(
            margin: EdgeInsets.only(left: -overlap),
            child: GestureDetector(
              onTap: onMoreTap,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$remainingCount',
                    style: TextStyle(
                      fontSize: avatarSize * 0.25,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Large user avatar for profiles
class UserAvatarLarge extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final bool isVerified;
  final bool isOnline;
  final VoidCallback? onTap;
  final VoidCallback? onEditTap;

  const UserAvatarLarge({
    Key? key,
    this.imageUrl,
    this.name,
    this.isVerified = false,
    this.isOnline = false,
    this.onTap,
    this.onEditTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        UserAvatar(
          imageUrl: imageUrl,
          name: name,
          size: 80,
          status: isOnline ? UserStatus.online : UserStatus.offline,
          isVerified: isVerified,
          onTap: onTap,
        ),
        
        if (onEditTap != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: onEditTap,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact user avatar for lists
class UserAvatarCompact extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final bool isVerified;
  final VoidCallback? onTap;

  const UserAvatarCompact({
    Key? key,
    this.imageUrl,
    this.name,
    this.isVerified = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      imageUrl: imageUrl,
      name: name,
      size: 24,
      showStatusIndicator: false,
      isVerified: isVerified,
      onTap: onTap,
    );
  }
}

/// Avatar with name and subtitle
class UserAvatarWithInfo extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final String? subtitle;
  final double avatarSize;
  final bool isVerified;
  final UserStatus? status;
  final VoidCallback? onTap;

  const UserAvatarWithInfo({
    Key? key,
    this.imageUrl,
    required this.name,
    this.subtitle,
    this.avatarSize = 40,
    this.isVerified = false,
    this.status,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          UserAvatar(
            imageUrl: imageUrl,
            name: name,
            size: avatarSize,
            status: status,
            isVerified: isVerified,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// User status enumeration
enum UserStatus {
  online,
  away,
  busy,
  offline,
}

/// Data class for user avatar information
class UserAvatarData {
  final String? imageUrl;
  final String name;
  final UserStatus? status;
  final bool isVerified;
  final VoidCallback? onTap;

  UserAvatarData({
    this.imageUrl,
    required this.name,
    this.status,
    this.isVerified = false,
    this.onTap,
  });
}
