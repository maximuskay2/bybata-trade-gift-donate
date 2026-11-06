enum ActivityType {
  trade,
  gift,
  donation,
  community,
  post,
  comment,
  like,
  follow,
  achievement,
  verification,
  karma,
}

enum ActivityStatus {
  pending,
  completed,
  failed,
  cancelled,
}

class Activity {
  final String id;
  final String userId;
  final ActivityType type;
  final ActivityStatus status;
  final String title;
  final String description;
  final Map<String, dynamic> metadata;
  final String? relatedUserId;
  final String? relatedItemId;
  final int? karmaPoints;
  final DateTime createdAt;
  final DateTime? completedAt;

  Activity({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    this.metadata = const {},
    this.relatedUserId,
    this.relatedItemId,
    this.karmaPoints,
    required this.createdAt,
    this.completedAt,
  });

  String get typeDisplayName {
    switch (type) {
      case ActivityType.trade:
        return 'Trade';
      case ActivityType.gift:
        return 'Gift';
      case ActivityType.donation:
        return 'Donation';
      case ActivityType.community:
        return 'Community';
      case ActivityType.post:
        return 'Post';
      case ActivityType.comment:
        return 'Comment';
      case ActivityType.like:
        return 'Like';
      case ActivityType.follow:
        return 'Follow';
      case ActivityType.achievement:
        return 'Achievement';
      case ActivityType.verification:
        return 'Verification';
      case ActivityType.karma:
        return 'KARMA';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case ActivityStatus.pending:
        return 'Pending';
      case ActivityStatus.completed:
        return 'Completed';
      case ActivityStatus.failed:
        return 'Failed';
      case ActivityStatus.cancelled:
        return 'Cancelled';
    }
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      type: ActivityType.values.firstWhere(
        (e) => e.toString() == 'ActivityType.${json['type']}',
        orElse: () => ActivityType.post,
      ),
      status: ActivityStatus.values.firstWhere(
        (e) => e.toString() == 'ActivityStatus.${json['status']}',
        orElse: () => ActivityStatus.pending,
      ),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      relatedUserId: json['relatedUserId'],
      relatedItemId: json['relatedItemId'],
      karmaPoints: json['karmaPoints'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      completedAt: json['completedAt'] != null 
        ? DateTime.parse(json['completedAt'])
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'title': title,
      'description': description,
      'metadata': metadata,
      'relatedUserId': relatedUserId,
      'relatedItemId': relatedItemId,
      'karmaPoints': karmaPoints,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  Activity copyWith({
    String? id,
    String? userId,
    ActivityType? type,
    ActivityStatus? status,
    String? title,
    String? description,
    Map<String, dynamic>? metadata,
    String? relatedUserId,
    String? relatedItemId,
    int? karmaPoints,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Activity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      title: title ?? this.title,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      relatedUserId: relatedUserId ?? this.relatedUserId,
      relatedItemId: relatedItemId ?? this.relatedItemId,
      karmaPoints: karmaPoints ?? this.karmaPoints,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class ActivityFilter {
  final List<ActivityType>? types;
  final List<ActivityStatus>? statuses;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? searchQuery;
  final int? limit;
  final int? offset;

  ActivityFilter({
    this.types,
    this.statuses,
    this.startDate,
    this.endDate,
    this.searchQuery,
    this.limit,
    this.offset,
  });

  Map<String, dynamic> toJson() {
    return {
      'types': types?.map((type) => type.toString().split('.').last).toList(),
      'statuses': statuses?.map((status) => status.toString().split('.').last).toList(),
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'searchQuery': searchQuery,
      'limit': limit,
      'offset': offset,
    };
  }

  ActivityFilter copyWith({
    List<ActivityType>? types,
    List<ActivityStatus>? statuses,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    int? limit,
    int? offset,
  }) {
    return ActivityFilter(
      types: types ?? this.types,
      statuses: statuses ?? this.statuses,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      searchQuery: searchQuery ?? this.searchQuery,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}