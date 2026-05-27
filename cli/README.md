# karna_cli

CLI tool to create and manage [Karna MVC](https://github.com/AkhmadRamadani/karna-flutter-base) Flutter projects.

## Install

```bash
dart pub global activate karna_cli
```

## Commands

### Create a project

```bash
karna create my_app
karna create my_app --org com.mycompany
```

Scaffolds a full Karna MVC Flutter project with:
- Typed error handling (`Result<T>`)
- Data strategies (localFirst, staleWhileRevalidate, remoteFirst)
- Memory management (priority-based service lifecycle)
- Storage-agnostic caching (Hive, SharedPrefs, InMemory)
- Event bus for cross-feature communication
- SnackBar notification service

### Create a feature

Run from inside a Karna MVC project:

```bash
karna feature auth
karna feature feed --memory-aware
```

Options:
- `--memory-aware` / `-m` — Use `MemoryAwareController` with automatic memory management

Generates model, repository, data sources, controller, view, and tests. Automatically registers in `providers.dart`.

## Requirements

- Dart SDK `^3.0.0`
- Flutter SDK (for `flutter create` and `flutter pub add`)
