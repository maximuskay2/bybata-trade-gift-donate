import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../config/env_config.dart';

/// Browser-based Google OAuth for Android (Chrome Custom Tab).
///
/// Uses the same iOS OAuth client + reversed URL scheme as iOS
/// (ASWebAuthenticationSession), with authorization-code + PKCE — Web clients
/// reject custom-scheme redirects and block implicit `id_token` flows.
class GoogleBrowserSignInResult {
  final String idToken;
  final String? email;

  const GoogleBrowserSignInResult({
    required this.idToken,
    this.email,
  });
}

class GoogleBrowserSignIn {
  GoogleBrowserSignIn._();

  static const _authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';

  /// Opens Google's sign-in page in a browser tab and returns an ID token.
  ///
  /// Returns `null` when the user cancels. Throws on configuration errors.
  static Future<GoogleBrowserSignInResult?> signIn() async {
    final clientId = EnvConfig.googleOAuthClientId;
    if (clientId.isEmpty) {
      throw PlatformException(
        code: 'google_not_configured',
        message: 'Google OAuth client ID is not configured.',
      );
    }

    final redirectUri = EnvConfig.googleOAuthRedirectUri;
    final codeVerifier = _randomCodeVerifier();
    final codeChallenge = _codeChallenge(codeVerifier);
    final state = _randomNonce();

    final url = Uri.parse(_authEndpoint).replace(
      queryParameters: {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': state,
        'prompt': 'select_account',
      },
    );

    final callbackUrl = await FlutterWebAuth2.authenticate(
      url: url.toString(),
      callbackUrlScheme: EnvConfig.googleOAuthCallbackScheme,
    );

    final callback = Uri.parse(callbackUrl);
    final params = callback.queryParameters;

    final error = params['error'];
    if (error != null && error.isNotEmpty) {
      throw PlatformException(
        code: 'google_oauth_error',
        message: params['error_description'] ?? error,
      );
    }

    if (params['state'] != state) {
      throw PlatformException(
        code: 'google_oauth_error',
        message: 'OAuth state mismatch. Please try again.',
      );
    }

    final authCode = params['code'];
    if (authCode == null || authCode.isEmpty) {
      throw PlatformException(
        code: 'google_no_auth_code',
        message: 'Google sign-in completed but no authorization code was returned.',
      );
    }

    final tokenResponse = await http.post(
      Uri.parse(_tokenEndpoint),
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'code': authCode,
        'code_verifier': codeVerifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      },
    );

    if (tokenResponse.statusCode < 200 || tokenResponse.statusCode >= 300) {
      final body = tokenResponse.body;
      throw PlatformException(
        code: 'google_token_exchange_failed',
        message: body.isNotEmpty ? body : 'Failed to exchange Google auth code.',
      );
    }

    final tokenJson = jsonDecode(tokenResponse.body);
    if (tokenJson is! Map) {
      throw PlatformException(
        code: 'google_token_exchange_failed',
        message: 'Unexpected token response from Google.',
      );
    }

    final idToken = tokenJson['id_token']?.toString();
    if (idToken == null || idToken.isEmpty) {
      throw PlatformException(
        code: 'google_no_id_token',
        message: 'Google sign-in completed but no ID token was returned.',
      );
    }

    return GoogleBrowserSignInResult(
      idToken: idToken,
      email: _emailFromIdToken(idToken),
    );
  }

  static String _randomNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String _randomCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(64, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static String _codeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static String? _emailFromIdToken(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length < 2) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is Map && payload['email'] is String) {
        return payload['email'] as String;
      }
    } catch (_) {}
    return null;
  }
}
