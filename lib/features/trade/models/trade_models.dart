import 'package:flutter/material.dart';
import 'package:bybata/core/theme/app_theme.dart';

import '../../../core/models/listing_media.dart';

enum TradeStatus {
  active,        // OPEN in backend
  inOffer,       // IN_OFFER in backend (negotiation pending)
  completed,     // CLOSED in backend
  cancelled,     // CANCELLED in backend
  pending,
  expired,
}

extension TradeStatusExtension on TradeStatus {
  String get backendValue {
    switch (this) {
      case TradeStatus.active:
        return 'OPEN';
      case TradeStatus.inOffer:
        return 'IN_OFFER';
      case TradeStatus.completed:
        return 'CLOSED';
      case TradeStatus.cancelled:
        return 'CANCELLED';
      case TradeStatus.pending:
        return 'OPEN';
      case TradeStatus.expired:
        return 'EXPIRED';
    }
  }

  static TradeStatus fromBackendValue(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return TradeStatus.active;
      case 'IN_OFFER':
        return TradeStatus.inOffer;
      case 'CLOSED':
        return TradeStatus.completed;
      case 'CANCELLED':
        return TradeStatus.cancelled;
      case 'DRAFT':
        return TradeStatus.pending;
      default:
        return TradeStatus.active;
    }
  }
}

enum TradeCategory {
  electronics,
  books,
  clothing,
  fashion,
  homeGarden,
  sports,
  tools,
  automotive,
  collectibles,
  others,
}

/// Normalizes API / form values (e.g. `HOME_GARDEN`, `homeGarden`) to [TradeCategory].
TradeCategory parseTradeCategory(dynamic raw) {
  if (raw is TradeCategory) return raw;
  if (raw is Map) {
    return parseTradeCategory(raw['name'] ?? raw['slug'] ?? raw['id']);
  }
  var s = (raw?.toString() ?? '').trim().toUpperCase();
  if (s.isEmpty) return TradeCategory.others;
  s = s.replaceAll(' ', '_').replaceAll('-', '_').replaceAll('&', '');
  if (s == 'HOMEGARDEN') s = 'HOME_GARDEN';

  final compact = s.replaceAll('_', '');
  for (final e in TradeCategory.values) {
    final enumCompact = e.name.toUpperCase();
    final enumSnake = e.name
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]}_${m[2]}')
        .toUpperCase();
    if (s == enumSnake || compact == enumCompact || s == enumCompact) {
      return e;
    }
  }
  return TradeCategory.others;
}

/// Labels shown on Trade Centre category chips under search.
String tradeCategoryBrowseLabel(TradeCategory category) {
  switch (category) {
    case TradeCategory.electronics:
      return 'Electronics';
    case TradeCategory.books:
      return 'Books';
    case TradeCategory.clothing:
    case TradeCategory.fashion:
      return 'Clothing';
    case TradeCategory.homeGarden:
      return 'Home & Garden';
    case TradeCategory.sports:
      return 'Sports';
    case TradeCategory.tools:
      return 'Tools';
    case TradeCategory.automotive:
    case TradeCategory.collectibles:
    case TradeCategory.others:
      return 'Others';
  }
}

/// Human-readable category for cards and filters from any API payload shape.
String tradeCategoryDisplayName(dynamic raw) {
  if (raw is Map) {
    return tradeCategoryDisplayName(raw['name'] ?? raw['slug']);
  }
  final str = raw?.toString().trim() ?? '';
  if (str.isEmpty) return 'Others';
  for (final cat in TradeCategory.values) {
    final label = tradeCategoryBrowseLabel(cat);
    if (label.toLowerCase() == str.toLowerCase()) return label;
  }
  return tradeCategoryBrowseLabel(parseTradeCategory(raw));
}

bool tradeMatchesBrowseCategory(dynamic rawCategory, String selectedChip) {
  if (selectedChip == 'All') return true;
  return tradeCategoryBrowseLabel(parseTradeCategory(rawCategory)) ==
      selectedChip;
}

