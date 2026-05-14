import 'package:flutter_test/flutter_test.dart';
import 'package:karna_mvc/core/network/connectivity_checker.dart';
import 'package:karna_mvc/features/post/repository/post_repository_impl.dart';

class MockPostRemoteSource implements PostRemoteSource {
  Map<String, dynamic>? postJson;
  List<Map<String, dynamic>>? postsJson;
  Exception? exceptionToThrow;

  @override
  Future<Map<String, dynamic>> fetchPost(String id) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return postJson!;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAllPosts() async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return postsJson!;
  }
}

class MockPostLocalSource implements PostLocalSource {
  Map<String, dynamic>? cachedPost;
  List<Map<String, dynamic>> cachedPosts = [];

  @override
  Future<Map<String, dynamic>?> getCachedPost(String id) async => cachedPost;

  @override
  Future<List<Map<String, dynamic>>> getCachedPosts() async => cachedPosts;

  @override
  Future<void> cachePost(Map<String, dynamic> post) async {
    cachedPost = post;
  }

  @override
  Future<void> cachePosts(List<Map<String, dynamic>> posts) async {
    cachedPosts = posts;
  }

  @override
  Future<void> clearCache() async {
    cachedPost = null;
    cachedPosts = [];
  }
}

class MockConnectivity implements ConnectivityChecker {
  bool isConnected = true;

  @override
  Future<bool> get hasConnection async => isConnected;
}

void main() {
  late MockPostRemoteSource mockRemote;
  late MockPostLocalSource mockLocal;
  late MockConnectivity mockConnectivity;
  late PostRepositoryImpl repository;

  final postJson = {
    'id': '1',
    'title': 'Hello World',
    'body': 'Test body',
    'author_id': 'author_1',
  };

  setUp(() {
    mockRemote = MockPostRemoteSource();
    mockLocal = MockPostLocalSource();
    mockConnectivity = MockConnectivity();
    repository = PostRepositoryImpl(
      remoteSource: mockRemote,
      localSource: mockLocal,
      connectivity: mockConnectivity,
    );
  });

  group('getPostById (local-first)', () {
    test('returns cached data when available', () async {
      mockLocal.cachedPost = postJson;

      final result = await repository.getPostById('1');

      expect(result.isSuccess, isTrue);
      expect(result.data.title, equals('Hello World'));
    });

    test('fetches from remote when no cache', () async {
      mockRemote.postJson = postJson;

      final result = await repository.getPostById('1');

      expect(result.isSuccess, isTrue);
      expect(result.data.title, equals('Hello World'));
      expect(mockLocal.cachedPost, isNotNull);
    });

    test('returns failure when offline and no cache', () async {
      mockConnectivity.isConnected = false;

      final result = await repository.getPostById('1');

      expect(result.isFailure, isTrue);
      expect(result.exception.code, equals('NO_CONNECTION'));
    });
  });

  group('getPostFromCache', () {
    test('returns cached post', () async {
      mockLocal.cachedPost = postJson;

      final result = await repository.getPostFromCache('1');

      expect(result.isSuccess, isTrue);
      expect(result.data.title, equals('Hello World'));
    });

    test('returns failure on cache miss', () async {
      final result = await repository.getPostFromCache('1');

      expect(result.isFailure, isTrue);
      expect(result.exception.code, equals('CACHE_MISS'));
    });
  });

  group('getPostFromRemote', () {
    test('fetches and caches post', () async {
      mockRemote.postJson = postJson;

      final result = await repository.getPostFromRemote('1');

      expect(result.isSuccess, isTrue);
      expect(result.data.title, equals('Hello World'));
      expect(mockLocal.cachedPost, isNotNull);
    });

    test('returns failure when offline', () async {
      mockConnectivity.isConnected = false;

      final result = await repository.getPostFromRemote('1');

      expect(result.isFailure, isTrue);
      expect(result.exception.code, equals('NO_CONNECTION'));
    });
  });
}
