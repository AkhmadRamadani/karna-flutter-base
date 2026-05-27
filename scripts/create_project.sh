#!/bin/bash

# Karna MVC — Project Initializer
# Creates a new Flutter project with the full Karna MVC architecture.
#
# Usage:
#   ./scripts/create_project.sh <project_name> [--org com.example]
#
# Example:
#   ./scripts/create_project.sh my_app
#   ./scripts/create_project.sh my_app --org com.mycompany
#
# This will:
#   1. Create a new Flutter project
#   2. Add required dependencies
#   3. Scaffold the full core/ architecture
#   4. Set up scripts, analysis options, and ARCHITECTURE.md
#   5. Remove the default counter app

set -e

# ─── Parse arguments ─────────────────────────────────────────────────

PROJECT_NAME=""
ORG="com.example"

while [[ $# -gt 0 ]]; do
  case $1 in
    --org)
      ORG="$2"
      shift 2
      ;;
    -*)
      echo "❌ Unknown option: $1"
      exit 1
      ;;
    *)
      PROJECT_NAME="$1"
      shift
      ;;
  esac
done

if [ -z "$PROJECT_NAME" ]; then
  echo "❌ Usage: ./scripts/create_project.sh <project_name> [--org com.example]"
  echo ""
  echo "   Example: ./scripts/create_project.sh my_app"
  echo "            ./scripts/create_project.sh my_app --org com.mycompany"
  exit 1
fi

# Validate project name
if [[ ! "$PROJECT_NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
  echo "❌ Project name must be snake_case (lowercase letters, numbers, underscores)"
  exit 1
fi

# Check if directory already exists
if [ -d "$PROJECT_NAME" ]; then
  echo "❌ Directory '$PROJECT_NAME' already exists"
  exit 1
fi

echo "🚀 Creating Karna MVC project: $PROJECT_NAME"
echo "   Organization: $ORG"
echo ""

# ─── Step 1: Create Flutter project ─────────────────────────────────

echo "📦 Creating Flutter project..."
flutter create --org "$ORG" "$PROJECT_NAME"
if [ ! -d "$PROJECT_NAME" ]; then
  echo "❌ flutter create failed. Make sure Flutter is installed and in your PATH."
  exit 1
fi
cd "$PROJECT_NAME"

echo "  ✅ Flutter project created"

# ─── Step 2: Add dependencies ────────────────────────────────────────

echo "📦 Adding dependencies..."
flutter pub add provider http shared_preferences hive_ce hive_ce_flutter
echo "  ✅ Dependencies added"

# ─── Step 3: Create directory structure ──────────────────────────────

echo "📁 Scaffolding Karna MVC architecture..."

mkdir -p lib/core/config
mkdir -p lib/core/controller
mkdir -p lib/core/di
mkdir -p lib/core/errors
mkdir -p lib/core/events
mkdir -p lib/core/memory
mkdir -p lib/core/network
mkdir -p lib/core/notification
mkdir -p lib/core/result
mkdir -p lib/core/routes
mkdir -p lib/core/storage
mkdir -p lib/core/theme
mkdir -p lib/core/widgets
mkdir -p lib/features
mkdir -p scripts
mkdir -p test/features

# ─── Step 4: Core files ──────────────────────────────────────────────

# app_config.dart
cat > lib/core/config/app_config.dart << 'EOF'
/// Environment configuration for the app.
/// Populated from --dart-define flags.
///
/// Usage:
///   flutter run --dart-define=BASE_URL=https://api.example.com
///   flutter run --dart-define=ENV=production
class AppConfig {
  final String baseUrl;
  final String environment;
  final Duration timeout;
  final bool enableLogging;

  const AppConfig({
    required this.baseUrl,
    required this.environment,
    this.timeout = const Duration(seconds: 30),
    this.enableLogging = false,
  });

  factory AppConfig.fromEnvironment() {
    const baseUrl = String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'http://localhost:8080',
    );
    const env = String.fromEnvironment('ENV', defaultValue: 'development');
    const timeoutSeconds = int.fromEnvironment('TIMEOUT', defaultValue: 30);
    const enableLogging = bool.fromEnvironment(
      'ENABLE_LOGGING',
      defaultValue: true,
    );

    return AppConfig(
      baseUrl: baseUrl,
      environment: env,
      timeout: Duration(seconds: timeoutSeconds),
      enableLogging: enableLogging,
    );
  }

  bool get isDevelopment => environment == 'development';
  bool get isStaging => environment == 'staging';
  bool get isProduction => environment == 'production';
}
EOF

# app_exception.dart
cat > lib/core/errors/app_exception.dart << 'EOF'
class AppException implements Exception {
  final String message;
  final String? code;
  const AppException({required this.message, this.code});

  @override
  String toString() => 'AppException($code): $message';
}

class NetworkException extends AppException {
  const NetworkException({required super.message, super.code});
}

class ServerException extends AppException {
  final int? statusCode;
  const ServerException({required super.message, super.code, this.statusCode});
}

class CacheException extends AppException {
  const CacheException({required super.message, super.code});
}
EOF

# result.dart
cat > lib/core/result/result.dart << 'EOF'
import '../errors/app_exception.dart';

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  T get data => (this as Success<T>).value;
  AppException get exception => (this as Failure<T>).error;

  R when<R>({
    required R Function(T data) success,
    required R Function(AppException error) failure,
  }) {
    return switch (this) {
      Success<T>(value: final data) => success(data),
      Failure<T>(error: final error) => failure(error),
    };
  }

  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success<T>(value: final data) => Success(transform(data)),
      Failure<T>(error: final error) => Failure(error),
    };
  }
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

