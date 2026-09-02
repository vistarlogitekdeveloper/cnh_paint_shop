import 'dart:convert';

import 'package:drift/drift.dart';

import 'db_opener.dart';

part 'app_database.g.dart';

/// ---------------------------------------------------------------------------
/// The on-device database.
///
/// Two jobs:
///
/// 1. THE OUTBOX. Nesting entries, pattern runs, requests and machine-builds are
///    written HERE FIRST, always — online or not. The sync service drains them to
///    `POST /sync/batch`. This is what makes the SRS's "works offline" promise
///    real rather than aspirational: the operator's save never depends on the
///    network, and a `client_uuid` generated at write time makes the upload
///    idempotent so a replay cannot double-count stock.
///
/// 2. THE MASTER CACHE. Parts, patterns and lines, so the entry screens can be
///    used with no connection at all — an operator cannot pick a part from a
///    dropdown that needs a round-trip to populate.
/// ---------------------------------------------------------------------------

/// What kind of queued operation an outbox row holds. Mirrors the backend's
/// `kind` enum on /sync/batch.
enum OutboxKind { nesting, patternRun, request, machineBuilt }

/// Where a queued row is in its life.
enum OutboxState {
  /// Waiting to upload.
  pending,

  /// Currently being uploaded — set so a second sync pass cannot pick it up.
  inFlight,

  /// The server accepted it (or recognised it as a duplicate).
  synced,

  /// The server refused it for a reason retrying will not fix (stock moved, the
  /// pattern lost its approval). Needs a human.
  conflict,

  /// A transport failure. Retried with backoff.
  failed,
}

@DataClassName('OutboxRow')
class OutboxItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Generated on THIS device before the row is first written. The server's
  /// unique index on it is the idempotency guarantee.
  TextColumn get clientUuid => text().unique()();

  IntColumn get kind => intEnum<OutboxKind>()();

  /// The request body, as JSON.
  TextColumn get payload => text()();

  /// A short human description for the pending-queue screen ("LEVER ×60"), so
  /// the operator can see WHAT is waiting without decoding JSON.
  TextColumn get summary => text().withDefault(const Constant(''))();

  IntColumn get state => intEnum<OutboxState>().withDefault(Constant(OutboxState.pending.index))();

  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get errorCode => text().nullable()();

  /// The server's view when it reported a conflict, so the screen can explain
  /// exactly what changed underneath the operator.
  TextColumn get serverState => text().nullable()();

  DateTimeColumn get queuedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Backoff gate: not retried before this instant.
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  /// Which user queued it. A shared tablet can be handed over mid-shift, and an
  /// entry must stay attributed to whoever actually made it.
  TextColumn get userId => text().nullable()();
}

@DataClassName('CachedPart')
class CachedParts extends Table {
  TextColumn get id => text()();
  TextColumn get unpaintedPn => text()();
  TextColumn get paintedPn => text().nullable()();
  TextColumn get description => text()();
  TextColumn get colorShade => text().nullable()();
  TextColumn get partType => text().nullable()();
  TextColumn get station => text().nullable()();
  TextColumn get rackCode => text().nullable()();
  BoolColumn get isBulky => boolean().withDefault(const Constant(false))();
  RealColumn get availableStock => real().withDefault(const Constant(0))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CachedPattern')
class CachedPatterns extends Table {
  TextColumn get id => text()();
  TextColumn get lineId => text()();
  TextColumn get code => text()();
  TextColumn get name => text().nullable()();
  RealColumn get plannedSurface => real().nullable()();
  TextColumn get shade => text().nullable()();
  BoolColumn get isSpecial => boolean().withDefault(const Constant(false))();
  BoolColumn get approved => boolean().withDefault(const Constant(true))();

