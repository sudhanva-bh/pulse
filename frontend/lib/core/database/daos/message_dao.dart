import 'package:drift/drift.dart';
import 'package:frontend/core/database/app_database.dart';
import 'package:frontend/core/database/tables/messages.dart';

part 'message_dao.g.dart';

@DriftAccessor(tables: [Messages])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  MessageDao(AppDatabase db) : super(db);

  Stream<List<Message>> watchMessages(String conversationId) {
    return (select(messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.rowId, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<int> insertMessage(MessagesCompanion message) {
    return into(messages).insert(message);
  }

  Future<void> updateStatus(String id, String status) {
    return (update(messages)..where((t) => t.id.equals(id))).write(
      MessagesCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> markSynced(String id) {
    return (update(messages)..where((t) => t.id.equals(id))).write(
      MessagesCompanion(
        syncedToCloud: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> upsertMessage(MessagesCompanion message) {
    return into(messages).insertOnConflictUpdate(message);
  }

  Future<List<Message>> getUnsyncedMessages() {
    return (select(messages)..where((t) => t.syncedToCloud.equals(false))).get();
  }

  Future<DateTime?> getLatestMessageTimestamp() async {
    final query = select(messages)
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
      ..limit(1);
    final msg = await query.getSingleOrNull();
    return msg?.createdAt;
  }

  Future<void> deleteAll() {
    return delete(messages).go();
  }
}
