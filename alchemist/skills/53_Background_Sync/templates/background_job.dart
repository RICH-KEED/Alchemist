// =============================================================================
// background_job.dart — Background Sync (#53) template
//
// Covers:
//  - Drift outbox table + DAO
//  - BackgroundSyncService (enqueue, processOutbox)
//  - WorkManager callbackDispatcher
//  - Exponential backoff utility
//  - Initialize function (call once in main())
//
// Dependencies: workmanager, drift, dio, path_provider, sqlite3_flutter_libs
// Pairs with: skill 14 (Network Resilience) and skill 15 (Error Handling)
//
// House style: ../../references/CONVENTIONS.md
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide JsonKey;
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

// ---------------------------------------------------------------------------
// 1. Drift: Outbox table definition
// ---------------------------------------------------------------------------

/// Status of an outbox entry in its lifecycle.
enum OutboxStatus {
  pending,
  processing,
  done,
  failed;
}

/// Persistent queue of operations that must be replayed to the server.
///
/// Paired with [OutboxDao] for typed queries and [BackgroundSyncService] for
/// lifecycle management. Also consumed by skill 14's connectivity-triggered drain.
@DataClassName('OutboxEntryData')
class OutboxEntries extends Table {
  /// Client-generated UUID; doubles as the idempotency key sent to the server.
  @override
  Set<Column> get primaryKey => {id};

  TextColumn get id => text()();

  /// Discriminator: POST, PUT, PATCH, DELETE.
  TextColumn get operationType => text()();

  /// Server path to replay against, e.g. "/api/v1/todos".
  TextColumn get endpoint => text()();

  /// JSON-encoded request body.
  TextColumn get payload => text()();

  /// Unix milliseconds when the entry was queued.
  IntColumn get createdAt => integer()();

  /// Current attempt count. 0 = never attempted.
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Hard cap on retry attempts before dead-letter.
  IntColumn get maxRetries => integer().withDefault(const Constant(5))();

  /// Current lifecycle status.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Most recent error message (nullable).
  TextColumn get lastError => text().nullable()();

  /// Sort by creation time for FIFO drain.
  @override
  List<OrderingTerm<dynamic>>? get defaultOrderBy => [
        orderingTerm(asc: createdAt),
      ];
}

// ---------------------------------------------------------------------------
// 2. Drift: Outbox DAO
// ---------------------------------------------------------------------------

