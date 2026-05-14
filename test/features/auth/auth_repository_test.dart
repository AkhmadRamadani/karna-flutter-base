import 'package:flutter_test/flutter_test.dart';
import 'package:karna_mvc/core/network/connectivity_checker.dart';
import 'package:karna_mvc/features/auth/repository/auth_repository_impl.dart';

class MockAuthRemoteSource implements AuthRemoteSource {
  Map<String, dynamic>? userJson;
  List<Map<String, dynamic>>? usersJson;
  Exception? exceptionToThrow;

  @override
  Future<Map<String, dynamic>> fetchUser(String id) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return userJson!;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return usersJson!;
  }
}

class MockAuthLocalSource implements AuthLocalSource {
  Map<String, dynamic>? cachedUser;
  List<Map<String, dynamic>> cachedUsers = [];

  @override
  Future<Map<String, dynamic>?> getCachedUser(String id) async => cachedUser;

  @override
  Future<List<Map<String, dynamic>>> getCachedUsers() async => cachedUsers;

  @override
  Future<void> cacheUser(Map<String, dynamic> user) async {
    cachedUser = user;
  }

  @override
  Future<void> cacheUsers(List<Map<String, dynamic>> users) async {
    cachedUsers = users;
  }

  @override
  Future<void> clearCache() async {
    cachedUser = null;
    cachedUsers = [];
  }
}

class MockConnectivity implements ConnectivityChecker {
  bool isConnected = true;

  @override
  Future<bool> get hasConnection async => isConnected;
}

void main() {
  late MockAuthRemoteSource mockRemote;
  late MockAuthLocalSource mockLocal;
  late MockConnectivity mockConnectivity;
  late AuthRepositoryImpl repository;

  setUp(() {
    mockRemote = MockAuthRemoteSource();
    mockLocal = MockAuthLocalSource();
    mockConnectivity = MockConnectivity();
    repository = AuthRepositoryImpl(
      remoteSource: mockRemote,
      localSource: mockLocal,
      connectivity: mockConnectivity,
    );
  });

  group('getUserById (local-first)', () {
    test('returns cached data when available', () async {
      mockLocal.cachedUser = {
        'id': '1',
        'name': 'Alice (cached)',
        'email': 'alice@test.com',
      };

      final result = await repository.getUserById('1');

      expect(result.isSuccess, isTrue);
      expect(result.data.name, equals('Alice (cached)'));
    });

    test('fetches from remote when no cache', () async {
      mockRemote.userJson = {
        'id': '1',
        'name': 'Alice',
        'email': 'alice@test.com',
      };

      final result = await repository.getUserById('1');

      expect(result.isSuccess, isTrue);
      expect(result.data.name, equals('Alice'));
      expect(mockLocal.cachedUser, isNotNull);
    });

    test('returns failure when offline and no cache', () async {
      mockConnectivity.isConnected = false;

      final result = await repository.getUserById('1');

      expect(result.isFailure, isTrue);
      expect(result.exception.code, equals('NO_CONNECTION'));
    });
  });

  group('getUserFromCache', () {
    test('returns cached user', () async {
      mockLocal.cachedUser = {
        'id': '1',
        'name': 'Alice',
        'email': 'alice@test.com',
      };

      final result = await repository.getUserFromCache('1');

      expect(result.isSuccess, isTrue);
      expect(result.data.name, equals('Alice'));
    });

    test('returns failure on cache miss', () async {
      final result = await repository.getUserFromCache('1');

      expect(result.isFailure, isTrue);
      expect(result.exception.code, equals('CACHE_MISS'));
    });
  });

  group('getUserFromRemote', () {
    test('fetches and caches user', () async {
      mockRemote.userJson = {
        'id': '1',
        'name': 'Alice (fresh)',
        'email': 'alice@test.com',
      };

      final result = await repository.getUserFromRemote('1');

      expect(result.isSuccess, isTrue);
      expect(result.data.name, equals('Alice (fresh)'));
      expect(mockLocal.cachedUser, isNotNull);
    });

    test('returns failure when offline', () async {
      mockConnectivity.isConnected = false;

      final result = await repository.getUserFromRemote('1');

      expect(result.isFailure, isTrue);
      expect(result.exception.code, equals('NO_CONNECTION'));
    });
  });
}
