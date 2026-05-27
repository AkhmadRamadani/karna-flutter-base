import '../events/event_bus.dart';
import 'service_priority.dart';

/// Fired when the memory pressure level changes.
class MemoryPressureChangedEvent extends AppEvent {
  final MemoryPressure previous;
  final MemoryPressure current;

  const MemoryPressureChangedEvent({
    required this.previous,
    required this.current,
  });
}

/// Fired when a service is killed by the memory manager.
class ServiceKilledEvent extends AppEvent {
  final String serviceId;
  final ServicePriority priority;
  final MemoryPressure reason;

  const ServiceKilledEvent({
    required this.serviceId,
    required this.priority,
    required this.reason,
  });
}

/// Fired when a previously killed service is revived.
class ServiceRevivedEvent extends AppEvent {
  final String serviceId;
  final ServicePriority priority;

  const ServiceRevivedEvent({required this.serviceId, required this.priority});
}
