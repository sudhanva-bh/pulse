import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/routing/app_router.dart';

import 'package:workmanager/workmanager.dart';
import 'package:frontend/core/services/sync_engine.dart';
import 'package:frontend/core/services/connectivity_service.dart';
import 'package:frontend/core/database/app_database.dart';
import 'package:frontend/core/database/daos/message_dao.dart';
import 'package:frontend/core/network/api_client.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final db = AppDatabase();
    final dao = MessageDao(db);
    final api = ApiClient().dio;
    final engine = SyncEngine(dao, api);

    await engine.runSync();
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Workmanager().initialize(callbackDispatcher);

  Workmanager().registerPeriodicTask(
    "periodic_sync",
    "syncTask",
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );

  runApp(const ProviderScope(child: PulseApp()));
}

class PulseApp extends ConsumerWidget {
  const PulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(connectivityServiceProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Pulse',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
