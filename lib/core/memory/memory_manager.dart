import 'dart:async';

import 'package:flutter/widgets.dart';

import '../events/event_bus.dart';
import 'managed_service.dart';
import 'memory_events.dart';
import 'service_priority.dart';

/// Manages app memory by monitoring system memory pressure and controlling
/// service lifecycles based on their priority.
///
/// Services register themselves with a [ServicePriority]:
/// - [ServicePriority.critical] — Never killed (auth, storage, navigation)
/// - [ServicePriority.high] — Only killed when device is out of memory
/// - [ServicePriority.normal] — Killed under moderate pressure
/// - [ServicePriority.low] — Auto-killed when idle
///
/// The manager listens to Flutter's [WidgetsBindingObserver] for system
/// memory warnings and also runs a periodic idle check for low-priority
/// services.
///
/// Usage:
/// ```dart
/// final memoryManager = MemoryManager(eventBus: eventBus);
/// memoryManager.register(imageCacheService);
/// memoryManager.register(analyticsService);
/// ```
class MemoryManager with WidgetsBindingObserver {
  final EventBus _eventBus;
  final Map<String, ServiceState> _services = {};
  final Duration _idleThreshold;
  Timer? _idleCheckTimer;
  MemoryPressure _currentPressure = MemoryPressure.low;

  /// Creates a memory manager.
  ///
  /// [idleThreshold] — how long a low-priority service can be idle before
  /// being auto-killed. Defaults to 5 minutes.
  ///
  /// [idleCheckInterval] — how often to check for idle services.
  /// Defaults to 1 minute.
  MemoryManager({
    required EventBus eventBus,
    Duration idleThreshold = const Duration(minutes: 5),
    Duration idleCheckInterval = const Duration(minutes: 1),
  }) : _eventBus = eventBus,
       _idleThreshold = idleThreshold {
    WidgetsBinding.instance.addObserver(this);
    _startIdleCheck(idleCheckInterval);
  }

  /// Current memory pressure level.
  MemoryPressure get currentPressure => _currentPressure;

  /// All registered services and their states.
  Map<String, ServiceState> get services => Map.unmodifiable(_services);

  /// Number of currently alive (not killed) services.
  int get aliveCount => _services.values.where((s) => !s.isKilled).length;

  /// Number of currently killed services.
  int get killedCount => _services.values.where((s) => s.isKilled).length;

  // ─── Registration ─────────────────────────────────────────────────

  /// Register a service for memory management.
  void register(ManagedService service) {
    _services[service.serviceId] = ServiceState(
      service: service,
      lastActiveAt: DateTime.now(),
    );
    debugPrint(
      '[MemoryManager] Registered: ${service.serviceId} '
      '(priority: ${service.priority.name})',
    );
  }

  /// Unregister a service (e.g. when it's permanently disposed).
  void unregister(String serviceId) {
    _services.remove(serviceId);
    debugPrint('[MemoryManager] Unregistered: $serviceId');
  }

  /// Mark a service as currently active (resets idle timer).
  void markActive(String serviceId) {
    _services[serviceId]?.markActive();
  }

  // ─── System Memory Callbacks ──────────────────────────────────────

  /// Called by the system when memory is low.
  @override
  void didHaveMemoryPressure() {
    debugPrint('[MemoryManager] System memory pressure received');
    _escalatePressure();
  }

