import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Web storage.
///
/// Drift on the web needs `sqlite3.wasm` + `drift_worker.js` served alongside
/// the app. Both live in `web/` (see web/README-drift.md).
///
/// They are REQUIRED, not optional. [WasmDatabase.open] fetches those two URIs;
/// if they 404 it throws, and because drift opens lazily the throw surfaces at
/// whatever happens to run the first query rather than at startup. That cost a
/// debugging session once: with the files absent the app logged in fine and
/// then the Log out button did nothing, because the first awaited query was the
/// logout's queue wipe.
///
/// [WasmDatabase.missingFeatures] is a different thing entirely — it reports
/// which browser capabilities (OPFS, SharedWorker, IndexedDB) were unavailable
/// once the files HAVE loaded, and only affects whether the queue survives a
/// page reload. That degradation is acceptable on web and only on web: this
/// target is the planner's and management's desk dashboards, not the shop-floor
/// operators who depend on offline entry. Those run the Android build.
QueryExecutor openAppDatabase() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'cnh_paint_shop',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );

    if (result.missingFeatures.isNotEmpty) {
      // Not fatal — drift picked the best available implementation. Logged so a
      // "my queue emptied on refresh" report is diagnosable.
      // ignore: avoid_print
      print(
        '[db] web storage degraded; missing: ${result.missingFeatures}. '
        'Queued entries may not survive a page reload.',
      );
    }

    return result.resolvedExecutor;
  });
}

QueryExecutor openInMemoryDatabase() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'cnh_paint_shop_test',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
