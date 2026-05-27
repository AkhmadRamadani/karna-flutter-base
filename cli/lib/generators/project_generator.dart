import 'dart:io';

import '../templates/project_templates.dart';
import '../util/logger.dart';
import '../util/process_runner.dart';

/// Generates a complete Karna MVC project.
Future<void> generateProject({
  required String projectName,
  required String org,
}) async {
  // Step 1: flutter create
  Logger.step('Creating Flutter project...');
  await runOrFail('flutter', ['create', '--org', org, projectName]);

  if (!Directory(projectName).existsSync()) {
    Logger.error('flutter create failed.');
    exit(1);
  }
  Logger.success('Flutter project created');

  // Step 2: Add dependencies
  Logger.step('Adding dependencies...');
  await runOrFail(
    'flutter',
    [
      'pub',
      'add',
      'provider',
      'http',
      'shared_preferences',
      'hive_ce',
      'hive_ce_flutter'
    ],
    workingDirectory: projectName,
  );
  Logger.success('Dependencies added');

  // Step 3: Scaffold architecture
  Logger.step('Scaffolding Karna MVC architecture...');
  await _scaffoldCore(projectName);
  Logger.success('Core architecture scaffolded');

  // Step 4: Clean up default files
  await _cleanup(projectName);

  Logger.newLine();
  Logger.info("✨ Karna MVC project '$projectName' created successfully!");
  Logger.newLine();
  Logger.info('📝 Next steps:');
  Logger.info('   cd $projectName');
  Logger.info('   karna feature auth');
  Logger.info(
      '   flutter run --dart-define=BASE_URL=http://localhost:8080/api');
}

Future<void> _scaffoldCore(String root) async {
  final dirs = [
    'lib/core/config',
    'lib/core/controller',
    'lib/core/di',
    'lib/core/errors',
    'lib/core/events',
    'lib/core/memory',
    'lib/core/network',
    'lib/core/notification',
    'lib/core/result',
    'lib/core/routes',
    'lib/core/storage',
    'lib/core/theme',
    'lib/core/widgets',
    'lib/features',
    'test/features',
  ];

  for (final dir in dirs) {
    await Directory('$root/$dir').create(recursive: true);
  }

  // Write all template files
  final files = projectFiles();
  for (final entry in files.entries) {
    await File('$root/${entry.key}').writeAsString(entry.value);
  }
}

Future<void> _cleanup(String root) async {
  // Remove default test
  final defaultTest = File('$root/test/widget_test.dart');
  if (defaultTest.existsSync()) await defaultTest.delete();
}
