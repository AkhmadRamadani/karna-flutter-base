import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../config/app_config.dart';
import '../events/event_bus.dart';
import '../network/api_client.dart';
import '../network/connectivity_checker.dart';
import '../storage/local_storage.dart';
import 'app_dependencies.dart';
import '../../features/post/controller/post_controller.dart';
import '../../features/post/repository/post_repository_impl.dart';
import '../../features/post/repository/data_source/post_remote_source.dart';
import '../../features/post/repository/data_source/post_local_source.dart';

/// All feature providers wired together.
/// Receives [AppDependencies] initialized in main().
///
/// To add a new feature:
/// 1. Import its controller + repository + data sources
/// 2. Add a ChangeNotifierProvider at the bottom
/// 3. Wire dependencies via `context.read<T>()`
List<SingleChildWidget> appProviders({
  required AppDependencies dependencies,
}) => [
  // ─── Core singletons ─────────────────────────────────────────────
  Provider<AppConfig>(create: (_) => AppConfig.fromEnvironment()),
  Provider<ConnectivityChecker>(create: (_) => ConnectivityCheckerImpl()),
  Provider<LocalStorage>(create: (_) => dependencies.storage),
  Provider<EventBus>(
    create: (_) => EventBusImpl(),
    dispose: (_, bus) => bus.dispose(),
  ),
  ProxyProvider<AppConfig, ApiClient>(
    update: (_, config, previous) {
      previous?.dispose();
      return ApiClient(config: config);
    },
    dispose: (_, client) => client.dispose(),
  ),

  // ─── Feature controllers ─────────────────────────────────────────
  // Example: Post feature (delete this and add your own features)
  ChangeNotifierProvider<PostController>(
    create: (context) => PostController(
      repository: PostRepositoryImpl(
        remoteSource: PostRemoteSourceImpl(client: context.read<ApiClient>()),
        localSource: PostLocalSourceImpl(storage: context.read<LocalStorage>()),
        connectivity: context.read<ConnectivityChecker>(),
      ),
      eventBus: context.read<EventBus>(),
      notificationService: dependencies.notificationService,
    ),
  ),
];
