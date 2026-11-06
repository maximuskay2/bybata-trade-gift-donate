import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/listing_media_constants.dart';

/// A modern bottom sheet for choosing between camera and gallery when uploading images.
/// Used in trade, gift, donation, and ad creation flows.
class ImageSourcePickerSheet extends StatelessWidget {
  final String title;
  final String? gallerySubtitle;
  final Color? accentColor;
  final int maxImages;
  final int currentCount;
  /// When true, gallery is hidden (fraud prevention for listings/profile).
  final bool cameraOnly;

  const ImageSourcePickerSheet({
    super.key,
    this.title = 'Add photos',
    this.gallerySubtitle,
    this.accentColor,
    this.maxImages = ListingMediaConstants.maxPhotosPerListing,
    this.currentCount = 0,
    this.cameraOnly = false,
  });

  /// Shows the image source picker sheet and returns the selected source, or null if cancelled.
  static Future<ImageSource?> show(
    BuildContext context, {
    String title = 'Add photos',
    String? gallerySubtitle,
    Color? accentColor,
    int maxImages = ListingMediaConstants.maxPhotosPerListing,
    int currentCount = 0,
    bool cameraOnly = false,
  }) {
    if (cameraOnly) {
      return Future.value(ImageSource.camera);
    }
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ImageSourcePickerSheet(
        title: title,
        gallerySubtitle: gallerySubtitle,
        accentColor: accentColor,
        maxImages: maxImages,
        currentCount: currentCount,
        cameraOnly: cameraOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accentColor ?? scheme.primary;
    final remaining = maxImages - currentCount;
    final galleryHint = gallerySubtitle ??
        (remaining > 0
            ? '${ListingMediaConstants.aspectRatioLabel} · up to $remaining ${remaining == 1 ? 'photo' : 'photos'}'
            : 'Choose from your library');

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              _buildOption(
                context: context,
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                subtitle: cameraOnly
                    ? 'Live photo required for verification'
                    : 'Take a new photo',
                color: color,
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              if (!cameraOnly) ...[
                const SizedBox(height: 12),
                _buildOption(
                  context: context,
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  subtitle: galleryHint,
                  color: color,
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface.withValues(alpha: 0.4),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