  /// The frame's parts as JSON: `[{part_id, seq_no, qty_per_frame}]`. Stored
  /// denormalised because it is always read as a whole frame, never queried
  /// across patterns.
  TextColumn get itemsJson => text().withDefault(const Constant('[]'))();

  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CachedLine')
class CachedLines extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  IntColumn get yellowThreshold => integer().withDefault(const Constant(10))();
  IntColumn get redThreshold => integer().withDefault(const Constant(5))();
  BoolColumn get runsDriveConsumption => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pallet photos waiting to be uploaded.
///
/// A separate table, not a column on [OutboxItems], for two reasons. The
/// migration that adds it cannot touch a row holding an operator's unsynced
/// entry — adding a table is the safest change drift can make. And a photo is
/// megabytes: keeping it out of the outbox means the queue screen, the pending
/// count and every retry keep reading small rows.
///
/// Keyed on the photo's own client_uuid, which the entries reference. The two
/// upload independently and in any order, exactly as the server expects.
class PendingPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Generated on THIS device at capture. The server dedupes on it, so a
  /// retried upload can never store a second copy of the same megabyte.
  TextColumn get clientUuid => text().unique()();

  BlobColumn get bytes => blob()();
  TextColumn get mimeType => text().withDefault(const Constant('image/jpeg'))();

  TextColumn get lineId => text().nullable()();
  TextColumn get patternId => text().nullable()();
  TextColumn get nestingFrameNo => text().nullable()();

