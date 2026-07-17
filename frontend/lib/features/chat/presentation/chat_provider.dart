import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/database/app_database.dart' hide Message, Conversation;
import 'package:frontend/core/database/daos/conversation_dao.dart';
import 'package:frontend/core/database/daos/message_dao.dart';
import 'package:frontend/features/chat/data/conversation_repository.dart';
import 'package:frontend/features/chat/data/message_repository.dart';
import 'package:frontend/features/chat/domain/conversation.dart';
import 'package:frontend/features/chat/domain/message.dart';

import 'package:frontend/core/network/websocket_manager.dart';

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
  return MessageRepository(
    ref.watch(messageDaoProvider),
    ref.watch(webSocketManagerProvider),
  );
});

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository(ref.watch(conversationDaoProvider));
});

final messagesProvider = StreamProvider.family<List<Message>, String>((ref, conversationId) {
  final repository = ref.watch(messageRepositoryProvider);
  return repository.watchMessages(conversationId);
});

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final repository = ref.watch(conversationRepositoryProvider);
  return repository.watchConversations();
});

final connectionStateProvider = StreamProvider<WsConnectionState>((ref) {
  final ws = ref.watch(webSocketManagerProvider);
  return ws.connectionStateStream;
});

final typingStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final ws = ref.watch(webSocketManagerProvider);
  return ws.typingStream;
});
