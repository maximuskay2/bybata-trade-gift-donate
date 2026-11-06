import 'package:flutter/material.dart';
import 'package:bybata/core/theme/app_theme.dart';

import '../../../core/models/listing_media.dart';

// Gift User Model
class GiftUser {
  final String id;
  final String name;
  final String username;
  final double rating;
  final int completedGifts;
  final int karmaPoints;
  final DateTime joinedDate;
  final bool isVerified;
  final String? profileImageUrl;
  final List<String> badges;

  const GiftUser({
    required this.id,
    required this.name,
    required this.username,
    required this.rating,
    required this.completedGifts,
    required this.karmaPoints,
    required this.joinedDate,
    required this.isVerified,
    this.profileImageUrl,
    this.badges = const [],
  });

  factory GiftUser.fromJson(Map<String, dynamic> json) {
    // Support both nested profile structure (from API) and flat structure
    final profile = json['profile'] as Map<String, dynamic>?;
    final displayName = profile?['displayName'] as String? ?? json['displayName'] as String? ?? json['name'] as String?;
    final avatarKey = profile?['avatarKey'] as String? ?? json['avatarKey'] as String? ?? json['profileImageUrl'] as String? ?? json['profile_image_url'] as String?;
    
    return GiftUser(
      id: json['id'] as String,
      name: displayName ?? 'Unknown User',
      username: json['username'] as String? ?? '@${displayName?.replaceAll(' ', '').toLowerCase() ?? 'user'}',
      rating: ((json['rating'] ?? 0) as num).toDouble(),
      completedGifts: (json['completedGifts'] ?? json['completed_gifts'] ?? 0) as int,
      karmaPoints: (json['karmaPoints'] ?? json['karma_points'] ?? 0) as int,
      joinedDate: json['joinedDate'] != null 
          ? DateTime.parse(json['joinedDate'] as String)
          : (json['joined_date'] != null 
              ? DateTime.parse(json['joined_date'] as String)
              : DateTime.now()),
      isVerified: (json['isVerified'] ?? json['is_verified'] ?? false) as bool,
      profileImageUrl: avatarKey,
      badges: List<String>.from(json['badges'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'rating': rating,
      'completed_gifts': completedGifts,
      'karma_points': karmaPoints,
      'joined_date': joinedDate.toIso8601String(),
      'is_verified': isVerified,
      'profile_image_url': profileImageUrl,
      'badges': badges,
    };
  }
}

// Gift Types Enum
enum GiftType {
  random('Random Gift', 'Anyone can claim', Icons.card_giftcard, Colors.purple),
  targeted('Targeted Gift', 'Specific user/criteria', Icons.person_pin, AppColors.primary),
  skill('Skill Gift', 'Offer services/knowledge', Icons.school, Colors.green),
  experience('Experience Gift', 'Events, workshops', Icons.local_activity, Colors.orange),
  digital('Digital Gift', 'E-books, courses', Icons.computer, AppColors.primaryDark);

  const GiftType(this.label, this.description, this.icon, this.color);

  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

// Gift Status Enum
enum GiftStatus {
  active('Active', Colors.green),
  pending('Pending', Colors.orange),
  claimed('Claimed', AppColors.primary),
  expired('Expired', Colors.red),
  completed('Completed', Colors.grey);

  const GiftStatus(this.label, this.color);

  final String label;
  final Color color;
}

// Gift Category Enum
enum GiftCategory {
  electronics('Electronics', Icons.devices, AppColors.primary),
  food('Food & Drink', Icons.restaurant, Colors.orange),
  books('Books', Icons.menu_book, Colors.green),
  clothing('Clothing', Icons.checkroom, Colors.pink),
  services('Services', Icons.build, Colors.purple),
  health('Health & Wellness', Icons.favorite, Colors.red),
  education('Education', Icons.school, AppColors.primaryDark),
  travel('Travel', Icons.flight, Colors.teal),
  arts('Arts & Crafts', Icons.palette, Colors.deepOrange),
  sports('Sports', Icons.sports_soccer, Colors.lightGreen),
  technology('Technology', Icons.computer, AppColors.primaryLight),
  others('Others', Icons.category, Colors.grey);

  const GiftCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

// KARMA Level Requirements
enum KarmaLevel {
  bronze(0, 'Bronze', Colors.brown),
  silver(100, 'Silver', Colors.grey),
  gold(500, 'Gold', Colors.amber),
  platinum(1000, 'Platinum', AppColors.primaryMuted),
  diamond(2500, 'Diamond', AppColors.primaryLight);

  const KarmaLevel(this.requiredPoints, this.label, this.color);

  final int requiredPoints;
  final String label;
  final Color color;

  static KarmaLevel getLevel(int points) {
    if (points >= diamond.requiredPoints) return diamond;
    if (points >= platinum.requiredPoints) return platinum;
    if (points >= gold.requiredPoints) return gold;
    if (points >= silver.requiredPoints) return silver;
    return bronze;
  }
}

// Main Gift Model
class Gift {
  final String id;
  final String title;
  final String description;
  final GiftUser giver;
  final GiftType type;
  final GiftCategory category;
  final GiftStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? claimedAt;
  final GiftUser? claimedBy;
  final int karmaReward;
  final KarmaLevel? minimumKarmaLevel;
  final String? location;
  final bool isLocationRestricted;
  final int maxClaims;
  final int currentClaims;
  final List<String> imageUrls;
  final String? mediaType;
  final String? videoKey;
  final String? thumbnailKey;
  final Map<String, dynamic> metadata;
  final List<String> tags;
  final String? targetUserId;
  final Map<String, dynamic>? targetCriteria;
  final bool isChainGift;
  final String? chainParentId;
  final int viewCount;
  final int likeCount;
  final int requestCount;
  final double rating;
  final List<GiftReview> reviews;
  final bool isFeatured;
  final bool isSurpriseGift;

  const Gift({
    required this.id,
    required this.title,
    required this.description,
    required this.giver,
    required this.type,
    required this.category,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.claimedAt,
    this.claimedBy,
    required this.karmaReward,
    this.minimumKarmaLevel,
    this.location,
    this.isLocationRestricted = false,
    this.maxClaims = 1,
    this.currentClaims = 0,
    this.imageUrls = const [],
    this.mediaType,
    this.videoKey,
    this.thumbnailKey,
    this.metadata = const {},
    this.tags = const [],
    this.targetUserId,
    this.targetCriteria,
    this.isChainGift = false,
    this.chainParentId,
    this.viewCount = 0,
    this.likeCount = 0,
    this.requestCount = 0,
    this.rating = 0.0,
    this.reviews = const [],
    this.isFeatured = false,
    this.isSurpriseGift = false,
  });

  // Helper methods
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isAvailable => status == GiftStatus.active && !isExpired && currentClaims < maxClaims;
  bool get isClaimable => isAvailable && (minimumKarmaLevel == null);
  
  String get timeRemaining {
    if (expiresAt == null) return '';
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return 'Expired';
    
    final difference = expiresAt!.difference(now);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h remaining';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m remaining';
    } else {
      return '${difference.inMinutes}m remaining';
    }
  }

  Color get statusColor => status.color;
  IconData get categoryIcon => category.icon;
  Color get categoryColor => category.color;
  IconData get typeIcon => type.icon;
  Color get typeColor => type.color;

  ListingMediaFields get listingMedia {
    final isVideo = (mediaType?.toUpperCase() == 'VIDEO') ||
        ((videoKey ?? '').isNotEmpty && imageUrls.isEmpty);
    return ListingMediaFields(
      mediaType: isVideo ? ListingMediaType.video : ListingMediaType.image,
      mediaKeys: imageUrls,
      videoKey: videoKey,
      thumbnailKey: thumbnailKey,
    );
  }

  factory Gift.fromJson(Map<String, dynamic> json) {
    return Gift(
      id: json['id'] as String,
      title: json['title'] as String,
      description: (json['description'] ?? '') as String,
      giver: GiftUser.fromJson(json['giver'] as Map<String, dynamic>),
      type: GiftType.values.firstWhere(
        (t) => t.name.toLowerCase() == (json['type'] as String).toLowerCase(),
        orElse: () => GiftType.random,
      ),
      category: GiftCategory.values.firstWhere(
        (c) => c.name.toLowerCase() == (json['category'] as String).toLowerCase(),
        orElse: () => GiftCategory.others,
      ),
      status: GiftStatus.values.firstWhere(
        (s) => s.name.toLowerCase() == (json['status'] as String).toLowerCase(),
        orElse: () => GiftStatus.active,
      ),
      createdAt: DateTime.parse((json['createdAt'] ?? json['created_at']) as String),
      expiresAt: (json['expiresAt'] ?? json['expires_at']) != null 
          ? DateTime.parse((json['expiresAt'] ?? json['expires_at']) as String) 
          : null,
      claimedAt: (json['claimedAt'] ?? json['claimed_at']) != null 
          ? DateTime.parse((json['claimedAt'] ?? json['claimed_at']) as String) 
          : null,
      claimedBy: (json['claimedBy'] ?? json['claimed_by']) != null 
          ? GiftUser.fromJson((json['claimedBy'] ?? json['claimed_by']) as Map<String, dynamic>) 
          : null,
      karmaReward: (json['karmaReward'] ?? json['karma_reward']) as int,
      minimumKarmaLevel: (json['minimumKarmaLevel'] ?? json['minimum_karma_level']) != null 
          ? KarmaLevel.values.firstWhere(
              (l) => l.name == (json['minimumKarmaLevel'] ?? json['minimum_karma_level']),
              orElse: () => KarmaLevel.bronze,
            )
          : null,
      location: json['location'] as String?,
      isLocationRestricted: (json['isLocationRestricted'] ?? json['is_location_restricted'] ?? false) as bool,
      maxClaims: (json['maxClaims'] ?? json['max_claims'] ?? 1) as int,
      currentClaims: (json['currentClaims'] ?? json['current_claims'] ?? 0) as int,
      imageUrls: List<String>.from((json['mediaKeys'] ?? json['imageUrls'] ?? json['image_urls']) ?? []),
      mediaType: json['mediaType']?.toString(),
      videoKey: json['videoKey']?.toString(),
      thumbnailKey: json['thumbnailKey']?.toString(),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      tags: List<String>.from(json['tags'] ?? []),
      targetUserId: (json['targetUserId'] ?? json['target_user_id']) as String?,
      targetCriteria: (json['targetCriteria'] ?? json['target_criteria']) as Map<String, dynamic>?,
      isChainGift: (json['isChainGift'] ?? json['is_chain_gift'] ?? false) as bool,
      chainParentId: (json['chainParentId'] ?? json['chain_parent_id']) as String?,
      viewCount: (json['viewCount'] ?? json['view_count'] ?? 0) as int,
      likeCount: (json['likeCount'] ?? json['like_count'] ?? (json['metadata'] as Map?)?['likes'] ?? 0) as int,
      requestCount: (json['requestCount'] ?? json['request_count'] ?? 0) as int,
      rating: ((json['rating'] ?? 0) as num).toDouble(),
      reviews: (json['reviews'] as List<dynamic>?)
          ?.map((r) => GiftReview.fromJson(r as Map<String, dynamic>))
          .toList() ?? [],
      isFeatured: (json['isFeatured'] ?? json['is_featured'] ?? false) as bool,
      isSurpriseGift: (json['isSurpriseGift'] ?? json['is_surprise_gift'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'giver': giver.toJson(),
      'type': type.name,
      'category': category.name,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'claimed_at': claimedAt?.toIso8601String(),
      'claimed_by': claimedBy?.toJson(),
      'karma_reward': karmaReward,
      'minimum_karma_level': minimumKarmaLevel?.name,
      'location': location,
      'is_location_restricted': isLocationRestricted,
      'max_claims': maxClaims,
      'current_claims': currentClaims,
      'image_urls': imageUrls,
      'metadata': metadata,
      'tags': tags,
      'target_user_id': targetUserId,
      'target_criteria': targetCriteria,
      'is_chain_gift': isChainGift,
      'chain_parent_id': chainParentId,
      'view_count': viewCount,
      'like_count': likeCount,
      'request_count': requestCount,
      'rating': rating,
      'reviews': reviews.map((r) => r.toJson()).toList(),
      'is_featured': isFeatured,
      'is_surprise_gift': isSurpriseGift,
    };
  }
}

// Gift Request Model
class GiftRequest {
  final String id;
  final String giftId;
  final Gift gift;
  final GiftUser requester;
  final String? message;
  final DateTime createdAt;
  final GiftRequestStatus status;
  final DateTime? respondedAt;
  final String? responseMessage;

  const GiftRequest({
    required this.id,
    required this.giftId,
    required this.gift,
    required this.requester,
    this.message,
    required this.createdAt,
    required this.status,
    this.respondedAt,
    this.responseMessage,
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

  factory GiftRequest.fromJson(Map<String, dynamic> json) {
    return GiftRequest(
      id: json['id'] as String,
      giftId: json['giftId'] as String,
      gift: Gift.fromJson(json['gift'] as Map<String, dynamic>),
      requester: GiftUser.fromJson(json['requester'] as Map<String, dynamic>),
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: GiftRequestStatus.values.firstWhere(
        (s) => s.name.toLowerCase() == (json['status'] as String).toLowerCase(),
      ),
      respondedAt: json['respondedAt'] != null ? DateTime.parse(json['respondedAt'] as String) : null,
      responseMessage: json['responseMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'giftId': giftId,
      'gift': gift.toJson(),
      'requester': requester.toJson(),
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'respondedAt': respondedAt?.toIso8601String(),
      'responseMessage': responseMessage,
    };
  }
}

enum GiftRequestStatus {
  pending('Pending', Colors.orange),
  approved('Approved', Colors.green),
  declined('Declined', Colors.red),
  expired('Expired', Colors.grey);

  const GiftRequestStatus(this.label, this.color);

  final String label;
  final Color color;
}

// Gift Review Model
class GiftReview {
  final String id;
  final GiftUser reviewer;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final List<String> imageUrls;

  const GiftReview({
    required this.id,
    required this.reviewer,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.imageUrls = const [],
  });

  factory GiftReview.fromJson(Map<String, dynamic> json) {
    return GiftReview(
      id: json['id'] as String,
      reviewer: GiftUser.fromJson(json['reviewer'] as Map<String, dynamic>),
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      imageUrls: List<String>.from(json['image_urls'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reviewer': reviewer.toJson(),
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      'image_urls': imageUrls,
    };
  }
}

// Gift Transaction Model
class GiftTransaction {
  final String id;
  final String giftId;
  final GiftUser giver;
  final GiftUser receiver;
  final DateTime completedAt;
  final int karmaAwarded;
  final String? notes;
  final double rating;
  final String? reviewComment;

  const GiftTransaction({
    required this.id,
    required this.giftId,
    required this.giver,
    required this.receiver,
    required this.completedAt,
    required this.karmaAwarded,
    this.notes,
    this.rating = 0.0,
    this.reviewComment,
  });

  factory GiftTransaction.fromJson(Map<String, dynamic> json) {
    return GiftTransaction(
      id: json['id'] as String,
      giftId: json['gift_id'] as String,
      giver: GiftUser.fromJson(json['giver'] as Map<String, dynamic>),
      receiver: GiftUser.fromJson(json['receiver'] as Map<String, dynamic>),
      completedAt: DateTime.parse(json['completed_at'] as String),
      karmaAwarded: json['karma_awarded'] as int,
      notes: json['notes'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewComment: json['review_comment'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gift_id': giftId,
      'giver': giver.toJson(),
      'receiver': receiver.toJson(),
      'completed_at': completedAt.toIso8601String(),
      'karma_awarded': karmaAwarded,
      'notes': notes,
      'rating': rating,
      'review_comment': reviewComment,
    };
  }
}

// Gift Analytics Model
class GiftAnalytics {
  final int totalGiftsGiven;
  final int totalGiftsReceived;
  final int totalKarmaEarned;
  final double averageRating;
  final int totalViews;
  final int totalRequests;
  final Map<GiftCategory, int> categoryBreakdown;
  final Map<String, int> monthlyGifts;

  const GiftAnalytics({
    required this.totalGiftsGiven,
    required this.totalGiftsReceived,
    required this.totalKarmaEarned,
    required this.averageRating,
    required this.totalViews,
    required this.totalRequests,
    required this.categoryBreakdown,
    required this.monthlyGifts,
  });

  factory GiftAnalytics.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    }

    double asDouble(dynamic v) {
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0.0;
    }

    final rawCategories =
        json['categoryBreakdown'] ?? json['category_breakdown'];
    final categoryBreakdown = <GiftCategory, int>{};
    if (rawCategories is Map) {
      for (final entry in rawCategories.entries) {
        final key = entry.key.toString().toLowerCase();
        try {
          categoryBreakdown[GiftCategory.values.firstWhere(
            (c) => c.name.toLowerCase() == key,
          )] = asInt(entry.value);
        } catch (_) {}
      }
    }

    final rawMonthly = json['monthlyGifts'] ?? json['monthly_gifts'];
    final monthlyGifts = rawMonthly is Map
        ? Map<String, int>.from(
            rawMonthly.map((k, v) => MapEntry(k.toString(), asInt(v))),
          )
        : <String, int>{};

    return GiftAnalytics(
      totalGiftsGiven: asInt(json['totalGiftsGiven'] ?? json['total_gifts_given']),
      totalGiftsReceived:
          asInt(json['totalGiftsReceived'] ?? json['total_gifts_received']),
      totalKarmaEarned:
          asInt(json['totalKarmaEarned'] ?? json['total_karma_earned']),
      averageRating:
          asDouble(json['averageRating'] ?? json['average_rating']),
      totalViews: asInt(json['totalViews'] ?? json['total_views']),
      totalRequests: asInt(json['totalRequests'] ?? json['total_requests']),
      categoryBreakdown: categoryBreakdown,
      monthlyGifts: monthlyGifts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_gifts_given': totalGiftsGiven,
      'total_gifts_received': totalGiftsReceived,
      'total_karma_earned': totalKarmaEarned,
      'average_rating': averageRating,
      'total_views': totalViews,
      'total_requests': totalRequests,
      'category_breakdown': Map<String, int>.fromEntries(
        categoryBreakdown.entries.map((e) => MapEntry(e.key.name, e.value)),
      ),
      'monthly_gifts': monthlyGifts,
    };
  }
}

// Gift Comment Model
class GiftComment {
  final String id;
  final String giftId;
  final GiftUser author;
  final String content;
  final DateTime createdAt;
  final int likes;
  final List<GiftComment> replies;

  const GiftComment({
    required this.id,
    required this.giftId,
    required this.author,
    required this.content,
    required this.createdAt,
    this.likes = 0,
    this.replies = const [],
  });

  factory GiftComment.fromJson(Map<String, dynamic> json) {
    return GiftComment(
      id: json['id'] as String,
      giftId: json['gift_id'] as String,
      author: GiftUser.fromJson(json['author'] as Map<String, dynamic>),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      likes: json['likes'] as int? ?? 0,
      replies: (json['replies'] as List<dynamic>?)
          ?.map((r) => GiftComment.fromJson(r as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gift_id': giftId,
      'author': author.toJson(),
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'likes': likes,
      'replies': replies.map((r) => r.toJson()).toList(),
    };
  }
}

// Gift Like Model
class GiftLike {
  final String id;
  final String giftId;
  final GiftUser user;
  final DateTime createdAt;

  const GiftLike({
    required this.id,
    required this.giftId,
    required this.user,
    required this.createdAt,
  });

  factory GiftLike.fromJson(Map<String, dynamic> json) {
    return GiftLike(
      id: json['id'] as String,
      giftId: json['gift_id'] as String,
      user: GiftUser.fromJson(json['user'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gift_id': giftId,
      'user': user.toJson(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Gift Chain Model for pay-it-forward functionality
class GiftChain {
  final String id;
  final String rootGiftId;
  final List<Gift> gifts;
  final int totalLinks;
  final int totalKarmaGenerated;
  final DateTime createdAt;
  final bool isActive;

  const GiftChain({
    required this.id,
    required this.rootGiftId,
    required this.gifts,
    required this.totalLinks,
    required this.totalKarmaGenerated,
    required this.createdAt,
    required this.isActive,
  });

  factory GiftChain.fromJson(Map<String, dynamic> json) {
    return GiftChain(
      id: json['id'] as String,
      rootGiftId: json['root_gift_id'] as String,
      gifts: (json['gifts'] as List<dynamic>)
          .map((g) => Gift.fromJson(g as Map<String, dynamic>))
          .toList(),
      totalLinks: json['total_links'] as int,
      totalKarmaGenerated: json['total_karma_generated'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['is_active'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'root_gift_id': rootGiftId,
      'gifts': gifts.map((g) => g.toJson()).toList(),
      'total_links': totalLinks,
      'total_karma_generated': totalKarmaGenerated,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
    };
  }
}