class Failure<T> extends Result<T> {
  final AppException error;
  const Failure(this.error);
}
EOF

# data_strategy.dart
cat > lib/core/network/data_strategy.dart << 'EOF'
enum DataStrategy {
  localFirst,
  staleWhileRevalidate,
  remoteFirst,
}
EOF

# connectivity_checker.dart
cat > lib/core/network/connectivity_checker.dart << 'EOF'
abstract class ConnectivityChecker {
  Future<bool> get hasConnection;
}

class ConnectivityCheckerImpl implements ConnectivityChecker {
  @override
  Future<bool> get hasConnection async {
    try {
      return true;
    } catch (_) {
      return false;
    }
  }
}
EOF

# local_storage.dart
cat > lib/core/storage/local_storage.dart << 'EOF'
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
EOF

# hive_storage.dart
cat > lib/core/storage/hive_storage.dart << 'EOF'
import 'dart:convert';
import 'package:hive_ce/hive.dart';
import 'local_storage.dart';

class HiveStorage implements LocalStorage {
  final Box<String> _box;
  HiveStorage({required Box<String> box}) : _box = box;

  @override
  Future<Map<String, dynamic>?> getJson(String key) async {
    final raw = _box.get(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    final raw = _box.get(key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  @override
  Future<void> putJson(String key, Map<String, dynamic> value) async {
    await _box.put(key, jsonEncode(value));
  }

  @override
  Future<void> putJsonList(String key, List<Map<String, dynamic>> value) async {
    await _box.put(key, jsonEncode(value));
  }

  @override
  Future<void> remove(String key) async => await _box.delete(key);

  @override
  Future<void> removeByPrefix(String prefix) async {
    final keys = _box.keys.whereType<String>().where((k) => k.startsWith(prefix)).toList();
    await _box.deleteAll(keys);
  }

  @override
  Future<void> clear() async => await _box.clear();

  @override
  Future<bool> has(String key) async => _box.containsKey(key);
}
EOF

# in_memory_storage.dart
cat > lib/core/storage/in_memory_storage.dart << 'EOF'
import 'local_storage.dart';

class InMemoryStorage implements LocalStorage {
  final Map<String, dynamic> _store = {};

  @override
  Future<Map<String, dynamic>?> getJson(String key) async {
    final value = _store[key];
    if (value is Map<String, dynamic>) return Map.from(value);
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    final value = _store[key];
    if (value is List) return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return [];
  }

  @override
  Future<void> putJson(String key, Map<String, dynamic> value) async {
    _store[key] = Map<String, dynamic>.from(value);
  }

  @override
  Future<void> putJsonList(String key, List<Map<String, dynamic>> value) async {
    _store[key] = value.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<void> remove(String key) async => _store.remove(key);

  @override
  Future<void> removeByPrefix(String prefix) async {
    _store.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<bool> has(String key) async => _store.containsKey(key);
}
EOF

# event_bus.dart
cat > lib/core/events/event_bus.dart << 'EOF'
import 'dart:async';

abstract class EventBus {
  Stream<T> on<T extends AppEvent>();
  void fire(AppEvent event);
  void dispose();
}

abstract class AppEvent {
  const AppEvent();
}

class EventBusImpl implements EventBus {
  final StreamController<AppEvent> _controller = StreamController<AppEvent>.broadcast();

  @override
  Stream<T> on<T extends AppEvent>() => _controller.stream.where((e) => e is T).cast<T>();

  @override
  void fire(AppEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  @override
  void dispose() => _controller.close();
}
EOF

# app_events.dart
cat > lib/core/events/app_events.dart << 'EOF'
import 'event_bus.dart';

/// Add your app-wide events here.
/// Example:
///   class UserLoggedOutEvent extends AppEvent { const UserLoggedOutEvent(); }

class CacheClearedEvent extends AppEvent {
  const CacheClearedEvent();
}
EOF

# notification_service.dart
cat > lib/core/notification/notification_service.dart << 'EOF'
import 'app_notification.dart';

abstract class NotificationService {
  void show(AppNotification notification);
}
EOF

# app_notification.dart
cat > lib/core/notification/app_notification.dart << 'EOF'
class AppNotification {
  final String message;
  final NotificationType type;
  final Duration duration;
  final String? actionLabel;
  final void Function()? onAction;

  const AppNotification({
    required this.message,
    this.type = NotificationType.error,
    this.duration = const Duration(seconds: 4),
    this.actionLabel,
    this.onAction,
  });

  const AppNotification.error(String message, {Duration? duration})
    : this(message: message, type: NotificationType.error, duration: duration ?? const Duration(seconds: 4));

  const AppNotification.success(String message, {Duration? duration})
    : this(message: message, type: NotificationType.success, duration: duration ?? const Duration(seconds: 3));

  const AppNotification.warning(String message, {Duration? duration})
    : this(message: message, type: NotificationType.warning, duration: duration ?? const Duration(seconds: 4));

  const AppNotification.info(String message, {Duration? duration})
    : this(message: message, type: NotificationType.info, duration: duration ?? const Duration(seconds: 3));
}

enum NotificationType { error, warning, success, info }
EOF

# snackbar_notification_service.dart
cat > lib/core/notification/snackbar_notification_service.dart << 'EOF'
import 'package:flutter/material.dart';
import 'app_notification.dart';
import 'notification_service.dart';

class SnackBarNotificationService implements NotificationService {
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  SnackBarNotificationService({required this.messengerKey});

  @override
  void show(AppNotification notification) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Row(children: [
        Icon(_iconFor(notification.type), color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(notification.message, style: const TextStyle(color: Colors.white))),
      ]),
      backgroundColor: _colorFor(notification.type),
      duration: notification.duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      action: notification.actionLabel != null
          ? SnackBarAction(label: notification.actionLabel!, textColor: Colors.white, onPressed: notification.onAction ?? () {})
          : null,
    ));
  }

  Color _colorFor(NotificationType type) => switch (type) {
    NotificationType.error => const Color(0xFFD32F2F),
    NotificationType.warning => const Color(0xFFF57C00),
    NotificationType.success => const Color(0xFF388E3C),
    NotificationType.info => const Color(0xFF1976D2),
  };

  IconData _iconFor(NotificationType type) => switch (type) {
    NotificationType.error => Icons.error_outline,
    NotificationType.warning => Icons.warning_amber_outlined,
    NotificationType.success => Icons.check_circle_outline,
    NotificationType.info => Icons.info_outline,
  };
}
EOF

# api_client.dart
cat > lib/core/network/api_client.dart << 'EOF'
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../errors/app_exception.dart';

class ApiClient {
  final http.Client _client;
  final AppConfig _config;
  String? _authToken;

  ApiClient({required AppConfig config, http.Client? client})
    : _config = config, _client = client ?? http.Client();

  void setAuthToken(String? token) => _authToken = token;

  Future<dynamic> get(String path, {Map<String, String>? queryParams, Map<String, String>? headers}) async {
    final uri = _buildUri(path, queryParams);
    final response = await _executeWithRetry(() => _client.get(uri, headers: _buildHeaders(headers)));
    return _handleResponse(response);
  }

  Future<dynamic> post(String path, {Object? body, Map<String, String>? headers}) async {
    final uri = _buildUri(path, null);
    final response = await _executeWithRetry(() => _client.post(uri, headers: _buildHeaders(headers), body: body is String ? body : jsonEncode(body)));
    return _handleResponse(response);
  }

  Future<dynamic> put(String path, {Object? body, Map<String, String>? headers}) async {
    final uri = _buildUri(path, null);
    final response = await _executeWithRetry(() => _client.put(uri, headers: _buildHeaders(headers), body: body is String ? body : jsonEncode(body)));
    return _handleResponse(response);
  }

  Future<dynamic> delete(String path, {Map<String, String>? headers}) async {
    final uri = _buildUri(path, null);
    final response = await _executeWithRetry(() => _client.delete(uri, headers: _buildHeaders(headers)));
    return _handleResponse(response);
  }

  Uri _buildUri(String path, Map<String, String>? queryParams) {
    final baseUri = Uri.parse(_config.baseUrl);
    return baseUri.replace(path: '${baseUri.path}$path', queryParameters: queryParams);
  }

  Map<String, String> _buildHeaders(Map<String, String>? extra) {
    final headers = <String, String>{'Content-Type': 'application/json', 'Accept': 'application/json', ...?extra};
    if (_authToken != null) headers['Authorization'] = 'Bearer $_authToken';
    return headers;
  }

  Future<http.Response> _executeWithRetry(Future<http.Response> Function() request, {int maxRetries = 2}) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await request().timeout(_config.timeout);
      } on SocketException {
        if (attempts > maxRetries) throw const NetworkException(message: 'No internet connection', code: 'NO_CONNECTION');
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      } on HttpException {
        if (attempts > maxRetries) throw const NetworkException(message: 'Network request failed', code: 'HTTP_ERROR');
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
  }

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    switch (statusCode) {
      case 401: throw const ServerException(message: 'Unauthorized', code: 'UNAUTHORIZED', statusCode: 401);
      case 403: throw const ServerException(message: 'Forbidden', code: 'FORBIDDEN', statusCode: 403);
      case 404: throw const ServerException(message: 'Not found', code: 'NOT_FOUND', statusCode: 404);
      case 429: throw const ServerException(message: 'Too many requests', code: 'RATE_LIMITED', statusCode: 429);
      default:
        if (statusCode >= 500) throw ServerException(message: 'Server error', code: 'SERVER_ERROR', statusCode: statusCode);
        throw ServerException(message: 'Unexpected error (HTTP $statusCode)', code: 'UNKNOWN', statusCode: statusCode);
    }
  }

  void dispose() => _client.close();
}
EOF

# base_controller.dart
cat > lib/core/controller/base_controller.dart << 'EOF'
import 'package:flutter/foundation.dart';
import '../errors/app_exception.dart';
import '../network/data_strategy.dart';
import '../notification/app_notification.dart';
import '../notification/notification_service.dart';
import '../result/result.dart';

abstract class BaseController extends ChangeNotifier {
  final NotificationService? _notificationService;
  BaseController({NotificationService? notificationService}) : _notificationService = notificationService;

