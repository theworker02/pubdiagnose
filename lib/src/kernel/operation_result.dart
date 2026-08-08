/// Expected-failure result wrapper (exceptions reserved for exceptional cases).
sealed class OperationResult<T> {
  const OperationResult();

  /// Successful value.
  factory OperationResult.ok(T value) = OperationSuccess<T>;

  /// Expected failure.
  factory OperationResult.fail(
    String message, {
    String? code,
    Object? cause,
    bool retryable = false,
  }) {
    return OperationFailure<T>(
      message,
      code: code,
      cause: cause,
      retryable: retryable,
    );
  }

  /// Whether successful.
  bool get isOk;

  /// Whether failed.
  bool get isFailure => !isOk;

  /// Value or null.
  T? get valueOrNull;

  /// Map success value.
  OperationResult<R> map<R>(R Function(T value) transform);

  /// Fold into a single value.
  R when<R>({
    required R Function(T value) ok,
    required R Function(OperationFailure<T> failure) fail,
  });
}

/// Successful [OperationResult].
final class OperationSuccess<T> extends OperationResult<T> {
  /// Creates a success.
  const OperationSuccess(this.value);

  /// Result value.
  final T value;

  @override
  bool get isOk => true;

  @override
  T? get valueOrNull => value;

  @override
  OperationResult<R> map<R>(R Function(T value) transform) =>
      OperationResult.ok(transform(value));

  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(OperationFailure<T> failure) fail,
  }) =>
      ok(value);
}

/// Failed [OperationResult].
final class OperationFailure<T> extends OperationResult<T> {
  /// Creates a failure.
  const OperationFailure(
    this.message, {
    this.code,
    this.cause,
    this.retryable = false,
  });

  /// Human-readable message.
  final String message;

  /// Stable code (diagnostic / PD*).
  final String? code;

  /// Underlying cause.
  final Object? cause;

  /// Whether the caller may retry.
  final bool retryable;

  @override
  bool get isOk => false;

  @override
  T? get valueOrNull => null;

  @override
  OperationResult<R> map<R>(R Function(T value) transform) => OperationFailure(
        message,
        code: code,
        cause: cause,
        retryable: retryable,
      );

  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(OperationFailure<T> failure) fail,
  }) =>
      fail(this);

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'ok': false,
        'message': message,
        if (code != null) 'code': code,
        'retryable': retryable,
      };
}
