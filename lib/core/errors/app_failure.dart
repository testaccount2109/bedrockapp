sealed class AppFailure implements Exception {
  const AppFailure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    final detail = cause == null ? '' : ': $cause';
    return '$runtimeType($message$detail)';
  }
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, [super.cause]);
}

final class ProtocolFailure extends AppFailure {
  const ProtocolFailure(super.message, [super.cause]);
}

final class StorageFailure extends AppFailure {
  const StorageFailure(super.message, [super.cause]);
}
