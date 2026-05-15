import 'package:flutter/material.dart';

import 'app_notification.dart';
import 'notification_service.dart';

/// Default [NotificationService] implementation using Material SnackBar.
///
/// Requires a [GlobalKey<ScaffoldMessengerState>] to show snackbars from
/// anywhere in the app without needing a BuildContext.
///
/// Setup in main.dart:
/// ```dart
/// final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
///
/// MaterialApp(
///   scaffoldMessengerKey: scaffoldMessengerKey,
///   ...
/// );
///
/// // Pass to providers:
/// final notificationService = SnackBarNotificationService(
///   messengerKey: scaffoldMessengerKey,
/// );
/// ```
class SnackBarNotificationService implements NotificationService {
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  SnackBarNotificationService({required this.messengerKey});

  @override
  void show(AppNotification notification) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(_iconFor(notification.type), color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                notification.message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: _colorFor(notification.type),
        duration: notification.duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: notification.actionLabel != null
            ? SnackBarAction(
                label: notification.actionLabel!,
                textColor: Colors.white,
                onPressed: notification.onAction ?? () {},
              )
            : null,
      ),
    );
  }

  Color _colorFor(NotificationType type) {
    switch (type) {
      case NotificationType.error:
        return const Color(0xFFD32F2F);
      case NotificationType.warning:
        return const Color(0xFFF57C00);
      case NotificationType.success:
        return const Color(0xFF388E3C);
      case NotificationType.info:
        return const Color(0xFF1976D2);
    }
  }

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.warning:
        return Icons.warning_amber_outlined;
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.info:
        return Icons.info_outline;
    }
  }
}
