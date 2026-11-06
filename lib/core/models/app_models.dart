import 'package:flutter/foundation.dart';

/// User model for authentication and profile data
class AppUser {
  final String id;
  final String email;
  final String? phoneNumber;
  final String displayName;
  final String? photoUrl;
  final String? coverImageUrl;
  final String? bio;
  final String? location;
  final DateTime createdAt;
  final DateTime lastSeen;
  final bool isVerified;
  final bool isEmailVerified;
  final bool isOnline;
  final int karmaPoints;
  final double rating;
  final int followersCount;
  final int followingCount;
  final List<String> badges;
  final Map<String, dynamic>? preferences;

  const AppUser({
    required this.id,
    required this.email,
    this.phoneNumber,
    required this.displayName,
    this.photoUrl,
    this.coverImageUrl,
    this.bio,
    this.location,
    required this.createdAt,
    required this.lastSeen,
    this.isVerified = false,
    this.isEmailVerified = false,
    this.isOnline = false,
    this.karmaPoints = 0,
    this.rating = 0.0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.badges = const [],
    this.preferences,
  });

  AppUser copyWith({
    String? id,
    String? email,
    String? phoneNumber,
    String? displayName,
    String? photoUrl,
    String? coverImageUrl,
    String? bio,
    String? location,
    DateTime? createdAt,
    DateTime? lastSeen,
    bool? isVerified,
    bool? isEmailVerified,
    bool? isOnline,
    int? karmaPoints,
    double? rating,
    int? followersCount,
    int? followingCount,
    List<String>? badges,
    Map<String, dynamic>? preferences,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isVerified: isVerified ?? this.isVerified,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isOnline: isOnline ?? this.isOnline,
      karmaPoints: karmaPoints ?? this.karmaPoints,
      rating: rating ?? this.rating,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      badges: badges ?? this.badges,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'coverImageUrl': coverImageUrl,
      'bio': bio,
      'location': location,
      'createdAt': createdAt.toIso8601String(),
      'lastSeen': lastSeen.toIso8601String(),
      'isVerified': isVerified,
      'isEmailVerified': isEmailVerified,
      'isOnline': isOnline,
      'karmaPoints': karmaPoints,
      'rating': rating,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'badges': badges,
      'preferences': preferences,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      isVerified: json['isVerified'] as bool? ?? false,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      isOnline: json['isOnline'] as bool? ?? false,
      karmaPoints: json['karmaPoints'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      badges: List<String>.from(json['badges'] as List? ?? []),
      preferences: json['preferences'] as Map<String, dynamic>?,
    );
  }
}

/// KARMA level configuration
class KarmaLevel {
  final int level;
  final String title;
  final int minPoints;
  final int maxPoints;
  final String color;
  final String icon;
  final List<String> perks;

  const KarmaLevel({
    required this.level,
    required this.title,
    required this.minPoints,
    required this.maxPoints,
    required this.color,
    required this.icon,
    required this.perks,
  });
}

/// Trade item model
class TradeItem {
  final String id;
  final String title;
  final String description;
  final List<String> images;
  final String category;
  final String condition;
  final double? price;
  final String? currency;
  final String sellerId;
  final String sellerName;
  final String? sellerImageUrl;
  final double? sellerRating;
  final String? location;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TradeItemStatus status;
  final Map<String, dynamic>? metadata;

  const TradeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.images,
    required this.category,
    required this.condition,
    this.price,
    this.currency,
    required this.sellerId,
    required this.sellerName,
    this.sellerImageUrl,
    this.sellerRating,
    this.location,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.metadata,
  });

  TradeItem copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? images,
    String? category,
    String? condition,
    double? price,
    String? currency,
    String? sellerId,
    String? sellerName,
    String? sellerImageUrl,
    double? sellerRating,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
    TradeItemStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return TradeItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      images: images ?? this.images,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerImageUrl: sellerImageUrl ?? this.sellerImageUrl,
      sellerRating: sellerRating ?? this.sellerRating,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Gift item model
class GiftItem {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final String currency;
  final String? brandName;
  final String? brandLogo;
  final String category;
  final bool isDigital;
  final int availableQuantity;
  final DateTime? expiryDate;
  final bool isFeatured;
  final DateTime createdAt;
  final GiftItemStatus status;

  const GiftItem({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.currency,
    this.brandName,
    this.brandLogo,
    required this.category,
    this.isDigital = false,
    required this.availableQuantity,
    this.expiryDate,
    this.isFeatured = false,
    required this.createdAt,
    required this.status,
  });
}

/// Campaign model
class Campaign {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String organizerId;
  final String organizerName;
  final String? organizerImageUrl;
  final double targetAmount;
  final double currentAmount;
  final String currency;
  final DateTime startDate;
  final DateTime endDate;
  final String category;
  final bool isVerified;
  final bool isUrgent;
  final List<String> supporters;
  final CampaignStatus status;

