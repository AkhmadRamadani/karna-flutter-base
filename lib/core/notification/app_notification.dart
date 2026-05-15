/// Represents an app-wide notification to display to the user.
///
/// Used by [NotificationService] to show errors, warnings, successes, or info
/// messages. Controllers push these; the service decides how to display them.
class AppNotification {
  final String message;
  final NotificationType type;
  final Duration duration;
  final String? actionLabel;
  final void Function()? onAction;

  const AppNotification({
    required this.message,
    this.type = NotificationType.error,
    this.duration = const Duration(seconds: 4),
    this.actionLabel,
    this.onAction,
  });

  /// Convenience constructors for common notification types.
  const AppNotification.error(String message, {Duration? duration})
    : this(
        message: message,
        type: NotificationType.error,
        duration: duration ?? const Duration(seconds: 4),
      );

  const AppNotification.success(String message, {Duration? duration})
    : this(
        message: message,
        type: NotificationType.success,
        duration: duration ?? const Duration(seconds: 3),
      );

  const AppNotification.warning(String message, {Duration? duration})
    : this(
        message: message,
        type: NotificationType.warning,
        duration: duration ?? const Duration(seconds: 4),
      );

  const AppNotification.info(String message, {Duration? duration})
    : this(
        message: message,
        type: NotificationType.info,
        duration: duration ?? const Duration(seconds: 3),
      );
}

enum NotificationType { error, warning, success, info }
