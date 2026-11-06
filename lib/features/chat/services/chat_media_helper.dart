import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/permissions_helper.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../widgets/v2/chat_upload_overlay.dart';
import 'chat_media_service.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';

/// Helper for picking, uploading, and sending chat media (images, videos, files, voice notes).
class ChatMediaHelper {
  static final ImagePicker _picker = ImagePicker();
  static final AudioRecorder _recorder = AudioRecorder();
  static bool _isRecording = false;
  static String? _recordingPath;
  static const int _maxVideoBytes = 80 * 1024 * 1024; // 80 MB

  static void _showUploadingOverlay(
    BuildContext context,
    ChatUploadKind kind, {
    String? fileName,
  }) {
    ChatUploadOverlay.show(context, kind: kind, fileName: fileName);
  }

  static void _closeOverlay(NavigatorState navigator) {
    if (navigator.canPop()) navigator.pop();
  }

  /// Take a photo with the camera, upload, and send.
  /// On Android, XFile.path can be a content:// URI which File() cannot read.
  /// We use readAsBytes() and write to a temp file for cross-platform compatibility.
  static Future<void> pickAndSendImage(
    BuildContext context, {
    required String conversationId,
    required VoidCallback onScrollToBottom,
  }) async {
    final granted = await PermissionsHelper.requestCameraWithFallback(
      context,
      purpose: 'take photos for chat',
    );
    if (!granted || !context.mounted) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (image == null || !context.mounted) return;

    File file;
    try {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) {
        if (context.mounted) {
          AppToast.show(context, 'Could not read the photo. Please try again.');
        }
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final pathParts = image.path.split('.');
      final ext = pathParts.length > 1 ? pathParts.last.toLowerCase() : 'jpg';
      final safeExt =
          ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'].contains(ext)
              ? ext
              : 'jpg';
      file = File(
        '${tempDir.path}/chat_image_${DateTime.now().millisecondsSinceEpoch}.$safeExt',
      );
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Failed to read image: $e');
      }
      return;
    }

    if (!context.mounted) return;
    _showUploadingOverlay(context, ChatUploadKind.photo);
    final navigator = Navigator.of(context, rootNavigator: true);

