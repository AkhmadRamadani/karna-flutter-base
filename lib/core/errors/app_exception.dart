/// Base exception class for the application.
class AppException implements Exception {
  final String message;
  final String? code;

  const AppException({required this.message, this.code});

  @override
  String toString() => 'AppException($code): $message';
}

/// Thrown when a network request fails.
class NetworkException extends AppException {
  const NetworkException({required super.message, super.code});
}

/// Thrown when server returns an error response.
class ServerException extends AppException {
  final int? statusCode;

  const ServerException({required super.message, super.code, this.statusCode});
}

/// Thrown when local cache/storage fails.
class CacheException extends AppException {
  const CacheException({required super.message, super.code});
}
