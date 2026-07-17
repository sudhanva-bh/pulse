import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/database/daos/conversation_dao.dart';
import 'package:frontend/features/chat/domain/conversation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:frontend/core/database/app_database.dart' as db;

class ConversationRepository {
  final ConversationDao _conversationDao;
  final Dio _dio = ApiClient().dio;

  ConversationRepository(this._conversationDao);

  Future<void> createConversation(String username) async {
    try {
      final response = await _dio.post('/conversations', data: {'participant_username': username});
      final json = response.data;
      final conv = Conversation(
        id: json['id'],
        participantIds: List<String>.from(json['participant_ids']),
        lastMessageAt: json['last_message_at'] != null ? DateTime.parse(json['last_message_at']).toUtc() : null,
        createdAt: DateTime.parse(json['created_at']).toUtc(),
        title: json['title'],
        lastMessageContent: json['last_message_content'],
        status: json['status'],
        initiatorId: json['initiator_id'],
      );
      await upsertConversation(conv);
    } catch (e) {
      print("Error creating conversation: $e");
      rethrow;
    }
  }

  Future<void> acceptRequest(String convId) async {
    try {
      final response = await _dio.post('/conversations/$convId/accept');
      final json = response.data;
      final conv = Conversation(
        id: json['id'], participantIds: List<String>.from(json['participant_ids']),
        lastMessageAt: json['last_message_at'] != null ? DateTime.parse(json['last_message_at']).toUtc() : null,
        createdAt: DateTime.parse(json['created_at']).toUtc(), title: json['title'],
        lastMessageContent: json['last_message_content'], status: json['status'], initiatorId: json['initiator_id'],
      );
      await upsertConversation(conv);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectRequest(String convId) async {
    try {
      final response = await _dio.post('/conversations/$convId/reject');
      final json = response.data;
      final conv = Conversation(
        id: json['id'], participantIds: List<String>.from(json['participant_ids']),
        lastMessageAt: json['last_message_at'] != null ? DateTime.parse(json['last_message_at']).toUtc() : null,
        createdAt: DateTime.parse(json['created_at']).toUtc(), title: json['title'],
        lastMessageContent: json['last_message_content'], status: json['status'], initiatorId: json['initiator_id'],
      );
      await upsertConversation(conv);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchConversations() async {
    try {
      final response = await _dio.get('/conversations');
      final List data = response.data;
      for (var json in data) {
        final conv = Conversation(
          id: json['id'],
          participantIds: List<String>.from(json['participant_ids']),
          lastMessageAt: json['last_message_at'] != null ? DateTime.parse(json['last_message_at']).toUtc() : null,
          createdAt: DateTime.parse(json['created_at']).toUtc(),
          title: json['title'],
          lastMessageContent: json['last_message_content'],
          status: json['status'],
          initiatorId: json['initiator_id'],
        );
        await upsertConversation(conv);
      }
    } catch (e) {
      // Failed to fetch conversations
    }
  }

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
      title: drift.Value(conversation.title),
      lastMessageContent: drift.Value(conversation.lastMessageContent),
      status: drift.Value(conversation.status),
      initiatorId: drift.Value(conversation.initiatorId),
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
      title: c.title,
      lastMessageContent: c.lastMessageContent,
      status: c.status,
      initiatorId: c.initiatorId,
    );
  }
}
