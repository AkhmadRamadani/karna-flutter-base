import '../../../core/errors/app_exception.dart';
import '../../../core/network/connectivity_checker.dart';
import '../../../core/result/result.dart';
import 'post_repository.dart';
import '../model/post_model.dart';

/// Remote data source abstraction for post feature.
abstract class PostRemoteSource {
  Future<Map<String, dynamic>> fetchPost(String id);
  Future<List<Map<String, dynamic>>> fetchAllPosts();
}

/// Local data source abstraction for post feature.
abstract class PostLocalSource {
  Future<Map<String, dynamic>?> getCachedPost(String id);
  Future<List<Map<String, dynamic>>> getCachedPosts();
  Future<void> cachePost(Map<String, dynamic> post);
  Future<void> cachePosts(List<Map<String, dynamic>> posts);
  Future<void> clearCache();
}

/// Concrete repository — orchestrates local + remote with connectivity checks.
///
/// This is the standard Karna MVC repository pattern:
/// 1. Try local cache first
/// 2. Check connectivity before remote calls
/// 3. Return typed Result — never throw
class PostRepositoryImpl implements PostRepository {
  final PostRemoteSource _remoteSource;
  final PostLocalSource _localSource;
  final ConnectivityChecker _connectivity;

  PostRepositoryImpl({
    required PostRemoteSource remoteSource,
    required PostLocalSource localSource,
    required ConnectivityChecker connectivity,
  }) : _remoteSource = remoteSource,
       _localSource = localSource,
       _connectivity = connectivity;

  @override
  Future<Result<PostModel>> getPostById(String id) async {
    try {
      final cached = await _localSource.getCachedPost(id);
      if (cached != null) {
        return Success(PostModel.fromJson(cached));
      }

      if (!await _connectivity.hasConnection) {
        return const Failure(
          NetworkException(
            message: 'No internet connection',
            code: 'NO_CONNECTION',
          ),
        );
      }

      final json = await _remoteSource.fetchPost(id);
      await _localSource.cachePost(json);
      return Success(PostModel.fromJson(json));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<List<PostModel>>> getAllPosts() async {
    try {
      final cached = await _localSource.getCachedPosts();
      if (cached.isNotEmpty) {
        return Success(cached.map(PostModel.fromJson).toList());
      }

      if (!await _connectivity.hasConnection) {
        return const Failure(
          NetworkException(
            message: 'No internet connection',
            code: 'NO_CONNECTION',
          ),
        );
      }

      final list = await _remoteSource.fetchAllPosts();
      await _localSource.cachePosts(list);
      return Success(list.map(PostModel.fromJson).toList());
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<PostModel>> getPostFromCache(String id) async {
    try {
      final cached = await _localSource.getCachedPost(id);
      if (cached != null) {
        return Success(PostModel.fromJson(cached));
      }
      return const Failure(
        CacheException(message: 'No cached data', code: 'CACHE_MISS'),
      );
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<PostModel>> getPostFromRemote(String id) async {
    try {
      if (!await _connectivity.hasConnection) {
        return const Failure(
          NetworkException(
            message: 'No internet connection',
            code: 'NO_CONNECTION',
          ),
        );
      }

      final json = await _remoteSource.fetchPost(id);
      await _localSource.cachePost(json);
      return Success(PostModel.fromJson(json));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<List<PostModel>>> getPostsFromCache() async {
    try {
      final cached = await _localSource.getCachedPosts();
      if (cached.isNotEmpty) {
        return Success(cached.map(PostModel.fromJson).toList());
      }
      return const Failure(
        CacheException(message: 'No cached data', code: 'CACHE_MISS'),
      );
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<List<PostModel>>> getPostsFromRemote() async {
    try {
      if (!await _connectivity.hasConnection) {
        return const Failure(
          NetworkException(
            message: 'No internet connection',
            code: 'NO_CONNECTION',
          ),
        );
      }

      final list = await _remoteSource.fetchAllPosts();
      await _localSource.cachePosts(list);
      return Success(list.map(PostModel.fromJson).toList());
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }
}
