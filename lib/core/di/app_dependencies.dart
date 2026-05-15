import 'package:flutter/material.dart';

import '../notification/notification_service.dart';
import '../storage/local_storage.dart';

/// Bundles all app-level dependencies initialized in main().
/// Passed as a single object into KarnaApp and the DI layer.
class AppDependencies {
  final LocalStorage storage;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final NotificationService? notificationService;

  const AppDependencies({
    required this.storage,
    required this.scaffoldMessengerKey,
    this.notificationService,
  });
}
