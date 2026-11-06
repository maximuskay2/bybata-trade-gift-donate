import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/errors/graceful_errors.dart';

/// Which auth screen / action produced the error.
enum AuthFlow {
  login,
  signUp,
  forgotPassword,
  resetPassword,
  emailVerification,
  googleSignIn,
  appleSignIn,
}

/// Production-safe, user-friendly auth error messages.
abstract final class AuthErrors {
  static String login(Object error, {String? fallback}) =>
      message(error, flow: AuthFlow.login, fallback: fallback);

  static String signUp(Object error, {String? fallback}) =>
      message(error, flow: AuthFlow.signUp, fallback: fallback);

  static String forgotPassword(Object error, {String? fallback}) =>
      message(error, flow: AuthFlow.forgotPassword, fallback: fallback);

  static String resetPassword(Object error, {String? fallback}) =>
      message(error, flow: AuthFlow.resetPassword, fallback: fallback);

  static String emailVerification(Object error, {String? fallback}) =>
      message(error, flow: AuthFlow.emailVerification, fallback: fallback);

  static String googleSignIn(Object error, {String? fallback}) =>
      message(error, flow: AuthFlow.googleSignIn, fallback: fallback);

  static String appleSignIn(Object error, {String? fallback}) =>
      message(error, flow: AuthFlow.appleSignIn, fallback: fallback);

  /// Maps raw errors to copy safe to show in production.
  static String message(
    Object error, {
    AuthFlow flow = AuthFlow.login,
    String? fallback,
  }) {
    if (error is PlatformException) {
      return _platformMessage(error, flow: flow, fallback: fallback);
    }

    if (error is Exception) {
      final text = error.toString();
      if (text.startsWith('Exception: ')) {
        final inner = text.substring('Exception: '.length).trim();
        if (inner.isNotEmpty && !_looksTechnical(inner)) {
          return inner;
        }
      }
    }

    final backend = ErrorHandler.backendMessageFrom(error);
    if (backend != null && backend.isNotEmpty) {
      final mapped = _mapBackendMessage(backend, flow: flow);
      if (mapped != null) return mapped;
      if (!_looksTechnical(backend)) return backend;
    }

    final graceful = GracefulErrors.userMessage(error);
    if (!_isGenericGracefulMessage(graceful)) return graceful;

    return fallback ?? _defaultFor(flow);
  }

  /// Sanitizes a message already stored on [AuthProvider.errorMessage].
  static String sanitizeProviderMessage(
    String? raw, {
    required AuthFlow flow,
    String? fallback,
  }) {
    if (raw == null || raw.trim().isEmpty) {
      return fallback ?? _defaultFor(flow);
    }
    final mapped = _mapBackendMessage(raw.trim(), flow: flow);
    if (mapped != null) return mapped;
    if (_looksTechnical(raw)) return fallback ?? _defaultFor(flow);
    return raw.trim();
  }