  bool _isLoading = false;
  bool _isRefreshing = false;
  AppException? _error;

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  AppException? get error => _error;
  String? get errorMessage => _error?.message;
  bool get hasError => _error != null;

  void clearError() { _error = null; notifyListeners(); }

  @protected
  void notify(AppNotification notification) => _notificationService?.show(notification);

  void _setError(AppException error) {
    _error = error;
    _notificationService?.show(AppNotification.error(error.message));
  }

  @protected
  Future<void> execute(Future<void> Function() action) async {
    _isLoading = true; _error = null; notifyListeners();
    try { await action(); } catch (e) {
      _setError(e is AppException ? e : AppException(message: e.toString()));
    } finally { _isLoading = false; notifyListeners(); }
  }

  @protected
  Future<void> executeResult<T>(Future<Result<T>> Function() action, {required void Function(T data) onSuccess}) async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      final result = await action();
      result.when(success: (data) => onSuccess(data), failure: (error) => _setError(error));
    } catch (e) {
      _setError(e is AppException ? e : AppException(message: e.toString()));
    } finally { _isLoading = false; notifyListeners(); }
  }

  @protected
  Future<void> load<T>({
    required DataStrategy strategy,
    required Future<Result<T>> Function() cacheAction,
    required Future<Result<T>> Function() freshAction,
    required void Function(T data) onSuccess,
  }) async {
    switch (strategy) {
      case DataStrategy.localFirst: await _loadLocalFirst(cacheAction: cacheAction, freshAction: freshAction, onSuccess: onSuccess);
      case DataStrategy.staleWhileRevalidate: await _loadSWR(cacheAction: cacheAction, freshAction: freshAction, onSuccess: onSuccess);
      case DataStrategy.remoteFirst: await _loadRemoteFirst(cacheAction: cacheAction, freshAction: freshAction, onSuccess: onSuccess);
    }
  }

  Future<void> _loadLocalFirst<T>({required Future<Result<T>> Function() cacheAction, required Future<Result<T>> Function() freshAction, required void Function(T) onSuccess}) async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      final cache = await cacheAction();
      if (cache.isSuccess) { onSuccess(cache.data); _isLoading = false; notifyListeners(); return; }
      final fresh = await freshAction();
      fresh.when(success: (d) => onSuccess(d), failure: (e) => _setError(e));
    } catch (e) { _setError(e is AppException ? e : AppException(message: e.toString())); }
    finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> _loadSWR<T>({required Future<Result<T>> Function() cacheAction, required Future<Result<T>> Function() freshAction, required void Function(T) onSuccess}) async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      final cache = await cacheAction();
      cache.when(success: (d) { onSuccess(d); _isLoading = false; _isRefreshing = true; notifyListeners(); }, failure: (_) {});
      final fresh = await freshAction();
      fresh.when(success: (d) { onSuccess(d); _error = null; }, failure: (e) { if (cache.isFailure) _setError(e); });
    } catch (e) { _setError(e is AppException ? e : AppException(message: e.toString())); }
    finally { _isLoading = false; _isRefreshing = false; notifyListeners(); }
  }

  Future<void> _loadRemoteFirst<T>({required Future<Result<T>> Function() cacheAction, required Future<Result<T>> Function() freshAction, required void Function(T) onSuccess}) async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      final fresh = await freshAction();
      if (fresh.isSuccess) { onSuccess(fresh.data); _isLoading = false; notifyListeners(); return; }
      final cache = await cacheAction();
      cache.when(success: (d) => onSuccess(d), failure: (_) => _setError(fresh.exception));
    } catch (e) { _setError(e is AppException ? e : AppException(message: e.toString())); }
    finally { _isLoading = false; notifyListeners(); }
  }
}
EOF

