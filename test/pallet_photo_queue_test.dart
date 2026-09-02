import 'dart:typed_data';

import 'package:cnh_paint_shop/core/db/app_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The offline promise applied to photographs.
///
/// An operator photographs a pallet in a dead spot on the shop floor. The bytes
/// are the only copy that exists until they upload, so the queue must hold them
/// across a failed upload, a killed app and a retry — and must never store the
/// same capture twice, because these rows are megabytes rather than bytes.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Uint8List jpeg(int size) => Uint8List.fromList(List.filled(size, 0xAB));

  test('a captured photo is queued and readable back', () async {
    await db.queuePhoto(
      clientUuid: 'photo-1',
      bytes: jpeg(2048),
      capturedAt: DateTime(2026, 8, 19, 7, 30),
      lineId: 'line-1',
      nestingFrameNo: 'PF-22',
    );

    final batch = await db.pendingPhotoBatch();
    expect(batch, hasLength(1));
    expect(batch.single.clientUuid, 'photo-1');
    expect(batch.single.bytes, hasLength(2048));
    expect(batch.single.nestingFrameNo, 'PF-22');
    expect(batch.single.mimeType, 'image/jpeg');
    expect(await db.pendingPhotoCount(), 1);
  });

  test('re-queuing the same capture does not store a second copy', () async {
    for (var i = 0; i < 3; i++) {
      await db.queuePhoto(
        clientUuid: 'photo-1',
        bytes: jpeg(1024),
        capturedAt: DateTime(2026, 8, 19),
      );
    }
    // Megabytes, not bytes — a duplicate here is a real cost on a tablet.
    expect(await db.pendingPhotoCount(), 1);
  });

  test('a failed upload keeps the bytes and counts the attempt', () async {
    await db.queuePhoto(
      clientUuid: 'photo-1',
      bytes: jpeg(512),
      capturedAt: DateTime(2026, 8, 19),
    );

    await db.photoFailed('photo-1', 'No connection to the server.');
    await db.photoFailed('photo-1', 'No connection to the server.');

    final row = (await db.pendingPhotoBatch()).single;
    // This is the assertion that matters: the operator's only copy survives.
    expect(row.bytes, hasLength(512));
    expect(row.attempts, 2);
    expect(row.lastError, 'No connection to the server.');
  });

  test('an uploaded photo leaves the queue', () async {
    await db.queuePhoto(
      clientUuid: 'photo-1',
      bytes: jpeg(256),
      capturedAt: DateTime(2026, 8, 19),
    );
    await db.photoUploaded('photo-1');
    expect(await db.pendingPhotoCount(), 0);
  });

  test('the oldest capture uploads first', () async {
    await db.queuePhoto(
      clientUuid: 'newer',
      bytes: jpeg(16),
      capturedAt: DateTime(2026, 8, 19, 10),
    );
    await db.queuePhoto(
      clientUuid: 'older',
      bytes: jpeg(16),
      capturedAt: DateTime(2026, 8, 19, 8),
    );
    final batch = await db.pendingPhotoBatch();
    expect(batch.first.clientUuid, 'older');
  });

  test('logout wipes queued photos with the rest of the device data', () async {
    // A shared shop-floor tablet must not hand one operator's pallet photo to
    // whoever signs in next.
    await db.queuePhoto(
      clientUuid: 'photo-1',
      bytes: jpeg(64),
      capturedAt: DateTime(2026, 8, 19),
    );
    await db.wipe();
    expect(await db.pendingPhotoCount(), 0);
  });
}
