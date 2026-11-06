import 'package:flutter/material.dart';

import '../../../core/utils/listing_category_parser.dart';

/// Enum for different search categories
enum SearchCategory {
  all('All'),
  trades('Trades'),
  gifts('Gifts'), 
  campaigns('Campaigns'),
  communities('Communities'),
  users('Users');

  const SearchCategory(this.displayName);
  final String displayName;

  IconData get icon {
    switch (this) {
      case SearchCategory.all:
        return Icons.search;
      case SearchCategory.trades:
        return Icons.swap_horiz;
      case SearchCategory.gifts:
        return Icons.card_giftcard;
      case SearchCategory.campaigns:
        return Icons.campaign;
      case SearchCategory.communities:
        return Icons.groups;
      case SearchCategory.users:
        return Icons.person;
    }
  }
}

/// Enum for sorting search results
enum SearchSort {
  relevance('Most Relevant'),
  newest('Newest First'),
  oldest('Oldest First'),
  popular('Most Popular'),
  nearby('Nearest First');

  const SearchSort(this.displayName);
  final String displayName;
}

/// Model for search filters
class SearchFilters {
  final SearchCategory category;
  final SearchSort sortBy;
  final String? location;
  final double? maxDistance;
  final DateTimeRange? dateRange;
  final List<String> tags;
  final double? minRating;
  final bool verified;

  const SearchFilters({
    this.category = SearchCategory.all,
    this.sortBy = SearchSort.relevance,
    this.location,
    this.maxDistance,
    this.dateRange,
    this.tags = const [],
    this.minRating,
    this.verified = false,
  });

  SearchFilters copyWith({
    SearchCategory? category,
    SearchSort? sortBy,
    String? location,
    double? maxDistance,
    DateTimeRange? dateRange,
    List<String>? tags,
    double? minRating,
    bool? verified,
  }) {
    return SearchFilters(
      category: category ?? this.category,
      sortBy: sortBy ?? this.sortBy,
      location: location ?? this.location,
      maxDistance: maxDistance ?? this.maxDistance,
      dateRange: dateRange ?? this.dateRange,
      tags: tags ?? this.tags,
      minRating: minRating ?? this.minRating,
      verified: verified ?? this.verified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category.name,
      'sortBy': sortBy.name,
      'location': location,
      'maxDistance': maxDistance,
      'dateRange': dateRange != null ? {
        'start': dateRange!.start.toIso8601String(),
        'end': dateRange!.end.toIso8601String(),
      } : null,
      'tags': tags,
      'minRating': minRating,
      'verified': verified,
    };
  }

  factory SearchFilters.fromJson(Map<String, dynamic> json) {
    return SearchFilters(
      category: SearchCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => SearchCategory.all,
      ),
      sortBy: SearchSort.values.firstWhere(
        (s) => s.name == json['sortBy'],
        orElse: () => SearchSort.relevance,
      ),
      location: json['location'] as String?,
      maxDistance: (json['maxDistance'] as num?)?.toDouble(),
      dateRange: json['dateRange'] != null 
          ? DateTimeRange(
              start: DateTime.parse(json['dateRange']['start'] as String),
              end: DateTime.parse(json['dateRange']['end'] as String),
            )
          : null,
      tags: List<String>.from(json['tags'] as List? ?? []),
      minRating: (json['minRating'] as num?)?.toDouble(),
      verified: json['verified'] as bool? ?? false,
    );
  }
}

/// Model for search history item
class SearchHistoryItem {
  final String id;
  final String query;
  final SearchCategory category;
  final DateTime timestamp;
  final int resultCount;

  const SearchHistoryItem({
    required this.id,
    required this.query,
    required this.category,
    required this.timestamp,
    required this.resultCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'query': query,
      'category': category.name,
      'timestamp': timestamp.toIso8601String(),
      'resultCount': resultCount,
    };
  }

  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) {
    return SearchHistoryItem(
      id: json['id'] as String,
      query: json['query'] as String,
      category: SearchCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => SearchCategory.all,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      resultCount: json['resultCount'] as int,
    );
  }
}

/// Model for trending search term
class TrendingSearch {
  final String query;
  final SearchCategory category;
  final int searchCount;
  final double trendingScore;
  final String? changeIndicator;

  const TrendingSearch({
    required this.query,
    required this.category,
    required this.searchCount,
    required this.trendingScore,
    this.changeIndicator,
  });

