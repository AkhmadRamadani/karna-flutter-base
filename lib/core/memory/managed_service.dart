import 'service_priority.dart';

/// Interface for services that participate in memory management.
///
/// Any service that wants to be managed by [MemoryManager] should implement
/// this interface. The memory manager will call lifecycle methods based on
/// the service's priority and current memory pressure.
///
/// Example:
/// ```dart
/// class ImageCacheService implements ManagedService {
///   @override
///   String get serviceId => 'image_cache';
///
///   @override
///   ServicePriority get priority => ServicePriority.low;
///
///   @override
///   bool get isActive => _cache.isNotEmpty;
///
///   @override
///   Future<void> onMemoryWarning() async {
///     // Trim cache to 50%
///     _cache.trimToSize(_cache.size ~/ 2);
///   }
///
///   @override
///   Future<void> onKill() async {
///     _cache.clear();
///   }
///
///   @override
///   Future<void> onRevive() async {
///     // Re-initialize if needed when memory is available again
///   }
/// }
/// ```
abstract class ManagedService {
  /// Unique identifier for this service.
  String get serviceId;

  /// The priority level of this service.
  /// Determines when it gets killed under memory pressure.
  ServicePriority get priority;

  /// Whether this service is currently active/in-use.
  /// Active services within the same priority tier are killed last.
  bool get isActive;

  /// Called when memory pressure increases but before killing.
  /// Services should reduce their memory footprint (trim caches, release
  /// buffers) without fully shutting down.
  Future<void> onMemoryWarning();

  /// Called when the memory manager decides to kill this service.
  /// Release all resources, clear caches, cancel subscriptions.
  /// The service should be in a state where it can be revived later.
  Future<void> onKill();

  /// Called when memory pressure decreases and the service can restart.
  /// Re-initialize resources that were released in [onKill].
  Future<void> onRevive();
}

/// Tracks the runtime state of a managed service.
class ServiceState {
  final ManagedService service;
  bool isKilled;
  DateTime? lastActiveAt;
  DateTime? killedAt;

  ServiceState({
    required this.service,
    this.isKilled = false,
    this.lastActiveAt,
    this.killedAt,
  });

  /// How long the service has been idle (not active).
  Duration get idleDuration {
    if (lastActiveAt == null) return Duration.zero;
    return DateTime.now().difference(lastActiveAt!);
  }

  /// Mark the service as active now.
  void markActive() {
    lastActiveAt = DateTime.now();
  }

  /// Mark the service as killed.
  void markKilled() {
    isKilled = true;
    killedAt = DateTime.now();
  }

  /// Mark the service as revived.
  void markRevived() {
    isKilled = false;
    killedAt = null;
  }
}
