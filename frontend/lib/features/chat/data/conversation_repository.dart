import 'dart:convert';
import 'package:frontend/core/database/daos/conversation_dao.dart';
import 'package:frontend/features/chat/domain/conversation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:frontend/core/database/app_database.dart' as db;

class ConversationRepository {
  final ConversationDao _conversationDao;

  ConversationRepository(this._conversationDao);

  Stream<List<Conversation>> watchConversations() {
    return _conversationDao.watchAllConversations().map((driftConvos) {
      return driftConvos.map((c) => _mapFromDrift(c)).toList();
    });
  }

  Future<void> upsertConversation(Conversation conversation) async {
    final companion = db.ConversationsCompanion(
      id: drift.Value(conversation.id),
      participantIds: drift.Value(jsonEncode(conversation.participantIds)),
      lastMessageAt: drift.Value(conversation.lastMessageAt),
      createdAt: drift.Value(conversation.createdAt),
    );
    await _conversationDao.upsertConversation(companion);
  }

  Conversation _mapFromDrift(db.Conversation c) {
    List<String> participants = [];
    try {
      participants = List<String>.from(jsonDecode(c.participantIds));
    } catch (_) {}

    return Conversation(
      id: c.id,
      participantIds: participants,
      lastMessageAt: c.lastMessageAt,
      createdAt: c.createdAt,
    );
  }
}
