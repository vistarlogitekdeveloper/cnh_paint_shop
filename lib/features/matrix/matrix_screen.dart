import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../../router/app_router.dart';
import '../common/common_widgets.dart';

/// ---------------------------------------------------------------------------
/// The Shortage Matrix — "the same machine-wise sheet you use today".
///
/// Parts down the rows, machine serial numbers across the columns, each cell the
/// running balance AFTER that machine is built. Negative cells are red. That is
/// exactly how the Excel tracker reads, and reproducing it faithfully is what
/// makes the app adoptable rather than a thing to be learned.
///
/// The hard part is the grid mechanics. A 65 × 270 sheet cannot be a Table:
///   * The part column must stay put while the machine columns scroll sideways.
///   * The machine header must stay put while the rows scroll vertically.
///   * Both must scroll in lockstep with the body, on touch AND trackpad.
///
/// So the layout is four quadrants sharing two linked scroll groups — one
/// horizontal (header ↔ body), one vertical (part column ↔ body) — and the body
/// cells are built lazily so only the visible rows are ever laid out.
/// ---------------------------------------------------------------------------

/// Window size. Requested from the server rather than fetched whole: a grown plan
/// is 500 parts × 1000 machines, and half a million cells is not a payload.
const int _machineWindow = 40;
const int _partWindow = 60;

/// Column geometry. Fixed widths, because a matrix whose columns resize as data
/// changes is unreadable — the eye needs to track down a column.
const double _partColumnWidth = 232;
const double _cellWidth = 58;
const double _rowHeight = 46;
const double _headerHeight = 56;

final _matrixWindowProvider = StateProvider<({int machineOffset, int partOffset})>(
  (ref) => (machineOffset: 0, partOffset: 0),
);

final _matrixSearchProvider = StateProvider<String>((ref) => '');
final _matrixLevelProvider = StateProvider<String>((ref) => 'all');

final _matrixProvider = FutureProvider.autoDispose<MatrixResult>((ref) async {
  final lineId = ref.watch(selectedLineIdProvider);
  if (lineId == null) throw Exception('Pick a production line first.');

  final window = ref.watch(_matrixWindowProvider);
  final search = ref.watch(_matrixSearchProvider);
  final level = ref.watch(_matrixLevelProvider);

  return ref.watch(coverageRepositoryProvider).matrix(
        lineId: lineId,
        machineLimit: _machineWindow,
        machineOffset: window.machineOffset,
        partLimit: _partWindow,
        partOffset: window.partOffset,
        search: search.isEmpty ? null : search,
        level: level,
      );
});

class MatrixScreen extends ConsumerStatefulWidget {
  const MatrixScreen({super.key});

  @override
  ConsumerState<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends ConsumerState<MatrixScreen> {
  late final LinkedScrollControllerGroup _horizontal;
  late final ScrollController _headerH;
  late final ScrollController _bodyH;

  late final LinkedScrollControllerGroup _vertical;
  late final ScrollController _partColumnV;
  late final ScrollController _bodyV;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _horizontal = LinkedScrollControllerGroup();
    _headerH = _horizontal.addAndGet();
    _bodyH = _horizontal.addAndGet();

    _vertical = LinkedScrollControllerGroup();
    _partColumnV = _vertical.addAndGet();
    _bodyV = _vertical.addAndGet();
  }

  @override
  void dispose() {
    _headerH.dispose();
    _bodyH.dispose();
    _partColumnV.dispose();
    _bodyV.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_matrixProvider);

    return LineRequired(
      builder: (context, line) => Column(
        children: [
          _MatrixToolbar(line: line, searchController: _searchController),
          Expanded(
            child: async.when(
              loading: () => const _MatrixSkeleton(),
              error: (error, _) => VErrorState(
                message: describeError(error),
                onRetry: () => ref.invalidate(_matrixProvider),
              ),
              data: (result) {
                if (result.rows.isEmpty) {
                  return VEmptyState(
                    title: 'No parts match',
                    message: ref.read(_matrixSearchProvider).isEmpty
                        ? 'This line has no BOM yet — an admin needs to import the QPV list '
                            'before coverage can be calculated.'
                        : 'Nothing matches that search on ${line.code}.',
                    icon: Icons.grid_off_rounded,
                    actionLabel: 'Clear filters',
                    onAction: () {
                      _searchController.clear();
                      ref.read(_matrixSearchProvider.notifier).state = '';
                      ref.read(_matrixLevelProvider.notifier).state = 'all';
                    },
                  );
                }
                return _MatrixGrid(
                  result: result,
                  headerH: _headerH,
                  bodyH: _bodyH,
                  partColumnV: _partColumnV,
                  bodyV: _bodyV,
                );
              },
            ),
          ),
          if (async.hasValue) _MatrixPager(result: async.requireValue),
        ],
      ),
    );
  }
}

