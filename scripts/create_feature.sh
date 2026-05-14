#!/bin/bash

# Karna MVC — Feature Generator (macOS compatible)
# Usage: ./scripts/create_feature.sh <feature_name>
# Example: ./scripts/create_feature.sh payment
#          ./scripts/create_feature.sh order_history
#
# This will create all Karna MVC feature files and register in DI.
# Generated features support both local-first and stale-while-revalidate strategies.

set -e

if [ -z "$1" ]; then
  echo "❌ Usage: ./scripts/create_feature.sh <feature_name>"
  echo "   Example: ./scripts/create_feature.sh payment"
  echo "            ./scripts/create_feature.sh order_history"
  exit 1
fi

FEATURE="$1"

# Validate: only lowercase letters and underscores
if [[ ! "$FEATURE" =~ ^[a-z][a-z0-9_]*$ ]]; then
  echo "❌ Feature name must be snake_case (lowercase letters, numbers, underscores)"
  echo "   Example: payment, order_history, user_settings"
  exit 1
fi

# Convert snake_case to PascalCase (macOS compatible)
to_pascal() {
  echo "$1" | awk -F'_' '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1' OFS=''
}

# Convert snake_case to camelCase
to_camel() {
  local pascal
  pascal=$(to_pascal "$1")
  local first_char
  first_char=$(echo "${pascal:0:1}" | awk '{print tolower($0)}')
  echo "${first_char}${pascal:1}"
}

PASCAL=$(to_pascal "$FEATURE")
CAMEL=$(to_camel "$FEATURE")

# Detect project root (where pubspec.yaml lives)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

LIB_DIR="$PROJECT_ROOT/lib/features/$FEATURE"
TEST_DIR="$PROJECT_ROOT/test/features/$FEATURE"
DI_FILE="$PROJECT_ROOT/lib/core/di/providers.dart"

# Check if feature already exists
if [ -d "$LIB_DIR" ]; then
  echo "❌ Feature '$FEATURE' already exists at $LIB_DIR"
  exit 1
fi

echo "🚀 Creating Karna MVC feature: $FEATURE ($PASCAL)"
echo ""

# Create directories
mkdir -p "$LIB_DIR/model"
mkdir -p "$LIB_DIR/repository/data_source"
mkdir -p "$LIB_DIR/controller"
mkdir -p "$LIB_DIR/view/widgets"
mkdir -p "$TEST_DIR"

# ============================================================
# MODEL
# ============================================================
cat > "$LIB_DIR/model/${FEATURE}_model.dart" << EOF
class ${PASCAL}Model {
  final String id;

  const ${PASCAL}Model({
    required this.id,
  });

  factory ${PASCAL}Model.fromJson(Map<String, dynamic> json) => ${PASCAL}Model(
        id: json['id'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
      };

  ${PASCAL}Model copyWith({String? id}) => ${PASCAL}Model(
        id: id ?? this.id,
      );
}
EOF
echo "  ✅ model/${FEATURE}_model.dart"

# ============================================================
# REPOSITORY (abstract — supports both strategies)
# ============================================================
cat > "$LIB_DIR/repository/${FEATURE}_repository.dart" << EOF
import '../../../core/result/result.dart';
import '../model/${FEATURE}_model.dart';

abstract class ${PASCAL}Repository {
  /// Get by ID using local-first strategy.
  Future<Result<${PASCAL}Model>> getById(String id);

  /// Get all using local-first strategy.
  Future<Result<List<${PASCAL}Model>>> getAll();

  /// Get from local cache only. Returns Failure on cache miss.
  Future<Result<${PASCAL}Model>> getFromCache(String id);

  /// Get from remote only. Always hits network and updates cache.
  Future<Result<${PASCAL}Model>> getFromRemote(String id);
}
EOF
echo "  ✅ repository/${FEATURE}_repository.dart"

# ============================================================
# REPOSITORY (implementation — local-first + connectivity)
# ============================================================
cat > "$LIB_DIR/repository/${FEATURE}_repository_impl.dart" << EOF
import '../../../core/errors/app_exception.dart';
import '../../../core/network/connectivity_checker.dart';
import '../../../core/result/result.dart';
import '${FEATURE}_repository.dart';
import '../model/${FEATURE}_model.dart';

/// Remote data source abstraction for $FEATURE feature.
abstract class ${PASCAL}RemoteSource {
  Future<Map<String, dynamic>> fetchById(String id);
  Future<List<Map<String, dynamic>>> fetchAll();
}

/// Local data source abstraction for $FEATURE feature.
abstract class ${PASCAL}LocalSource {
  Future<Map<String, dynamic>?> getCached(String id);
  Future<List<Map<String, dynamic>>> getCachedList();
  Future<void> cache(Map<String, dynamic> data);
  Future<void> cacheList(List<Map<String, dynamic>> data);
  Future<void> clearCache();
}

class ${PASCAL}RepositoryImpl implements ${PASCAL}Repository {
  final ${PASCAL}RemoteSource _remoteSource;
  final ${PASCAL}LocalSource _localSource;
  final ConnectivityChecker _connectivity;

