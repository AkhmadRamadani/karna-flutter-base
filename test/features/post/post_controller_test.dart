import 'package:flutter_test/flutter_test.dart';
import 'package:karna_mvc/core/errors/app_exception.dart';
import 'package:karna_mvc/core/events/app_events.dart';
import 'package:karna_mvc/core/events/event_bus.dart';
import 'package:karna_mvc/core/network/data_strategy.dart';
import 'package:karna_mvc/core/result/result.dart';
import 'package:karna_mvc/features/post/controller/post_controller.dart';
import 'package:karna_mvc/features/post/model/post_model.dart';
import 'package:karna_mvc/features/post/repository/post_repository.dart';

class MockPostRepository implements PostRepository {
  Result<PostModel>? postResult;
  Result<List<PostModel>>? postsResult;
  Result<PostModel>? cacheResult;
  Result<PostModel>? remoteResult;
  Result<List<PostModel>>? postsCacheResult;
  Result<List<PostModel>>? postsRemoteResult;

  @override
  Future<Result<PostModel>> getPostById(String id) async => postResult!;

  @override
  Future<Result<List<PostModel>>> getAllPosts() async => postsResult!;

  @override
  Future<Result<PostModel>> getPostFromCache(String id) async => cacheResult!;

  @override
  Future<Result<PostModel>> getPostFromRemote(String id) async => remoteResult!;

  @override
  Future<Result<List<PostModel>>> getPostsFromCache() async =>
      postsCacheResult!;

  @override
  Future<Result<List<PostModel>>> getPostsFromRemote() async =>
      postsRemoteResult!;
}

void main() {
  late MockPostRepository mockRepo;
  late PostController controller;
  late EventBusImpl eventBus;

  final fakePost = PostModel(
    id: '1',
    title: 'Hello World',
    body: 'This is a test post.',
    authorId: 'author_1',
  );

  setUp(() {
    mockRepo = MockPostRepository();
    eventBus = EventBusImpl();
    controller = PostController(repository: mockRepo, eventBus: eventBus);
  });

  tearDown(() {
    controller.dispose();
    eventBus.dispose();
  });

  group('DataStrategy.localFirst', () {
    test('shows cached posts when available', () async {
      mockRepo.postsCacheResult = Success([fakePost]);

      await controller.loadPosts();

      expect(controller.posts.length, equals(1));
      expect(controller.posts.first.title, equals('Hello World'));
      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
    });

    test('falls back to remote on cache miss', () async {
      mockRepo.postsCacheResult = const Failure(
        CacheException(message: 'miss', code: 'CACHE_MISS'),
      );
      mockRepo.postsRemoteResult = Success([fakePost]);

      await controller.loadPosts();

      expect(controller.posts.length, equals(1));
      expect(controller.hasError, isFalse);
    });

    test('sets error when both fail', () async {
      mockRepo.postsCacheResult = const Failure(
        CacheException(message: 'miss', code: 'CACHE_MISS'),
      );
      mockRepo.postsRemoteResult = const Failure(
        NetworkException(message: 'No connection', code: 'NO_CONNECTION'),
      );

      await controller.loadPosts();

      expect(controller.posts, isEmpty);
      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, equals('No connection'));
    });
  });

  group('DataStrategy.staleWhileRevalidate', () {
    test('shows cache then replaces with fresh data', () async {
      final stalePost = fakePost.copyWith(title: 'Stale Title');
      final freshPost = fakePost.copyWith(title: 'Fresh Title');

      mockRepo.postsCacheResult = Success([stalePost]);
      mockRepo.postsRemoteResult = Success([freshPost]);

      await controller.loadPosts(strategy: DataStrategy.staleWhileRevalidate);

      expect(controller.posts.first.title, equals('Fresh Title'));
      expect(controller.isLoading, isFalse);
      expect(controller.isRefreshing, isFalse);
    });

    test('keeps stale data when refresh fails', () async {
      final stalePost = fakePost.copyWith(title: 'Stale Title');

      mockRepo.postsCacheResult = Success([stalePost]);
      mockRepo.postsRemoteResult = const Failure(
        NetworkException(message: 'Timeout', code: 'TIMEOUT'),
      );

      await controller.loadPosts(strategy: DataStrategy.staleWhileRevalidate);

      expect(controller.posts.first.title, equals('Stale Title'));
      expect(controller.hasError, isFalse);
    });
  });

  group('DataStrategy.remoteFirst', () {
    test('shows remote data directly', () async {
      mockRepo.postsRemoteResult = Success([fakePost]);

      await controller.loadPosts(strategy: DataStrategy.remoteFirst);

      expect(controller.posts.length, equals(1));
      expect(controller.hasError, isFalse);
    });

    test('falls back to cache when remote fails', () async {
      mockRepo.postsRemoteResult = const Failure(
        NetworkException(message: 'Timeout', code: 'TIMEOUT'),
      );
      mockRepo.postsCacheResult = Success([fakePost]);

      await controller.loadPosts(strategy: DataStrategy.remoteFirst);

      expect(controller.posts.first.title, equals('Hello World'));
      expect(controller.hasError, isFalse);
    });
  });

  group('EventBus', () {
    test('clears posts on CacheClearedEvent', () async {
      mockRepo.postsCacheResult = Success([fakePost]);
      await controller.loadPosts();
      expect(controller.posts.length, equals(1));

      // Simulate app-wide cache clear
      eventBus.fire(const CacheClearedEvent());

      // Allow the stream listener to process
      await Future<void>.delayed(Duration.zero);

      expect(controller.posts, isEmpty);
      expect(controller.selectedPost, isNull);
    });
  });
}
