import '../../../core/controller/base_controller.dart';
import '../../../core/network/data_strategy.dart';
import '../model/user_model.dart';
import '../repository/auth_repository.dart';

class AuthController extends BaseController {
  final AuthRepository _repository;

  AuthController({required AuthRepository repository})
    : _repository = repository;

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
      onSuccess: (data) => _user = data,
    );
  }

  /// Load all users (local-first only — no hybrid for lists).
  Future<void> loadAllUsers() async {
    await executeResult(
      () => _repository.getAllUsers(),
      onSuccess: (data) => _users = data,
    );
  }
}
