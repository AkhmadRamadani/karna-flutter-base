/// Returns a map of file paths → file contents for the core architecture.
Map<String, String> projectFiles() => {
      'lib/core/config/app_config.dart': _appConfig,
      'lib/core/errors/app_exception.dart': _appException,
      'lib/core/result/result.dart': _result,
      'lib/core/network/data_strategy.dart': _dataStrategy,
      'lib/core/network/connectivity_checker.dart': _connectivityChecker,
      'lib/core/network/api_client.dart': _apiClient,
      'lib/core/storage/local_storage.dart': _localStorage,
      'lib/core/storage/hive_storage.dart': _hiveStorage,
      'lib/core/storage/in_memory_storage.dart': _inMemoryStorage,
      'lib/core/events/event_bus.dart': _eventBus,
      'lib/core/events/app_events.dart': _appEvents,
      'lib/core/controller/base_controller.dart': _baseController,
      'lib/core/memory/service_priority.dart': _servicePriority,
      'lib/core/memory/managed_service.dart': _managedService,
      'lib/core/memory/memory_events.dart': _memoryEvents,
      'lib/core/memory/memory_manager.dart': _memoryManager,
      'lib/core/memory/memory_aware_controller.dart': _memoryAwareController,
      'lib/core/notification/notification_service.dart': _notificationService,
      'lib/core/notification/app_notification.dart': _appNotification,
      'lib/core/notification/snackbar_notification_service.dart':
          _snackbarService,
      'lib/core/theme/app_theme.dart': _appTheme,
      'lib/core/widgets/error_display.dart': _errorDisplay,
      'lib/core/widgets/loading_indicator.dart': _loadingIndicator,
      'lib/core/di/app_dependencies.dart': _appDependencies,
      'lib/core/di/providers.dart': _providers,
      'lib/core/routes/app_routes.dart': _appRoutes,
      'lib/main.dart': _mainDart,
      'analysis_options.yaml': _analysisOptions,
    };

const _appConfig = '''
class AppConfig {
  final String baseUrl;
  final String environment;
  final Duration timeout;
  final bool enableLogging;

  const AppConfig({required this.baseUrl, required this.environment, this.timeout = const Duration(seconds: 30), this.enableLogging = false});

  factory AppConfig.fromEnvironment() {
    const baseUrl = String.fromEnvironment('BASE_URL', defaultValue: 'http://localhost:8080');
    const env = String.fromEnvironment('ENV', defaultValue: 'development');
    const timeoutSeconds = int.fromEnvironment('TIMEOUT', defaultValue: 30);
    const enableLogging = bool.fromEnvironment('ENABLE_LOGGING', defaultValue: true);
    return AppConfig(baseUrl: baseUrl, environment: env, timeout: Duration(seconds: timeoutSeconds), enableLogging: enableLogging);
  }

  bool get isDevelopment => environment == 'development';
  bool get isStaging => environment == 'staging';
  bool get isProduction => environment == 'production';
}
''';

const _appException = '''
class AppException implements Exception {
  final String message;
  final String? code;
  const AppException({required this.message, this.code});
  @override
  String toString() => 'AppException(\$code): \$message';
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
''';

const _result = '''
import '../errors/app_exception.dart';

sealed class Result<T> {
  const Result();
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  T get data => (this as Success<T>).value;
  AppException get exception => (this as Failure<T>).error;

  R when<R>({required R Function(T data) success, required R Function(AppException error) failure}) {
    return switch (this) { Success<T>(value: final d) => success(d), Failure<T>(error: final e) => failure(e) };
  }

  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) { Success<T>(value: final d) => Success(transform(d)), Failure<T>(error: final e) => Failure(e) };
  }
}

class Success<T> extends Result<T> { final T value; const Success(this.value); }
class Failure<T> extends Result<T> { final AppException error; const Failure(this.error); }
''';

const _dataStrategy = '''
enum DataStrategy { localFirst, staleWhileRevalidate, remoteFirst }
''';

const _connectivityChecker = '''
abstract class ConnectivityChecker {
  Future<bool> get hasConnection;
}

class ConnectivityCheckerImpl implements ConnectivityChecker {
  @override
  Future<bool> get hasConnection async => true;
}
''';

