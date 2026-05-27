/// Priority levels for managed services.
///
/// Determines the order in which services are killed when memory is low.
/// Lower priority services are killed first.
///
/// | Priority    | Behavior                                              |
/// |-------------|-------------------------------------------------------|
/// | critical    | Never killed — essential for app to function           |
/// | high        | Only killed when phone is completely out of memory     |
/// | normal      | Killed under moderate memory pressure                  |
/// | low         | Auto-killed when idle or on light memory pressure      |
enum ServicePriority {
  /// Auto-kill when idle. First to be reclaimed.
  /// Use for: prefetch caches, analytics batchers, background sync.
  low(0),

  /// Killed under moderate memory pressure.
  /// Use for: non-visible feature controllers, image caches.
  normal(1),

  /// Only killed when the device is critically low on memory.
  /// Use for: active/visible feature controllers, real-time connections.
  high(2),

  /// Never killed by the memory manager.
  /// Use for: auth state, navigation, core networking, storage.
  critical(3);

  final int weight;
  const ServicePriority(this.weight);

  /// Whether this priority level can be killed at the given pressure.
  bool canKillAt(MemoryPressure pressure) {
    switch (pressure) {
      case MemoryPressure.low:
        return this == ServicePriority.low;
      case MemoryPressure.moderate:
        return weight <= ServicePriority.normal.weight;
      case MemoryPressure.high:
        return weight <= ServicePriority.high.weight;
      case MemoryPressure.critical:
        // Even critical pressure doesn't kill critical services
        return this != ServicePriority.critical;
    }
  }
}

/// Represents the current memory pressure level of the device.
enum MemoryPressure {
  /// Normal operation — no services need to be killed.
  low,

  /// Moderate pressure — kill idle/low-priority services.
  moderate,

  /// High pressure — kill normal-priority services too.
  high,

  /// Critical — device is nearly out of memory. Kill everything except critical.
  critical,
}
