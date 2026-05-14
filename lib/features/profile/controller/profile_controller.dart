import '../../../core/controller/base_controller.dart';
import '../../../core/network/data_strategy.dart';
import '../model/profile_model.dart';
import '../repository/profile_repository.dart';

class ProfileController extends BaseController {
  final ProfileRepository _repository;

  ProfileController({required ProfileRepository repository})
    : _repository = repository;

  ProfileModel? _profile;

  ProfileModel? get profile => _profile;

  /// Load profile with the specified data strategy.
  ///
  /// Examples:
  ///   loadProfile('1')                                              → local-first
  ///   loadProfile('1', strategy: DataStrategy.staleWhileRevalidate) → cache + refresh
  ///   loadProfile('1', strategy: DataStrategy.remoteFirst)          → always network
  Future<void> loadProfile(
    String id, {
    DataStrategy strategy = DataStrategy.localFirst,
  }) async {
    await load(
      strategy: strategy,
      cacheAction: () => _repository.getProfileFromCache(id),
      freshAction: () => _repository.getProfileFromRemote(id),
      onSuccess: (data) => _profile = data,
    );
  }

  /// Update profile (always remote-first).
  Future<void> updateProfile(ProfileModel profile) async {
    await executeResult(
      () => _repository.updateProfile(profile),
      onSuccess: (_) => _profile = profile,
    );
  }
}
