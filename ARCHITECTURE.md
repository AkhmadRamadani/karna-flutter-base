# Karna MVC — Flutter Architecture

> Named after Karna of the Mahabharata: a warrior complete in himself,
> needing nothing from outside — yet fighting for a greater whole.
> In Indonesian: *karena* (because of) — every layer exists because of its feature.
>
> This document describes the conventions, folder structure, and patterns used in this Flutter project.
> It is intended to be read by AI coding assistants to understand how to contribute correctly.

---

## Overview

This project follows **Karna MVC** — a feature-first Model-View-Controller pattern for Flutter where each feature is self-contained (model, repository, data sources, controller, view) and depends on nothing outside itself except `core/`.

Like Karna, each feature stands alone — fully capable, fully equipped. The controller exists *because of* the feature. The model exists *because of* the feature. The view exists *because of* the feature. Nothing bleeds across boundaries.

Key principles:
- **Typed error handling** — repositories return `Result<T>` (sealed Success/Failure), never throw
- **Data strategy** — each load call declares its strategy: `localFirst`, `staleWhileRevalidate`, or `remoteFirst`
- **Storage-agnostic** — a single `LocalStorage` interface backs all caching (Hive, SharedPrefs, InMemory)
- **Connectivity-aware** — repositories check network before remote calls, return typed failures
- **Zero boilerplate** — `BaseController` handles loading/error/refresh state for all controllers

---

## Folder Structure

```
lib/
├── main.dart
├── core/
│   ├── config/
│   │   └── app_config.dart               # Environment config (--dart-define)
│   ├── controller/
│   │   └── base_controller.dart          # Shared loading/error/strategy logic
│   ├── di/
│   │   └── providers.dart                # Wires all feature providers (DI)
│   ├── errors/
│   │   └── app_exception.dart            # Typed exception hierarchy
│   ├── extensions/
│   │   └── context_extensions.dart       # Dart extension methods
│   ├── network/
│   │   ├── api_client.dart               # HTTP client with retry & auth
│   │   ├── connectivity_checker.dart     # Network availability check
│   │   └── data_strategy.dart            # DataStrategy enum
│   ├── result/
│   │   └── result.dart                   # Sealed Result<T> (Success/Failure)
│   ├── routes/
│   │   └── app_routes.dart               # Centralized routing
│   ├── storage/
│   │   ├── local_storage.dart            # Abstract storage interface
│   │   ├── in_memory_storage.dart        # Dev/tests (no persistence)
│   │   ├── shared_prefs_storage.dart     # Small key-value data
│   │   └── hive_storage.dart             # Larger datasets, fast reads
│   ├── theme/
│   │   └── app_theme.dart                # Light & dark theme
│   ├── utils/
│   │   └── logger.dart                   # Debug logger utility
│   └── widgets/
│       ├── error_display.dart            # Shared error widget
│       └── loading_indicator.dart        # Shared loading widget
│
├── features/
│   └── <feature>/
│       ├── model/
│       │   └── <feature>_model.dart
│       ├── repository/
│       │   ├── <feature>_repository.dart          # Abstract (returns Result<T>)
│       │   ├── <feature>_repository_impl.dart     # Orchestrates local + remote
│       │   └── data_source/
│       │       ├── <feature>_remote_source.dart   # HTTP via ApiClient
│       │       └── <feature>_local_source.dart    # Cache via LocalStorage
│       ├── controller/
│       │   └── <feature>_controller.dart          # Extends BaseController
│       └── view/
│           ├── <feature>_view.dart
│           └── widgets/                           # Feature-local widgets
│
test/
└── features/
    └── <feature>/
        ├── <feature>_controller_test.dart
        ├── <feature>_repository_test.dart
        └── <feature>_view_test.dart
```

---

## Core Layer

### Result Type (`core/result/result.dart`)

A sealed type that forces explicit error handling. Repositories never throw — they return `Result<T>`.

```dart
sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T data) success,
    required R Function(AppException error) failure,
  });

  Result<R> map<R>(R Function(T data) transform);
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

class Failure<T> extends Result<T> {
  final AppException error;
  const Failure(this.error);
}
```

---

### Exception Hierarchy (`core/errors/app_exception.dart`)

Typed exceptions allow the UI to react differently to different failures:

```dart
class AppException implements Exception {
  final String message;
  final String? code;
  const AppException({required this.message, this.code});
}

class NetworkException extends AppException { ... }   // No internet
class ServerException extends AppException { ... }    // 4xx/5xx with statusCode
class CacheException extends AppException { ... }     // Local storage failures
```

---

### Data Strategy (`core/network/data_strategy.dart`)

Declares how a controller resolves data between local and remote:

