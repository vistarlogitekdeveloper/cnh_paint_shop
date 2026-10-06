import 'dart:convert';
import 'dart:typed_data';

import 'package:cnh_paint_shop/core/telemetry/telemetry.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const uuid = '7f3c2a10-1b2c-4d5e-8f90-a1b2c3d4e5f6';

  test('screen names carry no record ids or query strings', () {
    expect(Telemetry.routePattern('/nesting'), '/nesting');
    expect(Telemetry.routePattern('/pattern-runs'), '/pattern-runs');
    expect(Telemetry.routePattern('/can-build?serial=398'), '/can-build');
    expect(Telemetry.routePattern('/parts/$uuid/ledger?limit=50'), '/parts/:id/ledger');
    expect(
      Telemetry.routePattern('https://api.example.com/api/v1/cnh-paint-shop/machines/42/built'),
      '/api/v1/cnh-paint-shop/machines/:id/built',
    );
  });

  test('serials, part, pattern, rack and batch codes become :id / :ref', () {
    // A machine serial is replaced whatever it looks like, even all letters.
    expect(Telemetry.routePattern('/can-build/398'), '/can-build/:ref');
    expect(Telemetry.routePattern('/can-build/HCCZ5100CNH000123'), '/can-build/:ref');
    expect(Telemetry.routePattern('/can-build/abc'), '/can-build/:ref');
    expect(Telemetry.routePattern('/can-build/SN%2F2026%2F0012'), '/can-build/:ref');
    expect(Telemetry.routePattern('/parts/ATS44'), '/parts/:ref');
    expect(Telemetry.routePattern('/parts/87654321'), '/parts/:id');
    expect(Telemetry.routePattern('/patterns/7FT_HD'), '/patterns/:ref');
    expect(Telemetry.routePattern('/racks/R-12/parts'), '/racks/:ref/parts');
    expect(Telemetry.routePattern('/nesting/LOT-2026-0042/reverse'), '/nesting/:ref/reverse');
    expect(Telemetry.routePattern('/users/NES01'), '/users/:ref');
  });

  test('the paint shop journey is named from successful writes', () {
    expect(Telemetry.actionFor('POST', '/nesting'), 'nesting_recorded');
    expect(Telemetry.actionFor('POST', '/nesting/batch'), 'nesting_frame_recorded');
    expect(Telemetry.actionFor('POST', '/nesting/photos'), 'pallet_photo_uploaded');
    expect(Telemetry.actionFor('POST', '/nesting/$uuid/reverse'), 'nesting_reversed');
    expect(Telemetry.actionFor('POST', '/pattern-runs'), 'pattern_run_recorded');
    expect(Telemetry.actionFor('POST', '/sync/batch'), 'offline_entries_synced');
    expect(Telemetry.actionFor('POST', '/requests'), 'request_raised');
    expect(Telemetry.actionFor('POST', '/requests/$uuid/approve'), 'request_approved');
    expect(Telemetry.actionFor('POST', '/requests/$uuid/reject'), 'request_rejected');
    expect(Telemetry.actionFor('POST', '/requests/$uuid/cancel'), 'request_cancelled');
    expect(Telemetry.actionFor('POST', '/machines'), 'machine_added');
    expect(Telemetry.actionFor('POST', '/machines/bulk'), 'machines_bulk_added');
    expect(Telemetry.actionFor('POST', '/machines/reorder'), 'plan_reordered');
    expect(Telemetry.actionFor('POST', '/machines/$uuid/built'), 'machine_marked_built');
    expect(
      Telemetry.actionFor('POST', '/machines/$uuid/built', data: {'built_with_shortage': true}),
      'machine_built_with_shortage',
    );
    expect(Telemetry.actionFor('POST', '/machines/$uuid/unbuilt'), 'machine_unmarked_built');
    expect(Telemetry.actionFor('PUT', '/machines/$uuid/overrides'), 'machine_bom_overridden');
    expect(Telemetry.actionFor('POST', '/alerts/$uuid/acknowledge'), 'alert_acknowledged');
    expect(Telemetry.actionFor('POST', '/alerts/reevaluate'), 'alerts_reevaluated');
    expect(Telemetry.actionFor('POST', '/parts'), 'part_created');
    expect(Telemetry.actionFor('PATCH', '/parts/$uuid'), 'part_updated');
    expect(Telemetry.actionFor('POST', '/parts/$uuid/stock-count'), 'stock_count_recorded');
    expect(Telemetry.actionFor('POST', '/parts/$uuid/adjust'), 'stock_adjusted');
    expect(Telemetry.actionFor('POST', '/patterns'), 'pattern_created');
    expect(Telemetry.actionFor('POST', '/patterns/$uuid/approve'), 'pattern_approved');
    expect(Telemetry.actionFor('POST', '/bom-items'), 'bom_item_saved');
    expect(Telemetry.actionFor('POST', '/racks'), 'rack_created');
    expect(Telemetry.actionFor('PATCH', '/production-lines/$uuid/thresholds'), 'line_thresholds_updated');
    expect(Telemetry.actionFor('POST', '/imports/parts'), 'import_checked');
    expect(Telemetry.actionFor('POST', '/imports/bom-items'), 'import_checked');
    expect(Telemetry.actionFor('POST', '/imports/$uuid/commit'), 'import_committed');
    expect(Telemetry.actionFor('POST', '/imports/$uuid/cancel'), 'import_cancelled');
    expect(Telemetry.actionFor('post', '/users'), 'user_created');
    expect(Telemetry.actionFor('PATCH', '/users/$uuid'), 'user_updated');
    expect(Telemetry.actionFor('POST', '/users/$uuid/deactivate'), 'user_deactivated');
    expect(Telemetry.actionFor('POST', '/auth/change-password'), 'password_changed');
  });

  test('a replay the server already had is not counted twice', () {
    expect(Telemetry.actionFor('POST', '/nesting', data: {'duplicate': true}), isNull);
    expect(Telemetry.actionFor('POST', '/nesting/photos', data: {'duplicate': true}), isNull);
    expect(Telemetry.actionFor('POST', '/pattern-runs', data: {'duplicate': true}), isNull);
    expect(Telemetry.actionFor('POST', '/nesting', data: {'duplicate': false}), 'nesting_recorded');
  });

  test('reads, auth, the push token, exports and unknown paths are not reported', () {
    expect(Telemetry.actionFor('GET', '/nesting'), isNull);
    expect(Telemetry.actionFor('GET', '/can-build/398'), isNull);
    expect(Telemetry.actionFor('GET', '/shortage-matrix'), isNull);
    expect(Telemetry.actionFor('GET', '/reports/shortage/export'), isNull);
    expect(Telemetry.actionFor('GET', '/sync/bootstrap'), isNull);
    expect(Telemetry.actionFor('POST', '/auth/login'), isNull);
    expect(Telemetry.actionFor('POST', '/auth/logout'), isNull);
    expect(Telemetry.actionFor('POST', '/users/me/fcm-token'), isNull);
    expect(Telemetry.actionFor('DELETE', '/parts/$uuid'), isNull);
    expect(Telemetry.actionFor('PATCH', '/nesting'), isNull);
    expect(Telemetry.actionFor('POST', '/unknown'), isNull);
  });

  test('off without ET_APP_ID and ET_WRITE_KEY (the default build); calls are safe', () async {
    expect(Telemetry.enabled, isFalse);
    await Telemetry.init();
    Telemetry.screen('/nesting');
    Telemetry.track('nesting_recorded');
    Telemetry.error('api_error', {'endpoint': '/nesting', 'method': 'POST'});
    Telemetry.signedIn(userId: 'u1', role: 'nesting_operator');
    Telemetry.signedOut();
  });

  test('the interceptor changes nothing about a request or its outcome', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid'))
      ..httpClientAdapter = _Answer()
      ..interceptors.add(TelemetryInterceptor());
    final ok = await dio.post<dynamic>('/nesting', data: {'qty': 1});
    expect(ok.statusCode, 201);
    expect((ok.data as Map)['success'], isTrue);
    await expectLater(
      dio.post<dynamic>('/pattern-runs'),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 503)),
    );
  });
}

/// Answers 201 for a nesting entry and 503 for anything else, with no network.
class _Answer implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final created = options.path == '/nesting';
    return ResponseBody.fromString(
      jsonEncode({'success': created}),
      created ? 201 : 503,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
