import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Downloads PDF receipts from the API and opens the system share sheet.
class ReceiptDownloadService {
  static Future<File> downloadPdf({
    required Dio dio,
    required String path,
    required String fallbackFilename,
  }) async {
    final response = await dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    final raw = response.data;
    if (raw == null || raw.isEmpty) {
      throw Exception('Empty receipt response');
    }

    final bytes = raw is Uint8List ? raw : Uint8List.fromList(List<int>.from(raw));
    if (!_looksLikePdf(bytes)) {
      final preview = String.fromCharCodes(bytes.take(200));
      throw Exception(
        preview.contains('message')
            ? 'Receipt could not be generated. Please try again later.'
            : 'Server did not return a valid PDF receipt.',
      );
    }

    final filename = _filenameFromDisposition(
          response.headers.value('content-disposition'),
        ) ??
        fallbackFilename;

    final dir = await getApplicationDocumentsDirectory();
    final safeName = filename.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static bool _looksLikePdf(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  static Future<void> sharePdf(
    File file, {
    String? subject,
    BuildContext? context,
  }) async {
    final name = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'receipt.pdf';
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf', name: name)],
      subject: subject,
      sharePositionOrigin: _shareOrigin(context),
    );
  }

  static Rect _shareOrigin(BuildContext? context) {
    if (context != null) {
      final box = context.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final offset = box.localToGlobal(Offset.zero);
        return offset & box.size;
      }
    }
    return const Rect.fromLTWH(0, 0, 1, 1);
  }

  static Future<File> downloadAndShare({
    required Dio dio,
    required String path,
    required String fallbackFilename,
    String? shareSubject,
    BuildContext? context,
  }) async {
    final file = await downloadPdf(
      dio: dio,
      path: path,
      fallbackFilename: fallbackFilename,
    );
    await sharePdf(file, subject: shareSubject, context: context);
    return file;
  }

  static String? _filenameFromDisposition(String? contentDisposition) {
    if (contentDisposition == null) return null;
    final match = RegExp(r'filename="?([^";\n]+)"?').firstMatch(contentDisposition);
    return match?.group(1)?.trim();
  }
}
