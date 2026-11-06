import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bybata/core/config/env_config.dart';
import '../utils/network_utils.dart';
import 'package:flutter/foundation.dart';
import '../errors/error_handler.dart';
import '../utils/app_logger.dart';
import '../utils/ui_utils.dart';
import '../utils/app_messenger.dart';
import '../utils/client_device_info.dart';
import '../../features/wallet/services/wallet_security_service.dart';
import '../providers/auth_provider.dart';

class ApiClient {
  final Dio dio;
  final FlutterSecureStorage storage;

  // Prevent spamming the user with repeated "Session expired" messages when
  // multiple requests all fail with 401 after the session is gone.
  static bool _hasShownSessionExpired = false;

  /// Single-flight refresh shared across all [ApiClient] instances so parallel
  /// 401s don't rotate the refresh token twice and force a logout.
  static Future<Map<String, String>?>? _refreshInFlight;

  ApiClient(String baseUrl, this.storage)
      : dio = Dio(
          BaseOptions(
            // Priority for effective base URL:
            //   1. --dart-define=API_BASE_URL override (any mode)
            //   2. In profile/release: the provided baseUrl (prod by default)
            //   3. In debug with no override: local dev API (never hit prod
            //      accidentally from a dev machine)
            baseUrl: EnvConfig.hasOverride
                ? EnvConfig.overrideBaseUrl
                : baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
          ),
        ) {
    if (kDebugMode) {
      AppLogger.debug(
        '[API] ApiClient created. '
        'mode=${kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug')}, '
        'override=${EnvConfig.hasOverride ? EnvConfig.overrideBaseUrl : '(none)'}, '
        'effectiveBaseUrl=${dio.options.baseUrl}, '
        'requestedBaseUrl=$baseUrl',
      );
      dio.interceptors.add(
        _QuietPollLogInterceptor(
          logPrint: (log) => AppLogger.debug('[API] $log'),
        ),
      );
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final isAuth = _isAuthEndpoint(options.path);
          if (isAuth) {
            options.receiveTimeout = const Duration(seconds: 30);
            options.sendTimeout = const Duration(seconds: 30);
          }

