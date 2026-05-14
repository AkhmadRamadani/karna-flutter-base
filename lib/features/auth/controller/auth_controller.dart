import '../../../core/controller/base_controller.dart';
import '../../../core/events/app_events.dart';
import '../../../core/events/event_bus.dart';
import '../../../core/network/data_strategy.dart';
import '../model/user_model.dart';
import '../repository/auth_repository.dart';

class AuthController extends BaseController {
  final AuthRepository _repository;
  final EventBus _eventBus;

  AuthController({
    required AuthRepository repository,
    required EventBus eventBus,
  }) : _repository = repository,
       _eventBus = eventBus;

  UserModel? _user;
  List<UserModel> _users = [];

  UserModel? get user => _user;
  List<UserModel> get users => _users;

  /// Load user with the specified data strategy.
  ///
  /// Examples:
  ///   loadUser('1')                                      → local-first (default)
  ///   loadUser('1', strategy: DataStrategy.remoteFirst)  → always hit network
  ///   loadUser('1', strategy: DataStrategy.staleWhileRevalidate) → cache + refresh
  Future<void> loadUser(
    String id, {
    DataStrategy strategy = DataStrategy.localFirst,
  }) async {
    await load(
      strategy: strategy,
      cacheAction: () => _repository.getUserFromCache(id),
      freshAction: () => _repository.getUserFromRemote(id),
      onSuccess: (data) {
        _user = data;
        // Notify other features that a user has logged in
        _eventBus.fire(UserLoggedInEvent(userId: data.id));
      },
    );
  }

  /// Log out the current user and notify the app.
  Future<void> logout() async {
    _user = null;
    _eventBus.fire(const UserLoggedOutEvent());
    notifyListeners();
  }

  /// Load all users (local-first only — no hybrid for lists).
  Future<void> loadAllUsers() async {
    await executeResult(
      () => _repository.getAllUsers(),
      onSuccess: (data) => _users = data,
    );
  }
}
