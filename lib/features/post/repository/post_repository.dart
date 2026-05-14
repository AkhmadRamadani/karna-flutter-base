import '../../../core/result/result.dart';
import '../model/post_model.dart';

/// Abstract repository — returns Result, exposes cache/remote separately
/// to support all three data strategies in the controller.
abstract class PostRepository {
  /// Get a single post (local-first orchestration).
  Future<Result<PostModel>> getPostById(String id);

  /// Get all posts (local-first orchestration).
  Future<Result<List<PostModel>>> getAllPosts();

  /// Get post from local cache only. Returns Failure on miss.
  Future<Result<PostModel>> getPostFromCache(String id);

  /// Get post from remote only. Always hits network and updates cache.
  Future<Result<PostModel>> getPostFromRemote(String id);

  /// Get all posts from local cache only.
  Future<Result<List<PostModel>>> getPostsFromCache();

  /// Get all posts from remote only.
  Future<Result<List<PostModel>>> getPostsFromRemote();
}
