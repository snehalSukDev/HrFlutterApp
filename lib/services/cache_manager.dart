import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheEntry {
  final dynamic value;
  final int? expiresAt;

  CacheEntry({
    required this.value,
    this.expiresAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'expiresAt': expiresAt,
    };
  }

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      value: json['value'],
      expiresAt: json['expiresAt'] as int?,
    );
  }
}

class CacheManager {
  static Future<void> set(
    String key,
    dynamic value, [
    Duration? ttl,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = CacheEntry(
      value: value,
      expiresAt: ttl != null
          ? DateTime.now().add(ttl).millisecondsSinceEpoch
          : null,
    );
    await prefs.setString(key, jsonEncode(entry.toJson()));
  }

  static Future<dynamic> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) {
      return null;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final entry = CacheEntry.fromJson(map);
      if (entry.expiresAt != null &&
          entry.expiresAt! < DateTime.now().millisecondsSinceEpoch) {
        await prefs.remove(key);
        return null;
      }
      return entry.value;
    } catch (_) {
      return null;
    }
  }
}