# memory/service_priority.dart
cat > lib/core/memory/service_priority.dart << 'EOF'
enum ServicePriority {
  low(0),
  normal(1),
  high(2),
  critical(3);

  final int weight;
  const ServicePriority(this.weight);

  bool canKillAt(MemoryPressure pressure) {
    switch (pressure) {
      case MemoryPressure.low: return this == ServicePriority.low;
      case MemoryPressure.moderate: return weight <= ServicePriority.normal.weight;
      case MemoryPressure.high: return weight <= ServicePriority.high.weight;
      case MemoryPressure.critical: return this != ServicePriority.critical;
    }
  }
}

enum MemoryPressure { low, moderate, high, critical }
EOF

# memory/managed_service.dart
cat > lib/core/memory/managed_service.dart << 'EOF'
import 'service_priority.dart';

abstract class ManagedService {
  String get serviceId;
  ServicePriority get priority;
  bool get isActive;
  Future<void> onMemoryWarning();
  Future<void> onKill();
  Future<void> onRevive();
}

class ServiceState {
  final ManagedService service;
  bool isKilled;
  DateTime? lastActiveAt;
  DateTime? killedAt;

  ServiceState({required this.service, this.isKilled = false, this.lastActiveAt, this.killedAt});

  Duration get idleDuration {
    if (lastActiveAt == null) return Duration.zero;
    return DateTime.now().difference(lastActiveAt!);
  }

