import 'dart:io';

import 'package:args/command_runner.dart';

import '../generators/project_generator.dart';
import '../util/logger.dart';
import '../util/string_utils.dart';

/// `karna create <project_name>`
class CreateCommand extends Command<int> {
  @override
  String get name => 'create';

  @override
  String get description => 'Create a new Karna MVC Flutter project.';

  @override
  String get invocation => 'karna create <project_name> [--org com.example]';

  CreateCommand() {
    argParser.addOption(
      'org',
      abbr: 'o',
      defaultsTo: 'com.example',
      help: 'Organization identifier for the Flutter project.',
    );
  }

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      Logger.error('Missing project name.');
      Logger.info('Usage: karna create <project_name> [--org com.example]');
      return 64;
    }

    final projectName = argResults!.rest.first;
    final org = argResults!['org'] as String;

    if (!isValidSnakeCase(projectName)) {
      Logger.error(
        'Project name must be snake_case (lowercase letters, numbers, underscores).',
      );
      return 64;
    }

    if (Directory(projectName).existsSync()) {
      Logger.error("Directory '$projectName' already exists.");
      return 1;
    }

    Logger.info('🚀 Creating Karna MVC project: $projectName');
    Logger.info('   Organization: $org');
    Logger.newLine();

    await generateProject(projectName: projectName, org: org);

    return 0;
  }
}
