import 'dart:async';

/// A typed, app-wide event bus for cross-feature communication.
///
/// Features never import each other — but sometimes Feature A needs to react
/// when something happens in Feature B (e.g. user logs out → clear profile cache).
/// The event bus solves this without coupling features together.
///
/// Usage:
/// ```dart
/// // Publishing (in a controller or repository):
/// eventBus.fire(CacheClearedEvent());
///
/// // Subscribing (in a controller's constructor or init):
/// _subscription = eventBus.on<CacheClearedEvent>().listen((_) {
///   reloadData();
/// });
/// ```
abstract class EventBus {
  /// Listen to events of a specific type [T].
  Stream<T> on<T extends AppEvent>();

  /// Fire an event to all listeners of that event type.
  void fire(AppEvent event);

  /// Dispose the event bus and close the underlying stream.
  void dispose();
}

/// Base class for all app-wide events.
/// Extend this to create typed events.
abstract class AppEvent {
  const AppEvent();
}

/// Stream-based implementation of [EventBus].
///
/// Uses a broadcast [StreamController] so multiple listeners can subscribe
/// to the same event type independently.
class EventBusImpl implements EventBus {
  final StreamController<AppEvent> _controller =
      StreamController<AppEvent>.broadcast();

  @override
  Stream<T> on<T extends AppEvent>() {
    return _controller.stream.where((event) => event is T).cast<T>();
  }

  @override
  void fire(AppEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  @override
  void dispose() {
    _controller.close();
  }
}