  void markActive() => lastActiveAt = DateTime.now();
  void markKilled() { isKilled = true; killedAt = DateTime.now(); }
  void markRevived() { isKilled = false; killedAt = null; }
}
EOF

# memory/memory_events.dart
cat > lib/core/memory/memory_events.dart << 'EOF'
import '../events/event_bus.dart';
import 'service_priority.dart';

class MemoryPressureChangedEvent extends AppEvent {
  final MemoryPressure previous;
  final MemoryPressure current;
  const MemoryPressureChangedEvent({required this.previous, required this.current});
}

class ServiceKilledEvent extends AppEvent {
  final String serviceId;
  final ServicePriority priority;
  final MemoryPressure reason;
  const ServiceKilledEvent({required this.serviceId, required this.priority, required this.reason});
}

class ServiceRevivedEvent extends AppEvent {
  final String serviceId;
  final ServicePriority priority;
  const ServiceRevivedEvent({required this.serviceId, required this.priority});
}
EOF

# memory/memory_manager.dart
cat > lib/core/memory/memory_manager.dart << 'EOF'
import 'dart:async';
import 'package:flutter/widgets.dart';
import '../events/event_bus.dart';
import 'managed_service.dart';
import 'memory_events.dart';
import 'service_priority.dart';

class MemoryManager with WidgetsBindingObserver {
  final EventBus _eventBus;
  final Map<String, ServiceState> _services = {};
  final Duration _idleThreshold;
  Timer? _idleCheckTimer;
  MemoryPressure _currentPressure = MemoryPressure.low;

