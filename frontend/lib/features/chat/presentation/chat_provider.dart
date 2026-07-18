import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/database/app_database.dart'
    hide Message, Conversation;
import 'package:frontend/core/database/daos/conversation_dao.dart';
import 'package:frontend/core/database/daos/message_dao.dart';
import 'package:frontend/features/chat/data/conversation_repository.dart';
import 'package:frontend/features/chat/data/message_repository.dart';
import 'package:frontend/features/chat/domain/conversation.dart';
import 'package:frontend/features/chat/domain/message.dart';
import 'package:frontend/core/providers/user_provider.dart';

import 'package:frontend/core/network/websocket_manager.dart';
import 'package:frontend/core/services/sync_engine.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final messageDaoProvider = Provider<MessageDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.messageDao;
});

final conversationDaoProvider = Provider<ConversationDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.conversationDao;
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final messageDao = ref.read(messageDaoProvider);
  final conversationDao = ref.read(conversationDaoProvider);
  final wsManager = ref.read(webSocketManagerProvider);
  final syncEngine = ref.read(syncEngineProvider);
  return MessageRepository(messageDao, conversationDao, wsManager, syncEngine);
});

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository(ref.watch(conversationDaoProvider));
});

final messagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  conversationId,
) {
  return ref.watch(messageRepositoryProvider).watchMessages(conversationId);
});

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  return ref.watch(conversationRepositoryProvider).watchConversations();
});

final acceptedConversationsProvider = StreamProvider<List<Conversation>>((
  ref,
) async* {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) {
    yield [];
    return;
  }

  await for (final list
      in ref.watch(conversationRepositoryProvider).watchConversations()) {
    yield list
        .where(
          (c) =>
              c.status == 'accepted' ||
              (c.status == 'pending' && c.initiatorId == currentUser) ||
              (c.status == 'rejected' && c.initiatorId == currentUser),
        )
        .toList();
  }
});

final pendingRequestsProvider = StreamProvider<List<Conversation>>((
  ref,
) async* {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) {
    yield [];
    return;
  }

  await for (final list
      in ref.watch(conversationRepositoryProvider).watchConversations()) {
    yield list
        .where((c) => c.status == 'pending' && c.initiatorId != currentUser)
        .toList();
  }
});

final unreadRequestsCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(pendingRequestsProvider).whenData((list) => list.length);
});

final typingStreamProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  return ref.watch(webSocketManagerProvider).typingStream;
});

final connectionStateProvider = StreamProvider<WsConnectionState>((ref) {
  return ref.watch(webSocketManagerProvider).connectionStateStream;
});
