import 'dart:typed_data';

// share_plus re-exports XFile from cross_file, so importing it directly would
// be both redundant and an undeclared dependency.
import 'package:share_plus/share_plus.dart';

/// Hands the report to the browser.
///
/// `XFile.fromData` keeps its `name` on web, and share_plus's web implementation
/// falls back to a plain download when the Web Share API is not available —
/// which is the usual case on a desktop browser. Either way the planner ends up
/// with the file, so the toast says "downloaded or shared" rather than promising
/// one specific outcome we cannot guarantee here.
Future<String> deliverReport({
  required List<int> bytes,
  required String filename,
  required String mimeType,
  required String subject,
}) async {
  final result = await Share.shareXFiles(
    [XFile.fromData(Uint8List.fromList(bytes), mimeType: mimeType, name: filename)],
    subject: subject,
    text: subject,
    fileNameOverrides: [filename],
  );

  return switch (result.status) {
    ShareResultStatus.success => 'Shared $filename',
    ShareResultStatus.dismissed => 'Sharing was cancelled — check your downloads for $filename',
    ShareResultStatus.unavailable => '$filename downloaded',
  };
}