  factory TrendingSearch.fromJson(Map<String, dynamic> json) {
    return TrendingSearch(
      query: json['query'] as String,
      category: SearchCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => SearchCategory.all,
      ),
      searchCount: json['searchCount'] as int,
      trendingScore: (json['trendingScore'] as num).toDouble(),
      changeIndicator: json['changeIndicator'] as String?,
    );
  }
}

/// Base class for search results
abstract class SearchResult {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final DateTime createdAt;
  final SearchCategory category;
  final double relevanceScore;
  final List<String> tags;
  final String? location;

  const SearchResult({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.createdAt,
    required this.category,
    required this.relevanceScore,
    this.tags = const [],
    this.location,
  });
}

/// Trade search result
class TradeSearchResult extends SearchResult {
  final String ownerId;
  final String ownerName;
  final String? ownerAvatar;
  final String condition;
  final bool isActive;
  final double? estimatedValue;

  const TradeSearchResult({
    required super.id,
    required super.title,
    required super.description,
    super.imageUrl,
    required super.createdAt,
    required super.relevanceScore,
    super.tags,
    super.location,
    required this.ownerId,
    required this.ownerName,
    this.ownerAvatar,
    required this.condition,
    required this.isActive,
    this.estimatedValue,
  }) : super(category: SearchCategory.trades);

  factory TradeSearchResult.fromJson(Map<String, dynamic> json) {
    return TradeSearchResult(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      relevanceScore: (json['relevanceScore'] as num).toDouble(),
      tags: List<String>.from(json['tags'] as List? ?? []),
      location: json['location'] as String?,
      ownerId: json['ownerId'] as String,
      ownerName: json['ownerName'] as String,
      ownerAvatar: json['ownerAvatar'] as String?,
      condition: json['condition'] as String,
      isActive: json['isActive'] as bool,
      estimatedValue: (json['estimatedValue'] as num?)?.toDouble(),
    );
  }
}

/// Gift search result
class GiftSearchResult extends SearchResult {
  final String giverId;
  final String giverName;
  final String? giverAvatar;
  final DateTime? expiresAt;
  final int maxClaims;
  final int currentClaims;
  final bool isAvailable;

  const GiftSearchResult({
    required super.id,
    required super.title,
    required super.description,
    super.imageUrl,
    required super.createdAt,
    required super.relevanceScore,
    super.tags,
    required this.giverId,
    required this.giverName,
    this.giverAvatar,
    this.expiresAt,
    required this.maxClaims,
    required this.currentClaims,
    required this.isAvailable,
  }) : super(category: SearchCategory.gifts);

  factory GiftSearchResult.fromJson(Map<String, dynamic> json) {
    return GiftSearchResult(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      relevanceScore: (json['relevanceScore'] as num).toDouble(),
      tags: List<String>.from(json['tags'] as List? ?? []),
      giverId: json['giverId'] as String,
      giverName: json['giverName'] as String,
      giverAvatar: json['giverAvatar'] as String?,
      expiresAt: json['expiresAt'] != null 
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      maxClaims: json['maxClaims'] as int,
      currentClaims: json['currentClaims'] as int,
      isAvailable: json['isAvailable'] as bool,
    );
  }
}

/// Campaign search result
class CampaignSearchResult extends SearchResult {
  final String creatorId;
  final String creatorName;
  final String? creatorAvatar;
  final double goalAmount;
  final double currentAmount;
  final DateTime? deadline;
  final bool isActive;

  const CampaignSearchResult({
    required super.id,
    required super.title,
    required super.description,
    super.imageUrl,
    required super.createdAt,
    required super.relevanceScore,
    super.tags,
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatar,
    required this.goalAmount,
    required this.currentAmount,
    this.deadline,
    required this.isActive,
  }) : super(category: SearchCategory.campaigns);

  double get progressPercentage => currentAmount / goalAmount;
  double get progress => (currentAmount / goalAmount) * 100;

