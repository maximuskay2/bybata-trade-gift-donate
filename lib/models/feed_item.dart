import 'intent_types.dart';

class FeedItemAuthor {
  final String id;
  final String name;
  final String? avatar;
  /// Cached average rating (0..5) for this author.
  ///
  /// Backend feed/public-browse endpoints precompute this in batch
  /// (see [UsersService.getAverageRatingsBatch]) so the new 3D Glass
  /// ListingCard can render its top-row stars without per-card lookups.
  /// `null` means the value was not provided by the backend (older
  /// payloads). `0` means the user has no ratings yet.
  final double? averageRating;

  FeedItemAuthor({
    required this.id,
    required this.name,
    this.avatar,
    this.averageRating,
  });

  factory FeedItemAuthor.fromJson(Map<String, dynamic> json) {
    final raw = json['averageRating'];
    final rating = raw is num
        ? raw.toDouble()
        : raw is String
            ? double.tryParse(raw)
            : null;
    return FeedItemAuthor(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      averageRating: rating,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'averageRating': averageRating,
    };
  }
}

class FeedItem {
  final String id;
  final FeedSourceType sourceType;
  final IntentType intentType;
  final IntentSubType intentSubType;
  final String title;
  final String summary;
  final String? imageUrl;
  final String? location;
  /// Optional taxonomy (e.g. "Furniture", "Education") surfaced by the
  /// backend so the 3D Glass ListingCard can render "Category • Location"
  /// under the title. Null when the underlying entity has no category.
  final String? category;
  final DateTime createdAt;
  final FeedItemAuthor author;
  final String status;
  final Map<String, dynamic>? metadata;

  FeedItem({
    required this.id,
    required this.sourceType,
    required this.intentType,
    required this.intentSubType,
    required this.title,
    required this.summary,
    this.imageUrl,
    this.location,
    this.category,
    required this.createdAt,
    required this.author,
    required this.status,
    this.metadata,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id'] as String,
      sourceType: FeedSourceType.fromString(json['sourceType'] as String),
      intentType: IntentType.fromString(json['intentType'] as String),
      intentSubType: IntentSubType.fromString(json['intentSubType'] as String),
      title: json['title'] as String,
      summary: json['summary'] as String,
      imageUrl: json['imageUrl'] as String?,
      location: json['location'] as String?,
      category: json['category'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      author: FeedItemAuthor.fromJson(json['author'] as Map<String, dynamic>),
      status: json['status'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceType': sourceType.value,
      'intentType': intentType.value,
      'intentSubType': intentSubType.value,
      'title': title,
      'summary': summary,
      'imageUrl': imageUrl,
      'location': location,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'author': author.toJson(),
      'status': status,
      'metadata': metadata,
    };
  }
}

class HomeFeedResponse {
  final List<FeedItem> items;
  final int total;
  final int page;
  final int size;
  final int totalPages;

  HomeFeedResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
    required this.totalPages,
  });

  factory HomeFeedResponse.fromJson(Map<String, dynamic> json) {
    return HomeFeedResponse(
      items: (json['items'] as List<dynamic>)
          .map((item) => FeedItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      size: json['size'] as int,
      totalPages: json['totalPages'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
      'total': total,
      'page': page,
      'size': size,
      'totalPages': totalPages,
    };
  }
}
