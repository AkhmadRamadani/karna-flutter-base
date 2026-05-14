import 'event_bus.dart';

/// Fired when a user successfully logs in.
class UserLoggedInEvent extends AppEvent {
  final String userId;
  const UserLoggedInEvent({required this.userId});
}

/// Fired when a user logs out (locally or via session expiry).
class UserLoggedOutEvent extends AppEvent {
  const UserLoggedOutEvent();
}

/// Fired when the user's session token has expired.
/// Controllers can listen to this to redirect to login.
class SessionExpiredEvent extends AppEvent {
  const SessionExpiredEvent();
}

/// Fired when user profile data has been updated.
/// Other features displaying user info can refresh.
class UserProfileUpdatedEvent extends AppEvent {
  final String userId;
  const UserProfileUpdatedEvent({required this.userId});
}

/// Fired when connectivity status changes.
class ConnectivityChangedEvent extends AppEvent {
  final bool isConnected;
  const ConnectivityChangedEvent({required this.isConnected});
}

/// Fired when app-wide cache has been cleared.
class CacheClearedEvent extends AppEvent {
  const CacheClearedEvent();
}