class _MatrixToolbar extends ConsumerWidget {
  const _MatrixToolbar({required this.line, required this.searchController});

  final ProductionLine line;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final level = ref.watch(_matrixLevelProvider);
    final user = ref.watch(currentUserProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(VSpace.lg, VSpace.md, VSpace.lg, VSpace.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: v.line)),
      ),
      child: Wrap(
        spacing: VSpace.md,
        runSpacing: VSpace.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Shortage Matrix', style: context.text.titleLarge),
              Text(
                '${line.name} · cells show the balance after that machine',
                style: context.text.bodySmall?.copyWith(color: v.txt3),
              ),
            ],
          ),
          SizedBox(
            width: 250,
            child: VSearchField(
              controller: searchController,
              hint: 'Part number or description',
              onChanged: (value) {
                ref.read(_matrixSearchProvider.notifier).state = value;
                // A new search invalidates the current page.
                ref.read(_matrixWindowProvider.notifier).state =
                    (machineOffset: 0, partOffset: 0);
              },
            ),
          ),
          VSegmented<String>(
            value: level,
            onChanged: (next) {
              ref.read(_matrixLevelProvider.notifier).state = next;
              ref.read(_matrixWindowProvider.notifier).state =
                  (machineOffset: 0, partOffset: 0);
            },
            segments: const [
              (value: 'all', label: 'All', icon: null),
              (value: 'red', label: 'Critical', icon: Icons.error_rounded),
              (value: 'yellow', label: 'Warning', icon: Icons.warning_amber_rounded),
            ],
          ),
          const _MatrixLegend(),
          if (user?.can(Perm.reportView) ?? false)
            VButton.ghost(
              label: 'Export',
              icon: Icons.download_rounded,
              size: VButtonSize.small,
              onPressed: () => context.go(Routes.reports),
            ),
          VButton.ghost(
            label: 'Refresh',
            icon: Icons.refresh_rounded,
            size: VButtonSize.small,
            onPressed: () => ref.invalidate(_matrixProvider),
          ),
        ],
      ),
    );
  }
}

class _MatrixLegend extends StatelessWidget {
  const _MatrixLegend();

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendDot(color: v.bad, label: 'Cannot build'),
        const SizedBox(width: VSpace.sm),
        _LegendDot(color: v.warn, label: 'Running low'),
        const SizedBox(width: VSpace.sm),
        _LegendDot(color: v.ok, label: 'Covered'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.text.labelSmall?.copyWith(color: context.v.txt3, fontSize: 10),
        ),
      ],
    );
  }
}

/// The four-quadrant grid.
class _MatrixGrid extends StatelessWidget {
  const _MatrixGrid({
    required this.result,
    required this.headerH,
    required this.bodyH,
    required this.partColumnV,
    required this.bodyV,
  });

  final MatrixResult result;
  final ScrollController headerH;
  final ScrollController bodyH;
  final ScrollController partColumnV;
  final ScrollController bodyV;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final machines = result.machines;
    final rows = result.rows;

