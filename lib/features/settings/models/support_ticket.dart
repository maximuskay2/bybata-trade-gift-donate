import 'package:flutter/material.dart';
import 'package:bybata/core/theme/app_theme.dart';

enum SupportTicketStatus {
  open,
  inProgress,
  resolved,
  closed,
  waiting;

  String get displayName {
    switch (this) {
      case SupportTicketStatus.open:
        return 'Open';
      case SupportTicketStatus.inProgress:
        return 'In Progress';
      case SupportTicketStatus.resolved:
        return 'Resolved';
      case SupportTicketStatus.closed:
        return 'Closed';
      case SupportTicketStatus.waiting:
        return 'Waiting for Response';
    }
  }

  Color get color {
    switch (this) {
      case SupportTicketStatus.open:
        return AppColors.primary; // Blue
      case SupportTicketStatus.inProgress:
        return const Color(0xFFF59E0B); // Orange
      case SupportTicketStatus.resolved:
        return const Color(0xFF10B981); // Green
      case SupportTicketStatus.closed:
        return const Color(0xFF6B7280); // Gray
      case SupportTicketStatus.waiting:
        return const Color(0xFF8B5CF6); // Purple
    }
  }
}

enum SupportTicketPriority {
  low,
  medium,
  high,
  urgent;

  String get displayName {
    switch (this) {
      case SupportTicketPriority.low:
        return 'Low';
      case SupportTicketPriority.medium:
        return 'Medium';
      case SupportTicketPriority.high:
        return 'High';
      case SupportTicketPriority.urgent:
        return 'Urgent';
    }
  }

  Color get color {
    switch (this) {
      case SupportTicketPriority.low:
        return const Color(0xFF10B981); // Green
      case SupportTicketPriority.medium:
        return AppColors.primary; // Blue
      case SupportTicketPriority.high:
        return const Color(0xFFF59E0B); // Orange
      case SupportTicketPriority.urgent:
        return const Color(0xFFEF4444); // Red
    }
  }
}

class SupportTicket {
  final String id;
  final String subject;
  final String description;
  final String category;
  final SupportTicketStatus status;
  final SupportTicketPriority priority;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final String? assignedAgent;
  final List<String> attachments;
  final List<SupportTicketMessage> messages;
  final Map<String, dynamic> metadata;

  const SupportTicket({
    required this.id,
    required this.subject,
    required this.description,
    required this.category,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.lastUpdated,
    this.assignedAgent,
    this.attachments = const [],
    this.messages = const [],
    this.metadata = const {},
  });

  SupportTicket copyWith({
    String? id,
    String? subject,
    String? description,
    String? category,
    SupportTicketStatus? status,
    SupportTicketPriority? priority,
    DateTime? createdAt,
    DateTime? lastUpdated,
    String? assignedAgent,
    List<String>? attachments,
    List<SupportTicketMessage>? messages,
    Map<String, dynamic>? metadata,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      assignedAgent: assignedAgent ?? this.assignedAgent,
      attachments: attachments ?? this.attachments,
      messages: messages ?? this.messages,
      metadata: metadata ?? this.metadata,
    );
  }

  String get statusDescription {
    switch (status) {
      case SupportTicketStatus.open:
        return 'We\'ve received your ticket and will respond soon';
      case SupportTicketStatus.inProgress:
        return 'Our team is actively working on your issue';
      case SupportTicketStatus.resolved:
        return 'Issue has been resolved';
      case SupportTicketStatus.closed:
        return 'Ticket has been closed';
      case SupportTicketStatus.waiting:
        return 'Waiting for your response';
    }
  }

  Duration get timeSinceCreated {
    return DateTime.now().difference(createdAt);
  }

  Duration get timeSinceUpdated {
    return DateTime.now().difference(lastUpdated);
  }

  bool get isActive {
    return status == SupportTicketStatus.open || 
           status == SupportTicketStatus.inProgress ||
           status == SupportTicketStatus.waiting;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'description': description,
      'category': category,
      'status': status.name,
      'priority': priority.name,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'assignedAgent': assignedAgent,
      'attachments': attachments,
      'messages': messages.map((m) => m.toJson()).toList(),
      'metadata': metadata,
    };
  }

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket.fromApiJson(json);
  }

  factory SupportTicket.fromApiJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      status: _statusFromApi(json['status']?.toString()),
      priority: _priorityFromApi(json['priority']?.toString()),
      createdAt: _parseDate(json['createdAt']),
      lastUpdated: _parseDate(json['lastUpdated'] ?? json['updatedAt']),
      assignedAgent: json['assignedAgent']?.toString(),
      attachments: List<String>.from(json['attachments'] ?? []),
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => SupportTicketMessage.fromApiJson(
                    Map<String, dynamic>.from(m as Map),
                  ))
              .toList() ??
          [],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  static SupportTicketStatus _statusFromApi(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'IN_PROGRESS':
        return SupportTicketStatus.inProgress;
      case 'RESOLVED':
        return SupportTicketStatus.resolved;
      case 'CLOSED':
        return SupportTicketStatus.closed;
      case 'WAITING':
        return SupportTicketStatus.waiting;
      case 'OPEN':
      default:
        return SupportTicketStatus.open;
    }
  }

  static SupportTicketPriority _priorityFromApi(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'LOW':
        return SupportTicketPriority.low;
      case 'HIGH':
        return SupportTicketPriority.high;
      case 'URGENT':
        return SupportTicketPriority.urgent;
      case 'MEDIUM':
      default:
        return SupportTicketPriority.medium;
    }
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}

class SupportTicketMessage {
  final String id;
  final String content;
  final bool isFromUser;
  final DateTime timestamp;
  final String? authorName;
  final List<String> attachments;

  const SupportTicketMessage({
    required this.id,
    required this.content,
    required this.isFromUser,
    required this.timestamp,
    this.authorName,
    this.attachments = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isFromUser': isFromUser,
      'timestamp': timestamp.toIso8601String(),
      'authorName': authorName,
      'attachments': attachments,
    };
  }

  factory SupportTicketMessage.fromJson(Map<String, dynamic> json) {
    return SupportTicketMessage.fromApiJson(json);
  }

  factory SupportTicketMessage.fromApiJson(Map<String, dynamic> json) {
    return SupportTicketMessage(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      isFromUser: json['isFromUser'] == true,
      timestamp: SupportTicket._parseDate(json['timestamp'] ?? json['createdAt']),
      authorName: json['authorName']?.toString() ?? json['senderName']?.toString(),
      attachments: List<String>.from(json['attachments'] ?? []),
    );
  }
}