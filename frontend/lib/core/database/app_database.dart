import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:frontend/core/database/tables/messages.dart';
import 'package:frontend/core/database/tables/conversations.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Messages, Conversations])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Week 7: add steps here when schemaVersion bumps
      // if (from < 2) await m.addColumn(messages, messages.isStarred);
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