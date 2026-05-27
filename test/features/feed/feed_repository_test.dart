import 'package:flutter_test/flutter_test.dart';
import 'package:karna_mvc/core/network/connectivity_checker.dart';
import 'package:karna_mvc/features/feed/repository/feed_repository_impl.dart';

class MockFeedRemoteSource implements FeedRemoteSource {
  Map<String, dynamic>? jsonToReturn;
  List<Map<String, dynamic>>? listToReturn;
  Exception? exceptionToThrow;

  @override
  Future<Map<String, dynamic>> fetchById(String id) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return jsonToReturn!;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return listToReturn!;
  }
}

class MockFeedLocalSource implements FeedLocalSource {
  Map<String, dynamic>? cachedItem;
  List<Map<String, dynamic>> cachedList = [];

  @override
  Future<Map<String, dynamic>?> getCached(String id) async => cachedItem;

  @override
  Future<List<Map<String, dynamic>>> getCachedList() async => cachedList;

  @override
  Future<void> cache(Map<String, dynamic> data) async {
    cachedItem = data;
  }

  @override
  Future<void> cacheList(List<Map<String, dynamic>> data) async {
    cachedList = data;
  }

  @override
  Future<void> clearCache() async {
    cachedItem = null;
    cachedList = [];
  }
}

class MockConnectivity implements ConnectivityChecker {
  bool isConnected = true;

  @override
  Future<bool> get hasConnection async => isConnected;
}

void main() {
  late MockFeedRemoteSource mockRemote;
  late MockFeedLocalSource mockLocal;
  late MockConnectivity mockConnectivity;
  late FeedRepositoryImpl repository;

  setUp(() {
    mockRemote = MockFeedRemoteSource();
    mockLocal = MockFeedLocalSource();
    mockConnectivity = MockConnectivity();
    repository = FeedRepositoryImpl(
      remoteSource: mockRemote,
      localSource: mockLocal,
      connectivity: mockConnectivity,
    );
  });

  group('getById (local-first)', () {
    test('returns cached data when available', () async {
      mockLocal.cachedItem = {
        'id': '1',
        'author_name': 'Test',
        'content': 'Hello',
        'created_at': '2025-01-01T00:00:00.000',
      };

      final result = await repository.getById('1');

      expect(result.isSuccess, isTrue);
      expect(result.data.id, equals('1'));
    });

    test('fetches from remote when no cache', () async {
      mockRemote.jsonToReturn = {
        'id': '1',
        'author_name': 'Test',
        'content': 'Hello',
        'created_at': '2025-01-01T00:00:00.000',
      };

      final result = await repository.getById('1');

      expect(result.isSuccess, isTrue);
      expect(mockLocal.cachedItem, isNotNull);
    });

    test('returns failure when offline and no cache', () async {
      mockConnectivity.isConnected = false;

      final result = await repository.getById('1');

      expect(result.isFailure, isTrue);
      expect(result.exception.code, equals('NO_CONNECTION'));
    });
  });

  group('getFromCache', () {
    test('returns cached data', () async {
      mockLocal.cachedItem = {
        'id': '1',
        'author_name': 'Test',
        'content': 'Hello',
        'created_at': '2025-01-01T00:00:00.000',
      };

      final result = await repository.getFromCache('1');

      expect(result.isSuccess, isTrue);
    });

    test('returns failure on cache miss', () async {
      final result = await repository.getFromCache('1');

      expect(result.isFailure, isTrue);
      expect(result.exception.code, equals('CACHE_MISS'));
    });
  });

  group('getFromRemote', () {
    test('fetches and caches data', () async {
      mockRemote.jsonToReturn = {
        'id': '1',
        'author_name': 'Test',
        'content': 'Hello',
        'created_at': '2025-01-01T00:00:00.000',
      };

      final result = await repository.getFromRemote('1');

      expect(result.isSuccess, isTrue);
      expect(mockLocal.cachedItem, isNotNull);
    });

    test('returns failure when offline', () async {
      mockConnectivity.isConnected = false;

      final result = await repository.getFromRemote('1');

      expect(result.isFailure, isTrue);
      expect(result.exception.code, equals('NO_CONNECTION'));
    });
  });
}
