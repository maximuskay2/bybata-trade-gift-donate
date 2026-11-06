import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Builds client metadata sent with API requests for security alerts & auditing.
abstract final class ClientDeviceInfo {
  static String? _userAgent;

  static Map<String, String> headers() {
    if (kIsWeb) {
      return {
        'X-Bybata-Platform': 'Web',
        'X-Bybata-Device-Name': 'Web browser',
        'User-Agent': userAgent(),
      };
    }

    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.android => 'Android',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      _ => Platform.operatingSystem,
    };

    final osVersion = Platform.operatingSystemVersion.trim();
    final deviceName = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iPhone',
      TargetPlatform.android => 'Android phone',
      TargetPlatform.macOS => 'Mac',
      TargetPlatform.windows => 'Windows PC',
      TargetPlatform.linux => 'Linux PC',
      _ => platform,
    };

    return {
      'X-Bybata-Platform': platform,
      'X-Bybata-Device-Name': deviceName,
      if (osVersion.isNotEmpty) 'X-Bybata-Device-OS': osVersion,
      'User-Agent': userAgent(),
    };
  }

  static String userAgent() {
    if (_userAgent != null) return _userAgent!;

    if (kIsWeb) {
      _userAgent = 'Bybata/1.0 (Web) Flutter';
      return _userAgent!;
    }

    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.android => 'Android',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      _ => Platform.operatingSystem,
    };
    final version = Platform.operatingSystemVersion.trim();
    _userAgent = version.isEmpty
        ? 'Bybata/1.0 ($platform) Dart/Flutter'
        : 'Bybata/1.0 ($platform; $version) Dart/Flutter';
    return _userAgent!;
  }
}
