import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:karna_cli/commands/create_command.dart';
import 'package:karna_cli/commands/feature_command.dart';

void main(List<String> args) async {
  final runner = CommandRunner<int>(
    'karna',
    'Karna MVC — CLI for creating and managing Flutter projects.',
  )
    ..addCommand(CreateCommand())
    ..addCommand(FeatureCommand());

  try {
    final result = await runner.run(args);
    exit(result ?? 0);
  } on UsageException catch (e) {
    stderr.writeln('${e.message}\n');
    stderr.writeln(runner.usage);
    exit(64);
  } catch (e) {
    stderr.writeln('❌ $e');
    exit(1);
  }
}
