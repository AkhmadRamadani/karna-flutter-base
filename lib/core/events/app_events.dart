import 'event_bus.dart';

/// Fired when app-wide cache has been cleared.
/// PostController listens to this to reload data.
class CacheClearedEvent extends AppEvent {
  const CacheClearedEvent();
}

// Memory management events are in core/memory/memory_events.dart
