import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../models/models.dart';

/// ---------------------------------------------------------------------------
/// Repositories.
///
/// One class per backend resource group. They own the URL shapes and the JSON →
/// model mapping and nothing else — no caching, no state, no notion of which
/// line is selected. That belongs to the providers, so a repository stays
/// trivially testable against a fake ApiClient.
/// ---------------------------------------------------------------------------

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  /// Returns the user, both tokens, and the active lines — the login response
  /// carries the lines so the app bar can render without a second round-trip on
  /// a shop-floor connection.
  Future<({AppUser user, String access, String refresh, String? refreshExpiresAt, List<ProductionLine> lines})>
      login({required String empCode, required String password}) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: {'emp_code': empCode, 'password': password},
    );
    return (
      user: AppUser.fromJson(asMap(data['user'])),
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
      refreshExpiresAt: data['refresh_expires_at']?.toString(),
      lines: asList(data['lines']).map(ProductionLine.fromJson).toList(),
    );
  }

  Future<AppUser> me() async {
    final data = await _api.get<Map<String, dynamic>>('/auth/me');
    return AppUser.fromJson(asMap(data['user']));
  }

  /// Best-effort: a logout must succeed locally even if the server is down.
  Future<void> logout({String? refreshToken, String? fcmToken}) async {
    try {
      await _api.post<Map<String, dynamic>>('/auth/logout', body: {
        if (refreshToken != null) 'refresh_token': refreshToken,
        if (fcmToken != null) 'fcm_token': fcmToken,
      });
    } catch (_) {
      // Swallowed on purpose — see above.
    }
  }

  Future<void> changePassword({required String oldPassword, required String newPassword}) {
    return _api.post<Map<String, dynamic>>('/auth/change-password', body: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  Future<void> registerFcmToken(String token, {bool unregister = false}) {
    return _api.post<Map<String, dynamic>>('/users/me/fcm-token', body: {
      'token': token,
      'action': unregister ? 'unregister' : 'register',
    });
  }
}

class MasterRepository {
  MasterRepository(this._api);
  final ApiClient _api;

  Future<List<ProductionLine>> lines() async {
    final data = await _api.get<List<dynamic>>('/production-lines');
    return data.whereType<Map<String, dynamic>>().map(ProductionLine.fromJson).toList();
  }

  Future<ProductionLine> updateThresholds(
    String lineId, {
    required int yellow,
    required int red,
  }) async {
    final data = await _api.patch<Map<String, dynamic>>(
      '/production-lines/$lineId/thresholds',
      body: {'yellow_threshold': yellow, 'red_threshold': red},
    );
    return ProductionLine.fromJson(asMap(data['line']));
  }

  Future<List<LineVariant>> variants({String? lineId}) async {
    final data = await _api.get<List<dynamic>>('/line-variants', query: {'line_id': lineId});
    return data.whereType<Map<String, dynamic>>().map(LineVariant.fromJson).toList();
  }

  // ---- racks ----

  Future<({List<Rack> rows, int total})> racks({String? search, int limit = 200, int offset = 0}) async {
    final env = await _api.getEnvelope<List<dynamic>>('/racks', query: {
      'search': search,
      'limit': limit,
      'offset': offset,
    });
    return (
      rows: env.data.whereType<Map<String, dynamic>>().map(Rack.fromJson).toList(),
      total: env.total ?? env.data.length,
    );
  }

  Future<({Rack rack, List<Part> parts})> rackParts(String rackId) async {
    final data = await _api.get<Map<String, dynamic>>('/racks/$rackId/parts');
    return (
      rack: Rack.fromJson(asMap(data['rack'])),
      parts: asList(data['parts']).map(Part.fromJson).toList(),
    );
  }

  Future<Rack> createRack({required String code, String? zone, String? description}) async {
    final data = await _api.post<Map<String, dynamic>>('/racks', body: {
      'code': code,
      if (zone != null) 'zone': zone,
      if (description != null) 'description': description,
    });
    return Rack.fromJson(data);
  }

  // ---- parts ----

  Future<({List<Part> rows, int total, bool hasMore})> parts({
    String? search,
    bool? bulky,
    String? rackId,
    int limit = 50,
    int offset = 0,
    String? sort,
  }) async {
    final env = await _api.getEnvelope<List<dynamic>>('/parts', query: {
      'search': search,
      if (bulky != null) 'bulky': bulky,
      'rack_id': rackId,
      'limit': limit,
      'offset': offset,
      'sort': sort,
    });
    return (
      rows: env.data.whereType<Map<String, dynamic>>().map(Part.fromJson).toList(),
      total: env.total ?? env.data.length,
      hasMore: env.hasMore,
    );
  }

  /// The lookup screen's search. Returns rack, patterns, lines and stock in one
  /// row; exact part-number hits rank first.
  Future<List<Part>> searchParts(String query, {int limit = 25, CancelToken? cancelToken}) async {
    if (query.trim().isEmpty) return const [];
    final data = await _api.get<List<dynamic>>(
      '/parts/search',
      query: {'q': query.trim(), 'limit': limit},
      cancelToken: cancelToken,
    );
    return data.whereType<Map<String, dynamic>>().map(Part.fromJson).toList();
  }

  Future<({Part part, double availableStock, List<Map<String, dynamic>> coverage})> part(
      String partId) async {
    final data = await _api.get<Map<String, dynamic>>('/parts/$partId');
    return (
      part: Part.fromJson(asMap(data['part'])),
      availableStock: asDouble(data['available_stock']),
      coverage: asList(data['coverage']),
    );
  }

  Future<({List<LedgerEntry> entries, double openingStock, double availableStock, int total})> ledger(
    String partId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final env = await _api.getEnvelope<Map<String, dynamic>>('/parts/$partId/ledger', query: {
      'limit': limit,
      'offset': offset,
    });
    return (
      entries: asList(env.data['entries']).map(LedgerEntry.fromJson).toList(),
      openingStock: asDouble(env.data['opening_stock']),
      availableStock: asDouble(env.data['available_stock']),
      total: env.total ?? 0,
    );
  }

  Future<Part> createPart(Map<String, dynamic> body) async {
    final data = await _api.post<Map<String, dynamic>>('/parts', body: body);
    return Part.fromJson(data);
  }

  Future<Part> updatePart(String partId, Map<String, dynamic> body) async {
    final data = await _api.patch<Map<String, dynamic>>('/parts/$partId', body: body);
    return Part.fromJson(data);
  }

  /// Physical count → appends the adjustment that makes the book match the rack.
  Future<double> applyStockCount(String partId, {required double countedQty, String? note}) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/parts/$partId/stock-count',
      body: {'counted_qty': countedQty, if (note != null) 'note': note},
    );
    return asDouble(data['balance_after']);
  }

  Future<double> adjustStock(
    String partId, {
    required double qtyDelta,
    required String note,
    String? lineId,
  }) async {
    final data = await _api.post<Map<String, dynamic>>('/parts/$partId/adjust', body: {
      'qty_delta': qtyDelta,
      'note': note,
      if (lineId != null) 'line_id': lineId,
    });
    return asDouble(data['balance_after']);
  }

  // ---- patterns ----

  Future<({List<Pattern> rows, int total})> patterns({
    String? lineId,
    String? search,
    bool? special,
    int limit = 200,
    int offset = 0,
  }) async {
    final env = await _api.getEnvelope<List<dynamic>>('/patterns', query: {
      'line_id': lineId,
      'search': search,
      if (special != null) 'special': special,
      'limit': limit,
      'offset': offset,
    });
    return (
      rows: env.data.whereType<Map<String, dynamic>>().map(Pattern.fromJson).toList(),
      total: env.total ?? env.data.length,
    );
  }

  /// A pattern with its parts AND their live stock — what the loading operator
  /// needs before hanging the frame.
  Future<({Pattern pattern, List<PatternItem> items})> pattern(String patternId) async {
    final data = await _api.get<Map<String, dynamic>>('/patterns/$patternId');
    return (
      pattern: Pattern.fromJson(asMap(data['pattern'])),
      items: asList(data['items']).map(PatternItem.fromJson).toList(),
    );
  }

  Future<Pattern> createPattern({
    required String lineId,
    required String code,
    String? name,
    double? plannedSurface,
    String? shade,
    bool isSpecial = false,
    List<PatternItem> items = const [],
  }) async {
    final data = await _api.post<Map<String, dynamic>>('/patterns', body: {
      'line_id': lineId,
      'code': code,
      if (name != null) 'name': name,
      if (plannedSurface != null) 'planned_surface': plannedSurface,
      if (shade != null) 'shade': shade,
      'is_special': isSpecial,
      'items': items.map((i) => i.toJson()).toList(),
    });
    return Pattern.fromJson(data);
  }

  Future<Pattern> approvePattern(String patternId) async {
    final data = await _api.post<Map<String, dynamic>>('/patterns/$patternId/approve');
    return Pattern.fromJson(data);
  }

  // ---- BOM ----

  Future<List<BomItem>> bom({String? lineId, String? variantCode}) async {
    final data = await _api.get<List<dynamic>>('/bom-items', query: {
      'line_id': lineId,
      if (variantCode != null) 'variant_code': variantCode,
    });
    return data.whereType<Map<String, dynamic>>().map(BomItem.fromJson).toList();
  }

  Future<void> upsertBom({
    required String lineId,
    required String partId,
    required int qpv,
    String variantCode = '',
  }) {
    return _api.post<Map<String, dynamic>>('/bom-items', body: {
      'line_id': lineId,
      'part_id': partId,
      'qpv': qpv,
      'variant_code': variantCode,
    });
  }
}

