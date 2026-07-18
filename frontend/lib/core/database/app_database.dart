import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:frontend/core/database/tables/messages.dart';
import 'package:frontend/core/database/tables/conversations.dart';

import 'package:frontend/core/database/daos/message_dao.dart';
import 'package:frontend/core/database/daos/conversation_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Messages, Conversations],
  daos: [MessageDao, ConversationDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        try {
          await m.addColumn(conversations, conversations.title);
        } catch (_) {}
        try {
          await m.addColumn(conversations, conversations.lastMessageContent);
        } catch (_) {}
      }
      if (from < 3) {
        try {
          await m.addColumn(conversations, conversations.status);
        } catch (_) {}
        try {
          await m.addColumn(conversations, conversations.initiatorId);
        } catch (_) {}
      }
      if (from < 4) {
        try {
          await m.addColumn(messages, messages.attachmentUri);
        } catch (_) {}
        try {
          await m.addColumn(messages, messages.attachmentSize);
        } catch (_) {}
        try {
          await m.addColumn(messages, messages.attachmentName);
        } catch (_) {}
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'pulse.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