          // Auth sign-in should reach the server quickly; skip slow DNS probe.
          if (!isAuth) {
            final hasInternet = await NetworkUtils.hasInternetConnection();
            if (!hasInternet) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                  error: const SocketException('No internet connection'),
                ),
              );
            }
          }

          // Ensure base URL reflects the active environment before each request.
          // Priority:
          //   1. --dart-define=API_BASE_URL override (any mode)
          //   2. In debug with no override: hard-lock to local dev API
          //   3. In profile/release: respect the stored value, falling back
          //      to the production default if the stored value is a local URL
          try {
            final prefs = await SharedPreferences.getInstance();
            if (EnvConfig.hasOverride) {
              final effective = EnvConfig.overrideBaseUrl;
              if (dio.options.baseUrl != effective) {
                dio.options.baseUrl = effective;
              }
              await prefs.setString('api_base_url', effective);
            } else if (kDebugMode) {
              final effective = await EnvConfig.getBaseUrl();
              if (dio.options.baseUrl != effective) {
                dio.options.baseUrl = effective;
              }
            } else {
              final storedBase = prefs.getString('api_base_url');
              if (storedBase != null && storedBase.isNotEmpty) {
                // In profile/release, treat local URLs as legacy and fall
                // back to the production default; otherwise respect stored.
                final effective = EnvConfig.isLocalUrl(storedBase)
                    ? EnvConfig.defaultBaseUrl
                    : storedBase;
                if (dio.options.baseUrl != effective) {
                  dio.options.baseUrl = effective;
                }
              }
            }
          } catch (_) {
            // Ignore base URL sync errors to avoid breaking requests
          }

          final token = await _readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            AppLogger.debug('[API] Warning: No access token found for request to ${options.path}');
          }

          options.headers.addAll(ClientDeviceInfo.headers());
          handler.next(options);
        },
        onResponse: (response, handler) {
          final status = response.statusCode ?? 0;

          // Any successful response means the session is currently valid,
          // so allow future "Session expired" messages again if they occur.
          if (status >= 200 && status < 400) {
            _hasShownSessionExpired = false;
          }

          if (status >= 400) {
            // For auth endpoints (login, register, verify, etc.), let the
            // calling screen handle errors locally instead of showing a
            // global snackbar like "Session expired". This avoids confusing
            // messages when, for example, the user enters a wrong OTP.
            if (_isAuthEndpoint(response.requestOptions.path)) {
              return handler.reject(
                DioException(
                  requestOptions: response.requestOptions,
                  response: response,
                  type: DioExceptionType.badResponse,
                ),
              );
            }

            final appException = ErrorHandler.toAppException(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );

            // Suppress global 404 toast for trade-detail lookups; the
            // TradeDetailsLoader screen handles the "not found" state
            // itself. This avoids showing "We couldn't find what you were
            // looking for" while the details screen is still loading.
            final path = response.requestOptions.path;
            final suppressGlobalError =
                (appException.statusCode == 404 && path.contains('/v1/trades/')) ||
                path.contains('receipt.pdf');

            if (!suppressGlobalError) {
              // Avoid spamming the same global "Session expired" toast if the
              // user is already being logged out and many requests are failing
              // with the same 401.
              final isSessionExpired401 =
                  appException.statusCode == 401 &&
                  appException.userMessage.startsWith('Session expired');

              if (isSessionExpired401) {
                if (!_hasShownSessionExpired) {
                  _hasShownSessionExpired = true;
                  UiUtils.handleError(appException);
                }
              } else {
                UiUtils.handleError(appException);
              }
            }

            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
                error: appException,
              ),
            );
          }
          handler.next(response);
        },
        onError: (e, handler) async {
          AppLogger.debug('[API ERROR] ${e.type}: ${e.message}');
          AppLogger.debug('[API ERROR] URL: ${e.requestOptions.uri}');

          // Extract backend message (if any) to detect verification-specific 401s
          final status = e.response?.statusCode;
          final data = e.response?.data;
          String? backendMessage;
          if (data is Map) {
            final msg = data['message'];
            if (msg is String) {
              backendMessage = msg;
            } else if (msg is Map && msg['message'] is String) {
              backendMessage = msg['message'] as String;
            }
          }
          final lowerMsg = (backendMessage ?? '').toLowerCase();
          // Business-rule 401s (wallet PIN / KYC / unlock) must NOT trigger
          // token refresh + forced logout — the JWT is still valid.
          final isBusinessAuth401 = status == 401 &&
              (lowerMsg.contains('verification') ||
                  lowerMsg.contains('invalid pin') ||
                  lowerMsg.contains('biometric') ||
                  lowerMsg.contains('wallet session') ||
                  lowerMsg.contains('unlock') ||
                  lowerMsg.contains('re-authenticate'));

          if (isBusinessAuth401) {
            final appException = ErrorHandler.toAppException(e);
            UiUtils.handleError(appException);
            return handler.reject(
              DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                type: e.type,
                error: appException,
              ),
            );
          }

          // Handle 401 with token refresh (skip if already trying to refresh)
          if (e.response?.statusCode == 401 &&
              !_isAuthEndpoint(e.requestOptions.path)) {
            // First check if user had any stored tokens - if not, they were never
            // logged in, so don't redirect to login (they're just browsing)
            final hadAccessToken = await _readAccessToken();
            final hadRefreshToken = await _readRefreshToken();
            final wasAuthenticated = hadAccessToken != null || hadRefreshToken != null;
            
            if (!wasAuthenticated) {
              // User was never logged in - just reject the error without redirecting
              AppLogger.debug('[API ERROR] 401 for unauthenticated user - not redirecting');
              // Don't call _forceLogout() - let the error propagate normally
            } else {
              AppLogger.debug('[API ERROR] 401 Unauthorized - attempting token refresh');
              final newTokens = await _refreshAndGetTokens();
              if (newTokens != null) {
                AppLogger.debug('[API ERROR] Token refresh successful, retrying request');
                final req = e.requestOptions;
                req.headers['Authorization'] = 'Bearer ${newTokens['access']}';
                try {
                  final clone = await dio.fetch(req);
                  return handler.resolve(clone);
                } catch (retryError) {
                  AppLogger.debug('[API ERROR] Retry failed: $retryError');
                  // Refresh worked but retry is still 401 → usually a business
                  // rule (PIN/KYC), not a dead session. Only force logout when
                  // the retry message looks like a real auth failure.
                  if (retryError is DioException &&
                      retryError.response?.statusCode == 401) {
                    final retryMsg = _backendMessageFrom(retryError.response?.data)
                            ?.toLowerCase() ??
                        '';
                    final looksLikeDeadSession = retryMsg.isEmpty ||
                        retryMsg.contains('unauthorized') ||
                        retryMsg.contains('jwt') ||
                        retryMsg.contains('token') ||
                        retryMsg.contains('invalid credentials');
                    if (looksLikeDeadSession &&
                        !retryMsg.contains('pin') &&
                        !retryMsg.contains('verification') &&
                        !retryMsg.contains('biometric') &&
                        !retryMsg.contains('wallet')) {
                      AppLogger.debug(
                        '[API ERROR] Token refresh did not resolve auth 401 - forcing logout',
                      );
                      await _forceLogout();
                    } else {
                      AppLogger.debug(
                        '[API ERROR] Post-refresh 401 is business/authz - keeping session',
                      );
                    }
                  }
                }
              } else {
                // Only force logout when refresh tokens were cleared (true
                // auth failure). Keep the session on transient refresh errors
                // (5xx / network) so users aren't kicked during API outages.
                final stillHasRefresh = await _readRefreshToken();
                if (stillHasRefresh == null) {
                  AppLogger.debug(
                    '[API ERROR] Token refresh failed permanently - forcing logout',
                  );
                  await _forceLogout();
                } else {
                  AppLogger.debug(
                    '[API ERROR] Token refresh failed transiently - keeping session',
                  );
                }
              }
            }
          }

          // Handle 429 Rate Limit - add retry-after information to response
          if (e.response?.statusCode == 429) {
            AppLogger.debug('[API ERROR] 429 Rate limit exceeded');
            // Check for retry-after headers (both standard and custom short version)
            final retryAfter = e.response?.headers.value('retry-after') ??
                e.response?.headers.value('retry-after-short');
            if (retryAfter != null) {
              AppLogger.debug('[API ERROR] Retry after: $retryAfter seconds');
              // Add retry-after to response data for frontend handling
              if (e.response?.data is Map) {
                (e.response!.data as Map)['retryAfter'] = int.tryParse(retryAfter);
              }
            }
          }

          final appException = ErrorHandler.toAppException(e);

          // Suppress global 404 toast for trade-detail lookups; the
          // TradeDetailsLoader screen handles the "not found" state
          // itself.
          final path = e.requestOptions.path;
          final suppressGlobalError =
              appException.statusCode == 404 && path.contains('/v1/trades/');
          
          // Also suppress 401 errors for unauthenticated users browsing public content
          final accessToken = await _readAccessToken();
          final isUnauthenticatedBrowsing = accessToken == null && appException.statusCode == 401;

          if (!suppressGlobalError && !isUnauthenticatedBrowsing) {
            // Avoid spamming the same global "Session expired" toast when many
            // requests fail after the session is gone. We treat the first one as
            // the primary notification and suppress subsequent duplicates until a
            // successful authenticated call happens.
            final isSessionExpired401 =
                appException.statusCode == 401 &&
                appException.userMessage.startsWith('Session expired');

            if (isSessionExpired401) {
              if (!_hasShownSessionExpired) {
                _hasShownSessionExpired = true;
                UiUtils.handleError(appException);
              }
            } else {
              UiUtils.handleError(appException);
            }
          }

          handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              response: e.response,
              type: e.type,
              error: appException,
            ),
          );
        },
      ),
    );
  }

  bool _isAuthEndpoint(String path) {
    return path.contains('/v1/auth/login') ||
        path.contains('/v1/auth/google') ||
        path.contains('/v1/auth/apple') ||
        path.contains('/v1/auth/register') ||
        path.contains('/v1/auth/forgot') ||
        path.contains('/v1/auth/reset') ||
        path.contains('/v1/auth/verify') ||
        path.contains('/v1/auth/refresh');
  }

  static String? _backendMessageFrom(dynamic data) {
    if (data is Map) {
      final msg = data['message'];
      if (msg is String) return msg;
      if (msg is Map && msg['message'] is String) return msg['message'] as String;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
    }
    return null;
  }
  
  /// Returns true for public listing endpoints that can be accessed without auth
  bool _isPublicListEndpoint(String path) {
    // These endpoints are used for browsing without authentication
    return (path == '/v1/trades' || path.startsWith('/v1/trades?')) ||
        (path == '/v1/gifts' || path.startsWith('/v1/gifts?')) ||
        (path == '/v1/campaigns' || path.startsWith('/v1/campaigns?')) ||
        (path == '/v1/communities' || path.startsWith('/v1/communities?')) ||
        path.contains('/v1/public/browse') ||
        path.contains('/v1/ads/') ||
        path.contains('/v1/search');
  }

  Future<String?> _readAccessToken() async {
    try {
      final token = await storage.read(key: 'access');
      if (token != null) return token;
    } on PlatformException catch (_) {
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<String?> _readRefreshToken() async {
    try {
      final token = await storage.read(key: 'refresh');
      if (token != null) return token;
    } on PlatformException catch (_) {
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<void> _writeAccessToken(String value) async {
    try {
      await storage.write(key: 'access', value: value);
    } on PlatformException catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', value);
  }

  Future<void> _writeRefreshToken(String value) async {
    try {
      await storage.write(key: 'refresh', value: value);
    } on PlatformException catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('refresh_token', value);
  }

  Future<void> _clearTokens() async {
    try {
      await storage.delete(key: 'access');
    } on PlatformException catch (_) {}
    try {
      await storage.delete(key: 'refresh');
    } on PlatformException catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }

  Future<void> _forceLogout() async {
    await _clearTokens();
    try {
      await WalletSecurityService().switchUser(null);
    } catch (_) {}
    final ctx = appNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        await Provider.of<AuthProvider>(ctx, listen: false).clearLocalSession();
      } catch (_) {}
    }
    appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  Future<Map<String, String>?> _refreshAndGetTokens() async {
    // Coalesce concurrent refreshes across all ApiClient instances.
    if (_refreshInFlight != null) {
      return _refreshInFlight;
    }
    _refreshInFlight = _refreshAndGetTokensInternal().whenComplete(() {
      _refreshInFlight = null;
    });
    return _refreshInFlight;
  }

  Future<Map<String, String>?> _refreshAndGetTokensInternal() async {
    final refresh = await _readRefreshToken();
    if (refresh == null) {
      AppLogger.debug('[API] No refresh token available for token refresh');
      return null;
    }
    try {
      AppLogger.debug('[API] Attempting to refresh access token...');
      // Create a new Dio instance without interceptors to avoid infinite loop
      final refreshDio = Dio(BaseOptions(
        baseUrl: dio.options.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ));

      final res = await refreshDio.post(
        '/v1/auth/refresh',
        data: {'refreshToken': refresh},
      );

      final access = res.data['accessToken'] as String?;
      final newRefresh = res.data['refreshToken'] as String?;

      if (access != null) {
        await _writeAccessToken(access);
        AppLogger.debug('[API] Access token refreshed successfully');
      } else {
        AppLogger.debug('[API] Warning: No access token in refresh response');
      }

      if (newRefresh != null) {
        await _writeRefreshToken(newRefresh);
        AppLogger.debug('[API] Refresh token updated');
      }

      if (access != null && newRefresh != null) {
        return {
          'access': access,
          'refresh': newRefresh,
        };
      }

      AppLogger.debug('[API] Token refresh incomplete - missing tokens in response');
      return null;
    } catch (e) {
      AppLogger.debug('[API] Token refresh failed: $e');
      final status = e is DioException ? e.response?.statusCode : null;
      // Only wipe credentials on definitive auth rejection. Keep tokens on
      // 5xx / timeouts so a temporary API outage doesn't log everyone out.
      if (status == 401 || status == 403) {
        await _clearTokens();
      }
      return null;
    }
  }

  // Deprecated method for backward compatibility
  Future<bool> _refresh() async {
    final tokens = await _refreshAndGetTokens();
    return tokens != null;
  }

  // HTTP Methods
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return dio.put(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return dio.delete(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return dio.patch(path, data: data, queryParameters: queryParameters);
  }
}

/// Skips verbose [LogInterceptor] lines for unread-count polling (debug log noise).
class _QuietPollLogInterceptor extends LogInterceptor {
  _QuietPollLogInterceptor({
    required void Function(Object object) logPrint,
  }) : super(
          requestBody: true,
          responseBody: true,
          error: true,
          logPrint: logPrint,
        );

  static bool _isQuietPollUri(Uri uri) =>
      uri.path.contains('notifications/unread-count');

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (_isQuietPollUri(options.uri)) {
      handler.next(options);
      return;
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_isQuietPollUri(response.requestOptions.uri)) {
      handler.next(response);
      return;
    }
    super.onResponse(response, handler);
  }
}
