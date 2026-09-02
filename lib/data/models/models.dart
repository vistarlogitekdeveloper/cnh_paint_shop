import 'package:flutter/foundation.dart';

/// ---------------------------------------------------------------------------
/// Domain models, typed against the backend's OpenAPI schema.
///
/// Field names deliberately match the Postgres columns (`unpainted_pn`,
/// `painted_pn`, `qpv`, `machines_covered`) rather than being camel-cased into
/// something prettier. The whole point of the app is that it speaks the same
/// language as the sheets the team already reads; renaming `QPV` to
/// `quantityPerVehicle` in the client would put a translation layer between the
/// operator's vocabulary and the code.
///
/// Written by hand rather than generated. Every `fromJson` here has to be
/// tolerant of a NUMERIC column arriving as a string (node-postgres does that
/// for `numeric` to avoid float truncation), of nulls in nullable columns, and
/// of nested objects that may or may not have been included by the endpoint —
/// which is exactly the kind of leniency a generator gets wrong.
/// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Parsing helpers
// ---------------------------------------------------------------------------

/// Postgres NUMERIC arrives as a String. Every quantity in this app goes through
/// here so no screen ever does arithmetic on `"225"`.
double asDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

int asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

int? asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

bool asBool(dynamic v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  final s = v.toString().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

String? asStringOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString())?.toLocal();
}

Map<String, dynamic> asMap(dynamic v) =>
    v is Map<String, dynamic> ? v : <String, dynamic>{};

List<Map<String, dynamic>> asList(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// The six SRS roles.
enum UserRole {
  nestingOperator('nesting_operator', 'Nesting Operator'),
  loadingOperator('loading_operator', 'Loading Operator'),
  supervisor('supervisor', 'Paint Shop Supervisor'),
  planner('planner', 'Planner'),
  admin('admin', 'Admin'),
  viewer('viewer', 'Viewer (Mgmt / CNH)');

  const UserRole(this.wire, this.label);
  final String wire;
  final String label;

  static UserRole fromWire(String? wire) => UserRole.values.firstWhere(
        (r) => r.wire == wire,
        // An unknown role from a newer server degrades to the least-privileged
        // one rather than throwing — a login must not fail because a role was
        // added server-side.
        orElse: () => UserRole.viewer,
      );

  bool get isOperator => this == nestingOperator || this == loadingOperator;
  bool get isReadOnly => this == viewer;
}

/// 🔴 / 🟡 / null. Named `AlertLevel` to match the backend enum.
enum AlertLevel {
  red('red'),
  yellow('yellow');

  const AlertLevel(this.wire);
  final String wire;

  static AlertLevel? fromWire(String? wire) => switch (wire) {
        'red' => AlertLevel.red,
        'yellow' => AlertLevel.yellow,
        _ => null,
      };
}

enum AlertStatus {
  open('open'),
  acknowledged('acknowledged'),
  resolved('resolved');

  const AlertStatus(this.wire);
  final String wire;

  static AlertStatus fromWire(String? w) =>
      AlertStatus.values.firstWhere((s) => s.wire == w, orElse: () => AlertStatus.open);
}

enum RequestType {
  spdIssue('spd_issue', 'SPD Issue'),
  specialLoad('special_load', 'Special Load');

  const RequestType(this.wire, this.label);
  final String wire;
  final String label;

  static RequestType fromWire(String? w) =>
      RequestType.values.firstWhere((t) => t.wire == w, orElse: () => RequestType.spdIssue);
}

enum RequestStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  cancelled('cancelled', 'Cancelled');

  const RequestStatus(this.wire, this.label);
  final String wire;
  final String label;

  static RequestStatus fromWire(String? w) =>
      RequestStatus.values.firstWhere((s) => s.wire == w, orElse: () => RequestStatus.pending);
}

enum PartType {
  buy('buy', 'Buy'),
  makeWh('make_wh', 'Make WH');

  const PartType(this.wire, this.label);
  final String wire;
  final String label;

  static PartType fromWire(String? w) =>
      PartType.values.firstWhere((t) => t.wire == w, orElse: () => PartType.buy);
}

enum LedgerReason {
  opening('opening', 'Opening stock'),
  nestingReceipt('nesting_receipt', 'Nesting receipt'),
  consumption('consumption', 'Consumed by machine'),
  consumptionReversal('consumption_reversal', 'Consumption reversed'),
  spdIssue('spd_issue', 'Issued to spares'),
  manualAdjust('manual_adjust', 'Manual adjustment'),
  stockCount('stock_count', 'Physical count');

  const LedgerReason(this.wire, this.label);
  final String wire;
  final String label;

  static LedgerReason fromWire(String? w) =>
      LedgerReason.values.firstWhere((r) => r.wire == w, orElse: () => LedgerReason.manualAdjust);
}

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------

@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.empCode,
    required this.fullName,
    required this.role,
    required this.permissions,
    required this.defaultRoute,
    this.phone,
    this.email,
    this.shift,
    this.forcePasswordChange = false,
    this.lastLoginAt,
    this.isActive = true,
  });

  final String id;
  final String empCode;
  final String fullName;
  final UserRole role;

  /// Server-derived permission codes. The UI hides controls the role cannot use;
  /// the server refuses them regardless, so this is a courtesy not a gate.
  final Set<String> permissions;

  /// Where this role lands after login. Server-driven so the role→screen map has
  /// exactly one home (config/roles.js).
  final String defaultRoute;

  final String? phone;
  final String? email;
  final int? shift;
  final bool forcePasswordChange;
  final DateTime? lastLoginAt;
  final bool isActive;

  bool can(String permission) => permissions.contains(permission);
  bool canAny(Iterable<String> perms) => perms.any(permissions.contains);

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id']?.toString() ?? '',
        empCode: json['emp_code']?.toString() ?? '',
        fullName: json['full_name']?.toString() ?? '',
        role: UserRole.fromWire(json['role']?.toString()),
        permissions: {
          for (final p in (json['permissions'] as List? ?? const [])) p.toString(),
        },
        defaultRoute: json['default_route']?.toString() ?? '/dashboard',
        phone: asStringOrNull(json['phone']),
        email: asStringOrNull(json['email']),
        shift: asIntOrNull(json['shift']),
        forcePasswordChange: asBool(json['force_password_change']),
        lastLoginAt: asDate(json['last_login_at']),
        isActive: asBool(json['is_active'], true),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'emp_code': empCode,
        'full_name': fullName,
        'role': role.wire,
        'permissions': permissions.toList(),
        'default_route': defaultRoute,
        'phone': phone,
        'email': email,
        'shift': shift,
        'force_password_change': forcePasswordChange,
        'last_login_at': lastLoginAt?.toIso8601String(),
        'is_active': isActive,
      };
}

