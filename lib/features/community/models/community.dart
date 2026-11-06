/// Community data models
library;

import 'package:flutter/foundation.dart';

/// Community type enumeration
enum CommunityType {
  general,
  sports,
  education,
  arts,
  technology,
  health,
  environment,
  business,
  interestBased,
  skillSharing,
  impactFocused,
  regional,
}

/// Community visibility/privacy settings
enum CommunityVisibility {
  open,    // Anyone can join
  closed,  // Requires approval
  secret,  // Invite only
}

/// Community member role
enum CommunityMemberRole {
  member,
  moderator,
  admin,
  owner,
}

/// Community member status
enum CommunityMemberStatus {
  pending,
  approved,
  rejected,
  banned,
}

/// Expert level for community members
enum ExpertLevel {
  newcomer,
  contributor,
  specialist,
  expert,
  authority,
}

/// Community Goal model
class CommunityGoal {
  final String id;
  final String title;
  final String? description;
  final DateTime? targetDate;
  final bool isCompleted;
  final DateTime createdAt;

  CommunityGoal({
    required this.id,
    required this.title,
    this.description,
    this.targetDate,
    this.isCompleted = false,
    required this.createdAt,
  });

  factory CommunityGoal.fromJson(Map<String, dynamic> json) {
    return CommunityGoal(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      targetDate: json['targetDate'] != null 
          ? DateTime.parse(json['targetDate']) 
          : null,
      isCompleted: json['isCompleted'] ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'targetDate': targetDate?.toIso8601String(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Badge model for community members
class Badge {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final DateTime earnedAt;

  Badge({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    required this.earnedAt,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      iconUrl: json['iconUrl'],
      earnedAt: json['earnedAt'] != null 
          ? DateTime.parse(json['earnedAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'earnedAt': earnedAt.toIso8601String(),
    };
  }
}

/// Impact Tracker for community metrics
class ImpactTracker {
  final int postsCreated;
  final int problemsSolved;
  final int eventsOrganized;
  final int membersHelped;
  final Map<String, dynamic>? additionalMetrics;

  ImpactTracker({
    this.postsCreated = 0,
    this.problemsSolved = 0,
    this.eventsOrganized = 0,
    this.membersHelped = 0,
    this.additionalMetrics,
  });

  factory ImpactTracker.fromJson(Map<String, dynamic> json) {
    return ImpactTracker(
      postsCreated: json['postsCreated'] ?? 0,
      problemsSolved: json['problemsSolved'] ?? 0,
      eventsOrganized: json['eventsOrganized'] ?? 0,
      membersHelped: json['membersHelped'] ?? 0,
      additionalMetrics: json['additionalMetrics'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'postsCreated': postsCreated,
      'problemsSolved': problemsSolved,
      'eventsOrganized': eventsOrganized,
      'membersHelped': membersHelped,
      if (additionalMetrics != null) 'additionalMetrics': additionalMetrics,
    };
  }
}

/// Community Member model
class CommunityMember {
  final String userId;
  final String userName;
  final String? userAvatar;
  final CommunityMemberRole role;
  final CommunityMemberStatus status;
  final DateTime joinedAt;
  final ExpertLevel expertLevel;
  final List<Badge> badges;
  final int contributionScore;
  final int totalKarma;
  final int helpfulAnswers;
  final double responsivenessScore;
  final List<String> specializations;
  final List<Map<String, dynamic>>? recentKarmaActivities;

  CommunityMember({
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.role = CommunityMemberRole.member,
    this.status = CommunityMemberStatus.approved,
    required this.joinedAt,
    this.expertLevel = ExpertLevel.newcomer,
    this.badges = const [],
    this.contributionScore = 0,
    this.totalKarma = 0,
    this.helpfulAnswers = 0,
    this.responsivenessScore = 0.0,
    this.specializations = const [],
    this.recentKarmaActivities,
  });

  factory CommunityMember.fromJson(Map<String, dynamic> json) {
    return CommunityMember(
      userId: json['userId'] ?? json['user']?['id'] ?? '',
      userName: json['userName'] ?? json['user']?['name'] ?? '',
      userAvatar: json['userAvatar'] ?? json['user']?['avatar'],
      role: _parseRole(json['role']),
      status: _parseStatus(json['status']),
      joinedAt: json['joinedAt'] != null 
          ? DateTime.parse(json['joinedAt']) 
          : DateTime.now(),
      expertLevel: _parseExpertLevel(json['expertLevel']),
      badges: (json['badges'] as List<dynamic>?)
          ?.map((b) => Badge.fromJson(b as Map<String, dynamic>))
          .toList() ?? [],
      contributionScore: json['contributionScore'] ?? 0,
      totalKarma: json['totalKarma'] ?? 0,
      helpfulAnswers: json['helpfulAnswers'] ?? 0,
      responsivenessScore: (json['responsivenessScore'] ?? 0).toDouble(),
      specializations: List<String>.from(json['specializations'] ?? []),
      recentKarmaActivities: json['recentKarmaActivities'] != null
          ? List<Map<String, dynamic>>.from(json['recentKarmaActivities'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'role': role.name,
      'status': status.name,
      'joinedAt': joinedAt.toIso8601String(),
      'expertLevel': expertLevel.name,
      'badges': badges.map((b) => b.toJson()).toList(),
      'contributionScore': contributionScore,
      'totalKarma': totalKarma,
      'helpfulAnswers': helpfulAnswers,
      'responsivenessScore': responsivenessScore,
      'specializations': specializations,
      if (recentKarmaActivities != null) 'recentKarmaActivities': recentKarmaActivities,
    };
  }

  static CommunityMemberRole _parseRole(dynamic role) {
    if (role == null) return CommunityMemberRole.member;
    final roleStr = role.toString().toLowerCase();
    switch (roleStr) {
      case 'owner':
        return CommunityMemberRole.owner;
      case 'admin':
        return CommunityMemberRole.admin;
      case 'moderator':
        return CommunityMemberRole.moderator;
      default:
        return CommunityMemberRole.member;
    }
  }

  static CommunityMemberStatus _parseStatus(dynamic status) {
    if (status == null) return CommunityMemberStatus.approved;
    final statusStr = status.toString().toLowerCase();
    switch (statusStr) {
      case 'pending':
        return CommunityMemberStatus.pending;
      case 'rejected':
        return CommunityMemberStatus.rejected;
      case 'banned':
        return CommunityMemberStatus.banned;
      default:
        return CommunityMemberStatus.approved;
    }
  }

  static ExpertLevel _parseExpertLevel(dynamic level) {
    if (level == null) return ExpertLevel.newcomer;
    final levelStr = level.toString().toLowerCase();
    switch (levelStr) {
      case 'authority':
        return ExpertLevel.authority;
      case 'expert':
        return ExpertLevel.expert;
      case 'specialist':
        return ExpertLevel.specialist;
      case 'contributor':
        return ExpertLevel.contributor;
      default:
        return ExpertLevel.newcomer;
    }
  }
}

/// Main Community model
class Community {
  final String id;
  final String name;
  final String? description;
  final String? longDescription;
  final CommunityType type;
  final String? category;
  final int memberCount;
  final double? distance; // in km
  final String? location;
  final CommunityVisibility visibility;
  final String? imageUrl;
  final String? bannerUrl;
  final List<String> tags;
  final String? rules;
  final List<CommunityGoal> goals;
  final List<CommunityMember> members;
  final String ownerId;
  final String? ownerName;
  final int postsCount;
  final int eventsCount;
  final double? rating;
  final ImpactTracker? impactTracker;
  final bool isJoined;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? settings;
  final double? centerLatitude;
  final double? centerLongitude;

  Community({
    required this.id,
    required this.name,
    this.description,
    this.longDescription,
    this.type = CommunityType.general,
    this.category,
    this.memberCount = 0,
    this.distance,
    this.location,
    this.visibility = CommunityVisibility.open,
    this.imageUrl,
    this.bannerUrl,
    this.tags = const [],
    this.rules,
    this.goals = const [],
    this.members = const [],
    required this.ownerId,
    this.ownerName,
    this.postsCount = 0,
    this.eventsCount = 0,
    this.rating,
    this.impactTracker,
    this.isJoined = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.settings,
    this.centerLatitude,
    this.centerLongitude,
  });

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      longDescription: json['longDescription'],
      type: _parseType(json['type']),
      category: json['category'],
      memberCount: json['memberCount'] ?? 
          (json['_count'] != null ? json['_count']['members'] : 0) ?? 0,
      distance: json['distance'] != null 
          ? (json['distance'] is int 
              ? (json['distance'] as int).toDouble() 
              : json['distance'] as double)
          : null,
      location: json['location'],
      visibility: _parseVisibility(json['visibility']),
      imageUrl: json['imageUrl'],
      bannerUrl: json['bannerUrl'],
      tags: List<String>.from(json['tags'] ?? []),
      rules: json['rules'],
      goals: (json['goals'] as List<dynamic>?)
          ?.map((g) => CommunityGoal.fromJson(g as Map<String, dynamic>))
          .toList() ?? [],
      members: (json['members'] as List<dynamic>?)
          ?.map((m) => CommunityMember.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
      ownerId: json['ownerId'] ?? json['createdById'] ?? '',
      ownerName: json['ownerName'] ?? json['createdBy']?['name'],
      postsCount: json['postsCount'] ?? 
          (json['_count'] != null ? json['_count']['posts'] : 0) ?? 0,
      eventsCount: json['eventsCount'] ?? 
          (json['_count'] != null ? json['_count']['events'] : 0) ?? 0,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      impactTracker: json['impactTracker'] != null
          ? ImpactTracker.fromJson(json['impactTracker'] as Map<String, dynamic>)
          : null,
      isJoined: json['isJoined'] ?? false,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
      settings: json['settings'],
      centerLatitude: json['centerLatitude'] is int 
          ? (json['centerLatitude'] as int).toDouble() 
          : json['centerLatitude'],
      centerLongitude: json['centerLongitude'] is int 
          ? (json['centerLongitude'] as int).toDouble() 
          : json['centerLongitude'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'longDescription': longDescription,
      'type': type.name,
      'category': category,
      'memberCount': memberCount,
      'distance': distance,
      'location': location,
      'visibility': visibility.name,
      'imageUrl': imageUrl,
      'bannerUrl': bannerUrl,
      'tags': tags,
      'rules': rules,
      'goals': goals.map((g) => g.toJson()).toList(),
      'members': members.map((m) => m.toJson()).toList(),
      'ownerId': ownerId,
      'ownerName': ownerName,
      'postsCount': postsCount,
      'eventsCount': eventsCount,
      'rating': rating,
      'impactTracker': impactTracker?.toJson(),
      'isJoined': isJoined,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'settings': settings,
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
    };
  }

  static CommunityType _parseType(dynamic type) {
    if (type == null) return CommunityType.general;
    final typeStr = type.toString().toUpperCase();
    switch (typeStr) {
      case 'SPORTS':
        return CommunityType.sports;
      case 'EDUCATION':
        return CommunityType.education;
      case 'ARTS':
        return CommunityType.arts;
      case 'TECHNOLOGY':
        return CommunityType.technology;
      case 'HEALTH':
        return CommunityType.health;
      case 'ENVIRONMENT':
        return CommunityType.environment;
      case 'BUSINESS':
        return CommunityType.business;
      case 'INTERESTBASED':
        return CommunityType.interestBased;
      case 'SKILLSHARING':
        return CommunityType.skillSharing;
      case 'IMPACTFOCUSED':
        return CommunityType.impactFocused;
      case 'REGIONAL':
        return CommunityType.regional;
      default:
        return CommunityType.general;
    }
  }

  static CommunityVisibility _parseVisibility(dynamic visibility) {
    if (visibility == null) return CommunityVisibility.open;
    final visStr = visibility.toString().toLowerCase();
    switch (visStr) {
      case 'closed':
        return CommunityVisibility.closed;
      case 'secret':
        return CommunityVisibility.secret;
      default:
        return CommunityVisibility.open;
    }
  }

  String get typeDisplayName {
    switch (type) {
      case CommunityType.sports:
        return 'Sports';
      case CommunityType.education:
        return 'Education';
      case CommunityType.arts:
        return 'Arts';
      case CommunityType.technology:
        return 'Technology';
      case CommunityType.health:
        return 'Health';
      case CommunityType.environment:
        return 'Environment';
      case CommunityType.business:
        return 'Business';
      case CommunityType.interestBased:
        return 'Interest Based';
      case CommunityType.skillSharing:
        return 'Skill Sharing';
      case CommunityType.impactFocused:
        return 'Impact Focused';
      case CommunityType.regional:
        return 'Regional';
      default:
        return 'General';
    }
  }

  bool get isPublic => visibility == CommunityVisibility.open;
  bool get requiresApproval => visibility == CommunityVisibility.closed;
}

