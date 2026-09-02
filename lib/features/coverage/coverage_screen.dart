import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../../router/app_router.dart';
import '../common/common_widgets.dart';

/// Part Coverage — "for every part: how many pieces are ready, up to which
/// machine you are safe, and where it runs out." Sorted most-critical first.
///
/// This is the list form of the matrix. It exists because the matrix answers
/// "what does the sheet look like" while this answers "what do I do next", and
/// the second question needs the parts ranked rather than laid out.
class CoverageScreen extends ConsumerWidget {
  const CoverageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coverageProvider);
    final filters = ref.watch(coverageFiltersProvider);

    return LineRequired(
      builder: (context, line) => AsyncBody<CoverageResult>(
        value: async,
        onRefresh: () async => ref.invalidate(coverageProvider),
        isEmpty: (data) => data.rows.isEmpty,
        emptyTitle: filters.level == 'all' ? 'No parts on this line yet' : 'Nothing at this level',
        emptyMessage: filters.level == 'all'
            ? 'An admin needs to import the BOM (QPV list) for ${line.name} before coverage '
                'can be calculated.'
            : 'Good news — no ${filters.level == 'red' ? 'critical' : 'warning'} parts on '
                '${line.code} right now.',
        builder: (context, result) => VPageBody(
          children: [
            VPageHeader(
              breadcrumb: const ['Shortage', 'Part Coverage'],
              title: 'Part Coverage',
              description: '${result.line.name} · thresholds ${result.line.yellowThreshold} '
                  'machines (warning) / ${result.line.redThreshold} (critical). '
                  '${result.planLength} machines planned'
                  '${result.nextMachineSerial != null ? ', next is ${result.nextMachineSerial}' : ''}.',
              actions: [
                VButton.ghost(
                  label: 'Matrix view',
                  icon: Icons.grid_on_rounded,
                  size: VButtonSize.small,
                  onPressed: () => context.go(Routes.matrix),
                ),
                VButton.ghost(
                  label: 'Refresh',
                  icon: Icons.refresh_rounded,
                  size: VButtonSize.small,
                  onPressed: () => ref.invalidate(coverageProvider),
                ),
              ],
            ),

            _CoverageSummary(counts: result.counts),
            const SizedBox(height: VSpace.lg),
            const _CoverageToolbar(),
            const SizedBox(height: VSpace.md),

            for (final row in result.rows)
              Padding(
                padding: const EdgeInsets.only(bottom: VSpace.sm),
                child: CoverageRowCard(
                  row: row,
                  onTap: () => _showPartSheet(context, ref, row, result.line),
                  onCheckMachine: (serial) => context.go('${Routes.canBuild}?serial=$serial'),
                ),
              ),

            if (result.hasMore)
              Padding(
                padding: const EdgeInsets.only(top: VSpace.md),
                child: Center(
                  child: Text(
                    'Showing ${result.rows.length} of ${result.total} parts — '
                    'narrow the search to see the rest.',
                    style: context.text.bodySmall?.copyWith(color: context.v.txt3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPartSheet(
    BuildContext context,
    WidgetRef ref,
    CoverageRow row,
    ProductionLine line,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.v.bg2,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (sheetContext) => _PartDetailSheet(row: row, line: line),
    );
  }
}

class _CoverageSummary extends ConsumerWidget {
  const _CoverageSummary({required this.counts});

  final CoverageCounts counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    return VCardGrid(
      minTileWidth: 190,
      children: [
        VKpiCard(
          label: 'Critical',
          value: '${counts.red}',
          icon: Icons.error_rounded,
          iconColor: v.bad,
          iconBackground: v.badTint,
          valueColor: counts.red > 0 ? v.bad : null,
          onTap: () => ref.read(coverageFiltersProvider.notifier).setLevel('red'),
        ),
        VKpiCard(
          label: 'Warning',
          value: '${counts.yellow}',
          icon: Icons.warning_amber_rounded,
          iconColor: v.warn,
          iconBackground: v.warnTint,
          valueColor: counts.yellow > 0 ? v.warn : null,
          onTap: () => ref.read(coverageFiltersProvider.notifier).setLevel('yellow'),
        ),
        VKpiCard(
          label: 'Covered',
          value: '${counts.ok}',
          icon: Icons.verified_rounded,
          iconColor: v.ok,
          iconBackground: v.okTint,
          onTap: () => ref.read(coverageFiltersProvider.notifier).setLevel('all'),
        ),
        VKpiCard(
          label: 'Parts tracked',
          value: '${counts.total}',
          icon: Icons.inventory_2_rounded,
        ),
      ],
    );
  }
}

class _CoverageToolbar extends ConsumerStatefulWidget {
  const _CoverageToolbar();

  @override
  ConsumerState<_CoverageToolbar> createState() => _CoverageToolbarState();
}

class _CoverageToolbarState extends ConsumerState<_CoverageToolbar> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(coverageFiltersProvider).search;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(coverageFiltersProvider);

    return Wrap(
      spacing: VSpace.md,
      runSpacing: VSpace.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: VSearchField(
            controller: _controller,
            hint: 'Part number or description',
            onChanged: (value) => ref.read(coverageFiltersProvider.notifier).setSearch(value),
          ),
        ),
        VSegmented<String>(
          value: filters.level,
          onChanged: (next) => ref.read(coverageFiltersProvider.notifier).setLevel(next),
          segments: const [
            (value: 'all', label: 'All', icon: null),
            (value: 'red', label: 'Critical', icon: Icons.error_rounded),
            (value: 'yellow', label: 'Warning', icon: Icons.warning_amber_rounded),
          ],
        ),
        VSegmented<String>(
          value: filters.sort,
          onChanged: (next) => ref.read(coverageFiltersProvider.notifier).setSort(next),
          segments: const [
            (value: 'critical', label: 'Most critical', icon: Icons.priority_high_rounded),
            (value: 'coverage', label: 'Least cover', icon: Icons.trending_down_rounded),
            (value: 'part', label: 'Part no.', icon: Icons.sort_by_alpha_rounded),
          ],
        ),
      ],
    );
  }
}

/// The part drill-in: the walk explained, plus the ledger that proves the number.
class _PartDetailSheet extends ConsumerWidget {
  const _PartDetailSheet({required this.row, required this.line});

  final CoverageRow row;
  final ProductionLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final status = statusFor(row.level);
    final canSeeLedger = ref.watch(canProvider(Perm.ledgerView));

    return Padding(
      padding: const EdgeInsets.fromLTRB(VSpace.xl, 0, VSpace.xl, VSpace.xl),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: PartIdentity(part: row.part)),
                VPill(label: levelLabel(row.level), status: status),
              ],
            ),
            const SizedBox(height: VSpace.lg),

            // The walk, in plain words — this is the app's whole answer.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(VSpace.md),
              decoration: BoxDecoration(
                color: row.level == null ? v.okTint : v.tintFor(status),
                borderRadius: VRadius.allSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.horizonLabel,
                    style: context.text.titleSmall?.copyWith(
                      color: row.level == null ? v.ok : v.forStatus(status),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: VSpace.xs),
                  Text(
                    'With ${fmtQty(row.availableStock)} pieces on hand and a QPV of ${row.qpv} '
                    'on ${line.name}, this part covers ${row.machinesCovered} more machine(s)'
                    '${row.shortfallQty > 0 ? '. ${fmtQty(row.shortfallQty)} more pieces would clear the block' : ''}.',
                    style: context.text.bodySmall?.copyWith(color: v.txt2, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: VSpace.lg),
            VSectionTitle(title: 'The numbers'),
            _DetailGrid(rows: [
              ('Opening stock (Stk 30sep)', fmtQty(row.part.openingStock)),
              ('Received today', '+${fmtQty(row.part.dailyNesting)}'),
              ('Taken by SPD', '−${fmtQty(row.part.takenBySpd)}'),
              ('Available now', fmtQty(row.availableStock)),
              ('QPV (per machine)', '${row.qpv}'),
              ('Machines covered', '${row.machinesCovered}'),
              ('Safe up to', row.safeUntilSerial ?? '—'),
              ('Runs out at', row.firstBlockedSerial ?? 'not within the plan'),
              if (row.part.rackCode != null) ('Rack', row.part.rackCode!),
              if (row.part.station != null) ('Station', row.part.station!),
              ('Type', row.part.partType.label),
              if (row.part.paintFormat != null) ('Paint format', row.part.paintFormat!),
            ]),

            const SizedBox(height: VSpace.lg),
            Wrap(
              spacing: VSpace.sm,
              runSpacing: VSpace.sm,
              children: [
                if (row.firstBlockedSerial != null)
                  VButton(
                    label: 'Check machine ${row.firstBlockedSerial}',
                    icon: Icons.fact_check_rounded,
                    size: VButtonSize.small,
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('${Routes.canBuild}?serial=${row.firstBlockedSerial}');
                    },
                  ),
                if (canSeeLedger)
                  VButton.ghost(
                    label: 'Stock history',
                    icon: Icons.history_rounded,
                    size: VButtonSize.small,
                    onPressed: () {
                      Navigator.pop(context);
                      _showLedger(context, ref, row.part);
                    },
                  ),
                VButton.ghost(
                  label: 'Find in lookup',
                  icon: Icons.search_rounded,
                  size: VButtonSize.small,
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('${Routes.lookup}?q=${row.part.unpaintedPn}');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLedger(BuildContext context, WidgetRef ref, Part part) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.v.bg2,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => PartLedgerSheet(part: part),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Container(
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: VRadius.allSm,
        border: Border.all(color: v.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: VSpace.md, vertical: VSpace.sm),
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: v.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].$1,
                      style: context.text.bodySmall?.copyWith(color: v.txt3),
                    ),
                  ),
                  Text(
                    rows[i].$2,
                    style: context.text.labelMedium?.copyWith(
                      color: v.txt,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Prove this number" — the append-only ledger behind a part's stock.
///
/// The SRS's complaint about Excel was "nobody knows who entered or changed a
/// number". This sheet is the answer, and it is why the backend refuses to let
/// the ledger be edited.
class PartLedgerSheet extends ConsumerWidget {
  const PartLedgerSheet({super.key, required this.part});

  final Part part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final future = ref.watch(_ledgerProvider(part.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(VSpace.xl, 0, VSpace.xl, VSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PartIdentity(part: part),
          const SizedBox(height: VSpace.md),
          Text(
            'Every movement, with who entered it and when. Nothing here can be edited or '
            'deleted — corrections are new rows, which is what makes the number provable.',
            style: context.text.bodySmall?.copyWith(color: v.txt3, height: 1.5),
          ),
          const SizedBox(height: VSpace.lg),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
            child: future.when(
              loading: () => const VSkeletonList(rows: 4, height: 58),
              error: (error, _) => VErrorState(
                message: describeError(error),
                compact: true,
                onRetry: () => ref.invalidate(_ledgerProvider(part.id)),
              ),
              data: (data) {
                if (data.entries.isEmpty) {
                  return const VEmptyState(
                    title: 'No movements yet',
                    message: 'This part is still at its opening stock.',
                    icon: Icons.history_rounded,
                    compact: true,
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(VSpace.md),
                      decoration: BoxDecoration(
                        color: v.surface2,
                        borderRadius: VRadius.allSm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _LedgerTotal(
                              label: 'Opening',
                              value: fmtQty(data.openingStock),
                            ),
                          ),
                          Expanded(
                            child: _LedgerTotal(
                              label: 'Movements',
                              value: '${data.total}',
                            ),
                          ),
                          Expanded(
                            child: _LedgerTotal(
                              label: 'Available now',
                              value: fmtQty(data.availableStock),
                              emphasise: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: VSpace.sm),
                    Expanded(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: data.entries.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: v.line),
                        itemBuilder: (context, index) =>
                            _LedgerRow(entry: data.entries[index]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final _ledgerProvider = FutureProvider.autoDispose.family<
    ({List<LedgerEntry> entries, double openingStock, double availableStock, int total}),
    String>((ref, partId) {
  return ref.watch(masterRepositoryProvider).ledger(partId, limit: 200);
});

class _LedgerTotal extends StatelessWidget {
  const _LedgerTotal({required this.label, required this.value, this.emphasise = false});

  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9),
        ),
        Text(
          value,
          style: (emphasise ? context.text.titleMedium : context.text.titleSmall)?.copyWith(
            color: v.txt,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final positive = entry.isReceipt;
    final color = positive ? v.ok : v.bad;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VSpace.sm),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: positive ? v.okTint : v.badTint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              positive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              size: 15,
              color: color,
            ),
          ),
          const SizedBox(width: VSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.reason.label, style: context.text.titleSmall?.copyWith(fontSize: 13)),
                Text(
                  '${fmtDateTime(entry.createdAt)}'
                  '${entry.createdByName != null ? ' · ${entry.createdByName}' : ''}',
                  style: context.text.bodySmall?.copyWith(color: v.txt3, fontSize: 11),
                ),
                if (entry.note != null)
                  Text(
                    entry.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(color: v.txt3, fontSize: 11),
                  ),
              ],
            ),
          ),
          const SizedBox(width: VSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${positive ? '+' : ''}${fmtQty(entry.qtyDelta)}',
                style: context.text.titleSmall?.copyWith(
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (entry.balanceAfter != null)
                Text(
                  '→ ${fmtQty(entry.balanceAfter!)}',
                  style: context.text.labelSmall?.copyWith(
                    color: v.txt3,
                    fontSize: 10,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