  static String? _mapBackendMessage(String raw, {required AuthFlow flow}) {
    final normalized = raw.toLowerCase().trim();

    if (normalized.contains('internal server error') ||
        normalized.contains('server error') ||
        normalized.contains('service unavailable') ||
        normalized == '500' ||
        normalized.contains('status code 500')) {
      return 'Our servers are having trouble right now. Please try again in a moment.';
    }
    if (normalized.contains('email already in use') ||
        normalized.contains('email already exists') ||
        normalized.contains('email is already')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (normalized.contains('username already in use') ||
        normalized.contains('username already taken') ||
        normalized.contains('username is not available')) {
      return 'This username is already taken. Please choose another one.';
    }
    if (normalized.contains('invalid credentials') ||
        normalized.contains('incorrect email or password')) {
      return 'Incorrect email or password. Double-check your details or reset your password.';
    }
    if (normalized.contains('email verification required') ||
        normalized.contains('verify your email')) {
      return 'Please verify your email before signing in. Check your inbox for the code.';
    }
    if (normalized.contains('invalid verification code')) {
      return 'That code is incorrect or has expired. Request a new code and try again.';
    }
    if (normalized.contains('invalid token')) {
      switch (flow) {
        case AuthFlow.resetPassword:
          return 'That reset code is invalid or has expired. Request a new one from your email.';
        case AuthFlow.emailVerification:
          return 'That verification code is invalid or has expired. Tap Resend Code to get a new one.';
        default:
          return 'That code is invalid or has expired. Please request a new one.';
      }
    }
    if (normalized.contains('too many requests') ||
        normalized.contains('rate limit')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }
    if (normalized.contains('google sign-in failed') ||
        normalized.contains('google token missing')) {
      return 'We couldn\'t sign you in with Google. Please try again or use email instead.';
    }
    if (normalized.contains('apple sign-in failed') ||
        normalized.contains('apple account is already linked')) {
      return 'We couldn\'t sign you in with Apple. Please try again or use email instead.';
    }
    if (normalized.contains('google email not verified')) {
      return 'Your Google email must be verified before you can sign in.';
    }
    if (normalized.contains('password') &&
        (normalized.contains('weak') ||
            normalized.contains('short') ||
            normalized.contains('at least'))) {
      return 'Choose a stronger password with at least 8 characters, including letters and numbers.';
    }
    if (normalized.contains('referral') && normalized.contains('invalid')) {
      return 'That referral code isn\'t valid. You can continue without it or check the code and try again.';
    }

    return null;
  }

  static String _platformMessage(
    PlatformException error, {
    required AuthFlow flow,
    String? fallback,
  }) {
    final code = error.code.toLowerCase();
    if (code == 'canceled' || code == 'cancelled') {
      return 'Sign-in was cancelled.';
    }
    if (code == 'google_oauth_error' ||
        (error.message?.toLowerCase().contains('redirect_uri') ?? false)) {
      if (kDebugMode && error.message?.isNotEmpty == true) {
        return 'Google Sign-In setup issue: ${error.message}';
      }
      return 'We couldn\'t sign you in with Google right now. Please try again or use email instead.';
    }
    if (error.message != null &&
        error.message!.isNotEmpty &&
        !_looksTechnical(error.message!)) {
      return error.message!;
    }
    return fallback ?? _defaultFor(flow);
  }

  static bool _looksTechnical(String msg) {
    final m = msg.toLowerCase();
    return m.contains('dioexception') ||
        m.contains('socketexception') ||
        m.contains('httpexception') ||
        m.contains('type \'') ||
        m.contains('stacktrace') ||
        m.contains('redirect_uri') ||
        m.contains('client_id') ||
        m.contains('google_client') ||
        m.contains('failed host lookup') ||
        m.contains('connection refused') ||
        m.contains('internal server error') ||
        m.startsWith('error:') ||
        (m.contains('status code') && RegExp(r'\b\d{3}\b').hasMatch(m));
  }

  static bool _isGenericGracefulMessage(String msg) {
    return msg == GracefulErrors.defaultMessage ||
        msg == "Something went wrong. We've noted the issue." ||
        msg == 'Something went wrong. Please check your input.';
  }

  static String _defaultFor(AuthFlow flow) {
    switch (flow) {
      case AuthFlow.login:
        return 'We couldn\'t sign you in. Please check your details and try again.';
      case AuthFlow.signUp:
        return 'We couldn\'t create your account. Please review your details and try again.';
      case AuthFlow.forgotPassword:
        return 'We couldn\'t send a reset code. Check your email address and try again.';
      case AuthFlow.resetPassword:
        return 'We couldn\'t update your password. Check the code and try again.';
      case AuthFlow.emailVerification:
        return 'We couldn\'t verify your email. Check the code and try again.';
      case AuthFlow.googleSignIn:
        return 'We couldn\'t sign you in with Google. Please try again or use email instead.';
      case AuthFlow.appleSignIn:
        return 'We couldn\'t sign you in with Apple. Please try again or use email instead.';
    }
  }
}