const _apiClient = '''
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../errors/app_exception.dart';

class ApiClient {
  final http.Client _client;
  final AppConfig _config;
  String? _authToken;

  ApiClient({required AppConfig config, http.Client? client}) : _config = config, _client = client ?? http.Client();

  void setAuthToken(String? token) => _authToken = token;

  Future<dynamic> get(String path, {Map<String, String>? queryParams, Map<String, String>? headers}) async {
    final response = await _executeWithRetry(() => _client.get(_buildUri(path, queryParams), headers: _buildHeaders(headers)));
    return _handleResponse(response);
  }

  Future<dynamic> post(String path, {Object? body, Map<String, String>? headers}) async {
    final response = await _executeWithRetry(() => _client.post(_buildUri(path, null), headers: _buildHeaders(headers), body: body is String ? body : jsonEncode(body)));
    return _handleResponse(response);
  }

  Future<dynamic> put(String path, {Object? body, Map<String, String>? headers}) async {
    final response = await _executeWithRetry(() => _client.put(_buildUri(path, null), headers: _buildHeaders(headers), body: body is String ? body : jsonEncode(body)));
    return _handleResponse(response);
  }

  Future<dynamic> delete(String path, {Map<String, String>? headers}) async {
    final response = await _executeWithRetry(() => _client.delete(_buildUri(path, null), headers: _buildHeaders(headers)));
    return _handleResponse(response);
  }

  Uri _buildUri(String path, Map<String, String>? queryParams) {
    final baseUri = Uri.parse(_config.baseUrl);
    return baseUri.replace(path: '\\\${baseUri.path}\\\$path', queryParameters: queryParams);
  }

  Map<String, String> _buildHeaders(Map<String, String>? extra) {
    final headers = <String, String>{'Content-Type': 'application/json', 'Accept': 'application/json', ...?extra};
    if (_authToken != null) headers['Authorization'] = 'Bearer \\\$_authToken';
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
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    switch (response.statusCode) {
      case 401: throw const ServerException(message: 'Unauthorized', code: 'UNAUTHORIZED', statusCode: 401);
      case 403: throw const ServerException(message: 'Forbidden', code: 'FORBIDDEN', statusCode: 403);
      case 404: throw const ServerException(message: 'Not found', code: 'NOT_FOUND', statusCode: 404);
      case 429: throw const ServerException(message: 'Too many requests', code: 'RATE_LIMITED', statusCode: 429);
      default:
        if (response.statusCode >= 500) throw ServerException(message: 'Server error', code: 'SERVER_ERROR', statusCode: response.statusCode);
        throw ServerException(message: 'Unexpected error (HTTP \\\${response.statusCode})', code: 'UNKNOWN', statusCode: response.statusCode);
    }
  }

  void dispose() => _client.close();
}
''';

const _localStorage = '''
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
''';

const _hiveStorage = '''
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
    return (jsonDecode(raw) as List).map((e) => e as Map<String, dynamic>).toList();
  }

  @override
  Future<void> putJson(String key, Map<String, dynamic> value) async => await _box.put(key, jsonEncode(value));

  @override
  Future<void> putJsonList(String key, List<Map<String, dynamic>> value) async => await _box.put(key, jsonEncode(value));

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
''';

const _inMemoryStorage = '''
import 'local_storage.dart';

class InMemoryStorage implements LocalStorage {
  final Map<String, dynamic> _store = {};

  @override
  Future<Map<String, dynamic>?> getJson(String key) async {
    final v = _store[key];
    if (v is Map<String, dynamic>) return Map.from(v);
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    final v = _store[key];
    if (v is List) return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return [];
  }

  @override
  Future<void> putJson(String key, Map<String, dynamic> value) async => _store[key] = Map<String, dynamic>.from(value);

  @override
  Future<void> putJsonList(String key, List<Map<String, dynamic>> value) async => _store[key] = value.map((e) => Map<String, dynamic>.from(e)).toList();

  @override
  Future<void> remove(String key) async => _store.remove(key);

  @override
  Future<void> removeByPrefix(String prefix) async => _store.removeWhere((k, _) => k.startsWith(prefix));

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<bool> has(String key) async => _store.containsKey(key);
}
''';