```dart
enum DataStrategy {
  /// Cache first, network only on miss. Best for: rarely-changing data.
  localFirst,

  /// Show cache immediately, refresh from network in background.
  /// Best for: feeds, dashboards, frequently-changing data.
  staleWhileRevalidate,

  /// Always hit network, fall back to cache on failure.
  /// Best for: real-time data, transactions.
  remoteFirst,
}
```

---

### BaseController (`core/controller/base_controller.dart`)

All controllers extend this. Provides:
- `isLoading` — true during initial load
- `isRefreshing` — true during background refresh (stale-while-revalidate)
- `hasError` / `error` / `errorMessage` — typed error state
- `load()` — unified method that accepts a `DataStrategy`
- `executeResult()` — shorthand for single Result actions

```dart
abstract class BaseController extends ChangeNotifier {
  Future<void> load<T>({
    required DataStrategy strategy,
    required Future<Result<T>> Function() cacheAction,
    required Future<Result<T>> Function() freshAction,
    required void Function(T data) onSuccess,
  });

  Future<void> executeResult<T>(
    Future<Result<T>> Function() action, {
    required void Function(T data) onSuccess,
  });
}
```

**Strategy behavior:**

| Scenario | `localFirst` | `staleWhileRevalidate` | `remoteFirst` |
|----------|-------------|----------------------|--------------|
| Cache hit, network ok | Shows cache, done | Shows cache → replaces with fresh | Shows fresh |
| Cache hit, network fails | Shows cache, done | Shows cache, silent fail | Falls back to cache |
| Cache miss, network ok | Shows fresh | Shows fresh | Shows fresh |
| Cache miss, network fails | Error | Error | Error |

---

### ApiClient (`core/network/api_client.dart`)

A thin HTTP wrapper that handles:
- Base URL resolution from `AppConfig`
- Auth token injection (`setAuthToken()`)
- Retry logic for transient failures (2 retries with backoff)
- Response → JSON parsing
- HTTP status → typed `AppException` mapping

```dart
class ApiClient {
  ApiClient({required AppConfig config, http.Client? client});

  void setAuthToken(String? token);

  Future<dynamic> get(String path, {Map<String, String>? queryParams});
  Future<dynamic> post(String path, {Object? body});
  Future<dynamic> put(String path, {Object? body});
  Future<dynamic> delete(String path);

  void dispose();
}
```

---

### LocalStorage (`core/storage/local_storage.dart`)

Storage-agnostic interface. Swap the implementation in DI — all features follow automatically.

```dart
abstract class LocalStorage {
  Future<Map<String, dynamic>?> getJson(String key);
  Future<List<Map<String, dynamic>>> getJsonList(String key);
  Future<void> putJson(String key, Map<String, dynamic> value);
  Future<void> putJsonList(String key, List<Map<String, dynamic>> value);
  Future<void> remove(String key);
  Future<void> removeByPrefix(String prefix);
  Future<void> clear();
  Future<bool> has(String key);
}
```

**Implementations:**
| Class | Backend | Best for |
|-------|---------|----------|
| `InMemoryStorage` | RAM | Dev, tests, prototyping |
| `SharedPrefsStorage` | SharedPreferences | Small key-value, settings |
| `HiveStorage` | Hive | Larger datasets, offline-first |

---

### ConnectivityChecker (`core/network/connectivity_checker.dart`)

```dart
abstract class ConnectivityChecker {
  Future<bool> get hasConnection;
}
```

Repositories check this before attempting remote calls. Returns typed `NetworkException` when offline.

---

### AppConfig (`core/config/app_config.dart`)

Environment configuration from `--dart-define` flags:

```dart
class AppConfig {
  final String baseUrl;
  final String environment;
  final Duration timeout;
  final bool enableLogging;

  factory AppConfig.fromEnvironment();

  bool get isDevelopment;
  bool get isStaging;
  bool get isProduction;
}
```

Run with: `flutter run --dart-define=BASE_URL=https://api.prod.com --dart-define=ENV=production`

---

## Feature Structure

Every feature follows the same internal layout.

### model/

- Pure Dart classes, **no Flutter dependencies**.
- Responsible for data shape, serialization (`fromJson` / `toJson`), and `copyWith`.
- Fields are **immutable** (`final`).

```dart
class UserModel {
  final String id;
  final String name;
  final String email;

  const UserModel({required this.id, required this.name, required this.email});

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};

  UserModel copyWith({String? id, String? name, String? email}) => UserModel(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
      );
}
```

---

### repository/

**Abstract interface** — returns `Result<T>`, exposes cache/remote separately for strategy support:

```dart
abstract class AuthRepository {
  Future<Result<UserModel>> getUserById(String id);
  Future<Result<List<UserModel>>> getAllUsers();
  Future<Result<UserModel>> getUserFromCache(String id);
  Future<Result<UserModel>> getUserFromRemote(String id);
}
```

**Concrete implementation** — orchestrates local + remote with connectivity checks:

```dart
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteSource _remoteSource;
  final AuthLocalSource _localSource;
  final ConnectivityChecker _connectivity;

  @override
  Future<Result<UserModel>> getUserById(String id) async {
    try {
      final cached = await _localSource.getCachedUser(id);
      if (cached != null) return Success(UserModel.fromJson(cached));

      if (!await _connectivity.hasConnection) {
        return const Failure(NetworkException(message: 'No internet connection', code: 'NO_CONNECTION'));
      }

      final json = await _remoteSource.fetchUser(id);
      await _localSource.cacheUser(json);
      return Success(UserModel.fromJson(json));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }
}
```

---

### repository/data_source/

**Remote source** — uses `ApiClient`:

```dart
class AuthRemoteSourceImpl implements AuthRemoteSource {
  final ApiClient _client;

  AuthRemoteSourceImpl({required ApiClient client}) : _client = client;

  @override
  Future<Map<String, dynamic>> fetchUser(String id) async {
    final json = await _client.get('/users/$id');
    return json as Map<String, dynamic>;
  }
}
```

**Local source** — uses `LocalStorage`:

```dart
class AuthLocalSourceImpl implements AuthLocalSource {
  final LocalStorage _storage;

  static const _keyPrefix = 'auth_';
  static const _userKey = '${_keyPrefix}user_';

  AuthLocalSourceImpl({required LocalStorage storage}) : _storage = storage;

  @override
  Future<Map<String, dynamic>?> getCachedUser(String id) async {
    return _storage.getJson('$_userKey$id');
  }

  @override
  Future<void> cacheUser(Map<String, dynamic> user) async {
    final id = user['id'] as String;
    await _storage.putJson('$_userKey$id', user);
  }

  @override
  Future<void> clearCache() async {
    await _storage.removeByPrefix(_keyPrefix);
  }
}
```

---

### controller/

Extends `BaseController`. Uses `DataStrategy` to declare how data is loaded:

```dart
class AuthController extends BaseController {
  final AuthRepository _repository;

  AuthController({required AuthRepository repository}) : _repository = repository;

  UserModel? _user;
  UserModel? get user => _user;

  Future<void> loadUser(String id, {DataStrategy strategy = DataStrategy.localFirst}) async {
    await load(
      strategy: strategy,
      cacheAction: () => _repository.getUserFromCache(id),
      freshAction: () => _repository.getUserFromRemote(id),
      onSuccess: (data) => _user = data,
    );
  }
}
```

**Usage in views:**

```dart
// Default — local-first
controller.loadUser('1');

// Show stale data immediately, refresh in background
controller.loadUser('1', strategy: DataStrategy.staleWhileRevalidate);

// Always hit network (e.g. after login)
controller.loadUser('1', strategy: DataStrategy.remoteFirst);
```

---

### view/

- Flutter `Widget` (stateless or stateful).
- Obtains the controller via `context.watch<Controller>()`.
- **Reads state** from the controller; **calls methods** on the controller.
- Contains **zero business logic** — only UI logic.
- Can show a subtle refresh indicator via `controller.isRefreshing`.

```dart
class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.hasError) {
      return Center(child: Text('Error: ${controller.errorMessage}'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.user?.name ?? ''),
        actions: [
          if (controller.isRefreshing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: ...,
    );
  }
}
```

---

## Dependency Injection

`core/di/providers.dart` is the **only file** that imports across features. It receives `LocalStorage` as a parameter (initialized in `main()`):

```dart
List<SingleChildWidget> appProviders({required LocalStorage storage}) => [
  // Core singletons
  Provider<AppConfig>(create: (_) => AppConfig.fromEnvironment()),
  Provider<ConnectivityChecker>(create: (_) => ConnectivityCheckerImpl()),
  Provider<LocalStorage>(create: (_) => storage),
  ProxyProvider<AppConfig, ApiClient>(
    update: (_, config, previous) {
      previous?.dispose();
      return ApiClient(config: config);
    },
    dispose: (_, client) => client.dispose(),
  ),

  // Feature controllers
  ChangeNotifierProvider<AuthController>(
    create: (context) => AuthController(
      repository: AuthRepositoryImpl(
        remoteSource: AuthRemoteSourceImpl(client: context.read<ApiClient>()),
        localSource: AuthLocalSourceImpl(storage: context.read<LocalStorage>()),
        connectivity: context.read<ConnectivityChecker>(),
      ),
    ),
  ),
];
```