/// Permission codes, mirrored from the backend's config/roles.js.
///
/// Duplicated deliberately: the client needs them as compile-time constants to
/// decide what to render, and a typo'd string literal at a call site would fail
/// silently by hiding a control the user should have.
abstract final class Perm {
  static const dashboardView = 'DASHBOARD_VIEW';
  static const coverageView = 'COVERAGE_VIEW';
  static const matrixView = 'MATRIX_VIEW';
  static const partView = 'PART_VIEW';
  static const patternView = 'PATTERN_VIEW';
  static const machineView = 'MACHINE_VIEW';
  static const nestingView = 'NESTING_VIEW';
  static const runView = 'RUN_VIEW';
  static const requestView = 'REQUEST_VIEW';
  static const alertView = 'ALERT_VIEW';
  static const reportView = 'REPORT_VIEW';
  static const ledgerView = 'LEDGER_VIEW';
  static const auditView = 'AUDIT_VIEW';

  static const nestingCreate = 'NESTING_CREATE';
  static const runCreate = 'RUN_CREATE';
  static const alertAck = 'ALERT_ACK';
  static const requestCreate = 'REQUEST_CREATE';
  static const requestApprove = 'REQUEST_APPROVE';
  static const patternManage = 'PATTERN_MANAGE';
  static const machineManage = 'MACHINE_MANAGE';
  static const machineBuild = 'MACHINE_BUILD';
  static const masterManage = 'MASTER_MANAGE';
  static const thresholdManage = 'THRESHOLD_MANAGE';
  static const stockAdjust = 'STOCK_ADJUST';
  static const importManage = 'IMPORT_MANAGE';
  static const userManage = 'USER_MANAGE';
}

// ---------------------------------------------------------------------------
// Masters
// ---------------------------------------------------------------------------

@immutable
class ProductionLine {
  const ProductionLine({
    required this.id,
    required this.code,
    required this.name,
    this.yellowThreshold = 10,
    this.redThreshold = 5,
    this.runsDriveConsumption = false,
    this.sortOrder = 0,
    this.isActive = true,
    this.variants = const [],
  });

  final String id;
  final String code;
  final String name;

  /// Machines of coverage at which a part turns amber / red.
  final int yellowThreshold;
  final int redThreshold;

  final bool runsDriveConsumption;
  final int sortOrder;
  final bool isActive;
  final List<LineVariant> variants;

  factory ProductionLine.fromJson(Map<String, dynamic> json) => ProductionLine(
        id: json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        yellowThreshold: asInt(json['yellow_threshold'], 10),
        redThreshold: asInt(json['red_threshold'], 5),
        runsDriveConsumption: asBool(json['runs_drive_consumption']),
        sortOrder: asInt(json['sort_order']),
        isActive: asBool(json['is_active'], true),
        variants: asList(json['variants']).map(LineVariant.fromJson).toList(),
      );
}

@immutable
class LineVariant {
  const LineVariant({
    required this.id,
    required this.lineId,
    required this.code,
    required this.name,
    this.isSpecial = false,
  });

  final String id;
  final String lineId;
  final String code;
  final String name;
  final bool isSpecial;

