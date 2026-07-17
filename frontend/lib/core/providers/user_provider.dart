import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/storage/secure_storage.dart';

final currentUserProvider = FutureProvider<String?>((ref) async {
  return await SecureStorage.getUserId();
});
