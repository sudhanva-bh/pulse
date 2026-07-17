import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/auth/domain/user.dart';
import 'package:frontend/core/database/app_database.dart';
import 'package:frontend/features/chat/presentation/chat_provider.dart';

sealed class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final User user;
  AuthAuthenticated(this.user);
}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

final authRepositoryProvider = Provider((ref) => AuthRepository());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(authRepositoryProvider), ref.read(appDatabaseProvider)),
);

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final AppDatabase _db;

  AuthNotifier(this._repo, this._db) : super(AuthInitial());

  Future<void> checkSession() async {
    final loggedIn = await _repo.isLoggedIn();
    state = loggedIn ? AuthAuthenticated(
      User(id: '', username: ''),  // hydrated properly in Week 6 via /auth/me
    ) : AuthUnauthenticated();
  }

  Future<void> login(String username, String password) async {
    state = AuthLoading();
    try {
      final user = await _repo.login(username, password);
      state = AuthAuthenticated(user);
    } on DioException catch (e) {
      state = AuthError(_parseDioError(e, 'Login failed'));
    }
  }

  Future<void> register(String username, String password) async {
    state = AuthLoading();
    try {
      final user = await _repo.register(username, password);
      state = AuthAuthenticated(user);
    } on DioException catch (e) {
      state = AuthError(_parseDioError(e, 'Registration failed'));
    }
  }

  String _parseDioError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data.containsKey('detail')) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        return detail[0]['msg'] ?? fallback;
      }
    }
    return fallback;
  }

  Future<void> logout() async {
    await _db.messageDao.deleteAll();
    await _db.conversationDao.deleteAll();
    await _repo.logout();
    state = AuthUnauthenticated();
  }
}