/// The coverage engine's client — the screens that answer the plant's question.
class CoverageRepository {
  CoverageRepository(this._api);
  final ApiClient _api;

  Future<CoverageResult> coverage({
    required String lineId,
    String sort = 'critical',
    String level = 'all',
    String? search,
    int limit = 200,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    final env = await _api.getEnvelope<Map<String, dynamic>>(
      '/coverage',
      query: {
        'lineId': lineId,
        'sort': sort,
        'level': level,
        'search': search,
        'limit': limit,
        'offset': offset,
      },
      cancelToken: cancelToken,
    );
    return CoverageResult.fromJson(env.data, meta: env.meta);
  }

  /// The machine-wise sheet. Windowed on BOTH axes — a grown plan is 500 parts ×
  /// 1000 machines and half a million cells is not a payload for a phone.
  Future<MatrixResult> matrix({
    required String lineId,
    int partLimit = 60,
    int partOffset = 0,
    int machineLimit = 40,
    int machineOffset = 0,
    String? search,
    String level = 'all',
    String sort = 'critical',
    CancelToken? cancelToken,
  }) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/shortage-matrix',
      query: {
        'lineId': lineId,
        'partLimit': partLimit,
        'partOffset': partOffset,
        'machineLimit': machineLimit,
        'machineOffset': machineOffset,
        'search': search,
        'level': level,
        'sort': sort,
      },
      cancelToken: cancelToken,
    );
    return MatrixResult.fromJson(data);
  }

  Future<CanBuildResult> canBuild({required String lineId, required String serialNo}) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/can-build/${Uri.encodeComponent(serialNo)}',
      query: {'lineId': lineId},
    );
    return CanBuildResult.fromJson(data);
  }

  Future<CoverageRow> partCoverage({required String lineId, required String partId}) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/coverage/part/$partId',
      query: {'lineId': lineId},
    );
    return CoverageRow.fromJson(data);
  }
}

