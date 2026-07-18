import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/database/daos/message_dao.dart';
import 'package:drift/drift.dart' as drift;
import 'package:frontend/core/database/app_database.dart' as db;
import 'package:frontend/features/chat/presentation/chat_provider.dart';

class LanClient {
  final MessageDao _messageDao;
  
  LanClient(this._messageDao);

  Future<int> connectAndReceive(String ip, int port, String token) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      socket.add(utf8.encode(jsonEncode({'token': token})));

      final data = await socket.first;
      final payloadStr = utf8.decode(data);
      final List payload = jsonDecode(payloadStr);

      int count = 0;
      for (var json in payload) {
        final companion = db.MessagesCompanion(
          id: drift.Value(json['id']),
          conversationId: drift.Value(json['conversation_id']),
          senderId: drift.Value(json['sender_id']),
          content: drift.Value(json['content']),
          status: const drift.Value('deliveredLocally'),
          createdAt: drift.Value(DateTime.parse(json['created_at']).toUtc()),
          updatedAt: drift.Value(DateTime.parse(json['updated_at']).toUtc()),
          syncedToCloud: const drift.Value(true), // We are the receiver, don't upload
        );
        await _messageDao.upsertMessage(companion);
        count++;
      }
      
      socket.close();
      return count;
    } catch (e) {
      return 0;
    }
  }
}

final lanClientProvider = Provider<LanClient>((ref) {
  final dao = ref.watch(messageDaoProvider);
  return LanClient(dao);
});
