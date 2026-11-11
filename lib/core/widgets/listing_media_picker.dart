import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/listing_media_constants.dart';
import '../media/listing_capture_flow.dart';
import '../models/listing_media.dart';
import '../utils/permissions_helper.dart';
import '../utils/video_processing_utils.dart';
import 'image_source_picker_sheet.dart';
import 'listing_media_upload_guidance.dart';
import 'local_listing_media_preview.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';

/// Picture-or-video picker for create flows (mutually exclusive).
class ListingMediaPicker extends StatefulWidget {
  final Color accentColor;
  final String title;
  final int maxImages;
  final ValueChanged<ListingMediaDraft> onChanged;
  final ListingMediaDraft initial;
  /// Optional label: `trade`, `gift`, or `donation` for tailored guidance copy.
  final String? moduleLabel;
  /// Fraud prevention: only allow live camera capture (no gallery).
  final bool cameraOnly;
  /// Hide the big Take photo / Add video button — capture from the stage hero instead.
  final bool hidePrimaryCapture;

  const ListingMediaPicker({
    super.key,
    required this.accentColor,
    required this.title,
    this.maxImages = ListingMediaConstants.maxPhotosPerListing,
    required this.onChanged,
    this.initial = const ListingMediaDraft(),
    this.moduleLabel,
    this.cameraOnly = true,
    this.hidePrimaryCapture = false,
  });

  /// Same capture path as the in-picker button — used by the stage “Add a photo” ring.
  static Future<ListingMediaDraft?> captureInto(
    BuildContext context, {
    required ListingMediaDraft draft,
    required Color accentColor,
    String title = 'Add photos',
    int maxImages = ListingMediaConstants.maxPhotosPerListing,
    bool cameraOnly = true,
  }) async {
    if (draft.mediaType == ListingMediaType.video) {
      return _captureVideoInto(
        context,
        draft: draft,
        accentColor: accentColor,
        cameraOnly: cameraOnly,
      );
    }
    return _capturePhotoInto(
      context,
      draft: draft,
      accentColor: accentColor,
      title: title,
      maxImages: maxImages,
      cameraOnly: cameraOnly,
    );
  }

  static Future<ListingMediaDraft?> _capturePhotoInto(
    BuildContext context, {
    required ListingMediaDraft draft,
    required Color accentColor,
    required String title,
    required int maxImages,
    required bool cameraOnly,
  }) async {
    if (draft.videoPath != null) {
      AppToast.show(context, 'Remove video before adding photos.');
      return null;
    }
    if (draft.imagePaths.length >= maxImages) {
      AppToast.show(context, 'Maximum $maxImages images allowed.');
      return null;
    }
    final source = await ImageSourcePickerSheet.show(
      context,
      title: title,
      accentColor: accentColor,
      maxImages: maxImages,
      currentCount: draft.imagePaths.length,
      cameraOnly: cameraOnly,
    );
    if (source == null || !context.mounted) return null;

    File? accepted;
    if (source == ImageSource.gallery) {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked == null || !context.mounted) return null;
      accepted = await ListingCaptureFlow.acceptGalleryPhoto(
        context,
        sourcePath: picked.path,
        stageColor: accentColor,
      );
    } else {
      if (!await PermissionsHelper.requestCameraWithFallback(
        context,
        purpose: 'take a photo',
      )) {
        return null;
      }
      if (!context.mounted) return null;
      accepted = await ListingCaptureFlow.takePhoto(
        context,
        stageColor: accentColor,
      );
    }
    if (accepted == null) return null;
    return ListingMediaDraft(
      mediaType: ListingMediaType.image,
      imagePaths: [...draft.imagePaths, accepted.path],
    );
  }

  static Future<ListingMediaDraft?> _captureVideoInto(
    BuildContext context, {
    required ListingMediaDraft draft,
    required Color accentColor,
    required bool cameraOnly,
  }) async {
    if (draft.imagePaths.isNotEmpty) {
      AppToast.show(context, 'Remove images before adding a video.');
      return null;
    }
    if (!await PermissionsHelper.requestCameraWithFallback(
      context,
      purpose: cameraOnly ? 'record a video' : 'select a video',
    )) {
      return null;
    }
    if (!context.mounted) return null;

    final ProcessedVideoResult? processed;
    if (cameraOnly) {
      processed = await ListingCaptureFlow.takeVideo(
        context,
        stageColor: accentColor,
      );
    } else {
      final file = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: ListingMediaConstants.heroClipMax,
      );
      if (file == null || !context.mounted) return null;
      processed = await ListingCaptureFlow.acceptGalleryVideo(
        context,
        sourcePath: file.path,
        stageColor: accentColor,
      );
    }
    if (processed == null) return null;
    return ListingMediaDraft(
      mediaType: ListingMediaType.video,
      videoPath: processed.videoPath,
      videoThumbnailPath: processed.thumbnailPath,
    );
  }

  @override
  State<ListingMediaPicker> createState() => _ListingMediaPickerState();
}