class DashboardRepository {
  DashboardRepository(this._api);
  final ApiClient _api;

  Future<DashboardData> dashboard({String? lineId}) async {
    final data = await _api.get<Map<String, dynamic>>('/dashboard', query: {'lineId': lineId});
    return DashboardData.fromJson(data);
  }

  Future<BadgeCounts> badges() async {
    final data = await _api.get<Map<String, dynamic>>('/dashboard/badges');
    return BadgeCounts.fromJson(data);
  }

  Future<({List<AuditRecord> rows, int total})> audit({
    String? entity,
    String? entityId,
    String? action,
    int limit = 100,
    int offset = 0,
  }) async {
    final env = await _api.getEnvelope<List<dynamic>>('/audit', query: {
      'entity': entity,
      'entity_id': entityId,
      'action': action,
      'limit': limit,
      'offset': offset,
    });
    return (
      rows: env.data.whereType<Map<String, dynamic>>().map(AuditRecord.fromJson).toList(),
      total: env.total ?? env.data.length,
    );
  }
}

class NestingRepository {
  NestingRepository(this._api);
  final ApiClient _api;

  /// Direct (online) save. The OFFLINE path goes through the outbox instead —
  /// see SyncService. Both end up at the same server row because both carry the
  /// same client_uuid.
  Future<({NestingEntry entry, double? balanceAfter, bool duplicate})> create(
    Map<String, dynamic> body,
  ) async {
    final data = await _api.post<Map<String, dynamic>>('/nesting', body: body);
    return (
      entry: NestingEntry.fromJson(asMap(data['entry'])),
      balanceAfter: data['balance_after'] == null ? null : asDouble(data['balance_after']),
      duplicate: asBool(data['duplicate']),
    );
  }

