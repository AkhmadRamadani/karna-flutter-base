import 'package:flutter/foundation.dart';

import '../errors/app_exception.dart';
import '../network/data_strategy.dart';
import '../notification/app_notification.dart';
import '../notification/notification_service.dart';
import '../result/result.dart';

/// Base controller that provides common state management patterns.
/// Extend this to avoid repeating isLoading/error boilerplate in every controller.
///
/// Optionally accepts a [NotificationService] to automatically show
/// notifications on errors. If not provided, errors are only available
/// via [hasError] / [errorMessage] state (the view decides how to display them).
abstract class BaseController extends ChangeNotifier {
  final NotificationService? _notificationService;

  BaseController({NotificationService? notificationService})
    : _notificationService = notificationService;

  bool _isLoading = false;
  bool _isRefreshing = false;
  AppException? _error;

  bool get isLoading => _isLoading;

  /// True when fresh data is being fetched in the background
  /// (stale-while-revalidate). UI already has stale data to show.
  bool get isRefreshing => _isRefreshing;

  AppException? get error => _error;
  String? get errorMessage => _error?.message;

  /// Whether the controller has an active error state.
  bool get hasError => _error != null;

  /// Clear the current error state.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Manually push a notification (success, info, warning, or error).
  /// Only works if a [NotificationService] was provided.
  @protected
  void notify(AppNotification notification) {
    _notificationService?.show(notification);
  }

  /// Internal helper — sets error state and optionally shows a notification.
  void _setError(AppException error) {
    _error = error;
    _notificationService?.show(AppNotification.error(error.message));
  }

  /// Execute an async action with automatic loading/error state management.
  @protected
  Future<void> execute(Future<void> Function() action) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await action();
    } catch (e) {
      _setError(e is AppException ? e : AppException(message: e.toString()));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load data using a specified [DataStrategy].
  ///
  /// - [localFirst]: calls [cacheAction], falls back to [freshAction] on miss.
  /// - [staleWhileRevalidate]: calls [cacheAction] for instant UI, then
  ///   [freshAction] to replace with fresh data.
  /// - [remoteFirst]: calls [freshAction] directly, falls back to [cacheAction] on failure.
  @protected
  Future<void> load<T>({
    required DataStrategy strategy,
    required Future<Result<T>> Function() cacheAction,
    required Future<Result<T>> Function() freshAction,
    required void Function(T data) onSuccess,
  }) async {
    switch (strategy) {
      case DataStrategy.localFirst:
        await _loadLocalFirst(
          cacheAction: cacheAction,
          freshAction: freshAction,
          onSuccess: onSuccess,
        );
      case DataStrategy.staleWhileRevalidate:
        await _loadStaleWhileRevalidate(
          cacheAction: cacheAction,
          freshAction: freshAction,
          onSuccess: onSuccess,
        );
      case DataStrategy.remoteFirst:
        await _loadRemoteFirst(
          cacheAction: cacheAction,
          freshAction: freshAction,
          onSuccess: onSuccess,
        );
    }
  }

  /// Shorthand for loading with a single Result action (no strategy needed).
  @protected
  Future<void> executeResult<T>(
    Future<Result<T>> Function() action, {
    required void Function(T data) onSuccess,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await action();
      result.when(
        success: (data) => onSuccess(data),
        failure: (error) => _setError(error),
      );
    } catch (e) {
      _setError(e is AppException ? e : AppException(message: e.toString()));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Private strategy implementations ───────────────────────────────

  Future<void> _loadLocalFirst<T>({
    required Future<Result<T>> Function() cacheAction,
    required Future<Result<T>> Function() freshAction,
    required void Function(T data) onSuccess,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try cache first
      final cacheResult = await cacheAction();
      if (cacheResult.isSuccess) {
        onSuccess(cacheResult.data);
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Cache miss — try remote
      final freshResult = await freshAction();
      freshResult.when(
        success: (data) => onSuccess(data),
        failure: (error) => _setError(error),
      );
    } catch (e) {
      _setError(e is AppException ? e : AppException(message: e.toString()));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadStaleWhileRevalidate<T>({
    required Future<Result<T>> Function() cacheAction,
    required Future<Result<T>> Function() freshAction,
    required void Function(T data) onSuccess,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Phase 1: Try cache for instant UI
      final cacheResult = await cacheAction();
      cacheResult.when(
        success: (data) {
          onSuccess(data);
          _isLoading = false;
          _isRefreshing = true;
          notifyListeners();
        },
        failure: (_) {
          // No cache — keep isLoading true, wait for network
        },
      );

      // Phase 2: Fetch fresh data
      final freshResult = await freshAction();
      freshResult.when(
        success: (data) {
          onSuccess(data);
          _error = null;
        },
        failure: (error) {
          // Only set error if we had no cache data
          if (cacheResult.isFailure) {
            _setError(error);
          }
        },
      );
    } catch (e) {
      _setError(e is AppException ? e : AppException(message: e.toString()));
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> _loadRemoteFirst<T>({
    required Future<Result<T>> Function() cacheAction,
    required Future<Result<T>> Function() freshAction,
    required void Function(T data) onSuccess,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try remote first
      final freshResult = await freshAction();
      if (freshResult.isSuccess) {
        onSuccess(freshResult.data);
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Remote failed — fall back to cache
      final cacheResult = await cacheAction();
      cacheResult.when(
        success: (data) => onSuccess(data),
        failure: (_) => _setError(freshResult.exception),
      );
    } catch (e) {
      _setError(e is AppException ? e : AppException(message: e.toString()));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
