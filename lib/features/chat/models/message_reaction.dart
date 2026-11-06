/// A lightweight reaction record attached to a message.
class MessageReaction {
  final String userId;
  final String emoji;
  final DateTime createdAt;

  const MessageReaction({
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    return MessageReaction(
      userId: (json['userId'] ?? '').toString(),
      emoji: (json['emoji'] ?? '').toString(),
      createdAt: created is String
          ? DateTime.tryParse(created) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'emoji': emoji,
        'createdAt': createdAt.toIso8601String(),
      };

  MessageReaction copyWith({String? userId, String? emoji, DateTime? createdAt}) =>
      MessageReaction(
        userId: userId ?? this.userId,
        emoji: emoji ?? this.emoji,
        createdAt: createdAt ?? this.createdAt,
      );
}
