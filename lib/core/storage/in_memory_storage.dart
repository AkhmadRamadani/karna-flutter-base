import 'local_storage.dart';

/// In-memory implementation of [LocalStorage].
///
/// Useful for:
/// - Development and prototyping (no setup needed)
/// - Tests (fast, no disk I/O)
/// - As a fallback when no persistent storage is configured
///
/// Data is lost when the app restarts.
class InMemoryStorage implements LocalStorage {
  final Map<String, dynamic> _store = {};

  @override
  Future<Map<String, dynamic>?> getJson(String key) async {
    final value = _store[key];
    if (value is Map<String, dynamic>) return Map.from(value);
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    final value = _store[key];
    if (value is List) {
      return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  @override
  Future<void> putJson(String key, Map<String, dynamic> value) async {
    _store[key] = Map<String, dynamic>.from(value);
  }

  @override
  Future<void> putJsonList(String key, List<Map<String, dynamic>> value) async {
    _store[key] = value.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> removeByPrefix(String prefix) async {
    _store.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<bool> has(String key) async {
    return _store.containsKey(key);
  }
}
