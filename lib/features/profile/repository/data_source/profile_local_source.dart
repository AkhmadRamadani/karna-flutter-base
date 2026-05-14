import '../../../../core/storage/local_storage.dart';
import '../profile_repository_impl.dart';

/// Profile local source backed by the agnostic [LocalStorage].
class ProfileLocalSourceImpl implements ProfileLocalSource {
  final LocalStorage _storage;

  static const _keyPrefix = 'profile_';
  static const _profileKey = '${_keyPrefix}data_';

  ProfileLocalSourceImpl({required LocalStorage storage}) : _storage = storage;

  @override
  Future<Map<String, dynamic>?> getCachedProfile(String id) async {
    return _storage.getJson('$_profileKey$id');
  }

  @override
  Future<void> cacheProfile(Map<String, dynamic> profile) async {
    final id = profile['id'] as String;
    await _storage.putJson('$_profileKey$id', profile);
  }

  @override
  Future<void> clearCache() async {
    await _storage.removeByPrefix(_keyPrefix);
  }
}