  MemoryManager({
    required EventBus eventBus,
    Duration idleThreshold = const Duration(minutes: 5),
    Duration idleCheckInterval = const Duration(minutes: 1),
  }) : _eventBus = eventBus, _idleThreshold = idleThreshold {
    WidgetsBinding.instance.addObserver(this);
    _idleCheckTimer = Timer.periodic(idleCheckInterval, (_) => _checkIdleServices());
  }

  MemoryPressure get currentPressure => _currentPressure;
  Map<String, ServiceState> get services => Map.unmodifiable(_services);
  int get aliveCount => _services.values.where((s) => !s.isKilled).length;
  int get killedCount => _services.values.where((s) => s.isKilled).length;

  void register(ManagedService service) {
    _services[service.serviceId] = ServiceState(service: service, lastActiveAt: DateTime.now());
    debugPrint('[MemoryManager] Registered: ${service.serviceId} (priority: ${service.priority.name})');
  }

  void unregister(String serviceId) {
    _services.remove(serviceId);
    debugPrint('[MemoryManager] Unregistered: $serviceId');
  }

  void markActive(String serviceId) => _services[serviceId]?.markActive();

  @override
  void didHaveMemoryPressure() => _escalatePressure();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _handleBackgrounded();
      case AppLifecycleState.resumed:
        _handleResumed();
      default: break;
    }
  }

  Future<void> setPressure(MemoryPressure pressure) async {
    if (pressure == _currentPressure) return;
    final previous = _currentPressure;
    _currentPressure = pressure;
    _eventBus.fire(MemoryPressureChangedEvent(previous: previous, current: pressure));
    if (pressure.index > previous.index) await _applyPressure(pressure);
    else await _releasePressure(pressure);
  }

  Future<void> forceKill(String serviceId) async {
    final state = _services[serviceId];
    if (state == null || state.isKilled) return;
    await _killService(state);
  }

  Future<void> forceRevive(String serviceId) async {
    final state = _services[serviceId];
    if (state == null || !state.isKilled) return;
    await _reviveService(state);
  }

  Future<void> _escalatePressure() async {
    final nextIndex = (_currentPressure.index + 1).clamp(0, MemoryPressure.values.length - 1);
    await setPressure(MemoryPressure.values[nextIndex]);
  }

  Future<void> _checkIdleServices() async {
    final idle = _services.values.where((s) => !s.isKilled && s.service.priority == ServicePriority.low && !s.service.isActive && s.idleDuration > _idleThreshold).toList();
    for (final s in idle) await _killService(s);
  }

  Future<void> _applyPressure(MemoryPressure pressure) async {
    final alive = _services.values.where((s) => !s.isKilled).toList();
    for (final s in alive) { try { await s.service.onMemoryWarning(); } catch (_) {} }
    final killable = alive.where((s) => s.service.priority.canKillAt(pressure)).toList()
      ..sort((a, b) => a.service.priority.weight.compareTo(b.service.priority.weight));
    for (final s in killable) await _killService(s);
  }

  Future<void> _releasePressure(MemoryPressure pressure) async {
    final revivable = _services.values.where((s) => s.isKilled && !s.service.priority.canKillAt(pressure)).toList()
      ..sort((a, b) => b.service.priority.weight.compareTo(a.service.priority.weight));
    for (final s in revivable) await _reviveService(s);
  }

  Future<void> _handleBackgrounded() async {
    final low = _services.values.where((s) => !s.isKilled && s.service.priority == ServicePriority.low && !s.service.isActive).toList();
    for (final s in low) await _killService(s);
  }

  Future<void> _handleResumed() async {
    if (_currentPressure != MemoryPressure.low) await setPressure(MemoryPressure.low);
  }

  Future<void> _killService(ServiceState state) async {
    if (state.isKilled) return;
    try {
      await state.service.onKill();
      state.markKilled();
      _eventBus.fire(ServiceKilledEvent(serviceId: state.service.serviceId, priority: state.service.priority, reason: _currentPressure));
    } catch (_) {}
  }

  Future<void> _reviveService(ServiceState state) async {
    if (!state.isKilled) return;
    try {
      await state.service.onRevive();
      state.markRevived();
      _eventBus.fire(ServiceRevivedEvent(serviceId: state.service.serviceId, priority: state.service.priority));
    } catch (_) {}
  }

  void dispose() {
    _idleCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _services.clear();
  }
}
EOF

