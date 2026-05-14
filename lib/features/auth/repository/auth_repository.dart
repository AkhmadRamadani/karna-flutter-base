import '../../../core/result/result.dart';
import '../model/user_model.dart';

abstract class AuthRepository {
  /// Get user using the configured data strategy (local-first by default).
  Future<Result<UserModel>> getUserById(String id);

  /// Get all users using the configured data strategy.
  Future<Result<List<UserModel>>> getAllUsers();

  /// Get user from local cache only. Returns Failure if not cached.
  Future<Result<UserModel>> getUserFromCache(String id);

  /// Get user from remote only. Always hits network and updates cache.
  Future<Result<UserModel>> getUserFromRemote(String id);
}
