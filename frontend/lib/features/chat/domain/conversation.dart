class Conversation {
  final String id;
  final List<String> participantIds;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final String? title;
  final String? lastMessageContent;
  final String status;
  final String initiatorId;

  Conversation({
    required this.id,
    required this.participantIds,
    this.lastMessageAt,
    required this.createdAt,
    this.title,
    this.lastMessageContent,
    required this.status,
    required this.initiatorId,
  });
}
