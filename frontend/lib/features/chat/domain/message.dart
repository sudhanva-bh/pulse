enum MessageStatus {
  pending,
  sending,
  sent,
  delivered,
  read,
  failed,
  queued,
  deliveredLocally,
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
  final String? attachmentUri;
  final int? attachmentSize;
  final String? attachmentName;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.syncedToCloud,
    this.attachmentUri,
    this.attachmentSize,
    this.attachmentName,
  });
}
