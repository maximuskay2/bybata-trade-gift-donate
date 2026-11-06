enum AppExceptionType {
  network,
  timeout,
  unauthorized,
  notFound,
  server,
  serviceUnavailable,
  badRequest,
  unknown,
}

class AppException implements Exception {
  final AppExceptionType type;
  final String userMessage;
  final int? statusCode;
  final Object? originalError;

  const AppException({
    required this.type,
    required this.userMessage,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'AppException(type: $type, statusCode: $statusCode, message: $userMessage)';
}