**`main.dart`:**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox<String>('app_storage');
  final storage = HiveStorage(box: box);
  runApp(KarnaApp(storage: storage));
}
```

---

## The Karna Principle — Cross-feature Rules

| Rule | Rationale |
|------|-----------|
| A feature folder never imports another feature folder | Features are independent |
| Cross-feature data is passed via constructor injection at the DI layer | `core/di/` is the only place that knows about multiple features |
| A model used by 2+ features moves to `core/` | Don't duplicate; don't couple |
| A widget used by 2+ features moves to `core/widgets/` | Same principle |

---

## Testing Strategy

Tests mirror the `features/` folder structure exactly.

### Controller Tests

Mock the repository, test all three strategies:

```dart
class MockAuthRepository implements AuthRepository {
  Result<UserModel>? cacheResult;
  Result<UserModel>? remoteResult;
  // ...
}

test('DataStrategy.localFirst shows cached data', () async {
  mockRepo.cacheResult = Success(fakeUser);
  await controller.loadUser('1');
  expect(controller.user, equals(fakeUser));
});

test('DataStrategy.staleWhileRevalidate keeps stale on refresh fail', () async {
  mockRepo.cacheResult = Success(staleUser);
  mockRepo.remoteResult = const Failure(NetworkException(...));
  await controller.loadUser('1', strategy: DataStrategy.staleWhileRevalidate);
  expect(controller.user, equals(staleUser));
  expect(controller.hasError, isFalse);
});
```

### Repository Tests

Mock remote source, local source, and connectivity:

```dart
test('returns failure when offline and no cache', () async {
  mockConnectivity.isConnected = false;
  final result = await repository.getUserById('1');
  expect(result.isFailure, isTrue);
  expect(result.exception.code, equals('NO_CONNECTION'));
});
```

### Widget Tests

Use a fake repository with `InMemoryStorage` — no Hive/SharedPrefs needed:

```dart
testWidgets('LoginView displays "No user found." initially', (tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthController>(
      create: (_) => AuthController(repository: FakeAuthRepository()),
      child: const MaterialApp(home: LoginView()),
    ),
  );
  expect(find.text('No user found.'), findsOneWidget);
});
```

---

## Conventions & Rules

| Rule | Rationale |
|------|-----------|
| One feature folder per product feature | Co-located and deletable as a unit |
| Controllers extend `BaseController` | Shared loading/error/strategy patterns |
| Controllers never import `package:flutter/widgets.dart` | Pure Dart, testable without widget tree |
| Repositories return `Result<T>` | Typed errors, no uncaught exceptions |
| Repositories expose `getFromCache` + `getFromRemote` | Enables all three data strategies |
| Views never contain `if/else` business logic | Logic belongs in controllers |
| Data sources use `ApiClient` (remote) and `LocalStorage` (local) | Agnostic, swappable |
| Models are immutable (`final` fields + `copyWith`) | Predictable state |
| All dependencies are injected via constructor | No hidden singletons; fully mockable |
| Features never import other features | Cross-feature coupling resolved in `core/di/` |
| Shared code only moves to `core/` when used by 2+ features | No premature abstraction |

---

## Adding a New Feature — Checklist

Run the generator:

```bash
./scripts/create_feature.sh <feature_name>
```

Or manually:

1. Create `lib/features/<feature>/model/<name>_model.dart`
2. Create `lib/features/<feature>/repository/<name>_repository.dart` (abstract, returns `Result<T>`)
3. Create `lib/features/<feature>/repository/<name>_repository_impl.dart` (local-first + connectivity)
4. Create `lib/features/<feature>/repository/data_source/<name>_remote_source.dart` (uses `ApiClient`)
5. Create `lib/features/<feature>/repository/data_source/<name>_local_source.dart` (uses `LocalStorage`)
6. Create `lib/features/<feature>/controller/<name>_controller.dart` (extends `BaseController`)
7. Create `lib/features/<feature>/view/<name>_view.dart`
8. Register the controller in `core/di/providers.dart`
9. Create `test/features/<feature>/` with controller, repository, and widget tests

**Never:**
- Put `await http.get(...)` inside a controller or widget directly — use `ApiClient` in a remote source
- Put `if (userRole == 'admin')` inside a view — that belongs in the controller
- Import from another feature folder
- Use a real network or file system in tests
- Throw exceptions from repositories — return `Failure(...)` instead

---

## Key Packages

| Package | Role |
|---------|------|
| `provider` | DI + state propagation to the widget tree |
| `http` | HTTP client (used by `ApiClient`) |
| `hive` / `hive_flutter` | Fast local storage backend |
| `shared_preferences` | Simple key-value storage backend |
| `flutter_test` | Widget and unit testing |