  DateTimeColumn get capturedAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [OutboxItems, CachedParts, CachedPatterns, CachedLines, PendingPhotos])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openAppDatabase());

  /// In-memory instance for tests.
  AppDatabase.memory() : super(openInMemoryDatabase());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // v1 -> v2 adds the pallet-photo queue. Creating a table is additive:
        // it cannot corrupt or drop an outbox row, and an operator mid-shift
        // with unsynced entries keeps every one of them. This is the first
        // upgrade this database has ever run, so it deliberately does the
        // smallest possible thing.
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(pendingPhotos);
        },
        beforeOpen: (details) async {
          // Foreign keys are off by default in SQLite.
          await customStatement('PRAGMA foreign_keys = ON');
          // WAL: an operator saving an entry must not block the sync service
          // reading the queue, and vice versa.
          await customStatement('PRAGMA journal_mode = WAL');

          // A crash or a kill mid-upload leaves rows stuck in `inFlight`. On
          // every open, hand them back to `pending` — the client_uuid makes a
          // re-upload safe even if the server did receive the first attempt.
          await (update(outboxItems)..where((t) => t.state.equalsValue(OutboxState.inFlight)))
              .write(OutboxItemsCompanion(
            state: Value(OutboxState.pending),
            updatedAt: Value(DateTime.now()),
          ));
        },
      );

  // -------------------------------------------------------------------------
  // Outbox
  // -------------------------------------------------------------------------

  /// Enqueues an operation. Returns the row id.
  Future<int> enqueue({
    required String clientUuid,
    required OutboxKind kind,
    required Map<String, dynamic> payload,
    required String summary,
    String? userId,
  }) {
    final now = DateTime.now();
    return into(outboxItems).insert(
      OutboxItemsCompanion.insert(
        clientUuid: clientUuid,
        kind: kind,
        payload: jsonEncode(payload),
        summary: Value(summary),
        queuedAt: now,
        updatedAt: now,
        userId: Value(userId),
      ),
      // A re-enqueue of the same client_uuid is a no-op, not a crash: the entry
      // is already queued and must not be duplicated locally either.
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Rows ready to upload, oldest first.
  ///
  /// Order matters: two entries for the same part must reach the server in the
  /// order the operator made them, so the ledger reads chronologically.
  Future<List<OutboxRow>> dueForSync({int limit = 100}) {
    final now = DateTime.now();
    return (select(outboxItems)
          ..where((t) =>
              t.state.equalsValue(OutboxState.pending) |
              (t.state.equalsValue(OutboxState.failed) &
                  (t.nextAttemptAt.isSmallerOrEqualValue(now) | t.nextAttemptAt.isNull())))
          ..orderBy([(t) => OrderingTerm.asc(t.queuedAt)])
          ..limit(limit))
        .get();
  }

  Future<void> markInFlight(List<int> ids) {
    if (ids.isEmpty) return Future.value();
    return (update(outboxItems)..where((t) => t.id.isIn(ids))).write(
      OutboxItemsCompanion(
        state: Value(OutboxState.inFlight),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Accepted by the server. Kept briefly (see [purgeSynced]) so the UI can show
  /// "12 uploaded" rather than silently emptying the list.
  Future<void> markSynced(List<String> clientUuids) {
    if (clientUuids.isEmpty) return Future.value();
    return (update(outboxItems)..where((t) => t.clientUuid.isIn(clientUuids))).write(
      OutboxItemsCompanion(
        state: Value(OutboxState.synced),
        updatedAt: Value(DateTime.now()),
        lastError: const Value(null),
        errorCode: const Value(null),
      ),
    );
  }

  /// Refused for a reason a retry will not fix.
  Future<void> markConflict(
    String clientUuid, {
    required String error,
    String? code,
    Map<String, dynamic>? serverState,
  }) {
    return (update(outboxItems)..where((t) => t.clientUuid.equals(clientUuid))).write(
      OutboxItemsCompanion(
        state: Value(OutboxState.conflict),
        lastError: Value(error),
        errorCode: Value(code),
        serverState: Value(serverState == null ? null : jsonEncode(serverState)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Transport failure — retry with exponential backoff, capped.
  Future<void> markFailed(String clientUuid, {required String error, String? code}) async {
    final row = await (select(outboxItems)..where((t) => t.clientUuid.equals(clientUuid)))
        .getSingleOrNull();
    final attempts = (row?.attempts ?? 0) + 1;

    // 30s, 1m, 2m, 4m, … capped at 15m. Capped because a shop-floor device may
    // be out of range for an hour and should still retry promptly on return.
    final backoffSeconds = (30 * (1 << (attempts - 1).clamp(0, 5))).clamp(30, 900);

    await (update(outboxItems)..where((t) => t.clientUuid.equals(clientUuid))).write(
      OutboxItemsCompanion(
        state: Value(OutboxState.failed),
        attempts: Value(attempts),
        lastError: Value(error),
        errorCode: Value(code),
        nextAttemptAt: Value(DateTime.now().add(Duration(seconds: backoffSeconds))),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Hands a whole in-flight batch back to pending — used when the request
  /// itself failed (no connection), as opposed to individual items being refused.
  Future<void> releaseInFlight() {
    return (update(outboxItems)..where((t) => t.state.equalsValue(OutboxState.inFlight))).write(
      OutboxItemsCompanion(
        state: Value(OutboxState.pending),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// The badge number: everything not yet accepted, INCLUDING conflicts.
  ///
  /// Conflicts count deliberately. They are unresolved work sitting on the
  /// device, and hiding them from the badge is how an entry gets silently lost.
  Stream<int> watchPendingCount() {
    final query = selectOnly(outboxItems)
      ..addColumns([outboxItems.id.count()])
      ..where(outboxItems.state.isNotIn([OutboxState.synced.index]));
    return query.map((row) => row.read(outboxItems.id.count()) ?? 0).watchSingle();
  }

  Stream<List<OutboxRow>> watchQueue() {
    return (select(outboxItems)
          ..where((t) => t.state.isNotIn([OutboxState.synced.index]))
          ..orderBy([(t) => OrderingTerm.asc(t.queuedAt)]))
        .watch();
  }

  Future<List<OutboxRow>> conflicts() {
    return (select(outboxItems)..where((t) => t.state.equalsValue(OutboxState.conflict))).get();
  }

  /// Discards a conflicted row after the operator has acknowledged it.
  Future<void> discard(int id) => (delete(outboxItems)..where((t) => t.id.equals(id))).go();

  /// Retries a conflicted row immediately (after the operator has fixed the
  /// underlying cause — e.g. the Planner has now approved the pattern).
  Future<void> retryNow(int id) {
    return (update(outboxItems)..where((t) => t.id.equals(id))).write(
      OutboxItemsCompanion(
        state: Value(OutboxState.pending),
        nextAttemptAt: const Value(null),
        lastError: const Value(null),
        errorCode: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Removes accepted rows older than [keep]. Called after each sync so the
  /// table does not grow without bound over a year of shifts.
  Future<int> purgeSynced({Duration keep = const Duration(hours: 12)}) {
    final cutoff = DateTime.now().subtract(keep);
    return (delete(outboxItems)
          ..where((t) =>
              t.state.equalsValue(OutboxState.synced) & t.updatedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  // -------------------------------------------------------------------------
  // Master cache
  // -------------------------------------------------------------------------

  /// Replaces the cached masters in one transaction.
  ///
  /// Transactional so a sync interrupted halfway cannot leave the entry screens
  /// showing parts from one bootstrap and patterns from another.
  Future<void> cacheMasters({
    List<CachedPart>? parts,
    List<CachedPattern>? patterns,
    List<CachedLine>? lines,
  }) async {
    await transaction(() async {
      if (parts != null) {
        await batch((b) => b.insertAllOnConflictUpdate(cachedParts, parts));
      }
      if (patterns != null) {
        await batch((b) => b.insertAllOnConflictUpdate(cachedPatterns, patterns));
      }
      if (lines != null) {
        await batch((b) => b.insertAllOnConflictUpdate(cachedLines, lines));
      }
    });
  }

  Future<List<CachedPart>> allCachedParts() =>
      (select(cachedParts)..orderBy([(t) => OrderingTerm.asc(t.unpaintedPn)])).get();

  /// Offline part search — the same three fields the server searches.
  Future<List<CachedPart>> searchCachedParts(String term, {int limit = 30}) {
    final like = '%${term.toLowerCase()}%';
    return (select(cachedParts)
          ..where((t) =>
              t.unpaintedPn.lower().like(like) |
              t.paintedPn.lower().like(like) |
              t.description.lower().like(like))
          ..limit(limit))
        .get();
  }

  Future<List<CachedPattern>> cachedPatternsForLine(String lineId) =>
      (select(cachedPatterns)
            ..where((t) => t.lineId.equals(lineId))
            ..orderBy([(t) => OrderingTerm.asc(t.code)]))
          .get();

  Future<List<CachedLine>> allCachedLines() =>
      (select(cachedLines)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

  Future<bool> hasCachedMasters() async {
    final count = await (selectOnly(cachedParts)..addColumns([cachedParts.id.count()]))
        .map((r) => r.read(cachedParts.id.count()) ?? 0)
        .getSingle();
    return count > 0;
  }

  // -------------------------------------------------------------------------
  // Pallet photos
  // -------------------------------------------------------------------------

  /// Queues a captured photo. Idempotent on clientUuid, like [enqueue].
  Future<void> queuePhoto({
    required String clientUuid,
    required Uint8List bytes,
    required DateTime capturedAt,
    String mimeType = 'image/jpeg',
    String? lineId,
    String? patternId,
    String? nestingFrameNo,
  }) async {
    await into(pendingPhotos).insert(
      PendingPhotosCompanion.insert(
        clientUuid: clientUuid,
        bytes: bytes,
        capturedAt: capturedAt,
        mimeType: Value(mimeType),
        lineId: Value(lineId),
        patternId: Value(patternId),
        nestingFrameNo: Value(nestingFrameNo),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<List<PendingPhoto>> pendingPhotoBatch({int limit = 3}) {
    // Small batches on purpose: these are megabytes each, and a shop-floor
    // uplink that stalls halfway through ten of them helps nobody.
    return (select(pendingPhotos)
          ..orderBy([(t) => OrderingTerm(expression: t.capturedAt)])
          ..limit(limit))
        .get();
  }

  Future<int> pendingPhotoCount() async {
    final count = countAll();
    final row = await (selectOnly(pendingPhotos)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// Called once the server has the bytes. The local copy has no further use —
  /// the photo is re-readable from the API by client_uuid.
  Future<void> photoUploaded(String clientUuid) =>
      (delete(pendingPhotos)..where((t) => t.clientUuid.equals(clientUuid))).go();

  /// Records a failed attempt without dropping the photo — the bytes are the
  /// only copy the operator has, so a failure never discards them.
  Future<void> photoFailed(String clientUuid, String error) async {
    await customUpdate(
      'UPDATE pending_photos SET attempts = attempts + 1, last_error = ? WHERE client_uuid = ?',
      variables: [Variable<String>(error), Variable<String>(clientUuid)],
      updates: {pendingPhotos},
    );
  }

    /// Wipes everything. Used on logout so a shared tablet does not leak one
  /// user's queued entries to the next.
  Future<void> wipe() async {
    await transaction(() async {
      await delete(outboxItems).go();
      await delete(cachedParts).go();
      await delete(cachedPatterns).go();
      await delete(cachedLines).go();
      await delete(pendingPhotos).go();
    });
  }
}
