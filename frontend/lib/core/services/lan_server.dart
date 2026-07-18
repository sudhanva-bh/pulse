import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:frontend/core/database/daos/message_dao.dart';
import 'package:frontend/features/chat/presentation/chat_provider.dart';

class LanServer {
  final MessageDao _messageDao;
  ServerSocket? _serverSocket;
  String? _token;
  Timer? _expiryTimer;

  LanServer(this._messageDao);

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
    socket.listen((List<int> data) async {
       final String requestStr = utf8.decode(data);
       final request = jsonDecode(requestStr);
       
       if (request['token'] != _token) {
         socket.destroy();
         return;
       }

       // Valid token, send unsynced messages
       final unsynced = await _messageDao.getUnsyncedMessages();
       final payload = unsynced.map((m) => {
         'id': m.id,
         'conversation_id': m.conversationId,
         'content': m.content,
         'created_at': m.createdAt.toUtc().toIso8601String(),
         'updated_at': m.updatedAt.toUtc().toIso8601String(),
         'sender_id': m.senderId,
       }).toList();

       socket.add(utf8.encode(jsonEncode(payload)));
       
       // Update status to deliveredLocally
       for (final m in unsynced) {
         await _messageDao.updateStatus(m.id, 'deliveredLocally');
       }
       
       socket.close();
       stop();
    });
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
  final server = LanServer(dao);
  ref.onDispose(() => server.stop());
  return server;
});
