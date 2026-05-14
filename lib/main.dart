import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/di/providers.dart';
import 'core/routes/app_routes.dart';
import 'core/storage/hive_storage.dart';
import 'core/storage/local_storage.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive before building providers
  await Hive.initFlutter();
  final box = await Hive.openBox<String>('app_storage');
  final storage = HiveStorage(box: box);

  runApp(KarnaApp(storage: storage));
}

class KarnaApp extends StatelessWidget {
  final LocalStorage storage;

  const KarnaApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: appProviders(storage: storage),
      child: MaterialApp(
        title: 'Karna MVC',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routes: AppRoutes.routes,
        initialRoute: AppRoutes.posts,
      ),
    );
  }
}
