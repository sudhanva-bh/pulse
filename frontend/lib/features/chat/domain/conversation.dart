class Conversation {
  final String id;
  final List<String> participantIds;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  Conversation({
    required this.id,
    required this.participantIds,
    this.lastMessageAt,
    required this.createdAt,
  });
}
