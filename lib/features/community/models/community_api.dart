/// Community API response model (simplified for API responses)
library;

/// Community API model for API responses
class CommunityApi {
  final String id;
  final String name;
  final String? description;
  final String? shortDescription;
  final String? category;
  final String? type;
  final String? status;
  final String? imageUrl;
  final double? centerLatitude;
  final double? centerLongitude;
  final String? location;
  final List<String> tags;
  final String? rules;
  final int memberCount;
  final int postCount;
  final int eventCount;
  final String createdById;
  final bool isFeatured;
  final bool isVerified;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? settings;
  final double? distanceMeters; // For nearby communities

  const CommunityApi({
    required this.id,
    required this.name,
    this.description,
    this.shortDescription,
    this.category,
    this.type,
    this.status,
    this.imageUrl,
    this.centerLatitude,
    this.centerLongitude,
    this.location,
    this.tags = const [],
    this.rules,
    this.memberCount = 0,
    this.postCount = 0,
    this.eventCount = 0,
    required this.createdById,
    this.isFeatured = false,
    this.isVerified = false,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.settings,
    this.distanceMeters,
  });

  factory CommunityApi.fromJson(Map<String, dynamic> json) {
    final memberCount = json['memberCount'] ?? 
                      (json['_count'] != null ? json['_count']['members'] : 0) ?? 0;
    final postCount = json['postCount'] ?? 
                     (json['_count'] != null ? json['_count']['posts'] : 0) ?? 0;
    final eventCount = json['eventCount'] ?? 
                      (json['_count'] != null ? json['_count']['events'] : 0) ?? 0;
    
    return CommunityApi(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      shortDescription: json['shortDescription'],
      category: json['category'],
      type: json['type'],
      status: json['status'],
      imageUrl: json['imageUrl'],
      centerLatitude: json['centerLatitude'] is int 
          ? (json['centerLatitude'] as int).toDouble() 
          : json['centerLatitude'],
      centerLongitude: json['centerLongitude'] is int 
          ? (json['centerLongitude'] as int).toDouble() 
          : json['centerLongitude'],
      location: json['location'],
      tags: List<String>.from(json['tags'] ?? []),
      rules: json['rules'],
      memberCount: memberCount,
      postCount: postCount,
      eventCount: eventCount,
      createdById: json['createdById'] ?? json['created_by_id'] ?? '',
      isFeatured: json['isFeatured'] ?? json['is_featured'] ?? false,
      isVerified: json['isVerified'] ?? json['is_verified'] ?? false,
      metadata: json['metadata'],
      createdAt: json['createdAt'] is String 
          ? DateTime.parse(json['createdAt']) 
          : json['createdAt'] is DateTime 
              ? json['createdAt'] 
              : DateTime.now(),
      updatedAt: json['updatedAt'] is String 
          ? DateTime.parse(json['updatedAt']) 
          : json['updatedAt'] is DateTime 
              ? json['updatedAt'] 
              : DateTime.now(),
      settings: json['settings'],
      distanceMeters: json['distanceMeters'] is int 
          ? (json['distanceMeters'] as int).toDouble() 
          : json['distanceMeters'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'shortDescription': shortDescription,
      'category': category,
      'type': type,
      'status': status,
      'imageUrl': imageUrl,
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
      'location': location,
      'tags': tags,
      'rules': rules,
      'memberCount': memberCount,
      'postCount': postCount,
      'eventCount': eventCount,
      'createdById': createdById,
      'isFeatured': isFeatured,
      'isVerified': isVerified,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'settings': settings,
      'distanceMeters': distanceMeters,
    };
  }

  String get typeDisplayName {
    if (type == null) return 'General';
    switch (type!.toUpperCase()) {
      case 'SPORTS':
        return 'Sports';
      case 'EDUCATION':
        return 'Education';
      case 'ARTS':
        return 'Arts';
      case 'TECHNOLOGY':
        return 'Technology';
      case 'HEALTH':
        return 'Health';
      case 'ENVIRONMENT':
        return 'Environment';
      case 'BUSINESS':
        return 'Business';
      case 'GENERAL':
      default:
        return 'General';
    }
  }

  String get statusDisplayName {
    if (status == null) return 'Active';
    switch (status!.toUpperCase()) {
      case 'INACTIVE':
        return 'Inactive';
      case 'SUSPENDED':
        return 'Suspended';
      case 'BANNED':
        return 'Banned';
      case 'ACTIVE':
      default:
        return 'Active';
    }
  }

  bool get isActive => status == null || status!.toUpperCase() == 'ACTIVE';
  bool get isPublic => type == 'PUBLIC';
  bool get isPrivate => type == 'PRIVATE';
  
  /// Get distance in kilometers
  double? get distanceKm => distanceMeters != null ? distanceMeters! / 1000 : null;
}

