import '../controller/base_controller.dart';
import 'managed_service.dart';
import 'memory_manager.dart';
import 'service_priority.dart';

/// A [BaseController] that automatically participates in memory management.
///
/// Extend this instead of [BaseController] when your controller should be
/// managed by the [MemoryManager]. Override [priority] to set the kill order.
///
/// Example:
/// ```dart
/// class FeedController extends MemoryAwareController {
///   FeedController({
///     required MemoryManager memoryManager,
///     required FeedRepository repository,
///   }) : _repository = repository,
///        super(
///          memoryManager: memoryManager,
///          servicePriority: ServicePriority.normal,
///        );
///
///   List<FeedItem> _items = [];
///
///   @override
///   String get serviceId => 'feed_controller';
///
///   @override
///   bool get isActive => _items.isNotEmpty;
///
///   @override
///   Future<void> onMemoryWarning() async {
///     // Trim to latest 20 items
///     if (_items.length > 20) {
///       _items = _items.sublist(0, 20);
///       notifyListeners();
///     }
///   }
///
///   @override
///   Future<void> onKill() async {
///     _items.clear();
///     notifyListeners();
///   }
///
///   @override
///   Future<void> onRevive() async {
///     await loadFeed();
///   }
/// }
/// ```
abstract class MemoryAwareController extends BaseController
    implements ManagedService {
  final MemoryManager _memoryManager;
  final ServicePriority _priority;

  MemoryAwareController({
    required MemoryManager memoryManager,
    required ServicePriority servicePriority,
    super.notificationService,
  }) : _memoryManager = memoryManager,
       _priority = servicePriority {
    _memoryManager.register(this);
  }

  @override
  ServicePriority get priority => _priority;

  /// Notify the memory manager that this controller is actively being used.
  /// Call this in methods that indicate user interaction.
  void markSelfActive() {
    _memoryManager.markActive(serviceId);
  }

  @override
  void dispose() {
    _memoryManager.unregister(serviceId);
    super.dispose();
  }
}
