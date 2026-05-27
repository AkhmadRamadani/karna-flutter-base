import 'dart:io';

import 'package:args/command_runner.dart';

import '../generators/feature_generator.dart';
import '../util/logger.dart';
import '../util/string_utils.dart';

/// `karna feature <feature_name>`
class FeatureCommand extends Command<int> {
  @override
  String get name => 'feature';

  @override
  String get description => 'Scaffold a new feature in the current project.';

  @override
  String get invocation => 'karna feature <feature_name>';

  FeatureCommand() {
    argParser.addFlag(
      'memory-aware',
      abbr: 'm',
      defaultsTo: false,
      help: 'Use MemoryAwareController instead of BaseController.',
    );
  }

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      Logger.error('Missing feature name.');
      Logger.info('Usage: karna feature <feature_name>');
      return 64;
    }

    final featureName = argResults!.rest.first;
    final memoryAware = argResults!['memory-aware'] as bool;

    if (!isValidSnakeCase(featureName)) {
      Logger.error(
        'Feature name must be snake_case (lowercase letters, numbers, underscores).',
      );
      return 64;
    }

    // Check we're in a Flutter project
    if (!File('pubspec.yaml').existsSync()) {
      Logger.error(
        'Not in a Flutter project. Run this from the project root (where pubspec.yaml is).',
      );
      return 1;
    }

    if (Directory('lib/features/$featureName').existsSync()) {
      Logger.error("Feature '$featureName' already exists.");
      return 1;
    }

    Logger.info('🚀 Creating feature: $featureName');
    Logger.newLine();

    await generateFeature(
      featureName: featureName,
      memoryAware: memoryAware,
    );

    return 0;
  }
}
