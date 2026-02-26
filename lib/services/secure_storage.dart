import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> setItem(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  static Future<String?> getItem(String key) {
    return _storage.read(key: key);
  }

  static Future<void> removeItem(String key) {
    return _storage.delete(key: key);
  }
}
