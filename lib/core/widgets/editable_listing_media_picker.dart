import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/listing_media_constants.dart';
import '../models/listing_media.dart';
import '../utils/image_crop_utils.dart';
import '../utils/image_resize_utils.dart';
import '../utils/permissions_helper.dart';
import '../utils/video_processing_utils.dart';
import 'cached_media_image.dart';
import 'image_source_picker_sheet.dart';
import 'listing_media_picker.dart' show ListingMediaActionButton, ListingMediaModeSwitch;
import 'local_listing_media_preview.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';

/// Edit-flow picker: keep/remove existing media or add photos (≤5) or one video.
class EditableListingMediaPicker extends StatefulWidget {
  final Color accentColor;
  final ListingMediaFields initialExisting;
  final ValueChanged<EditableListingMediaState> onChanged;
  final int maxImages;
  final String? moduleLabel;
  final bool cameraOnly;
  final String? title;
  final bool compact;

  const EditableListingMediaPicker({
    super.key,
    required this.accentColor,
    required this.initialExisting,
    required this.onChanged,
    this.maxImages = ListingMediaConstants.maxPhotosPerListing,
    this.moduleLabel,
    this.cameraOnly = true,
    this.title,
    this.compact = false,
  });

  @override
  State<EditableListingMediaPicker> createState() =>
      _EditableListingMediaPickerState();
}

class _EditableListingMediaPickerState extends State<EditableListingMediaPicker> {
  final ImagePicker _picker = ImagePicker();
  late EditableListingMediaState _state;
  bool _processingVideo = false;
  double _videoProgress = 0;
  String? _videoSizeLabel;

