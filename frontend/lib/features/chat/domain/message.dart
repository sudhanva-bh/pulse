enum MessageStatus {
  pending,
  sending,
  sent,
  delivered,
  read,
  failed,
  queued,
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final MessageStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool syncedToCloud;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.syncedToCloud,
  });
}
