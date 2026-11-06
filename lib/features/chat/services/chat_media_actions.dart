import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/media_file_cache.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/theme/app_theme.dart';

enum ChatMediaKind { image, video, document }

/// Resolve / download / save / share helpers for chat attachments.
///
/// Used by every chat surface via [ChatImageAttachment],
/// [ChatVideoAttachment], and [DocumentBubble].
class ChatMediaActions {
  ChatMediaActions._();

  static Future<String?> resolveUrl(
    String storageKey, {
    bool forVideo = false,
  }) {
    return MediaResolver.resolveUrl(storageKey, forVideo: forVideo);
  }

  /// Download media to a local cache file (reuses listing media cache).
  static Future<File?> downloadFile(String storageKey) async {
    final key = storageKey.trim();
    if (key.isEmpty) return null;
    return MediaFileCache.getFile(key);
  }

  static Future<bool> saveToGallery(
    BuildContext context, {
    required String storageKey,
    required ChatMediaKind kind,
    String? fileName,
  }) async {
    try {
      final file = await downloadFile(storageKey);
      if (file == null || !await file.exists()) {
        if (context.mounted) {
          AppToast.show(context, 'Could not download media');
        }
        return false;
      }

      if (kind == ChatMediaKind.document) {
        // Documents aren't gallery items — export via the share sheet
        // so the user can save to Files / Drive / AirDrop.
        await share(
          context,
          storageKey: storageKey,
          kind: kind,
          fileName: fileName,
          alreadyDownloaded: file,
        );
        return true;
      }

      final name = _safeName(
        fileName ??
            (kind == ChatMediaKind.video
                ? 'bybata_video_${DateTime.now().millisecondsSinceEpoch}'
                : 'bybata_photo_${DateTime.now().millisecondsSinceEpoch}'),
      );

      dynamic result;
      if (kind == ChatMediaKind.image) {
        result = await ImageGallerySaverPlus.saveFile(file.path, name: name);
        if (!_isSuccess(result)) {
          final bytes = await file.readAsBytes();
          result = await ImageGallerySaverPlus.saveImage(
            bytes,
            quality: 100,
            name: name,
          );
        }
      } else {
        result = await ImageGallerySaverPlus.saveFile(file.path, name: name);
      }

      if (!context.mounted) return _isSuccess(result);
      if (_isSuccess(result)) {
        AppToast.success(
          context,
          kind == ChatMediaKind.video
              ? 'Video saved to gallery'
              : 'Photo saved to gallery',
        );
        return true;
      }
      AppToast.show(context, 'Could not save to gallery');
      return false;
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Save failed: $e');
      }
      return false;
    }
  }

  static Future<void> share(
    BuildContext context, {
    required String storageKey,
    required ChatMediaKind kind,
    String? fileName,
    File? alreadyDownloaded,
  }) async {
    try {
      final file = alreadyDownloaded ?? await downloadFile(storageKey);
      if (file == null || !await file.exists()) {
        if (context.mounted) {
          AppToast.show(context, 'Could not download media to share');
        }
        return;
      }

      final ext = _extOf(file.path) ?? _defaultExt(kind);
      final name = _safeName(
        fileName ??
            'bybata_${kind.name}_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );

      final tmp = await getTemporaryDirectory();
      final shareFile = await file.copy('${tmp.path}/$name');

      if (!context.mounted) return;
      await Share.shareXFiles(
        [
          XFile(
            shareFile.path,
            mimeType: _mimeFor(kind, ext),
            name: name,
          ),
        ],
        sharePositionOrigin: _shareOrigin(context),
      );
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Share failed: $e');
      }
    }
  }

  /// Open an attachment via a **local** file so the cloud/signed URL never
  /// appears in Safari/Chrome (which would expose storage tokens).
  static Future<void> openExternal(
    BuildContext context,
    String storageKey, {
    bool forVideo = false,
    String? fileName,
  }) async {
    try {
      if (context.mounted) {
        AppToast.show(context, 'Preparing file…');
      }

      final cached = await downloadFile(storageKey);
      if (cached == null || !await cached.exists()) {
        if (context.mounted) {
          AppToast.show(context, 'Could not download attachment');
        }
        return;
      }

      final kind = forVideo ? ChatMediaKind.video : ChatMediaKind.document;
      final ext = _extOf(fileName ?? '') ??
          _extOf(cached.path) ??
          _defaultExt(kind);
      var name = _safeName(
        (fileName != null && fileName.trim().isNotEmpty)
            ? fileName.trim()
            : 'bybata_${kind.name}_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      if (!name.contains('.')) name = '$name.$ext';

      final tmp = await getTemporaryDirectory();
      final localPath = '${tmp.path}/$name';
      final local =
          cached.path == localPath ? cached : await cached.copy(localPath);

      final result = await OpenFilex.open(
        local.path,
        type: _mimeFor(kind, ext),
      );

      if (!context.mounted) return;
      if (result.type == ResultType.done) return;

      // No suitable viewer installed — fall back to share (still local, no URL).
      if (result.type == ResultType.noAppToOpen ||
          result.type == ResultType.fileNotFound ||
          result.type == ResultType.error) {
        await share(
          context,
          storageKey: storageKey,
          kind: kind,
          fileName: name,
          alreadyDownloaded: local,
        );
        return;
      }

      AppToast.show(context, result.message);
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Open failed: $e');
      }
    }
  }

  static Future<void> showFileActions(
    BuildContext context, {
    required String storageKey,
    String? fileName,
    int? fileSizeBytes,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = AppTheme.primaryColor;
    final name = (fileName != null && fileName.trim().isNotEmpty)
        ? fileName.trim()
        : 'Attachment';

    Widget leadingIcon(IconData icon) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (fileSizeBytes != null && fileSizeBytes > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _prettySize(fileSizeBytes),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(ctx),
                        style: IconButton.styleFrom(
                          backgroundColor: theme,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: leadingIcon(Icons.open_in_new_rounded),
                  title: const Text('View / Open'),
                  subtitle: const Text('Opens securely without showing a link'),
                  onTap: () {
                    Navigator.pop(ctx);
                    openExternal(
                      context,
                      storageKey,
                      fileName: fileName,
                    );
                  },
                ),
                ListTile(
                  leading: leadingIcon(Icons.ios_share_rounded),
                  title: const Text('Share'),
                  onTap: () {
                    Navigator.pop(ctx);
                    share(
                      context,
                      storageKey: storageKey,
                      kind: ChatMediaKind.document,
                      fileName: fileName,
                    );
                  },
                ),
                ListTile(
                  leading: leadingIcon(Icons.download_rounded),
                  title: const Text('Save / Export'),
                  subtitle: const Text('Download and share to Files or Drive'),
                  onTap: () {
                    Navigator.pop(ctx);
                    saveToGallery(
                      context,
                      storageKey: storageKey,
                      kind: ChatMediaKind.document,
                      fileName: fileName,
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme,
                      side: BorderSide(color: theme.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static bool _isSuccess(dynamic result) {
    if (result is Map) return result['isSuccess'] == true;
    return result == true;
  }

  static String _safeName(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^\w.\-]'), '_');
    return cleaned.isEmpty ? 'bybata_file' : cleaned;
  }

  static String? _extOf(String path) {
    final parts = path.split('.');
    if (parts.length < 2) return null;
    final ext = parts.last.toLowerCase();
    if (ext.isEmpty || ext.length > 8) return null;
    return ext;
  }

  static String _defaultExt(ChatMediaKind kind) {
    switch (kind) {
      case ChatMediaKind.image:
        return 'jpg';
      case ChatMediaKind.video:
        return 'mp4';
      case ChatMediaKind.document:
        return 'bin';
    }
  }

  static String _mimeFor(ChatMediaKind kind, String ext) {
    switch (kind) {
      case ChatMediaKind.image:
        if (ext == 'png') return 'image/png';
        if (ext == 'gif') return 'image/gif';
        if (ext == 'webp') return 'image/webp';
        return 'image/jpeg';
      case ChatMediaKind.video:
        if (ext == 'mov') return 'video/quicktime';
        return 'video/mp4';
      case ChatMediaKind.document:
        if (ext == 'pdf') return 'application/pdf';
        if (ext == 'doc') return 'application/msword';
        if (ext == 'docx') {
          return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        }
        if (ext == 'xls') return 'application/vnd.ms-excel';
        if (ext == 'xlsx') {
          return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        }
        if (ext == 'ppt') return 'application/vnd.ms-powerpoint';
        if (ext == 'pptx') {
          return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
        }
        if (ext == 'txt') return 'text/plain';
        if (ext == 'csv') return 'text/csv';
        if (ext == 'zip') return 'application/zip';
        return 'application/octet-stream';
    }
  }

  static String _prettySize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size < 10 && i > 0 ? 1 : 0)} ${units[i]}';
  }

  static Rect _shareOrigin(BuildContext context) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final offset = box.localToGlobal(Offset.zero);
      return offset & box.size;
    }
    return const Rect.fromLTWH(0, 0, 1, 1);
  }
}
