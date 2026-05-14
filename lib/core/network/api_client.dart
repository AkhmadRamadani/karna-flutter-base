import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../errors/app_exception.dart';

/// A thin HTTP client wrapper that handles:
/// - Base URL resolution
/// - Auth token injection
/// - Retry logic for transient failures
/// - Consistent error mapping to AppException types
class ApiClient {
  final http.Client _client;
  final AppConfig _config;
  String? _authToken;

  ApiClient({required AppConfig config, http.Client? client})
    : _config = config,
      _client = client ?? http.Client();

  /// Set the auth token for subsequent requests.
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// GET request.
  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParams);
    final response = await _executeWithRetry(
      () => _client.get(uri, headers: _buildHeaders(headers)),
    );
    return _handleResponse(response);
  }

  /// POST request.
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, null);
    final response = await _executeWithRetry(
      () => _client.post(
        uri,
        headers: _buildHeaders(headers),
        body: body is String ? body : jsonEncode(body),
      ),
    );
    return _handleResponse(response);
  }

  /// PUT request.
  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, null);
    final response = await _executeWithRetry(
      () => _client.put(
        uri,
        headers: _buildHeaders(headers),
        body: body is String ? body : jsonEncode(body),
      ),
    );
    return _handleResponse(response);
  }

  /// DELETE request.
  Future<dynamic> delete(String path, {Map<String, String>? headers}) async {
    final uri = _buildUri(path, null);
    final response = await _executeWithRetry(
      () => _client.delete(uri, headers: _buildHeaders(headers)),
    );
    return _handleResponse(response);
  }

  /// Build the full URI from path and optional query params.
  Uri _buildUri(String path, Map<String, String>? queryParams) {
    final baseUri = Uri.parse(_config.baseUrl);
    return baseUri.replace(
      path: '${baseUri.path}$path',
      queryParameters: queryParams,
    );
  }

  /// Build headers with auth token and content type.
  Map<String, String> _buildHeaders(Map<String, String>? extra) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?extra,
    };

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  /// Execute a request with retry logic for transient failures.
  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function() request, {
    int maxRetries = 2,
  }) async {
    int attempts = 0;

    while (true) {
      try {
        attempts++;
        return await request().timeout(_config.timeout);
      } on SocketException {
        if (attempts > maxRetries) {
          throw const NetworkException(
            message: 'No internet connection',
            code: 'NO_CONNECTION',
          );
        }
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      } on HttpException {
        if (attempts > maxRetries) {
          throw const NetworkException(
            message: 'Network request failed',
            code: 'HTTP_ERROR',
          );
        }
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
  }

  /// Parse response and map HTTP errors to typed exceptions.
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    switch (statusCode) {
      case 401:
        throw const ServerException(
          message: 'Unauthorized — please log in again',
          code: 'UNAUTHORIZED',
          statusCode: 401,
        );
      case 403:
        throw const ServerException(
          message: 'Forbidden — you do not have access',
          code: 'FORBIDDEN',
          statusCode: 403,
        );
      case 404:
        throw const ServerException(
          message: 'Resource not found',
          code: 'NOT_FOUND',
          statusCode: 404,
        );
      case 422:
        throw ServerException(
          message: _extractErrorMessage(response.body) ?? 'Validation failed',
          code: 'VALIDATION_ERROR',
          statusCode: 422,
        );
      case 429:
        throw const ServerException(
          message: 'Too many requests — please try again later',
          code: 'RATE_LIMITED',
          statusCode: 429,
        );
      default:
        if (statusCode >= 500) {
          throw ServerException(
            message: 'Server error — please try again later',
            code: 'SERVER_ERROR',
            statusCode: statusCode,
          );
        }
        throw ServerException(
          message: 'Unexpected error (HTTP $statusCode)',
          code: 'UNKNOWN',
          statusCode: statusCode,
        );
    }
  }

  /// Try to extract an error message from a JSON response body.
  String? _extractErrorMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        return json['message'] as String? ??
            json['error'] as String? ??
            json['detail'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Dispose the underlying HTTP client.
  void dispose() {
    _client.close();
  }
}