const _eventBus = '''
import 'dart:async';

abstract class EventBus {
  Stream<T> on<T extends AppEvent>();
  void fire(AppEvent event);
  void dispose();
}

abstract class AppEvent { const AppEvent(); }

class EventBusImpl implements EventBus {
  final StreamController<AppEvent> _controller = StreamController<AppEvent>.broadcast();

  @override
  Stream<T> on<T extends AppEvent>() => _controller.stream.where((e) => e is T).cast<T>();

  @override
  void fire(AppEvent event) { if (!_controller.isClosed) _controller.add(event); }

  @override
  void dispose() => _controller.close();
}
''';

const _appEvents = '''
import 'event_bus.dart';

class CacheClearedEvent extends AppEvent { const CacheClearedEvent(); }
''';

const _baseController = '''
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

  void _setError(AppException error) { _error = error; _notificationService?.show(AppNotification.error(error.message)); }

  @protected
  Future<void> execute(Future<void> Function() action) async {
    _isLoading = true; _error = null; notifyListeners();
    try { await action(); } catch (e) { _setError(e is AppException ? e : AppException(message: e.toString())); }
    finally { _isLoading = false; notifyListeners(); }
  }

  @protected
  Future<void> executeResult<T>(Future<Result<T>> Function() action, {required void Function(T data) onSuccess}) async {
    _isLoading = true; _error = null; notifyListeners();
    try { (await action()).when(success: onSuccess, failure: _setError); }
    catch (e) { _setError(e is AppException ? e : AppException(message: e.toString())); }
    finally { _isLoading = false; notifyListeners(); }
  }

  @protected
  Future<void> load<T>({required DataStrategy strategy, required Future<Result<T>> Function() cacheAction, required Future<Result<T>> Function() freshAction, required void Function(T data) onSuccess}) async {
    switch (strategy) {
      case DataStrategy.localFirst: await _localFirst(cacheAction: cacheAction, freshAction: freshAction, onSuccess: onSuccess);
      case DataStrategy.staleWhileRevalidate: await _swr(cacheAction: cacheAction, freshAction: freshAction, onSuccess: onSuccess);
      case DataStrategy.remoteFirst: await _remoteFirst(cacheAction: cacheAction, freshAction: freshAction, onSuccess: onSuccess);
    }
  }

  Future<void> _localFirst<T>({required Future<Result<T>> Function() cacheAction, required Future<Result<T>> Function() freshAction, required void Function(T) onSuccess}) async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      final cache = await cacheAction();
      if (cache.isSuccess) { onSuccess(cache.data); _isLoading = false; notifyListeners(); return; }
      (await freshAction()).when(success: onSuccess, failure: _setError);
    } catch (e) { _setError(e is AppException ? e : AppException(message: e.toString())); }
    finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> _swr<T>({required Future<Result<T>> Function() cacheAction, required Future<Result<T>> Function() freshAction, required void Function(T) onSuccess}) async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      final cache = await cacheAction();
      cache.when(success: (d) { onSuccess(d); _isLoading = false; _isRefreshing = true; notifyListeners(); }, failure: (_) {});
      final fresh = await freshAction();
      fresh.when(success: (d) { onSuccess(d); _error = null; }, failure: (e) { if (cache.isFailure) _setError(e); });
    } catch (e) { _setError(e is AppException ? e : AppException(message: e.toString())); }
    finally { _isLoading = false; _isRefreshing = false; notifyListeners(); }
  }

  Future<void> _remoteFirst<T>({required Future<Result<T>> Function() cacheAction, required Future<Result<T>> Function() freshAction, required void Function(T) onSuccess}) async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      final fresh = await freshAction();
      if (fresh.isSuccess) { onSuccess(fresh.data); _isLoading = false; notifyListeners(); return; }
      (await cacheAction()).when(success: onSuccess, failure: (_) => _setError(fresh.exception));
    } catch (e) { _setError(e is AppException ? e : AppException(message: e.toString())); }
    finally { _isLoading = false; notifyListeners(); }
  }
}
''';

const _servicePriority = '''
enum ServicePriority {
  low(0), normal(1), high(2), critical(3);
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
''';

