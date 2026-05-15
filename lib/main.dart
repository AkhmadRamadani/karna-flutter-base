import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/di/app_dependencies.dart';
import 'core/di/providers.dart';
import 'core/notification/snackbar_notification_service.dart';
import 'core/routes/app_routes.dart';
import 'core/storage/hive_storage.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage
  await Hive.initFlutter();
  final box = await Hive.openBox<String>('app_storage');
  final storage = HiveStorage(box: box);

  // Create scaffold messenger key for SnackBar notifications
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  // Default notification service — replace with your own or set to null
  final notificationService = SnackBarNotificationService(
    messengerKey: scaffoldMessengerKey,
  );

  // Bundle all dependencies
  final deps = AppDependencies(
    storage: storage,
    scaffoldMessengerKey: scaffoldMessengerKey,
    notificationService: notificationService,
  );

  runApp(KarnaApp(dependencies: deps));
}

class KarnaApp extends StatelessWidget {
  final AppDependencies dependencies;

  const KarnaApp({super.key, required this.dependencies});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: appProviders(dependencies: dependencies),
      child: MaterialApp(
        title: 'Karna MVC',
        scaffoldMessengerKey: dependencies.scaffoldMessengerKey,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routes: AppRoutes.routes,
        initialRoute: AppRoutes.posts,
      ),
    );
  }
}
