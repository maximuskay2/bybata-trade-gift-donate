import '../../../core/models/listing_media.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/listing_category_parser.dart';
import '../../../core/utils/media_utils.dart';
import 'package:flutter/material.dart';

/// Normalized display model for search grid tiles (parsed via [ListingCategoryParser]).
class SearchItemViewData {
  final String id;
  final String moduleType;
  final String title;
  final String subtitle;
  final String? previewImageKey;
  final ListingMediaFields media;
  final SearchMetricFlag metric;

  const SearchItemViewData({
    required this.id,
    required this.moduleType,
    required this.title,
    required this.subtitle,
    this.previewImageKey,
    required this.media,
    required this.metric,
  });

  /// Rough height hint for masonry column balancing.
  double get estimatedTileHeight {
    const imageBlock = 220.0;
    const textBlock = 88.0;
    final subtitleExtra = subtitle.length > 36 ? 14.0 : 0.0;
    return imageBlock + textBlock + subtitleExtra;
  }

  static SearchItemViewData fromRaw(Map<String, dynamic> raw) {
    final typeRaw = raw['type']?.toString();
    final moduleType = ListingCategoryParser.normalizeModuleLabel(typeRaw);

    final media = _parseListingMedia(raw);
    final previewKey = media.previewImageKey ?? _firstMediaKey(raw);

    return SearchItemViewData(
      id: raw['id']?.toString() ?? '',
      moduleType: moduleType,
      title: _title(raw, moduleType),
      subtitle: _subtitle(raw, moduleType),
      previewImageKey: previewKey,
      media: media,
      metric: _metric(raw, moduleType),
    );
  }

  static String _title(Map<String, dynamic> raw, String moduleType) {
    if (moduleType == 'user') {
      final username = raw['profile']?['username'] ?? raw['username'];
      if (username != null && username.toString().isNotEmpty) {
        final s = username.toString();
        return s.startsWith('@') ? s : '@$s';
      }
      return raw['profile']?['displayName'] ??
          raw['displayName'] ??
          raw['email'] ??
          'User';
    }
    return raw['title'] ?? raw['name'] ?? 'Item';
  }

  static String _subtitle(Map<String, dynamic> raw, String moduleType) {
    if (moduleType == 'user') {
      return raw['profile']?['displayName'] ??
          raw['displayName'] ??
          raw['profile']?['bio'] ??
          '';
    }
    return raw['description'] ??
        raw['shortDescription'] ??
        raw['story'] ??
        '';
  }

  static SearchMetricFlag _metric(Map<String, dynamic> raw, String moduleType) {
    switch (moduleType) {
      case 'trade':
        return SearchMetricFlag(
          icon: Icons.place_rounded,
          label: _tradeMetricLabel(raw),
          color: AppTheme.tradeColor,
        );
      case 'gift':
        final karma = _toInt(raw['karmaReward'] ?? raw['karmaPoints'] ?? raw['karma']);
        return SearchMetricFlag(
          icon: Icons.auto_awesome_rounded,
          label: karma > 0 ? '+$karma Karma' : 'Free gift',
          color: AppTheme.karmaColor,
        );
      case 'campaign':
        final goal = _toDouble(raw['goalAmount']);
        final raised = _toDouble(raw['currentAmount'] ?? raw['raisedAmount']);
        final pct = goal > 0 ? ((raised / goal) * 100).clamp(0, 100).round() : 0;
        return SearchMetricFlag(
          icon: Icons.favorite_rounded,
          label: goal > 0 ? '$pct% Funded' : 'New campaign',
          color: AppTheme.donationColor,
        );
      case 'community':
        final members = _toInt(raw['memberCount'] ?? raw['membersCount']);
        return SearchMetricFlag(
          icon: Icons.groups_rounded,
          label: members > 0 ? '$members members' : 'Community',
          color: AppTheme.communityColor,
        );
      case 'user':
        return SearchMetricFlag(
          icon: Icons.person_rounded,
          label: 'Profile',
          color: AppTheme.primaryColor,
        );
      default:
        return SearchMetricFlag(
          icon: Icons.search_rounded,
          label: 'Discover',
          color: AppTheme.primaryColor,
        );
    }
  }

  static String _tradeMetricLabel(Map<String, dynamic> raw) {
    final location = raw['location'] ??
        raw['locationLabel'] ??
        raw['city'] ??
        raw['area'];
    final distance = raw['distanceKm'] ?? raw['distance'];
    if (location != null && location.toString().trim().isNotEmpty) {
      final loc = location.toString().trim();
      if (distance is num && distance > 0) {
        final km = distance.toDouble();
        final distLabel = km < 1
            ? '${(km * 1000).round()}m'
            : '${km.toStringAsFixed(km < 10 ? 1 : 0)}km';
        return '📍 $loc, $distLabel';
      }
      return '📍 $loc';
    }
    if (distance is num && distance > 0) {
      final km = distance.toDouble();
      return km < 1
          ? '${(km * 1000).round()}m away'
          : '${km.toStringAsFixed(km < 10 ? 1 : 0)}km away';
    }
    final value = _toDouble(raw['estimatedValue'] ?? raw['value']);
    if (value > 0) {
      return 'Est. \$${value.toStringAsFixed(0)}';
    }
    return 'Open to trade';
  }

  static String? _firstMediaKey(Map<String, dynamic> raw) {
    final keys = raw['mediaKeys'];
    if (keys is List && keys.isNotEmpty) {
      for (final entry in keys) {
        final first = entry?.toString().trim();
        if (first != null && first.isNotEmpty) return first;
      }
    }
    for (final field in ['thumbnailKey', 'imageUrl', 'image', 'coverImage']) {
      final v = raw[field]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    final images = raw['images'] ?? raw['imageUrls'];
    if (images is List && images.isNotEmpty) {
      for (final entry in images) {
        final first = entry?.toString().trim();
        if (first != null && first.isNotEmpty) return first;
      }
    }
    return null;
  }

  static ListingMediaFields _parseListingMedia(Map<String, dynamic> raw) {
    final media = ListingMediaFields.fromJson(raw);
    if (media.hasMedia) return media;

    final fallbackKey = _firstMediaKey(raw);
    if (fallbackKey == null) return media;

    return ListingMediaFields(
      mediaType: ListingMediaType.image,
      mediaKeys: [fallbackKey],
      thumbnailKey: fallbackKey,
    );
  }

  /// Pre-resolve preview URLs so fresh listings show thumbnails immediately.
  static Future<void> warmPreviewMedia(
    Iterable<Map<String, dynamic>> items, {
    int limit = 24,
  }) async {
    var warmed = 0;
    for (final raw in items) {
      if (warmed >= limit) break;
      final data = fromRaw(raw);
      final preview = data.previewImageKey;
      if (preview != null && preview.isNotEmpty) {
        warmed++;
        await MediaResolver.resolveUrl(preview);
      }
      if (data.media.isVideo) {
        final videoKey = data.media.videoKey?.trim();
        if (videoKey != null && videoKey.isNotEmpty) {
          await MediaResolver.resolveUrl(videoKey, forVideo: true);
        }
      }
    }
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

class SearchMetricFlag {
  final IconData icon;
  final String label;
  final Color color;

  const SearchMetricFlag({
    required this.icon,
    required this.label,
    required this.color,
  });
}
