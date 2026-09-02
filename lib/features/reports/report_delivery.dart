/// Delivering an exported report to the user, per platform.
///
/// Split because the two platforms genuinely differ:
///
/// * **Native** — `XFile.fromData` deliberately IGNORES its `name` on everything
///   except web, and carries no real path, so the share sheet would offer a
///   nameless blob. The bytes are written to a temp file first and shared by
///   path, which is what makes "CNH_shortage-tracker_ID10_2026-07-31.xlsx" show
///   up correctly in WhatsApp.
/// * **Web** — there is no filesystem to write to. The bytes are shared as data
///   with `fileNameOverrides`, and share_plus falls back to a browser download
///   when the Web Share API is unavailable (which it is on most desktop
///   browsers).
library;

export 'report_delivery_native.dart'
    if (dart.library.js_interop) 'report_delivery_web.dart';
