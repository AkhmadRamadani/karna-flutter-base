import '../../../core/errors/app_exception.dart';
import '../../../core/network/connectivity_checker.dart';
import '../../../core/result/result.dart';
import 'profile_repository.dart';
import '../model/profile_model.dart';

/// Remote data source abstraction for profile feature.
abstract class ProfileRemoteSource {
  Future<Map<String, dynamic>> fetchProfile(String id);
  Future<void> updateProfile(Map<String, dynamic> data);
}

/// Local data source abstraction for profile feature.
abstract class ProfileLocalSource {
  Future<Map<String, dynamic>?> getCachedProfile(String id);
  Future<void> cacheProfile(Map<String, dynamic> profile);
  Future<void> clearCache();
}

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteSource _remoteSource;
  final ProfileLocalSource _localSource;
  final ConnectivityChecker _connectivity;

  ProfileRepositoryImpl({
    required ProfileRemoteSource remoteSource,
    required ProfileLocalSource localSource,
    required ConnectivityChecker connectivity,
  }) : _remoteSource = remoteSource,
       _localSource = localSource,
       _connectivity = connectivity;

  @override
  Future<Result<ProfileModel>> getProfileById(String id) async {
    try {
      final cached = await _localSource.getCachedProfile(id);
      if (cached != null) {
        return Success(ProfileModel.fromJson(cached));
      }

      if (!await _connectivity.hasConnection) {
        return const Failure(
          NetworkException(
            message: 'No internet connection',
            code: 'NO_CONNECTION',
          ),
        );
      }

      final json = await _remoteSource.fetchProfile(id);
      await _localSource.cacheProfile(json);
      return Success(ProfileModel.fromJson(json));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<ProfileModel>> getProfileFromCache(String id) async {
    try {
      final cached = await _localSource.getCachedProfile(id);
      if (cached != null) {
        return Success(ProfileModel.fromJson(cached));
      }
      return const Failure(
        CacheException(message: 'No cached data', code: 'CACHE_MISS'),
      );
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<ProfileModel>> getProfileFromRemote(String id) async {
    try {
      if (!await _connectivity.hasConnection) {
        return const Failure(
          NetworkException(
            message: 'No internet connection',
            code: 'NO_CONNECTION',
          ),
        );
      }

      final json = await _remoteSource.fetchProfile(id);
      await _localSource.cacheProfile(json);
      return Success(ProfileModel.fromJson(json));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> updateProfile(ProfileModel profile) async {
    try {
      if (!await _connectivity.hasConnection) {
        return const Failure(
          NetworkException(
            message: 'No internet connection',
            code: 'NO_CONNECTION',
          ),
        );
      }

      await _remoteSource.updateProfile(profile.toJson());
      await _localSource.cacheProfile(profile.toJson());
      return const Success(null);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }
}
