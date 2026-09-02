import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the on-disk database on Android, iOS, Windows, macOS and Linux.
///
/// `createInBackground` runs SQLite on its own isolate. That matters on the
/// operator screens: writing the outbox row on the UI isolate would put a disk
/// fsync in the middle of the Save tap, which is exactly the frame the operator
/// is watching.
QueryExecutor openAppDatabase() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'cnh_paint_shop.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

QueryExecutor openInMemoryDatabase() => NativeDatabase.memory();