# memory/memory_aware_controller.dart
cat > lib/core/memory/memory_aware_controller.dart << 'EOF'
import '../controller/base_controller.dart';
import 'managed_service.dart';
import 'memory_manager.dart';
import 'service_priority.dart';

abstract class MemoryAwareController extends BaseController implements ManagedService {
  final MemoryManager _memoryManager;
  final ServicePriority _priority;

  MemoryAwareController({
    required MemoryManager memoryManager,
    required ServicePriority servicePriority,
    super.notificationService,
  }) : _memoryManager = memoryManager, _priority = servicePriority {
    _memoryManager.register(this);
  }

  @override
  ServicePriority get priority => _priority;

  void markSelfActive() => _memoryManager.markActive(serviceId);

  @override
  void dispose() {
    _memoryManager.unregister(serviceId);
    super.dispose();
  }
}
EOF

# app_theme.dart
cat > lib/core/theme/app_theme.dart << 'EOF'
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
  );
}
EOF

# widgets
cat > lib/core/widgets/error_display.dart << 'EOF'
import 'package:flutter/material.dart';

class ErrorDisplay extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorDisplay({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
      const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
      if (onRetry != null) ...[const SizedBox(height: 16), ElevatedButton(onPressed: onRetry, child: const Text('Retry'))],
    ])));
  }
}
EOF

cat > lib/core/widgets/loading_indicator.dart << 'EOF'
import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final String? message;
  const LoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(),
      if (message != null) ...[const SizedBox(height: 16), Text(message!)],
    ]));
  }
}
EOF

# app_dependencies.dart
cat > lib/core/di/app_dependencies.dart << 'EOF'
import 'package:flutter/material.dart';
import '../notification/notification_service.dart';
import '../storage/local_storage.dart';

class AppDependencies {
  final LocalStorage storage;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final NotificationService? notificationService;

  const AppDependencies({
    required this.storage,
    required this.scaffoldMessengerKey,
    this.notificationService,
  });
}
EOF

# providers.dart (clean — no example features)
cat > lib/core/di/providers.dart << 'EOF'
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../config/app_config.dart';
import '../events/event_bus.dart';
import '../memory/memory_manager.dart';
import '../network/api_client.dart';
import '../network/connectivity_checker.dart';
import '../storage/local_storage.dart';
import 'app_dependencies.dart';

/// All providers wired together.
/// Add feature controllers below the core singletons.
List<SingleChildWidget> appProviders({
  required AppDependencies dependencies,
}) => [
  // ─── Core singletons ─────────────────────────────────────────────
  Provider<AppConfig>(create: (_) => AppConfig.fromEnvironment()),
  Provider<ConnectivityChecker>(create: (_) => ConnectivityCheckerImpl()),
  Provider<LocalStorage>(create: (_) => dependencies.storage),
  Provider<EventBus>(
    create: (_) => EventBusImpl(),
    dispose: (_, bus) => bus.dispose(),
  ),
  ProxyProvider<EventBus, MemoryManager>(
    update: (_, eventBus, previous) {
      previous?.dispose();
      return MemoryManager(eventBus: eventBus);
    },
    dispose: (_, manager) => manager.dispose(),
  ),
  ProxyProvider<AppConfig, ApiClient>(
    update: (_, config, previous) {
      previous?.dispose();
      return ApiClient(config: config);
    },
    dispose: (_, client) => client.dispose(),
  ),

  // ─── Feature controllers ─────────────────────────────────────────
  // Add your feature providers here. Example:
  // ChangeNotifierProvider<MyController>(
  //   create: (context) => MyController(
  //     memoryManager: context.read<MemoryManager>(),
  //     repository: MyRepositoryImpl(...),
  //   ),
  // ),
];
EOF