  ${PASCAL}RepositoryImpl({
    required ${PASCAL}RemoteSource remoteSource,
    required ${PASCAL}LocalSource localSource,
    required ConnectivityChecker connectivity,
  })  : _remoteSource = remoteSource,
        _localSource = localSource,
        _connectivity = connectivity;

  @override
  Future<Result<${PASCAL}Model>> getById(String id) async {
    try {
      // Try local first
      final cached = await _localSource.getCached(id);
      if (cached != null) {
        return Success(${PASCAL}Model.fromJson(cached));
      }

      // Check connectivity before remote call
      if (!await _connectivity.hasConnection) {
        return const Failure(NetworkException(
          message: 'No internet connection',
          code: 'NO_CONNECTION',
        ));
      }

      // Fall back to remote
      final json = await _remoteSource.fetchById(id);
      await _localSource.cache(json);
      return Success(${PASCAL}Model.fromJson(json));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<List<${PASCAL}Model>>> getAll() async {
    try {
      // Try local first
      final cached = await _localSource.getCachedList();
      if (cached.isNotEmpty) {
        return Success(cached.map(${PASCAL}Model.fromJson).toList());
      }

      // Check connectivity before remote call
      if (!await _connectivity.hasConnection) {
        return const Failure(NetworkException(
          message: 'No internet connection',
          code: 'NO_CONNECTION',
        ));
      }

      // Fall back to remote
      final list = await _remoteSource.fetchAll();
      await _localSource.cacheList(list);
      return Success(list.map(${PASCAL}Model.fromJson).toList());
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<${PASCAL}Model>> getFromCache(String id) async {
    try {
      final cached = await _localSource.getCached(id);
      if (cached != null) {
        return Success(${PASCAL}Model.fromJson(cached));
      }
      return const Failure(CacheException(
        message: 'No cached data',
        code: 'CACHE_MISS',
      ));
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  @override
  Future<Result<${PASCAL}Model>> getFromRemote(String id) async {
    try {
      if (!await _connectivity.hasConnection) {
        return const Failure(NetworkException(
          message: 'No internet connection',
          code: 'NO_CONNECTION',
        ));
      }

      final json = await _remoteSource.fetchById(id);
      await _localSource.cache(json);
      return Success(${PASCAL}Model.fromJson(json));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }
}
EOF
echo "  ✅ repository/${FEATURE}_repository_impl.dart"

# ============================================================
# DATA SOURCE — Remote
# ============================================================
cat > "$LIB_DIR/repository/data_source/${FEATURE}_remote_source.dart" << EOF
import '../${FEATURE}_repository_impl.dart';

/// TODO: Replace with real HTTP implementation using ApiClient.
class ${PASCAL}RemoteSourceImpl implements ${PASCAL}RemoteSource {
  @override
  Future<Map<String, dynamic>> fetchById(String id) async {
    throw UnimplementedError('Replace with real implementation');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    throw UnimplementedError('Replace with real implementation');
  }
}
EOF
echo "  ✅ repository/data_source/${FEATURE}_remote_source.dart"

# ============================================================
# DATA SOURCE — Local (uses agnostic LocalStorage)
# ============================================================
cat > "$LIB_DIR/repository/data_source/${FEATURE}_local_source.dart" << EOF
import '../../../../core/storage/local_storage.dart';
import '../${FEATURE}_repository_impl.dart';

/// ${PASCAL} local source backed by the agnostic [LocalStorage].
class ${PASCAL}LocalSourceImpl implements ${PASCAL}LocalSource {
  final LocalStorage _storage;

  static const _keyPrefix = '${FEATURE}_';
  static const _itemKey = '\${_keyPrefix}item_';
  static const _listKey = '\${_keyPrefix}list';

  ${PASCAL}LocalSourceImpl({required LocalStorage storage}) : _storage = storage;

  @override
  Future<Map<String, dynamic>?> getCached(String id) async {
    return _storage.getJson('\$_itemKey\$id');
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedList() async {
    return _storage.getJsonList(_listKey);
  }

  @override
  Future<void> cache(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    await _storage.putJson('\$_itemKey\$id', data);
  }

  @override
  Future<void> cacheList(List<Map<String, dynamic>> data) async {
    await _storage.putJsonList(_listKey, data);
  }

  @override
  Future<void> clearCache() async {
    await _storage.removeByPrefix(_keyPrefix);
  }
}
EOF
echo "  ✅ repository/data_source/${FEATURE}_local_source.dart"

# ============================================================
# CONTROLLER (extends BaseController, supports DataStrategy)
# ============================================================
cat > "$LIB_DIR/controller/${FEATURE}_controller.dart" << EOF
import '../../../core/controller/base_controller.dart';
import '../../../core/network/data_strategy.dart';
import '../model/${FEATURE}_model.dart';
import '../repository/${FEATURE}_repository.dart';

class ${PASCAL}Controller extends BaseController {
  final ${PASCAL}Repository _repository;

  ${PASCAL}Controller({required ${PASCAL}Repository repository})
      : _repository = repository;

  ${PASCAL}Model? _${CAMEL};
  List<${PASCAL}Model> _${CAMEL}List = [];

  ${PASCAL}Model? get ${CAMEL} => _${CAMEL};
  List<${PASCAL}Model> get ${CAMEL}List => _${CAMEL}List;

  /// Load by ID with the specified data strategy.
  ///
  /// Examples:
  ///   loadById('1')                                              → local-first
  ///   loadById('1', strategy: DataStrategy.staleWhileRevalidate) → cache + refresh
  ///   loadById('1', strategy: DataStrategy.remoteFirst)          → always network
  Future<void> loadById(
    String id, {
    DataStrategy strategy = DataStrategy.localFirst,
  }) async {
    await load(
      strategy: strategy,
      cacheAction: () => _repository.getFromCache(id),
      freshAction: () => _repository.getFromRemote(id),
      onSuccess: (data) => _${CAMEL} = data,
    );
  }

  /// Load all with local-first strategy.
  Future<void> loadAll() async {
    await executeResult(
      () => _repository.getAll(),
      onSuccess: (data) => _${CAMEL}List = data,
    );
  }
}
EOF
echo "  ✅ controller/${FEATURE}_controller.dart"

# ============================================================
# VIEW
# ============================================================
cat > "$LIB_DIR/view/${FEATURE}_view.dart" << 'VIEWEOF'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/FEATURE_controller.dart';

class PASTEView extends StatelessWidget {
  const PASTEView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PASTEController>();

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.hasError) {
      return Center(child: Text('Error: ${controller.errorMessage}'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PASTE'),
        actions: [
          if (controller.isRefreshing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: const Center(
        child: Text('PASTE View'),
      ),
    );
  }
}
VIEWEOF
# Replace placeholders in view file
sed -i '' "s/FEATURE/${FEATURE}/g" "$LIB_DIR/view/${FEATURE}_view.dart"
sed -i '' "s/PASTE/${PASCAL}/g" "$LIB_DIR/view/${FEATURE}_view.dart"
echo "  ✅ view/${FEATURE}_view.dart"

# ============================================================
# TEST: Controller
# ============================================================
cat > "$TEST_DIR/${FEATURE}_controller_test.dart" << EOF
import 'package:flutter_test/flutter_test.dart';
import 'package:karna_mvc/core/errors/app_exception.dart';
import 'package:karna_mvc/core/network/data_strategy.dart';
import 'package:karna_mvc/core/result/result.dart';
import 'package:karna_mvc/features/${FEATURE}/controller/${FEATURE}_controller.dart';
import 'package:karna_mvc/features/${FEATURE}/model/${FEATURE}_model.dart';
import 'package:karna_mvc/features/${FEATURE}/repository/${FEATURE}_repository.dart';

class Mock${PASCAL}Repository implements ${PASCAL}Repository {
  Result<${PASCAL}Model>? modelResult;
  Result<List<${PASCAL}Model>>? listResult;
  Result<${PASCAL}Model>? cacheResult;
  Result<${PASCAL}Model>? remoteResult;

  @override
  Future<Result<${PASCAL}Model>> getById(String id) async => modelResult!;

  @override
  Future<Result<List<${PASCAL}Model>>> getAll() async => listResult!;

  @override
  Future<Result<${PASCAL}Model>> getFromCache(String id) async => cacheResult!;

  @override
  Future<Result<${PASCAL}Model>> getFromRemote(String id) async => remoteResult!;
}

void main() {
  late Mock${PASCAL}Repository mockRepo;
  late ${PASCAL}Controller controller;

  setUp(() {
    mockRepo = Mock${PASCAL}Repository();
    controller = ${PASCAL}Controller(repository: mockRepo);
  });

  group('loadById (local-first)', () {
    test('sets data on success', () async {
      mockRepo.cacheResult = Success(${PASCAL}Model(id: '1'));

      await controller.loadById('1');

      expect(controller.${CAMEL}?.id, equals('1'));
      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
    });

    test('sets error on failure', () async {
      mockRepo.cacheResult = const Failure(
        CacheException(message: 'miss', code: 'CACHE_MISS'),
      );
      mockRepo.remoteResult = const Failure(
        NetworkException(message: 'No connection', code: 'NO_CONNECTION'),
      );

      await controller.loadById('1');

      expect(controller.${CAMEL}, isNull);
      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, equals('No connection'));
    });
  });

  group('DataStrategy.staleWhileRevalidate', () {
    test('shows cache then replaces with fresh data', () async {
      mockRepo.cacheResult = Success(${PASCAL}Model(id: '1'));
      mockRepo.remoteResult = Success(${PASCAL}Model(id: '1'));

      await controller.loadById('1', strategy: DataStrategy.staleWhileRevalidate);

      expect(controller.${CAMEL}?.id, equals('1'));
      expect(controller.isLoading, isFalse);
      expect(controller.isRefreshing, isFalse);
      expect(controller.hasError, isFalse);
    });

    test('keeps stale data when refresh fails', () async {
      mockRepo.cacheResult = Success(${PASCAL}Model(id: '1'));
      mockRepo.remoteResult = const Failure(
        NetworkException(message: 'Timeout', code: 'TIMEOUT'),
      );

      await controller.loadById('1', strategy: DataStrategy.staleWhileRevalidate);

      expect(controller.${CAMEL}?.id, equals('1'));
      expect(controller.hasError, isFalse);
    });

    test('sets error when both cache and remote fail', () async {
      mockRepo.cacheResult = const Failure(
        CacheException(message: 'No cached data', code: 'CACHE_MISS'),
      );
      mockRepo.remoteResult = const Failure(
        NetworkException(message: 'No connection', code: 'NO_CONNECTION'),
      );

      await controller.loadById('1', strategy: DataStrategy.staleWhileRevalidate);

      expect(controller.${CAMEL}, isNull);
      expect(controller.hasError, isTrue);
    });
  });

  test('loadAll sets list on success', () async {
    mockRepo.listResult = Success([
      ${PASCAL}Model(id: '1'),
      ${PASCAL}Model(id: '2'),
    ]);

    await controller.loadAll();

    expect(controller.${CAMEL}List.length, equals(2));
    expect(controller.isLoading, isFalse);
    expect(controller.hasError, isFalse);
  });
}
EOF
echo "  ✅ test/${FEATURE}_controller_test.dart"

# ============================================================
# TEST: Repository
# ============================================================
cat > "$TEST_DIR/${FEATURE}_repository_test.dart" << EOF
import 'package:flutter_test/flutter_test.dart';
import 'package:karna_mvc/core/network/connectivity_checker.dart';
import 'package:karna_mvc/features/${FEATURE}/repository/${FEATURE}_repository_impl.dart';

class Mock${PASCAL}RemoteSource implements ${PASCAL}RemoteSource {
  Map<String, dynamic>? jsonToReturn;
  List<Map<String, dynamic>>? listToReturn;
  Exception? exceptionToThrow;

  @override
  Future<Map<String, dynamic>> fetchById(String id) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return jsonToReturn!;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return listToReturn!;
  }
}

class Mock${PASCAL}LocalSource implements ${PASCAL}LocalSource {
  Map<String, dynamic>? cachedItem;
  List<Map<String, dynamic>> cachedList = [];

  @override
  Future<Map<String, dynamic>?> getCached(String id) async => cachedItem;

  @override
  Future<List<Map<String, dynamic>>> getCachedList() async => cachedList;

  @override
  Future<void> cache(Map<String, dynamic> data) async {
    cachedItem = data;
  }

  @override
  Future<void> cacheList(List<Map<String, dynamic>> data) async {
    cachedList = data;
  }

  @override
  Future<void> clearCache() async {
    cachedItem = null;
    cachedList = [];
  }
}

class MockConnectivity implements ConnectivityChecker {
  bool isConnected = true;

  @override
  Future<bool> get hasConnection async => isConnected;
}

void main() {
  late Mock${PASCAL}RemoteSource mockRemote;
  late Mock${PASCAL}LocalSource mockLocal;
  late MockConnectivity mockConnectivity;
  late ${PASCAL}RepositoryImpl repository;

  setUp(() {
    mockRemote = Mock${PASCAL}RemoteSource();
    mockLocal = Mock${PASCAL}LocalSource();
    mockConnectivity = MockConnectivity();
    repository = ${PASCAL}RepositoryImpl(
      remoteSource: mockRemote,
      localSource: mockLocal,
      connectivity: mockConnectivity,
    );
  });

  group('getById (local-first)', () {
    test('returns cached data when available', () async {
      mockLocal.cachedItem = {'id': '1'};

      final result = await repository.getById('1');

      expect(result.isSuccess, isTrue);
      expect(result.data.id, equals('1'));
    });

    test('fetches from remote when no cache', () async {
      mockRemote.jsonToReturn = {'id': '1'};

      final result = await repository.getById('1');

      expect(result.isSuccess, isTrue);
      expect(mockLocal.cachedItem, isNotNull);
    });

    test('returns failure when offline and no cache', () async {
      mockConnectivity.isConnected = false;

      final result = await repository.getById('1');

      expect(result.isFailure, isTrue);
      expect(result.exception.code, equals('NO_CONNECTION'));
    });
  });

  group('getFromCache', () {
    test('returns cached data', () async {
      mockLocal.cachedItem = {'id': '1'};

      final result = await repository.getFromCache('1');

      expect(result.isSuccess, isTrue);
    });

    test('returns failure on cache miss', () async {
      final result = await repository.getFromCache('1');

      expect(result.isFailure, isTrue);
      expect(result.exception.code, equals('CACHE_MISS'));
    });
  });

  group('getFromRemote', () {
    test('fetches and caches data', () async {
      mockRemote.jsonToReturn = {'id': '1'};

      final result = await repository.getFromRemote('1');

      expect(result.isSuccess, isTrue);
      expect(mockLocal.cachedItem, isNotNull);
    });

    test('returns failure when offline', () async {
      mockConnectivity.isConnected = false;

      final result = await repository.getFromRemote('1');

      expect(result.isFailure, isTrue);
      expect(result.exception.code, equals('NO_CONNECTION'));
    });
  });
}
EOF
echo "  ✅ test/${FEATURE}_repository_test.dart"

# ============================================================
# TEST: View
# ============================================================
cat > "$TEST_DIR/${FEATURE}_view_test.dart" << EOF
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:karna_mvc/core/result/result.dart';
import 'package:karna_mvc/features/${FEATURE}/controller/${FEATURE}_controller.dart';
import 'package:karna_mvc/features/${FEATURE}/repository/${FEATURE}_repository.dart';
import 'package:karna_mvc/features/${FEATURE}/model/${FEATURE}_model.dart';
import 'package:karna_mvc/features/${FEATURE}/view/${FEATURE}_view.dart';

class Fake${PASCAL}Repository implements ${PASCAL}Repository {
  @override
  Future<Result<${PASCAL}Model>> getById(String id) async =>
      Success(${PASCAL}Model(id: '1'));

  @override
  Future<Result<List<${PASCAL}Model>>> getAll() async => const Success([]);

  @override
  Future<Result<${PASCAL}Model>> getFromCache(String id) async =>
      Success(${PASCAL}Model(id: '1'));

  @override
  Future<Result<${PASCAL}Model>> getFromRemote(String id) async =>
      Success(${PASCAL}Model(id: '1'));
}

void main() {
  testWidgets('${PASCAL}View renders without crashing', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<${PASCAL}Controller>(
        create: (_) => ${PASCAL}Controller(repository: Fake${PASCAL}Repository()),
        child: const MaterialApp(home: ${PASCAL}View()),
      ),
    );

    expect(find.text('${PASCAL} View'), findsOneWidget);
  });
}
EOF
echo "  ✅ test/${FEATURE}_view_test.dart"

# ============================================================
# REGISTER IN core/di/providers.dart
# ============================================================
if [ -f "$DI_FILE" ]; then
  # Check if already registered
  if grep -q "${PASCAL}Controller" "$DI_FILE"; then
    echo "  ⚠️  ${PASCAL}Controller already registered in providers.dart"
  else
    # Build the new import lines
    IMPORT1="import '../../features/${FEATURE}/controller/${FEATURE}_controller.dart';"
    IMPORT2="import '../../features/${FEATURE}/repository/${FEATURE}_repository_impl.dart';"
    IMPORT3="import '../../features/${FEATURE}/repository/data_source/${FEATURE}_remote_source.dart';"
    IMPORT4="import '../../features/${FEATURE}/repository/data_source/${FEATURE}_local_source.dart';"

    # Insert imports after the last existing import line
    LAST_IMPORT_LINE=$(grep -n "^import " "$DI_FILE" | tail -1 | cut -d: -f1)
    sed -i '' "${LAST_IMPORT_LINE}a\\
${IMPORT1}
" "$DI_FILE"
    LAST_IMPORT_LINE=$((LAST_IMPORT_LINE + 1))
    sed -i '' "${LAST_IMPORT_LINE}a\\
${IMPORT2}
" "$DI_FILE"
    LAST_IMPORT_LINE=$((LAST_IMPORT_LINE + 1))
    sed -i '' "${LAST_IMPORT_LINE}a\\
${IMPORT3}
" "$DI_FILE"
    LAST_IMPORT_LINE=$((LAST_IMPORT_LINE + 1))
    sed -i '' "${LAST_IMPORT_LINE}a\\
${IMPORT4}
" "$DI_FILE"

    # Insert provider before the closing ];
    PROVIDER_BLOCK="  ChangeNotifierProvider<${PASCAL}Controller>(\\
    create: (context) => ${PASCAL}Controller(\\
      repository: ${PASCAL}RepositoryImpl(\\
        remoteSource: ${PASCAL}RemoteSourceImpl(),\\
        localSource: ${PASCAL}LocalSourceImpl(\\
          storage: context.read<LocalStorage>(),\\
        ),\\
        connectivity: context.read<ConnectivityChecker>(),\\
      ),\\
    ),\\
  ),"
    CLOSING_LINE=$(grep -n "^];" "$DI_FILE" | tail -1 | cut -d: -f1)
    sed -i '' "${CLOSING_LINE}i\\
${PROVIDER_BLOCK}
" "$DI_FILE"

    echo "  ✅ Registered ${PASCAL}Controller in core/di/providers.dart"
  fi
else
  echo "  ⚠️  Could not find $DI_FILE — skipping DI registration"
fi

echo ""
echo "✨ Feature '$FEATURE' created successfully!"
echo ""
echo "📁 Structure:"
echo "   lib/features/$FEATURE/"
echo "   ├── model/${FEATURE}_model.dart"
echo "   ├── repository/"
echo "   │   ├── ${FEATURE}_repository.dart          (abstract, returns Result<T>)"
echo "   │   ├── ${FEATURE}_repository_impl.dart     (local-first + connectivity)"
echo "   │   └── data_source/"
echo "   │       ├── ${FEATURE}_remote_source.dart   (HTTP)"
echo "   │       └── ${FEATURE}_local_source.dart    (cache/DB)"
echo "   ├── controller/${FEATURE}_controller.dart   (extends BaseController)"
echo "   └── view/"
echo "       ├── ${FEATURE}_view.dart"
echo "       └── widgets/"
echo ""
echo "   test/features/$FEATURE/"
echo "   ├── ${FEATURE}_controller_test.dart"
echo "   ├── ${FEATURE}_repository_test.dart"
echo "   └── ${FEATURE}_view_test.dart"
echo ""
echo "📝 Data strategies available in controller:"
echo "   • loadById('1')                                              → local-first"
echo "   • loadById('1', strategy: DataStrategy.staleWhileRevalidate) → cache + refresh"
echo "   • loadById('1', strategy: DataStrategy.remoteFirst)          → always network"
echo ""
echo "📝 Next steps:"
echo "   1. Add fields to model/${FEATURE}_model.dart"
echo "   2. Implement HTTP calls in data_source/${FEATURE}_remote_source.dart"
echo "   3. Implement caching in data_source/${FEATURE}_local_source.dart"
echo "   4. Add a route in core/routes/app_routes.dart"
echo "   5. Build your UI in view/${FEATURE}_view.dart"