  /// Uploads the pallet photo for a save.
  ///
  /// Multipart rather than part of the entry JSON: entries travel through the
  /// offline batch envelope, and a megabyte of binary in there would make every
  /// retry of a handful of small rows re-send the image too.
  ///
  /// Returns true when the server already had it — a replay is a success, the
  /// same contract as a duplicate entry.
  Future<bool> uploadPhoto({
    required String clientUuid,
    required List<int> bytes,
    required String mimeType,
    required DateTime capturedAt,
    String? lineId,
    String? patternId,
    String? nestingFrameNo,
  }) async {
    final form = FormData.fromMap({
      'client_uuid': clientUuid,
      'captured_at': capturedAt.toIso8601String(),
      if (lineId != null) 'line_id': lineId,
      if (patternId != null) 'pattern_id': patternId,
      if (nestingFrameNo != null && nestingFrameNo.isNotEmpty) 'nesting_frame_no': nestingFrameNo,
      'photo': MultipartFile.fromBytes(
        bytes,
        filename: 'pallet.jpg',
        contentType: DioMediaType.parse(mimeType),
      ),
    });
    final data = await _api.postForm<Map<String, dynamic>>('/nesting/photos', form);
    return asBool(data['duplicate']);
  }

  /// A whole frame's grid in one save. Per-row outcomes come back so one bad row
  /// does not discard the nine good ones the operator keyed in.
  Future<({List<Map<String, dynamic>> results, int created, int duplicates, int errors})> createBatch(
    Map<String, dynamic> body,
  ) async {
    final data = await _api.post<Map<String, dynamic>>('/nesting/batch', body: body);
    return (
      results: asList(data['results']),
      created: asInt(data['created']),
      duplicates: asInt(data['duplicates']),
      errors: asInt(data['errors']),
    );
  }

  Future<({List<NestingEntry> rows, int total, Map<String, dynamic> totals})> register({
    String? lineId,
    String? partId,
    String? patternId,
    String? date,
    String? from,
    String? to,
    int? shift,
    int limit = 100,
    int offset = 0,
  }) async {
    final env = await _api.getEnvelope<List<dynamic>>('/nesting', query: {
      'line_id': lineId,
      'part_id': partId,
      'pattern_id': patternId,
      'date': date,
      'from': from,
      'to': to,
      if (shift != null) 'shift': shift,
      'limit': limit,
      'offset': offset,
    });
    return (
      rows: env.data.whereType<Map<String, dynamic>>().map(NestingEntry.fromJson).toList(),
      total: env.total ?? env.data.length,
      totals: asMap(env.meta?['totals']),
    );
  }

  /// A correction, not a delete: writes an offsetting ledger row so the register
  /// still shows what was originally entered, and by whom.
  Future<double> reverse(String entryId, {required String note}) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/nesting/$entryId/reverse',
      body: {'note': note},
    );
    return asDouble(data['balance_after']);
  }
}

class RunRepository {
  RunRepository(this._api);
  final ApiClient _api;

  Future<({PatternRun run, bool consumed, List<RunPieceLine> pieces, bool duplicate})> create(
    Map<String, dynamic> body,
  ) async {
    final data = await _api.post<Map<String, dynamic>>('/pattern-runs', body: body);
    return (
      run: PatternRun.fromJson(asMap(data['run'])),
      consumed: asBool(data['consumed']),
      pieces: asList(data['pieces']).map(RunPieceLine.fromJson).toList(),
      duplicate: asBool(data['duplicate']),
    );
  }