  @override
  void initState() {
    super.initState();
    _state = EditableListingMediaState.fromExisting(widget.initialExisting);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onChanged(_state);
    });
  }

  void _emit(EditableListingMediaState next) {
    setState(() => _state = next);
    widget.onChanged(next);
  }

  void _setMode(ListingMediaType mode) {
    if (mode == _state.mediaType) return;
    _emit(_state.copyWith(
      mediaType: mode,
      clearImages: mode == ListingMediaType.video,
      clearVideo: mode == ListingMediaType.image,
    ));
    if (mode == ListingMediaType.image) {
      setState(() => _videoSizeLabel = null);
    }
  }

  Future<void> _pickImages() async {
    if (_state.mediaType == ListingMediaType.video) return;
    if (_state.totalImageCount >= widget.maxImages) {
      _toast('Maximum ${widget.maxImages} images allowed.');
      return;
    }
    final source = await ImageSourcePickerSheet.show(
      context,
      title: 'Add photos',
      accentColor: widget.accentColor,
      maxImages: widget.maxImages,
      currentCount: _state.totalImageCount,
      cameraOnly: widget.cameraOnly,
    );
    if (source == null || !mounted) return;

    final files = <File>[];
    if (!await PermissionsHelper.requestCameraWithFallback(
      context,
      purpose: 'take a photo',
    )) {
      return;
    }
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (file == null || !mounted) return;
    final cropped = await ImageCropUtils.cropToFeedWidescreen(context, File(file.path));
    if (cropped == null || !mounted) return;
    files.add(await ImageResizeUtils.resizeToFeedAspectFile(cropped));

    if (files.isEmpty || !mounted) return;
    _emit(_state.copyWith(
      mediaType: ListingMediaType.image,
      newImageFiles: [..._state.newImageFiles, ...files],
      clearVideo: true,
    ));
  }

  Future<void> _pickVideo() async {
    if (_state.mediaType == ListingMediaType.image && _state.totalImageCount > 0) {
      _toast('Remove images before adding a video.');
      return;
    }
    if (!await PermissionsHelper.requestCameraWithFallback(
      context,
      purpose: widget.cameraOnly ? 'record a video' : 'select a video',
    )) {
      return;
    }
    final file = await _picker.pickVideo(
      source: widget.cameraOnly ? ImageSource.camera : ImageSource.gallery,
      maxDuration: VideoProcessingUtils.maxDuration,
    );
    if (file == null || !mounted) return;

    setState(() {
      _processingVideo = true;
      _videoProgress = 0;
      _videoSizeLabel = null;
    });

    final processed = await VideoProcessingUtils.prepareForUpload(
      file.path,
      onProgress: (p) {
        if (mounted) setState(() => _videoProgress = p);
      },
    );

    if (!mounted) return;
    if (processed == null) {
      setState(() => _processingVideo = false);
      _toast('Videos must be 1 minute or shorter.');
      return;
    }

    setState(() => _processingVideo = false);
    _emit(_state.copyWith(
      mediaType: ListingMediaType.video,
      newVideoPath: processed.videoPath,
      newVideoThumbnailPath: processed.thumbnailPath,
      clearImages: true,
      clearVideo: true,
      keptVideoKey: null,
      keptThumbnailKey: null,
    ));
    setState(() {
      _videoSizeLabel =
          '${VideoProcessingUtils.formatSize(processed.compressedBytes)}'
          ' (was ${VideoProcessingUtils.formatSize(processed.originalBytes)})';
    });
  }

  void _toast(String msg) => AppToast.show(context, msg);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVideo = _state.mediaType == ListingMediaType.video;
    final heading = widget.title ?? 'Add photos or a short video';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.compact) ...[
          Text(
            heading,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
        ],
        ListingMediaModeSwitch(
          selected: _state.mediaType,
          accentColor: widget.accentColor,
          onChanged: _setMode,
        ),
        const SizedBox(height: 14),
        if (!isVideo) ...[
          if (_state.totalImageCount == 0)
            ListingMediaActionButton(
              accentColor: widget.accentColor,
              icon: Icons.add_a_photo_rounded,
              label: widget.cameraOnly ? 'Take photo' : 'Add photos',
              subtitle:
                  'Up to ${widget.maxImages} photos · ${ListingMediaConstants.aspectRatioLabel}',
              onPressed: _pickImages,
            )
          else ...[
            Text(
              '${_state.totalImageCount} of ${widget.maxImages} photos · ${ListingMediaConstants.aspectRatioLabel}',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _state.totalImageCount +
                  (_state.totalImageCount < widget.maxImages ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _state.totalImageCount &&
                    _state.totalImageCount < widget.maxImages) {
                  return GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.accentColor.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        color: widget.accentColor.withValues(alpha: isDark ? 0.08 : 0.05),
                      ),
                      child: Icon(Icons.add_rounded, color: widget.accentColor, size: 28),
                    ),
                  );
                }
                final isExisting = index < _state.keptImageKeys.length;
                if (isExisting) {
                  final key = _state.keptImageKeys[index];
                  return _removableTile(
                    onPreview: () => LocalListingMediaPreview.showRemotePhoto(
                      context,
                      mediaKey: key,
                    ),
                    child: CachedMediaImage(mediaKey: key, fit: BoxFit.cover),
                    onRemove: () {
                      final keys = List<String>.from(_state.keptImageKeys)
                        ..removeAt(index);
                      _emit(_state.copyWith(keptImageKeys: keys));
                    },
                  );
                }
                final fileIndex = index - _state.keptImageKeys.length;
                final file = _state.newImageFiles[fileIndex];
                return _removableTile(
                  onPreview: () => LocalListingMediaPreview.showPhoto(
                    context,
                    file: file,
                    gallery: List<File>.from(_state.newImageFiles),
                    initialIndex: fileIndex,
                  ),
                  child: Image.file(file, fit: BoxFit.cover),
                  onRemove: () {
                    final files = List<File>.from(_state.newImageFiles)
                      ..removeAt(fileIndex);
                    _emit(_state.copyWith(newImageFiles: files));
                  },
                );
              },
            ),
            if (_state.totalImageCount < widget.maxImages) ...[
              const SizedBox(height: 10),
              ListingMediaActionButton(
                accentColor: widget.accentColor,
                icon: Icons.add_a_photo_rounded,
                label: widget.cameraOnly ? 'Take another photo' : 'Add more photos',
                subtitle: '${widget.maxImages - _state.totalImageCount} slots left',
                onPressed: _pickImages,
              ),
            ],
          ],
        ] else ...[
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
            )
          else if (!_state.hasMedia)
            ListingMediaActionButton(
              accentColor: widget.accentColor,
              icon: Icons.videocam_rounded,
              label: 'Record video',
              subtitle:
                  'One video · ${ListingMediaConstants.maxVideoDurationLabel} · auto-compressed',
              onPressed: _pickVideo,
            )
          else ...[
            _buildVideoPreview(scheme),
            const SizedBox(height: 10),
            ListingMediaActionButton(
              accentColor: widget.accentColor,
              icon: Icons.swap_horiz_rounded,
              label: 'Replace video',
              subtitle: 'Record a new clip to replace the current one',
              onPressed: _pickVideo,
            ),
          ],
        ],
        const SizedBox(height: 4),
        Text(
          'Choose photos or one video — not both.',
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPreview(ColorScheme scheme) {
    final hasNew = _state.newVideoPath != null && _state.newVideoPath!.isNotEmpty;
    Widget preview;
    if (hasNew && _state.newVideoThumbnailPath != null) {
      preview = Image.file(
        File(_state.newVideoThumbnailPath!),
        fit: BoxFit.cover,
      );
    } else if (_state.keptThumbnailKey != null &&
        _state.keptThumbnailKey!.trim().isNotEmpty) {
      preview = CachedMediaImage(
        mediaKey: _state.keptThumbnailKey!,
        fit: BoxFit.cover,
      );
    } else {
      preview = Container(
        color: scheme.surfaceContainerHighest,
        child: const Icon(Icons.videocam_rounded, size: 36),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () {
                if (hasNew) {
                  LocalListingMediaPreview.showVideo(
                    context,
                    videoPath: _state.newVideoPath!,
                    thumbnailPath: _state.newVideoThumbnailPath,
                  );
                } else {
                  AppToast.show(
                    context,
                    'Play this video from the listing details after saving',
                  );
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 180,
                  child: AspectRatio(
                    aspectRatio: ListingMediaConstants.feedAspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        preview,
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
                  _emit(_state.copyWith(clearVideo: true));
                  setState(() => _videoSizeLabel = null);
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
          hasNew ? 'Tap video to play' : 'Save to preview this video',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  Widget _removableTile({
    required Widget child,
    required VoidCallback onRemove,
    VoidCallback? onPreview,
  }) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onPreview,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.expand(child: child),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
