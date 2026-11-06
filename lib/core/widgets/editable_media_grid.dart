import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'cached_media_image.dart';

/// Grid of existing storage keys + newly picked local files for edit flows.
class EditableMediaGrid extends StatelessWidget {
  final List<String> existingKeys;
  final List<File> newFiles;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemoveExisting;
  final ValueChanged<int> onRemoveNew;
  final int maxTotal;
  final Color accentColor;

  const EditableMediaGrid({
    super.key,
    required this.existingKeys,
    required this.newFiles,
    required this.onAdd,
    required this.onRemoveExisting,
    required this.onRemoveNew,
    this.maxTotal = 5,
    this.accentColor = AppColors.primary,
  });

  int get _total => existingKeys.length + newFiles.length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_total == 0) {
      return GestureDetector(
        onTap: onAdd,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1E24).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 2),
          ),
          child: Column(
            children: [
              Icon(Icons.add_photo_alternate_outlined, color: accentColor, size: 40),
              const SizedBox(height: 8),
              Text(
                'Tap to add photos',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final itemCount = _total + (_total < maxTotal ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == itemCount - 1 && _total < maxTotal) {
          return GestureDetector(
            onTap: onAdd,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withValues(alpha: 0.35)),
              ),
              child: Icon(Icons.add, color: accentColor, size: 32),
            ),
          );
        }

        final isExisting = index < existingKeys.length;
        if (isExisting) {
          final key = existingKeys[index];
          return _MediaTile(
            child: CachedMediaImage(
              mediaKey: key,
              fit: BoxFit.cover,
              errorWidget: Container(
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
            onRemove: () => onRemoveExisting(index),
          );
        }

        final fileIndex = index - existingKeys.length;
        final file = newFiles[fileIndex];
        return _MediaTile(
          child: Image.file(file, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
          onRemove: () => onRemoveNew(fileIndex),
        );
      },
    );
  }
}

class _MediaTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;

  const _MediaTile({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
