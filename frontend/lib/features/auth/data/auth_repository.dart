import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/features/auth/domain/user.dart';

class AuthRepository {
  final Dio _dio = ApiClient().dio;

  Future<User> login(String username, String password) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'username': username, 'password': password},
      options: Options(contentType: 'application/x-www-form-urlencoded'),
      // OAuth2 password flow requires form data, not JSON
    );

    final token = response.data['access_token'] as String;
    final userId = response.data['user_id'] as String;

    await SecureStorage.saveToken(token);
    await SecureStorage.saveUserId(userId);

    return User(id: userId, username: username);
  }

  Future<User> register(String username, String password) async {
    await _dio.post('/auth/register', data: {
      'username': username,
      'password': password,
    });
    return login(username, password);
  }

  Future<bool> isLoggedIn() async {
    final token = await SecureStorage.getToken();
    return token != null;
  }

  Future<void> logout() async {
    await SecureStorage.clear();
  }
}