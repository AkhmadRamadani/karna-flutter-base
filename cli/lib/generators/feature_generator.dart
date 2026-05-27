import 'dart:io';

import '../templates/feature_templates.dart';
import '../util/logger.dart';
import '../util/string_utils.dart';

/// Generates a complete Karna MVC feature.
Future<void> generateFeature({
  required String featureName,
  bool memoryAware = false,
}) async {
  final pascal = toPascalCase(featureName);
  final camel = toCamelCase(featureName);

  final libDir = 'lib/features/$featureName';
  final testDir = 'test/features/$featureName';

  // Create directories
  await Directory('$libDir/model').create(recursive: true);
  await Directory('$libDir/repository/data_source').create(recursive: true);
  await Directory('$libDir/controller').create(recursive: true);
  await Directory('$libDir/view').create(recursive: true);
  await Directory(testDir).create(recursive: true);

  // Write files
  await _write('$libDir/model/${featureName}_model.dart',
      modelTemplate(featureName, pascal));
  Logger.success('model/${featureName}_model.dart');

  await _write('$libDir/repository/${featureName}_repository.dart',
      repositoryTemplate(featureName, pascal));
  Logger.success('repository/${featureName}_repository.dart');

  await _write('$libDir/repository/${featureName}_repository_impl.dart',
      repositoryImplTemplate(featureName, pascal));
  Logger.success('repository/${featureName}_repository_impl.dart');

  await _write(
      '$libDir/repository/data_source/${featureName}_remote_source.dart',
      remoteSourceTemplate(featureName, pascal));
  Logger.success('repository/data_source/${featureName}_remote_source.dart');

  await _write(
      '$libDir/repository/data_source/${featureName}_local_source.dart',
      localSourceTemplate(featureName, pascal));
  Logger.success('repository/data_source/${featureName}_local_source.dart');

  await _write('$libDir/controller/${featureName}_controller.dart',
      controllerTemplate(featureName, pascal, camel, memoryAware: memoryAware));
  Logger.success('controller/${featureName}_controller.dart');

  await _write('$libDir/view/${featureName}_view.dart',
      viewTemplate(featureName, pascal, camel));
  Logger.success('view/${featureName}_view.dart');

  await _write('$testDir/${featureName}_controller_test.dart',
      controllerTestTemplate(featureName, pascal, camel));
  Logger.success('test/${featureName}_controller_test.dart');

  // Register in providers.dart
  await _registerInProviders(featureName, pascal, memoryAware: memoryAware);

  Logger.newLine();
  Logger.info("✨ Feature '$featureName' created successfully!");
  Logger.newLine();
  Logger.info('📝 Next steps:');
  Logger.info('   1. Add fields to model/${featureName}_model.dart');
  Logger.info('   2. Implement ${featureName}_remote_source.dart');
  Logger.info('   3. Add a route in core/routes/app_routes.dart');
  Logger.info('   4. Build your UI in view/${featureName}_view.dart');
}

Future<void> _write(String path, String content) async {
  await File(path).writeAsString(content);
}

Future<void> _registerInProviders(
  String feature,
  String pascal, {
  bool memoryAware = false,
}) async {
  final diFile = File('lib/core/di/providers.dart');
  if (!diFile.existsSync()) {
    Logger.warning('providers.dart not found — skipping DI registration');
    return;
  }

  var content = await diFile.readAsString();

  if (content.contains('${pascal}Controller')) {
    Logger.warning('${pascal}Controller already registered in providers.dart');
    return;
  }

  // Add imports
  final imports = [
    "import '../../features/$feature/controller/${feature}_controller.dart';",
    "import '../../features/$feature/repository/${feature}_repository_impl.dart';",
    "import '../../features/$feature/repository/data_source/${feature}_remote_source.dart';",
    "import '../../features/$feature/repository/data_source/${feature}_local_source.dart';",
  ].join('\n');

  // Find last import line
  final lines = content.split('\n');
  var lastImportIndex = 0;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('import ')) lastImportIndex = i;
  }
  lines.insert(lastImportIndex + 1, imports);

  // Build provider block
  final memoryManagerLine = memoryAware
      ? '\n      memoryManager: context.read<MemoryManager>(),'
      : '';
  final provider = '''
  ChangeNotifierProvider<${pascal}Controller>(
    create: (context) => ${pascal}Controller($memoryManagerLine
      repository: ${pascal}RepositoryImpl(
        remoteSource: ${pascal}RemoteSourceImpl(client: context.read<ApiClient>()),
        localSource: ${pascal}LocalSourceImpl(storage: context.read<LocalStorage>()),
        connectivity: context.read<ConnectivityChecker>(),
      ),
    ),
  ),''';

  // Insert before closing ];
  final closingIndex = lines.lastIndexOf('];');
  if (closingIndex != -1) {
    lines.insert(closingIndex, provider);
  }

  await diFile.writeAsString(lines.join('\n'));
  Logger.success('Registered ${pascal}Controller in providers.dart');
}
