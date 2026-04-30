/// Web: passive SQLite batches are not used.
class SyncBatchService {
  SyncBatchService._();

  static final SyncBatchService instance = SyncBatchService._();

  static const int batchSize = 10;

  Future<void> maybeCreateLocationBatches() async {}
}
