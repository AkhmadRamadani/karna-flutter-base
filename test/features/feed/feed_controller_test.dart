import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karna_mvc/core/errors/app_exception.dart';
import 'package:karna_mvc/core/events/event_bus.dart';
import 'package:karna_mvc/core/memory/memory_manager.dart';
import 'package:karna_mvc/core/network/data_strategy.dart';
import 'package:karna_mvc/core/result/result.dart';
import 'package:karna_mvc/features/feed/controller/feed_controller.dart';
import 'package:karna_mvc/features/feed/model/feed_model.dart';
import 'package:karna_mvc/features/feed/repository/feed_repository.dart';

class MockFeedRepository implements FeedRepository {
  Result<FeedModel>? modelResult;
  Result<List<FeedModel>>? listResult;
  Result<FeedModel>? cacheResult;
  Result<FeedModel>? remoteResult;

  @override
  Future<Result<FeedModel>> getById(String id) async => modelResult!;

  @override
  Future<Result<List<FeedModel>>> getAll() async => listResult!;

  @override
  Future<Result<FeedModel>> getFromCache(String id) async => cacheResult!;

  @override
  Future<Result<FeedModel>> getFromRemote(String id) async => remoteResult!;
}

FeedModel _fakeFeed({String id = '1'}) => FeedModel(
  id: id,
  authorName: 'Test Author',
  content: 'Test content',
  createdAt: DateTime(2025, 1, 1),
);

void main() {
  late MockFeedRepository mockRepo;
  late FeedController controller;
  late MemoryManager memoryManager;

  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
    mockRepo = MockFeedRepository();
    memoryManager = MemoryManager(eventBus: EventBusImpl());
    controller = FeedController(
      memoryManager: memoryManager,
      repository: mockRepo,
    );
  });

  tearDown(() {
    controller.dispose();
    memoryManager.dispose();
  });

  group('loadById (local-first)', () {
    test('sets data on success', () async {
      mockRepo.cacheResult = Success(_fakeFeed());

      await controller.loadById('1');

      expect(controller.feed?.id, equals('1'));
      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
    });

    test('sets error on failure', () async {
      mockRepo.cacheResult = const Failure(
        CacheException(message: 'miss', code: 'CACHE_MISS'),
      );
      mockRepo.remoteResult = const Failure(
        NetworkException(message: 'No connection', code: 'NO_CONNECTION'),
      );

      await controller.loadById('1');

      expect(controller.feed, isNull);
      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, equals('No connection'));
    });
  });

  group('DataStrategy.staleWhileRevalidate', () {
    test('shows cache then replaces with fresh data', () async {
      mockRepo.cacheResult = Success(_fakeFeed());
      mockRepo.remoteResult = Success(_fakeFeed());

      await controller.loadById(
        '1',
        strategy: DataStrategy.staleWhileRevalidate,
      );

      expect(controller.feed?.id, equals('1'));
      expect(controller.isLoading, isFalse);
      expect(controller.isRefreshing, isFalse);
      expect(controller.hasError, isFalse);
    });

    test('keeps stale data when refresh fails', () async {
      mockRepo.cacheResult = Success(_fakeFeed());
      mockRepo.remoteResult = const Failure(
        NetworkException(message: 'Timeout', code: 'TIMEOUT'),
      );

      await controller.loadById(
        '1',
        strategy: DataStrategy.staleWhileRevalidate,
      );

      expect(controller.feed?.id, equals('1'));
      expect(controller.hasError, isFalse);
    });

    test('sets error when both cache and remote fail', () async {
      mockRepo.cacheResult = const Failure(
        CacheException(message: 'No cached data', code: 'CACHE_MISS'),
      );
      mockRepo.remoteResult = const Failure(
        NetworkException(message: 'No connection', code: 'NO_CONNECTION'),
      );

      await controller.loadById(
        '1',
        strategy: DataStrategy.staleWhileRevalidate,
      );

      expect(controller.feed, isNull);
      expect(controller.hasError, isTrue);
    });
  });

  group('memory management', () {
    test('onMemoryWarning trims list to 20 items', () async {
      mockRepo.listResult = Success(
        List.generate(50, (i) => _fakeFeed(id: '$i')),
      );

      await controller.loadAll();
      expect(controller.feedList.length, equals(50));

      await controller.onMemoryWarning();
      expect(controller.feedList.length, equals(20));
    });

    test('onKill clears all data', () async {
      mockRepo.listResult = Success([_fakeFeed()]);

      await controller.loadAll();
      expect(controller.feedList.isNotEmpty, isTrue);

      await controller.onKill();
      expect(controller.feedList.isEmpty, isTrue);
      expect(controller.feed, isNull);
    });

    test('serviceId is feed_controller', () {
      expect(controller.serviceId, equals('feed_controller'));
    });
  });

  test('loadAll sets list on success', () async {
    mockRepo.listResult = Success([_fakeFeed(id: '1'), _fakeFeed(id: '2')]);

    await controller.loadAll();

    expect(controller.feedList.length, equals(2));
    expect(controller.isLoading, isFalse);
    expect(controller.hasError, isFalse);
  });
}
