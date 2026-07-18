import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/database/daos/message_dao.dart';
import 'package:frontend/core/database/daos/conversation_dao.dart';
import 'package:drift/drift.dart' as drift;
import 'package:frontend/core/database/app_database.dart' as db;
import 'package:frontend/features/chat/presentation/chat_provider.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter/material.dart';

class LanConnectionManager {
  final MessageDao _messageDao;
  final ConversationDao _conversationDao;
  Socket? _socket;
  StreamSubscription? _subscription;

  String? _expectedToken;
  bool _isAuthenticated = false;
  VoidCallback? _onAuthenticated;

  LanConnectionManager(this._messageDao, this._conversationDao);

  bool get isConnected => _socket != null && _isAuthenticated;

  void attachSocket(Socket socket, {String? expectedToken, VoidCallback? onAuthenticated}) {
    disconnect(); // Ensure any existing socket is closed
    _socket = socket;
    _expectedToken = expectedToken;
    _isAuthenticated = expectedToken == null;
    _onAuthenticated = onAuthenticated;

    _subscription = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      _handleIncomingFrame,
      onDone: disconnect,
      onError: (e) => disconnect(),
    );

    if (_isAuthenticated) {
      _showSuccessToast();
      _onAuthenticated?.call();
    }
  }

  void _showSuccessToast() {
    toastification.show(
      title: const Text('LAN Connection Established'),
      description: const Text('You are now chatting peer-to-peer.'),
      type: ToastificationType.success,
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  Future<void> _handleIncomingFrame(String frame) async {
    try {
      final data = jsonDecode(frame);
      
      if (!_isAuthenticated) {
        if (data['token'] == _expectedToken) {
          _isAuthenticated = true;
          _showSuccessToast();
          _onAuthenticated?.call();
        } else {
          disconnect();
        }
        return;
      }

      if (data is Map<String, dynamic> && data['type'] == 'message') {
        final payload = data['data'];
        
        final companion = db.MessagesCompanion(
          id: drift.Value(payload['id']),
          conversationId: drift.Value(payload['conversation_id']),
          senderId: drift.Value(payload['sender_id']),
          content: drift.Value(payload['content']),
          status: const drift.Value('deliveredLocally'),
          createdAt: drift.Value(DateTime.parse(payload['created_at']).toUtc()),
          updatedAt: drift.Value(DateTime.parse(payload['updated_at']).toUtc()),
          syncedToCloud: const drift.Value(true), 
        );

        await _messageDao.upsertMessage(companion);
        await _conversationDao.updateLastMessage(
          payload['conversation_id'],
          DateTime.parse(payload['created_at']).toUtc(),
          payload['content'],
        );
      }
    } catch (e) {
      // Ignore parse errors
    }
  }

  void sendMessage(Map<String, dynamic> msgData) {
    if (_socket != null) {
      final frame = jsonEncode({'type': 'message', 'data': msgData});
      _socket!.write('$frame\n');
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    
    if (_socket != null) {
      _socket!.close();
      _socket = null;
      
      toastification.show(
        title: const Text('LAN Disconnected'),
        type: ToastificationType.info,
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }
}

final lanConnectionManagerProvider = Provider<LanConnectionManager>((ref) {
  final messageDao = ref.watch(messageDaoProvider);
  final conversationDao = ref.watch(conversationDaoProvider);
  final manager = LanConnectionManager(messageDao, conversationDao);
  ref.onDispose(() => manager.disconnect());
  return manager;
});
