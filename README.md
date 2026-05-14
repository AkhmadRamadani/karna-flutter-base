# Karna MVC

A feature-first Model-View-Controller starter template for Flutter with typed error handling, pluggable data strategies, storage-agnostic caching, and event-driven cross-feature communication. Each feature is self-contained and depends on nothing outside itself except `core/`.

> Named after Karna of the Mahabharata: a warrior complete in himself.
> In Indonesian: *karena* (because of) — every layer exists because of its feature.

This is a **starter project** — not a package. Clone it, delete the example `post` feature, and start building your own features using the same patterns.

## Quick Start

```bash
# Clone and rename
git clone <this-repo> my_app
cd my_app

# Install dependencies
flutter pub get

# Run the example
flutter run

# Create your first feature
./scripts/create_feature.sh my_feature

# Then delete the example feature when you're ready
rm -rf lib/features/post test/features/post
```

## Project Structure

```
lib/
├── main.dart
├── core/
│   ├── config/app_config.dart            # Environment config (--dart-define)
│   ├── controller/base_controller.dart   # Shared loading/error/strategy logic
│   ├── di/providers.dart                 # Wires all feature providers (DI)
│   ├── errors/app_exception.dart         # Typed exception hierarchy
│   ├── events/
│   │   ├── event_bus.dart                # Abstract EventBus + stream impl
│   │   └── app_events.dart              # Typed app-wide event classes
│   ├── extensions/                       # Dart extension methods
│   ├── network/
│   │   ├── api_client.dart               # HTTP client with retry & auth
│   │   ├── connectivity_checker.dart     # Network availability check
│   │   └── data_strategy.dart            # DataStrategy enum
│   ├── result/result.dart                # Sealed Result<T> (Success/Failure)
│   ├── routes/app_routes.dart            # Centralized routing
│   ├── storage/
│   │   ├── local_storage.dart            # Abstract storage interface
│   │   ├── in_memory_storage.dart        # Dev/tests
│   │   ├── shared_prefs_storage.dart     # Small key-value
│   │   └── hive_storage.dart             # Larger datasets
│   ├── theme/app_theme.dart              # Light & dark theme
│   ├── utils/                            # Pure utility functions
│   └── widgets/                          # Shared widgets (2+ features)
│
├── features/
│   └── <feature>/
│       ├── model/<feature>_model.dart
│       ├── repository/
│       │   ├── <feature>_repository.dart          # Abstract (returns Result<T>)
│       │   ├── <feature>_repository_impl.dart     # Local + remote orchestration
│       │   └── data_source/
│       │       ├── <feature>_remote_source.dart   # HTTP via ApiClient
│       │       └── <feature>_local_source.dart    # Cache via LocalStorage
│       ├── controller/<feature>_controller.dart   # Extends BaseController
│       └── view/
│           ├── <feature>_view.dart
│           └── widgets/
│
test/
└── features/
    └── <feature>/
        ├── <feature>_controller_test.dart
        ├── <feature>_repository_test.dart
        └── <feature>_view_test.dart
```

## Getting Started

### Prerequisites

- Flutter SDK `^3.11.5`
- Dart SDK (bundled with Flutter)

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
# Development (default — uses localhost)
flutter run

# With custom environment
flutter run --dart-define=BASE_URL=https://api.example.com --dart-define=ENV=staging
```

### Run tests

```bash
flutter test
```

### Analyze

```bash
flutter analyze
```

## Creating a New Feature

Use the generator script to scaffold a complete feature in one command:

```bash
./scripts/create_feature.sh <feature_name>
```

Example:

```bash
./scripts/create_feature.sh payment
./scripts/create_feature.sh order_history
```

This creates all files following the Karna MVC pattern and registers the controller in `core/di/providers.dart` automatically. Generated features include:
- `Result<T>` returns from repositories
- Local-first data strategy with connectivity checks
- `BaseController` with `DataStrategy` support
- Remote source using `ApiClient`
- Local source using `LocalStorage`
- Full test suite (controller, repository, view)

You can also run it from VS Code:
1. `Cmd+Shift+P` → "Run Task"
2. Select **"Karna: Create Feature"**
3. Enter the feature name in `snake_case`

## Core Concepts

### Result Type

Repositories return `Result<T>` instead of throwing exceptions:

```dart
final result = await repository.getById(id);
result.when(
  success: (data) => _user = data,
  failure: (error) => _error = error,  // Typed AppException
);
```

### Data Strategy

Controllers declare how data is loaded via `DataStrategy`:

```dart
// Default — cache first, network on miss
await controller.loadPosts();

