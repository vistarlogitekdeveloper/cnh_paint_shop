import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../db/app_database.dart';
import '../network/api_exception.dart';
import '../storage/token_store.dart';

/// ---------------------------------------------------------------------------
/// SyncService — the offline promise, made real.
///
/// The rule the SRS implies and this class enforces: AN OPERATOR'S SAVE NEVER
/// DEPENDS ON THE NETWORK. Every entry is written to the local outbox first and
/// acknowledged immediately; uploading is a separate, retryable concern.
///
/// Why write locally even when online:
///   * The operator gets the same instant confirmation either way, so the flow
///     never changes shape depending on signal — and a save that appeared to
///     work must never turn out not to have.
///   * Plant Wi-Fi drops mid-request. A row already in the outbox survives that;
///     a row that only existed in a pending HTTP call does not.
///
/// Idempotency is the whole reason this is safe. The `client_uuid` is generated
/// on the device before the row is written and is UNIQUE server-side, so the
/// same batch may be replayed any number of times — after a crash, after a
/// timeout that actually succeeded, after a user taps "Sync now" twice — without
/// double-counting stock.
/// ---------------------------------------------------------------------------
class SyncService {
  SyncService({
    required AppDatabase db,
    required SyncRepository sync,
    required NestingRepository nesting,
    required TokenStore tokens,
    Connectivity? connectivity,
    // Positional-private fields would leak the underscores into the public
    // constructor, so these are assigned in the initialiser list.
    // ignore: prefer_initializing_formals
  })  : _db = db,
        // ignore: prefer_initializing_formals
        _sync = sync,
        // ignore: prefer_initializing_formals
        _nesting = nesting,
        // ignore: prefer_initializing_formals
        _tokens = tokens,
        _connectivity = connectivity ?? Connectivity();

  final AppDatabase _db;
  final SyncRepository _sync;
  final NestingRepository _nesting;
  final TokenStore _tokens;
  final Connectivity _connectivity;

  static const _uuid = Uuid();

  /// How many queued operations go up in one request. The server caps the batch
  /// at 500; 50 keeps each request small enough to succeed on a weak link and
  /// lets progress be made incrementally rather than all-or-nothing.
  static const int _batchSize = 50;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;
  bool _flushing = false;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get status => _statusController.stream;

  SyncStatus _status = const SyncStatus();
  SyncStatus get currentStatus => _status;

