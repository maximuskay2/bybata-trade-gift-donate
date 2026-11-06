import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../navigation/app_routes.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_toast.dart';
import 'package:provider/provider.dart';

class CommentsSection extends StatefulWidget {
  final String itemId;
  final String itemType; // 'TRADE' | 'GIFT' | 'CAMPAIGN'
  final bool allowCommenting;
  final int initialDisplayCount;
  final VoidCallback? onCommentAdded;
  final Future<List<Map<String, dynamic>>> Function() onLoadComments;
  final Future<bool> Function(String comment) onAddComment;
  final Future<bool> Function(String commentId, String comment)? onEditComment;

  const CommentsSection({
    super.key,
    required this.itemId,
    required this.itemType,
    this.allowCommenting = true,
    this.initialDisplayCount = 3,
    this.onCommentAdded,
    required this.onLoadComments,
    required this.onAddComment,
    this.onEditComment,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _editController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = false;
  bool _showAll = false;
  bool _isAdding = false;
  String? _editingCommentId;
  String? _savingCommentId;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await widget.onLoadComments();
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (AppRoutes.requireSignIn(context)) return;

    setState(() => _isAdding = true);
    try {
      final success = await widget.onAddComment(text);
      if (success && mounted) {
        _commentController.clear();
        _loadComments();
        widget.onCommentAdded?.call();
        AppToast.success(context, 'Your comment is now visible', title: 'Comment added');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e.toString(), title: 'Couldn\'t add comment');
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  void _startEditing(Map<String, dynamic> comment) {
    setState(() {
      _editingCommentId = comment['id']?.toString();
      _editController.text = comment['comment']?.toString() ?? '';
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingCommentId = null;
      _editController.clear();
    });
  }

  Future<void> _saveEdit(String commentId) async {
    if (widget.onEditComment == null) return;
    final text = _editController.text.trim();
    if (text.isEmpty) return;

    setState(() => _savingCommentId = commentId);
    try {
      final success = await widget.onEditComment!(commentId, text);
      if (!mounted) return;
      if (success) {
        _cancelEditing();
        await _loadComments();
        AppToast.success(context, 'Your changes have been saved', title: 'Comment updated');
      } else {
        AppToast.error(context, 'Please try again', title: 'Couldn\'t update comment');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e.toString(), title: 'Couldn\'t update comment');
      }
    } finally {
      if (mounted) setState(() => _savingCommentId = null);
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'now';
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'now';
    } catch (_) {
      return 'now';
    }
  }

  bool _wasEdited(Map<String, dynamic> comment) {
    final created = comment['time']?.toString();
    final updated = comment['updatedAt']?.toString();
    if (created == null || updated == null || updated.isEmpty) return false;
    try {
      return DateTime.parse(updated).isAfter(DateTime.parse(created));
    } catch (_) {
      return false;
    }
  }

  bool _canEditComment(Map<String, dynamic> comment) {
    if (widget.onEditComment == null) return false;
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    if (currentUserId == null) return false;
    return comment['authorId']?.toString() == currentUserId;
  }

  Widget _buildCommentRow(Map<String, dynamic> comment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final bgColor = scheme.surface;
    final primaryColor = AppColors.primary;
    final commentId = comment['id']?.toString() ?? '';
    final isEditing = _editingCommentId == commentId;
    final isSaving = _savingCommentId == commentId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: primaryColor.withValues(alpha: 0.15),
            child: Text(
              (comment['avatar'] as String?)?.substring(0, 1).toUpperCase() ?? '?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey[200] ?? Colors.grey,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment['user'] ?? 'Anonymous',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(comment['time']),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[600] : Colors.grey[500],
                        ),
                      ),
                      if (_canEditComment(comment) && !isEditing) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _startEditing(comment),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: primaryColor.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (isEditing) ...[
                    TextField(
                      controller: _editController,
                      maxLines: 3,
                      minLines: 1,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : _cancelEditing,
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: isSaving
                              ? null
                              : () => _saveEdit(commentId),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          child: isSaving
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.onPrimary,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      comment['comment'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[300] : Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    if (_wasEdited(comment))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Edited',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.grey[600] : Colors.grey[500],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final bgColor = scheme.surface;
    final primaryColor = AppColors.primary;
    final isAuthed = context.watch<AuthProvider>().isAuthenticated;
    final canComment = widget.allowCommenting && isAuthed;

    final displayCount = _showAll ? _comments.length : widget.initialDisplayCount;
    final displayedComments = _comments.take(displayCount).toList();
    final hasMore = _comments.length > widget.initialDisplayCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Comments (${_comments.length})',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            if (hasMore && !_showAll)
              GestureDetector(
                onTap: () => setState(() => _showAll = true),
                child: Text(
                  'See all ▶',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.allowCommenting && !isAuthed) ...[
          OutlinedButton.icon(
            onPressed: () => AppRoutes.requireSignIn(context),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Sign in to comment'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
        ] else if (canComment) ...[
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey[300] ?? Colors.grey,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    maxLines: 1,
                    enabled: !_isAdding,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: _isAdding
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        )
                      : Icon(Icons.send_rounded, color: primaryColor),
                  onPressed: _isAdding ? null : _addComment,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
          )
        else if (displayedComments.isEmpty)
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Text(
              'No comments yet. Be the first!',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          )
        else ...[
          ...displayedComments.map(_buildCommentRow),
          if (hasMore && _showAll)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(
                onTap: () => setState(() => _showAll = false),
                child: Text(
                  'Show less ▲',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ]
      ],
    );
  }
}
