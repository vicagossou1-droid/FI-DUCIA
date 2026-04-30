/// Résultat typé pour flux async (pas de dépendance `Either` externe).
sealed class Result<T, E> {
  const Result._();

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  T? get valueOrNull => switch (this) {
        Success<T, E>(:final T value) => value,
        Failure<T, E>() => null,
      };

  E? get errorOrNull => switch (this) {
        Success<T, E>() => null,
        Failure<T, E>(:final E error) => error,
      };

  R fold<R>({required R Function(T value) onSuccess, required R Function(E error) onFailure}) {
    return switch (this) {
      Success<T, E>(:final T value) => onSuccess(value),
      Failure<T, E>(:final E error) => onFailure(error),
    };
  }
}

final class Success<T, E> extends Result<T, E> {
  const Success(this.value) : super._();
  final T value;
}

final class Failure<T, E> extends Result<T, E> {
  const Failure(this.error) : super._();
  final E error;
}