  Future<({List<PatternRun> rows, int total})> list({
    String? lineId,
    String? patternId,
    String? date,
    int limit = 100,
    int offset = 0,
  }) async {
    final env = await _api.getEnvelope<List<dynamic>>('/pattern-runs', query: {
      'line_id': lineId,
      'pattern_id': patternId,
      'date': date,
      'limit': limit,
      'offset': offset,
    });
    return (
      rows: env.data.whereType<Map<String, dynamic>>().map(PatternRun.fromJson).toList(),
      total: env.total ?? env.data.length,
    );
  }
}

class RequestRepository {
  RequestRepository(this._api);
  final ApiClient _api;

  Future<({SpdRequest request, Map<String, dynamic>? impact})> create(
    Map<String, dynamic> body,
  ) async {
    final data = await _api.post<Map<String, dynamic>>('/requests', body: body);
    return (
      request: SpdRequest.fromJson(asMap(data['request'])),
      impact: data['impact'] is Map<String, dynamic> ? data['impact'] as Map<String, dynamic> : null,
    );
  }

  Future<({List<SpdRequest> rows, int total, int pending})> list({
    String? status,
    String? type,
    String? lineId,
    bool mine = false,
    int limit = 100,
    int offset = 0,
  }) async {
    final env = await _api.getEnvelope<List<dynamic>>('/requests', query: {
      'status': status,
      'type': type,
      'line_id': lineId,
      if (mine) 'mine': true,
      'limit': limit,
      'offset': offset,
    });
    return (
      rows: env.data.whereType<Map<String, dynamic>>().map(SpdRequest.fromJson).toList(),
      total: env.total ?? env.data.length,
      pending: asInt(asMap(env.meta?['counts'])['pending']),
    );
  }

  Future<SpdRequest> approve(String id, {String? note}) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/requests/$id/approve',
      body: {if (note != null) 'decision_note': note},
    );
    return SpdRequest.fromJson(asMap(data['request']));
  }

  Future<SpdRequest> reject(String id, {String? note}) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/requests/$id/reject',
      body: {if (note != null) 'decision_note': note},
    );
    return SpdRequest.fromJson(data);
  }

  Future<SpdRequest> cancel(String id) async {
    final data = await _api.post<Map<String, dynamic>>('/requests/$id/cancel');
    return SpdRequest.fromJson(data);
  }
}

class PlanRepository {
  PlanRepository(this._api);
  final ApiClient _api;

  Future<({List<Machine> rows, int total, bool hasMore})> machines({
    String? lineId,
    bool? built,
    bool? special,
    String? search,
    int limit = 200,
    int offset = 0,
  }) async {
    final env = await _api.getEnvelope<List<dynamic>>('/machines', query: {
      'line_id': lineId,
      if (built != null) 'built': built,
      if (special != null) 'special': special,
      'search': search,
      'limit': limit,
      'offset': offset,
    });
    return (
      rows: env.data.whereType<Map<String, dynamic>>().map(Machine.fromJson).toList(),
      total: env.total ?? env.data.length,
      hasMore: env.hasMore,
    );
  }

  /// Machine detail with its RESOLVED BOM — override → variant → line standard.
  Future<MachineDetail> machine(String machineId) async {
    final data = await _api.get<Map<String, dynamic>>('/machines/$machineId');
    return MachineDetail.fromJson(data);
  }

  Future<Machine> createMachine({
    required String lineId,
    required String serialNo,
    int? seqIndex,
    String variantCode = '',
    bool isSpecial = false,
    String? specialLabel,
    String? plannedDate,
  }) async {
    final data = await _api.post<Map<String, dynamic>>('/machines', body: {
      'line_id': lineId,
      'serial_no': serialNo,
      if (seqIndex != null) 'seq_index': seqIndex,
      'variant_code': variantCode,
      'is_special': isSpecial,
      if (specialLabel != null) 'special_label': specialLabel,
      if (plannedDate != null) 'planned_date': plannedDate,
    });
    return Machine.fromJson(data);
  }

