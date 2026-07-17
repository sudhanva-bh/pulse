import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/auth/presentation/auth_provider.dart';
import 'package:frontend/features/auth/presentation/login_screen.dart';
import 'package:frontend/features/auth/presentation/register_screen.dart';
import 'package:frontend/features/chat/presentation/conversation_list_screen.dart';
import 'package:frontend/features/chat/presentation/chat_screen.dart';
import 'package:frontend/features/chat/presentation/requests_screen.dart';
import 'package:frontend/features/settings/presentation/settings_screen.dart';
import 'package:frontend/features/sync/presentation/sync_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isSplash = state.matchedLocation == '/splash';
      final isLogin = state.matchedLocation == '/login';
      final isRegister = state.matchedLocation == '/register';

      if (authState is AuthInitial) {
        return isSplash ? null : '/splash';
      }
      if (authState is AuthUnauthenticated) {
        return (isLogin || isRegister) ? null : '/login';
      }
      if (authState is AuthAuthenticated) {
        if (isSplash) {
          return '/home';
        }
        if (isLogin || isRegister) {
          return '/sync';
        }
        return null;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const ConversationListScreen()),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          return ChatScreen(conversationId: conversationId);
        },
      ),
      GoRoute(
        path: '/requests',
        builder: (context, state) => const RequestsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/sync',
        builder: (context, state) => const SyncScreen(),
      ),
    ],
  );
});

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Triggers session check on first frame
    Future.microtask(() => ref.read(authProvider.notifier).checkSession());
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
