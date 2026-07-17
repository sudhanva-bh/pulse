import 'package:drift/drift.dart';

class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get participantIds => text()(); // Store as JSON string
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get lastMessageContent => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get initiatorId => text()();

  @override
  Set<Column> get primaryKey => {id};
}