String? browseChipToApiCategory(String chip) {
  if (chip == 'All') return null;
  for (final cat in TradeCategory.values) {
    if (tradeCategoryBrowseLabel(cat) == chip) {
      return cat.name.toUpperCase();
    }
  }
  return null;
}

enum OfferStatus {
  pending,
  accepted,
  acceptedAwaitingFinalization,
  finalized,
  rejected,
  declined,
  withdrawn,
  counterOffer,
}

/// Parses backend status string (e.g. ACCEPTED_AWAITING_FINALIZATION) to OfferStatus.
/// Backend uses underscores; enum uses camelCase.
OfferStatus _parseOfferStatus(dynamic statusValue) {
  final raw = (statusValue?.toString() ?? 'PENDING').toUpperCase();
  final normalized = raw.replaceAll('_', '');
  for (final e in OfferStatus.values) {
    final enumStr = e.toString().split('.').last.toUpperCase().replaceAll('_', '');
    if (enumStr == normalized) return e;
  }
  return OfferStatus.pending;
}

/// Returns (label, color) for raw status string from API. Use for offer cards.
(String label, Color color) getOfferStatusDisplayFromRaw(
  dynamic statusRaw, {
  bool isReceived = false,
  bool isCashOffer = false,
}) {
  final status = _parseOfferStatus(statusRaw);
  String label;
  if (status == OfferStatus.pending && isReceived) {
    label = 'Awaiting your response';
  } else if (status == OfferStatus.acceptedAwaitingFinalization && isCashOffer) {
    label = 'Accepted – finalize';
  } else {
    label = status.displayLabel;
  }
  return (label, status.displayColor);
}

extension OfferStatusDisplay on OfferStatus {
  String get displayLabel {
    switch (this) {
      case OfferStatus.pending:
        return 'Pending';
      case OfferStatus.accepted:
        return 'Accepted';
      case OfferStatus.acceptedAwaitingFinalization:
        return 'Awaiting Finalization';
      case OfferStatus.finalized:
        return 'Finalized';
      case OfferStatus.rejected:
        return 'Rejected';
      case OfferStatus.declined:
        return 'Declined';
      case OfferStatus.withdrawn:
        return 'Withdrawn';
      case OfferStatus.counterOffer:
        return 'Counter Offer';
    }
  }

  Color get displayColor {
    switch (this) {
      case OfferStatus.pending:
        return Colors.orange;
      case OfferStatus.accepted:
        return Colors.green;
      case OfferStatus.acceptedAwaitingFinalization:
        return Colors.orange;
      case OfferStatus.finalized:
        return Colors.green;
      case OfferStatus.rejected:
        return Colors.red;
      case OfferStatus.declined:
        return Colors.red;
      case OfferStatus.withdrawn:
        return Colors.grey;
      case OfferStatus.counterOffer:
        return AppColors.primary;
    }
  }
}

enum ItemCondition {
  new_,
  excellent,
  good,
  fair,
  poor,
}

extension ItemConditionExtension on ItemCondition {
  String get displayText {
    switch (this) {
      case ItemCondition.new_:
        return 'New';
      case ItemCondition.excellent:
        return 'Excellent';
      case ItemCondition.good:
        return 'Good';
      case ItemCondition.fair:
        return 'Fair';
      case ItemCondition.poor:
        return 'Poor';
    }
  }
}

class TradeUser {
  final String id;
  final String name;
  final String username;
  final String? avatar;
  final double rating;
  final int completedTrades;
  final DateTime joinedDate;
  final bool isVerified;
  final String? location;
  final String? bio;
  final int karmaPoints;
  final List<TrustBadge> trustBadges;
  final double trustScore;

