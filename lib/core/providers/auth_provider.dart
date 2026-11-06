import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/app_models.dart';
import '../config/env_config.dart';
import '../api/api_client.dart';
import '../../features/auth/repository/auth_repository.dart';
import '../../features/auth/utils/auth_errors.dart';
import '../../features/profile/repository/profile_repository.dart';
import '../../features/notifications/services/push_notifications_service.dart';
import '../../features/wallet/services/wallet_security_service.dart';
import '../models/locale_hints.dart';
import '../services/signup_location_service.dart';
import '../services/user_currency_service.dart';
import '../auth/google_browser_sign_in.dart';
import '../utils/network_utils.dart';

class AuthProvider extends ChangeNotifier {
  static const String _userDataKey = 'user_data';
  static const String _authTokenKey = 'auth_token';
  static const String _lastLoginKey = 'last_login_identifier';
  static const String _pendingVerificationKey = 'pending_verification_email';
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  AuthStatus _status = AuthStatus.loading;
  AppUser? _currentUser;
  String? _authToken;
  String? _errorMessage;
  String? _pendingVerificationEmail;
  SharedPreferences? _prefs;

  // Getters
  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  String? get authToken => _authToken;
  String? get errorMessage => _errorMessage;
  String? get pendingVerificationEmail => _pendingVerificationEmail;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _currentUser != null;
  bool get isLoading => _status == AuthStatus.loading;
  bool get hasCachedSession {
    final userData = _prefs?.getString(_userDataKey);
    final token = _prefs?.getString(_authTokenKey);
    return userData != null &&
        userData.isNotEmpty &&
        token != null &&
        token.isNotEmpty;
  }

  static const Duration _startupInitTimeout = Duration(seconds: 8);
  static const Duration _secureStorageTimeout = Duration(seconds: 2);

