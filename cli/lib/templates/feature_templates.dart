String modelTemplate(String feature, String pascal) => '''
class ${pascal}Model {
  final String id;

  const ${pascal}Model({required this.id});

  factory ${pascal}Model.fromJson(Map<String, dynamic> json) => ${pascal}Model(
        id: json['id'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id};

  ${pascal}Model copyWith({String? id}) => ${pascal}Model(id: id ?? this.id);
}
''';

String repositoryTemplate(String feature, String pascal) => '''
import '../../../core/result/result.dart';
import '../model/${feature}_model.dart';

abstract class ${pascal}Repository {
  Future<Result<${pascal}Model>> getById(String id);
  Future<Result<List<${pascal}Model>>> getAll();
  Future<Result<${pascal}Model>> getFromCache(String id);
  Future<Result<${pascal}Model>> getFromRemote(String id);
}
''';

String repositoryImplTemplate(String feature, String pascal) => '''
import '../../../core/errors/app_exception.dart';
import '../../../core/network/connectivity_checker.dart';
import '../../../core/result/result.dart';
import '${feature}_repository.dart';
import '../model/${feature}_model.dart';

abstract class ${pascal}RemoteSource {
  Future<Map<String, dynamic>> fetchById(String id);
  Future<List<Map<String, dynamic>>> fetchAll();
}

abstract class ${pascal}LocalSource {
  Future<Map<String, dynamic>?> getCached(String id);
  Future<List<Map<String, dynamic>>> getCachedList();
  Future<void> cache(Map<String, dynamic> data);
  Future<void> cacheList(List<Map<String, dynamic>> data);
  Future<void> clearCache();
}

class ${pascal}RepositoryImpl implements ${pascal}Repository {
  final ${pascal}RemoteSource _remoteSource;
  final ${pascal}LocalSource _localSource;
  final ConnectivityChecker _connectivity;

  ${pascal}RepositoryImpl({
    required ${pascal}RemoteSource remoteSource,
    required ${pascal}LocalSource localSource,
    required ConnectivityChecker connectivity,
  })  : _remoteSource = remoteSource,
        _localSource = localSource,
        _connectivity = connectivity;

  @override
  Future<Result<${pascal}Model>> getById(String id) async {
    try {
      final cached = await _localSource.getCached(id);
      if (cached != null) return Success(${pascal}Model.fromJson(cached));
      if (!await _connectivity.hasConnection) {
        return const Failure(NetworkException(message: 'No internet connection', code: 'NO_CONNECTION'));
      }
      final json = await _remoteSource.fetchById(id);
      await _localSource.cache(json);
      return Success(${pascal}Model.fromJson(json));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<List<${pascal}Model>>> getAll() async {
    try {
      final cached = await _localSource.getCachedList();
      if (cached.isNotEmpty) return Success(cached.map(${pascal}Model.fromJson).toList());
      if (!await _connectivity.hasConnection) {
        return const Failure(NetworkException(message: 'No internet connection', code: 'NO_CONNECTION'));
      }
      final list = await _remoteSource.fetchAll();
      await _localSource.cacheList(list);
      return Success(list.map(${pascal}Model.fromJson).toList());
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<${pascal}Model>> getFromCache(String id) async {
    try {
      final cached = await _localSource.getCached(id);
      if (cached != null) return Success(${pascal}Model.fromJson(cached));
      return const Failure(CacheException(message: 'No cached data', code: 'CACHE_MISS'));
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<${pascal}Model>> getFromRemote(String id) async {
    try {
      if (!await _connectivity.hasConnection) {
        return const Failure(NetworkException(message: 'No internet connection', code: 'NO_CONNECTION'));
      }
      final json = await _remoteSource.fetchById(id);
      await _localSource.cache(json);
      return Success(${pascal}Model.fromJson(json));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }
}
''';

String remoteSourceTemplate(String feature, String pascal) => '''
import '../../../../core/network/api_client.dart';
import '../${feature}_repository_impl.dart';

class ${pascal}RemoteSourceImpl implements ${pascal}RemoteSource {
  final ApiClient _client;
  ${pascal}RemoteSourceImpl({required ApiClient client}) : _client = client;

  @override
  Future<Map<String, dynamic>> fetchById(String id) async {
    final json = await _client.get('/${feature}s/\$id');
    return json as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    final json = await _client.get('/${feature}s');
    return (json as List).map((e) => e as Map<String, dynamic>).toList();
  }
}
''';

String localSourceTemplate(String feature, String pascal) => '''
import '../../../../core/storage/local_storage.dart';
import '../${feature}_repository_impl.dart';

class ${pascal}LocalSourceImpl implements ${pascal}LocalSource {
  final LocalStorage _storage;
  static const _keyPrefix = '${feature}_';
  static const _itemKey = '\\\${_keyPrefix}item_';
  static const _listKey = '\\\${_keyPrefix}list';

  ${pascal}LocalSourceImpl({required LocalStorage storage}) : _storage = storage;

  @override
  Future<Map<String, dynamic>?> getCached(String id) async => _storage.getJson('\\\$_itemKey\\\$id');

  @override
  Future<List<Map<String, dynamic>>> getCachedList() async => _storage.getJsonList(_listKey);

  @override
  Future<void> cache(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    await _storage.putJson('\\\$_itemKey\\\$id', data);
  }

  @override
  Future<void> cacheList(List<Map<String, dynamic>> data) async => _storage.putJsonList(_listKey, data);

  @override
  Future<void> clearCache() async => _storage.removeByPrefix(_keyPrefix);
}
''';

