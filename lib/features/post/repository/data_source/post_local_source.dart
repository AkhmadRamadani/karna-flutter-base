import '../../../../core/storage/local_storage.dart';
import '../post_repository_impl.dart';

/// Local source — uses the agnostic LocalStorage interface for caching.
class PostLocalSourceImpl implements PostLocalSource {
  final LocalStorage _storage;

  static const _keyPrefix = 'post_';
  static const _postKey = '${_keyPrefix}item_';
  static const _postsKey = '${_keyPrefix}all';

  PostLocalSourceImpl({required LocalStorage storage}) : _storage = storage;

  @override
  Future<Map<String, dynamic>?> getCachedPost(String id) async {
    return _storage.getJson('$_postKey$id');
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedPosts() async {
    return _storage.getJsonList(_postsKey);
  }

  @override
  Future<void> cachePost(Map<String, dynamic> post) async {
    final id = post['id'] as String;
    await _storage.putJson('$_postKey$id', post);
  }

  @override
  Future<void> cachePosts(List<Map<String, dynamic>> posts) async {
    await _storage.putJsonList(_postsKey, posts);
  }

  @override
  Future<void> clearCache() async {
    await _storage.removeByPrefix(_keyPrefix);
  }
}