  /// Bulk append. Array order IS plan order.
  Future<({int inserted, List<String> skipped})> bulkMachines({
    required String lineId,
    required List<Map<String, dynamic>> machines,
  }) async {
    final data = await _api.post<Map<String, dynamic>>('/machines/bulk', body: {
      'line_id': lineId,
      'machines': machines,
    });
    return (
      inserted: asInt(data['inserted']),
      skipped: (data['skipped'] as List? ?? const []).map((s) => s.toString()).toList(),
    );
  }

  Future<void> reorder({required String lineId, required List<String> machineIds}) {
    return _api.post<Map<String, dynamic>>('/machines/reorder', body: {
      'line_id': lineId,
      'machine_ids': machineIds,
    });
  }

  /// Marks built → consumes the resolved BOM.
  ///
  /// Throws ApiException with code INSUFFICIENT_STOCK (422) when a part is
  /// short; `blockingParts` on the exception carries what is missing. Pass
  /// `allowShortage` only after the Planner has seen that list and chosen to
  /// proceed.
  Future<({Machine machine, int consumedParts, bool builtWithShortage})> markBuilt(
    String machineId, {
    bool allowShortage = false,
    String? clientUuid,
  }) async {
    final data = await _api.post<Map<String, dynamic>>('/machines/$machineId/built', body: {
      'allow_shortage': allowShortage,
      if (clientUuid != null) 'client_uuid': clientUuid,
    });
    return (
      machine: Machine.fromJson(asMap(data['machine'])),
      consumedParts: asInt(data['consumed_parts']),
      builtWithShortage: asBool(data['built_with_shortage']),
    );
  }

  Future<int> unmarkBuilt(String machineId) async {
    final data = await _api.post<Map<String, dynamic>>('/machines/$machineId/unbuilt');
    return asInt(data['restored_parts']);
  }

  /// Replaces the machine's override list. `[]` clears it and returns the unit
  /// to its variant / line BOM.
  Future<int> setOverrides(String machineId, List<Map<String, dynamic>> items) async {
    final data = await _api.put<Map<String, dynamic>>(
      '/machines/$machineId/overrides',
      body: {'items': items},
    );
    return asInt(data['count']);
  }
}

class AlertRepository {
  AlertRepository(this._api);
  final ApiClient _api;

  Future<({List<ShortageAlert> rows, int total})> list({
    String? lineId,
    String status = 'open',
    String? level,
    int limit = 100,
    int offset = 0,
  }) async {
    final env = await _api.getEnvelope<List<dynamic>>('/alerts', query: {
      'lineId': lineId,
      'status': status,
      'level': level,
      'limit': limit,
      'offset': offset,
    });
    return (
      rows: env.data.whereType<Map<String, dynamic>>().map(ShortageAlert.fromJson).toList(),
      total: env.total ?? env.data.length,
    );
  }

  Future<ShortageAlert> acknowledge(String alertId) async {
    final data = await _api.post<Map<String, dynamic>>('/alerts/$alertId/acknowledge');
    return ShortageAlert.fromJson(data);
  }

  /// Forces a recompute — the admin screen, and after a bulk import.
  Future<void> reevaluate({String? lineId, bool push = false}) {
    return _api.post<Map<String, dynamic>>('/alerts/reevaluate', query: {
      'lineId': lineId,
      'push': push,
    });
  }
}

class ReportRepository {
  ReportRepository(this._api);
  final ApiClient _api;

  Future<List<ReportDefinition>> catalogue() async {
    final data = await _api.get<List<dynamic>>('/reports');
    return data.whereType<Map<String, dynamic>>().map(ReportDefinition.fromJson).toList();
  }

  /// Returns bytes + filename so the caller decides what to do with them: share
  /// sheet on mobile, browser download on web.
  Future<({List<int> bytes, String filename, String contentType})> export({
    required String type,
    String format = 'xlsx',
    String? lineId,
    String? date,
    String? from,
    String? to,
    int? machineLimit,
    ProgressCallback? onProgress,
  }) {
    return _api.download(
      '/reports/$type/export',
      query: {
        'format': format,
        'lineId': lineId,
        'date': date,
        'from': from,
        'to': to,
        if (machineLimit != null) 'machineLimit': machineLimit,
      },
      fallbackFilename: 'CNH_$type.$format',
      onProgress: onProgress,
    );
  }
}

