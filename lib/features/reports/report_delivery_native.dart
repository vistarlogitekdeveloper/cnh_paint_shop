import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes the report to a temp file and opens the share sheet.
///
/// Returns a short line for the confirmation toast.
///
/// The temp file is deliberately left in place: the share sheet hands the path
/// to another app (WhatsApp, Gmail) which reads it asynchronously, so deleting
/// it here would race that read. The OS reclaims the temp directory.
Future<String> deliverReport({
  required List<int> bytes,
  required String filename,
  required String mimeType,
  required String subject,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, filename));
  await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);

  final result = await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType, name: filename)],
    subject: subject,
    text: subject,
    fileNameOverrides: [filename],
  );

  return switch (result.status) {
    ShareResultStatus.success => 'Shared $filename',
    ShareResultStatus.dismissed => 'Saved as $filename — sharing was cancelled',
    ShareResultStatus.unavailable => 'Saved to this device as $filename',
  };
}
