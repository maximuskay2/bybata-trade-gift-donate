/// Community Post models
library;

import 'package:flutter/foundation.dart';

/// Community post type enumeration
enum CommunityPostType {
  text,
  image,
  poll,
  event,
  resource,
  successStory,
  announcement,
}

/// Poll status
enum PollStatus {
  active,
  closed,
}

/// Event status
enum EventStatus {
  upcoming,
  ongoing,
  completed,
  cancelled,
}

/// Poll Option model
class PollOption {
  final String id;
  final String text;
  final int voteCount;
  final List<String> voterIds;

  PollOption({
    required this.id,
    required this.text,
    this.voteCount = 0,
    this.voterIds = const [],
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      voteCount: json['voteCount'] ?? 0,
      voterIds: List<String>.from(json['voterIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'voteCount': voteCount,
      'voterIds': voterIds,
    };
  }

  double getPercentage(int totalVotes) {
    if (totalVotes == 0) return 0.0;
    return (voteCount / totalVotes) * 100;
  }
}

/// Poll Details model
class PollDetails {
  final String id;
  final String question;
  final List<PollOption> options;
  final PollStatus status;
  final DateTime? closesAt;
  final bool allowMultipleVotes;
  final int totalVotes;

  PollDetails({
    required this.id,
    required this.question,
    this.options = const [],
    this.status = PollStatus.active,
    this.closesAt,
    this.allowMultipleVotes = false,
    this.totalVotes = 0,
  });

  factory PollDetails.fromJson(Map<String, dynamic> json) {
    return PollDetails(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      options: (json['options'] as List<dynamic>?)
          ?.map((o) => PollOption.fromJson(o as Map<String, dynamic>))
          .toList() ?? [],
      status: _parsePollStatus(json['status']),
      closesAt: json['closesAt'] != null 
          ? DateTime.parse(json['closesAt']) 
          : null,
      allowMultipleVotes: json['allowMultipleVotes'] ?? false,
      totalVotes: json['totalVotes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options.map((o) => o.toJson()).toList(),
      'status': status.name,
      'closesAt': closesAt?.toIso8601String(),
      'allowMultipleVotes': allowMultipleVotes,
      'totalVotes': totalVotes,
    };
  }

  static PollStatus _parsePollStatus(dynamic status) {
    if (status == null) return PollStatus.active;
    final statusStr = status.toString().toLowerCase();
    return statusStr == 'closed' ? PollStatus.closed : PollStatus.active;
  }
}

/// Event Details model
class EventDetails {
  final String id;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String? location; // Physical or virtual
  final bool isVirtual;
  final String? virtualLink;
  final int? capacity;
  final int currentAttendees;
  final EventStatus status;
  final List<String> attendeeIds;
  final Map<String, dynamic>? additionalInfo;

  EventDetails({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    this.location,
    this.isVirtual = false,
    this.virtualLink,
    this.capacity,
    this.currentAttendees = 0,
    this.status = EventStatus.upcoming,
    this.attendeeIds = const [],
    this.additionalInfo,
  });

  factory EventDetails.fromJson(Map<String, dynamic> json) {
    return EventDetails(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      location: json['location'],
      isVirtual: json['isVirtual'] ?? false,
      virtualLink: json['virtualLink'],
      capacity: json['capacity'],
      currentAttendees: json['currentAttendees'] ?? 0,
      status: _parseEventStatus(json['status']),
      attendeeIds: List<String>.from(json['attendeeIds'] ?? []),
      additionalInfo: json['additionalInfo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'location': location,
      'isVirtual': isVirtual,
      'virtualLink': virtualLink,
      'capacity': capacity,
      'currentAttendees': currentAttendees,
      'status': status.name,
      'attendeeIds': attendeeIds,
      if (additionalInfo != null) 'additionalInfo': additionalInfo,
    };
  }

  static EventStatus _parseEventStatus(dynamic status) {
    if (status == null) return EventStatus.upcoming;
    final statusStr = status.toString().toLowerCase();
    switch (statusStr) {
      case 'ongoing':
        return EventStatus.ongoing;
      case 'completed':
        return EventStatus.completed;
      case 'cancelled':
        return EventStatus.cancelled;
      default:
        return EventStatus.upcoming;
    }
  }

  bool get isFull => capacity != null && currentAttendees >= capacity!;
  bool get canRegister => !isFull && status == EventStatus.upcoming;
}

/// Resource Details model
class ResourceDetails {
  final String id;
  final String title;
  final String? description;
  final String url;
  final String? resourceType; // link, file, document, etc.
  final String? category;
  final Map<String, dynamic>? metadata;

  ResourceDetails({
    required this.id,
    required this.title,
    this.description,
    required this.url,
    this.resourceType,
    this.category,
    this.metadata,
  });

  factory ResourceDetails.fromJson(Map<String, dynamic> json) {
    return ResourceDetails(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      url: json['url'] ?? '',
      resourceType: json['resourceType'],
      category: json['category'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'url': url,
      'resourceType': resourceType,
      'category': category,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Comment model
class CommunityPostComment {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likesCount;
  final bool isLiked;
  final List<CommunityPostComment>? replies;
  final String? parentCommentId;

  CommunityPostComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.likesCount = 0,
    this.isLiked = false,
    this.replies,
    this.parentCommentId,
  });

  factory CommunityPostComment.fromJson(Map<String, dynamic> json) {
    return CommunityPostComment(
      id: json['id'] ?? '',
      authorId: json['authorId'] ?? json['author']?['id'] ?? '',
      authorName: json['authorName'] ?? json['author']?['name'] ?? '',
      authorAvatar: json['authorAvatar'] ?? json['author']?['avatar'],
      content: json['content'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
      likesCount: json['likesCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      replies: json['replies'] != null
          ? (json['replies'] as List<dynamic>)
              .map((r) => CommunityPostComment.fromJson(r as Map<String, dynamic>))
              .toList()
          : null,
      parentCommentId: json['parentCommentId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'likesCount': likesCount,
      'isLiked': isLiked,
      'replies': replies?.map((r) => r.toJson()).toList(),
      'parentCommentId': parentCommentId,
    };
  }
}

/// Main Community Post model
class CommunityPost {
  final String id;
  final String communityId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final CommunityPostType type;
  final String? content;
  final String? title;
  final List<String> imageUrls;
  final String? videoUrl;
  final String? location;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLiked;
  final bool isAuthor;
  final bool isPinned;
  final bool isAnnouncement;
  final List<CommunityPostComment> comments;
  final Map<String, int> reactions; // reaction type -> count
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Type-specific data
  final PollDetails? pollDetails;
  final EventDetails? eventDetails;
  final ResourceDetails? resourceDetails;

  CommunityPost({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.type,
    this.content,
    this.title,
    this.imageUrls = const [],
    this.videoUrl,
    this.location,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.isLiked = false,
    this.isAuthor = false,
    this.isPinned = false,
    this.isAnnouncement = false,
    this.comments = const [],
    this.reactions = const {},
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
    this.pollDetails,
    this.eventDetails,
    this.resourceDetails,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] ?? '',
      communityId: json['communityId'] ?? '',
      authorId: json['authorId'] ?? json['author']?['id'] ?? '',
      authorName: json['authorName'] ?? json['author']?['name'] ?? '',
      authorAvatar: json['authorAvatar'] ?? json['author']?['avatar'],
      type: _parsePostType(json['type']),
      content: json['content'],
      title: json['title'],
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      videoUrl: json['videoUrl'],
      location: json['location'],
      likesCount: json['likesCount'] ?? 
          (json['_count'] != null ? json['_count']['likes'] : 0) ?? 0,
      commentsCount: json['commentsCount'] ?? 
          (json['_count'] != null ? json['_count']['comments'] : 0) ?? 0,
      sharesCount: json['sharesCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      isAuthor: json['isAuthor'] ?? false,
      isPinned: json['isPinned'] ?? false,
      isAnnouncement: json['isAnnouncement'] ?? false,
      comments: (json['comments'] as List<dynamic>?)
          ?.map((c) => CommunityPostComment.fromJson(c as Map<String, dynamic>))
          .toList() ?? [],
      reactions: json['reactions'] != null
          ? Map<String, int>.from(json['reactions'])
          : {},
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
      pollDetails: json['pollDetails'] != null
          ? PollDetails.fromJson(json['pollDetails'] as Map<String, dynamic>)
          : null,
      eventDetails: json['eventDetails'] != null
          ? EventDetails.fromJson(json['eventDetails'] as Map<String, dynamic>)
          : null,
      resourceDetails: json['resourceDetails'] != null
          ? ResourceDetails.fromJson(json['resourceDetails'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'communityId': communityId,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'type': type.name,
      'content': content,
      'title': title,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'location': location,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'isLiked': isLiked,
      'isAuthor': isAuthor,
      'isPinned': isPinned,
      'isAnnouncement': isAnnouncement,
      'comments': comments.map((c) => c.toJson()).toList(),
      'reactions': reactions,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      if (pollDetails != null) 'pollDetails': pollDetails!.toJson(),
      if (eventDetails != null) 'eventDetails': eventDetails!.toJson(),
      if (resourceDetails != null) 'resourceDetails': resourceDetails!.toJson(),
    };
  }

  static CommunityPostType _parsePostType(dynamic type) {
    if (type == null) return CommunityPostType.text;
    final typeStr = type.toString().toLowerCase();
    switch (typeStr) {
      case 'image':
        return CommunityPostType.image;
      case 'poll':
        return CommunityPostType.poll;
      case 'event':
        return CommunityPostType.event;
      case 'resource':
        return CommunityPostType.resource;
      case 'successstory':
        return CommunityPostType.successStory;
      case 'announcement':
        return CommunityPostType.announcement;
      default:
        return CommunityPostType.text;
    }
  }

  String get typeDisplayName {
    switch (type) {
      case CommunityPostType.image:
        return 'Image';
      case CommunityPostType.poll:
        return 'Poll';
      case CommunityPostType.event:
        return 'Event';
      case CommunityPostType.resource:
        return 'Resource';
      case CommunityPostType.successStory:
        return 'Success Story';
      case CommunityPostType.announcement:
        return 'Announcement';
      default:
        return 'Text';
    }
  }
}