String controllerTemplate(
  String feature,
  String pascal,
  String camel, {
  bool memoryAware = false,
}) {
  if (memoryAware) {
    return '''
import '../../../core/memory/memory_aware_controller.dart';
import '../../../core/memory/service_priority.dart';
import '../../../core/network/data_strategy.dart';
import '../model/${feature}_model.dart';
import '../repository/${feature}_repository.dart';

class ${pascal}Controller extends MemoryAwareController {
  final ${pascal}Repository _repository;

  ${pascal}Controller({
    required super.memoryManager,
    required ${pascal}Repository repository,
    super.notificationService,
  }) : _repository = repository,
       super(servicePriority: ServicePriority.normal);

  ${pascal}Model? _$camel;
  List<${pascal}Model> _${camel}List = [];

  ${pascal}Model? get $camel => _$camel;
  List<${pascal}Model> get ${camel}List => _${camel}List;

  @override
  String get serviceId => '${feature}_controller';

  @override
  bool get isActive => _${camel}List.isNotEmpty;

  @override
  Future<void> onMemoryWarning() async {
    if (_${camel}List.length > 20) {
      _${camel}List = _${camel}List.sublist(0, 20);
      notifyListeners();
    }
  }

  @override
  Future<void> onKill() async {
    _$camel = null;
    _${camel}List = [];
    notifyListeners();
  }

  @override
  Future<void> onRevive() async => loadAll();

  Future<void> loadById(String id, {DataStrategy strategy = DataStrategy.localFirst}) async {
    markSelfActive();
    await load(
      strategy: strategy,
      cacheAction: () => _repository.getFromCache(id),
      freshAction: () => _repository.getFromRemote(id),
      onSuccess: (data) => _$camel = data,
    );
  }

  Future<void> loadAll() async {
    markSelfActive();
    await executeResult(() => _repository.getAll(), onSuccess: (data) => _${camel}List = data);
  }
}
''';
  }

  return '''
import '../../../core/controller/base_controller.dart';
import '../../../core/network/data_strategy.dart';
import '../model/${feature}_model.dart';
import '../repository/${feature}_repository.dart';

class ${pascal}Controller extends BaseController {
  final ${pascal}Repository _repository;

  ${pascal}Controller({required ${pascal}Repository repository}) : _repository = repository;

  ${pascal}Model? _$camel;
  List<${pascal}Model> _${camel}List = [];

  ${pascal}Model? get $camel => _$camel;
  List<${pascal}Model> get ${camel}List => _${camel}List;

  Future<void> loadById(String id, {DataStrategy strategy = DataStrategy.localFirst}) async {
    await load(
      strategy: strategy,
      cacheAction: () => _repository.getFromCache(id),
      freshAction: () => _repository.getFromRemote(id),
      onSuccess: (data) => _$camel = data,
    );
  }

  Future<void> loadAll() async {
    await executeResult(() => _repository.getAll(), onSuccess: (data) => _${camel}List = data);
  }
}
''';
}

String viewTemplate(String feature, String pascal, String camel) => '''
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/${feature}_controller.dart';

class ${pascal}View extends StatefulWidget {
  const ${pascal}View({super.key});

  @override
  State<${pascal}View> createState() => _${pascal}ViewState();
}

class _${pascal}ViewState extends State<${pascal}View> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<${pascal}Controller>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<${pascal}Controller>();

    if (controller.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (controller.hasError) {
      return Scaffold(body: Center(child: Text('Error: \\\${controller.errorMessage}')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('$pascal')),
      body: const Center(child: Text('$pascal View')),
    );
  }
}
''';

String controllerTestTemplate(String feature, String pascal, String camel) =>
    '''
import 'package:flutter_test/flutter_test.dart';
import 'package:karna_mvc/core/errors/app_exception.dart';
import 'package:karna_mvc/core/result/result.dart';
import 'package:karna_mvc/features/$feature/controller/${feature}_controller.dart';
import 'package:karna_mvc/features/$feature/model/${feature}_model.dart';
import 'package:karna_mvc/features/$feature/repository/${feature}_repository.dart';

class Mock${pascal}Repository implements ${pascal}Repository {
  Result<${pascal}Model>? modelResult;
  Result<List<${pascal}Model>>? listResult;
  Result<${pascal}Model>? cacheResult;
  Result<${pascal}Model>? remoteResult;

  @override
  Future<Result<${pascal}Model>> getById(String id) async => modelResult!;
  @override
  Future<Result<List<${pascal}Model>>> getAll() async => listResult!;
  @override
  Future<Result<${pascal}Model>> getFromCache(String id) async => cacheResult!;
  @override
  Future<Result<${pascal}Model>> getFromRemote(String id) async => remoteResult!;
}

void main() {
  late Mock${pascal}Repository mockRepo;
  late ${pascal}Controller controller;

  setUp(() {
    mockRepo = Mock${pascal}Repository();
    controller = ${pascal}Controller(repository: mockRepo);
  });

  test('loadAll sets list on success', () async {
    mockRepo.listResult = Success([${pascal}Model(id: '1'), ${pascal}Model(id: '2')]);
    await controller.loadAll();
    expect(controller.${camel}List.length, equals(2));
    expect(controller.isLoading, isFalse);
  });

  test('loadById sets data on cache hit', () async {
    mockRepo.cacheResult = Success(${pascal}Model(id: '1'));
    await controller.loadById('1');
    expect(controller.$camel?.id, equals('1'));
  });

  test('loadById sets error on failure', () async {
    mockRepo.cacheResult = const Failure(CacheException(message: 'miss', code: 'CACHE_MISS'));
    mockRepo.remoteResult = const Failure(NetworkException(message: 'No connection', code: 'NO_CONNECTION'));
    await controller.loadById('1');
    expect(controller.hasError, isTrue);
  });
}
''';
