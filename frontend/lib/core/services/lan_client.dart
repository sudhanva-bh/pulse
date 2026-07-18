import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/services/lan_connection_manager.dart';

class LanClient {
  final Ref ref;
  
  LanClient(this.ref);

  Future<int> connectAndReceive(String ip, int port, String token) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      socket.write('${jsonEncode({'token': token})}\n');

      final manager = ref.read(lanConnectionManagerProvider);
      manager.attachSocket(socket); // Client is already authenticated

      return 1; // Indicate success connection
    } catch (e) {
      return 0;
    }
  }
}

final lanClientProvider = Provider<LanClient>((ref) {
  return LanClient(ref);
});
