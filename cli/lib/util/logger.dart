import 'dart:io';

/// Simple CLI logger with colored output.
class Logger {
  static void info(String message) => stdout.writeln(message);
  static void success(String message) => stdout.writeln('  ✅ $message');
  static void warning(String message) => stdout.writeln('  ⚠️  $message');
  static void error(String message) => stderr.writeln('❌ $message');
  static void step(String message) => stdout.writeln('📦 $message');
  static void newLine() => stdout.writeln();
}