class ImportRepository {
  ImportRepository(this._api);
  final ApiClient _api;

  Future<List<ImportTarget>> targets() async {
    final data = await _api.get<List<dynamic>>('/imports/targets');
    return data.whereType<Map<String, dynamic>>().map(ImportTarget.fromJson).toList();
  }

  /// STEP 1 — upload + dry run. Writes NOTHING to the masters; returns the
  /// checking report the admin reviews before confirming.
  Future<ImportBatch> dryRun({
    required String target,
    required List<int> bytes,
    required String filename,
    String? lineId,
    String? sheet,
    String? variantCode,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      if (lineId != null) 'line_id': lineId,
      if (sheet != null) 'sheet': sheet,
      if (variantCode != null) 'variant_code': variantCode,
    });
    final data = await _api.post<Map<String, dynamic>>('/imports/$target', body: form);
    return ImportBatch.fromJson(data);
  }

  /// STEP 2 — apply the reviewed batch.
  Future<({String status, Map<String, dynamic> result})> commit(
    String batchId, {
    bool replace = false,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/imports/$batchId/commit',
      body: {'replace': replace},
    );
    return (status: data['status']?.toString() ?? '', result: asMap(data['result']));
  }

  Future<void> cancel(String batchId) =>
      _api.post<Map<String, dynamic>>('/imports/$batchId/cancel');

  Future<({List<ImportBatch> rows, int total})> history({int limit = 50, int offset = 0}) async {
    final env = await _api.getEnvelope<List<dynamic>>('/imports', query: {
      'limit': limit,
      'offset': offset,
    });
    return (
      rows: env.data.whereType<Map<String, dynamic>>().map(ImportBatch.fromJson).toList(),
      total: env.total ?? env.data.length,
    );
  }
}

class UserRepository {
  UserRepository(this._api);
  final ApiClient _api;

  Future<({List<AppUser> rows, int total})> list({
    String? role,
    String? search,
    bool? active,
    int limit = 200,
    int offset = 0,
  }) async {
    final env = await _api.getEnvelope<List<dynamic>>('/users', query: {
      'role': role,
      'search': search,
      if (active != null) 'active': active,
      'limit': limit,
      'offset': offset,
    });
    return (
      rows: env.data.whereType<Map<String, dynamic>>().map(AppUser.fromJson).toList(),
      total: env.total ?? env.data.length,
    );
  }

  Future<AppUser> create(Map<String, dynamic> body) async {
    final data = await _api.post<Map<String, dynamic>>('/users', body: body);
    return AppUser.fromJson(data);
  }

  Future<AppUser> update(String id, Map<String, dynamic> body) async {
    final data = await _api.patch<Map<String, dynamic>>('/users/$id', body: body);
    return AppUser.fromJson(data);
  }

  Future<void> deactivate(String id) => _api.post<Map<String, dynamic>>('/users/$id/deactivate');
}

/// Offline sync + the bootstrap the device caches to work with no connection.
class SyncRepository {
  SyncRepository(this._api);
  final ApiClient _api;

  Future<SyncBatchResult> flush(List<Map<String, dynamic>> operations) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/sync/batch',
      body: {'operations': operations},
    );
    return SyncBatchResult.fromJson(data);
  }

  /// Everything the entry screens need cached. `since` returns only what changed.
  Future<({
    List<ProductionLine> lines,
    List<Map<String, dynamic>> patterns,
    List<Map<String, dynamic>> parts,
    DateTime serverTime,
  })> bootstrap({DateTime? since}) async {
    final data = await _api.get<Map<String, dynamic>>('/sync/bootstrap', query: {
      if (since != null) 'since': since.toUtc().toIso8601String(),
    });
    return (
      lines: asList(data['lines']).map(ProductionLine.fromJson).toList(),
      patterns: asList(data['patterns']),
      parts: asList(data['parts']),
      serverTime: asDate(data['server_time']) ?? DateTime.now(),
    );
  }
}