  void _emit(SyncStatus next) {
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  /// Starts watching connectivity and schedules a periodic drain.
  void start() {
    _connectivitySub ??= _connectivity.onConnectivityChanged.listen((results) {
      final online = _isOnline(results);
      _emit(_status.copyWith(online: online));
      // Coming back online is the single best moment to flush — the queue is
      // exactly what has been accumulating while there was no link.
      if (online) flush();
    });

    // A heartbeat so a `failed` row whose backoff has elapsed is retried even if
    // connectivity never changes and the user never opens the queue screen.
    _periodicTimer ??= Timer.periodic(const Duration(minutes: 2), (_) => flush());

    // Seed the initial state; connectivity_plus does not replay it.
    _connectivity.checkConnectivity().then((results) {
      _emit(_status.copyWith(online: _isOnline(results)));
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _periodicTimer?.cancel();
    _statusController.close();
  }

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);

  Future<bool> isOnline() async => _isOnline(await _connectivity.checkConnectivity());

  /// Live count of everything not yet accepted by the server, for the badge.
  Stream<int> watchPendingCount() => _db.watchPendingCount();

  Stream<List<OutboxRow>> watchQueue() => _db.watchQueue();

  // -------------------------------------------------------------------------
  // Enqueue
  // -------------------------------------------------------------------------

  /// Queues a nesting receipt and returns the generated client_uuid.
  ///
  /// The caller shows its confirmation as soon as this returns. Whether the row
  /// has reached the server yet is deliberately not part of that promise.
  Future<String> queueNesting({
    required String partId,
    required int quantity,
    required String summary,
    String? lineId,
    String? patternId,
    String? nestingFrameNo,
    String? photoClientUuid,
    String? machineNo,
    String? patternTxnId,
    int? requiredQty,
    String? reason,
    String? shade,
    double? plannedSurface,
    double? actualSurface,
    bool isNonStandard = false,
    int? shift,
    String? userId,
  }) async {
    final clientUuid = _uuid.v4();
    await _db.enqueue(
      clientUuid: clientUuid,
      kind: OutboxKind.nesting,
      summary: summary,
      userId: userId,
      payload: {
        'part_id': partId,
        'quantity': quantity,
        if (lineId != null) 'line_id': lineId,
        if (patternId != null) 'pattern_id': patternId,
        if (nestingFrameNo != null && nestingFrameNo.isNotEmpty)
          'nesting_frame_no': nestingFrameNo,
        if (photoClientUuid != null) 'photo_client_uuid': photoClientUuid,
        // Backend needs a `machine_no` column on nesting_entries to persist
        // this permanently; until then the field rides in the outbox payload
        // and reaches the server. It will land in the row once the column
        // exists — no client change required for that day.
        if (machineNo != null && machineNo.isNotEmpty) 'machine_no': machineNo,
        if (patternTxnId != null && patternTxnId.isNotEmpty) 'pattern_txn_id': patternTxnId,
        if (requiredQty != null) 'required_qty': requiredQty,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (shade != null && shade.isNotEmpty) 'shade': shade,
        if (plannedSurface != null) 'planned_surface': plannedSurface,
        if (actualSurface != null) 'actual_surface': actualSurface,
        'is_non_standard': isNonStandard,
        if (shift != null) 'shift': shift,
        // The moment the operator actually saved. The server clamps this to a
        // sane window, so a device with a wrong clock cannot backdate a receipt
        // into last month.
        'entry_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
    // Fire and forget: the confirmation must not wait on the upload.
    flush();
    return clientUuid;
  }

  Future<String> queuePatternRun({
    required String patternId,
    required int frameCount,
    required String summary,
    String? lineId,
    String? shade,
    bool isNonStandard = false,
    int? shift,
    String? userId,
  }) async {
    final clientUuid = _uuid.v4();
    await _db.enqueue(
      clientUuid: clientUuid,
      kind: OutboxKind.patternRun,
      summary: summary,
      userId: userId,
      payload: {
        'pattern_id': patternId,
        'frame_count': frameCount,
        if (lineId != null) 'line_id': lineId,
        if (shade != null && shade.isNotEmpty) 'shade': shade,
        'is_non_standard': isNonStandard,
        if (shift != null) 'shift': shift,
        'run_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
    flush();
    return clientUuid;
  }

  Future<String> queueRequest({
    required RequestType type,
    required String summary,
    String? lineId,
    String? partId,
    String? patternId,
    int? quantity,
    String? reason,
    String? userId,
  }) async {
    final clientUuid = _uuid.v4();
    await _db.enqueue(
      clientUuid: clientUuid,
      kind: OutboxKind.request,
      summary: summary,
      userId: userId,
      payload: {
        'type': type.wire,
        if (lineId != null) 'line_id': lineId,
        if (partId != null) 'part_id': partId,
        if (patternId != null) 'pattern_id': patternId,
        if (quantity != null) 'quantity': quantity,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    flush();
    return clientUuid;
  }

  Future<String> queueMachineBuilt({
    required String machineId,
    required String summary,
    String? userId,
  }) async {
    final clientUuid = _uuid.v4();
    await _db.enqueue(
      clientUuid: clientUuid,
      kind: OutboxKind.machineBuilt,
      summary: summary,
      userId: userId,
      payload: {'machine_id': machineId},
    );
    flush();
    return clientUuid;
  }

  /// Uploads queued pallet photos.
  ///
  /// Deliberately AFTER the outbox drain and deliberately not fatal: a photo
  /// that will not upload must never hold back the receipts, which are the
  /// rows that actually move stock. Order does not matter to the server —
  /// entries carry the photo's client_uuid as a plain value, so the two halves
  /// can arrive in either sequence.
  Future<void> _flushPhotos() async {
    while (true) {
      final batch = await _db.pendingPhotoBatch();
      if (batch.isEmpty) return;

      for (final photo in batch) {
        try {
          await _nesting.uploadPhoto(
            clientUuid: photo.clientUuid,
            bytes: photo.bytes,
            mimeType: photo.mimeType,
            capturedAt: photo.capturedAt,
            lineId: photo.lineId,
            patternId: photo.patternId,
            nestingFrameNo: photo.nestingFrameNo,
          );
          // Server has the bytes; the local megabyte has no further use.
          await _db.photoUploaded(photo.clientUuid);
        } catch (error) {
          // Kept, never dropped — this is the operator's only copy.
          await _db.photoFailed(photo.clientUuid, error is ApiException ? error.message : error.toString());
          return; // stop the loop; the next flush retries
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // Flush
  // -------------------------------------------------------------------------

  /// Drains the outbox. Safe to call at any time and from anywhere — concurrent
  /// calls collapse onto the one already running.
  Future<SyncStatus> flush({bool force = false}) async {
    if (_flushing) return _status;

    if (!force && !await isOnline()) {
      _emit(_status.copyWith(online: false));
      return _status;
    }

    _flushing = true;
    _emit(_status.copyWith(syncing: true, lastError: null));

    var totalAccepted = 0;
    var totalConflicts = 0;

    try {
      // Loop so a large backlog drains fully rather than one batch per trigger.
      while (true) {
        final due = await _db.dueForSync(limit: _batchSize);
        if (due.isEmpty) break;

        await _db.markInFlight(due.map((r) => r.id).toList());

        final operations = [
          for (final row in due)
            {
              'client_uuid': row.clientUuid,
              'kind': _wireKind(row.kind),
              'payload': jsonDecode(row.payload),
              'queued_at': row.queuedAt.toUtc().toIso8601String(),
            },
        ];

        try {
          final result = await _sync.flush(operations);

          for (final item in result.results) {
            if (item.isAccepted) {
              totalAccepted += 1;
            } else if (item.isConflict) {
              totalConflicts += 1;
              await _db.markConflict(
                item.clientUuid,
                error: item.error ?? 'The server refused this entry.',
                code: item.code,
                serverState: item.serverState,
              );
            } else {
              await _db.markFailed(
                item.clientUuid,
                error: item.error ?? 'Upload failed.',
                code: item.code,
              );
            }
          }

          final accepted = result.results.where((r) => r.isAccepted).map((r) => r.clientUuid).toList();
          if (accepted.isNotEmpty) await _db.markSynced(accepted);

          // The server may not have echoed every uuid (a truncated response, a
          // proxy). Anything still in-flight goes back to pending rather than
          // being stranded — the client_uuid makes the retry harmless.
          await _db.releaseInFlight();
        } on ApiException catch (e) {
          // The REQUEST failed, not the individual items. Hand the whole batch
          // back so it is retried intact.
          await _db.releaseInFlight();
          _emit(_status.copyWith(syncing: false, lastError: e.message, online: !e.isOffline));
          return _status;
        } catch (e) {
          await _db.releaseInFlight();
          _emit(_status.copyWith(syncing: false, lastError: e.toString()));
          return _status;
        }

        // A short batch means the queue is drained.
        if (due.length < _batchSize) break;
      }

      await _db.purgeSynced();
      await _flushPhotos();
      if (totalAccepted > 0) await _tokens.saveLastSyncAt(DateTime.now());

      _emit(_status.copyWith(
        syncing: false,
        online: true,
        lastSyncAt: totalAccepted > 0 ? DateTime.now() : _status.lastSyncAt,
        lastAccepted: totalAccepted,
        lastConflicts: totalConflicts,
        lastError: null,
      ));
    } finally {
      _flushing = false;
    }

    return _status;
  }

  static String _wireKind(OutboxKind kind) => switch (kind) {
        OutboxKind.nesting => 'nesting',
        OutboxKind.patternRun => 'pattern_run',
        OutboxKind.request => 'request',
        OutboxKind.machineBuilt => 'machine_built',
      };

  // -------------------------------------------------------------------------
  // Conflict handling
  // -------------------------------------------------------------------------

  Future<List<OutboxRow>> conflicts() => _db.conflicts();

  /// Re-queues a conflicted row — after the operator has fixed the cause (the
  /// Planner has now approved the pattern, material has arrived).
  Future<void> retryConflict(int id) async {
    await _db.retryNow(id);
    await flush();
  }

  /// Discards a conflicted row the operator has decided to abandon.
  Future<void> discardConflict(int id) => _db.discard(id);

  // -------------------------------------------------------------------------
  // Master cache
  // -------------------------------------------------------------------------

  /// Pulls the masters the entry screens need offline.
  ///
  /// Delta by default: a returning device asks only for what changed since its
  /// last successful pull, which on a plant network is the difference between a
  /// 2KB response and a 400KB one.
  Future<bool> refreshMasters({bool full = false}) async {
    try {
      final since = full ? null : _tokens.lastSyncAt;
      final data = await _sync.bootstrap(since: since);
      final now = DateTime.now();

      await _db.cacheMasters(
        lines: [
          for (final line in data.lines)
            CachedLine(
              id: line.id,
              code: line.code,
              name: line.name,
              yellowThreshold: line.yellowThreshold,
              redThreshold: line.redThreshold,
              runsDriveConsumption: line.runsDriveConsumption,
              sortOrder: line.sortOrder,
              cachedAt: now,
            ),
        ],
        parts: [
          for (final p in data.parts)
            CachedPart(
              id: p['id']?.toString() ?? '',
              unpaintedPn: p['unpainted_pn']?.toString() ?? '',
              paintedPn: asStringOrNull(p['painted_pn']),
              description: p['description']?.toString() ?? '',
              colorShade: asStringOrNull(p['color_shade']),
              partType: asStringOrNull(p['part_type']),
              station: asStringOrNull(p['station']),
              rackCode: asStringOrNull(p['rack_code']),
              isBulky: asBool(p['is_bulky']),
              availableStock: asDouble(p['available_stock']),
              cachedAt: now,
            ),
        ],
        patterns: [
          for (final pt in data.patterns)
            CachedPattern(
              id: pt['id']?.toString() ?? '',
              lineId: pt['line_id']?.toString() ?? '',
              code: pt['code']?.toString() ?? '',
              name: asStringOrNull(pt['name']),
              plannedSurface: pt['planned_surface'] == null ? null : asDouble(pt['planned_surface']),
              shade: asStringOrNull(pt['shade']),
              isSpecial: asBool(pt['is_special']),
              // A special pattern is only loadable once approved; cache that so
              // the offline entry screen can refuse it the same way the server
              // would rather than queueing something certain to conflict.
              approved: !asBool(pt['is_special']) || pt['approved_at'] != null,
              itemsJson: jsonEncode(pt['items'] ?? const []),
              cachedAt: now,
            ),
        ],
      );

      await _tokens.saveLastSyncAt(data.serverTime);
      return true;
    } catch (e) {
      debugPrint('[sync] master refresh failed: $e');
      return false;
    }
  }

  Future<List<CachedPart>> cachedParts() => _db.allCachedParts();
  Future<List<CachedPart>> searchCachedParts(String term) => _db.searchCachedParts(term);
  Future<List<CachedPattern>> cachedPatterns(String lineId) => _db.cachedPatternsForLine(lineId);
  Future<List<CachedLine>> cachedLines() => _db.allCachedLines();
  Future<bool> hasCachedMasters() => _db.hasCachedMasters();

  /// Queues a pallet photo for upload. Bytes land on disk before this returns,
  /// so the capture survives the app being killed on the walk back.
  Future<void> queuePhoto({
    required String clientUuid,
    required Uint8List bytes,
    required DateTime capturedAt,
    String mimeType = 'image/jpeg',
    String? lineId,
    String? patternId,
    String? nestingFrameNo,
  }) {
    return _db.queuePhoto(
      clientUuid: clientUuid,
      bytes: bytes,
      capturedAt: capturedAt,
      mimeType: mimeType,
      lineId: lineId,
      patternId: patternId,
      nestingFrameNo: nestingFrameNo,
    );
  }

  Future<int> pendingPhotoCount() => _db.pendingPhotoCount();

  /// Called on logout so a shared tablet does not leak one user's queued entries
  /// to whoever signs in next.
  Future<void> wipe() => _db.wipe();
}

/// A snapshot of the sync subsystem, for the offline banner and the queue screen.
@immutable
class SyncStatus {
  const SyncStatus({
    this.online = true,
    this.syncing = false,
    this.lastSyncAt,
    this.lastError,
    this.lastAccepted = 0,
    this.lastConflicts = 0,
  });

  final bool online;
  final bool syncing;
  final DateTime? lastSyncAt;
  final String? lastError;
  final int lastAccepted;
  final int lastConflicts;

  SyncStatus copyWith({
    bool? online,
    bool? syncing,
    DateTime? lastSyncAt,
    String? lastError,
    int? lastAccepted,
    int? lastConflicts,
  }) {
    return SyncStatus(
      online: online ?? this.online,
      syncing: syncing ?? this.syncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      // Explicitly nullable: clearing the error is a real state change.
      lastError: lastError,
      lastAccepted: lastAccepted ?? this.lastAccepted,
      lastConflicts: lastConflicts ?? this.lastConflicts,
    );
  }
}
