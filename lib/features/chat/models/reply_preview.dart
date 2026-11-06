/// Quoted reply preview embedded on a message.
/// Contains just enough info to render the grey quote card above a bubble.
class ReplyPreview {
  final String messageId;
  final String? senderId;
  final String senderName;
  final String contentPreview;
  final String type; // TEXT / IMAGE / FILE / ...

  const ReplyPreview({
    required this.messageId,
    required this.senderName,
    required this.contentPreview,
    this.senderId,
    this.type = 'TEXT',
  });

  factory ReplyPreview.fromJson(Map<String, dynamic> json) {
    return ReplyPreview(
      messageId: (json['id'] ?? json['messageId'] ?? '').toString(),
      senderId: (json['senderId'] ?? json['sender']?['id'])?.toString(),
      senderName: (json['senderName'] ??
              json['sender']?['profile']?['displayName'] ??
              json['sender']?['displayName'] ??
              'Someone')
          .toString(),
      contentPreview: (json['content'] ?? json['contentPreview'] ?? '').toString(),
      type: (json['type'] ?? 'TEXT').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': messageId,
        'senderId': senderId,
        'senderName': senderName,
        'content': contentPreview,
        'type': type,
      };
}
