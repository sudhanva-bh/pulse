import 'package:dio/dio.dart';
import 'package:frontend/core/storage/secure_storage.dart';

class ApiClient {
  static const _baseUrl = 'http://127.0.0.1:8080';
  // 10.0.2.2:8000 : Android emulator
  // Change to 192.168.1.3:8000 for a physical device without adb reverse

  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    dio.interceptors.add(_AuthInterceptor());
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
