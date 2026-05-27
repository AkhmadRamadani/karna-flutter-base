import '../../../core/result/result.dart';
import '../model/feed_model.dart';

abstract class FeedRepository {
  /// Get by ID using local-first strategy.
  Future<Result<FeedModel>> getById(String id);

  /// Get all using local-first strategy.
  Future<Result<List<FeedModel>>> getAll();

  /// Get from local cache only. Returns Failure on cache miss.
  Future<Result<FeedModel>> getFromCache(String id);

  /// Get from remote only. Always hits network and updates cache.
  Future<Result<FeedModel>> getFromRemote(String id);
}
