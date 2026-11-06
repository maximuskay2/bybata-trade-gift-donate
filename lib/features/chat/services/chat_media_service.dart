import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../storage/repository/storage_repository.dart';
import '../utils/chat_image_prep.dart';

/// Service for uploading chat media (images, videos, files, voice notes).
class ChatMediaService {
  ChatMediaService(this._storage);

  final StorageRepository _storage;

  static Future<ChatMediaService> create() async {
    final baseUrl = await EnvConfig.getBaseUrl();
    final client = ApiClient(baseUrl, const FlutterSecureStorage());
    return ChatMediaService(StorageRepository(client.dio));
  }

  /// Upload a chat photo. Normalizes to JPEG when possible.
  Future<String?> uploadImage(File file) async {
    try {
      final prepared = await ChatImagePrep.prepareJpeg(file);
      final bytes = await prepared.readAsBytes();
      if (bytes.isEmpty) return null;

      final ext = prepared.path.toLowerCase().endsWith('.jpg') ||
              prepared.path.toLowerCase().endsWith('.jpeg')
          ? 'jpg'
          : (_extFromPath(prepared.path) ?? 'jpg');
      final contentType = _contentTypeFromExt(ext, kind: _MediaKind.image);

      return await _uploadBytes(bytes, ext: ext, contentType: contentType);
    } catch (e, st) {
      debugPrint('[ChatMediaService] uploadImage failed: $e\n$st');
      return null;
    }
  }

  /// Upload a chat video (mp4/mov/etc.).
  Future<String?> uploadVideo(File file, {String? ext}) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      final fileExt = (ext ?? _extFromPath(file.path) ?? 'mp4').toLowerCase();
      final contentType = _contentTypeFromExt(fileExt, kind: _MediaKind.video);
      return await _uploadBytes(bytes, ext: fileExt, contentType: contentType);
    } catch (e, st) {
      debugPrint('[ChatMediaService] uploadVideo failed: $e\n$st');
      return null;
    }
  }

  /// Upload a generic file (document, etc.).
  Future<String?> uploadFile(File file, {String? ext}) async {
    try {
      final bytes = await file.readAsBytes();
      return uploadBytes(bytes, ext: ext ?? _extFromPath(file.path) ?? 'bin');
    } catch (e, st) {
      debugPrint('[ChatMediaService] uploadFile failed: $e\n$st');
      return null;
    }
  }

  /// Upload raw bytes (needed when [PlatformFile.path] is null on iOS).
  Future<String?> uploadBytes(
    Uint8List bytes, {
    required String ext,
    String? contentType,
  }) async {
    try {
      if (bytes.isEmpty) return null;
      final fileExt = ext.toLowerCase();
      final ct = contentType ??
          _contentTypeFromExt(fileExt, kind: _MediaKind.file);
      return await _uploadBytes(bytes, ext: fileExt, contentType: ct);
    } catch (e, st) {
      debugPrint('[ChatMediaService] uploadBytes failed: $e\n$st');
      return null;
    }
  }

  /// Upload an audio file (voice note).
  Future<String?> uploadAudio(File file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      final ext = _extFromPath(file.path) ?? 'm4a';
      const contentType = 'audio/mp4';
      return await _uploadBytes(bytes, ext: ext, contentType: contentType);
    } catch (e, st) {
      debugPrint('[ChatMediaService] uploadAudio failed: $e\n$st');
      return null;
    }
  }

  Future<String?> _uploadBytes(
    Uint8List bytes, {
    required String ext,
    required String contentType,
  }) async {
    final meta = await _storage.createUploadUrl(
      domain: 'chat',
      ext: ext,
      contentType: contentType,
    );
    final uploadUrl = meta['uploadUrl'] as String?;
    final key = meta['key'] as String?;
    if (uploadUrl == null || key == null) return null;
    await _storage.uploadToSignedUrl(
      uploadUrl: uploadUrl,
      bytes: bytes,
      contentType: contentType,
    );
    return key;
  }

  String? _extFromPath(String path) {
    final parts = path.split('.');
    if (parts.length < 2) return null;
    return parts.last.toLowerCase();
  }

  String _contentTypeFromExt(String ext, {required _MediaKind kind}) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'mp4':
        // mp4 is ambiguous — prefer video when uploading video attachments.
        return kind == _MediaKind.video ? 'video/mp4' : 'audio/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'webm':
        return 'video/webm';
      case 'm4a':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }
}

enum _MediaKind { image, video, file }
