import '../../../../core/storage/local_storage.dart';
import '../feed_repository_impl.dart';

/// Feed local source backed by the agnostic [LocalStorage].
class FeedLocalSourceImpl implements FeedLocalSource {
  final LocalStorage _storage;

  static const _keyPrefix = 'feed_';
  static const _itemKey = '${_keyPrefix}item_';
  static const _listKey = '${_keyPrefix}list';

  FeedLocalSourceImpl({required LocalStorage storage}) : _storage = storage;

  @override
  Future<Map<String, dynamic>?> getCached(String id) async {
    return _storage.getJson('$_itemKey$id');
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedList() async {
    return _storage.getJsonList(_listKey);
  }

  @override
  Future<void> cache(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    await _storage.putJson('$_itemKey$id', data);
  }

  @override
  Future<void> cacheList(List<Map<String, dynamic>> data) async {
    await _storage.putJsonList(_listKey, data);
  }

  @override
  Future<void> clearCache() async {
    await _storage.removeByPrefix(_keyPrefix);
  }
}