    try {
      final service = await ChatMediaService.create();
      final key = await service.uploadImage(file);
      if (key == null) {
        _closeOverlay(navigator);
        if (context.mounted) {
          AppToast.show(context, 'Failed to upload image');
        }
        return;
      }

      final ok = await chatProvider.sendMessage(
        conversationId,
        'Sent an image',
        type: MessageType.image,
        metadata: {
          'mediaKeys': [key],
          'mediaKind': 'image',
        },
      );
      _closeOverlay(navigator);
      if (!ok) {
        if (context.mounted) {
          AppToast.show(context, 'Failed to send image');
        }
        return;
      }
      onScrollToBottom();
    } catch (e) {
      _closeOverlay(navigator);
      if (context.mounted) {
        AppToast.show(context, 'Failed to send image: $e');
      }
    }
  }

  /// Record / capture a video with the camera, upload, and send as FILE + video meta.
  static Future<void> pickAndSendVideo(
    BuildContext context, {
    required String conversationId,
    required VoidCallback onScrollToBottom,
    ImageSource source = ImageSource.camera,
  }) async {
    final granted = await PermissionsHelper.requestCameraWithFallback(
      context,
      purpose: 'record videos for chat',
    );
    if (!granted || !context.mounted) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final XFile? video = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 2),
    );
    if (video == null || !context.mounted) return;

    File file;
    String ext;
    try {
      final bytes = await video.readAsBytes();
      if (bytes.isEmpty) {
        if (context.mounted) {
          AppToast.show(context, 'Could not read the video. Please try again.');
        }
        return;
      }
      if (bytes.length > _maxVideoBytes) {
        if (context.mounted) {
          AppToast.show(
            context,
            'Video is too large (max 80 MB). Try a shorter clip.',
          );
        }
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final pathParts = video.path.split('.');
      ext = pathParts.length > 1 ? pathParts.last.toLowerCase() : 'mp4';
      if (!['mp4', 'mov', 'm4v', 'webm'].contains(ext)) ext = 'mp4';
      file = File(
        '${tempDir.path}/chat_video_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Failed to read video: $e');
      }
      return;
    }

    if (!context.mounted) return;
    _showUploadingOverlay(context, ChatUploadKind.video);
    final navigator = Navigator.of(context, rootNavigator: true);

    try {
      final service = await ChatMediaService.create();
      final key = await service.uploadVideo(file, ext: ext);
      if (key == null) {
        _closeOverlay(navigator);
        if (context.mounted) {
          AppToast.show(context, 'Failed to upload video');
        }
        return;
      }

      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ok = await chatProvider.sendMessage(
        conversationId,
        'Sent a video',
        type: MessageType.video,
        metadata: {
          'mediaKeys': [key],
          'mediaKind': 'video',
          'mimeType': ext == 'mov' ? 'video/quicktime' : 'video/$ext',
          'fileName': fileName,
          'documentName': fileName,
          'documentKey': key,
          'fileKey': key,
        },
      );
      _closeOverlay(navigator);
      if (!ok) {
        if (context.mounted) {
          AppToast.show(context, 'Failed to send video');
        }
        return;
      }
      onScrollToBottom();
    } catch (e) {
      _closeOverlay(navigator);
      if (context.mounted) {
        AppToast.show(context, 'Failed to send video: $e');
      }
    }
  }

  /// Pick file (document), upload, and send.
  static Future<void> pickAndSendFile(
    BuildContext context, {
    required String conversationId,
    required VoidCallback onScrollToBottom,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !context.mounted) return;

    final picked = result.files.single;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final ext = (picked.extension ?? 'bin').toLowerCase();
    final fileName = picked.name;

    Uint8List? bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      final path = picked.path;
      if (path == null) {
        if (context.mounted) {
          AppToast.show(context, 'Could not read the selected file');
        }
        return;
      }
      try {
        bytes = await File(path).readAsBytes();
      } catch (e) {
        if (context.mounted) {
          AppToast.show(context, 'Failed to read file: $e');
        }
        return;
      }
    }
    if (bytes.isEmpty) {
      if (context.mounted) {
        AppToast.show(context, 'Selected file is empty');
      }
      return;
    }

    // Route video files picked via Document into the video pipeline.
    final isVideoExt = ['mp4', 'mov', 'm4v', 'webm'].contains(ext);
    if (!context.mounted) return;
    _showUploadingOverlay(
      context,
      isVideoExt ? ChatUploadKind.video : ChatUploadKind.document,
      fileName: fileName,
    );
    final navigator = Navigator.of(context, rootNavigator: true);

    try {
      final service = await ChatMediaService.create();
      final String? key;
      if (isVideoExt) {
        key = await service.uploadBytes(
          bytes,
          ext: ext,
          contentType: ext == 'mov' ? 'video/quicktime' : 'video/$ext',
        );
      } else {
        key = await service.uploadBytes(bytes, ext: ext);
      }
      if (key == null) {
        _closeOverlay(navigator);
        if (context.mounted) {
          AppToast.show(context, 'Failed to upload file');
        }
        return;
      }

      if (isVideoExt) {
        final ok = await chatProvider.sendMessage(
          conversationId,
          'Sent a video',
          type: MessageType.video,
          metadata: {
            'mediaKeys': [key],
            'mediaKind': 'video',
            'mimeType': ext == 'mov' ? 'video/quicktime' : 'video/$ext',
            'fileName': fileName,
            'documentName': fileName,
            'documentKey': key,
            'fileKey': key,
            'fileSize': bytes.length,
            'documentSize': bytes.length,
          },
        );
        _closeOverlay(navigator);
        if (!ok) {
          if (context.mounted) {
            AppToast.show(context, 'Failed to send video');
          }
          return;
        }
      } else {
        final ok = await chatProvider.sendMessage(
          conversationId,
          'Sent a file: $fileName',
          type: MessageType.file,
          metadata: {
            'mediaKeys': [key],
            'fileName': fileName,
            'documentName': fileName,
            'documentKey': key,
            'fileKey': key,
            'fileSize': bytes.length,
            'documentSize': bytes.length,
          },
        );
        _closeOverlay(navigator);
        if (!ok) {
          if (context.mounted) {
            AppToast.show(context, 'Failed to send file');
          }
          return;
        }
      }
      onScrollToBottom();
    } catch (e) {
      _closeOverlay(navigator);
      if (context.mounted) {
        AppToast.show(context, 'Failed to send file: $e');
      }
    }
  }

  /// Start voice recording. Returns true if started.
  ///
  /// Wrapped in try/catch so a missing OS-level microphone permission or a
  /// platform exception (e.g. MissingPluginException on a stale build) never
  /// propagates up to the UI and crashes the app — we simply return false and
  /// let the caller surface a "Microphone permission required" snackbar.
  static Future<bool> startVoiceRecording() async {
    if (_isRecording) return false;
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return false;

      final dir = await getTemporaryDirectory();
      _recordingPath =
          '${dir.path}/chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );
      _isRecording = true;
      return true;
    } catch (e, st) {
      debugPrint('startVoiceRecording failed: $e\n$st');
      _isRecording = false;
      _recordingPath = null;
      return false;
    }
  }

  /// Stop voice recording.
  static Future<String?> stopVoiceRecording() async {
    if (!_isRecording || _recordingPath == null) return null;
    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('stopVoiceRecording failed: $e');
    }
    _isRecording = false;
    final path = _recordingPath;
    _recordingPath = null;
    return path;
  }

  static bool get isRecording => _isRecording;

  /// Live microphone amplitude during recording, normalized to 0.0-1.0.
  /// Emits roughly every 100ms. `.current` from the `record` package is in
  /// dBFS (typically -60..0); we map that linearly so the waveform bars in
  /// the composer have a stable visual range across devices.
  static Stream<double> amplitudeStream() {
    return _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .map((a) {
      final db = a.current;
      if (db.isNaN || db.isInfinite) return 0.0;
      return ((db + 60) / 60).clamp(0.0, 1.0);
    });
  }

  /// Live timer label while recording (WhatsApp-style `m:ss`).
  static String formatRecordingElapsed(DateTime? start) {
    if (start == null) return '0:00';
    final secs = DateTime.now().difference(start).inSeconds.clamp(0, 5999);
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Preview playback locally, then send or discard (like WhatsApp).
  /// Returns uploaded duration from the file when possible.
  static Future<void> showVoiceNotePreviewBeforeSend(
    BuildContext context, {
    required String path,
    required String conversationId,
    required int durationSeconds,
    required VoidCallback onScrollToBottom,
  }) async {
    final int? secondsToSend = await showModalBottomSheet<int?>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VoiceNotePreviewSheet(
        filePath: path,
        fallbackDurationSeconds: durationSeconds,
      ),
    );
    if (!context.mounted) return;
    if (secondsToSend != null) {
      await uploadAndSendVoice(
        context,
        path: path,
        conversationId: conversationId,
        durationSeconds: secondsToSend.clamp(1, 300),
        onScrollToBottom: onScrollToBottom,
      );
    } else {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// Upload and send voice note.
  static Future<void> uploadAndSendVoice(
    BuildContext context, {
    required String path,
    required String conversationId,
    required int durationSeconds,
    required VoidCallback onScrollToBottom,
  }) async {
    final file = File(path);
    if (!await file.exists()) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final service = await ChatMediaService.create();
    final key = await service.uploadAudio(file);
    if (key == null) {
      if (context.mounted) {
        AppToast.show(context, 'Failed to upload voice note');
      }
      return;
    }

    try {
      final ok = await chatProvider.sendMessage(
        conversationId,
        'Voice note',
        type: MessageType.voice,
        metadata: {'audioKey': key, 'durationSeconds': durationSeconds},
      );
      if (!ok) {
        if (context.mounted) {
          AppToast.show(context, 'Failed to send voice note');
        }
        return;
      }
      if (context.mounted) onScrollToBottom();
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Failed to send voice note: $e');
      }
    }
  }
}

