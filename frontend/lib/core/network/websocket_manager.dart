import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/core/database/app_database.dart' as db;
import 'package:frontend/features/chat/presentation/chat_provider.dart';
import 'package:drift/drift.dart' as drift;

enum WsConnectionState { connected, reconnecting, disconnected }

class WebSocketManager {
  final Ref ref;
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  static const _wsUrl = 'ws://192.168.1.3:8000/ws';

  final _connectionStateController =
      StreamController<WsConnectionState>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<WsConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;

  WebSocketManager(this.ref) {
    _connectionStateController.add(WsConnectionState.disconnected);
  }

  Future<void> connect() async {
    final token = await SecureStorage.getToken();
    if (token == null) return;

    final url = Uri.parse('$_wsUrl?token=$token');

    try {
      _channel = WebSocketChannel.connect(url);
      _connectionStateController.add(WsConnectionState.connected);
      _reconnectAttempt = 0;
      
      _runBackgroundDeltaSync();

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onDone: () {
          _scheduleReconnect();
        },
        onError: (error) {
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _scheduleReconnect();
    }
  }

  Future<void> _runBackgroundDeltaSync() async {
    try {
      await ref.read(conversationRepositoryProvider).fetchConversations();
      await ref.read(messageRepositoryProvider).syncMissedMessages();
    } catch (e) {
      // ignore
    }
  }

  void _handleMessage(dynamic messageStr) {
    try {
      final Map<String, dynamic> data = jsonDecode(messageStr);
      final type = data['type'];
      final payload = data['data'];

      if (type == 'message') {
        _handleIncomingMessage(payload);
      } else if (type == 'ack') {
        _handleAck(payload);
      } else if (type == 'typing') {
        _typingController.add(payload);
      } else if (type == 'conversation_update') {
        _handleConversationUpdate(payload);
      } else if (type == 'status_update') {
        _handleStatusUpdate(payload);
      }
    } catch (e) {
      // Ignore parsing errors
    }
  }

  Future<void> _handleConversationUpdate(Map<String, dynamic> payload) async {
    final conversationDao = ref.read(conversationDaoProvider);
    final companion = db.ConversationsCompanion(
      id: drift.Value(payload['id']),
      participantIds: drift.Value(jsonEncode(payload['participant_ids'])),
      createdAt: drift.Value(DateTime.parse(payload['created_at'])),
      lastMessageAt: drift.Value(payload['last_message_at'] != null ? DateTime.parse(payload['last_message_at']) : null),
      title: drift.Value(payload['title']),
      lastMessageContent: drift.Value(payload['last_message_content']),
      status: drift.Value(payload['status']),
      initiatorId: drift.Value(payload['initiator_id']),
    );
    await conversationDao.upsertConversation(companion);
  }

  Future<void> _handleIncomingMessage(Map<String, dynamic> payload) async {
    final messageDao = ref.read(messageDaoProvider);
    final conversationDao = ref.read(conversationDaoProvider);
    
    final convId = payload['conversation_id'] as String;
    final conv = await conversationDao.getConversation(convId);
    if (conv == null) {
      // If we don't have this conversation locally, fetch it from the backend
      await ref.read(conversationRepositoryProvider).fetchConversations();
    }

    final msgId = payload['id'] as String;
    final companion = db.MessagesCompanion(
      id: drift.Value(msgId),
      conversationId: drift.Value(payload['conversation_id']),
      senderId: drift.Value(payload['sender_id']),
      content: drift.Value(payload['content']),
      status: const drift.Value('delivered'),
      createdAt: drift.Value(DateTime.parse(payload['created_at'])),
      updatedAt: drift.Value(DateTime.parse(payload['updated_at'])),
      syncedToCloud: const drift.Value(true),
    );

    await messageDao.upsertMessage(companion);
    await conversationDao.updateLastMessage(
      payload['conversation_id'], 
      DateTime.parse(payload['created_at']), 
      payload['content']
    );

    // Send delivered receipt
    sendStatusUpdate(msgId, 'delivered');
  }

  void sendStatusUpdate(String messageId, String status) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'status_update',
        'data': {
          'message_id': messageId,
          'status': status,
        }
      }));
    }
  }

  Future<void> _handleStatusUpdate(Map<String, dynamic> payload) async {
    final messageId = payload['message_id'];
    final status = payload['status'];
    final messageDao = ref.read(messageDaoProvider);
    await messageDao.updateStatus(messageId, status);
  }

  Future<void> _handleAck(Map<String, dynamic> payload) async {
    final messageId = payload['message_id'];
    final messageDao = ref.read(messageDaoProvider);
    await messageDao.updateStatus(messageId, 'sent');
    await messageDao.markSynced(messageId);
  }

  void _scheduleReconnect() {
    _connectionStateController.add(WsConnectionState.reconnecting);
    _channel?.sink.close();
    _channel = null;

    final delay = (1 << _reconnectAttempt);
    final finalDelay = delay > 60 ? 60 : delay;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: finalDelay), () {
      _reconnectAttempt++;
      connect();
    });
  }

  void sendTyping(String conversationId) {
    if (_channel != null) {
      _channel!.sink.add(
        jsonEncode({
          'type': 'typing',
          'data': {'conversation_id': conversationId},
        }),
      );
    }
  }

  void sendMessage(Map<String, dynamic> msgData) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'type': 'message', 'data': msgData}));
    }
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _connectionStateController.close();
    _typingController.close();
  }
}

final webSocketManagerProvider = Provider<WebSocketManager>((ref) {
  final manager = WebSocketManager(ref);
  manager.connect();
  ref.onDispose(() => manager.dispose());
  return manager;
});
