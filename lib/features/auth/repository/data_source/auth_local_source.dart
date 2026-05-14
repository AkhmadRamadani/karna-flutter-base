import '../../../../core/storage/local_storage.dart';
import '../auth_repository_impl.dart';

/// Auth local source backed by the agnostic [LocalStorage].
class AuthLocalSourceImpl implements AuthLocalSource {
  final LocalStorage _storage;

  static const _keyPrefix = 'auth_';
  static const _userKey = '${_keyPrefix}user_';
  static const _usersKey = '${_keyPrefix}users';

  AuthLocalSourceImpl({required LocalStorage storage}) : _storage = storage;

  @override
  Future<Map<String, dynamic>?> getCachedUser(String id) async {
    return _storage.getJson('$_userKey$id');
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedUsers() async {
    return _storage.getJsonList(_usersKey);
  }

  @override
  Future<void> cacheUser(Map<String, dynamic> user) async {
    final id = user['id'] as String;
    await _storage.putJson('$_userKey$id', user);
  }

  @override
  Future<void> cacheUsers(List<Map<String, dynamic>> users) async {
    await _storage.putJsonList(_usersKey, users);
  }

  @override
  Future<void> clearCache() async {
    await _storage.removeByPrefix(_keyPrefix);
  }
}
