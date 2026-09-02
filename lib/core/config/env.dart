import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Values come from `--dart-define`, so one binary can point at local, staging
/// or production without a code change and without secrets in the repo:
///
///   flutter run --dart-define=API_BASE_URL=http://10.240.163.50:5000
///   flutter build web --dart-define=API_BASE_URL=https://api.vistarlogitek.com
abstract final class Env {
  /// The CRM host. The module path is appended by [apiBaseUrl].
  static const String host = String.fromEnvironment(
    'API_BASE_URL',
    // The deployed CRM, so the app works out of the box on any machine without
    // a backend running locally. A wrong default here is expensive: nothing
    // answers, and the client reports it as the offline banner rather than as a
    // misconfiguration anyone can read.
    //
    // To work against a local CRM instead (it listens on 3000 — its env schema
    // default, `.env` and `.env.example` all agree):
    //   flutter run --dart-define=API_BASE_URL=http://localhost:3000
    defaultValue: 'https://api.vistarlogitek.com',
  );

  static const String modulePath = '/api/v1/cnh-paint-shop';

  static String get apiBaseUrl => '$host$modulePath';

  /// Mock mode: the app runs entirely against in-memory fixtures.
  ///
  /// Kept because the build spec asks for "a mock API mode for development" —
  /// it lets the UI be demoed on a laptop with no backend, and lets widget
  /// tests exercise real screens without a server.
  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: false,
  );

  /// Firebase is optional. Without it the app runs fine; only push is lost.
  static const bool enablePush = bool.fromEnvironment(
    'ENABLE_PUSH',
    defaultValue: true,
  );

  static const Duration connectTimeout = Duration(seconds: 20);

  /// Generous on purpose: the shortage matrix computes a full plan walk, and a
  /// plant Wi-Fi dead spot should surface as "slow", not as a failure the
  /// operator has to retry.
  static const Duration receiveTimeout = Duration(seconds: 45);

  /// How often the app polls the badge counters while it is in the foreground.
  static const Duration badgePollInterval = Duration(seconds: 45);

  /// Debounce for search-as-you-type. Long enough to skip intermediate strokes
  /// on a glove-typed part number, short enough to feel live.
  static const Duration searchDebounce = Duration(milliseconds: 320);

  static bool get isDebug => kDebugMode;

  /// A one-line summary for the About / diagnostics panel.
  static String get summary => 'CNH Paint Shop · $host';
}
