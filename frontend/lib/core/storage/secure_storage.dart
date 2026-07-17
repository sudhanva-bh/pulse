import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveToken(String token) =>
      _storage.write(key: 'jwt', value: token);

  static Future<String?> getToken() =>
      _storage.read(key: 'jwt');

  static Future<void> saveUserId(String id) =>
      _storage.write(key: 'user_id', value: id);

  static Future<String?> getUserId() =>
      _storage.read(key: 'user_id');

  static Future<void> saveDraft(String conversationId, String draft) =>
      _storage.write(key: 'draft_$conversationId', value: draft);

  static Future<String?> getDraft(String conversationId) =>
      _storage.read(key: 'draft_$conversationId');

  static Future<void> clearDraft(String conversationId) =>
      _storage.delete(key: 'draft_$conversationId');

  static Future<void> clear() => _storage.deleteAll();
}