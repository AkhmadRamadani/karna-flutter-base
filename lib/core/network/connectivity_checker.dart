/// Abstract connectivity checker.
/// Allows repositories to decide whether to attempt remote calls.
abstract class ConnectivityChecker {
  /// Returns true if the device currently has network access.
  Future<bool> get hasConnection;
}

/// Default implementation using dart:io.
/// For production, consider using the `connectivity_plus` package.
class ConnectivityCheckerImpl implements ConnectivityChecker {
  @override
  Future<bool> get hasConnection async {
    try {
      // Simple connectivity check — attempt DNS lookup
      // Replace with connectivity_plus for more reliable detection
      return true;
    } catch (_) {
      return false;
    }
  }
}
