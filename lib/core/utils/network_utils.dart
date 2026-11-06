import 'dart:io';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

/// Network connectivity utility class
class NetworkUtils {
  static final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connection (hard-capped so startup never hangs).
  static Future<bool> hasInternetConnection({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      return await _hasInternetConnectionImpl().timeout(timeout);
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _hasInternetConnectionImpl() async {
    try {
      final connectivityResult = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(seconds: 2));

      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }

      final result = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Listen to connectivity changes
  static Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged;
  }

  /// Check if error is a network error
  static bool isNetworkError(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError ||
          (error.error is SocketException) ||
          (error.error is TimeoutException);
    }
    return error is SocketException || error is TimeoutException;
  }

  /// Check if error is a server error
  static bool isServerError(dynamic error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      return statusCode != null && statusCode >= 500;
    }
    return false;
  }

  /// Get user-friendly error message
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection timeout. Please check your internet connection and try again.';
        
        case DioExceptionType.connectionError:
          if (error.error is SocketException) {
            return 'No internet connection. Please check your network settings.';
          }
          return 'Failed to connect to server. Please try again later.';
        
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final message = error.response?.data?['message'];
          
          switch (statusCode) {
            case 400:
              return message ?? 'Invalid request. Please check your input.';
            case 401:
              return 'Your session has expired. Please login again.';
            case 403:
              return 'You do not have permission to perform this action.';
            case 404:
              return 'The requested resource was not found.';
            case 429:
              return 'Too many requests. Please wait a moment and try again.';
            case 500:
              return 'Server error. Our team has been notified.';
            case 502:
            case 503:
            case 504:
              return 'Server is temporarily unavailable. Please try again in a few moments.';
            default:
              return message ?? 'Something went wrong. Please try again.';
          }
        
        case DioExceptionType.cancel:
          return 'Request was cancelled.';
        
        case DioExceptionType.unknown:
          if (error.error is SocketException) {
            return 'No internet connection. Please check your network settings.';
          }
          return 'An unexpected error occurred. Please try again.';
        
        default:
          return 'An error occurred. Please try again.';
      }
    }
    
    if (error is SocketException) {
      return 'No internet connection. Please check your network settings.';
    }
    
    if (error is TimeoutException) {
      return 'Connection timeout. Please try again.';
    }
    
    return error.toString();
  }
}
