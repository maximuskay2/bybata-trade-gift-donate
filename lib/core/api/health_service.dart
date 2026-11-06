import 'package:dio/dio.dart';

class HealthService {
  final Dio dio;
  HealthService(this.dio);

  Future<Map<String, dynamic>> getHealth() async {
    final res = await dio.get('/health', options: Options(headers: {'Accept': 'application/json'}));
    return Map<String, dynamic>.from(res.data as Map);
  }
}