  TradeUser({
    required this.id,
    required this.name,
    required this.username,
    this.avatar,
    required this.rating,
    required this.completedTrades,
    required this.joinedDate,
    required this.isVerified,
    this.location,
    this.bio,
    this.karmaPoints = 0,
    this.trustBadges = const [],
    this.trustScore = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'avatar': avatar,
      'rating': rating,
      'completedTrades': completedTrades,
      'joinedDate': joinedDate.toIso8601String(),
      'isVerified': isVerified,
      'location': location,
      'bio': bio,
      'karmaPoints': karmaPoints,
      'trustBadges': trustBadges.map((badge) => badge.toJson()).toList(),
      'trustScore': trustScore,
    };
  }

  factory TradeUser.fromJson(Map<String, dynamic> json) {
    // Handle different API response structures (owner from trade, or direct user profile)
    final profile = json['profile'] as Map<String, dynamic>? ?? {};
    final userId = json['id'] ?? '';
    final displayName = profile['displayName'] ?? json['name'] ?? json['displayName'] ?? 'Unknown User';
    final email = json['email'] ?? json['username'] ?? '';
    final username = json['username'] ?? email.split('@').first;
    
    // Parse joined date - could be from user.createdAt or profile
    DateTime joinedDate;
    try {
      if (json['joinedDate'] != null) {
        joinedDate = DateTime.parse(json['joinedDate']);
      } else if (json['createdAt'] != null) {
        joinedDate = DateTime.parse(json['createdAt']);
      } else if (profile['createdAt'] != null) {
        joinedDate = DateTime.parse(profile['createdAt']);
      } else {
        joinedDate = DateTime.now();
      }
    } catch (e) {
      joinedDate = DateTime.now();
    }
    
    return TradeUser(
      id: userId.toString(),
      name: displayName.toString(),
      username: username.toString(),
      avatar: profile['avatarKey'] ?? json['avatar'] ?? json['avatarKey'],
      rating: (json['rating'] ?? profile['rating'] ?? 0.0).toDouble(),
      completedTrades: json['completedTrades'] ?? profile['completedTrades'] ?? 0,
      joinedDate: joinedDate,
      isVerified: json['isVerified'] ?? profile['kycStatus'] == 'VERIFIED' ?? false,
      location: profile['location'] ?? json['location'],
      bio: profile['bio'] ?? json['bio'],
      karmaPoints: json['karmaPoints'] ?? profile['karmaPoints'] ?? 0,
      trustBadges: (json['trustBadges'] as List<dynamic>? ?? [])
          .map((badge) => TrustBadge.fromJson(badge))
          .toList(),
      trustScore: (json['trustScore'] ?? profile['trustScore'] ?? 0.0).toDouble(),
    );
  }
}

class Trade {
  final String id;
  final String title;
  final String description;
  final List<String> images;
  final String? mediaType;
  final String? videoKey;
  final String? thumbnailKey;
  final TradeCategory category;
  final TradeUser owner;
  final TradeStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final ItemCondition condition;
  final int estimatedValue;
  final List<String> interestedItems;
  final String location;
  final List<String> tags;
  final int viewCount;
  final int favoriteCount;
  final bool isNegotiable;
  final bool allowPickup;
  final bool enableBYCPromotion;
  final String? notes;
  final DateTime? updatedAt;

  Trade({
    required this.id,
    required this.title,
    required this.description,
    required this.images,
    this.mediaType,
    this.videoKey,
    this.thumbnailKey,
    required this.category,
    required this.owner,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    required this.condition,
    required this.estimatedValue,
    required this.interestedItems,
    required this.location,
    required this.tags,
    required this.viewCount,
    required this.favoriteCount,
    required this.isNegotiable,
    required this.allowPickup,
    this.enableBYCPromotion = false,
    this.notes,
    this.updatedAt,
  });

  ListingMediaFields get listingMedia {
    final isVideo = (mediaType?.toUpperCase() == 'VIDEO') ||
        ((videoKey ?? '').isNotEmpty && images.isEmpty);
    var mediaKeys = List<String>.from(images);
    if (!isVideo &&
        mediaKeys.isEmpty &&
        (thumbnailKey ?? '').trim().isNotEmpty) {
      mediaKeys = [thumbnailKey!.trim()];
    }
    return ListingMediaFields(
      mediaType: isVideo ? ListingMediaType.video : ListingMediaType.image,
      mediaKeys: mediaKeys,
      videoKey: videoKey,
      thumbnailKey: thumbnailKey,
    );
  }