class _ListingMediaPickerState extends State<ListingMediaPicker> {
  final ImagePicker _picker = ImagePicker();
  late ListingMediaType _mediaType;
  final List<File> _images = [];
  String? _videoPath;
  String? _videoThumbnailPath;
  bool _processingVideo = false;
  double _videoProgress = 0;
  String? _videoSizeLabel;

  @override
  void initState() {
    super.initState();
    _syncFromDraft(widget.initial);
  }

  @override
  void didUpdateWidget(ListingMediaPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_draftEquals(oldWidget.initial, widget.initial) &&
        !_draftEquals(_currentDraft(), widget.initial)) {
      setState(() => _syncFromDraft(widget.initial));
    }
  }

  bool _draftEquals(ListingMediaDraft a, ListingMediaDraft b) {
    if (a.mediaType != b.mediaType) return false;
    if (a.videoPath != b.videoPath) return false;
    if (a.videoThumbnailPath != b.videoThumbnailPath) return false;
    if (a.imagePaths.length != b.imagePaths.length) return false;
    for (var i = 0; i < a.imagePaths.length; i++) {
      if (a.imagePaths[i] != b.imagePaths[i]) return false;
    }
    return true;
  }

  ListingMediaDraft _currentDraft() {
    return ListingMediaDraft(
      mediaType: _mediaType,
      imagePaths: _images.map((f) => f.path).toList(),
      videoPath: _videoPath,
      videoThumbnailPath: _videoThumbnailPath,
    );
  }

  void _syncFromDraft(ListingMediaDraft draft) {
    _mediaType = draft.mediaType;
    _images
      ..clear()
      ..addAll(
        draft.imagePaths
            .map(File.new)
            .where((f) => f.existsSync()),
      );
    _videoPath = draft.videoPath;
    _videoThumbnailPath = draft.videoThumbnailPath;
  }

  void _notify() {
    widget.onChanged(ListingMediaDraft(
      mediaType: _mediaType,
      imagePaths: _images.map((f) => f.path).toList(),
      videoPath: _videoPath,
      videoThumbnailPath: _videoThumbnailPath,
    ));
  }

  void _setMode(ListingMediaType mode) {
    if (mode == _mediaType) return;
    setState(() {
      _mediaType = mode;
      if (mode == ListingMediaType.video) {
        _images.clear();
      } else {
        _videoPath = null;
        _videoThumbnailPath = null;
        _videoSizeLabel = null;
      }
    });
    _notify();
  }

  Future<void> _pickImages() async {
    if (_videoPath != null) {
      _snack('Remove video before adding photos.');
      return;
    }
    if (_images.length >= widget.maxImages) {
      _snack('Maximum ${widget.maxImages} images allowed.');
      return;
    }
    final source = await ImageSourcePickerSheet.show(
      context,
      title: widget.title,
      accentColor: widget.accentColor,
      maxImages: widget.maxImages,
      currentCount: _images.length,
      cameraOnly: widget.cameraOnly,
    );
    if (source == null || !mounted) return;

    File? accepted;
    if (source == ImageSource.gallery) {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked == null || !mounted) return;
      accepted = await ListingCaptureFlow.acceptGalleryPhoto(
        context,
        sourcePath: picked.path,
        stageColor: widget.accentColor,
      );
    } else {
      if (!await PermissionsHelper.requestCameraWithFallback(
        context,
        purpose: 'take a photo',
      )) {
        return;
      }
      if (!mounted) return;
      accepted = await ListingCaptureFlow.takePhoto(
        context,
        stageColor: widget.accentColor,
      );
    }
    if (accepted != null) {
      _images.add(accepted);
    }
    if (mounted && accepted != null) {
      setState(() => _mediaType = ListingMediaType.image);
      _notify();
    }
  }

  Future<void> _pickVideo() async {
    if (_images.isNotEmpty) {
      _snack('Remove images before adding a video.');
      return;
    }
    if (!await PermissionsHelper.requestCameraWithFallback(
      context,
      purpose: widget.cameraOnly ? 'record a video' : 'select a video',
    )) {
      return;
    }
    if (!mounted) return;

    setState(() {
      _processingVideo = true;
      _videoProgress = 0;
      _videoSizeLabel = null;
    });

    final ProcessedVideoResult? processed;
    if (widget.cameraOnly) {
      processed = await ListingCaptureFlow.takeVideo(
        context,
        stageColor: widget.accentColor,
        onProgress: (p) {
          if (mounted) setState(() => _videoProgress = p);
        },
      );
    } else {
      final file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: ListingMediaConstants.heroClipMax,
      );
      if (file == null || !mounted) {
        setState(() => _processingVideo = false);
        return;
      }
      processed = await ListingCaptureFlow.acceptGalleryVideo(
        context,
        sourcePath: file.path,
        stageColor: widget.accentColor,
        onProgress: (p) {
          if (mounted) setState(() => _videoProgress = p);
        },
      );
    }

    if (!mounted) return;
    final ready = processed;
    if (ready == null) {
      setState(() => _processingVideo = false);
      return;
    }

    setState(() {
      _videoPath = ready.videoPath;
      _videoThumbnailPath = ready.thumbnailPath;
      _mediaType = ListingMediaType.video;
      _processingVideo = false;
      _videoSizeLabel =
          '${VideoProcessingUtils.formatSize(ready.compressedBytes)}'
          ' (was ${VideoProcessingUtils.formatSize(ready.originalBytes)})';
    });
    _notify();
  }

  void _snack(String msg) {
    AppToast.show(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos or video',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        ListingMediaUploadGuidance(
          accentColor: widget.accentColor,
          maxPhotos: widget.maxImages,
          moduleLabel: widget.moduleLabel,
        ),
        const SizedBox(height: 12),
        ListingMediaModeSwitch(
          selected: _mediaType,
          accentColor: widget.accentColor,
          onChanged: _setMode,
        ),
        const SizedBox(height: 14),
        if (_mediaType == ListingMediaType.image) ...[
          Text(
            widget.hidePrimaryCapture
                ? (_images.isEmpty
                    ? 'Tap Add a photo above to capture. Up to ${widget.maxImages} photos.'
                    : '${_images.length}/${widget.maxImages} photos · tap the circle above to add more')
                : 'Add up to ${widget.maxImages} photos. The item is cut out before upload.',
            style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
          if (!widget.hidePrimaryCapture) ...[
            const SizedBox(height: 12),
            ListingMediaActionButton(
              accentColor: widget.accentColor,
              icon: Icons.photo_camera_rounded,
              label: widget.cameraOnly ? 'Take photo' : 'Add photos',
              subtitle: _images.isEmpty
                  ? 'Tap to capture your first photo'
                  : '${_images.length}/${widget.maxImages} added · tap to add more',
              onPressed: _pickImages,
            ),
          ],
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _images.asMap().entries.map((e) {
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () => LocalListingMediaPreview.showPhoto(
                        context,
                        file: e.value,
                        gallery: List<File>.from(_images),
                        initialIndex: e.key,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          e.value,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _images.removeAt(e.key));
                          _notify();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ] else ...[
          Text(
            widget.hidePrimaryCapture
                ? (_videoPath == null
                    ? 'Tap the circle above to record a ${ListingMediaConstants.heroClipMax.inSeconds}s video.'
                    : 'Video ready · tap the circle above to replace it')
                : 'One ${ListingMediaConstants.heroClipMax.inSeconds} second video. The poster is cut out.',
            style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
          if (!widget.hidePrimaryCapture) ...[
            const SizedBox(height: 12),
            if (!_processingVideo)
              ListingMediaActionButton(
                accentColor: widget.accentColor,
                icon: Icons.videocam_rounded,
                label: _videoPath == null ? 'Add video' : 'Replace video',
                subtitle: _videoPath == null
                    ? 'Record a short clip of your item'
                    : 'Tap to record a different video',
                onPressed: _pickVideo,
              ),
          ],
          if (_processingVideo)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  BybataLoadingIndicator(
                    size: BybataLoadingSize.compact,
                    color: widget.accentColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Compressing video… ${(_videoProgress * 100).round()}%',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          if (_videoPath != null && !_processingVideo)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () => LocalListingMediaPreview.showVideo(
                        context,
                        videoPath: _videoPath!,
                        thumbnailPath: _videoThumbnailPath,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 180,
                          child: AspectRatio(
                            aspectRatio: ListingMediaConstants.feedAspectRatio,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _videoThumbnailPath != null
                                    ? Image.file(
                                        File(_videoThumbnailPath!),
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: scheme.surfaceContainerHighest,
                                        child: const Icon(
                                          Icons.videocam_rounded,
                                          size: 36,
                                        ),
                                      ),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _videoPath = null;
                            _videoThumbnailPath = null;
                            _videoSizeLabel = null;
                          });
                          _notify();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_videoSizeLabel != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _videoSizeLabel!,
                    style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Tap video to play',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
        ],
        const SizedBox(height: 4),
        Text(
          'Choose photos or one video — not both.',
          style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.45)),
        ),
      ],
    );
  }

}

class ListingMediaModeSwitch extends StatelessWidget {
  final ListingMediaType selected;
  final Color accentColor;
  final ValueChanged<ListingMediaType> onChanged;

  const ListingMediaModeSwitch({
    required this.selected,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeTab(
              label: 'Photos',
              icon: Icons.photo_library_rounded,
              selected: selected == ListingMediaType.image,
              accentColor: accentColor,
              onTap: () => onChanged(ListingMediaType.image),
            ),
          ),
          Expanded(
            child: _ModeTab(
              label: 'Video',
              icon: Icons.videocam_rounded,
              selected: selected == ListingMediaType.video,
              accentColor: accentColor,
              onTap: () => onChanged(ListingMediaType.video),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? Colors.white
                    : accentColor.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? Colors.white
                      : accentColor.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ListingMediaActionButton extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onPressed;

  const ListingMediaActionButton({
    required this.accentColor,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor,
                Color.lerp(accentColor, Colors.black, 0.18)!,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
