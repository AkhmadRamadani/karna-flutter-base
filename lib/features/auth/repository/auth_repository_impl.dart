import '../../../core/errors/app_exception.dart';
import '../../../core/network/connectivity_checker.dart';
import '../../../core/result/result.dart';
import 'auth_repository.dart';
import '../model/user_model.dart';

/// Remote data source abstraction for auth feature.
abstract class AuthRemoteSource {
  Future<Map<String, dynamic>> fetchUser(String id);
  Future<List<Map<String, dynamic>>> fetchAllUsers();
}

/// Local data source abstraction for auth feature.
abstract class AuthLocalSource {
  Future<Map<String, dynamic>?> getCachedUser(String id);
  Future<List<Map<String, dynamic>>> getCachedUsers();
  Future<void> cacheUser(Map<String, dynamic> user);
  Future<void> cacheUsers(List<Map<String, dynamic>> users);
  Future<void> clearCache();
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteSource _remoteSource;
  final AuthLocalSource _localSource;
  final ConnectivityChecker _connectivity;

  AuthRepositoryImpl({
    required AuthRemoteSource remoteSource,
    required AuthLocalSource localSource,
    required ConnectivityChecker connectivity,
  }) : _remoteSource = remoteSource,
       _localSource = localSource,
       _connectivity = connectivity;

  @override
  Future<Result<UserModel>> getUserById(String id) async {
    try {
      // Try local first
      final cached = await _localSource.getCachedUser(id);
      if (cached != null) {
        return Success(UserModel.fromJson(cached));
      }

      // Check connectivity before remote call
      if (!await _connectivity.hasConnection) {
        return const Failure(
          NetworkException(
            message: 'No internet connection',
            code: 'NO_CONNECTION',
          ),
        );
      }

      // Fall back to remote
      final json = await _remoteSource.fetchUser(id);
      await _localSource.cacheUser(json);
      return Success(UserModel.fromJson(json));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<List<UserModel>>> getAllUsers() async {
    try {
      // Try local first
      final cached = await _localSource.getCachedUsers();
      if (cached.isNotEmpty) {
        return Success(cached.map(UserModel.fromJson).toList());
      }

      // Check connectivity before remote call
      if (!await _connectivity.hasConnection) {
        return const Failure(
          NetworkException(
            message: 'No internet connection',
            code: 'NO_CONNECTION',
          ),
        );
      }

      // Fall back to remote
      final list = await _remoteSource.fetchAllUsers();
      await _localSource.cacheUsers(list);
      return Success(list.map(UserModel.fromJson).toList());
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<UserModel>> getUserFromCache(String id) async {
    try {
      final cached = await _localSource.getCachedUser(id);
      if (cached != null) {
        return Success(UserModel.fromJson(cached));
      }
      return const Failure(
        CacheException(message: 'No cached data', code: 'CACHE_MISS'),
      );
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<UserModel>> getUserFromRemote(String id) async {
    try {
      if (!await _connectivity.hasConnection) {
        return const Failure(
          NetworkException(
            message: 'No internet connection',
            code: 'NO_CONNECTION',
          ),
        );
      }

      final json = await _remoteSource.fetchUser(id);
      await _localSource.cacheUser(json);
      return Success(UserModel.fromJson(json));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }
}