  /// Parses storage keys from API payloads (handles legacy shapes).
  static List<String> parseMediaKeysFromJson(Map<String, dynamic> json) {
    final raw = json['mediaKeys'] as List? ?? json['images'] as List? ?? [];
    final keys = <String>[];
    for (final entry in raw) {
      if (entry is String && entry.trim().isNotEmpty) {
        keys.add(entry.trim());
      } else if (entry is Map) {
        final key = entry['key'] ?? entry['url'] ?? entry['mediaKey'];
        if (key is String && key.trim().isNotEmpty) {
          keys.add(key.trim());
        }
      } else {
        final text = entry?.toString().trim() ?? '';
        if (text.isNotEmpty && !text.startsWith('{')) {
          keys.add(text);
        }
      }
    }
    if (keys.isEmpty) {
      for (final field in [
        'thumbnailKey',
        'mediaKey',
        'imageKey',
        'imageUrl',
        'image',
        'coverImage',
      ]) {
        final value = json[field]?.toString().trim();
        if (value != null && value.isNotEmpty) {
          keys.add(value);
          break;
        }
      }
    }
    return keys;
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String get categoryName {
    switch (category) {
      case TradeCategory.electronics:
        return 'Electronics';
      case TradeCategory.books:
        return 'Books';
      case TradeCategory.clothing:
        return 'Clothing';
      case TradeCategory.fashion:
        return 'Fashion';
      case TradeCategory.homeGarden:
        return 'Home & Garden';
      case TradeCategory.sports:
        return 'Sports';
      case TradeCategory.tools:
        return 'Tools';
      case TradeCategory.automotive:
        return 'Automotive';
      case TradeCategory.collectibles:
        return 'Collectibles';
      case TradeCategory.others:
        return 'Others';
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case TradeCategory.electronics:
        return Icons.devices;
      case TradeCategory.books:
        return Icons.menu_book;
      case TradeCategory.clothing:
        return Icons.checkroom;
      case TradeCategory.fashion:
        return Icons.style;
      case TradeCategory.homeGarden:
        return Icons.home;
      case TradeCategory.sports:
        return Icons.sports_basketball;
      case TradeCategory.tools:
        return Icons.build;
      case TradeCategory.automotive:
        return Icons.directions_car;
      case TradeCategory.collectibles:
        return Icons.collections;
      case TradeCategory.others:
        return Icons.category;
    }
  }

  Color get statusColor {
    switch (status) {
      case TradeStatus.active:
        return Colors.green;
      case TradeStatus.inOffer:
        return Colors.amber;
      case TradeStatus.pending:
        return Colors.orange;
      case TradeStatus.completed:
        return AppColors.primary;
      case TradeStatus.cancelled:
        return Colors.red;
      case TradeStatus.expired:
        return Colors.grey;
    }
  }

  String get statusText {
    switch (status) {
      case TradeStatus.active:
        return 'Active';
      case TradeStatus.inOffer:
        return 'In Offer';
      case TradeStatus.pending:
        return 'Pending';
      case TradeStatus.completed:
        return 'Completed';
      case TradeStatus.cancelled:
        return 'Cancelled';
      case TradeStatus.expired:
        return 'Expired';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'images': images,
      'category': category.toString(),
      'owner': owner.toJson(),
      'status': status.toString(),
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'condition': condition.toString(),
      'estimatedValue': estimatedValue,
      'interestedItems': interestedItems,
      'location': location,
      'tags': tags,
      'viewCount': viewCount,
      'favoriteCount': favoriteCount,
      'isNegotiable': isNegotiable,
      'allowPickup': allowPickup,
      'enableBYCPromotion': enableBYCPromotion,
      'notes': notes,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Trade.fromJson(Map<String, dynamic> json) {
    final images = parseMediaKeysFromJson(json);
    
    // Parse category - handle string enum values
    final category = parseTradeCategory(json['category']);
    // Parse backend status (OPEN, IN_OFFER, CLOSED, …)
    TradeStatus status = TradeStatus.active;
    try {
      status = TradeStatusExtension.fromBackendValue(
        json['status']?.toString() ?? 'OPEN',
      );
    } catch (e) {
      status = TradeStatus.active;
    }
    
    // Parse owner - handle nested structure
    final ownerData = json['owner'] as Map<String, dynamic>? ?? {};
    
    // Parse dates with null safety
    DateTime createdAt;
    try {
      createdAt = json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now();
    } catch (e) {
      createdAt = DateTime.now();
    }
    
    DateTime? expiresAt;
    try {
      expiresAt = json['expiresAt'] != null 
          ? DateTime.parse(json['expiresAt'].toString())
          : null;
    } catch (e) {
      expiresAt = null;
    }
    
    DateTime? updatedAt;
    try {
      updatedAt = json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'].toString())
          : null;
    } catch (e) {
      updatedAt = null;
    }
    
    // Parse condition
    ItemCondition condition = ItemCondition.good;
    try {
      if (json['condition'] != null) {
        final conditionStr = json['condition'].toString().toUpperCase();
        condition = ItemCondition.values.firstWhere(
          (e) => e.toString().split('.').last.toUpperCase() == conditionStr,
          orElse: () => ItemCondition.good,
        );
      }
    } catch (e) {
      condition = ItemCondition.good;
    }
    
    return Trade(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Trade',
      description: json['description']?.toString() ?? '',
      images: images,
      mediaType: json['mediaType']?.toString(),
      videoKey: json['videoKey']?.toString(),
      thumbnailKey: json['thumbnailKey']?.toString(),
      category: category,
      owner: TradeUser.fromJson(ownerData),
      status: status,
      createdAt: createdAt,
      expiresAt: expiresAt,
      condition: condition,
      estimatedValue: (json['estimatedValue'] ?? 0).toInt(),
      interestedItems: List<String>.from((json['interestedItems'] ?? []).map((e) => e.toString())),
      location: json['location']?.toString() ?? '',
      tags: List<String>.from((json['tags'] ?? []).map((e) => e.toString())),
      viewCount: json['viewCount'] ?? 0,
      favoriteCount: json['favoriteCount'] ?? 0,
      isNegotiable: json['isNegotiable'] ?? true,
      allowPickup: json['allowPickup'] ?? true,
      enableBYCPromotion: json['enableBYCPromotion'] == true,
      notes: json['notes']?.toString(),
      updatedAt: updatedAt,
    );
  }
}

class TradeOffer {
  final String id;
  final Trade targetTrade; // The trade being offered to
  final Trade? offeredTrade; // The trade being offered in return (nullable for cash offers)
  final String? amount; // Cash amount (nullable for item-for-item offers)
  final TradeUser offerer;
  final TradeUser recipient;
  final String message;
  final OfferStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? meetingLocation;
  final bool isCounterOffer;
  final String? parentOfferId; // ID of the parent offer (if this is a counter-offer)
  final List<TradeOffer>? counterOffers; // List of counter-offers to this offer
  final int timelineDepth; // From offer history API (0 = original)
  /// Owner counter: item the owner wants from the bidder.
  final Trade? requestedTrade;
  /// Owner counter: additional cash requested (BYC).
  final String? requestedAmount;

  TradeOffer({
    required this.id,
    required this.targetTrade,
    this.offeredTrade,
    this.amount,
    required this.offerer,
    required this.recipient,
    required this.message,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.meetingLocation,
    required this.isCounterOffer,
    this.parentOfferId,
    this.counterOffers,
    this.timelineDepth = 0,
    this.requestedTrade,
    this.requestedAmount,
  });

  /// Owner counter-offer (wants bidder's item and/or cash).
  bool get isOwnerCounter =>
      isCounterOffer &&
      (requestedTrade != null ||
          (requestedAmount != null && requestedAmount!.trim().isNotEmpty));

  String get statusText => status.displayLabel;

  /// User-friendly label considering direction and type (for offer cards).
  String statusLabelForCard({required bool isReceived, required bool isCashOffer}) {
    switch (status) {
      case OfferStatus.pending:
        return isReceived ? 'Awaiting your response' : 'Pending';
      case OfferStatus.acceptedAwaitingFinalization:
        return isCashOffer ? 'Accepted – finalize' : 'Awaiting Finalization';
      default:
        return status.displayLabel;
    }
  }

  Color get statusColor => status.displayColor;

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  bool get isItemOffer => offeredTrade != null;
  bool get isCashOffer => amount != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'targetTrade': targetTrade.toJson(),
      if (offeredTrade != null) 'offeredTrade': offeredTrade!.toJson(),
      if (amount != null) 'amount': amount,
      'offerer': offerer.toJson(),
      'recipient': recipient.toJson(),
      'message': message,
      'status': status.toString(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'meetingLocation': meetingLocation,
      'isCounterOffer': isCounterOffer,
    };
  }

  /// Parse one entry from GET /offers/:id/history `timeline` (flat list, no nested counters).
  static TradeOffer? tryParseTimelineEntry(dynamic raw) {
    if (raw is! Map) return null;
    try {
      return TradeOffer.fromTimelineJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  factory TradeOffer.fromTimelineJson(Map<String, dynamic> json) {
    final flat = Map<String, dynamic>.from(json);
    flat.remove('counterOffers');
    flat.remove('parentOffer');
    return TradeOffer.fromJson(flat, includeNestedCounters: false);
  }

  factory TradeOffer.fromJson(
    Map<String, dynamic> json, {
    bool includeNestedCounters = true,
  }) {
    // Listing being negotiated (`trade` from API history).
    final targetTradeData = json['trade'] ?? json['targetTrade'];
    final offeredTradeData = json['offeredTrade'];
    final requestedTradeData = json['requestedTrade'];
    final bidderData = json['bidder'] ?? json['offerer'];
    final tradeOwnerData = targetTradeData is Map
        ? (targetTradeData['owner'] ?? json['recipient'])
        : json['recipient'];
    final counterOffersData =
        includeNestedCounters ? json['counterOffers'] as List? : null;

    return TradeOffer(
      id: json['id'] ?? json['offerId'] ?? '',
      targetTrade: Trade.fromJson(
        Map<String, dynamic>.from(
          targetTradeData is Map ? targetTradeData : <String, dynamic>{},
        ),
      ),
      offeredTrade: offeredTradeData != null
          ? Trade.fromJson(Map<String, dynamic>.from(offeredTradeData))
          : null,
      requestedTrade: requestedTradeData is Map
          ? Trade.fromJson(Map<String, dynamic>.from(requestedTradeData))
          : null,
      requestedAmount: json['requestedAmount']?.toString(),
      amount: json['amount']?.toString(),
      offerer: TradeUser.fromJson(
        Map<String, dynamic>.from(bidderData ?? {}),
      ),
      recipient: TradeUser.fromJson(
        Map<String, dynamic>.from(tradeOwnerData ?? {}),
      ),
      message: json['message'] ?? '',
      status: _parseOfferStatus(json['status']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      meetingLocation: json['meetingLocation'],
      isCounterOffer: json['isCounterOffer'] == true || json['parentOfferId'] != null,
      parentOfferId: json['parentOfferId']?.toString(),
      timelineDepth: (json['depth'] as num?)?.toInt() ?? 0,
      counterOffers: counterOffersData
          ?.map((e) => TradeOffer.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

// KARMA and Trust System Models
enum TrustBadgeType {
  fastTrader,
  reliableTrader,
  friendlyTrader,
  expertTrader,
  communityHelper,
  safeMeeter,
  responseChamp,
}

class TrustBadge {
  final TrustBadgeType type;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final DateTime earnedAt;

  TrustBadge({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.earnedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'title': title,
      'description': description,
      'earnedAt': earnedAt.toIso8601String(),
    };
  }

  factory TrustBadge.fromJson(Map<String, dynamic> json) {
    final type = TrustBadgeType.values.firstWhere(
      (e) => e.toString() == json['type'],
      orElse: () => TrustBadgeType.reliableTrader,
    );
    return TrustBadge.fromType(
      type: type,
      earnedAt: DateTime.parse(json['earnedAt']),
    );
  }

  factory TrustBadge.fromType({required TrustBadgeType type, required DateTime earnedAt}) {
    switch (type) {
      case TrustBadgeType.fastTrader:
        return TrustBadge(
          type: type,
          title: 'Fast Trader',
          description: 'Completes trades quickly',
          icon: Icons.flash_on,
          color: Colors.yellow,
          earnedAt: earnedAt,
        );
      case TrustBadgeType.reliableTrader:
        return TrustBadge(
          type: type,
          title: 'Reliable Trader',
          description: 'Consistently follows through',
          icon: Icons.verified,
          color: AppColors.primary,
          earnedAt: earnedAt,
        );
      case TrustBadgeType.friendlyTrader:
        return TrustBadge(
          type: type,
          title: 'Friendly Trader',
          description: 'Great communication skills',
          icon: Icons.sentiment_very_satisfied,
          color: Colors.green,
          earnedAt: earnedAt,
        );
      case TrustBadgeType.expertTrader:
        return TrustBadge(
          type: type,
          title: 'Expert Trader',
          description: '100+ successful trades',
          icon: Icons.emoji_events,
          color: Colors.purple,
          earnedAt: earnedAt,
        );
      case TrustBadgeType.communityHelper:
        return TrustBadge(
          type: type,
          title: 'Community Helper',
          description: 'Helps resolve disputes',
          icon: Icons.people_outline,
          color: Colors.orange,
          earnedAt: earnedAt,
        );
      case TrustBadgeType.safeMeeter:
        return TrustBadge(
          type: type,
          title: 'Safe Meeter',
          description: 'Uses safe meeting locations',
          icon: Icons.security,
          color: Colors.teal,
          earnedAt: earnedAt,
        );
      case TrustBadgeType.responseChamp:
        return TrustBadge(
          type: type,
          title: 'Response Champ',
          description: 'Quick to respond',
          icon: Icons.reply,
          color: AppColors.primaryDark,
          earnedAt: earnedAt,
        );
    }
  }
}

// Safe Meeting Location Model
class SafeMeetingLocation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String type; // police_station, public_place, mall, etc.
  final bool isVerified;
  final double rating;
  final int usageCount;
  final List<String> amenities;
  final String operatingHours;

  SafeMeetingLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.isVerified,
    required this.rating,
    required this.usageCount,
    required this.amenities,
    required this.operatingHours,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
      'isVerified': isVerified,
      'rating': rating,
      'usageCount': usageCount,
      'amenities': amenities,
      'operatingHours': operatingHours,
    };
  }

  factory SafeMeetingLocation.fromJson(Map<String, dynamic> json) {
    return SafeMeetingLocation(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      type: json['type'],
      isVerified: json['isVerified'] ?? false,
      rating: json['rating']?.toDouble() ?? 0.0,
      usageCount: json['usageCount'] ?? 0,
      amenities: List<String>.from(json['amenities'] ?? []),
      operatingHours: json['operatingHours'] ?? '24/7',
    );
  }
}

// Dispute Resolution Model
enum DisputeStatus {
  open,
  investigating,
  resolved,
  escalated,
  closed,
}

enum DisputeType {
  noShow,
  itemMismatch,
  damagedItem,
  communication,
  safety,
  other,
}

class TradeDispute {
  final String id;
  final TradeOffer relatedOffer;
  final TradeUser complainant;
  final TradeUser respondent;
  final DisputeType type;
  final DisputeStatus status;
  final String description;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolution;
  final TradeUser? mediator;
  final List<DisputeEvidence> evidence;
  final int communityVotes;
  final double communityScore;

  TradeDispute({
    required this.id,
    required this.relatedOffer,
    required this.complainant,
    required this.respondent,
    required this.type,
    required this.status,
    required this.description,
    required this.createdAt,
    this.resolvedAt,
    this.resolution,
    this.mediator,
    required this.evidence,
    required this.communityVotes,
    required this.communityScore,
  });

  String get typeDescription {
    switch (type) {
      case DisputeType.noShow:
        return 'No Show';
      case DisputeType.itemMismatch:
        return 'Item Mismatch';
      case DisputeType.damagedItem:
        return 'Damaged Item';
      case DisputeType.communication:
        return 'Communication Issue';
      case DisputeType.safety:
        return 'Safety Concern';
      case DisputeType.other:
        return 'Other';
    }
  }

  Color get statusColor {
    switch (status) {
      case DisputeStatus.open:
        return Colors.red;
      case DisputeStatus.investigating:
        return Colors.orange;
      case DisputeStatus.resolved:
        return Colors.green;
      case DisputeStatus.escalated:
        return Colors.purple;
      case DisputeStatus.closed:
        return Colors.grey;
    }
  }
}

class DisputeEvidence {
  final String id;
  final String type; // image, text, document
  final String content; // path for images, text for messages
  final DateTime submittedAt;
  final TradeUser submittedBy;

  DisputeEvidence({
    required this.id,
    required this.type,
    required this.content,
    required this.submittedAt,
    required this.submittedBy,
  });
}

// Smart Matching Model
class SmartMatchSuggestion {
  final Trade suggestedTrade;
  final double matchScore;
  final List<String> matchReasons;
  final String algorithm; // location, category, user_preference, etc.
  final DateTime suggestedAt;

  SmartMatchSuggestion({
    required this.suggestedTrade,
    required this.matchScore,
    required this.matchReasons,
    required this.algorithm,
    required this.suggestedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'suggestedTrade': suggestedTrade.toJson(),
      'matchScore': matchScore,
      'matchReasons': matchReasons,
      'algorithm': algorithm,
      'suggestedAt': suggestedAt.toIso8601String(),
    };
  }
}

// Karma Transaction Model
class KarmaTransaction {
  final String id;
  final TradeUser user;
  final int points;
  final String reason;
  final String source; // trade_completion, dispute_resolution, etc.
  final DateTime createdAt;
  final Trade? relatedTrade;

  KarmaTransaction({
    required this.id,
    required this.user,
    required this.points,
    required this.reason,
    required this.source,
    required this.createdAt,
    this.relatedTrade,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'points': points,
      'reason': reason,
      'source': source,
      'createdAt': createdAt.toIso8601String(),
      'relatedTrade': relatedTrade?.toJson(),
    };
  }
}

class TradeMessage {
  final String id;
  final String tradeId;
  final String? offerId;
  final TradeUser sender;
  final String content;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? metadata;
  final String messageType; // 'regular', 'proposal', 'acceptance', 'decline', etc.
  final Map<String, dynamic>? proposalData; // Structured proposal details

  TradeMessage({
    required this.id,
    required this.tradeId,
    this.offerId,
    required this.sender,
    required this.content,
    required this.createdAt,
    required this.isRead,
    this.metadata,
    this.messageType = 'regular',
    this.proposalData,
  });

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tradeId': tradeId,
      'offerId': offerId,
      'sender': sender.toJson(),
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'metadata': metadata,
      'messageType': messageType,
      'proposalData': proposalData,
    };
  }

  factory TradeMessage.fromJson(Map<String, dynamic> json) {
    return TradeMessage(
      id: json['id'],
      tradeId: json['tradeId'],
      offerId: json['offerId'],
      sender: TradeUser.fromJson(json['sender']),
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'] ?? false,
      metadata: json['metadata'],
      messageType: json['messageType'] ?? 'regular',
      proposalData: json['proposalData'],
    );
  }
}