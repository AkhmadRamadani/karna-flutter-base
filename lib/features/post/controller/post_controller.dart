import 'dart:async';

import '../../../core/controller/base_controller.dart';
import '../../../core/events/app_events.dart';
import '../../../core/events/event_bus.dart';
import '../../../core/network/data_strategy.dart';
import '../model/post_model.dart';
import '../repository/post_repository.dart';

/// Example controller demonstrating:
/// - All three data strategies (localFirst, staleWhileRevalidate, remoteFirst)
/// - EventBus integration (subscribing + publishing)
/// - BaseController state management (isLoading, isRefreshing, hasError)
class PostController extends BaseController {
  final PostRepository _repository;
  final EventBus _eventBus;

  late final StreamSubscription<CacheClearedEvent> _cacheClearedSub;

  PostController({
    required PostRepository repository,
    required EventBus eventBus,
  }) : _repository = repository,
       _eventBus = eventBus {
    // Example: react to app-wide cache clear event
    _cacheClearedSub = _eventBus.on<CacheClearedEvent>().listen((_) {
      _posts = [];
      _selectedPost = null;
      notifyListeners();
    });
  }

  List<PostModel> _posts = [];
  PostModel? _selectedPost;

  List<PostModel> get posts => _posts;
  PostModel? get selectedPost => _selectedPost;

  /// Load all posts with the specified data strategy.
  ///
  /// Usage examples:
  /// ```dart
  /// // Default — cache first, network on miss
  /// controller.loadPosts();
  ///
  /// // Show stale list immediately, refresh in background
  /// controller.loadPosts(strategy: DataStrategy.staleWhileRevalidate);
  ///
  /// // Always hit network (e.g. pull-to-refresh)
  /// controller.loadPosts(strategy: DataStrategy.remoteFirst);
  /// ```
  Future<void> loadPosts({
    DataStrategy strategy = DataStrategy.localFirst,
  }) async {
    await load(
      strategy: strategy,
      cacheAction: () => _repository.getPostsFromCache(),
      freshAction: () => _repository.getPostsFromRemote(),
      onSuccess: (data) => _posts = data,
    );
  }

  /// Load a single post by ID.
  Future<void> loadPost(
    String id, {
    DataStrategy strategy = DataStrategy.localFirst,
  }) async {
    await load(
      strategy: strategy,
      cacheAction: () => _repository.getPostFromCache(id),
      freshAction: () => _repository.getPostFromRemote(id),
      onSuccess: (data) => _selectedPost = data,
    );
  }

  @override
  void dispose() {
    _cacheClearedSub.cancel();
    super.dispose();
  }
}
