import 'package:flutter/material.dart';
import '../../../core/utils/media_utils.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// Widget for displaying a community member
class MemberCard extends StatelessWidget {
  final Map<String, dynamic> member;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onUpdateRole;
  final bool canManage; // Whether current user can manage this member

  const MemberCard({
    super.key,
    required this.member,
    this.onTap,
    this.onRemove,
    this.onUpdateRole,
    this.canManage = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = member['user'] ?? {};
    final profile = user['profile'] ?? {};
    final name = user['name'] ?? user['displayName'] ?? profile['displayName'] ?? 'Anonymous';
    final avatarUrl = profile['avatarUrl'] ?? user['avatarUrl'];
    final role = member['role'] ?? 'MEMBER';
    final status = member['status'] ?? 'ACTIVE';
    final joinedAt = member['joinedAt'] is String
        ? DateTime.tryParse(member['joinedAt'])
        : member['joinedAt'] as DateTime?;
    final expertLevel = member['expertLevel'];
    final contributionScore = member['contributionScore'] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                FutureBuilder<String?>(
                  future: MediaResolver.resolveUrl(avatarUrl?.toString()),
                  builder: (context, snapshot) {
                    final resolved = snapshot.data;
                    final showImage =
                        resolved != null && resolved.startsWith('http');
                    return CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: showImage ? NetworkImage(resolved!) : null,
                      child: !showImage
                          ? Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            )
                          : null,
                    );
                  },
                ),
                if (status == 'ACTIVE')
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(width: 12),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      _buildRoleBadge(role),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  if (expertLevel != null)
                    Text(
                      _formatExpertLevel(expertLevel),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  
                  if (contributionScore > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text(
                          '$contributionScore points',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                  
                  if (joinedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Joined ${_formatDate(joinedAt)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            
            // Actions
            if (canManage)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'remove' && onRemove != null) {
                    onRemove!();
                  } else if (value == 'role' && onUpdateRole != null) {
                    onUpdateRole!();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'role', child: Text('Change Role')),
                  const PopupMenuItem(value: 'remove', child: Text('Remove Member')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role.toUpperCase()) {
      case 'OWNER':
        color = Colors.purple;
        break;
      case 'ADMIN':
        color = Colors.red;
        break;
      case 'MODERATOR':
        color = AppColors.primary;
        break;
      default:
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatExpertLevel(dynamic level) {
    final levelStr = level.toString().toUpperCase();
    switch (levelStr) {
      case 'AUTHORITY':
        return 'Authority';
      case 'EXPERT':
        return 'Expert';
      case 'SPECIALIST':
        return 'Specialist';
      case 'CONTRIBUTOR':
        return 'Contributor';
      case 'NEWCOMER':
      default:
        return 'Newcomer';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return 'Today';
    }
  }
}

