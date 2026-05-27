import '../../../core/memory/memory_aware_controller.dart';
import '../../../core/memory/service_priority.dart';
import '../../../core/network/data_strategy.dart';
import '../model/feed_model.dart';
import '../repository/feed_repository.dart';

/// Feed controller that participates in memory management.
///
/// Priority: [ServicePriority.normal] — killed under moderate memory pressure.
///
/// Memory behavior:
/// - [onMemoryWarning]: trims feed list to the latest 20 items.
/// - [onKill]: clears all feed data from memory.
/// - [onRevive]: reloads feed from cache/network.
///
/// Call [markSelfActive] when the user scrolls or interacts with the feed
/// to prevent the memory manager from killing it while in use.
class FeedController extends MemoryAwareController {
  final FeedRepository _repository;

  FeedController({
    required super.memoryManager,
    required FeedRepository repository,
    super.notificationService,
  }) : _repository = repository,
       super(servicePriority: ServicePriority.normal);

  FeedModel? _feed;
  List<FeedModel> _feedList = [];

  /// Maximum items to keep in memory under normal conditions.
  static const _maxItems = 100;

  /// Items to keep when memory warning is received.
  static const _trimmedItems = 20;

  FeedModel? get feed => _feed;
  List<FeedModel> get feedList => _feedList;

  // ─── ManagedService implementation ────────────────────────────────

  @override
  String get serviceId => 'feed_controller';

  @override
  bool get isActive => _feedList.isNotEmpty;

  @override
  Future<void> onMemoryWarning() async {
    // Trim to most recent items to reduce memory footprint
    if (_feedList.length > _trimmedItems) {
      _feedList = _feedList.sublist(0, _trimmedItems);
      notifyListeners();
    }
  }

  @override
  Future<void> onKill() async {
    _feed = null;
    _feedList = [];
    notifyListeners();
  }

  @override
  Future<void> onRevive() async {
    await loadAll(strategy: DataStrategy.localFirst);
  }

  // ─── Data loading ─────────────────────────────────────────────────

  /// Load a single feed item by ID.
  Future<void> loadById(
    String id, {
    DataStrategy strategy = DataStrategy.localFirst,
  }) async {
    markSelfActive();
    await load(
      strategy: strategy,
      cacheAction: () => _repository.getFromCache(id),
      freshAction: () => _repository.getFromRemote(id),
      onSuccess: (data) => _feed = data,
    );
  }

  /// Load the full feed list.
  ///
  /// Uses stale-while-revalidate by default — shows cached feed instantly,
  /// then refreshes from network in the background.
  Future<void> loadAll({
    DataStrategy strategy = DataStrategy.staleWhileRevalidate,
  }) async {
    markSelfActive();
    await executeResult(
      () => _repository.getAll(),
      onSuccess: (data) {
        _feedList = data.length > _maxItems ? data.sublist(0, _maxItems) : data;
      },
    );
  }

  /// Called when user scrolls the feed — keeps the controller alive.
  void onUserScroll() {
    markSelfActive();
  }
}
