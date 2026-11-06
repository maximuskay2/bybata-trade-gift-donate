import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/feed_item.dart';
import '../core/api/api_client.dart';
import '../core/config/env_config.dart';
import '../core/providers/auth_provider.dart';
import '../core/utils/media_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../widgets/completion_dialog.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class RequestDetailsScreen extends StatefulWidget {
  final FeedItem item;

  const RequestDetailsScreen({super.key, required this.item});

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  bool get _isOwner {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return auth.currentUser?.id == widget.item.author.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        actions: [
          if (_isOwner && widget.item.status == 'ACTIVE')
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'complete') {
                  _handleMarkCompleted(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'complete',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Mark as Completed'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: !_isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _onInterestedPressed(context),
              icon: const Icon(Icons.chat_bubble),
              label: const Text("I'm Interested"),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Row(
              children: [
                // Resolve raw storage keys via MediaResolver before passing
                // anything into NetworkImage — bare keys throw at paint.
                FutureBuilder<String?>(
                  future: MediaResolver.resolveUrl(widget.item.author.avatar),
                  builder: (context, snapshot) {
                    final url = snapshot.data;
                    final showImage = url != null &&
                        (url.startsWith('http://') ||
                            url.startsWith('https://'));
                    final initial = widget.item.author.name.isNotEmpty
                        ? widget.item.author.name[0].toUpperCase()
                        : '?';
                    return CircleAvatar(
                      backgroundImage:
                          showImage ? NetworkImage(url) : null,
                      onBackgroundImageError:
                          showImage ? (_, __) {} : null,
                      child: showImage ? null : Text(initial),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.item.author.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(_formatTime(widget.item.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                )
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.item.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if ((widget.item.status != 'ACTIVE'))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text('Completed', style: TextStyle(fontSize: 12, color: Colors.green)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(widget.item.summary),
            const SizedBox(height: 12),
            if (widget.item.location != null)
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(widget.item.location!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            const SizedBox(height: 12),
            if (widget.item.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.item.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onInterestedPressed(BuildContext context) async {
    try {
      const storage = FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final apiClient = ApiClient(baseUrl, storage);

      final response = await apiClient.post(
        '/v1/interactions/REQUEST/${widget.item.id}/interested',
        data: {'message': "I can help with this request!"},
      );

      if (context.mounted) {
        GuardedNavigator.pushNamed(context,
          '/chat',
          arguments: {
            'conversationId': response.data['conversationId'],
            'itemTitle': response.data['itemTitle'],
            'itemType': response.data['itemType'],
            'ownerId': response.data['ownerId'],
            'ownerName': response.data['ownerName'],
            'itemId': widget.item.id,
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Error: ${e.toString()}');
      }
    }
  }

  Future<void> _handleMarkCompleted(BuildContext context) async {
    final result = await showDialog<CompletionResult>(
      context: context,
      builder: (_) => CompletionDialog(
        itemType: 'REQUEST',
        itemTitle: widget.item.title,
      ),
    );

    if (result != null && context.mounted) {
      try {
        const storage = FlutterSecureStorage();
        final baseUrl = await EnvConfig.getBaseUrl();
        final apiClient = ApiClient(baseUrl, storage);

        await apiClient.post(
          '/v1/interactions/REQUEST/${widget.item.id}/complete',
          data: result.toJson(),
        );

        if (context.mounted) {
          AppToast.success(context, 'Request marked as completed! ✅');
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          AppToast.show(context, 'Error: ${e.toString()}');
        }
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('dd/MM/yyyy').format(dateTime);
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