  factory LineVariant.fromJson(Map<String, dynamic> json) => LineVariant(
        id: json['id']?.toString() ?? '',
        lineId: json['line_id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        isSpecial: asBool(json['is_special']),
      );
}

@immutable
class Rack {
  const Rack({
    required this.id,
    required this.code,
    this.zone,
    this.description,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String? zone;
  final String? description;
  final bool isActive;

  factory Rack.fromJson(Map<String, dynamic> json) => Rack(
        id: json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        zone: asStringOrNull(json['zone']),
        description: asStringOrNull(json['description']),
        isActive: asBool(json['is_active'], true),
      );
}

/// A part, with whatever stock context the endpoint included.
///
/// One class covers both the bare master row and the enriched shapes returned by
/// /parts/search and /coverage, because the screens treat them the same and a
/// second near-identical class would just mean two `fromJson` bodies to keep in
/// step. Fields the endpoint omitted are simply zero/null.
@immutable
class Part {
  const Part({
    required this.id,
    required this.unpaintedPn,
    required this.description,
    this.paintedPn,
    this.colorShade,
    this.partType = PartType.buy,
    this.paintFormat,
    this.station,
    this.isBulky = false,
    this.rackId,
    this.rackCode,
    this.rackZone,
    this.openingStock = 0,
    this.availableStock = 0,
    this.dailyNesting = 0,
    this.takenBySpd = 0,
    this.imageUrl,
    this.isActive = true,
    this.patterns = const [],
    this.lines = const [],
  });

  final String id;
  final String unpaintedPn;
  final String description;
  final String? paintedPn;
  final String? colorShade;
  final PartType partType;
  final String? paintFormat;
  final String? station;
  final bool isBulky;
  final String? rackId;
  final String? rackCode;
  final String? rackZone;

  /// The 'Stk 30sep' baseline.
  final double openingStock;

  /// opening + Σ ledger. The number every screen actually shows.
  final double availableStock;

  /// Today's receipts — the sheet's 'Daily nesting' column.
  final double dailyNesting;

  /// The sheet's 'Taken by SPD' column.
  final double takenBySpd;

  final String? imageUrl;
  final bool isActive;

  /// Frames this part hangs on, from /parts/search.
  final List<PartPatternRef> patterns;

  /// Lines that consume it, with QPV.
  final List<PartLineRef> lines;

  /// "47659644 · LEVER" — the label used in pickers and toasts.
  String get displayLabel => '$unpaintedPn · $description';

  /// The painted number if there is one, else the unpainted. What a sticker shows.
  String get primaryPn => paintedPn ?? unpaintedPn;

  factory Part.fromJson(Map<String, dynamic> json) {
    final rack = asMap(json['rack']);
    return Part(
      id: json['id']?.toString() ?? '',
      unpaintedPn: json['unpainted_pn']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      paintedPn: asStringOrNull(json['painted_pn']),
      colorShade: asStringOrNull(json['color_shade']),
      partType: PartType.fromWire(json['part_type']?.toString()),
      paintFormat: asStringOrNull(json['paint_format']),
      station: asStringOrNull(json['station']),
      isBulky: asBool(json['is_bulky']),
      rackId: asStringOrNull(json['rack_id']),
      // The rack arrives either nested (Sequelize include) or flattened
      // (raw-SQL endpoints). Both are accepted so callers never have to care.
      rackCode: asStringOrNull(json['rack_code']) ?? asStringOrNull(rack['code']),
      rackZone: asStringOrNull(json['rack_zone']) ?? asStringOrNull(rack['zone']),
      openingStock: asDouble(json['opening_stock']),
      availableStock: asDouble(json['available_stock']),
      dailyNesting: asDouble(json['daily_nesting']),
      takenBySpd: asDouble(json['taken_by_spd']),
      imageUrl: asStringOrNull(json['image_url']),
      isActive: asBool(json['is_active'], true),
      patterns: asList(json['patterns']).map(PartPatternRef.fromJson).toList(),
      lines: asList(json['lines']).map(PartLineRef.fromJson).toList(),
    );
  }
}

@immutable
class PartPatternRef {
  const PartPatternRef({
    required this.patternId,
    required this.code,
    this.lineCode,
    this.qtyPerFrame = 1,
  });

  final String patternId;
  final String code;
  final String? lineCode;
  final int qtyPerFrame;

  factory PartPatternRef.fromJson(Map<String, dynamic> json) => PartPatternRef(
        patternId: json['pattern_id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        lineCode: asStringOrNull(json['line_code']),
        qtyPerFrame: asInt(json['qty_per_frame'], 1),
      );
}

@immutable
class PartLineRef {
  const PartLineRef({
    required this.lineId,
    required this.lineCode,
    this.variantCode,
    this.qpv = 1,
  });

  final String lineId;
  final String lineCode;
  final String? variantCode;
  final int qpv;

  factory PartLineRef.fromJson(Map<String, dynamic> json) => PartLineRef(
        lineId: json['line_id']?.toString() ?? '',
        lineCode: json['line_code']?.toString() ?? '',
        variantCode: asStringOrNull(json['variant_code']),
        qpv: asInt(json['qpv'], 1),
      );
}

@immutable
class Pattern {
  const Pattern({
    required this.id,
    required this.lineId,
    required this.code,
    this.name,
    this.plannedSurface,
    this.shade,
    this.isSpecial = false,
    this.approvedAt,
    this.isActive = true,
    this.lineCode,
    this.items = const [],
  });

  final String id;
  final String lineId;
  final String code;
  final String? name;
  final double? plannedSurface;
  final String? shade;

  /// A one-time non-standard frame. Not loadable until a Planner approves it.
  final bool isSpecial;
  final DateTime? approvedAt;

  final bool isActive;
  final String? lineCode;
  final List<PatternItem> items;

  /// A special pattern is only usable once approved; a standard one always is.
  bool get isLoadable => isActive && (!isSpecial || approvedAt != null);

  bool get awaitingApproval => isSpecial && approvedAt == null;

  factory Pattern.fromJson(Map<String, dynamic> json) {
    final line = asMap(json['line']);
    return Pattern(
      id: json['id']?.toString() ?? '',
      lineId: json['line_id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: asStringOrNull(json['name']),
      plannedSurface: json['planned_surface'] == null ? null : asDouble(json['planned_surface']),
      shade: asStringOrNull(json['shade']),
      isSpecial: asBool(json['is_special']),
      approvedAt: asDate(json['approved_at']),
      isActive: asBool(json['is_active'], true),
      lineCode: asStringOrNull(json['line_code']) ?? asStringOrNull(line['code']),
      items: asList(json['items']).map(PatternItem.fromJson).toList(),
    );
  }
}

@immutable
class PatternItem {
  const PatternItem({
    required this.partId,
    this.id,
    this.seqNo,
    this.qtyPerFrame = 1,
    this.part,
    this.availableStock = 0,
  });

  final String partId;
  final String? id;

  /// The frame's 'Sr. No.'
  final int? seqNo;

  /// The sheet's 'Pattern Qty'.
  final int qtyPerFrame;

  final Part? part;
  final double availableStock;

  factory PatternItem.fromJson(Map<String, dynamic> json) {
    final partJson = asMap(json['part']);
    return PatternItem(
      id: asStringOrNull(json['id']),
      partId: json['part_id']?.toString() ?? partJson['id']?.toString() ?? '',
      seqNo: asIntOrNull(json['seq_no']),
      qtyPerFrame: asInt(json['qty_per_frame'], 1),
      part: partJson.isEmpty ? null : Part.fromJson(partJson),
      availableStock: asDouble(json['available_stock']),
    );
  }

  Map<String, dynamic> toJson() => {
        'part_id': partId,
        'seq_no': seqNo,
        'qty_per_frame': qtyPerFrame,
      };
}

@immutable
class BomItem {
  const BomItem({
    required this.id,
    required this.lineId,
    required this.partId,
    required this.qpv,
    this.variantCode = '',
    this.part,
    this.lineCode,
  });

  final String id;
  final String lineId;
  final String partId;

  /// Qty Per Vehicle — pieces consumed by ONE machine.
  final int qpv;

  /// '' = the line's standard BOM.
  final String variantCode;

  final Part? part;
  final String? lineCode;

  factory BomItem.fromJson(Map<String, dynamic> json) {
    final partJson = asMap(json['part']);
    final line = asMap(json['line']);
    return BomItem(
      id: json['id']?.toString() ?? '',
      lineId: json['line_id']?.toString() ?? '',
      partId: json['part_id']?.toString() ?? '',
      qpv: asInt(json['qpv'], 1),
      variantCode: json['variant_code']?.toString() ?? '',
      part: partJson.isEmpty ? null : Part.fromJson(partJson),
      lineCode: asStringOrNull(line['code']),
    );
  }
}

// ---------------------------------------------------------------------------
// Machine plan
// ---------------------------------------------------------------------------

@immutable
class Machine {
  const Machine({
    required this.id,
    required this.lineId,
    required this.serialNo,
    required this.seqIndex,
    this.variantCode = '',
    this.isSpecial = false,
    this.specialLabel,
    this.isBuilt = false,
    this.builtAt,
    this.builtByName,
    this.plannedDate,
    this.overrideCount = 0,
    this.lineCode,
  });

  final String id;
  final String lineId;
  final String serialNo;

  /// Plan position. The coverage walk follows THIS, not the serial number —
  /// 'ATS44-01' sorts wrong as text but sits in a definite place in the plan.
  final int seqIndex;

  final String variantCode;

  /// A project unit (ATS44 / Indigo).
  final bool isSpecial;
  final String? specialLabel;

  final bool isBuilt;
  final DateTime? builtAt;
  final String? builtByName;
  final DateTime? plannedDate;

  /// How many per-machine BOM override rows this unit has. Non-zero means its
  /// BOM is fully overridden.
  final int overrideCount;

  final String? lineCode;

  bool get hasOverride => overrideCount > 0;

  /// What to show in the plan list under the serial.
  String? get badge => specialLabel ?? (variantCode.isEmpty ? null : variantCode);

  factory Machine.fromJson(Map<String, dynamic> json) {
    final line = asMap(json['line']);
    final builtBy = asMap(json['builtBy']);
    return Machine(
      id: json['id']?.toString() ?? '',
      lineId: json['line_id']?.toString() ?? '',
      serialNo: json['serial_no']?.toString() ?? '',
      seqIndex: asInt(json['seq_index']),
      variantCode: json['variant_code']?.toString() ?? '',
      isSpecial: asBool(json['is_special']),
      specialLabel: asStringOrNull(json['special_label']),
      isBuilt: asBool(json['is_built']),
      builtAt: asDate(json['built_at']),
      builtByName: asStringOrNull(builtBy['full_name']),
      plannedDate: asDate(json['planned_date']),
      overrideCount: asInt(json['override_count']),
      lineCode: asStringOrNull(line['code']),
    );
  }
}

/// One line of a machine's resolved BOM — what building it will consume.
@immutable
class MachineBomLine {
  const MachineBomLine({
    required this.part,
    required this.qty,
    required this.availableStock,
    required this.short,
  });

  final Part part;
  final int qty;
  final double availableStock;
  final bool short;

  factory MachineBomLine.fromJson(Map<String, dynamic> json) => MachineBomLine(
        part: Part.fromJson(asMap(json['part'])),
        qty: asInt(json['qty'], 1),
        availableStock: asDouble(json['available_stock']),
        short: asBool(json['short']),
      );
}

@immutable
class MachineDetail {
  const MachineDetail({
    required this.machine,
    required this.bomSource,
    required this.items,
  });

  final Machine machine;

  /// 'machine_override' | 'variant' | 'line_standard' — shown on the plan detail
  /// so a Planner can see WHY a unit consumes what it does.
  final String bomSource;

  final List<MachineBomLine> items;

  String get bomSourceLabel => switch (bomSource) {
        'machine_override' => 'Per-machine override',
        'variant' => 'Variant BOM',
        _ => 'Line standard BOM',
      };

  factory MachineDetail.fromJson(Map<String, dynamic> json) => MachineDetail(
        machine: Machine.fromJson(asMap(json['machine'])),
        bomSource: json['bom_source']?.toString() ?? 'line_standard',
        items: asList(json['items']).map(MachineBomLine.fromJson).toList(),
      );
}

// ---------------------------------------------------------------------------
// Coverage — the heart
// ---------------------------------------------------------------------------

/// One part walked against a line's plan.
@immutable
class CoverageRow {
  const CoverageRow({
    required this.part,
    required this.qpv,
    required this.availableStock,
    required this.machinesCovered,
    this.safeUntilSerial,
    this.firstBlockedSerial,
    this.firstBlockedSeq,
    this.shortfallQty = 0,
    this.blockedInPlan = false,
    this.planLength = 0,
    this.level,
    this.cells = const [],
  });

  final Part part;

  /// Pieces per machine.
  final int qpv;

  final double availableStock;

  /// How many upcoming machines can be built.
  final int machinesCovered;

  /// The last machine that CAN be built.
  final String? safeUntilSerial;

  /// The first machine that cannot. Null exactly when nothing in the plan blocks.
  final String? firstBlockedSerial;

  final int? firstBlockedSeq;

  /// Pieces needed to clear the block.
  final double shortfallQty;

  final bool blockedInPlan;
  final int planLength;

  final AlertLevel? level;

  /// The matrix row: running balance after each machine in the visible window.
  final List<double> cells;

  bool get isCritical => level == AlertLevel.red;
  bool get isWarning => level == AlertLevel.yellow;
  bool get isOk => level == null;

  /// "Safe up to 617 · runs out at 618", or "covered for the whole plan".
  String get horizonLabel {
    if (firstBlockedSerial == null) {
      return planLength == 0
          ? 'No machine plan loaded'
          : 'Covered for all $planLength planned machines';
    }
    final safe = safeUntilSerial;
    return safe == null
        ? 'Cannot build the next machine ($firstBlockedSerial)'
        : 'Safe up to $safe · runs out at $firstBlockedSerial';
  }

  factory CoverageRow.fromJson(Map<String, dynamic> json) => CoverageRow(
        part: Part.fromJson(asMap(json['part'])),
        qpv: asInt(json['qpv'], 1),
        availableStock: asDouble(json['available_stock']),
        machinesCovered: asInt(json['machines_covered']),
        safeUntilSerial: asStringOrNull(json['safe_until_serial']),
        firstBlockedSerial: asStringOrNull(json['first_blocked_serial']),
        firstBlockedSeq: asIntOrNull(json['first_blocked_seq']),
        shortfallQty: asDouble(json['shortfall_qty']),
        blockedInPlan: asBool(json['blocked_in_plan']),
        planLength: asInt(json['plan_length']),
        level: AlertLevel.fromWire(json['level']?.toString()),
        cells: (json['cells'] as List? ?? const []).map(asDouble).toList(),
      );
}

@immutable
class CoverageCounts {
  const CoverageCounts({this.total = 0, this.red = 0, this.yellow = 0, this.ok = 0});

  final int total;
  final int red;
  final int yellow;
  final int ok;

  factory CoverageCounts.fromJson(Map<String, dynamic> json) => CoverageCounts(
        total: asInt(json['total']),
        red: asInt(json['red']),
        yellow: asInt(json['yellow']),
        ok: asInt(json['ok']),
      );
}

@immutable
class CoverageResult {
  const CoverageResult({
    required this.line,
    required this.rows,
    required this.counts,
    this.planLength = 0,
    this.nextMachineSerial,
    this.total = 0,
    this.hasMore = false,
  });

  final ProductionLine line;
  final List<CoverageRow> rows;
  final CoverageCounts counts;
  final int planLength;
  final String? nextMachineSerial;
  final int total;
  final bool hasMore;

  factory CoverageResult.fromJson(Map<String, dynamic> json, {Map<String, dynamic>? meta}) {
    final next = asMap(json['next_machine']);
    return CoverageResult(
      line: ProductionLine.fromJson(asMap(json['line'])),
      rows: asList(json['rows']).map(CoverageRow.fromJson).toList(),
      counts: CoverageCounts.fromJson(asMap(json['counts'])),
      planLength: asInt(json['plan_length']),
      nextMachineSerial: asStringOrNull(next['serial_no']),
      total: asInt(meta?['total']),
      hasMore: asBool(meta?['has_more']),
    );
  }
}

/// A machine column in the shortage matrix.
@immutable
class MatrixMachine {
  const MatrixMachine({
    required this.serialNo,
    required this.seqIndex,
    this.isSpecial = false,
    this.specialLabel,
    this.variantCode,
  });

  final String serialNo;
  final int seqIndex;
  final bool isSpecial;
  final String? specialLabel;
  final String? variantCode;

  /// The group band above the serial, as the Rotavator sheet labels its columns.
  String? get groupLabel => specialLabel ?? variantCode;

  factory MatrixMachine.fromJson(Map<String, dynamic> json) => MatrixMachine(
        serialNo: json['serial_no']?.toString() ?? '',
        seqIndex: asInt(json['seq_index']),
        isSpecial: asBool(json['is_special']),
        specialLabel: asStringOrNull(json['special_label']),
        variantCode: asStringOrNull(json['variant_code']),
      );
}

@immutable
class WindowMeta {
  const WindowMeta({this.total = 0, this.offset = 0, this.limit = 0, this.hasMore = false});

  final int total;
  final int offset;
  final int limit;
  final bool hasMore;

  factory WindowMeta.fromJson(Map<String, dynamic> json) => WindowMeta(
        total: asInt(json['total']),
        offset: asInt(json['offset']),
        limit: asInt(json['limit']),
        hasMore: asBool(json['has_more']),
      );
}

@immutable
class MatrixResult {
  const MatrixResult({
    required this.line,
    required this.machines,
    required this.rows,
    required this.machineMeta,
    required this.partMeta,
  });

  final ProductionLine line;
  final List<MatrixMachine> machines;
  final List<CoverageRow> rows;
  final WindowMeta machineMeta;
  final WindowMeta partMeta;

  factory MatrixResult.fromJson(Map<String, dynamic> json) => MatrixResult(
        line: ProductionLine.fromJson(asMap(json['line'])),
        machines: asList(json['machines']).map(MatrixMachine.fromJson).toList(),
        rows: asList(json['rows']).map(CoverageRow.fromJson).toList(),
        machineMeta: WindowMeta.fromJson(asMap(json['machine_meta'])),
        partMeta: WindowMeta.fromJson(asMap(json['part_meta'])),
      );
}

/// "Can I build machine N?"
@immutable
class CanBuildResult {
  const CanBuildResult({
    required this.serialNo,
    required this.ready,
    this.alreadyBuilt = false,
    this.notInPlan = false,
    this.machinesAhead = 0,
    this.isSpecial = false,
    this.specialLabel,
    this.blockingParts = const [],
    this.builtAt,
  });

  final String serialNo;
  final bool ready;
  final bool alreadyBuilt;
  final bool notInPlan;
  final int machinesAhead;
  final bool isSpecial;
  final String? specialLabel;
  final List<BlockingPart> blockingParts;
  final DateTime? builtAt;

  factory CanBuildResult.fromJson(Map<String, dynamic> json) => CanBuildResult(
        serialNo: json['serial_no']?.toString() ?? '',
        ready: asBool(json['ready']),
        alreadyBuilt: asBool(json['already_built']),
        notInPlan: asBool(json['not_in_plan']),
        machinesAhead: asInt(json['machines_ahead']),
        isSpecial: asBool(json['is_special']),
        specialLabel: asStringOrNull(json['special_label']),
        blockingParts: asList(json['blocking_parts']).map(BlockingPart.fromJson).toList(),
        builtAt: asDate(json['built_at']),
      );
}

@immutable
class BlockingPart {
  const BlockingPart({
    required this.part,
    required this.requiredQty,
    required this.availableAtMachine,
    required this.shortfallQty,
  });

  final Part part;
  final int requiredQty;

  /// The balance this part will have when the plan reaches that machine — not
  /// its balance today, which is why a part with stock on the shelf can still
  /// block a machine forty units out.
  final double availableAtMachine;

  final double shortfallQty;

  factory BlockingPart.fromJson(Map<String, dynamic> json) => BlockingPart(
        part: Part.fromJson(asMap(json['part'])),
        requiredQty: asInt(json['required_qty'], 1),
        availableAtMachine: asDouble(json['available_at_machine']),
        shortfallQty: asDouble(json['shortfall_qty']),
      );
}

// ---------------------------------------------------------------------------
// Transactions
// ---------------------------------------------------------------------------

@immutable
class NestingEntry {
  const NestingEntry({
    required this.id,
    required this.partId,
    required this.quantity,
    required this.entryTime,
    this.lineId,
    this.patternId,
    this.nestingFrameNo,
    this.patternTxnId,
    this.requiredQty,
    this.reason,
    this.shade,
    this.plannedSurface,
    this.actualSurface,
    this.isNonStandard = false,
    this.shift,
    this.part,
    this.lineCode,
    this.patternCode,
    this.enteredByName,
    this.enteredByCode,
    this.clientUuid,
  });

  final String id;
  final String partId;
  final int quantity;
  final DateTime entryTime;
  final String? lineId;
  final String? patternId;
  final String? nestingFrameNo;
  final String? patternTxnId;

  /// What the frame expected. A shortfall against this is the 'Reason' case.
  final int? requiredQty;
  final String? reason;

  final String? shade;
  final double? plannedSurface;
  final double? actualSurface;
  final bool isNonStandard;
  final int? shift;

  final Part? part;
  final String? lineCode;
  final String? patternCode;
  final String? enteredByName;
  final String? enteredByCode;
  final String? clientUuid;

  bool get isShort => requiredQty != null && quantity < requiredQty!;

  factory NestingEntry.fromJson(Map<String, dynamic> json) {
    final partJson = asMap(json['part']);
    final line = asMap(json['line']);
    final pattern = asMap(json['pattern']);
    final by = asMap(json['enteredBy']);
    return NestingEntry(
      id: json['id']?.toString() ?? '',
      partId: json['part_id']?.toString() ?? '',
      quantity: asInt(json['quantity']),
      entryTime: asDate(json['entry_time']) ?? DateTime.now(),
      lineId: asStringOrNull(json['line_id']),
      patternId: asStringOrNull(json['pattern_id']),
      nestingFrameNo: asStringOrNull(json['nesting_frame_no']),
      patternTxnId: asStringOrNull(json['pattern_txn_id']),
      requiredQty: asIntOrNull(json['required_qty']),
      reason: asStringOrNull(json['reason']),
      shade: asStringOrNull(json['shade']),
      plannedSurface: json['planned_surface'] == null ? null : asDouble(json['planned_surface']),
      actualSurface: json['actual_surface'] == null ? null : asDouble(json['actual_surface']),
      isNonStandard: asBool(json['is_non_standard']),
      shift: asIntOrNull(json['shift']),
      part: partJson.isEmpty ? null : Part.fromJson(partJson),
      lineCode: asStringOrNull(line['code']),
      patternCode: asStringOrNull(pattern['code']),
      enteredByName: asStringOrNull(by['full_name']),
      enteredByCode: asStringOrNull(by['emp_code']),
      clientUuid: asStringOrNull(json['client_uuid']),
    );
  }
}

@immutable
class PatternRun {
  const PatternRun({
    required this.id,
    required this.patternId,
    required this.lineId,
    required this.frameCount,
    required this.runTime,
    this.shade,
    this.isNonStandard = false,
    this.shift,
    this.patternCode,
    this.lineCode,
    this.enteredByName,
  });

  final String id;
  final String patternId;
  final String lineId;
  final int frameCount;
  final DateTime runTime;
  final String? shade;
  final bool isNonStandard;
  final int? shift;
  final String? patternCode;
  final String? lineCode;
  final String? enteredByName;

  factory PatternRun.fromJson(Map<String, dynamic> json) {
    final pattern = asMap(json['pattern']);
    final line = asMap(json['line']);
    final by = asMap(json['enteredBy']);
    return PatternRun(
      id: json['id']?.toString() ?? '',
      patternId: json['pattern_id']?.toString() ?? '',
      lineId: json['line_id']?.toString() ?? '',
      frameCount: asInt(json['frame_count']),
      runTime: asDate(json['run_time']) ?? DateTime.now(),
      shade: asStringOrNull(json['shade']),
      isNonStandard: asBool(json['is_non_standard']),
      shift: asIntOrNull(json['shift']),
      patternCode: asStringOrNull(pattern['code']),
      lineCode: asStringOrNull(line['code']),
      enteredByName: asStringOrNull(by['full_name']),
    );
  }
}

/// The pieces a run produced, echoed back so the operator can see what the app
/// counted rather than having to trust it.
@immutable
class RunPieceLine {
  const RunPieceLine({required this.partLabel, required this.qtyPerFrame, required this.pieces});

  final String partLabel;
  final int qtyPerFrame;
  final int pieces;

  factory RunPieceLine.fromJson(Map<String, dynamic> json) {
    final part = asMap(json['part']);
    return RunPieceLine(
      partLabel:
          '${part['unpainted_pn'] ?? ''} · ${part['description'] ?? ''}'.trim(),
      qtyPerFrame: asInt(json['qty_per_frame'], 1),
      pieces: asInt(json['pieces']),
    );
  }
}

@immutable
class SpdRequest {
  const SpdRequest({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.lineId,
    this.partId,
    this.patternId,
    this.quantity,
    this.reason,
    this.decisionNote,
    this.decidedAt,
    this.part,
    this.patternCode,
    this.lineCode,
    this.requestedByName,
    this.requestedByRole,
    this.approvedByName,
  });

  final String id;
  final RequestType type;
  final RequestStatus status;
  final DateTime createdAt;
  final String? lineId;
  final String? partId;
  final String? patternId;
  final int? quantity;
  final String? reason;
  final String? decisionNote;
  final DateTime? decidedAt;

  final Part? part;
  final String? patternCode;
  final String? lineCode;
  final String? requestedByName;
  final String? requestedByRole;
  final String? approvedByName;

  bool get isPending => status == RequestStatus.pending;

  factory SpdRequest.fromJson(Map<String, dynamic> json) {
    final partJson = asMap(json['part']);
    final pattern = asMap(json['pattern']);
    final line = asMap(json['line']);
    final requestedBy = asMap(json['requestedBy']);
    final approvedBy = asMap(json['approvedBy']);
    return SpdRequest(
      id: json['id']?.toString() ?? '',
      type: RequestType.fromWire(json['type']?.toString()),
      status: RequestStatus.fromWire(json['status']?.toString()),
      createdAt: asDate(json['created_at']) ?? DateTime.now(),
      lineId: asStringOrNull(json['line_id']),
      partId: asStringOrNull(json['part_id']),
      patternId: asStringOrNull(json['pattern_id']),
      quantity: asIntOrNull(json['quantity']),
      reason: asStringOrNull(json['reason']),
      decisionNote: asStringOrNull(json['decision_note']),
      decidedAt: asDate(json['decided_at']),
      part: partJson.isEmpty ? null : Part.fromJson(partJson),
      patternCode: asStringOrNull(pattern['code']),
      lineCode: asStringOrNull(line['code']),
      requestedByName: asStringOrNull(requestedBy['full_name']),
      requestedByRole: asStringOrNull(requestedBy['role']),
      approvedByName: asStringOrNull(approvedBy['full_name']),
    );
  }
}

@immutable
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.qtyDelta,
    required this.reason,
    required this.createdAt,
    this.refTable,
    this.refId,
    this.balanceAfter,
    this.note,
    this.createdByName,
    this.createdByCode,
  });

  final int id;
  final double qtyDelta;
  final LedgerReason reason;
  final DateTime createdAt;
  final String? refTable;
  final String? refId;
  final double? balanceAfter;
  final String? note;
  final String? createdByName;
  final String? createdByCode;

  bool get isReceipt => qtyDelta > 0;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: asInt(json['id']),
        qtyDelta: asDouble(json['qty_delta']),
        reason: LedgerReason.fromWire(json['reason']?.toString()),
        createdAt: asDate(json['created_at']) ?? DateTime.now(),
        refTable: asStringOrNull(json['ref_table']),
        refId: asStringOrNull(json['ref_id']),
        balanceAfter: json['balance_after'] == null ? null : asDouble(json['balance_after']),
        note: asStringOrNull(json['note']),
        createdByName: asStringOrNull(json['created_by_name']),
        createdByCode: asStringOrNull(json['created_by_code']),
      );
}

// ---------------------------------------------------------------------------
// Alerts
// ---------------------------------------------------------------------------

@immutable
class ShortageAlert {
  const ShortageAlert({
    required this.id,
    required this.level,
    required this.status,
    required this.createdAt,
    this.partId,
    this.lineId,
    this.machinesCovered,
    this.firstBlockedSerial,
    this.safeUntilSerial,
    this.availableStock,
    this.shortfallQty,
    this.message,
    this.acknowledgedAt,
    this.acknowledgedByName,
    this.part,
    this.lineCode,
  });

