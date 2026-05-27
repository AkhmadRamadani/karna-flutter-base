import 'dart:io';

import 'logger.dart';

/// Runs a shell command and streams output.
/// Returns the exit code.
Future<int> runCommand(
  String executable,
  List<String> args, {
  String? workingDirectory,
  bool silent = false,
}) async {
  final process = await Process.start(
    executable,
    args,
    workingDirectory: workingDirectory,
    mode: silent ? ProcessStartMode.normal : ProcessStartMode.inheritStdio,
  );

  return process.exitCode;
}

/// Runs a command and throws if it fails.
Future<void> runOrFail(
  String executable,
  List<String> args, {
  String? workingDirectory,
  String? errorMessage,
  bool silent = false,
}) async {
  final code = await runCommand(
    executable,
    args,
    workingDirectory: workingDirectory,
    silent: silent,
  );

  if (code != 0) {
    Logger.error(
        errorMessage ?? '$executable ${args.join(' ')} failed (exit $code)');
    exit(code);
  }
}
