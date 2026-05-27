import '../../../core/errors/app_exception.dart';
import '../../../core/network/connectivity_checker.dart';
import '../../../core/result/result.dart';
import 'feed_repository.dart';
import '../model/feed_model.dart';

/// Remote data source abstraction for feed feature.
abstract class FeedRemoteSource {
  Future<Map<String, dynamic>> fetchById(String id);
  Future<List<Map<String, dynamic>>> fetchAll();
}

/// Local data source abstraction for feed feature.
abstract class FeedLocalSource {
  Future<Map<String, dynamic>?> getCached(String id);
  Future<List<Map<String, dynamic>>> getCachedList();
  Future<void> cache(Map<String, dynamic> data);
  Future<void> cacheList(List<Map<String, dynamic>> data);
  Future<void> clearCache();
}

class FeedRepositoryImpl implements FeedRepository {
  final FeedRemoteSource _remoteSource;
  final FeedLocalSource _localSource;
  final ConnectivityChecker _connectivity;

  FeedRepositoryImpl({
    required FeedRemoteSource remoteSource,
    required FeedLocalSource localSource,
    required ConnectivityChecker connectivity,
  })  : _remoteSource = remoteSource,
        _localSource = localSource,
        _connectivity = connectivity;

  @override
  Future<Result<FeedModel>> getById(String id) async {
    try {
      // Try local first
      final cached = await _localSource.getCached(id);
      if (cached != null) {
        return Success(FeedModel.fromJson(cached));
      }

      // Check connectivity before remote call
      if (!await _connectivity.hasConnection) {
        return const Failure(NetworkException(
          message: 'No internet connection',
          code: 'NO_CONNECTION',
        ));
      }

      // Fall back to remote
      final json = await _remoteSource.fetchById(id);
      await _localSource.cache(json);
      return Success(FeedModel.fromJson(json));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<List<FeedModel>>> getAll() async {
    try {
      // Try local first
      final cached = await _localSource.getCachedList();
      if (cached.isNotEmpty) {
        return Success(cached.map(FeedModel.fromJson).toList());
      }

      // Check connectivity before remote call
      if (!await _connectivity.hasConnection) {
        return const Failure(NetworkException(
          message: 'No internet connection',
          code: 'NO_CONNECTION',
        ));
      }

      // Fall back to remote
      final list = await _remoteSource.fetchAll();
      await _localSource.cacheList(list);
      return Success(list.map(FeedModel.fromJson).toList());
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<FeedModel>> getFromCache(String id) async {
    try {
      final cached = await _localSource.getCached(id);
      if (cached != null) {
        return Success(FeedModel.fromJson(cached));
      }
      return const Failure(CacheException(
        message: 'No cached data',
        code: 'CACHE_MISS',
      ));
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<FeedModel>> getFromRemote(String id) async {
    try {
      if (!await _connectivity.hasConnection) {
        return const Failure(NetworkException(
          message: 'No internet connection',
          code: 'NO_CONNECTION',
        ));
      }

      final json = await _remoteSource.fetchById(id);
      await _localSource.cache(json);
      return Success(FeedModel.fromJson(json));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }
}