const _managedService = '''
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

  Duration get idleDuration => lastActiveAt == null ? Duration.zero : DateTime.now().difference(lastActiveAt!);
  void markActive() => lastActiveAt = DateTime.now();
  void markKilled() { isKilled = true; killedAt = DateTime.now(); }
  void markRevived() { isKilled = false; killedAt = null; }
}
''';

const _memoryEvents = '''
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
''';

const _memoryManager = '''
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

  MemoryManager({required EventBus eventBus, Duration idleThreshold = const Duration(minutes: 5), Duration idleCheckInterval = const Duration(minutes: 1)})
      : _eventBus = eventBus, _idleThreshold = idleThreshold {
    WidgetsBinding.instance.addObserver(this);
    _idleCheckTimer = Timer.periodic(idleCheckInterval, (_) => _checkIdle());
  }

  MemoryPressure get currentPressure => _currentPressure;
  void register(ManagedService service) { _services[service.serviceId] = ServiceState(service: service, lastActiveAt: DateTime.now()); }
  void unregister(String id) => _services.remove(id);
  void markActive(String id) => _services[id]?.markActive();

  @override
  void didHaveMemoryPressure() => _escalate();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) _onBackground();
    if (state == AppLifecycleState.resumed) _onResume();
  }

  Future<void> setPressure(MemoryPressure p) async {
    if (p == _currentPressure) return;
    final prev = _currentPressure; _currentPressure = p;
    _eventBus.fire(MemoryPressureChangedEvent(previous: prev, current: p));
    if (p.index > prev.index) await _apply(p); else await _release(p);
  }

  Future<void> forceKill(String id) async { final s = _services[id]; if (s != null && !s.isKilled) await _kill(s); }
  Future<void> forceRevive(String id) async { final s = _services[id]; if (s != null && s.isKilled) await _revive(s); }

  Future<void> _escalate() async { final i = (_currentPressure.index + 1).clamp(0, MemoryPressure.values.length - 1); await setPressure(MemoryPressure.values[i]); }

  Future<void> _checkIdle() async {
    for (final s in _services.values.where((s) => !s.isKilled && s.service.priority == ServicePriority.low && !s.service.isActive && s.idleDuration > _idleThreshold).toList()) {
      await _kill(s);
    }
  }

  Future<void> _apply(MemoryPressure p) async {
    for (final s in _services.values.where((s) => !s.isKilled)) { try { await s.service.onMemoryWarning(); } catch (_) {} }
    for (final s in _services.values.where((s) => !s.isKilled && s.service.priority.canKillAt(p)).toList()..sort((a, b) => a.service.priority.weight.compareTo(b.service.priority.weight))) {
      await _kill(s);
    }
  }

  Future<void> _release(MemoryPressure p) async {
    for (final s in _services.values.where((s) => s.isKilled && !s.service.priority.canKillAt(p)).toList()..sort((a, b) => b.service.priority.weight.compareTo(a.service.priority.weight))) {
      await _revive(s);
    }
  }

  Future<void> _onBackground() async {
    for (final s in _services.values.where((s) => !s.isKilled && s.service.priority == ServicePriority.low && !s.service.isActive).toList()) await _kill(s);
  }

  Future<void> _onResume() async { if (_currentPressure != MemoryPressure.low) await setPressure(MemoryPressure.low); }

  Future<void> _kill(ServiceState s) async {
    if (s.isKilled) return;
    try { await s.service.onKill(); s.markKilled(); _eventBus.fire(ServiceKilledEvent(serviceId: s.service.serviceId, priority: s.service.priority, reason: _currentPressure)); } catch (_) {}
  }

  Future<void> _revive(ServiceState s) async {
    if (!s.isKilled) return;
    try { await s.service.onRevive(); s.markRevived(); _eventBus.fire(ServiceRevivedEvent(serviceId: s.service.serviceId, priority: s.service.priority)); } catch (_) {}
  }

  void dispose() { _idleCheckTimer?.cancel(); WidgetsBinding.instance.removeObserver(this); _services.clear(); }
}
''';

