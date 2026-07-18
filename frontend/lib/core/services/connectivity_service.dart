import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;

  ConnectivityService() {
    _subscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.isEmpty) return;
      final result = results.first;
      if (result != ConnectivityResult.none) {
        // Trigger one-shot sync task
        Workmanager().registerOneOffTask(
          "sync_on_reconnect",
          "syncTask",
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingWorkPolicy.replace,
        );
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});