    return Column(
      children: [
        // ---- top strip: frozen corner + scrolling machine header ----
        SizedBox(
          height: _headerHeight,
          child: Row(
            children: [
              _CornerCell(rowCount: rows.length, machineCount: machines.length),
              Expanded(
                child: ListView.builder(
                  controller: headerH,
                  scrollDirection: Axis.horizontal,
                  // The header must never be independently scrollable — it is a
                  // slave to the body's horizontal controller.
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: machines.length,
                  itemExtent: _cellWidth,
                  itemBuilder: (context, index) => _MachineHeaderCell(
                    machine: machines[index],
                    // The group band only prints when it CHANGES, the way the
                    // Rotavator sheet labels a block of columns once.
                    showGroup: index == 0 ||
                        machines[index].groupLabel != machines[index - 1].groupLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: v.line2),

        // ---- body: frozen part column + scrolling cells ----
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: _partColumnWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: v.surface,
                    border: Border(right: BorderSide(color: v.line2)),
                  ),
                  child: ListView.builder(
                    controller: partColumnV,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length,
                    itemExtent: _rowHeight,
                    itemBuilder: (context, index) => _PartCell(
                      row: rows[index],
                      zebra: index.isOdd,
                    ),
                  ),
                ),
              ),
              Expanded(
                // ONE horizontal scroll view wrapping the vertical list.
                //
                // The rows cannot each be their own horizontal ListView sharing a
                // controller — a ScrollController may only be attached to one
                // scroll view, and doing so throws. Nesting it this way gives a
                // single horizontal position for every row by construction, and
                // the vertical ListView inside still builds rows lazily.
                child: Scrollbar(
                  controller: bodyH,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  child: SingleChildScrollView(
                    controller: bodyH,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: machines.length * _cellWidth,
                      child: Scrollbar(
                        controller: bodyV,
                        child: ListView.builder(
                          controller: bodyV,
                          itemCount: rows.length,
                          itemExtent: _rowHeight,
                          itemBuilder: (context, rowIndex) => _CellRow(
                            row: rows[rowIndex],
                            machines: machines,
                            zebra: rowIndex.isOdd,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The frozen top-left cell. Shows what the axes mean, since the grid itself is
/// just numbers.
class _CornerCell extends StatelessWidget {
  const _CornerCell({required this.rowCount, required this.machineCount});

  final int rowCount;
  final int machineCount;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Container(
      width: _partColumnWidth,
      padding: const EdgeInsets.symmetric(horizontal: VSpace.md, vertical: VSpace.xs),
      decoration: BoxDecoration(
        color: v.surface2,
        border: Border(right: BorderSide(color: v.line2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PART  ↓',
            style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9.5),
          ),
          const SizedBox(height: 1),
          Text(
            'MACHINE  →',
            style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9.5),
          ),
          const SizedBox(height: 2),
          Text(
            '$rowCount parts × $machineCount machines',
            style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _MachineHeaderCell extends StatelessWidget {
  const _MachineHeaderCell({required this.machine, required this.showGroup});

  final MatrixMachine machine;
  final bool showGroup;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Container(
      width: _cellWidth,
      decoration: BoxDecoration(
        color: machine.isSpecial ? v.accentTint : v.surface2,
        border: Border(left: BorderSide(color: v.line)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The variant / project band.
          SizedBox(
            height: 16,
            child: showGroup && machine.groupLabel != null
                ? Text(
                    machine.groupLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: context.text.labelSmall?.copyWith(
                      color: VRibbon.violet,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  )
                : null,
          ),
          Text(
            machine.serialNo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              color: machine.isSpecial ? v.accent : v.txt2,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (machine.isSpecial)
            Icon(Icons.star_rounded, size: 9, color: v.accent)
          else
            const SizedBox(height: 9),
        ],
      ),
    );
  }
}

/// The frozen part cell: the sheet's left block, compressed to what fits.
class _PartCell extends StatelessWidget {
  const _PartCell({required this.row, required this.zebra});

  final CoverageRow row;
  final bool zebra;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final status = statusFor(row.level);
    final accent = v.forStatus(status);

    return Container(
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: VSpace.sm),
      decoration: BoxDecoration(
        color: row.level != null
            ? v.tintFor(status).withValues(alpha: 0.5)
            : (zebra ? v.surface2.withValues(alpha: 0.4) : Colors.transparent),
        border: Border(bottom: BorderSide(color: v.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 26,
            decoration: BoxDecoration(
              color: row.level == null ? v.line2 : accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: VSpace.xs),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.part.unpaintedPn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: v.txt,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  row.part.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: v.txt3, fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: VSpace.xs),
          // Total (the sheet's 'Total' column) and QPV, the two numbers a reader
          // needs beside the row to interpret the cells.
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtQty(row.availableStock),
                style: context.text.labelMedium?.copyWith(
                  color: row.availableStock < 0 ? v.bad : v.txt,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'QPV ${row.qpv}',
                style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One row of cells — a plain Row inside the shared horizontal viewport, so it
/// owns no scroll position of its own.
///
/// Building all of the window's cells per row is deliberate: the window is capped
/// at 40 machines, so a visible page is ~40 × 15 = 600 lightweight containers,
/// which is cheaper than the bookkeeping a nested lazy axis would need.
class _CellRow extends StatelessWidget {
  const _CellRow({required this.row, required this.machines, required this.zebra});

  final CoverageRow row;
  final List<MatrixMachine> machines;
  final bool zebra;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          for (var index = 0; index < machines.length; index++)
            _BalanceCell(
              balance: index < row.cells.length ? row.cells[index] : null,
              machine: machines[index],
              partLabel: row.part.displayLabel,
              zebra: zebra,
            ),
        ],
      ),
    );
  }
}

/// One cell: the running balance after that machine. Negative is the wall.
class _BalanceCell extends StatelessWidget {
  const _BalanceCell({
    required this.balance,
    required this.machine,
    required this.partLabel,
    required this.zebra,
  });

  final double? balance;
  final MatrixMachine machine;
  final String partLabel;
  final bool zebra;

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    if (balance == null) {
      return Container(
        width: _cellWidth,
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: v.line),
            bottom: BorderSide(color: v.line),
          ),
        ),
      );
    }

    final short = balance! < 0;
    // Amber for the last few units of cover: the Excel sheet only shows red, but
    // the whole point of the app is warning BEFORE the wall, so the approach is
    // coloured too.
    final low = !short && balance! <= 5;

    final bg = short
        ? v.badTint
        : (low ? v.warnTint : (zebra ? v.surface2.withValues(alpha: 0.35) : Colors.transparent));
    final fg = short ? v.bad : (low ? v.warn : v.txt2);

    return Tooltip(
      message: '$partLabel\nAfter machine ${machine.serialNo}: ${fmtQty(balance!)} pcs'
          '${short ? ' — CANNOT BUILD' : ''}',
      waitDuration: const Duration(milliseconds: 500),
      child: Container(
        width: _cellWidth,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            left: BorderSide(color: v.line),
            bottom: BorderSide(color: v.line),
          ),
        ),
        child: Text(
          fmtQty(balance!),
          style: context.text.labelMedium?.copyWith(
            color: fg,
            fontSize: 11.5,
            fontWeight: short ? FontWeight.w800 : FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Window paging on both axes.
class _MatrixPager extends ConsumerWidget {
  const _MatrixPager({required this.result});

  final MatrixResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final window = ref.watch(_matrixWindowProvider);
    final machineMeta = result.machineMeta;
    final partMeta = result.partMeta;

    void setWindow({int? machineOffset, int? partOffset}) {
      ref.read(_matrixWindowProvider.notifier).state = (
        machineOffset: machineOffset ?? window.machineOffset,
        partOffset: partOffset ?? window.partOffset,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VSpace.lg, vertical: VSpace.sm),
      decoration: BoxDecoration(
        color: v.surface,
        border: Border(top: BorderSide(color: v.line)),
      ),
      child: Wrap(
        spacing: VSpace.lg,
        runSpacing: VSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _AxisPager(
            label: 'Machines',
            offset: machineMeta.offset,
            limit: machineMeta.limit,
            total: machineMeta.total,
            onPrevious: window.machineOffset > 0
                ? () => setWindow(
                      machineOffset: (window.machineOffset - _machineWindow).clamp(0, 1 << 30),
                    )
                : null,
            onNext: machineMeta.hasMore
                ? () => setWindow(machineOffset: window.machineOffset + _machineWindow)
                : null,
            onFirst: window.machineOffset > 0 ? () => setWindow(machineOffset: 0) : null,
          ),
          Container(width: 1, height: 22, color: v.line),
          _AxisPager(
            label: 'Parts',
            offset: partMeta.offset,
            limit: partMeta.limit,
            total: partMeta.total,
            onPrevious: window.partOffset > 0
                ? () => setWindow(partOffset: (window.partOffset - _partWindow).clamp(0, 1 << 30))
                : null,
            onNext: partMeta.hasMore
                ? () => setWindow(partOffset: window.partOffset + _partWindow)
                : null,
            onFirst: window.partOffset > 0 ? () => setWindow(partOffset: 0) : null,
          ),
        ],
      ),
    );
  }
}

class _AxisPager extends StatelessWidget {
  const _AxisPager({
    required this.label,
    required this.offset,
    required this.limit,
    required this.total,
    this.onPrevious,
    this.onNext,
    this.onFirst,
  });

  final String label;
  final int offset;
  final int limit;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onFirst;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final from = total == 0 ? 0 : offset + 1;
    final to = (offset + limit).clamp(0, total);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${label.toUpperCase()}  $from–$to of $total',
          style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 10.5),
        ),
        const SizedBox(width: VSpace.xs),
        VIconButton(
          icon: Icons.first_page_rounded,
          size: 30,
          iconSize: 16,
          filled: false,
          tooltip: 'Back to the start',
          onPressed: onFirst,
        ),
        VIconButton(
          icon: Icons.chevron_left_rounded,
          size: 30,
          iconSize: 18,
          filled: false,
          tooltip: 'Previous',
          onPressed: onPrevious,
        ),
        VIconButton(
          icon: Icons.chevron_right_rounded,
          size: 30,
          iconSize: 18,
          filled: false,
          tooltip: 'Next',
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _MatrixSkeleton extends StatelessWidget {
  const _MatrixSkeleton();

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return VShimmerScope(
      child: Column(
        children: [
          Container(
            height: _headerHeight,
            color: v.surface2,
            padding: const EdgeInsets.symmetric(horizontal: VSpace.md, vertical: VSpace.md),
            child: Row(
              children: [
                const VSkeleton(width: _partColumnWidth - 24, height: 16),
                const SizedBox(width: VSpace.lg),
                for (var i = 0; i < 12; i++) ...[
                  const VSkeleton(width: 34, height: 14),
                  const SizedBox(width: VSpace.md),
                ],
              ],
            ),
          ),
          for (var r = 0; r < 10; r++)
            Container(
              height: _rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: VSpace.md, vertical: VSpace.sm),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: v.line)),
              ),
              child: Row(
                children: [
                  VSkeleton.text(width: 130 + (r % 3) * 30),
                  const Spacer(),
                  for (var i = 0; i < 12; i++) ...[
                    const VSkeleton(width: 30, height: 13),
                    const SizedBox(width: VSpace.md),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
