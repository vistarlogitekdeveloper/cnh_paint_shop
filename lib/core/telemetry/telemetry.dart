import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:vistar_event_tracker/vistar_event_tracker.dart'
    show EventType, TrackerConfig, VistarEventTracker, VistarEvents;

import '../config/env.dart';

/// Usage analytics for the CNH Paint Shop app, sent to the in-house event
/// tracker and read in the Platform Console under Analytics > Event tracker.
///
/// Off unless the build is given both:
///   --dart-define=ET_APP_ID=paintshop_app --dart-define=ET_WRITE_KEY=wk_...
/// (register the app in the Platform Console, Settings > Event tracker; the
/// write key only lets a client append events, so it may ship in the app).
/// Optional --dart-define=ET_BASE_URL=... sends a test build's events
/// somewhere other than the API host the app uses (by default, the host of
/// API_BASE_URL, so a UAT build reports to UAT).
///
/// What is sent:
///   * screen views, by route pattern (`/nesting`, `/can-build`; ids, serial
///     numbers and codes replaced with `:id` / `:ref`, query strings dropped)
///   * sign-in / sign-out; the user as `paintshop:<user id>`, with their role
///     as the only trait (the login response carries no organisation code)
///   * named actions from successful API writes (see [_actions]):
///     `nesting_recorded`, `pattern_run_recorded`, `machine_marked_built`, ...
///   * failed API calls (5xx or no connection), and client errors by TYPE
///     only (never the message, which can quote a server reply)
/// Never sent: request or response bodies, names, employee codes, phone
/// numbers, batch / lot / part numbers, machine serials, frame numbers,
/// quantities, notes, photos or any other record content. The entry screens,
/// the camera and the offline queue are not touched: only the resulting
/// successful API call is counted.
///
/// NEVER IN THE WAY OF WORK. Nothing here is awaited by a screen, an entry, a
/// sign-in or a sign-out; start-up waits at most [_initBudget]; every call
/// swallows its own failures; the queue is capped at [_maxQueue] events
/// (oldest dropped) and lives in shared preferences; sending is in the
/// background with the SDK's backoff.
abstract final class Telemetry {
  static const _appId = String.fromEnvironment('ET_APP_ID');
  static const _writeKey = String.fromEnvironment('ET_WRITE_KEY');
  static const _baseUrlOverride = String.fromEnvironment('ET_BASE_URL');
  static const _appVersion = String.fromEnvironment('APP_VERSION');
  static const _initBudget = Duration(seconds: 2);
  static const _maxQueue = 200;

  static bool get enabled => _appId != '' && _writeKey != '';

  static VistarEventTracker get _t => VistarEventTracker.instance;
  static bool get _on => enabled && _t.isInitialized;

  static String? _lastScreen;
  static Future<void>? _resetting;

  static String get _origin {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    final u = Uri.parse(Env.host);
    return '${u.scheme}://${u.authority}';
  }

  static Future<void> init() async {
    if (!enabled) return;
    try {
      await _t
          .init(
            TrackerConfig(
              appId: _appId,
              writeKey: _writeKey,
              baseUrl: _origin,
              appVersion: _appVersion.isEmpty ? null : _appVersion,
              maxQueueSize: _maxQueue,
              // The SDK's own error capture sends the exception message and
              // stack, and a message here can quote a server reply (a part
              // number, a serial). [_captureErrors] sends the type only.
              autoCaptureErrors: false,
            ),
          )
          .timeout(_initBudget);
      _captureErrors();
    } catch (_) {
      // Analytics must never stop the app from starting.
    }
  }

