import 'package:frontend/core/database/daos/message_dao.dart';
import 'package:frontend/features/chat/domain/message.dart';
import 'package:frontend/core/network/websocket_manager.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:frontend/core/database/app_database.dart' as db;

class MessageRepository {
  final MessageDao _messageDao;
  final WebSocketManager _wsManager;
  final _uuid = const Uuid();

  MessageRepository(this._messageDao, this._wsManager);

  Stream<List<Message>> watchMessages(String conversationId) {
    return _messageDao.watchMessages(conversationId).map((driftMessages) {
      return driftMessages.map((m) => _mapFromDrift(m)).toList();
    });
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
