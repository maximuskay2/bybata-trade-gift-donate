import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../services/chat_media_actions.dart';

/// Document/file message bubble — tap for View / Share / Save.
class DocumentBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isDark;

  const DocumentBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isDark,
  });

  String _prettySize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${units[i]}';
  }

  void _onTap(BuildContext context) {
    final key = message.documentKey ?? message.mediaStorageKey;
    if (key == null || key.isEmpty) return;
    ChatMediaActions.showFileActions(
      context,
      storageKey: key,
      fileName: message.documentName,
      fileSizeBytes: message.documentSizeBytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isMe
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);
    final name = message.documentName ?? 'Attachment';
    final size = _prettySize(message.documentSizeBytes);
    return InkWell(
      onTap: () => _onTap(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 48,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.insert_drive_file_outlined,
                color: textColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (size.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        size,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.75),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Tap to view · save · share',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.55),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: textColor.withValues(alpha: 0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