  final String id;
  final AlertLevel level;
  final AlertStatus status;
  final DateTime createdAt;
  final String? partId;
  final String? lineId;
  final int? machinesCovered;
  final String? firstBlockedSerial;
  final String? safeUntilSerial;
  final double? availableStock;
  final double? shortfallQty;
  final String? message;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByName;
  final Part? part;
  final String? lineCode;

  bool get isRed => level == AlertLevel.red;
  bool get isAcknowledged => status == AlertStatus.acknowledged;

  factory ShortageAlert.fromJson(Map<String, dynamic> json) {
    final partJson = asMap(json['part']);
    final line = asMap(json['line']);
    final ackBy = asMap(json['acknowledgedBy']);
    return ShortageAlert(
      id: json['id']?.toString() ?? '',
      level: AlertLevel.fromWire(json['level']?.toString()) ?? AlertLevel.yellow,
      status: AlertStatus.fromWire(json['status']?.toString()),
      createdAt: asDate(json['created_at']) ?? DateTime.now(),
      partId: asStringOrNull(json['part_id']),
      lineId: asStringOrNull(json['line_id']),
      machinesCovered: asIntOrNull(json['machines_covered']),
      firstBlockedSerial: asStringOrNull(json['first_blocked_serial']),
      safeUntilSerial: asStringOrNull(json['safe_until_serial']),
      availableStock: json['available_stock'] == null ? null : asDouble(json['available_stock']),
      shortfallQty: json['shortfall_qty'] == null ? null : asDouble(json['shortfall_qty']),
      message: asStringOrNull(json['message']),
      acknowledgedAt: asDate(json['acknowledged_at']),
      acknowledgedByName: asStringOrNull(ackBy['full_name']),
      part: partJson.isEmpty ? null : Part.fromJson(partJson),
      lineCode: asStringOrNull(line['code']),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

@immutable
class TodayCounters {
  const TodayCounters({
    this.nestingEntries = 0,
    this.nestingQty = 0,
    this.patternRuns = 0,
    this.frames = 0,
    this.machinesBuilt = 0,
    this.pendingApprovals = 0,
  });

  final int nestingEntries;
  final double nestingQty;
  final int patternRuns;
  final int frames;
  final int machinesBuilt;
  final int pendingApprovals;

  factory TodayCounters.fromJson(Map<String, dynamic> json) => TodayCounters(
        nestingEntries: asInt(json['nesting_entries']),
        nestingQty: asDouble(json['nesting_qty']),
        patternRuns: asInt(json['pattern_runs']),
        frames: asInt(json['frames']),
        machinesBuilt: asInt(json['machines_built']),
        pendingApprovals: asInt(json['pending_approvals']),
      );
}

/// The answer to the question the plant asks every morning: which machine stops
/// first, and because of what.
@immutable
class FirstAffected {
  const FirstAffected({
    required this.serialNo,
    required this.machinesAhead,
    required this.partLabel,
    this.rackCode,
    this.shortfallQty = 0,
    this.partId,
  });

  final String serialNo;
  final int machinesAhead;
  final String partLabel;
  final String? rackCode;
  final double shortfallQty;
  final String? partId;

  factory FirstAffected.fromJson(Map<String, dynamic> json) {
    final part = asMap(json['part']);
    return FirstAffected(
      serialNo: json['serial_no']?.toString() ?? '',
      machinesAhead: asInt(json['machines_ahead']),
      partLabel: '${part['unpainted_pn'] ?? ''} · ${part['description'] ?? ''}'.trim(),
      rackCode: asStringOrNull(part['rack_code']),
      shortfallQty: asDouble(json['shortfall_qty']),
      partId: asStringOrNull(part['id']),
    );
  }
}

@immutable
class CriticalPart {
  const CriticalPart({
    required this.partId,
    required this.label,
    required this.level,
    required this.availableStock,
    required this.machinesCovered,
    this.rackCode,
    this.firstBlockedSerial,
    this.shortfallQty = 0,
  });

  final String partId;
  final String label;
  final AlertLevel level;
  final double availableStock;
  final int machinesCovered;
  final String? rackCode;
  final String? firstBlockedSerial;
  final double shortfallQty;

  factory CriticalPart.fromJson(Map<String, dynamic> json) {
    final part = asMap(json['part']);
    return CriticalPart(
      partId: part['id']?.toString() ?? '',
      label: '${part['unpainted_pn'] ?? ''} · ${part['description'] ?? ''}'.trim(),
      level: AlertLevel.fromWire(json['level']?.toString()) ?? AlertLevel.yellow,
      availableStock: asDouble(json['available_stock']),
      machinesCovered: asInt(json['machines_covered']),
      rackCode: asStringOrNull(part['rack_code']),
      firstBlockedSerial: asStringOrNull(json['first_blocked_serial']),
      shortfallQty: asDouble(json['shortfall_qty']),
    );
  }
}

@immutable
class LineHealth {
  const LineHealth({
    required this.line,
    required this.counts,
    required this.planTotal,
    required this.planBuilt,
    required this.planPending,
    this.nextMachineSerial,
    this.firstAffected,
    this.criticalParts = const [],
    this.redAlerts = 0,
    this.yellowAlerts = 0,
    this.unacknowledged = 0,
  });

  final ProductionLine line;
  final CoverageCounts counts;
  final int planTotal;
  final int planBuilt;
  final int planPending;
  final String? nextMachineSerial;
  final FirstAffected? firstAffected;
  final List<CriticalPart> criticalParts;
  final int redAlerts;
  final int yellowAlerts;
  final int unacknowledged;

  double get planProgress => planTotal == 0 ? 0 : planBuilt / planTotal;

  /// Worst state on this line, for the card's accent.
  AlertLevel? get worstLevel {
    if (counts.red > 0) return AlertLevel.red;
    if (counts.yellow > 0) return AlertLevel.yellow;
    return null;
  }

  factory LineHealth.fromJson(Map<String, dynamic> json) {
    final plan = asMap(json['plan']);
    final next = asMap(json['next_machine']);
    final alerts = asMap(json['alerts']);
    final first = asMap(json['first_affected']);
    return LineHealth(
      line: ProductionLine.fromJson(asMap(json['line'])),
      counts: CoverageCounts.fromJson(asMap(json['counts'])),
      planTotal: asInt(plan['total']),
      planBuilt: asInt(plan['built']),
      planPending: asInt(plan['pending']),
      nextMachineSerial: asStringOrNull(next['serial_no']),
      firstAffected: first.isEmpty ? null : FirstAffected.fromJson(first),
      criticalParts: asList(json['critical_parts']).map(CriticalPart.fromJson).toList(),
      redAlerts: asInt(alerts['red']),
      yellowAlerts: asInt(alerts['yellow']),
      unacknowledged: asInt(alerts['unacknowledged']),
    );
  }
}

@immutable
class DashboardData {
  const DashboardData({
    required this.today,
    required this.lines,
    required this.totals,
    required this.generatedAt,
  });

  final TodayCounters today;
  final List<LineHealth> lines;
  final CoverageCounts totals;
  final DateTime generatedAt;

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        today: TodayCounters.fromJson(asMap(json['today'])),
        lines: asList(json['lines']).map(LineHealth.fromJson).toList(),
        totals: CoverageCounts.fromJson(asMap(json['totals'])),
        generatedAt: asDate(json['generated_at']) ?? DateTime.now(),
      );
}

@immutable
class BadgeCounts {
  const BadgeCounts({this.redAlerts = 0, this.yellowAlerts = 0, this.pendingApprovals = 0});

  final int redAlerts;
  final int yellowAlerts;
  final int pendingApprovals;

  int get totalAlerts => redAlerts + yellowAlerts;

  factory BadgeCounts.fromJson(Map<String, dynamic> json) => BadgeCounts(
        redAlerts: asInt(json['red_alerts']),
        yellowAlerts: asInt(json['yellow_alerts']),
        pendingApprovals: asInt(json['pending_approvals']),
      );
}

// ---------------------------------------------------------------------------
// Reports & imports
// ---------------------------------------------------------------------------

@immutable
class ReportDefinition {
  const ReportDefinition({
    required this.type,
    required this.title,
    required this.description,
    required this.formats,
    this.needsLine = false,
    this.supportsDateRange = false,
  });

  final String type;
  final String title;
  final String description;
  final List<String> formats;
  final bool needsLine;
  final bool supportsDateRange;

  factory ReportDefinition.fromJson(Map<String, dynamic> json) => ReportDefinition(
        type: json['type']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        formats: (json['formats'] as List? ?? const ['xlsx']).map((f) => f.toString()).toList(),
        needsLine: asBool(json['needs_line']),
        supportsDateRange: asBool(json['supports_date_range']),
      );
}

@immutable
class ImportBatch {
  const ImportBatch({
    required this.id,
    required this.sourceFile,
    required this.target,
    required this.status,
    this.rowCount = 0,
    this.okCount = 0,
    this.errorCount = 0,
    this.report,
    this.committedAt,
    this.createdAt,
    this.importedByName,
  });

  final String id;
  final String sourceFile;
  final String target;
  final String status;
  final int rowCount;
  final int okCount;
  final int errorCount;
  final Map<String, dynamic>? report;
  final DateTime? committedAt;
  final DateTime? createdAt;
  final String? importedByName;

  bool get isDryRun => status == 'dry_run';
  bool get isCommitted => status == 'committed';
  bool get hasErrors => errorCount > 0;

  /// Per-row checking rows from the report blob.
  List<Map<String, dynamic>> get reportRows => asList(report?['rows']);

  factory ImportBatch.fromJson(Map<String, dynamic> json) {
    final by = asMap(json['importedBy']);
    return ImportBatch(
      // The dry-run response names it `batch_id`; the list endpoint names it `id`.
      id: (json['id'] ?? json['batch_id'])?.toString() ?? '',
      sourceFile: json['source_file']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
      status: json['status']?.toString() ?? 'dry_run',
      rowCount: asInt(json['row_count']),
      okCount: asInt(json['ok_count']),
      errorCount: asInt(json['error_count']),
      report: json['report'] is Map<String, dynamic> ? json['report'] as Map<String, dynamic> : null,
      committedAt: asDate(json['committed_at']),
      createdAt: asDate(json['created_at']),
      importedByName: asStringOrNull(by['full_name']),
    );
  }
}

@immutable
class ImportTarget {
  const ImportTarget({
    required this.target,
    required this.title,
    required this.columns,
    this.needsLine = false,
    this.note,
  });

  final String target;
  final String title;
  final List<String> columns;
  final bool needsLine;
  final String? note;

  factory ImportTarget.fromJson(Map<String, dynamic> json) => ImportTarget(
        target: json['target']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        columns: (json['columns'] as List? ?? const []).map((c) => c.toString()).toList(),
        needsLine: asBool(json['needs_line']),
        note: asStringOrNull(json['note']),
      );
}

@immutable
class AuditRecord {
  const AuditRecord({
    required this.id,
    required this.action,
    required this.entity,
    required this.createdAt,
    this.entityId,
    this.before,
    this.after,
    this.actorName,
    this.actorCode,
    this.actorRole,
  });

  final int id;
  final String action;
  final String entity;
  final DateTime createdAt;
  final String? entityId;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final String? actorName;
  final String? actorCode;
  final String? actorRole;

  factory AuditRecord.fromJson(Map<String, dynamic> json) {
    final actor = asMap(json['actor']);
    return AuditRecord(
      id: asInt(json['id']),
      action: json['action']?.toString() ?? '',
      entity: json['entity']?.toString() ?? '',
      createdAt: asDate(json['created_at']) ?? DateTime.now(),
      entityId: asStringOrNull(json['entity_id']),
      before: json['before'] is Map<String, dynamic> ? json['before'] as Map<String, dynamic> : null,
      after: json['after'] is Map<String, dynamic> ? json['after'] as Map<String, dynamic> : null,
      actorName: asStringOrNull(actor['full_name']),
      actorCode: asStringOrNull(actor['emp_code']),
      actorRole: asStringOrNull(actor['role']),
    );
  }
}

// ---------------------------------------------------------------------------
// Sync
// ---------------------------------------------------------------------------

/// Per-item outcome from /sync/batch.
@immutable
class SyncItemResult {
  const SyncItemResult({
    required this.clientUuid,
    required this.status,
    this.kind,
    this.serverId,
    this.error,
    this.code,
    this.serverState,
  });

  final String clientUuid;

  /// 'synced' | 'duplicate' | 'conflict' | 'error'
  final String status;

  final String? kind;
  final String? serverId;
  final String? error;
  final String? code;
  final Map<String, dynamic>? serverState;

  /// A duplicate is a SUCCESS from the device's point of view: the server
  /// already has the entry, so the queue row is done.
  bool get isAccepted => status == 'synced' || status == 'duplicate';
  bool get isConflict => status == 'conflict';

  factory SyncItemResult.fromJson(Map<String, dynamic> json) => SyncItemResult(
        clientUuid: json['client_uuid']?.toString() ?? '',
        status: json['status']?.toString() ?? 'error',
        kind: asStringOrNull(json['kind']),
        serverId: asStringOrNull(json['server_id']),
        error: asStringOrNull(json['error']),
        code: asStringOrNull(json['code']),
        serverState: json['server_state'] is Map<String, dynamic>
            ? json['server_state'] as Map<String, dynamic>
            : null,
      );
}

@immutable
class SyncBatchResult {
  const SyncBatchResult({
    required this.results,
    this.synced = 0,
    this.duplicates = 0,
    this.conflicts = 0,
    this.errors = 0,
  });

  final List<SyncItemResult> results;
  final int synced;
  final int duplicates;
  final int conflicts;
  final int errors;

  int get accepted => synced + duplicates;

  factory SyncBatchResult.fromJson(Map<String, dynamic> json) {
    final summary = asMap(json['summary']);
    return SyncBatchResult(
      results: asList(json['results']).map(SyncItemResult.fromJson).toList(),
      synced: asInt(summary['synced']),
      duplicates: asInt(summary['duplicates']),
      conflicts: asInt(summary['conflicts']),
      errors: asInt(summary['errors']),
    );
  }
}
