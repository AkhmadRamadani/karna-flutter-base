# Karna MVC

A feature-first Model-View-Controller architecture for Flutter with typed error handling, pluggable data strategies, memory management, storage-agnostic caching, and event-driven cross-feature communication.

> Named after Karna of the Mahabharata: a warrior complete in himself.
> In Indonesian: *karena* (because of) — every layer exists because of its feature.

---

## Installation

### Option A: Dart CLI (recommended)

Install globally via `dart pub global activate` — works on all platforms:

```bash
# From the cli/ directory of this repo (or publish to pub.dev)
dart pub global activate --source path ./cli

# Or once published to pub.dev:
# dart pub global activate karna_cli
```

Then use from anywhere:

```bash
karna create my_app
karna create my_app --org com.mycompany
karna feature auth
karna feature feed --memory-aware
```

### Option B: Shell script (macOS/Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/AkhmadRamadani/karna-flutter-base/main/scripts/create_project.sh -o /usr/local/bin/karna
chmod +x /usr/local/bin/karna

karna my_app
```

### Option C: Clone the template

```bash
git clone https://github.com/AkhmadRamadani/karna-flutter-base.git my_app
cd my_app
rm -rf .git
git init
flutter pub get
```

---

## Quick Start

```bash
# Create a new project
karna my_app
cd my_app

# Create your first feature
./scripts/create_feature.sh auth

# Run the app
flutter run --dart-define=BASE_URL=http://localhost:8080/api

# Run tests
flutter test
```

---

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
│   ├── memory/
│   │   ├── memory_manager.dart           # Service lifecycle manager
│   │   ├── memory_aware_controller.dart  # BaseController + memory management
│   │   ├── managed_service.dart          # Interface for managed services
│   │   ├── memory_events.dart            # Memory pressure events
│   │   └── service_priority.dart         # Priority levels + pressure enum
│   ├── network/
│   │   ├── api_client.dart               # HTTP client with retry & auth
│   │   ├── connectivity_checker.dart     # Network availability check
│   │   └── data_strategy.dart            # DataStrategy enum
│   ├── notification/                     # SnackBar notification service
│   ├── result/result.dart                # Sealed Result<T> (Success/Failure)
│   ├── routes/app_routes.dart            # Centralized routing
│   ├── storage/
│   │   ├── local_storage.dart            # Abstract storage interface
│   │   ├── in_memory_storage.dart        # Dev/tests
│   │   ├── shared_prefs_storage.dart     # Small key-value
│   │   └── hive_storage.dart             # Larger datasets
│   ├── theme/app_theme.dart              # Light & dark theme
│   └── widgets/                          # Shared widgets (2+ features)
│
├── features/
│   └── <feature>/
│       ├── model/<feature>_model.dart
│       ├── repository/
│       │   ├── <feature>_repository.dart
│       │   ├── <feature>_repository_impl.dart
│       │   └── data_source/
│       │       ├── <feature>_remote_source.dart
│       │       └── <feature>_local_source.dart
│       ├── controller/<feature>_controller.dart
│       └── view/<feature>_view.dart
│
scripts/
├── create_project.sh                     # Initialize a new Karna MVC project
└── create_feature.sh                     # Scaffold a new feature
```

---

## CLI Commands

### Create a new project

```bash
karna create <project_name> [--org com.example]
```

This will:
1. Run `flutter create` with your project name
2. Add all required dependencies (provider, http, hive, shared_preferences)
3. Scaffold the full `core/` architecture with memory management
4. Set up a clean `main.dart` with Hive, notifications, and MultiProvider
5. Remove the default counter app

### Create a new feature

```bash
karna feature <feature_name>
karna feature <feature_name> --memory-aware
```

Options:
- `--memory-aware` / `-m` — Use `MemoryAwareController` instead of `BaseController`

Example:

```bash
karna feature payment
karna feature feed --memory-aware
```

This creates all files following the Karna MVC pattern and registers the controller in `core/di/providers.dart` automatically.

---

## Core Concepts

### Result Type

Repositories return `Result<T>` instead of throwing exceptions:

```dart
final result = await repository.getById(id);
result.when(
  success: (data) => _user = data,
  failure: (error) => _error = error,
);
```

### Data Strategy

Controllers declare how data is loaded:

```dart
// Cache first, network on miss
await controller.loadPosts();

// Show stale cache immediately, refresh in background
await controller.loadPosts(strategy: DataStrategy.staleWhileRevalidate);

// Always hit network, fall back to cache on failure
await controller.loadPosts(strategy: DataStrategy.remoteFirst);
```

### Memory Management

Services and controllers participate in automatic memory management based on priority:

| Priority | Behavior |
|----------|----------|
| `critical` | Never killed — auth, storage, navigation |
| `high` | Only killed when device is out of memory |
| `normal` | Killed under moderate memory pressure |
| `low` | Auto-killed when idle (5 min default) |

Extend `MemoryAwareController` instead of `BaseController` for managed controllers:

```dart
class FeedController extends MemoryAwareController {
  FeedController({required super.memoryManager, required FeedRepository repository})
      : super(servicePriority: ServicePriority.normal);

  @override
  String get serviceId => 'feed';

  @override
  bool get isActive => _items.isNotEmpty;

  @override
  Future<void> onMemoryWarning() async => _trimToRecent(20);

  @override
  Future<void> onKill() async { _items.clear(); notifyListeners(); }

  @override
  Future<void> onRevive() async => loadFeed();
}
```

### Event Bus

Cross-feature communication without coupling:

```dart
// Fire from any controller
eventBus.fire(const CacheClearedEvent());

// Listen in another controller
_sub = eventBus.on<CacheClearedEvent>().listen((_) => reload());
```

### Storage-Agnostic Caching

Swap the storage backend in one line — all features follow automatically:

```dart
Provider<LocalStorage>(create: (_) => HiveStorage(box: box)),
// or: InMemoryStorage(), SharedPrefsStorage(prefs: prefs)
```

---

## Running with Environments

```bash
# Development (default)
flutter run

# Staging
flutter run --dart-define=BASE_URL=https://api.staging.com --dart-define=ENV=staging

# Production
flutter run --dart-define=BASE_URL=https://api.prod.com --dart-define=ENV=production
```

---

## Mock Server

A local JSON mock server is included in `mock_server/` for development:

```bash
# Install json-server (one-time)
npm install -g json-server@0.17.4

# Run
cd mock_server
json-server --watch db.json --routes routes.json --port 8080

# Connect your app
flutter run --dart-define=BASE_URL=http://localhost:8080/api
```

For Android emulator, use `http://10.0.2.2:8080/api` instead.

---

## Architecture Rules

| Rule | Rationale |
|------|-----------|
| One feature folder per product feature | Co-located and deletable as a unit |
| Features never import other features | Cross-feature coupling resolved in `core/di/` |
| Controllers extend `BaseController` or `MemoryAwareController` | Shared patterns |
| Repositories return `Result<T>` | Typed errors, no uncaught exceptions |
| Views contain zero business logic | Only UI logic |
| All dependencies injected via constructor | No hidden singletons, fully mockable |
| Shared code moves to `core/` only when used by 2+ features | No premature abstraction |

---

## Key Packages

| Package | Role |
|---------|------|
| `provider` | DI + state propagation |
| `http` | HTTP client |
| `hive_ce` / `hive_ce_flutter` | Fast local storage |
| `shared_preferences` | Simple key-value storage |

---

## Further Reading

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full specification including code examples, testing strategy, data strategy behavior matrix, and detailed conventions.
