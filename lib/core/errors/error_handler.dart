import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'app_exception.dart';

class ErrorHandler {
  static String? backendMessageFrom(Object error) {
    if (error is DioException) {
      return _messageFromResponseData(error.response?.data);
    }
    if (error is AppException && error.originalError is DioException) {
      return _messageFromResponseData(
        (error.originalError as DioException).response?.data,
      );
    }
    return null;
  }

  static String? _messageFromResponseData(dynamic data) {
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
      if (msg is List && msg.isNotEmpty) {
        final first = msg.first;
        if (first is String && first.isNotEmpty) return first;
      }
      if (msg is Map && msg['message'] is String) {
        return msg['message'] as String;
      }
    }
    return null;
  }

  static AppException toAppException(Object error) {
    if (error is AppException) return error;

    if (error is DioException) {
      final status = error.response?.statusCode;
      final backendMessage = _messageFromResponseData(error.response?.data);
      if (error.type == DioExceptionType.connectionError ||
          error.error is SocketException) {
        return const AppException(
          type: AppExceptionType.network,
          userMessage: 'No internet connection. Please check your settings.',
        );
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return const AppException(
          type: AppExceptionType.timeout,
          userMessage: 'The connection timed out. Please try again.',
        );
      }
      if (status == 401) {
        final normalized = backendMessage?.toLowerCase() ?? '';
        if (normalized.contains('verification')) {
          return const AppException(
            type: AppExceptionType.unauthorized,
            userMessage: 'Please verify your email to continue.',
            statusCode: 401,
          );
        }
        if (normalized.contains('invalid token') &&
            !normalized.contains('apple') &&
            !normalized.contains('google')) {
          return const AppException(
            type: AppExceptionType.unauthorized,
            userMessage: 'Invalid or expired code. Please try again.',
            statusCode: 401,
          );
        }
        if (backendMessage?.isNotEmpty == true) {
          return AppException(
            type: AppExceptionType.unauthorized,
            userMessage: backendMessage!,
            statusCode: 401,
            originalError: error,
          );
        }
        return const AppException(
          type: AppExceptionType.unauthorized,
          userMessage: 'Session expired. Please log in again.',
          statusCode: 401,
        );
      }
      if (status == 404) {
        return const AppException(
          type: AppExceptionType.notFound,
          userMessage: "We couldn't find what you were looking for.",
          statusCode: 404,
        );
      }
      if (status == 429) {
        return const AppException(
          type: AppExceptionType.badRequest,
          userMessage: 'Too many requests. Please wait a bit and try again.',
          statusCode: 429,
        );
      }
      if (status == 500) {
        return const AppException(
          type: AppExceptionType.server,
          userMessage: 'Our servers are having a moment. Please try again later.',
          statusCode: 500,
        );
      }
      if (status == 502 || status == 503) {
        return const AppException(
          type: AppExceptionType.serviceUnavailable,
          userMessage: "Service is temporarily unavailable. We'll be back soon!",
          statusCode: 503,
        );
      }
      if (status != null && status >= 400 && status < 500) {
        return AppException(
          type: status == 401
              ? AppExceptionType.unauthorized
              : AppExceptionType.badRequest,
          userMessage: backendMessage?.isNotEmpty == true
              ? backendMessage!
              : 'Something went wrong. Please check your input.',
          statusCode: status,
          originalError: error,
        );
      }
    }

    return AppException(
      type: AppExceptionType.unknown,
      userMessage: "Something went wrong. We've noted the issue.",
      originalError: error,
    );
  }

  static bool isRelease() => kReleaseMode;
}
