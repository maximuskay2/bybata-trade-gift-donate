import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/media_utils.dart';

/// Widget for displaying a community post
class PostItem extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final bool isLiked;

  const PostItem({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.isLiked = false,
  });

  @override
  Widget build(BuildContext context) {
    final author = post['author'] ?? {};
    final authorName = author['name'] ?? author['displayName'] ?? 'Anonymous';
    final authorAvatar = author['profile']?['avatarUrl'] ?? author['avatarUrl'];
    final content = post['content'] ?? '';
    final title = post['title'];
    final createdAt = post['createdAt'] is String
        ? DateTime.tryParse(post['createdAt'])
        : post['createdAt'] as DateTime?;
    final likeCount = post['likeCount'] ?? 0;
    final commentCount = post['commentCount'] ?? 0;
    final mediaKeys = (post['mediaKeys'] as List<dynamic>?) ?? [];
    final images = mediaKeys.where((url) => url.toString().isNotEmpty).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FutureBuilder<String?>(
                  future: MediaResolver.resolveUrl(authorAvatar?.toString()),
                  builder: (context, snapshot) {
                    final resolved = snapshot.data;
                    final showImage =
                        resolved != null && resolved.startsWith('http');
                    return CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[300],
                      backgroundImage:
                          showImage ? NetworkImage(resolved!) : null,
                      child: !showImage
                          ? Text(
                              authorName[0].toUpperCase(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            )
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (createdAt != null)
                        Text(
                          _formatDate(createdAt),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (post['isPinned'] == true)
                  Icon(Icons.push_pin, size: 16, color: Colors.orange[700]),
              ],
            ),
          ),
          
          // Title if present
          if (title != null && title.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          
          // Content
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                content,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          
          // Images
          if (images.isNotEmpty) _buildImageGrid(images),
          
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildActionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: likeCount > 0 ? _formatCount(likeCount) : 'Like',
                  color: isLiked ? Colors.red : Colors.grey[700],
                  onTap: onLike,
                ),
                const SizedBox(width: 24),
                _buildActionButton(
                  icon: Icons.comment_outlined,
                  label: commentCount > 0 ? _formatCount(commentCount) : 'Comment',
                  onTap: onComment,
                ),
                const SizedBox(width: 24),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: onShare,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(List<dynamic> images) {
    if (images.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildResolvedImage(
            images[0].toString(),
            height: 200,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: images.length > 4 ? 4 : images.length,
        itemBuilder: (context, index) {
          return _buildResolvedImage(
            images[index].toString(),
            borderRadius: BorderRadius.circular(12),
          );
        },
      ),
    );
  }

  Widget _buildResolvedImage(
    String value, {
    double? height,
    BorderRadius? borderRadius,
  }) {
    return FutureBuilder<String?>(
      future: MediaResolver.resolveUrl(value),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved == null || !resolved.startsWith('http')) {
          return Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: borderRadius,
            ),
            child: const Icon(Icons.broken_image),
          );
        }
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: Image.network(
            resolved,
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: height,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color ?? Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(date);
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

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