  // Initialize auth provider
  Future<void> initializeAuth({bool isRetry = false}) async {
    if (isRetry) {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      await _initializeAuthCore().timeout(
        _startupInitTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Auth initialization timed out',
            _startupInitTimeout,
          );
        },
      );
    } catch (e) {
      await _completeInitWithOfflineFallback(e);
    }
  }

  Future<void> retryInitializeAuth() => initializeAuth(isRetry: true);

  /// Skip remaining network work and use locally stored credentials, if any.
  Future<void> forceOfflineStartup() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _loadStoredUser(skipBackendSync: true);
      if (_status == AuthStatus.loading) {
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    } catch (_) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> _initializeAuthCore() async {
    _prefs = await SharedPreferences.getInstance();
    _pendingVerificationEmail = _prefs?.getString(_pendingVerificationKey);
    // try tokens from secure storage and fetch /me
    final access = await _safeRead('access');
    final refresh = await _safeRead('refresh');
    if (access != null || refresh != null) {
      final online = await NetworkUtils.hasInternetConnection();
      if (online) {
        try {
          // Try to authenticate with stored tokens
          await _tryAuthenticateWithAPI().timeout(
            const Duration(seconds: 4),
            onTimeout: () {
              throw TimeoutException(
                'API authentication timed out',
                const Duration(seconds: 4),
              );
            },
          );
          if (_status == AuthStatus.authenticated) {
            return;
          }
        } catch (e) {
          final shouldClear = e is DioException &&
              (e.response?.statusCode == 401 || e.response?.statusCode == 403);
          if (shouldClear) {
            if (e is DioException) {
              final data = e.response?.data;
              final message = data is Map && data['message'] is String
                  ? data['message'] as String
                  : e.message;
              final messageMap = data is Map && data['message'] is Map
                  ? Map<String, dynamic>.from(data['message'] as Map)
                  : null;
              final verificationMessage =
                  messageMap?['message'] as String? ?? message;
              if (verificationMessage != null &&
                  verificationMessage.toLowerCase().contains('verification')) {
                final last = _prefs?.getString(_lastLoginKey);
                if (last != null && last.isNotEmpty) {
                  await setPendingVerificationEmail(last);
                }
              }
            }
            await _safeDelete('access');
            await _safeDelete('refresh');
            await _prefs?.remove('auth_token');
            await _prefs?.remove('refresh_token');
          }
          // fallthrough to offline/cached session
        }
      }
    }
    await _loadStoredUser();
  }

  Future<void> _completeInitWithOfflineFallback(Object? cause) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _loadStoredUser(skipBackendSync: true);
      if (_status != AuthStatus.loading) return;
    } catch (_) {}
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }
  
  // Helper method for API authentication
  Future<void> _tryAuthenticateWithAPI({bool deferHeavySync = true}) async {
    final base = await EnvConfig.getBaseUrl();
    final client = ApiClient(base, _secure);
    final me = await ProfileRepository(client.dio).me(light: true);
    _currentUser = _mapMeToAppUser(me);
    
    // Retrieve and set the auth token
    final accessToken = await _safeRead('access');
    if (accessToken != null) {
      _authToken = accessToken;
    } else {
      // Fallback to SharedPreferences
      final token = _prefs?.getString('auth_token');
      if (token != null) {
        _authToken = token;
      }
    }
    
    _status = AuthStatus.authenticated;
    if (deferHeavySync) {
      unawaited(_bindWalletSecurityForCurrentUser());
      unawaited(_syncCurrencyFromMe(me));
    } else {
      await _bindWalletSecurityForCurrentUser();
      await _syncCurrencyFromMe(me);
    }
    notifyListeners();
  }

  Future<void> _syncCurrencyFromMe(Map<String, dynamic> me) async {
    final profile = me['profile'];
    if (profile is Map) {
      await UserCurrencyService.instance.applyFromProfile(Map<String, dynamic>.from(profile));
    }
    await UserCurrencyService.instance.ensureConfiguredFromDevice();
  }

  // Load stored user data
  Future<void> _loadStoredUser({bool skipBackendSync = false}) async {
    try {
      final userData = _prefs?.getString(_userDataKey);
      final token = _prefs?.getString(_authTokenKey);

      if (userData != null && token != null) {
        final parsed = jsonDecode(userData);
        if (parsed is Map) {
          _currentUser = AppUser.fromJson(Map<String, dynamic>.from(parsed));
        }
        _authToken = token;
        _status = AuthStatus.authenticated;
        if (skipBackendSync) {
          unawaited(WalletSecurityService().switchUser(_currentUser?.id));
        } else {
          await _bindWalletSecurityForCurrentUser();
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Failed to load user data';
    }
    notifyListeners();
  }

  Future<void> _bindWalletSecurityForCurrentUser({bool syncWithBackend = true}) async {
    await WalletSecurityService().switchUser(_currentUser?.id);
    if (syncWithBackend && _currentUser?.id != null) {
      unawaited(WalletSecurityService().syncPinStateWithBackend());
    }
  }

  // Save user data to storage
  Future<void> _saveUserData() async {
    if (_currentUser != null && _authToken != null) {
      await _prefs?.setString(_userDataKey, jsonEncode(_currentUser!.toJson()));
      await _prefs?.setString(_authTokenKey, _authToken!);
    }
  }

  // Clear stored user data
  Future<void> _clearUserData() async {
    await _prefs?.remove(_userDataKey);
    await _prefs?.remove(_authTokenKey);
  }

  // Sign in with email and password
  Future<bool> signInWithEmailPassword(String email, String password) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      _pendingVerificationEmail = null;
      notifyListeners();

      await _prefs?.setString(_lastLoginKey, email);
      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, _secure);
      final auth = AuthRepository(client.dio, client.storage);
      final loginData = await auth.login(email: email, password: password);

      // Retrieve the stored token after login
      final accessToken = await _safeRead('access');
      if (accessToken != null) {
        _authToken = accessToken;
      } else {
        // Fallback to SharedPreferences
        final token = _prefs?.getString('auth_token');
        if (token != null) {
          _authToken = token;
        }
      }

      // Prefer /me, but don't fail login if enrichment endpoints are down —
      // tokens are already stored and login already returned a user object.
      Map<String, dynamic> me;
      try {
        me = await ProfileRepository(client.dio).me(light: true);
      } catch (e) {
        final user = loginData['user'];
        if (user is Map) {
          me = Map<String, dynamic>.from(user);
        } else {
          rethrow;
        }
      }
      _currentUser = _mapMeToAppUser(me);
      _status = AuthStatus.authenticated;
      
      // Save the current user data
      await _saveUserData();
      await _bindWalletSecurityForCurrentUser();
      await _syncCurrencyFromMe(me);
      await PushNotificationsService.syncTokenWithServer();
      notifyListeners();
      return true;
    } catch (e) {
      // Translate common auth failures into plain-English messages so
      // users know what to do, especially in production.
      if (e is DioException) {
        final status = e.response?.statusCode;
        final data = e.response?.data;

        if (e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          _status = AuthStatus.unauthenticated;
          _errorMessage =
              'Connection timed out. Check your network and try again.';
          notifyListeners();
          return false;
        }

        // Dedicated handling for "email verification required" flows.
        if (data is Map &&
            ((data['code'] == 'EMAIL_VERIFICATION_REQUIRED') ||
             (data['message'] is Map && (data['message'] as Map)['code'] == 'EMAIL_VERIFICATION_REQUIRED'))) {
          final messageData = data['message'];
          final emailFromResponse = (data['email'] as String?) ??
              (messageData is Map ? messageData['email'] as String? : null);
          await setPendingVerificationEmail(emailFromResponse ?? email);
          _errorMessage = 'Email verification required. Please check your email for the code.';
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          return false;
        }

        // Friendly message for invalid credentials (401/400).
        if (status == 401 || status == 400) {
          _status = AuthStatus.unauthenticated;
          _errorMessage = 'Incorrect email or password. Please double-check your details or reset your password.';
          notifyListeners();
          return false;
        }

        // For other API errors, use production-safe messaging.
        _status = AuthStatus.unauthenticated;
        _errorMessage = AuthErrors.login(e);
        notifyListeners();
        return false;
      }

      // Non-HTTP errors: keep message simple in production.
      _status = AuthStatus.unauthenticated;
      _errorMessage = AuthErrors.login(e);
      notifyListeners();
      return false;
    }
  }

  void clearPendingVerification() {
    _pendingVerificationEmail = null;
    _prefs?.remove(_pendingVerificationKey);
  }

  Future<void> setPendingVerificationEmail(String email) async {
    _pendingVerificationEmail = email;
    await _prefs?.setString(_pendingVerificationKey, email);
  }

  Future<void> resendVerification(String email) async {
    final base = await EnvConfig.getBaseUrl();
    final client = ApiClient(base, _secure);
    await AuthRepository(client.dio, client.storage).requestEmailVerification(email);
  }

  // Sign up with email and password
  Future<bool> signUpWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
    required String username,
    String? phoneNumber,
    String? referralCode,
    LocaleHints? localeHints,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, _secure);
      final auth = AuthRepository(client.dio, _secure);
      final baseHints = localeHints ?? UserCurrencyService.instance.deviceLocaleHints();
      final signupLocation = await SignupLocationService.resolveForRegistration(
        countryCode: baseHints.countryCode,
      );
      final hints = LocaleHints(
        countryCode: baseHints.countryCode,
        preferredFiatCurrency: baseHints.preferredFiatCurrency,
        timezone: baseHints.timezone,
        location: signupLocation,
      );
      final data = await auth.register(
        email: email,
        password: password,
        displayName: displayName,
        username: username,
        referralCode: referralCode,
        localeHints: hints,
      );

      await _prefs?.setString(_lastLoginKey, email);
      final accessToken = await _safeRead('access');
      if (accessToken != null) {
        _authToken = accessToken;
      }
      if (data['user'] is Map) {
        final userMap = Map<String, dynamic>.from(data['user'] as Map);
        _currentUser = _mapMeToAppUser(userMap);
        final profile = userMap['profile'];
        if (profile is Map) {
          await UserCurrencyService.instance.applyFromProfile(Map<String, dynamic>.from(profile));
        }
      }
      _status = AuthStatus.authenticated;
      await setPendingVerificationEmail(email);
      await _saveUserData();
      await _bindWalletSecurityForCurrentUser();
      // Do NOT register device token yet; notifications endpoints require
      // verified email. We will sync the push token after successful
      // email verification or on the next login.
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = AuthErrors.signUp(e);
      notifyListeners();
      return false;
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      String? idToken;
      String? googleEmail;

      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android: browser OAuth (Chrome Custom Tab) — same UX as iOS Safari
        // sheet, without Play Services / SHA-1 requirements.
        final browserResult = await GoogleBrowserSignIn.signIn();
        if (browserResult == null) {
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          return false;
        }
        idToken = browserResult.idToken;
        googleEmail = browserResult.email;
      } else {
        final googleSignIn = GoogleSignIn(
          scopes: ['email'],
          clientId: defaultTargetPlatform == TargetPlatform.iOS &&
                  EnvConfig.googleIosClientId.isNotEmpty
              ? EnvConfig.googleIosClientId
              : null,
          serverClientId: EnvConfig.googleWebClientId.isNotEmpty
              ? EnvConfig.googleWebClientId
              : null,
        );
        final account = await googleSignIn.signIn();
        if (account == null) {
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          return false;
        }
        final auth = await account.authentication;
        idToken = auth.idToken;
        googleEmail = account.email;
      }

      if (idToken == null) {
        _status = AuthStatus.unauthenticated;
        _errorMessage =
            'We couldn\'t complete Google sign-in. Please try again or use email instead.';
        notifyListeners();
        return false;
      }

      if (googleEmail != null && googleEmail.isNotEmpty) {
        await _prefs?.setString(_lastLoginKey, googleEmail);
      }
      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, _secure);
      final baseHints = UserCurrencyService.instance.deviceLocaleHints();
      final signupLocation = await SignupLocationService.resolveForRegistration(
        countryCode: baseHints.countryCode,
      );
      final hints = LocaleHints(
        countryCode: baseHints.countryCode,
        preferredFiatCurrency: baseHints.preferredFiatCurrency,
        timezone: baseHints.timezone,
        location: signupLocation,
      );
      final loginData = await AuthRepository(client.dio, client.storage)
          .loginWithGoogle(
        idToken: idToken,
        localeHints: hints,
      );

      final accessToken = await _safeRead('access');
      if (accessToken != null) {
        _authToken = accessToken;
      }
      Map<String, dynamic> me;
      try {
        me = await ProfileRepository(client.dio).me(light: true);
      } catch (_) {
        final user = loginData['user'];
        if (user is Map) {
          me = Map<String, dynamic>.from(user);
        } else {
          rethrow;
        }
      }
      _currentUser = _mapMeToAppUser(me);
      _status = AuthStatus.authenticated;
      clearPendingVerification();
      await _saveUserData();
      await _bindWalletSecurityForCurrentUser();
      await _syncCurrencyFromMe(me);
      await PushNotificationsService.syncTokenWithServer();
      notifyListeners();
      return true;
    } catch (e, st) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = AuthErrors.googleSignIn(e);
      if (kDebugMode) {
        // ignore: avoid_print
        print('[Auth] Google sign-in error: $e\n$st');
      }
      notifyListeners();
      return false;
    }
  }

  // Sign in with Apple
  Future<bool> signInWithApple() async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final identityToken = credential.identityToken;
      if (identityToken == null) {
        _status = AuthStatus.unauthenticated;
        _errorMessage =
            'We couldn\'t complete Apple sign-in. Please try again or use email instead.';
        notifyListeners();
        return false;
      }

      final email =
          credential.email ?? _emailFromAppleIdentityToken(identityToken);
      final displayName = [
        credential.givenName,
        credential.familyName,
      ].where((part) => part != null && part!.isNotEmpty).map((part) => part!).join(' ');
      if (email != null) {
        await _prefs?.setString(_lastLoginKey, email);
      }

      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, _secure);
      final baseHints = UserCurrencyService.instance.deviceLocaleHints();
      final signupLocation = await SignupLocationService.resolveForRegistration(
        countryCode: baseHints.countryCode,
      );
      final hints = LocaleHints(
        countryCode: baseHints.countryCode,
        preferredFiatCurrency: baseHints.preferredFiatCurrency,
        timezone: baseHints.timezone,
        location: signupLocation,
      );
      final loginData = await AuthRepository(client.dio, client.storage)
          .loginWithApple(
        identityToken: identityToken,
        email: email,
        displayName: displayName.isNotEmpty ? displayName : null,
        localeHints: hints,
      );

      final accessToken = await _safeRead('access');
      if (accessToken != null) {
        _authToken = accessToken;
      }
      Map<String, dynamic> me;
      try {
        me = await ProfileRepository(client.dio).me(light: true);
      } catch (_) {
        final user = loginData['user'];
        if (user is Map) {
          me = Map<String, dynamic>.from(user);
        } else {
          rethrow;
        }
      }
      _currentUser = _mapMeToAppUser(me);
      _status = AuthStatus.authenticated;
      clearPendingVerification();
      await _saveUserData();
      await _bindWalletSecurityForCurrentUser();
      await _syncCurrencyFromMe(me);
      await PushNotificationsService.syncTokenWithServer();
      notifyListeners();
      return true;
    } catch (e, st) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = AuthErrors.appleSignIn(e);
      if (kDebugMode) {
        // ignore: avoid_print
        print('[Auth] Apple sign-in error: $e\n$st');
      }
      notifyListeners();
      return false;
    }
  }

  /// Apple only returns [AuthorizationCredentialAppleID.email] on first sign-in;
  /// the identity token may still contain an email claim afterward.
  static String? _emailFromAppleIdentityToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = jsonDecode(utf8.decode(base64Decode(payload)));
      if (decoded is! Map) return null;
      final email = decoded['email'];
      return email is String && email.isNotEmpty ? email : null;
    } catch (_) {
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _status = AuthStatus.loading;
      notifyListeners();

      await PushNotificationsService.unregisterTokenFromServer();
      await PushNotificationsService.clearLocalNotifications();

      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, _secure);
      final me = _currentUser;
      if (me != null) {
        try {
          await AuthRepository(client.dio, _secure).logout(me.id);
        } catch (_) {}
      }

      await clearLocalSession();
    } catch (e) {
      await clearLocalSession();
      _errorMessage = 'Failed to sign out';
      notifyListeners();
    }
  }

  /// Clears in-memory auth state and local tokens (session expiry / force logout).
  Future<void> clearLocalSession() async {
    _currentUser = null;
    _authToken = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;

    await _safeDelete('access');
    await _safeDelete('refresh');
    await _clearUserData();
    try {
      await WalletSecurityService().switchUser(null);
    } catch (_) {}
    notifyListeners();
  }

  // Update user profile
  Future<bool> updateUserProfile({
    String? displayName,
    String? bio,
    String? location,
    String? photoUrl,
    String? coverImageUrl,
    String? phoneNumber,
  }) async {
    if (_currentUser == null) return false;

    try {
      _errorMessage = null;

      // TODO: Implement profile update API call
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call

      _currentUser = _currentUser!.copyWith(
        displayName: displayName ?? _currentUser!.displayName,
        bio: bio ?? _currentUser!.bio,
        location: location ?? _currentUser!.location,
        photoUrl: photoUrl ?? _currentUser!.photoUrl,
        coverImageUrl: coverImageUrl ?? _currentUser!.coverImageUrl,
        phoneNumber: phoneNumber ?? _currentUser!.phoneNumber,
        lastSeen: DateTime.now(),
      );

      await _saveUserData();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update profile: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Update user preferences
  Future<bool> updateUserPreferences(Map<String, dynamic> preferences) async {
    if (_currentUser == null) return false;

    try {
      _errorMessage = null;

      // TODO: Implement preferences update API call
      await Future.delayed(const Duration(milliseconds: 500));

      _currentUser = _currentUser!.copyWith(
        preferences: preferences,
        lastSeen: DateTime.now(),
      );

      await _saveUserData();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update preferences: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      _errorMessage = null;

      // TODO: Implement password reset API call
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to reset password: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Verify email
  Future<bool> verifyEmail(String verificationCode) async {
    if (_currentUser == null) return false;

    try {
      _errorMessage = null;

      // TODO: Implement email verification API call
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call

      _currentUser = _currentUser!.copyWith(
        isEmailVerified: true,
        lastSeen: DateTime.now(),
      );

      await _saveUserData();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to verify email: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Update online status
  Future<void> updateOnlineStatus(bool isOnline) async {
    if (_currentUser == null) return;

    _currentUser = _currentUser!.copyWith(
      isOnline: isOnline,
      lastSeen: DateTime.now(),
    );

    await _saveUserData();
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Safe wrappers around secure storage to avoid unhandled PlatformExceptions (e.g., iOS -34018)
  Future<String?> _safeRead(String key) async {
    try {
      return await _secure
          .read(key: key)
          .timeout(_secureStorageTimeout, onTimeout: () => null);
    } on PlatformException catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('SecureStorage read failed for "$key": ${e.code} ${e.message}');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _safeDelete(String key) async {
    try {
      await _secure.delete(key: key);
    } on PlatformException catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('SecureStorage delete failed for "$key": ${e.code} ${e.message}');
      }
    } catch (_) {}
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    if (_currentUser == null) return;
    try {
      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, _secure);
      final me = await ProfileRepository(client.dio).me(fresh: true); // full profile, bypass me-cache
      _currentUser = _mapMeToAppUser(me);
      await _saveUserData();
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Failed to refresh user data';
      notifyListeners();
    }
  }

  // Delete account
  Future<bool> deleteAccount() async {
    if (_currentUser == null) return false;

    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      // TODO: Implement delete account API call
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      _currentUser = null;
      _authToken = null;
      _status = AuthStatus.unauthenticated;

      await _clearUserData();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete account: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  AppUser _mapMeToAppUser(Map<String, dynamic> me) {
    final profile = (me['profile'] as Map?) ?? {};
    // KYC verification (kycStatus == VERIFIED) = identity verified badge
    final kycStatus = profile['kycStatus']?.toString().toUpperCase();
    final isKycVerified = kycStatus == 'VERIFIED';
    // Email verification (emailVerifiedAt) = post-signup login gate
    final isEmailVerified = me['emailVerifiedAt'] != null;
    return AppUser(
      id: me['id']?.toString() ?? '',
      email: me['email']?.toString() ?? '',
      displayName: profile['displayName']?.toString() ?? me['email']?.toString() ?? '',
      photoUrl: profile['avatarKey'] != null ? profile['avatarKey'].toString() : null,
      createdAt: DateTime.now(),
      lastSeen: DateTime.now(),
      isVerified: isKycVerified,
      isEmailVerified: isEmailVerified,
      karmaPoints: 0,
      rating: 0,
      followersCount: 0,
      followingCount: 0,
      badges: const [],
    );
  }
}
