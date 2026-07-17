import 'package:frontend/core/database/daos/message_dao.dart';
import 'package:frontend/features/chat/domain/message.dart';
import 'package:frontend/core/network/websocket_manager.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:frontend/core/database/app_database.dart' as db;

import 'package:frontend/core/database/daos/conversation_dao.dart';

class MessageRepository {
  final MessageDao _messageDao;
  final ConversationDao _conversationDao;
  final WebSocketManager _wsManager;
  final _uuid = const Uuid();

  MessageRepository(this._messageDao, this._conversationDao, this._wsManager);

  Stream<List<Message>> watchMessages(String conversationId) {
    return _messageDao.watchMessages(conversationId).map((driftMessages) {
      return driftMessages.map((m) => _mapFromDrift(m)).toList();
    });
  }

  Future<int> fetchMessagesForConversation(String conversationId) async {
    try {
      final dio = ApiClient().dio;
      final response = await dio.get('/conversations/$conversationId/messages');
      final List data = response.data;
      
      int loaded = 0;
      for (var json in data) {
        final companion = db.MessagesCompanion(
          id: drift.Value(json['id']),
          conversationId: drift.Value(json['conversation_id']),
          senderId: drift.Value(json['sender_id']),
          content: drift.Value(json['content']),
          status: const drift.Value('delivered'),
          createdAt: drift.Value(DateTime.parse(json['created_at']).toUtc()),
          updatedAt: drift.Value(DateTime.parse(json['updated_at']).toUtc()),
          syncedToCloud: const drift.Value(true),
        );
        await _messageDao.upsertMessage(companion);
        loaded++;
      }
      return loaded;
    } catch (e) {
      return 0; // Return 0 loaded on error
    }
  }

  Future<int> syncMissedMessages(DateTime since) async {
    try {
      final dio = ApiClient().dio;
      final response = await dio.get('/messages/sync', queryParameters: {'since': since.toIso8601String()});
      final List data = response.data;
      
      int loaded = 0;
      for (var json in data) {
        final companion = db.MessagesCompanion(
          id: drift.Value(json['id']),
          conversationId: drift.Value(json['conversation_id']),
          senderId: drift.Value(json['sender_id']),
          content: drift.Value(json['content']),
          status: const drift.Value('delivered'),
          createdAt: drift.Value(DateTime.parse(json['created_at']).toUtc()),
          updatedAt: drift.Value(DateTime.parse(json['updated_at']).toUtc()),
          syncedToCloud: const drift.Value(true),
        );
        await _messageDao.upsertMessage(companion);
        loaded++;
      }
      return loaded;
    } catch (e) {
      return 0;
    }
  }

  Future<void> sendMessage(String conversationId, String content, String senderId) async {
    final now = DateTime.now().toUtc();
    final messageId = _uuid.v4();
    
    final companion = db.MessagesCompanion(
      id: drift.Value(messageId),
      conversationId: drift.Value(conversationId),
      senderId: drift.Value(senderId),
      content: drift.Value(content),
      status: const drift.Value('sending'), // Initially sending
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
      syncedToCloud: const drift.Value(false),
    );

    await _messageDao.insertMessage(companion);

    // Update conversation list UI
    await _conversationDao.updateLastMessage(conversationId, now, content);

    // Send over websocket
    _wsManager.sendMessage({
      'id': messageId,
      'conversation_id': conversationId,
      'content': content,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  Future<void> updateStatus(String id, MessageStatus status) async {
    await _messageDao.updateStatus(id, status.name);
  }

  Message _mapFromDrift(db.Message m) {
    return Message(
      id: m.id,
      conversationId: m.conversationId,
      senderId: m.senderId,
      content: m.content,
      status: MessageStatus.values.firstWhere(
        (e) => e.name == m.status,
        orElse: () => MessageStatus.pending,
      ),
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
      syncedToCloud: m.syncedToCloud,
    );
  }
}
