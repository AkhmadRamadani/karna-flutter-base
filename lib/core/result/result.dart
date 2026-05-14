import '../errors/app_exception.dart';

/// A typed result that forces explicit error handling.
/// Repositories return [Result] instead of throwing exceptions.
sealed class Result<T> {
  const Result();

  /// Returns true if this is a successful result.
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a failure result.
  bool get isFailure => this is Failure<T>;

  /// Unwraps the data or throws if failure.
  T get data => (this as Success<T>).value;

  /// Unwraps the exception or throws if success.
  AppException get exception => (this as Failure<T>).error;

  /// Pattern match on the result.
  R when<R>({
    required R Function(T data) success,
    required R Function(AppException error) failure,
  }) {
    return switch (this) {
      Success<T>(value: final data) => success(data),
      Failure<T>(error: final error) => failure(error),
    };
  }

  /// Map the success value to a new type.
  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success<T>(value: final data) => Success(transform(data)),
      Failure<T>(error: final error) => Failure(error),
    };
  }
}

/// Represents a successful result with data.
class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

/// Represents a failed result with a typed exception.
class Failure<T> extends Result<T> {
  final AppException error;
  const Failure(this.error);
}
