import 'package:flutter_test/flutter_test.dart';
import 'package:karna_mvc/core/errors/app_exception.dart';
import 'package:karna_mvc/core/network/data_strategy.dart';
import 'package:karna_mvc/core/result/result.dart';
import 'package:karna_mvc/features/profile/controller/profile_controller.dart';
import 'package:karna_mvc/features/profile/model/profile_model.dart';
import 'package:karna_mvc/features/profile/repository/profile_repository.dart';

class MockProfileRepository implements ProfileRepository {
  Result<ProfileModel>? profileResult;
  Result<ProfileModel>? cacheResult;
  Result<ProfileModel>? remoteResult;
  Result<void>? updateResult;

  @override
  Future<Result<ProfileModel>> getProfileById(String id) async =>
      profileResult!;

  @override
  Future<Result<ProfileModel>> getProfileFromCache(String id) async =>
      cacheResult!;

  @override
  Future<Result<ProfileModel>> getProfileFromRemote(String id) async =>
      remoteResult!;

  @override
  Future<Result<void>> updateProfile(ProfileModel profile) async =>
      updateResult!;
}

void main() {
  late MockProfileRepository mockRepo;
  late ProfileController controller;

  setUp(() {
    mockRepo = MockProfileRepository();
    controller = ProfileController(repository: mockRepo);
  });

  group('DataStrategy.localFirst (default)', () {
    test('sets profile from cache on success', () async {
      final cached = ProfileModel(
        id: '1',
        displayName: 'Alice',
        avatarUrl: 'https://example.com/avatar.png',
        bio: 'Hello',
      );
      mockRepo.cacheResult = Success(cached);

      await controller.loadProfile('1');

      expect(controller.profile?.displayName, equals('Alice'));
      expect(controller.hasError, isFalse);
    });

    test('sets error when both fail', () async {
      mockRepo.cacheResult = const Failure(
        CacheException(message: 'miss', code: 'CACHE_MISS'),
      );
      mockRepo.remoteResult = const Failure(
        NetworkException(message: 'No connection', code: 'NO_CONNECTION'),
      );

      await controller.loadProfile('1');

      expect(controller.profile, isNull);
      expect(controller.hasError, isTrue);
    });
  });

  group('DataStrategy.staleWhileRevalidate', () {
    test('shows cache then replaces with fresh data', () async {
      final stale = ProfileModel(
        id: '1',
        displayName: 'Alice (stale)',
        avatarUrl: 'https://example.com/avatar.png',
        bio: 'Old',
      );
      final fresh = ProfileModel(
        id: '1',
        displayName: 'Alice (fresh)',
        avatarUrl: 'https://example.com/avatar.png',
        bio: 'New',
      );

      mockRepo.cacheResult = Success(stale);
      mockRepo.remoteResult = Success(fresh);

      await controller.loadProfile(
        '1',
        strategy: DataStrategy.staleWhileRevalidate,
      );

      expect(controller.profile?.displayName, equals('Alice (fresh)'));
      expect(controller.hasError, isFalse);
    });

    test('keeps stale data when refresh fails', () async {
      final stale = ProfileModel(
        id: '1',
        displayName: 'Alice (stale)',
        avatarUrl: 'https://example.com/avatar.png',
        bio: 'Old',
      );

      mockRepo.cacheResult = Success(stale);
      mockRepo.remoteResult = const Failure(
        NetworkException(message: 'Timeout', code: 'TIMEOUT'),
      );

      await controller.loadProfile(
        '1',
        strategy: DataStrategy.staleWhileRevalidate,
      );

      expect(controller.profile?.displayName, equals('Alice (stale)'));
      expect(controller.hasError, isFalse);
    });
  });

  test('updateProfile updates local state on success', () async {
    final updated = ProfileModel(
      id: '1',
      displayName: 'Alice Updated',
      avatarUrl: 'https://example.com/avatar.png',
      bio: 'Updated',
    );
    mockRepo.updateResult = const Success(null);

    await controller.updateProfile(updated);

    expect(controller.profile, equals(updated));
    expect(controller.hasError, isFalse);
  });
}