  /// Client errors, by type only. Chains to whatever handled them before (the
  /// app's own FlutterError.onError, installed in main() before this), so the
  /// app's error handling is unchanged.
  static void _captureErrors() {
    if (!_on) return;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      _clientError(details.exception, fatal: false, library: details.library);
      previous?.call(details);
    };
    final dispatcher = PlatformDispatcher.instance;
    final previousAsync = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      _clientError(error, fatal: true);
      return previousAsync?.call(error, stack) ?? false;
    };
  }

  static void _clientError(Object e, {required bool fatal, String? library}) {
    try {
      error(VistarEvents.clientError, {
        'error': e.runtimeType.toString(),
        'library': ?library,
        'fatal': fatal,
      });
    } catch (_) {}
  }

  /// A screen, by its route pattern. Repeats are dropped.
  static void screen(String location) {
    if (!_on) return;
    final name = routePattern(location);
    if (name == _lastScreen) return;
    _lastScreen = name;
    _guard(() => _t.screen(name));
  }

  static void track(String name, [Map<String, dynamic>? properties]) {
    if (_on) _guard(() => _t.track(name, properties: properties));
  }

  static void error(String name, Map<String, dynamic> properties) {
    if (_on) {
      _guard(
        () => _t.track(name, properties: properties, type: EventType.error),
      );
    }
  }

  static void _guard(void Function() fn) {
    try {
      fn();
    } catch (_) {
      // Analytics never surfaces as an app error.
    }
  }

  /// Fire and forget: the sign-in never waits for analytics.
  ///
  /// Called just BEFORE the auth state changes. With no sign-out in flight the
  /// SDK sets the user synchronously (before its first await), so the screen
  /// the sign-in leads to is already attributed to them.
  static void signedIn({required String userId, String? role}) {
    if (!_on || userId.isEmpty) return;
    final id = 'paintshop:$userId';
    final traits = <String, dynamic>{
      if (role != null && role.isNotEmpty) 'role': role,
    };
    final pending = _resetting;
    if (pending == null) {
      _identify(id, traits);
      return;
    }
    // A sign-out just before (a shop-floor tablet changing hands) resets the
    // identity; let it finish so this one is not wiped by it.
    unawaited(() async {
      try {
        await pending.timeout(const Duration(seconds: 5), onTimeout: () {});
      } catch (_) {}
      _identify(id, traits);
    }());
  }

  static void _identify(String id, Map<String, dynamic> traits) {
    try {
      unawaited(_t.identify(id, traits: traits).catchError((Object _) {}));
    } catch (_) {}
  }

  /// Fire and forget: the sign-out never waits for analytics (the SDK's reset
  /// sends what is queued first, which can take a while on a poor network).
  static void signedOut() {
    _lastScreen = null;
    if (!_on) return;
    try {
      late final Future<void> done;
      done = _t.reset().catchError((Object _) {}).whenComplete(() {
        if (identical(_resetting, done)) _resetting = null;
      });
      _resetting = done;
    } catch (_) {}
  }

  /// `/parts/9f3c...-.../ledger?x=1` -> `/parts/:id/ledger`.
  ///
  /// Every static segment of this app's screens and API paths is lower-case
  /// words joined by `-`, `_` or `.` (`pattern-runs`, `fcm-token`,
  /// `cnh-paint-shop`), so anything else is a value and is replaced: digits
  /// only or a UUID -> `:id`; anything else with a digit, a capital or another
  /// character -> `:ref`. That covers machine serial / chassis numbers, part,
  /// pattern, rack and batch codes. The segment after `can-build` is always
  /// a machine serial and is replaced whatever it looks like. The query string
  /// is dropped. An API version segment (`v1`) is kept.
  static String routePattern(String location) {
    final path = Uri.tryParse(location)?.path ?? location.split('?').first;
    final out = <String>[];
    for (final s in path.split('/')) {
      if (s.isEmpty) {
        out.add(s);
      } else if (out.isNotEmpty && out.last == 'can-build') {
        out.add(':ref');
      } else if (RegExp(r'^\d+$').hasMatch(s)) {
        out.add(':id');
      } else if (RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-',
        caseSensitive: false,
      ).hasMatch(s)) {
        out.add(':id');
      } else if (RegExp(r'^v\d{1,2}$').hasMatch(s)) {
        out.add(s);
      } else if (!RegExp(r'^[a-z]+([._-][a-z]+)*$').hasMatch(s)) {
        out.add(':ref');
      } else {
        out.add(s);
      }
    }
    return out.join('/');
  }

  /// Successful API writes worth naming, by method and path (ids stripped).
  /// First match wins; anything else (reads, sign-in / sign-out, the push
  /// token, report exports, unknown paths) is not reported. Paths are relative
  /// to the module base (`/api/v1/cnh-paint-shop`).
  static final List<(String, RegExp, String)> _actions = [
    // Shop floor: nesting, loading, the offline queue
    ('POST', RegExp(r'^/nesting$'), 'nesting_recorded'),
    ('POST', RegExp(r'^/nesting/batch$'), 'nesting_frame_recorded'),
    ('POST', RegExp(r'^/nesting/photos$'), 'pallet_photo_uploaded'),
    ('POST', RegExp(r'^/nesting/:(id|ref)/reverse$'), 'nesting_reversed'),
    ('POST', RegExp(r'^/pattern-runs$'), 'pattern_run_recorded'),
    ('POST', RegExp(r'^/sync/batch$'), 'offline_entries_synced'),
    // Requests and approvals
    ('POST', RegExp(r'^/requests$'), 'request_raised'),
    ('POST', RegExp(r'^/requests/:(id|ref)/approve$'), 'request_approved'),
    ('POST', RegExp(r'^/requests/:(id|ref)/reject$'), 'request_rejected'),
    ('POST', RegExp(r'^/requests/:(id|ref)/cancel$'), 'request_cancelled'),
    // Production plan
    ('POST', RegExp(r'^/machines$'), 'machine_added'),
    ('POST', RegExp(r'^/machines/bulk$'), 'machines_bulk_added'),
    ('POST', RegExp(r'^/machines/reorder$'), 'plan_reordered'),
    ('POST', RegExp(r'^/machines/:(id|ref)/built$'), _built),
    ('POST', RegExp(r'^/machines/:(id|ref)/unbuilt$'), 'machine_unmarked_built'),
    ('PUT', RegExp(r'^/machines/:(id|ref)/overrides$'), 'machine_bom_overridden'),
    // Alerts
    ('POST', RegExp(r'^/alerts/:(id|ref)/acknowledge$'), 'alert_acknowledged'),
    ('POST', RegExp(r'^/alerts/reevaluate$'), 'alerts_reevaluated'),
    // Masters and stock
    ('POST', RegExp(r'^/parts$'), 'part_created'),
    ('PATCH', RegExp(r'^/parts/:(id|ref)$'), 'part_updated'),
    ('POST', RegExp(r'^/parts/:(id|ref)/stock-count$'), 'stock_count_recorded'),
    ('POST', RegExp(r'^/parts/:(id|ref)/adjust$'), 'stock_adjusted'),
    ('POST', RegExp(r'^/patterns$'), 'pattern_created'),
    ('POST', RegExp(r'^/patterns/:(id|ref)/approve$'), 'pattern_approved'),
    ('POST', RegExp(r'^/bom-items$'), 'bom_item_saved'),
    ('POST', RegExp(r'^/racks$'), 'rack_created'),
    (
      'PATCH',
      RegExp(r'^/production-lines/:(id|ref)/thresholds$'),
      'line_thresholds_updated',
    ),
    // Imports: the upload is the checking pass; commit applies it.
    ('POST', RegExp(r'^/imports/:(id|ref)/commit$'), 'import_committed'),
    ('POST', RegExp(r'^/imports/:(id|ref)/cancel$'), 'import_cancelled'),
    ('POST', RegExp(r'^/imports/[a-z]+([._-][a-z]+)*$'), 'import_checked'),
    // Administration
    ('POST', RegExp(r'^/users$'), 'user_created'),
    ('PATCH', RegExp(r'^/users/:(id|ref)$'), 'user_updated'),
    ('POST', RegExp(r'^/users/:(id|ref)/deactivate$'), 'user_deactivated'),
    // Account
    ('POST', RegExp(r'^/auth/change-password$'), 'password_changed'),
  ];

  /// Marking a machine built is named by whether the Planner chose to build
  /// it short, see [actionFor].
  static const _built = '_built';

  /// Writes the server may answer as a replay of one it already has (the same
  /// client_uuid from the offline queue): counted the first time only.
  static const _replayable = {
    'nesting_recorded',
    'pallet_photo_uploaded',
    'pattern_run_recorded',
  };

  /// The business event for a successful API call, or null. [data] is the
  /// response envelope's `data`; only its `duplicate` and
  /// `built_with_shortage` flags are looked at, and nothing from it is sent.
  static String? actionFor(String method, String path, {Object? data}) {
    final pattern = routePattern(path);
    final m = method.toUpperCase();
    for (final (am, re, name) in _actions) {
      if (am != m || !re.hasMatch(pattern)) continue;
      final flags = data is Map ? data : const {};
      if (name == _built) {
        return flags['built_with_shortage'] == true
            ? 'machine_built_with_shortage'
            : 'machine_marked_built';
      }
      if (_replayable.contains(name) && flags['duplicate'] == true) return null;
      return name;
    }
    return null;
  }
}