/// Typed queries for [OutboxEntries].
@DriftAccessor(tables: [OutboxEntries])
class OutboxDao extends DatabaseAccessor<AppDatabase>
    with _$OutboxDaoMixin {
  OutboxDao(super.attachedDatabase);

  /// All entries eligible for processing, FIFO order.
  Future<List<OutboxEntryData>> get pending =>
      (select(outboxEntries)
            ..where((t) => t.status.isIn([
                  OutboxStatus.pending.name,
                  OutboxStatus.processing.name,
                ]))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .get();

  /// Insert a new entry (status defaults to pending via table definition).
  Future<void> enqueue(Insertable<OutboxEntryData> entry) =>
      into(outboxEntries).insert(entry);

  /// Mark an entry as successfully replayed.
  Future<void> markDone(String id) =>
      (update(outboxEntries)..where((t) => t.id.equals(id))).write(
        OutboxEntriesCompanion(status: Value(OutboxStatus.done.name)),
      );

  /// Increment retryCount and record the error.
  ///
  /// If retryCount reaches maxRetries, marks the entry as failed (dead-letter).
  Future<void> bumpRetry(String id, String errorMessage) async {
    final entry = await (select(outboxEntries)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (entry == null) return;

    final nextCount = entry.retryCount + 1;
    final isDead = nextCount >= entry.maxRetries;

    await (update(outboxEntries)..where((t) => t.id.equals(id))).write(
      OutboxEntriesCompanion(
        retryCount: Value(nextCount),
        lastError: Value(errorMessage),
        status: Value(isDead ? OutboxStatus.failed.name : OutboxStatus.pending.name),
      ),
    );
  }

  /// Count of entries by status — useful for badges and debugging.
  Future<Map<String, int>> countByStatus() async {
    final rows = await (selectOnly(outboxEntries)
          ..addColumns([outboxEntries.status, outboxEntries.status.count()])
          ..groupBy([outboxEntries.status]))
        .map((r) => (r.read(outboxEntries.status)!, r.read(outboxEntries.status.count())!))
        .get();
    return {for (final (s, c) in rows) s: c};
  }

  /// Purge entries older than [olderThan] with status 'done'.
  Future<int> purgeDone(DateTime olderThan) =>
      (delete(outboxEntries)
            ..where(
              (t) => t.status.equals(OutboxStatus.done.name) &
                  t.createdAt.isSmallerThanValue(olderThan.millisecondsSinceEpoch),
            ))
          .go();
}

// ---------------------------------------------------------------------------
// 3. Exponential backoff utility
// ---------------------------------------------------------------------------

/// Full-jitter exponential backoff.
///
/// Formula: `min(cap, random(0, base * 2^attempt))`.
///
/// Used by both skill 14's [RetryInterceptor] and skill 53's deferred retries.
class BackoffStrategy {
  final Duration base;
  final Duration cap;

  const BackoffStrategy({
    this.base = const Duration(seconds: 1),
    this.cap = const Duration(seconds: 60),
  });

  /// Compute the delay in milliseconds for the given [attempt] (0-based).
  int computeMs(int attempt) {
    final range = (base.inMilliseconds * (1 << attempt)).toInt();
    final capped = range.clamp(0, cap.inMilliseconds);
    // Full jitter: random uniform in [0, capped]
    final rng = Rng();
    return rng.nextInt(capped + 1);
  }

  /// Convenience: return a Duration.
  Duration compute(int attempt) => Duration(milliseconds: computeMs(attempt));
}

/// Simple xorshift-based random. No dependency on dart:math (isolate-safe).
class Rng {
  int _state = DateTime.now().microsecondsSinceEpoch;

  int nextInt(int max) {
    if (max <= 0) return 0;
    _state ^= _state << 13;
    _state ^= _state >> 17;
    _state ^= _state << 5;
    return (_state.abs()) % max;
  }
}

// ---------------------------------------------------------------------------
// 4. BackgroundSyncService
// ---------------------------------------------------------------------------

/// Manages the outbox lifecycle: enqueue, periodic flush, retry, dead-letter.
///
/// Constructed as a singleton to simplify access from both the UI isolate
/// (enqueue calls from repositories) and the background isolate
/// (processOutbox via callbackDispatcher).
class BackgroundSyncService {
  BackgroundSyncService._();

  static final BackgroundSyncService instance = BackgroundSyncService._();

  AppDatabase? _db;
  OutboxDao? _dao;
  BackoffStrategy _backoff = const BackoffStrategy();

  AppDatabase get db {
    final d = _db;
    if (d == null) throw StateError('BackgroundSyncService not initialized');
    return d;
  }

  OutboxDao get dao {
    final d = _dao;
    if (d == null) throw StateError('BackgroundSyncService not initialized');
    return d;
  }

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  /// Call once after WidgetsFlutterBinding.ensureInitialized() in main().
  ///
  /// Opens a Drift database that can be used from both the UI isolate and
  /// the WorkManager isolate (via `sqlite3_flutter_libs`).
  Future<void> initialize({BackoffStrategy? backoff}) async {
    if (backoff != null) _backoff = backoff;

    final dbPath =
        (await getApplicationDocumentsDirectory()).path + '/app.db';
    _db = AppDatabase(NativeDatabase(File(dbPath)));
    _dao = OutboxDao(_db!);
  }

  // ---------------------------------------------------------------------------
  // Enqueue
  // ---------------------------------------------------------------------------

  /// Queue an operation for background replay.
  ///
  /// Called from repository layer when the device is offline or a write fails
  /// with a transient error that #14 can't retry (e.g., max retries exhausted).
  ///
  /// [id] doubles as the idempotency key sent to the server.
  Future<void> enqueue({
    required String id,
    required String operationType,
    required String endpoint,
    required String payload,
    int maxRetries = 5,
  }) async {
    await dao.enqueue(
      OutboxEntriesCompanion.insert(
        id: id,
        operationType: operationType,
        endpoint: endpoint,
        payload: payload,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        maxRetries: maxRetries,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Process (runs in the WorkManager isolate)
  // ---------------------------------------------------------------------------

  /// Drain all pending outbox entries in FIFO order.
  ///
  /// Called from [callbackDispatcher] — runs on a Dart isolate, NOT the UI
  /// thread. Constructs a standalone Dio client (Riverpod is unavailable).
  ///
  /// Returns the number of entries processed.
  Future<int> processOutbox() async {
    final entries = await dao.pending;
    if (entries.isEmpty) return 0;

    // Construct a fresh dio client for the background isolate.
    // The isolate has no access to Riverpod providers or the app's singleton.
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));

    int processed = 0;
    for (final entry in entries) {
      try {
        // Set status to processing to prevent double-drain.
        await (db.update(db.outboxEntries)
              ..where((t) => t.id.equals(entry.id)))
            .write(const OutboxEntriesCompanion(
              status: Value(OutboxStatus.processing.name),
            ));

        // Replay the HTTP call with the idempotency key as a header.
        final options = Options(
          method: entry.operationType,
          headers: {
            'Content-Type': 'application/json',
            'Idempotency-Key': entry.id,
          },
        );

        final response = await dio.request<dynamic>(
          entry.endpoint,
          data: entry.payload,
          options: options,
        );

        if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
          await dao.markDone(entry.id);
          processed++;
        } else if (_isRetryable(response.statusCode)) {
          await dao.bumpRetry(
            entry.id,
            'HTTP ${response.statusCode}: ${response.statusMessage}',
          );
          // Apply backoff before processing the next entry.
          await Future<void>.delayed(_backoff.compute(entry.retryCount + 1));
        } else {
          // Non-retryable client error — dead-letter immediately.
          await (db.update(db.outboxEntries)
                ..where((t) => t.id.equals(entry.id)))
              .write(
            OutboxEntriesCompanion(
              status: Value(OutboxStatus.failed.name),
              lastError: Value('HTTP ${response.statusCode}: ${response.statusMessage}'),
            ),
          );
        }
      } on DioException catch (e) {
        if (_isRetryable(e.response?.statusCode)) {
          await dao.bumpRetry(entry.id, e.message ?? 'Unknown dio error');
          await Future<void>.delayed(_backoff.compute(entry.retryCount + 1));
        } else {
          await (db.update(db.outboxEntries)
                ..where((t) => t.id.equals(entry.id)))
              .write(
            OutboxEntriesCompanion(
              status: Value(OutboxStatus.failed.name),
              lastError: Value(e.message ?? 'Unknown dio error'),
            ),
          );
        }
      } on Exception catch (e) {
        await dao.bumpRetry(entry.id, e.toString());
        await Future<void>.delayed(_backoff.compute(entry.retryCount + 1));
      }
    }

    return processed;
  }

  // ---------------------------------------------------------------------------
  // Dead-letter inspection
  // ---------------------------------------------------------------------------

  /// Returns all entries that have exhausted retries (status = 'failed').
  Future<List<OutboxEntryData>> get deadLetters =>
      (db.select(db.outboxEntries)
            ..where((t) => t.status.equals(OutboxStatus.failed.name)))
          .get();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// True if the status code represents a transient failure worth retrying.
  bool _isRetryable(int? statusCode) {
    if (statusCode == null) return true; // network error = retryable
    return statusCode == 408 || // Request Timeout
        statusCode == 429 || // Too Many Requests
        statusCode == 500 || // Internal Server Error
        statusCode == 502 || // Bad Gateway
        statusCode == 503 || // Service Unavailable
        statusCode == 504; // Gateway Timeout
  }
}

// ---------------------------------------------------------------------------
// 5. WorkManager callback dispatcher
// ---------------------------------------------------------------------------

/// Top-level entry point for background execution.
///
/// WorkManager calls this function in a separate Dart isolate.
/// Must be a top-level or static function — NOT a closure or lambda.
/// The [@pragma] annotation prevents tree-shaking in release builds.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    switch (taskName) {
      case 'outbox-flush':
        try {
          // The service singleton's db/dao need to be re-initialized in this
          // isolate (isolates don't share memory). If initialize() was not yet
          // called here, processOutbox will fail with a StateError.
          // In a real app, open a fresh DB connection in the background isolate
          // or use a separate initialization path that doesn't rely on
          // path_provider (which uses platform channels).
          //
          // Production alternative: pass the database path via inputData and
          // open NativeDatabase directly without path_provider.
          await BackgroundSyncService.instance.processOutbox();
          return true;
        } on Exception catch (e, st) {
          // Log the failure (logger / Sentry unavailable in isolate).
          // In production, write to a file or use isolate-safe logging.
          debugPrint('[background_sync] processOutbox failed: $e\n$st');
          return false; // false = retry later per WorkManager backoff
        }
      default:
        return true;
    }
  });
}

// ---------------------------------------------------------------------------
// 6. Initialization (call once in main())
// ---------------------------------------------------------------------------

/// Bootstrap background sync. Call after `WidgetsFlutterBinding.ensureInitialized()`.
///
/// 1. Opens the Drift database.
/// 2. Initializes WorkManager with the callback dispatcher.
/// 3. Registers the periodic outbox-flush task.
/// 4. Optionally registers a one-off task for immediate processing.
Future<void> initializeBackgroundSync({bool isDebug = false}) async {
  // 1. Open the database.
  await BackgroundSyncService.instance.initialize();

  // 2. Initialize WorkManager.
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: isDebug,
  );

  // 3. Register the periodic task.
  await Workmanager().registerPeriodicTask(
    'outbox-flush-1',
    'outbox-flush',
    tag: 'background-sync',
    frequency: const Duration(minutes: 15),
    constraints: const Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 1),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}

// ---------------------------------------------------------------------------
// 7. Database class (Drift boilerplate)
// ---------------------------------------------------------------------------

/// Drift database holding the outbox table.
///
/// In a real project, this would be merged into the app's central database
/// (from skill 11/15) rather than existing as a standalone instance.
@DriftDatabase(tables: [OutboxEntries], daos: [OutboxDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
