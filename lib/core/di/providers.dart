import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/connectivity_checker.dart';
import '../storage/local_storage.dart';
import '../../features/auth/controller/auth_controller.dart';
import '../../features/auth/repository/auth_repository_impl.dart';
import '../../features/auth/repository/data_source/auth_remote_source.dart';
import '../../features/auth/repository/data_source/auth_local_source.dart';
import '../../features/profile/controller/profile_controller.dart';
import '../../features/profile/repository/profile_repository_impl.dart';
import '../../features/profile/repository/data_source/profile_remote_source.dart';
import '../../features/profile/repository/data_source/profile_local_source.dart';

/// All feature providers wired together.
/// [storage] must be initialized before calling this (e.g. in main()).
List<SingleChildWidget> appProviders({required LocalStorage storage}) => [
  // Core singletons
  Provider<AppConfig>(create: (_) => AppConfig.fromEnvironment()),
  Provider<ConnectivityChecker>(create: (_) => ConnectivityCheckerImpl()),
  Provider<LocalStorage>(create: (_) => storage),
  ProxyProvider<AppConfig, ApiClient>(
    update: (_, config, previous) {
      previous?.dispose();
      return ApiClient(config: config);
    },
    dispose: (_, client) => client.dispose(),
  ),

  // Feature controllers
  ChangeNotifierProvider<AuthController>(
    create: (context) => AuthController(
      repository: AuthRepositoryImpl(
        remoteSource: AuthRemoteSourceImpl(client: context.read<ApiClient>()),
        localSource: AuthLocalSourceImpl(storage: context.read<LocalStorage>()),
        connectivity: context.read<ConnectivityChecker>(),
      ),
    ),
  ),
  ChangeNotifierProvider<ProfileController>(
    create: (context) => ProfileController(
      repository: ProfileRepositoryImpl(
        remoteSource: ProfileRemoteSourceImpl(
          client: context.read<ApiClient>(),
        ),
        localSource: ProfileLocalSourceImpl(
          storage: context.read<LocalStorage>(),
        ),
        connectivity: context.read<ConnectivityChecker>(),
      ),
    ),
  ),
];
