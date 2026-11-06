/**
 * Promotion Error Handler Utility
 * 
 * Centralized error handling for all promotion/boost/ad flows
 * Maps backend errors to user-friendly messages and provides actionable feedback
 */

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

enum PromotionErrorType {
  insufficientBalance,
  promotionNotFound,
  promotionInactive,
  invalidAmount,
  verificationFailed,
  limitExceeded,
  boostTypeNotFound,
  configurationMissing,
  placementNotFound,
  invalidDaysRange,
  placementNotAllowed,
  invalidSchedule,
  schedulePast,
  missingContent,
  invalidReference,
  networkTimeout,
  connectionFailed,
  serverError,
  unknown,
}

class PromotionErrorHandler {
  /// Extract message from Dio/API errors or raw exceptions.
  static String? extractBackendMessage(Object? error) {
    if (error == null) return null;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final msg = data['message'];
        if (msg is String && msg.isNotEmpty) return msg;
        if (msg is List && msg.isNotEmpty) {
          return msg.map((e) => e.toString()).join(', ');
        }
      }
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  /// Parse backend error message and return user-friendly message
  static String parseErrorMessage(String? backendError) {
    if (backendError == null || backendError.isEmpty) {
      return 'An unexpected error occurred. Please try again.';
    }

    final error = backendError.toLowerCase();

    if (error.contains('transaction already closed') ||
        (error.contains('transaction') && error.contains('timeout')) ||
        error.contains('took too long to process')) {
      return 'Payment took too long. Wait a moment and try again — if your balance was not deducted, you can safely retry.';
    }

    if (error.contains('prisma') ||
        error.contains('invocation') ||
        error.contains('p2028')) {
      return 'Something went wrong on our side. Please try again in a moment.';
    }

    if (error.contains('advert purchase failed') ||
        error.contains('promotion purchase failed')) {
      final stripped = backendError.replaceFirst(
        RegExp(r'^(advert|promotion) purchase failed:\s*', caseSensitive: false),
        '',
      );
      if (stripped.length < 120 &&
          !stripped.toLowerCase().contains('prisma')) {
        return parseErrorMessage(stripped);
      }
      return 'Payment could not be completed. Please try again.';
    }

    // Balance errors
    if (error.contains('insufficient funds')) {
      return _extractBalanceMessage(backendError);
    }

    // Promotion errors
    if (error.contains('promotion not found')) {
      return 'This promotion is no longer available.';
    }
    if (error.contains('promotion is not active')) {
      return 'This promotion has ended. Check other active promotions.';
    }
    if (error.contains('invalid promotion amount')) {
      return 'Promotion configuration is invalid. Please contact support.';
    }

    // Verification errors
    if (error.contains('incorrect pin') || error.contains('verification failed')) {
      return 'Authentication failed. Please try again.';
    }
    if (error.contains('biometric authentication failed')) {
      return 'Biometric authentication failed. Try again or use PIN.';
    }

    // Transaction limit errors
    if (error.contains('daily') && error.contains('limit')) {
      return 'You\'ve reached your daily promotion limit. Try again tomorrow.';
    }
    if (error.contains('monthly') && error.contains('limit')) {
      return 'You\'ve reached your monthly spending limit.';
    }
    if (error.contains('transaction limit') || error.contains('exceeds')) {
      return 'This amount exceeds your single transaction limit.';
    }

    // Boost configuration errors
    if (error.contains('boost type not found') || error.contains('boost type') && error.contains('not')) {
      return 'Selected boost type is no longer available.';
    }
    if (error.contains('boost configuration not found')) {
      return 'Boost configuration is not available right now. Please try again later.';
    }

    // Placement errors
    if (error.contains('placement not found') && error.contains('not')) {
      return 'Selected ad placement is no longer available.';
    }
    if (error.contains('placement not allowed')) {
      return 'This boost type is not available for the selected placement.';
    }

    // Days range errors
    if (error.contains('days must be between')) {
      return _extractDaysMessage(backendError);
    }

    // Schedule errors
    if (error.contains('end date must be after')) {
      return 'Ad end date must be after start date.';
    }
    if (error.contains('past') && error.contains('schedule')) {
      return 'Ad must be scheduled for a future date.';
    }

    // Content validation errors
    if (error.contains('required') && (error.contains('title') || error.contains('media'))) {
      return 'Please fill in all required ad details (title, media, dates).';
    }

    // Reference errors
    if (error.contains('invalid reference')) {
      return 'Unable to promote this item. Please try again or refresh.';
    }

    // Network errors
    if (error.contains('timeout')) {
      return 'Request timed out. Please check your connection and try again.';
    }
    if (error.contains('connection') || error.contains('network')) {
      return 'Connection failed. Please check your internet and try again.';
    }

    // Server errors
    if (error.contains('500') || error.contains('internal server')) {
      return 'Server error. Our team has been notified. Please try again later.';
    }
    if (error.contains('400') || error.contains('bad request')) {
      return 'Invalid request. Please try again or contact support.';
    }

    // Fallback
    return backendError.length > 100 
      ? 'An error occurred. Please try again or contact support.'
      : backendError;
  }

