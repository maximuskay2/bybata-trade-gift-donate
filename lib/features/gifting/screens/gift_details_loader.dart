import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/utils/app_logger.dart';
import '../api/gift_api.dart';
import 'gift_details_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import '../../../core/utils/media_file_cache.dart';
import '../../../core/utils/listing_video_handoff.dart';

/// Loads gift details by calling [GiftApi.getGift] DIRECTLY (bypassing
/// [GiftProvider.getGift], which silently catches and returns null and
/// hides the real failure cause).
///
/// On failure:
/// - Captures error + stacktrace and forwards to Crashlytics via [AppLogger.logError]
///   so it can be inspected in release.
/// - Renders a friendly error state. Technical details are debug-only.
class GiftDetailsLoader extends StatefulWidget {
  final String giftId;
  const GiftDetailsLoader({super.key, required this.giftId});

  @override
  State<GiftDetailsLoader> createState() => _GiftDetailsLoaderState();
}

class _GiftDetailsLoaderState extends State<GiftDetailsLoader> {
  Map<String, dynamic>? _gift;
  String? _errorMessage;
  Object? _errorObject;
  StackTrace? _errorStack;
  int? _httpStatus;
  String? _responseBody;
  String? _requestPath;
  bool _showDetails = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGift();
  }

  Future<void> _fetchGift() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _errorObject = null;
      _errorStack = null;
      _httpStatus = null;
      _responseBody = null;
      _requestPath = null;
      _showDetails = false;
    });

    Map<String, dynamic>? data;
    try {
      // Build a fresh ApiClient so we use the live base URL and the same
      // dio interceptor stack the rest of the app uses (auth header, etc.).
      final baseUrl = await EnvConfig.getBaseUrl();
      const storage = FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);
      final api = GiftApi(apiClient);

      data = await api.getGift(widget.giftId);
    } on DioException catch (e, s) {
      _httpStatus = e.response?.statusCode;
      _responseBody = _safeStringify(e.response?.data);
      _requestPath = e.requestOptions.uri.toString();
      _errorObject = e;
      _errorStack = s;
      _errorMessage = _friendlyDioMessage(e);
      await AppLogger.logError(
        e,
        s,
        hint: 'GiftDetailsLoader.getGift id=${widget.giftId} '
            'status=$_httpStatus path=$_requestPath',
      );
    } catch (e, s) {
      _errorObject = e;
      _errorStack = s;
      _errorMessage = 'Failed to load gift details';
      await AppLogger.logError(
        e,
        s,
        hint: 'GiftDetailsLoader.getGift id=${widget.giftId}',
      );
    }

    if (!mounted) return;

    if (_errorMessage != null) {
      ListingVideoHandoff.releaseUnclaimed();
      setState(() => _isLoading = false);
      return;
    }

    if (data == null) {
      ListingVideoHandoff.releaseUnclaimed();
      setState(() {
        _errorMessage = 'Gift not found';
        _isLoading = false;
      });
      return;
    }

    final normalized = _normalize(data!);
    ListingVideoPrefetch.warmListingMedia(
      videoKey: normalized['videoKey']?.toString(),
      thumbnailKey: normalized['thumbnailKey']?.toString(),
    );
    setState(() {
      _gift = normalized;
      _isLoading = false;
    });
  }

  /// Pass the raw API JSON straight through. The details screen already
  /// reads the canonical fields (title, description, mediaKeys, giver, etc.)
  /// and is more resilient than the previous Gift-model round-trip.
  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    final giver = raw['giver'];
    String giverName = 'Unknown';
    String? giverId;
    String? giverAvatarKey;
    if (giver is Map) {
      giverName = (giver['name'] ?? giver['username'] ?? 'Unknown').toString();
      giverId = giver['id']?.toString();
      final profile = giver['profile'];
      if (profile is Map) {
        giverAvatarKey =
            (profile['profileImageUrl'] ?? profile['avatarKey'])?.toString();
      }
      giverAvatarKey ??=
          (giver['profileImageUrl'] ?? giver['avatarKey'])?.toString();
    }

    return {
      'id': raw['id'],
      'title': raw['title'],
      'description': raw['description'],
      'giver': giverName,
      'giverId': giverId,
      'giverAvatarKey': giverAvatarKey,
      'karma': raw['karmaReward'],
      'location': raw['location'],
      'tags': raw['tags'] ?? [],
      'type': raw['type'],
      'category': raw['category'],
      'expires': raw['expiresAt'],
      'claimed': raw['status'] == 'CLAIMED',
      'mediaKeys': raw['mediaKeys'] ?? [],
      'mediaType': raw['mediaType']?.toString(),
      'videoKey': raw['videoKey']?.toString(),
      'thumbnailKey': raw['thumbnailKey']?.toString(),
      // Pass the entire raw payload too so the details screen can read
      // anything the normalized projection misses.
      '__raw': raw,
    };
  }

  String _friendlyDioMessage(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      return 'You don\'t have permission to view this gift';
    }
    if (status == 404) {
      return 'Gift not found';
    }
    if (status != null && status >= 500) {
      return 'Server error ($status). Please try again.';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Network timeout. Check your connection.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Cannot reach the server. Check your connection.';
    }
    return 'Failed to load gift details';
  }

  String _safeStringify(Object? value) {
    if (value == null) return '';
    try {
      return value.toString();
    } catch (_) {
      return '<unprintable>';
    }
  }

  String _buildDiagnosticBlock() {
    final buffer = StringBuffer();
    buffer.writeln('giftId: ${widget.giftId}');
    if (_requestPath != null) buffer.writeln('path: $_requestPath');
    if (_httpStatus != null) buffer.writeln('status: $_httpStatus');
    if (_responseBody != null && _responseBody!.isNotEmpty) {
      buffer.writeln('body: $_responseBody');
    }
    buffer.writeln('error: $_errorObject');
    if (_errorStack != null) {
      buffer.writeln('---stack---');
      buffer.writeln(_errorStack);
    }
    return buffer.toString();
  }

  Future<void> _copyDiagnostics() async {
    await Clipboard.setData(ClipboardData(text: _buildDiagnosticBlock()));
    if (!mounted) return;
    AppToast.show(context, 'Diagnostics copied to clipboard');
  }

  @override
  void dispose() {
    ListingVideoHandoff.onDetailRouteClosed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: BybataLoader());
    }
    if (_errorMessage != null) {
      return _buildErrorScaffold();
    }
    return GiftDetailsScreen(gift: _gift!);
  }

  Widget _buildErrorScaffold() {
    final theme = Theme.of(context);
    final showDetails = kDebugMode && _showDetails;
    return Scaffold(
      appBar: AppBar(title: const Text('Gift Details')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Something went wrong',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (_httpStatus != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'HTTP $_httpStatus',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _fetchGift,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    if (kDebugMode) ...[
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _showDetails = !_showDetails),
                        icon: Icon(
                          _showDetails ? Icons.visibility_off : Icons.bug_report,
                        ),
                        label: Text(_showDetails ? 'Hide details' : 'Details'),
                      ),
                      if (showDetails)
                        OutlinedButton.icon(
                          onPressed: _copyDiagnostics,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy'),
                        ),
                    ],
                  ],
                ),
                if (showDetails) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: SelectableText(
                      _buildDiagnosticBlock(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