const _memoryAwareController = '''
import '../controller/base_controller.dart';
import 'managed_service.dart';
import 'memory_manager.dart';
import 'service_priority.dart';

abstract class MemoryAwareController extends BaseController implements ManagedService {
  final MemoryManager _memoryManager;
  final ServicePriority _priority;

  MemoryAwareController({required MemoryManager memoryManager, required ServicePriority servicePriority, super.notificationService})
      : _memoryManager = memoryManager, _priority = servicePriority { _memoryManager.register(this); }

  @override
  ServicePriority get priority => _priority;
  void markSelfActive() => _memoryManager.markActive(serviceId);

  @override
  void dispose() { _memoryManager.unregister(serviceId); super.dispose(); }
}
''';

const _notificationService = '''
import 'app_notification.dart';

abstract class NotificationService {
  void show(AppNotification notification);
}
''';

const _appNotification = '''
class AppNotification {
  final String message;
  final NotificationType type;
  final Duration duration;
  final String? actionLabel;
  final void Function()? onAction;

  const AppNotification({required this.message, this.type = NotificationType.error, this.duration = const Duration(seconds: 4), this.actionLabel, this.onAction});
  const AppNotification.error(String message, {Duration? duration}) : this(message: message, type: NotificationType.error, duration: duration ?? const Duration(seconds: 4));
  const AppNotification.success(String message, {Duration? duration}) : this(message: message, type: NotificationType.success, duration: duration ?? const Duration(seconds: 3));
  const AppNotification.warning(String message, {Duration? duration}) : this(message: message, type: NotificationType.warning, duration: duration ?? const Duration(seconds: 4));
  const AppNotification.info(String message, {Duration? duration}) : this(message: message, type: NotificationType.info, duration: duration ?? const Duration(seconds: 3));
}

enum NotificationType { error, warning, success, info }
''';

const _snackbarService = '''
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
''';

const _appTheme = '''
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();
  static ThemeData get light => ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0));
  static ThemeData get dark => ThemeData(useMaterial3: true, brightness: Brightness.dark, colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark), appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0));
}
''';

const _errorDisplay = '''
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
      Text(message, textAlign: TextAlign.center),
      if (onRetry != null) ...[const SizedBox(height: 16), ElevatedButton(onPressed: onRetry, child: const Text('Retry'))],
    ])));
  }
}
''';

const _loadingIndicator = '''
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
''';

const _appDependencies = '''
import 'package:flutter/material.dart';
import '../notification/notification_service.dart';
import '../storage/local_storage.dart';

class AppDependencies {
  final LocalStorage storage;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final NotificationService? notificationService;

  const AppDependencies({required this.storage, required this.scaffoldMessengerKey, this.notificationService});
}
''';

const _providers = '''
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../config/app_config.dart';
import '../events/event_bus.dart';
import '../memory/memory_manager.dart';
import '../network/api_client.dart';
import '../network/connectivity_checker.dart';
import '../storage/local_storage.dart';
import 'app_dependencies.dart';

List<SingleChildWidget> appProviders({required AppDependencies dependencies}) => [
  Provider<AppConfig>(create: (_) => AppConfig.fromEnvironment()),
  Provider<ConnectivityChecker>(create: (_) => ConnectivityCheckerImpl()),
  Provider<LocalStorage>(create: (_) => dependencies.storage),
  Provider<EventBus>(create: (_) => EventBusImpl(), dispose: (_, bus) => bus.dispose()),
  ProxyProvider<EventBus, MemoryManager>(update: (_, eventBus, prev) { prev?.dispose(); return MemoryManager(eventBus: eventBus); }, dispose: (_, m) => m.dispose()),
  ProxyProvider<AppConfig, ApiClient>(update: (_, config, prev) { prev?.dispose(); return ApiClient(config: config); }, dispose: (_, c) => c.dispose()),
];
''';

const _appRoutes = '''
import 'package:flutter/material.dart';

class AppRoutes {
  AppRoutes._();
  static const String home = '/';
  static Map<String, WidgetBuilder> get routes => {
    home: (_) => const Scaffold(body: Center(child: Text('Welcome to Karna MVC'))),
  };
}
''';

const _mainDart = '''
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
  final deps = AppDependencies(storage: storage, scaffoldMessengerKey: scaffoldMessengerKey, notificationService: notificationService);
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
''';

const _analysisOptions = '''
include: package:flutter_lints/flutter.yaml
''';