class _VoiceNotePreviewSheet extends StatefulWidget {
  final String filePath;
  final int fallbackDurationSeconds;

  const _VoiceNotePreviewSheet({
    required this.filePath,
    required this.fallbackDurationSeconds,
  });

  @override
  State<_VoiceNotePreviewSheet> createState() => _VoiceNotePreviewSheetState();
}

class _VoiceNotePreviewSheetState extends State<_VoiceNotePreviewSheet> {
  final AudioPlayer _player = AudioPlayer();
  bool _loading = true;
  String? _loadError;

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _player.setFilePath(widget.filePath);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_loadError != null) return;
    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Playback failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final onBg = isDark ? Colors.white : Colors.black87;
    final fallback = Duration(seconds: widget.fallbackDurationSeconds);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Preview voice message',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: onBg,
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: const BybataLoader(),
                )
              else if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Could not load recording.\n$_loadError',
                    style: TextStyle(color: Colors.red[300], fontSize: 13),
                  ),
                )
              else
                StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  initialData: Duration.zero,
                  builder: (context, snapPos) {
                    return StreamBuilder<Duration?>(
                      stream: _player.durationStream,
                      initialData: _player.duration,
                      builder: (context, snapDur) {
                        final pos = snapPos.data ?? Duration.zero;
                        final total = snapDur.data ?? _player.duration ?? fallback;
                        final safeTotal = total.inMilliseconds > 0 ? total : fallback;
                        final progress = safeTotal.inMilliseconds > 0
                            ? (pos.inMilliseconds / safeTotal.inMilliseconds).clamp(0.0, 1.0)
                            : 0.0;
                        return Column(
                          children: [
                            Row(
                              children: [
                                StreamBuilder<PlayerState>(
                                  stream: _player.playerStateStream,
                                  builder: (context, snap) {
                                    final playing = snap.data?.playing ?? false;
                                    return IconButton.filled(
                                      style: IconButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                      ),
                                      onPressed: _togglePlay,
                                      icon: Icon(
                                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        size: 28,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor: isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : Colors.black.withValues(alpha: 0.08),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${_fmt(pos)} / ${_fmt(safeTotal)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, null),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[400],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (_loading || _loadError != null)
                          ? null
                          : () {
                              final secs = _player.duration?.inSeconds ??
                                  widget.fallbackDurationSeconds;
                              Navigator.pop(
                                context,
                                secs.clamp(1, 300),
                              );
                            },
                      icon: const Icon(Icons.send_rounded, size: 20),
                      label: const Text('Send'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
