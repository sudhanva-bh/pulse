import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:frontend/core/database/daos/message_dao.dart';
import 'package:frontend/features/chat/presentation/chat_provider.dart';
import 'package:frontend/core/services/lan_connection_manager.dart';

class LanServer {
  final MessageDao _messageDao;
  final Ref ref;
  ServerSocket? _serverSocket;
  String? _token;
  Timer? _expiryTimer;

  LanServer(this._messageDao, this.ref);

  Future<Map<String, dynamic>?> start() async {
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    
    if (ip == null) return null;

    _serverSocket = await ServerSocket.bind(ip, 0);
    _token = const Uuid().v4();

    _expiryTimer = Timer(const Duration(seconds: 60), stop);

    // Wait for connection
    _serverSocket!.listen((Socket socket) {
      _handleConnection(socket);
    });

    return {
      'ip': ip,
      'port': _serverSocket!.port,
      'token': _token,
      'expiry': DateTime.now().millisecondsSinceEpoch + 60000,
    };
  }

  void _handleConnection(Socket socket) {
    // Pass socket to connection manager
    final manager = ref.read(lanConnectionManagerProvider);
    
    manager.attachSocket(
      socket, 
      expectedToken: _token,
      onAuthenticated: () async {
        // Send queued messages upon connection
        final unsynced = await _messageDao.getUnsyncedMessages();
        for (final m in unsynced) {
          manager.sendMessage({
            'id': m.id,
            'conversation_id': m.conversationId,
            'content': m.content,
            'created_at': m.createdAt.toUtc().toIso8601String(),
            'updated_at': m.updatedAt.toUtc().toIso8601String(),
            'sender_id': m.senderId,
          });
          await _messageDao.updateStatus(m.id, 'deliveredLocally');
        }
        
        // Stop accepting new connections
        stop();
      }
    );
  }

  void stop() {
    _expiryTimer?.cancel();
    _serverSocket?.close();
    _serverSocket = null;
    _token = null;
  }
}

final lanServerProvider = Provider<LanServer>((ref) {
  final dao = ref.watch(messageDaoProvider);
  final server = LanServer(dao, ref);
  ref.onDispose(() => server.stop());
  return server;
});