  /// Called when app lifecycle changes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App going to background — be more aggressive
        _handleBackgrounded();
      case AppLifecycleState.resumed:
        // App coming back — revive killed services if pressure is low
        _handleResumed();
      default:
        break;
    }
  }

  // ─── Manual Controls ──────────────────────────────────────────────

  /// Manually set memory pressure level (useful for testing or
  /// responding to custom memory metrics).
  Future<void> setPressure(MemoryPressure pressure) async {
    if (pressure == _currentPressure) return;

    final previous = _currentPressure;
    _currentPressure = pressure;

    _eventBus.fire(
      MemoryPressureChangedEvent(previous: previous, current: pressure),
    );

    if (pressure.index > previous.index) {
      await _applyPressure(pressure);
    } else {
      await _releasePressure(pressure);
    }
  }

  /// Force kill a specific service regardless of priority.
  Future<void> forceKill(String serviceId) async {
    final state = _services[serviceId];
    if (state == null || state.isKilled) return;

    await _killService(state);
  }

  /// Force revive a specific service.
  Future<void> forceRevive(String serviceId) async {
    final state = _services[serviceId];
    if (state == null || !state.isKilled) return;

    await _reviveService(state);
  }

  /// Get a snapshot of all service states for debugging/monitoring.
  List<ServiceSnapshot> getSnapshot() {
    return _services.values.map((state) {
      return ServiceSnapshot(
        serviceId: state.service.serviceId,
        priority: state.service.priority,
        isActive: state.service.isActive,
        isKilled: state.isKilled,
        idleDuration: state.idleDuration,
        killedAt: state.killedAt,
      );
    }).toList()..sort((a, b) => a.priority.weight.compareTo(b.priority.weight));
  }

  // ─── Private Implementation ───────────────────────────────────────

  void _startIdleCheck(Duration interval) {
    _idleCheckTimer = Timer.periodic(interval, (_) => _checkIdleServices());
  }

  /// Auto-kill low-priority services that have been idle too long.
  Future<void> _checkIdleServices() async {
    final idleServices = _services.values.where((state) {
      return !state.isKilled &&
          state.service.priority == ServicePriority.low &&
          !state.service.isActive &&
          state.idleDuration > _idleThreshold;
    }).toList();

    for (final state in idleServices) {
      debugPrint(
        '[MemoryManager] Auto-killing idle service: ${state.service.serviceId} '
        '(idle for ${state.idleDuration.inMinutes}m)',
      );
      await _killService(state);
    }
  }

  /// Escalate pressure one level up from current.
  Future<void> _escalatePressure() async {
    final nextIndex = (_currentPressure.index + 1).clamp(
      0,
      MemoryPressure.values.length - 1,
    );
    final next = MemoryPressure.values[nextIndex];
    await setPressure(next);
  }

  /// Apply memory pressure — warn and kill services as needed.
  Future<void> _applyPressure(MemoryPressure pressure) async {
    debugPrint('[MemoryManager] Applying pressure: ${pressure.name}');

    // First, warn all alive services
    final aliveServices = _services.values.where((s) => !s.isKilled).toList();
    for (final state in aliveServices) {
      try {
        await state.service.onMemoryWarning();
      } catch (e) {
        debugPrint(
          '[MemoryManager] Warning failed for ${state.service.serviceId}: $e',
        );
      }
    }

    // Then kill services that can be killed at this pressure level.
    // Sort by priority (lowest first), then by idle time (longest idle first).
    final killable =
        aliveServices.where((state) {
          return state.service.priority.canKillAt(pressure);
        }).toList()..sort((a, b) {
          final priorityCompare = a.service.priority.weight.compareTo(
            b.service.priority.weight,
          );
          if (priorityCompare != 0) return priorityCompare;
          // Within same priority, kill inactive ones first
          if (a.service.isActive && !b.service.isActive) return 1;
          if (!a.service.isActive && b.service.isActive) return -1;
          // Then by idle duration (longest idle first)
          return b.idleDuration.compareTo(a.idleDuration);
        });

    for (final state in killable) {
      await _killService(state);
    }
  }

  /// Release pressure — revive services that can run at the new level.
  Future<void> _releasePressure(MemoryPressure pressure) async {
    debugPrint('[MemoryManager] Releasing pressure to: ${pressure.name}');

    // Revive services that shouldn't be killed at the new (lower) pressure.
    // Revive highest priority first.
    final revivable =
        _services.values.where((state) {
          return state.isKilled && !state.service.priority.canKillAt(pressure);
        }).toList()..sort(
          (a, b) =>
              b.service.priority.weight.compareTo(a.service.priority.weight),
        );

    for (final state in revivable) {
      await _reviveService(state);
    }
  }

  /// Handle app going to background.
  Future<void> _handleBackgrounded() async {
    debugPrint('[MemoryManager] App backgrounded — trimming low-priority');
    // Kill all low-priority inactive services immediately when backgrounded
    final lowPriority = _services.values.where((state) {
      return !state.isKilled &&
          state.service.priority == ServicePriority.low &&
          !state.service.isActive;
    }).toList();

    for (final state in lowPriority) {
      await _killService(state);
    }
  }

  /// Handle app coming back to foreground.
  Future<void> _handleResumed() async {
    debugPrint('[MemoryManager] App resumed — checking for revivals');
    // Reset pressure to low when coming back (system will re-notify if needed)
    if (_currentPressure != MemoryPressure.low) {
      await setPressure(MemoryPressure.low);
    }
  }

  Future<void> _killService(ServiceState state) async {
    if (state.isKilled) return;

    try {
      await state.service.onKill();
      state.markKilled();
      _eventBus.fire(
        ServiceKilledEvent(
          serviceId: state.service.serviceId,
          priority: state.service.priority,
          reason: _currentPressure,
        ),
      );
      debugPrint(
        '[MemoryManager] Killed: ${state.service.serviceId} '
        '(pressure: ${_currentPressure.name})',
      );
    } catch (e) {
      debugPrint(
        '[MemoryManager] Kill failed for ${state.service.serviceId}: $e',
      );
    }
  }

  Future<void> _reviveService(ServiceState state) async {
    if (!state.isKilled) return;

    try {
      await state.service.onRevive();
      state.markRevived();
      _eventBus.fire(
        ServiceRevivedEvent(
          serviceId: state.service.serviceId,
          priority: state.service.priority,
        ),
      );
      debugPrint('[MemoryManager] Revived: ${state.service.serviceId}');
    } catch (e) {
      debugPrint(
        '[MemoryManager] Revive failed for ${state.service.serviceId}: $e',
      );
    }
  }

  /// Dispose the memory manager. Call this when the app is shutting down.
  void dispose() {
    _idleCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _services.clear();
  }
}

/// Immutable snapshot of a service's state for monitoring/debugging.
class ServiceSnapshot {
  final String serviceId;
  final ServicePriority priority;
  final bool isActive;
  final bool isKilled;
  final Duration idleDuration;
  final DateTime? killedAt;

  const ServiceSnapshot({
    required this.serviceId,
    required this.priority,
    required this.isActive,
    required this.isKilled,
    required this.idleDuration,
    this.killedAt,
  });

  @override
  String toString() {
    final status = isKilled ? 'KILLED' : (isActive ? 'ACTIVE' : 'IDLE');
    return '[$status] $serviceId (${priority.name}) '
        'idle: ${idleDuration.inSeconds}s';
  }
}
