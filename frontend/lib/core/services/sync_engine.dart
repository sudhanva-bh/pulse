import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/database/daos/message_dao.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:drift/drift.dart' as drift;
import 'package:frontend/core/database/app_database.dart' as db;
import 'package:frontend/features/chat/presentation/chat_provider.dart';

class SyncEngine {
  final MessageDao _messageDao;
  final Dio _dio;

  SyncEngine(this._messageDao, this._dio);

  Future<bool> runSync() async {
    try {
      final since =
          await SecureStorage.getLastSyncTimestamp() ??
          DateTime.fromMillisecondsSinceEpoch(0).toUtc();

      final unsynced = await _messageDao.getUnsyncedMessages();
      final messagesPayload = unsynced
          .map(
            (m) => {
              'id': m.id,
              'conversation_id': m.conversationId,
              'content': m.content,
              'created_at': m.createdAt.toUtc().toIso8601String(),
              'updated_at': m.updatedAt.toUtc().toIso8601String(),
            },
          )
          .toList();

      final response = await _dio.post(
        '/sync',
        data: {
          'last_sync_timestamp': since.toIso8601String(),
          'messages': messagesPayload,
        },
      );

      // On success, mark local as synced
      for (final msg in unsynced) {
        await _messageDao.markSynced(msg.id);
        await _messageDao.updateStatus(msg.id, 'sent');
      }

      if (unsynced.isNotEmpty) {
        toastification.show(
          title: const Text('Messages delivered'),
          type: ToastificationType.success,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }

      // Process incoming
      final List data = response.data;
      DateTime? maxSyncedAt;

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

        final syncedAt = DateTime.parse(json['synced_at']).toUtc();
        if (maxSyncedAt == null || syncedAt.isAfter(maxSyncedAt)) {
          maxSyncedAt = syncedAt;
        }
      }

      if (maxSyncedAt != null) {
        await SecureStorage.saveLastSyncTimestamp(maxSyncedAt);
      }

      return true;
    } catch (e) {
      return false; // WorkManager will retry
    }
  }
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final dao = ref.watch(messageDaoProvider);
  final api = ApiClient().dio;
  return SyncEngine(dao, api);
});