/// Reports named actions and failed calls from the app's HTTP client
/// (ApiClient). Adds no headers and changes nothing about the request or its
/// handling.
class TelemetryInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    // ApiClient lets a 4xx through validateStatus and its own interceptor,
    // which runs first, turns it into an error before it reaches here; only a
    // 2xx is an action that happened.
    final code = response.statusCode ?? 0;
    if (Telemetry.enabled && code >= 200 && code < 300) {
      String? name;
      try {
        final o = response.requestOptions;
        final body = response.data;
        name = Telemetry.actionFor(
          o.method,
          o.path,
          data: body is Map ? body['data'] : null,
        );
      } catch (_) {}
      if (name != null) Telemetry.track(name);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (Telemetry.enabled) {
      try {
        final status = err.response?.statusCode;
        // A 4xx is a decision the server made (insufficient stock, a
        // duplicate, a wrong password), and a cancel is the app's own (a
        // search superseded by the next keystroke).
        if ((status == null || status >= 500) &&
            err.type != DioExceptionType.cancel) {
          Telemetry.error('api_error', {
            'endpoint': Telemetry.routePattern(err.requestOptions.path),
            'method': err.requestOptions.method,
            'status': ?status,
            'kind': err.type.name,
          });
        }
      } catch (_) {}
    }
    handler.next(err);
  }
}
