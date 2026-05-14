import 'dart:async';

import '../../../core/controller/base_controller.dart';
import '../../../core/events/app_events.dart';
import '../../../core/events/event_bus.dart';
import '../../../core/network/data_strategy.dart';
import '../model/profile_model.dart';
import '../repository/profile_repository.dart';

class ProfileController extends BaseController {
  final ProfileRepository _repository;
  final EventBus _eventBus;

  late final StreamSubscription<UserLoggedOutEvent> _logoutSub;
  late final StreamSubscription<UserLoggedInEvent> _loginSub;

  ProfileController({
    required ProfileRepository repository,
    required EventBus eventBus,
  }) : _repository = repository,
       _eventBus = eventBus {
    // React to auth events from another feature — no direct import needed
    _logoutSub = _eventBus.on<UserLoggedOutEvent>().listen((_) {
      _clearProfile();
    });
    _loginSub = _eventBus.on<UserLoggedInEvent>().listen((event) {
      loadProfile(event.userId, strategy: DataStrategy.remoteFirst);
    });
  }

  ProfileModel? _profile;

  ProfileModel? get profile => _profile;

  /// Load profile with the specified data strategy.
  ///
  /// Examples:
  ///   loadProfile('1')                                              → local-first
  ///   loadProfile('1', strategy: DataStrategy.staleWhileRevalidate) → cache + refresh
  ///   loadProfile('1', strategy: DataStrategy.remoteFirst)          → always network
  Future<void> loadProfile(
    String id, {
    DataStrategy strategy = DataStrategy.localFirst,
  }) async {
    await load(
      strategy: strategy,
      cacheAction: () => _repository.getProfileFromCache(id),
      freshAction: () => _repository.getProfileFromRemote(id),
      onSuccess: (data) => _profile = data,
    );
  }

  /// Update profile (always remote-first).
  Future<void> updateProfile(ProfileModel profile) async {
    await executeResult(
      () => _repository.updateProfile(profile),
      onSuccess: (_) {
        _profile = profile;
        // Notify other features that profile data changed
        _eventBus.fire(UserProfileUpdatedEvent(userId: profile.id));
      },
    );
  }

  void _clearProfile() {
    _profile = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _logoutSub.cancel();
    _loginSub.cancel();
    super.dispose();
  }
}
