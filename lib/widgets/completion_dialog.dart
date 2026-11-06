import 'package:flutter/material.dart';

class CompletionDialog extends StatefulWidget {
  final String itemType;
  final String itemTitle;

  const CompletionDialog({
    super.key,
    required this.itemType,
    required this.itemTitle,
  });

  @override
  State<CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<CompletionDialog> {
  int? _rating;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mark as Completed'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Complete: ${widget.itemTitle}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text('How would you rate this experience?'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return IconButton(
                  onPressed: () {
                    setState(() {
                      _rating = starValue;
                    });
                  },
                  icon: Icon(
                    _rating != null && starValue <= _rating!
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Comment (Optional)',
                hintText: 'Say thanks or leave feedback...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, CompletionResult(
              rating: _rating,
              comment: _commentController.text.trim().isEmpty
                  ? null
                  : _commentController.text.trim(),
            ));
          },
          child: const Text('Complete'),
        ),
      ],
    );
  }
}

class CompletionResult {
  final int? rating;
  final String? comment;

  CompletionResult({this.rating, this.comment});

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (rating != null) data['rating'] = rating;
    if (comment != null) data['comment'] = comment;
    return data;
  }
}