  factory CampaignSearchResult.fromJson(Map<String, dynamic> json) {
    return CampaignSearchResult(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      relevanceScore: (json['relevanceScore'] as num).toDouble(),
      tags: List<String>.from(json['tags'] as List? ?? []),
      creatorId: json['creatorId'] as String,
      creatorName: json['creatorName'] as String,
      creatorAvatar: json['creatorAvatar'] as String?,
      goalAmount: (json['goalAmount'] as num).toDouble(),
      currentAmount: (json['currentAmount'] as num).toDouble(),
      deadline: json['deadline'] != null 
          ? DateTime.parse(json['deadline'] as String)
          : null,
      isActive: json['isActive'] as bool,
    );
  }
}

/// Community search result
class CommunitySearchResult extends SearchResult {
  final int memberCount;
  final bool isPublic;
  final bool isJoined;
  final String? location;

  const CommunitySearchResult({
    required super.id,
    required super.title,
    required super.description,
    super.imageUrl,
    required super.createdAt,
    required super.relevanceScore,
    super.tags,
    required this.memberCount,
    required this.isPublic,
    required this.isJoined,
    this.location,
  }) : super(category: SearchCategory.communities);

  factory CommunitySearchResult.fromJson(Map<String, dynamic> json) {
    return CommunitySearchResult(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      relevanceScore: (json['relevanceScore'] as num).toDouble(),
      tags: List<String>.from(json['tags'] as List? ?? []),
      memberCount: json['memberCount'] as int,
      isPublic: json['isPublic'] as bool,
      isJoined: json['isJoined'] as bool,
      location: json['location'] as String?,
    );
  }
}

/// User search result
class UserSearchResult extends SearchResult {
  final String username;
  final String? avatarUrl;
  final double? rating;
  final int karmaPoints;
  final String? location;
  final bool isVerified;
  final bool isFollowed;

  const UserSearchResult({
    required super.id,
    required super.title, // Display name
    required super.description, // Bio
    super.imageUrl, // Same as avatarUrl
    required super.createdAt,
    required super.relevanceScore,
    super.tags,
    required this.username,
    this.avatarUrl,
    this.rating,
    required this.karmaPoints,
    this.location,
    required this.isVerified,
    required this.isFollowed,
  }) : super(category: SearchCategory.users);

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'] as String,
      title: json['displayName'] as String,
      description: json['bio'] as String? ?? '',
      imageUrl: json['avatarUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      relevanceScore: (json['relevanceScore'] as num).toDouble(),
      tags: List<String>.from(json['tags'] as List? ?? []),
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      karmaPoints: json['karmaPoints'] as int,
      location: json['location'] as String?,
      isVerified: json['isVerified'] as bool,
      isFollowed: json['isFollowed'] as bool,
    );
  }
}

/// Search response model
class SearchResponse {
  final List<SearchResult> results;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final String query;
  final SearchFilters filters;
  final Map<SearchCategory, int> categoryCounts;

  const SearchResponse({
    required this.results,
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.query,
    required this.filters,
    required this.categoryCounts,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    final resultsJson = json['results'] as List<dynamic>;
    final results = resultsJson.map((resultJson) {
      final map = resultJson as Map<String, dynamic>;
      final category = ListingCategoryParser.parseSearchCategory(
        map['category']?.toString(),
      );

      switch (category) {
        case SearchCategory.trades:
          return TradeSearchResult.fromJson(map);
        case SearchCategory.gifts:
          return GiftSearchResult.fromJson(map);
        case SearchCategory.campaigns:
          return CampaignSearchResult.fromJson(map);
        case SearchCategory.communities:
          return CommunitySearchResult.fromJson(map);
        case SearchCategory.users:
          return UserSearchResult.fromJson(map);
        case SearchCategory.all:
          // Unknown category — best-effort trade parse so mixed feeds never crash.
          try {
            return TradeSearchResult.fromJson(map);
          } catch (_) {
            return GiftSearchResult.fromJson(map);
          }
      }
    }).toList();

    return SearchResponse(
      results: results,
      totalCount: json['totalCount'] as int,
      currentPage: json['currentPage'] as int,
      totalPages: json['totalPages'] as int,
      query: json['query'] as String,
      filters: SearchFilters.fromJson(json['filters'] as Map<String, dynamic>),
      categoryCounts: Map<SearchCategory, int>.fromEntries(
        (json['categoryCounts'] as Map<String, dynamic>).entries.map(
          (entry) => MapEntry(
            SearchCategory.values.firstWhere(
              (c) => c.name == entry.key,
              orElse: () => SearchCategory.all,
            ),
            entry.value as int,
          ),
        ),
      ),
    );
  }
}

