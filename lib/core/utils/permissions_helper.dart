import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsHelper {
  static Future<bool> requestPhotoLibrary() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      if (status.isGranted || status.isLimited) return true;
      final result = await Permission.photos.request();
      return result.isGranted || result.isLimited;
    } else if (Platform.isAndroid) {
      // Android 13+
      final mediaStatus = await Permission.photos.status; // alias for READ_MEDIA_IMAGES
      if (mediaStatus.isGranted) return true;
      final result = await Permission.photos.request();
      // On older Android, permission_handler maps to READ_EXTERNAL_STORAGE
      return result.isGranted;
    }
    return true;
  }

  static Future<bool> requestCamera() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Request camera permission. If denied or permanently denied, shows a user-friendly
  /// dialog with option to open Settings. Returns true only if permission granted.
  /// On iOS: only checks status; image_picker handles the actual request to avoid
  /// double prompts that keep appearing after user has granted.
  static Future<bool> requestCameraWithFallback(
    BuildContext context, {
    String? purpose,
  }) async {
    if (Platform.isIOS) {
      // On iOS, image_picker requests permission itself. We only check and show our
      // dialog when denied/permanently denied - never call request() to avoid
      // recurring system prompts after user has already granted.
      final status = await Permission.camera.status;
      if (status.isGranted) return true;
      if (status.isDenied) {
        // First-time: let image_picker handle the request when it opens
        return true;
      }
      // Permanently denied: show our dialog
      if (!context.mounted) return false;
      await _showPermissionDeniedDialog(
        context,
        permissionName: 'Camera',
        purpose: purpose ?? 'take photos',
      );
      return false;
    }
    // Android: request as before
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (result.isGranted) return true;
    }
    if (!context.mounted) return false;
    await _showPermissionDeniedDialog(
      context,
      permissionName: 'Camera',
      purpose: purpose ?? 'take photos',
    );
    return false;
  }

  /// Request photo library permission. If denied or permanently denied, shows a
  /// user-friendly dialog with option to open Settings. Returns true only if granted.
  /// On iOS: only checks status; image_picker handles the actual request to avoid
  /// double prompts that keep appearing after user has already granted.
  static Future<bool> requestPhotoLibraryWithFallback(
    BuildContext context, {
    String? purpose,
  }) async {
    if (Platform.isIOS) {
      // On iOS, image_picker requests permission itself. We only check and show our
      // dialog when permanently denied - never call request() to avoid recurring prompts.
      final status = await Permission.photos.status;
      if (status.isGranted || status.isLimited) return true;
      if (status.isDenied) {
        // First-time: let image_picker handle the request when it opens
        return true;
      }
      // Permanently denied: show our dialog
      if (!context.mounted) return false;
      await _showPermissionDeniedDialog(
        context,
        permissionName: 'Photo Library',
        purpose: purpose ?? 'choose photos',
      );
      return false;
    }
    // Android: request as before
    final status = await Permission.photos.status;
    if (status.isGranted) return true;
    if (status.isDenied) {
      final result = await Permission.photos.request();
      if (result.isGranted) return true;
    }
    if (!context.mounted) return false;
    await _showPermissionDeniedDialog(
      context,
      permissionName: 'Photo Library',
      purpose: purpose ?? 'choose photos',
    );
    return false;
  }

  static Future<void> _showPermissionDeniedDialog(
    BuildContext context, {
    required String permissionName,
    required String purpose,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$permissionName Access Needed'),
        content: Text(
          'To $purpose, please allow $permissionName access. '
          'You can enable it in your device Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}