  /// Extract specific balance message with amounts
  static String _extractBalanceMessage(String message) {
    try {
      final availableMatch = RegExp(r'Available: ([\d.]+)').firstMatch(message);
      final requiredMatch = RegExp(r'Required: ([\d.]+)').firstMatch(message);
      
      if (availableMatch != null && requiredMatch != null) {
        final available = availableMatch.group(1);
        final required = requiredMatch.group(1);
        return 'Insufficient balance. You have $available BYC but need $required BYC.\nAdd funds to your wallet.';
      }
    } catch (_) {}
    
    return 'Insufficient balance. Please add funds to your wallet.';
  }

  /// Extract days range message
  static String _extractDaysMessage(String message) {
    try {
      final match = RegExp(r'between (\d+) and (\d+)').firstMatch(message);
      if (match != null) {
        final min = match.group(1);
        final max = match.group(2);
        return 'Boost duration must be between $min and $max days.';
      }
    } catch (_) {}
    
    return 'Please select a valid boost duration.';
  }

  /// Determine if error is retryable
  static bool isRetryable(String? error) {
    if (error == null) return false;
    final e = error.toLowerCase();
    return e.contains('timeout') ||
        e.contains('took too long') ||
        e.contains('transaction already closed') ||
        e.contains('connection') ||
        e.contains('network') ||
        e.contains('500') ||
        e.contains('temporarily');
  }

  /// Get appropriate icon for error type
  static IconData getErrorIcon(PromotionErrorType type) {
    switch (type) {
      case PromotionErrorType.insufficientBalance:
        return Icons.account_balance_wallet;
      case PromotionErrorType.networkTimeout:
      case PromotionErrorType.connectionFailed:
        return Icons.cloud_off;
      case PromotionErrorType.verificationFailed:
        return Icons.lock;
      case PromotionErrorType.limitExceeded:
        return Icons.block;
      default:
        return Icons.error_outline;
    }
  }

  /// Get toast duration based on error severity
  static Duration getToastDuration(String? error) {
    if (error == null) return const Duration(seconds: 3);
    
    final e = error.toLowerCase();
    
    // Important errors should stay longer
    if (e.contains('limit') || e.contains('verification') || e.contains('balance')) {
      return const Duration(seconds: 5);
    }
    
    return const Duration(seconds: 3);
  }
}

/// Action recommendation helper
class PromotionActionRecommendation {
  static String? getRetryAction(String? error) {
    if (PromotionErrorHandler.isRetryable(error)) {
      return 'Retry';
    }
    return null;
  }

  static String? getAlternativeAction(String? error) {
    if (error == null) return null;
    
    final e = error.toLowerCase();
    
    if (e.contains('insufficient')) {
      return 'Add Funds';
    }
    
    if (e.contains('not found') || e.contains('unavailable')) {
      return 'View Others';
    }
    
    if (e.contains('limit')) {
      return 'View Limits';
    }
    
    return null;
  }
}

/// Promotion Success Handler
/// Provides user-friendly success messages for various promotion operations
class PromotionSuccessHandler {
  /// Get success message based on promotion type
  static String getSuccessMessage({
    required String itemTitle,
    required String promotionType,
    int? days,
  }) {
    switch (promotionType.toLowerCase()) {
      case 'promotion':
        return '✓ \"$itemTitle\" has been promoted successfully!\nYour promotion is now active.';
      
      case 'boost':
        return '✓ \"$itemTitle\" has been boosted for $days day${days != 1 ? 's' : ''}!\nYour boost is now active.';
      
      case 'ad':
        return '✓ Your ad campaign is now live!\nStart reaching more customers today.';
      
      default:
        return '✓ Your promotion is now active!';
    }
  }

  /// Get success description for toast notifications
  static String getSuccessDescription(String promotionType) {
    switch (promotionType.toLowerCase()) {
      case 'promotion':
        return 'Promotion activated';
      case 'boost':
        return 'Boost activated';
      case 'ad':
        return 'Ad campaign live';
      default:
        return 'Success';
    }
  }
}