# app_routes.dart
cat > lib/core/routes/app_routes.dart << 'EOF'
import 'package:flutter/material.dart';

class AppRoutes {
  AppRoutes._();

  static const String home = '/';

  static Map<String, WidgetBuilder> get routes => {
    home: (_) => const Scaffold(body: Center(child: Text('Welcome to Karna MVC'))),
  };
}
EOF

# ─── Step 5: main.dart ───────────────────────────────────────────────

cat > lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'core/di/app_dependencies.dart';
import 'core/di/providers.dart';
import 'core/notification/snackbar_notification_service.dart';
import 'core/routes/app_routes.dart';
import 'core/storage/hive_storage.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  final box = await Hive.openBox<String>('app_storage');
  final storage = HiveStorage(box: box);

  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final notificationService = SnackBarNotificationService(messengerKey: scaffoldMessengerKey);

  final deps = AppDependencies(
    storage: storage,
    scaffoldMessengerKey: scaffoldMessengerKey,
    notificationService: notificationService,
  );

  runApp(KarnaApp(dependencies: deps));
}

class KarnaApp extends StatelessWidget {
  final AppDependencies dependencies;
  const KarnaApp({super.key, required this.dependencies});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: appProviders(dependencies: dependencies),
      child: MaterialApp(
        title: 'Karna MVC',
        scaffoldMessengerKey: dependencies.scaffoldMessengerKey,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routes: AppRoutes.routes,
        initialRoute: AppRoutes.home,
      ),
    );
  }
}
EOF

# Remove default test
rm -f test/widget_test.dart

# ─── Step 6: Copy create_feature.sh script ───────────────────────────

SCRIPT_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/create_feature.sh"
if [ -f "$SCRIPT_SOURCE" ]; then
  cp "$SCRIPT_SOURCE" scripts/create_feature.sh
  chmod +x scripts/create_feature.sh
  echo "  ✅ Copied create_feature.sh"
else
  echo "  ⚠️  create_feature.sh not found — you can copy it manually"
fi

# ─── Step 7: Analysis options ────────────────────────────────────────

cat > analysis_options.yaml << 'EOF'
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    # prefer_single_quotes: true
EOF

# ─── Step 8: Final output ────────────────────────────────────────────

echo "  ✅ Core architecture scaffolded"
echo ""
echo "✨ Karna MVC project '$PROJECT_NAME' created successfully!"
echo ""
echo "📁 Structure:"
echo "   $PROJECT_NAME/"
echo "   ├── lib/"
echo "   │   ├── main.dart"
echo "   │   ├── core/"
echo "   │   │   ├── config/app_config.dart"
echo "   │   │   ├── controller/base_controller.dart"
echo "   │   │   ├── di/providers.dart"
echo "   │   │   ├── errors/app_exception.dart"
echo "   │   │   ├── events/event_bus.dart"
echo "   │   │   ├── memory/ (memory manager)"
echo "   │   │   ├── network/api_client.dart"
echo "   │   │   ├── notification/"
echo "   │   │   ├── result/result.dart"
echo "   │   │   ├── routes/app_routes.dart"
echo "   │   │   ├── storage/ (hive + in-memory)"
echo "   │   │   ├── theme/app_theme.dart"
echo "   │   │   └── widgets/"
echo "   │   └── features/ (empty — add with create_feature.sh)"
echo "   ├── scripts/"
echo "   │   └── create_feature.sh"
echo "   └── test/features/"
echo ""
echo "📝 Next steps:"
echo "   cd $PROJECT_NAME"
echo "   ./scripts/create_feature.sh <your_feature>"
echo "   flutter run --dart-define=BASE_URL=http://localhost:8080/api"
echo ""
echo "📖 Run with environment:"
echo "   flutter run --dart-define=BASE_URL=https://api.prod.com --dart-define=ENV=production"
