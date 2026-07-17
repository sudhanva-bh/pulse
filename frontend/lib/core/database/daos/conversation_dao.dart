import 'package:drift/drift.dart';
import 'package:frontend/core/database/app_database.dart';
import 'package:frontend/core/database/tables/conversations.dart';

part 'conversation_dao.g.dart';

@DriftAccessor(tables: [Conversations])
class ConversationDao extends DatabaseAccessor<AppDatabase> with _$ConversationDaoMixin {
  ConversationDao(AppDatabase db) : super(db);

  Stream<List<Conversation>> watchAllConversations() {
    return (select(conversations)
          ..orderBy([
            (t) => OrderingTerm(
                expression: coalesce([t.lastMessageAt, t.createdAt]),
                mode: OrderingMode.desc)
          ]))
        .watch();
  }

  Future<List<Conversation>> getAllConversations() {
    return select(conversations).get();
  }

  Future<Conversation?> getConversation(String id) {
    return (select(conversations)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertConversation(ConversationsCompanion conversation) {
    return into(conversations).insertOnConflictUpdate(conversation);
  }

  Future<void> updateLastMessage(String id, DateTime time) {
    return (update(conversations)..where((t) => t.id.equals(id))).write(
      ConversationsCompanion(
        lastMessageAt: Value(time),
      ),
    );
  }

  Future<void> deleteAll() {
    return delete(conversations).go();
  }
}
