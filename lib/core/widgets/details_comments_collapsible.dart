import 'package:flutter/material.dart';

import 'collapsible_section.dart';
import 'comments_section.dart';

/// Collapsed-by-default comments block shared across detail screens.
class DetailsCommentsCollapsible extends StatelessWidget {
  final String itemId;
  final String itemType;
  final Future<List<Map<String, dynamic>>> Function() onLoadComments;
  final Future<bool> Function(String comment) onAddComment;
  final Future<bool> Function(String commentId, String comment)? onEditComment;
  final bool allowCommenting;
  final int initialDisplayCount;
  final Color? backgroundColor;

  const DetailsCommentsCollapsible({
    super.key,
    required this.itemId,
    required this.itemType,
    required this.onLoadComments,
    required this.onAddComment,
    this.onEditComment,
    this.allowCommenting = true,
    this.initialDisplayCount = 3,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleSection(
      title: 'Comments',
      leadingIcon: Icons.chat_bubble_outline_rounded,
      initiallyExpanded: false,
      backgroundColor: backgroundColor,
      content: CommentsSection(
        itemId: itemId,
        itemType: itemType,
        allowCommenting: allowCommenting,
        initialDisplayCount: initialDisplayCount,
        onLoadComments: onLoadComments,
        onAddComment: onAddComment,
        onEditComment: onEditComment,
      ),
    );
  }
}
