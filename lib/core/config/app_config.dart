/// Environment configuration for the app.
/// Populated from --dart-define flags or .env files.
///
/// Usage in flutter run:
///   flutter run --dart-define=BASE_URL=https://api.example.com
///   flutter run --dart-define=ENV=production
class AppConfig {
  final String baseUrl;
  final String environment;
  final Duration timeout;
  final bool enableLogging;

  const AppConfig({
    required this.baseUrl,
    required this.environment,
    this.timeout = const Duration(seconds: 30),
    this.enableLogging = false,
  });

  /// Create config from dart-define environment variables.
  factory AppConfig.fromEnvironment() {
    const baseUrl = String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'http://localhost:8080',
    );
    const env = String.fromEnvironment('ENV', defaultValue: 'development');
    const timeoutSeconds = int.fromEnvironment('TIMEOUT', defaultValue: 30);
    const enableLogging = bool.fromEnvironment(
      'ENABLE_LOGGING',
      defaultValue: true,
    );

    return AppConfig(
      baseUrl: baseUrl,
      environment: env,
      timeout: Duration(seconds: timeoutSeconds),
      enableLogging: enableLogging,
    );
  }

  /// Whether the app is running in development mode.
  bool get isDevelopment => environment == 'development';

  /// Whether the app is running in staging mode.
  bool get isStaging => environment == 'staging';

  /// Whether the app is running in production mode.
  bool get isProduction => environment == 'production';
}
