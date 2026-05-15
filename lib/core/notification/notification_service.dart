import 'app_notification.dart';

/// Abstract notification service.
///
/// Controllers call [show] to push a notification. The implementation decides
/// how to display it (SnackBar, toast, dialog, etc.).
///
/// If no service is injected into a controller, errors remain as state only
/// (the current `hasError` / `errorMessage` pattern still works).
///
/// Usage in a controller:
/// ```dart
/// class MyController extends BaseController {
///   MyController({NotificationService? notificationService})
///       : super(notificationService: notificationService);
///
///   // Errors will automatically show notifications if service is provided.
///   // Or manually:
///   void doSomething() {
///     notify(AppNotification.success('Item saved!'));
///   }
/// }
/// ```
abstract class NotificationService {
  /// Show a notification to the user.
  void show(AppNotification notification);
}
