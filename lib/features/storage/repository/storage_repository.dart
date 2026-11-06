import 'package:dio/dio.dart';

class StorageRepository {
  final Dio dio;
  StorageRepository(this.dio);

  Future<Map<String, dynamic>> createUploadUrl({
    required String domain,
    required String ext,
    required String contentType,
  }) async {
    final res = await dio.post('/v1/storage/upload-url', data: {
      'domain': domain,
      'ext': ext,
      'contentType': contentType,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> uploadToSignedUrl({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    final tmp = Dio();
    await tmp.put(
      uploadUrl,
      data: bytes,
      options: Options(headers: {
        'Content-Type': contentType,
        'Content-Length': bytes.length.toString(),
      }),
      onSendProgress: onProgress,
    );
  }
}