  const Campaign({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.organizerId,
    required this.organizerName,
    this.organizerImageUrl,
    required this.targetAmount,
    required this.currentAmount,
    required this.currency,
    required this.startDate,
    required this.endDate,
    required this.category,
    this.isVerified = false,
    this.isUrgent = false,
    required this.supporters,
    required this.status,
  });

  int get daysLeft {
    final now = DateTime.now();
    if (endDate.isBefore(now)) return 0;
    return endDate.difference(now).inDays;
  }

  double get progress => targetAmount > 0 ? currentAmount / targetAmount : 0.0;
}

/// Community model
class Community {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String? coverImageUrl;
  final String adminId;
  final String category;
  final bool isPublic;
  final bool isVerified;
  final List<String> members;
  final List<String> moderators;
  final DateTime createdAt;
  final CommunityStatus status;
  final Map<String, dynamic>? rules;

  const Community({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    this.coverImageUrl,
    required this.adminId,
    required this.category,
    this.isPublic = true,
    this.isVerified = false,
    required this.members,
    required this.moderators,
    required this.createdAt,
    required this.status,
    this.rules,
  });

  int get memberCount => members.length;
}

/// Transaction model
class BYCTransaction {
  final String id;
  final String title;
  final String? description;
  final double amount;
  final String currency;
  final TransactionType type;
  final TransactionStatus status;
  final String? fromUserId;
  final String? toUserId;
  final String? fromUserName;
  final String? toUserName;
  final String? reference;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const BYCTransaction({
    required this.id,
    required this.title,
    this.description,
    required this.amount,
    required this.currency,
    required this.type,
    required this.status,
    this.fromUserId,
    this.toUserId,
    this.fromUserName,
    this.toUserName,
    this.reference,
    required this.createdAt,
    this.metadata,
  });
}

/// Wallet model
class Wallet {
  final String id;
  final String userId;
  final double bycBalance;
  final double pendingBalance;
  final String currency;
  final DateTime lastUpdated;
  final List<BYCTransaction> recentTransactions;

  const Wallet({
    required this.id,
    required this.userId,
    required this.bycBalance,
    this.pendingBalance = 0.0,
    this.currency = 'BYC',
    required this.lastUpdated,
    this.recentTransactions = const [],
  });

  double get totalBalance => bycBalance + pendingBalance;

  Wallet copyWith({
    String? id,
    String? userId,
    double? bycBalance,
    double? pendingBalance,
    String? currency,
    DateTime? lastUpdated,
    List<BYCTransaction>? recentTransactions,
  }) {
    return Wallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bycBalance: bycBalance ?? this.bycBalance,
      pendingBalance: pendingBalance ?? this.pendingBalance,
      currency: currency ?? this.currency,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      recentTransactions: recentTransactions ?? this.recentTransactions,
    );
  }
}

/// Notification model
class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final String? imageUrl;
  final String? targetId;
  final String? actionUrl;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.imageUrl,
    this.targetId,
    this.actionUrl,
    this.isRead = false,
    required this.createdAt,
    this.data,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    String? imageUrl,
    String? targetId,
    String? actionUrl,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      targetId: targetId ?? this.targetId,
      actionUrl: actionUrl ?? this.actionUrl,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
    );
  }
}

/// Achievement model
class Achievement {
  final String id;
  final String title;
  final String description;
  final String? iconUrl;
  final int karmaPoints;
  final String badgeType;
  final DateTime? unlockedAt;
  final bool isUnlocked;
  final double? progress;
  final String? requirement;
  final AchievementCategory category;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    this.iconUrl,
    required this.karmaPoints,
    required this.badgeType,
    this.unlockedAt,
    this.isUnlocked = false,
    this.progress,
    this.requirement,
    required this.category,
  });

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? iconUrl,
    int? karmaPoints,
    String? badgeType,
    DateTime? unlockedAt,
    bool? isUnlocked,
    double? progress,
    String? requirement,
    AchievementCategory? category,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      karmaPoints: karmaPoints ?? this.karmaPoints,
      badgeType: badgeType ?? this.badgeType,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      progress: progress ?? this.progress,
      requirement: requirement ?? this.requirement,
      category: category ?? this.category,
    );
  }
}

/// Enumerations
enum AuthStatus { authenticated, unauthenticated, loading }
enum TradeItemStatus { active, sold, inactive, pending }
enum GiftItemStatus { available, outOfStock, discontinued }
enum CampaignStatus { active, completed, cancelled, draft }
enum CommunityStatus { active, inactive, suspended }
enum TransactionType { sent, received, purchase, refund, reward, fee }
enum TransactionStatus { completed, pending, failed, cancelled }
enum NotificationType { message, trade, gift, campaign, achievement, system, reminder }
enum AchievementCategory { trading, donations, community, social, milestones }