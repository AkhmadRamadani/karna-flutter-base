import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'local_storage.dart';

/// [LocalStorage] implementation backed by SharedPreferences.
///
/// Good for: small key-value data, user settings, simple caches.
/// Not ideal for: large datasets, complex queries, relational data.
class SharedPrefsStorage implements LocalStorage {
  final SharedPreferences _prefs;

  SharedPrefsStorage({required SharedPreferences prefs}) : _prefs = prefs;

  @override
  Future<Map<String, dynamic>?> getJson(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  @override
  Future<void> putJson(String key, Map<String, dynamic> value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  @override
  Future<void> putJsonList(String key, List<Map<String, dynamic>> value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  @override
  Future<void> removeByPrefix(String prefix) async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(prefix));
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  @override
  Future<void> clear() async {
    await _prefs.clear();
  }

  @override
  Future<bool> has(String key) async {
    return _prefs.containsKey(key);
  }
}
