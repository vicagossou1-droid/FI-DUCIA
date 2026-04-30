sealed class Either<L, R> {
  const Either();

  bool get isLeft => this is Left<L, R>;
  bool get isRight => this is Right<L, R>;

  T fold<T>({
    required T Function(L left) onLeft,
    required T Function(R right) onRight,
  }) {
    final Either<L, R> self = this;
    if (self is Left<L, R>) {
      return onLeft(self.value);
    }
    return onRight((self as Right<L, R>).value);
  }
}

final class Left<L, R> extends Either<L, R> {
  const Left(this.value);
  final L value;
}

final class Right<L, R> extends Either<L, R> {
  const Right(this.value);
  final R value;
}
