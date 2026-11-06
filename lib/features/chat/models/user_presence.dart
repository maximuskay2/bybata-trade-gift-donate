/// Online presence + last-seen info for a user.
///
/// Used by Chat screens' app bar subtitle & conversation list tile.
class UserPresence {
  final String userId;
  final bool isOnline;
  final DateTime? lastSeenAt;

  const UserPresence({
    required this.userId,
    required this.isOnline,
    this.lastSeenAt,
  });

  UserPresence copyWith({bool? isOnline, DateTime? lastSeenAt}) => UserPresence(
        userId: userId,
        isOnline: isOnline ?? this.isOnline,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );

  /// Human-friendly subtitle for app bars: "online" / "last seen 5m ago" / "last seen recently".
  String describe() {
    if (isOnline) return 'online';
    if (lastSeenAt == null) return 'last seen recently';
    final diff = DateTime.now().difference(lastSeenAt!);
    if (diff.inSeconds < 60) return 'last seen just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'last seen ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'last seen ${diff.inDays}d ago';
    return 'last seen a while ago';
  }
}