// Show stale cache immediately, refresh in background
await controller.loadPosts(strategy: DataStrategy.staleWhileRevalidate);

// Always hit network, fall back to cache on failure
await controller.loadPosts(strategy: DataStrategy.remoteFirst);
```

### BaseController

All controllers extend `BaseController` which provides:
- `isLoading` — true during initial load
- `isRefreshing` — true during background refresh
- `hasError` / `errorMessage` — typed error state
- `load(strategy:)` — unified data loading with strategy
- `executeResult()` — shorthand for single actions

### Storage-Agnostic Caching

A single `LocalStorage` interface backs all features. Swap the implementation in one line:

```dart
// In providers.dart — change backend for entire app:
Provider<LocalStorage>(create: (_) => HiveStorage(box: box)),
// or: InMemoryStorage(), SharedPrefsStorage(prefs: prefs)
```

### API Client

Shared HTTP client with:
- Base URL from `AppConfig` (environment-aware)
- Auth token injection
- Retry logic (2 retries with backoff)
- Typed error mapping (401 → `ServerException`, no network → `NetworkException`)

### Connectivity Awareness

Repositories check network before remote calls and return typed `NetworkException` failures, allowing the UI to show appropriate offline states.

### Event Bus (Cross-Feature Notifications)

Features never import each other — but sometimes one feature needs to react when something happens in another. The `EventBus` solves this with typed, fire-and-forget events:

```dart
// Publishing — fire an event from any controller:
_eventBus.fire(const CacheClearedEvent());

// Subscribing — react in another controller without importing the publisher:
_cacheSub = _eventBus.on<CacheClearedEvent>().listen((_) {
  _posts = [];
  notifyListeners();
});
```

Built-in events: `UserLoggedInEvent`, `UserLoggedOutEvent`, `SessionExpiredEvent`, `UserProfileUpdatedEvent`, `ConnectivityChangedEvent`, `CacheClearedEvent`.

Add custom events by extending `AppEvent` in `core/events/app_events.dart`. The event bus is injected via constructor — fully mockable in tests.

## Example Feature: Post

The project ships with a single `post` feature that demonstrates the full pattern end-to-end. Use it as a reference, then delete it when you start building your own features.

```
lib/features/post/
├── model/post_model.dart                    # Immutable model with fromJson/toJson/copyWith
├── repository/
│   ├── post_repository.dart                 # Abstract interface (returns Result<T>)
│   ├── post_repository_impl.dart            # Orchestrates local + remote + connectivity
│   └── data_source/
│       ├── post_remote_source.dart          # HTTP via ApiClient
│       └── post_local_source.dart           # Cache via LocalStorage
├── controller/post_controller.dart          # All 3 data strategies + EventBus
└── view/post_view.dart                      # Uses shared widgets, pull-to-refresh
```

The example demonstrates:
- All three `DataStrategy` modes in the controller
- `EventBus` subscription (reacts to `CacheClearedEvent`)
- Proper `dispose()` with subscription cleanup
- View using `LoadingIndicator`, `ErrorDisplay`, and `RefreshIndicator`
- Full test coverage (controller, repository, view)

## Architecture Rules

| Rule | Rationale |
|------|-----------|
| One feature folder per product feature | Co-located and deletable as a unit |
| Features never import other features | Cross-feature coupling resolved in `core/di/` |
| Controllers extend `BaseController` | Shared loading/error/strategy patterns |
| Repositories return `Result<T>` | Typed errors, no uncaught exceptions |
| Repositories expose `getFromCache` + `getFromRemote` | Enables all three data strategies |
| Views contain zero business logic | Only UI logic (animations, layout) |
| Remote sources use `ApiClient` | Centralized HTTP, auth, retries |
| Local sources use `LocalStorage` | Storage-agnostic, swappable backend |
| Models are immutable (`final` + `copyWith`) | Predictable state |
| All dependencies injected via constructor | No hidden singletons, fully mockable |
| Shared code moves to `core/` only when used by 2+ features | No premature abstraction |

## Key Packages

| Package | Role |
|---------|------|
| `provider` | DI + state propagation to the widget tree |
| `http` | HTTP client (used by ApiClient) |
| `hive` / `hive_flutter` | Fast local storage backend |
| `shared_preferences` | Simple key-value storage backend |
| `flutter_test` | Widget and unit testing |

## Further Reading

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full specification including code examples, testing strategy, data strategy behavior matrix, and detailed conventions.
