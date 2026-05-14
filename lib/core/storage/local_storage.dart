/// Storage-agnostic interface for local data persistence.
///
/// Features use this abstraction in their local sources instead of
/// depending directly on SharedPreferences, Hive, SQLite, etc.
///
/// Swap the implementation in `core/di/providers.dart` to change
/// the storage backend for the entire app — no feature code changes needed.
abstract class LocalStorage {
  /// Get a single JSON object by key.
  Future<Map<String, dynamic>?> getJson(String key);

  /// Get a list of JSON objects by key.
  Future<List<Map<String, dynamic>>> getJsonList(String key);

  /// Store a single JSON object.
  Future<void> putJson(String key, Map<String, dynamic> value);

  /// Store a list of JSON objects.
  Future<void> putJsonList(String key, List<Map<String, dynamic>> value);

  /// Remove a specific key.
  Future<void> remove(String key);

  /// Remove all keys matching a prefix.
  /// Useful for clearing all data for a feature: `removeByPrefix('auth_')`
  Future<void> removeByPrefix(String prefix);

  /// Clear all stored data.
  Future<void> clear();

  /// Check if a key exists.
  Future<bool> has(String key);
}
