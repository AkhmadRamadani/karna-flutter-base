import 'dart:convert';

import 'package:hive_ce/hive.dart';

import 'local_storage.dart';

/// [LocalStorage] implementation backed by Hive.
///
/// Good for: larger datasets, faster reads, offline-first apps.
/// Not ideal for: complex relational queries (use a full DB instead).
///
/// Usage:
/// ```dart
/// final box = await Hive.openBox<String>('app_storage');
/// final storage = HiveStorage(box: box);
/// ```
class HiveStorage implements LocalStorage {
  final Box<String> _box;

  HiveStorage({required Box<String> box}) : _box = box;

  @override
  Future<Map<String, dynamic>?> getJson(String key) async {
    final raw = _box.get(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    final raw = _box.get(key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  @override
  Future<void> putJson(String key, Map<String, dynamic> value) async {
    await _box.put(key, jsonEncode(value));
  }

  @override
  Future<void> putJsonList(String key, List<Map<String, dynamic>> value) async {
    await _box.put(key, jsonEncode(value));
  }

  @override
  Future<void> remove(String key) async {
    await _box.delete(key);
  }

  @override
  Future<void> removeByPrefix(String prefix) async {
    final keys = _box.keys
        .whereType<String>()
        .where((k) => k.startsWith(prefix))
        .toList();
    await _box.deleteAll(keys);
  }

  @override
  Future<void> clear() async {
    await _box.clear();
  }

  @override
  Future<bool> has(String key) async {
    return _box.containsKey(key);
  }
}
