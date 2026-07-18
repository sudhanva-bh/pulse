import 'package:drift/drift.dart';

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get senderId => text()();
  TextColumn get content => text()();
  TextColumn get status => text().withDefault(Constant('pending'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get syncedToCloud => boolean().withDefault(Constant(false))();

  TextColumn get attachmentUri => text().nullable()();
  IntColumn get attachmentSize => integer().nullable()();
  TextColumn get attachmentName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
