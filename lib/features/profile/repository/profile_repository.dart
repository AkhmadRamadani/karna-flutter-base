import '../../../core/result/result.dart';
import '../model/profile_model.dart';

abstract class ProfileRepository {
  /// Get profile using local-first strategy.
  Future<Result<ProfileModel>> getProfileById(String id);

  /// Get profile from local cache only.
  Future<Result<ProfileModel>> getProfileFromCache(String id);

  /// Get profile from remote only. Always hits network and updates cache.
  Future<Result<ProfileModel>> getProfileFromRemote(String id);

  /// Update profile (always remote, then cache).
  Future<Result<void>> updateProfile(ProfileModel profile);
}
