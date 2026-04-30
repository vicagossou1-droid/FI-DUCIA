/// Levée lorsque le fournisseur GPS signale une position fictive (`isMocked`).
class MockLocationException implements Exception {
  const MockLocationException([this.message = 'Mock / fausse localisation détectée.']);

  final String message;

  @override
  String toString() => 'MockLocationException: $message';
}
