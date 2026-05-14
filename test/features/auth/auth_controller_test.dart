import 'package:flutter_test/flutter_test.dart';
import 'package:karna_mvc/core/errors/app_exception.dart';
import 'package:karna_mvc/core/events/event_bus.dart';
import 'package:karna_mvc/core/network/data_strategy.dart';
import 'package:karna_mvc/core/result/result.dart';
import 'package:karna_mvc/features/auth/controller/auth_controller.dart';
import 'package:karna_mvc/features/auth/model/user_model.dart';
import 'package:karna_mvc/features/auth/repository/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  Result<UserModel>? userResult;
  Result<List<UserModel>>? usersResult;
  Result<UserModel>? cacheResult;
  Result<UserModel>? remoteResult;

  @override
  Future<Result<UserModel>> getUserById(String id) async => userResult!;

  @override
  Future<Result<List<UserModel>>> getAllUsers() async => usersResult!;

  @override
  Future<Result<UserModel>> getUserFromCache(String id) async => cacheResult!;

  @override
  Future<Result<UserModel>> getUserFromRemote(String id) async => remoteResult!;
}

void main() {
  late MockAuthRepository mockRepo;
  late AuthController controller;
  late EventBusImpl eventBus;

  setUp(() {
    mockRepo = MockAuthRepository();
    eventBus = EventBusImpl();
    controller = AuthController(repository: mockRepo, eventBus: eventBus);
  });

  tearDown(() {
    controller.dispose();
    eventBus.dispose();
  });

  group('DataStrategy.localFirst', () {
    test('shows cached data when available', () async {
      final cached = UserModel(
        id: '1',
        name: 'Alice (cached)',
        email: 'a@test.com',
      );
      mockRepo.cacheResult = Success(cached);

      await controller.loadUser('1');

      expect(controller.user?.name, equals('Alice (cached)'));
      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
    });

    test('falls back to remote on cache miss', () async {
      final fresh = UserModel(
        id: '1',
        name: 'Alice (fresh)',
        email: 'a@test.com',
      );
      mockRepo.cacheResult = const Failure(
        CacheException(message: 'miss', code: 'CACHE_MISS'),
      );
      mockRepo.remoteResult = Success(fresh);

      await controller.loadUser('1');

      expect(controller.user?.name, equals('Alice (fresh)'));
      expect(controller.hasError, isFalse);
    });

    test('sets error when both fail', () async {
      mockRepo.cacheResult = const Failure(
        CacheException(message: 'miss', code: 'CACHE_MISS'),
      );
      mockRepo.remoteResult = const Failure(
        NetworkException(message: 'No connection', code: 'NO_CONNECTION'),
      );

      await controller.loadUser('1');

      expect(controller.user, isNull);
      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, equals('No connection'));
    });
  });

  group('DataStrategy.staleWhileRevalidate', () {
    test('shows cache then replaces with fresh data', () async {
      final cached = UserModel(
        id: '1',
        name: 'Alice (stale)',
        email: 'a@test.com',
      );
      final fresh = UserModel(
        id: '1',
        name: 'Alice (fresh)',
        email: 'a@new.com',
      );

      mockRepo.cacheResult = Success(cached);
      mockRepo.remoteResult = Success(fresh);

      await controller.loadUser(
        '1',
        strategy: DataStrategy.staleWhileRevalidate,
      );

      expect(controller.user?.name, equals('Alice (fresh)'));
      expect(controller.isLoading, isFalse);
      expect(controller.isRefreshing, isFalse);
    });

    test('keeps stale data when refresh fails', () async {
      final cached = UserModel(
        id: '1',
        name: 'Alice (stale)',
        email: 'a@test.com',
      );

      mockRepo.cacheResult = Success(cached);
      mockRepo.remoteResult = const Failure(
        NetworkException(message: 'Timeout', code: 'TIMEOUT'),
      );

      await controller.loadUser(
        '1',
        strategy: DataStrategy.staleWhileRevalidate,
      );

      expect(controller.user?.name, equals('Alice (stale)'));
      expect(controller.hasError, isFalse);
    });

    test('sets error when both cache and remote fail', () async {
      mockRepo.cacheResult = const Failure(
        CacheException(message: 'miss', code: 'CACHE_MISS'),
      );
      mockRepo.remoteResult = const Failure(
        NetworkException(message: 'No connection', code: 'NO_CONNECTION'),
      );

      await controller.loadUser(
        '1',
        strategy: DataStrategy.staleWhileRevalidate,
      );

      expect(controller.user, isNull);
      expect(controller.hasError, isTrue);
    });
  });

  group('DataStrategy.remoteFirst', () {
    test('shows remote data directly', () async {
      final fresh = UserModel(
        id: '1',
        name: 'Alice (fresh)',
        email: 'a@test.com',
      );
      mockRepo.remoteResult = Success(fresh);

      await controller.loadUser('1', strategy: DataStrategy.remoteFirst);

      expect(controller.user?.name, equals('Alice (fresh)'));
      expect(controller.hasError, isFalse);
    });

    test('falls back to cache when remote fails', () async {
      final cached = UserModel(
        id: '1',
        name: 'Alice (cached)',
        email: 'a@test.com',
      );
      mockRepo.remoteResult = const Failure(
        NetworkException(message: 'Timeout', code: 'TIMEOUT'),
      );
      mockRepo.cacheResult = Success(cached);

      await controller.loadUser('1', strategy: DataStrategy.remoteFirst);

      expect(controller.user?.name, equals('Alice (cached)'));
      expect(controller.hasError, isFalse);
    });

    test('sets error when both remote and cache fail', () async {
      mockRepo.remoteResult = const Failure(
        NetworkException(message: 'Timeout', code: 'TIMEOUT'),
      );
      mockRepo.cacheResult = const Failure(
        CacheException(message: 'miss', code: 'CACHE_MISS'),
      );

      await controller.loadUser('1', strategy: DataStrategy.remoteFirst);

      expect(controller.user, isNull);
      expect(controller.hasError, isTrue);
    });
  });

  test('loadAllUsers sets users on success', () async {
    mockRepo.usersResult = Success([
      UserModel(id: '1', name: 'Alice', email: 'alice@test.com'),
      UserModel(id: '2', name: 'Bob', email: 'bob@test.com'),
    ]);

    await controller.loadAllUsers();

    expect(controller.users.length, equals(2));
    expect(controller.hasError, isFalse);
  });
}
