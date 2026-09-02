import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../common/common_widgets.dart';

/// ---------------------------------------------------------------------------
/// Machine Plan — the Planner maintains the ordered serial sequence per line,
/// marks project units (ATS44 / Indigo), and marks machines built.
///
/// The list is in PLAN ORDER (`seq_index`), not serial order. That distinction
/// is load-bearing: 'ATS44-01' sorts wrong as text but sits at a definite point
/// in the sequence, and the coverage walk follows seq_index precisely so those
/// units are consumed where they actually occur.
///
/// Marking a machine built consumes its RESOLVED BOM — override → variant →
/// line standard. The server refuses when a part is short (422 + blocking_parts)
/// unless the Planner explicitly chooses to record the shortage, because silently
/// driving stock negative is how a tracker stops being trustworthy.
/// ---------------------------------------------------------------------------
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(machinePlanProvider);
    final filter = ref.watch(planFilterProvider);
    final canManage = ref.watch(canProvider(Perm.machineManage));
    final canBuild = ref.watch(canProvider(Perm.machineBuild));

    return LineRequired(
      builder: (context, line) => AsyncBody<List<Machine>>(
        value: async,
        onRefresh: () async => ref.invalidate(machinePlanProvider),
        isEmpty: (rows) => rows.isEmpty,
        emptyTitle: filter == false ? 'No machines left to build' : 'No machine plan yet',
        emptyMessage: filter == false
            ? 'Every machine in ${line.name}\'s plan is marked built. The Planner needs to '
                'extend the sequence.'
            : 'A Planner needs to add the serial numbers for ${line.name}, in the order they '
                'will be built.',
        builder: (context, machines) => VPageBody(
          children: [
            VPageHeader(
              breadcrumb: const ['Planning', 'Machine Plan'],
              title: 'Machine Plan',
              description: '${line.name} · in plan order, which is not serial order — project '
                  'units sit inside the sequence and the coverage walk follows this exact order.',
              actions: [
                if (canManage)
                  VButton(
                    label: 'Add machines',
                    icon: Icons.playlist_add_rounded,
                    size: VButtonSize.small,
                    onPressed: () => _openAddSheet(context, ref, line),
                  ),
                VButton.ghost(
                  label: 'Refresh',
                  icon: Icons.refresh_rounded,
                  size: VButtonSize.small,
                  onPressed: () => ref.invalidate(machinePlanProvider),
                ),
              ],
            ),

            _PlanStats(machines: machines),
            const SizedBox(height: VSpace.lg),

            VSegmented<bool?>(
              value: filter,
              onChanged: (next) => ref.read(planFilterProvider.notifier).state = next,
              segments: const [
                (value: false, label: 'To build', icon: Icons.pending_actions_rounded),
                (value: true, label: 'Built', icon: Icons.check_circle_rounded),
                (value: null, label: 'All', icon: null),
              ],
            ),
            const SizedBox(height: VSpace.md),

            for (var i = 0; i < machines.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: VSpace.xs),
                child: _MachineRow(
                  machine: machines[i],
                  // The first pending machine is the one the shop is about to
                  // work on — worth calling out.
                  isNext: filter != true && i == 0 && !machines[i].isBuilt,
                  canManage: canManage,
                  canBuild: canBuild,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static void _openAddSheet(BuildContext context, WidgetRef ref, ProductionLine line) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.v.bg2,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (_) => _AddMachinesSheet(line: line),
    );
  }
}

class _PlanStats extends StatelessWidget {
  const _PlanStats({required this.machines});

  final List<Machine> machines;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final built = machines.where((m) => m.isBuilt).length;
    final pending = machines.length - built;
    final special = machines.where((m) => m.isSpecial).length;
    final next = machines.firstWhere(
      (m) => !m.isBuilt,
      orElse: () => machines.isEmpty
          ? const Machine(id: '', lineId: '', serialNo: '—', seqIndex: 0)
          : machines.last,
    );

    return VCardGrid(
      minTileWidth: 190,
      children: [
        VKpiCard(
          label: 'Next to build',
          value: next.isBuilt ? '—' : next.serialNo,
          gradientValue: !next.isBuilt && next.serialNo != '—',
          icon: Icons.play_arrow_rounded,
          caption: next.badge ?? 'Line standard BOM',
        ),
        VKpiCard(
          label: 'To build',
          value: '$pending',
          icon: Icons.pending_actions_rounded,
          iconColor: v.warn,
          iconBackground: v.warnTint,
        ),
        VKpiCard(
          label: 'Built',
          value: '$built',
          icon: Icons.check_circle_rounded,
          iconColor: v.ok,
          iconBackground: v.okTint,
        ),
        VKpiCard(
          label: 'Project units',
          value: '$special',
          icon: Icons.star_rounded,
          caption: 'ATS44 / Indigo and variants',
        ),
      ],
    );
  }
}

class _MachineRow extends ConsumerStatefulWidget {
  const _MachineRow({
    required this.machine,
    required this.isNext,
    required this.canManage,
    required this.canBuild,
  });

  final Machine machine;
  final bool isNext;
  final bool canManage;
  final bool canBuild;

  @override
  ConsumerState<_MachineRow> createState() => _MachineRowState();
}

class _MachineRowState extends ConsumerState<_MachineRow> {
  bool _busy = false;

  Machine get machine => widget.machine;

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    return VCard(
      onTap: () => _openDetail(context),
      accentEdge: widget.isNext ? v.accent : (machine.isBuilt ? v.ok : null),
      padding: const EdgeInsets.fromLTRB(VSpace.lg, VSpace.sm, VSpace.sm, VSpace.sm),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '#${machine.seqIndex}',
              style: context.text.labelSmall?.copyWith(
                color: v.txt3,
                fontSize: 10,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      machine.serialNo,
                      style: context.text.titleMedium?.copyWith(
                        fontSize: 15,
                        color: machine.isBuilt ? v.txt3 : v.txt,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (widget.isNext) ...[
                      const SizedBox(width: VSpace.xs),
                      const VPill(label: 'Next', status: VStatus.info, compact: true),
                    ],
                    if (machine.badge != null) ...[
                      const SizedBox(width: VSpace.xs),
                      VPill(
                        label: machine.badge!,
                        status: machine.isSpecial ? VStatus.warning : VStatus.neutral,
                        showDot: false,
                        compact: true,
                      ),
                    ],
                    if (machine.hasOverride) ...[
                      const SizedBox(width: VSpace.xs),
                      VPill(
                        label: '${machine.overrideCount} override',
                        status: VStatus.info,
                        icon: Icons.tune_rounded,
                        compact: true,
                      ),
                    ],
                  ],
                ),
                if (machine.isBuilt)
                  Text(
                    'Built ${machine.builtAt != null ? fmtDateTime(machine.builtAt!) : ''}'
                    '${machine.builtByName != null ? ' by ${machine.builtByName}' : ''}',
                    style: context.text.bodySmall?.copyWith(color: v.txt3, fontSize: 11),
                  )
                else if (machine.plannedDate != null)
                  Text(
                    'Planned ${fmtDate(machine.plannedDate!)}',
                    style: context.text.bodySmall?.copyWith(color: v.txt3, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: VSpace.md),
              child: VSpinner(),
            )
          else if (machine.isBuilt) ...[
            Icon(Icons.check_circle_rounded, size: 19, color: v.ok),
            if (widget.canManage) ...[
              const SizedBox(width: VSpace.xs),
              VIconButton(
                icon: Icons.undo_rounded,
                size: 34,
                iconSize: 16,
                filled: false,
                tooltip: 'Un-mark built (writes reversal rows)',
                onPressed: _unmark,
              ),
            ],
          ] else if (widget.canBuild)
            VButton.ghost(
              label: 'Mark built',
              icon: Icons.build_circle_rounded,
              size: VButtonSize.small,
              onPressed: _markBuilt,
            ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.v.bg2,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 660),
      builder: (_) => _MachineDetailSheet(
        machineId: machine.id,
        canManage: widget.canManage,
      ),
    );
  }

  Future<void> _markBuilt({bool allowShortage = false}) async {
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(planRepositoryProvider)
          .markBuilt(machine.id, allowShortage: allowShortage);

      if (!mounted) return;
      VToast.success(
        context,
        'Machine ${machine.serialNo} built',
        detail: result.builtWithShortage
            ? '${result.consumedParts} part(s) consumed — the shortage has been recorded.'
            : '${result.consumedParts} part(s) consumed from the ledger.',
      );
      _invalidateAll();
    } on ApiException catch (e) {
      if (!mounted) return;

      // 422 + blocking_parts is the interesting case: the server is telling us
      // exactly which parts are short. Show them and let the Planner decide,
      // rather than a bare "could not build".
      if (e.statusCode == 422 && e.blockingParts.isNotEmpty) {
        final force = await _showBlockedDialog(e.blockingParts);
        if (force == true) {
          await _markBuilt(allowShortage: true);
          return;
        }
      } else {
        VToast.error(context, 'Could not mark built', detail: e.message);
        if (e.isConflict) ref.invalidate(machinePlanProvider);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _showBlockedDialog(List<Map<String, dynamic>> blocking) {
    final v = context.v;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Machine ${machine.serialNo} cannot be built'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${blocking.length} part(s) are short. You can still record the build — the '
                'shortage will be written to the ledger, not hidden.',
                style: context.text.bodySmall?.copyWith(color: v.txt2, height: 1.5),
              ),
              const SizedBox(height: VSpace.md),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final part in blocking)
                        Container(
                          margin: const EdgeInsets.only(bottom: VSpace.xs),
                          padding: const EdgeInsets.all(VSpace.sm),
                          decoration: BoxDecoration(
                            color: v.badTint,
                            borderRadius: VRadius.allSm,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${part['unpainted_pn'] ?? part['part']?['unpainted_pn'] ?? ''}',
                                      style: context.text.titleSmall?.copyWith(fontSize: 13),
                                    ),
                                    Text(
                                      '${part['part']?['description'] ?? ''}',
                                      style: context.text.bodySmall
                                          ?.copyWith(color: v.txt3, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'need ${part['required_qty'] ?? '?'}',
                                    style: context.text.labelSmall?.copyWith(color: v.txt2),
                                  ),
                                  Text(
                                    'have ${part['available_stock'] ?? part['available_at_machine'] ?? 0}',
                                    style: context.text.labelSmall?.copyWith(
                                      color: v.bad,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: v.warn),
            child: const Text('Build anyway, record the shortage'),
          ),
        ],
      ),
    );
  }

  Future<void> _unmark() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Un-mark machine ${machine.serialNo}?'),
        content: const Text(
          'The pieces this machine consumed will be returned to stock as reversal entries. '
          'Nothing is deleted — the original consumption stays visible in the history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Un-mark'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final restored = await ref.read(planRepositoryProvider).unmarkBuilt(machine.id);
      if (!mounted) return;
      VToast.info(
        context,
        'Machine ${machine.serialNo} un-marked',
        detail: '$restored part(s) returned to stock.',
      );
      _invalidateAll();
    } on ApiException catch (e) {
      if (!mounted) return;
      VToast.error(context, 'Could not un-mark', detail: e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Building or un-building moves the ledger, so every coverage-derived screen
  /// is stale.
  void _invalidateAll() {
    ref
      ..invalidate(machinePlanProvider)
      ..invalidate(coverageProvider)
      ..invalidate(alertsProvider)
      ..invalidate(dashboardProvider)
      ..invalidate(badgeCountsProvider);
  }
}

/// A machine's resolved BOM — what building it will actually consume.
class _MachineDetailSheet extends ConsumerWidget {
  const _MachineDetailSheet({required this.machineId, required this.canManage});

  final String machineId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final async = ref.watch(machineDetailProvider(machineId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(VSpace.xl, 0, VSpace.xl, VSpace.xl),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(VSpace.xl),
          child: VSkeletonList(rows: 4, height: 56),
        ),
        error: (error, _) => VErrorState(
          message: describeError(error),
          compact: true,
          onRetry: () => ref.invalidate(machineDetailProvider(machineId)),
        ),
        data: (detail) {
          final machine = detail.machine;
          final shortCount = detail.items.where((i) => i.short).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Machine ${machine.serialNo}', style: context.text.headlineSmall),
                        Text(
                          'Position #${machine.seqIndex} in the plan',
                          style: context.text.bodySmall?.copyWith(color: v.txt3),
                        ),
                      ],
                    ),
                  ),
                  if (machine.isBuilt)
                    const VPill(label: 'Built', status: VStatus.ready)
                  else
                    VPill(
                      label: shortCount > 0 ? '$shortCount short' : 'Ready',
                      status: shortCount > 0 ? VStatus.critical : VStatus.ready,
                    ),
                ],
              ),

              const SizedBox(height: VSpace.md),

              // WHY this unit consumes what it does. An override set is
              // EXHAUSTIVE — a part absent from it is genuinely not on the unit,
              // which is how an ATS44 consumes only its own parts and none of
              // the standard cabin BOM.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(VSpace.md),
                decoration: BoxDecoration(
                  color: v.infoTint,
                  borderRadius: VRadius.allSm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.account_tree_rounded, size: 16, color: v.info),
                    const SizedBox(width: VSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.bomSourceLabel,
                            style: context.text.titleSmall?.copyWith(color: v.info, fontSize: 13),
                          ),
                          Text(
                            switch (detail.bomSource) {
                              'machine_override' =>
                                'This unit has its own part list. Nothing outside it is consumed, '
                                    'even if the line standard includes it.',
                              'variant' =>
                                'Consumes the ${machine.variantCode} variant BOM rather than the '
                                    'line standard.',
                              _ => 'Consumes the line\'s standard BOM.',
                            },
                            style: context.text.bodySmall?.copyWith(color: v.txt2, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: VSpace.lg),
              VSectionTitle(
                title: 'Will consume',
                subtitle: '${detail.items.length} part(s)',
                trailing: canManage && !machine.isBuilt
                    ? VButton.quiet(
                        label: 'Edit overrides',
                        icon: Icons.tune_rounded,
                        size: VButtonSize.small,
                        onPressed: () {
                          Navigator.pop(context);
                          _openOverrideSheet(context, ref, detail);
                        },
                      )
                    : null,
              ),

              if (detail.items.isEmpty)
                const VEmptyState(
                  title: 'No BOM for this unit',
                  message: 'It will consume nothing. Check the line BOM or add an override.',
                  icon: Icons.inventory_2_outlined,
                  compact: true,
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final item in detail.items)
                          Container(
                            margin: const EdgeInsets.only(bottom: VSpace.xs),
                            padding: const EdgeInsets.all(VSpace.sm),
                            decoration: BoxDecoration(
                              color: item.short ? v.badTint : v.surface2,
                              borderRadius: VRadius.allSm,
                            ),
                            child: Row(
                              children: [
                                Expanded(child: PartIdentity(part: item.part, dense: true)),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'needs ${item.qty}',
                                      style: context.text.labelMedium?.copyWith(
                                        color: v.txt,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                    Text(
                                      'have ${fmtQty(item.availableStock)}',
                                      style: context.text.labelSmall?.copyWith(
                                        color: item.short ? v.bad : v.txt3,
                                        fontWeight: item.short ? FontWeight.w800 : FontWeight.w600,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static void _openOverrideSheet(BuildContext context, WidgetRef ref, MachineDetail detail) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.v.bg2,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (_) => _OverrideSheet(detail: detail),
    );
  }
}

/// Replaces a machine's override list wholesale.
class _OverrideSheet extends ConsumerStatefulWidget {
  const _OverrideSheet({required this.detail});

  final MachineDetail detail;

  @override
  ConsumerState<_OverrideSheet> createState() => _OverrideSheetState();
}

class _OverrideSheetState extends ConsumerState<_OverrideSheet> {
  late List<({Part part, int qty})> _items;
  final _searchController = TextEditingController();
  List<Part> _results = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Seed from the resolved BOM so "override" starts from what the unit
    // consumes today rather than from nothing.
    _items = widget.detail.bomSource == 'machine_override'
        ? [for (final i in widget.detail.items) (part: i.part, qty: i.qty)]
        : [];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    return Padding(
      padding: EdgeInsets.only(
        left: VSpace.xl,
        right: VSpace.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + VSpace.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Override for ${widget.detail.machine.serialNo}',
              style: context.text.headlineSmall,
            ),
            const SizedBox(height: VSpace.xs),
            Text(
              'This list becomes the unit\'s WHOLE bill of materials. A part left off it is '
              'not consumed at all, even if the line standard includes it. Save an empty list '
              'to remove the override and return the unit to its variant or line BOM.',
              style: context.text.bodySmall?.copyWith(color: v.txt3, height: 1.5),
            ),
            const SizedBox(height: VSpace.lg),

            for (var i = 0; i < _items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: VSpace.xs),
                child: VCard(
                  padding: const EdgeInsets.all(VSpace.sm),
                  child: Row(
                    children: [
                      Expanded(child: PartIdentity(part: _items[i].part, dense: true)),
                      SizedBox(
                        width: 74,
                        child: TextFormField(
                          initialValue: '${_items[i].qty}',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(isDense: true),
                          style: context.text.labelLarge,
                          onChanged: (value) {
                            final qty = int.tryParse(value) ?? 1;
                            _items[i] = (part: _items[i].part, qty: qty < 1 ? 1 : qty);
                          },
                        ),
                      ),
                      VIconButton(
                        icon: Icons.delete_outline_rounded,
                        size: 32,
                        iconSize: 16,
                        filled: false,
                        color: v.bad,
                        tooltip: 'Remove',
                        onPressed: () => setState(() => _items.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: VSpace.md),
            VSearchField(
              controller: _searchController,
              hint: 'Add a part to this unit',
              onChanged: _search,
            ),
            for (final part in _results.take(5))
              Padding(
                padding: const EdgeInsets.only(top: VSpace.xs),
                child: VCard(
                  padding: const EdgeInsets.all(VSpace.sm),
                  onTap: () => setState(() {
                    if (!_items.any((i) => i.part.id == part.id)) {
                      _items.add((part: part, qty: 1));
                    }
                    _results = const [];
                    _searchController.clear();
                  }),
                  child: PartIdentity(part: part, dense: true),
                ),
              ),

            const SizedBox(height: VSpace.xl),
            VButton(
              label: _items.isEmpty ? 'Remove the override' : 'Save ${_items.length} part(s)',
              icon: Icons.save_rounded,
              size: VButtonSize.large,
              expand: true,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: VSpace.md),
          ],
        ),
      ),
    );
  }

  Future<void> _search(String term) async {
    if (term.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    try {
      final rows = await ref.read(masterRepositoryProvider).searchParts(term, limit: 6);
      if (mounted) setState(() => _results = rows);
    } on ApiException {
      if (mounted) setState(() => _results = const []);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final count = await ref.read(planRepositoryProvider).setOverrides(
            widget.detail.machine.id,
            [for (final i in _items) {'part_id': i.part.id, 'qty': i.qty}],
          );

      if (!mounted) return;
      Navigator.pop(context);
      VToast.success(
        context,
        count == 0 ? 'Override removed' : 'Override saved',
        detail: count == 0
            ? 'The unit is back on its variant or line BOM.'
            : '$count part(s) — coverage has been recalculated.',
      );
      ref
        ..invalidate(machinePlanProvider)
        ..invalidate(machineDetailProvider(widget.detail.machine.id))
        ..invalidate(coverageProvider)
        ..invalidate(alertsProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      VToast.error(context, 'Could not save the override', detail: e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Append a run of serial numbers to the plan.
class _AddMachinesSheet extends ConsumerStatefulWidget {
  const _AddMachinesSheet({required this.line});

  final ProductionLine line;

  @override
  ConsumerState<_AddMachinesSheet> createState() => _AddMachinesSheetState();
}

class _AddMachinesSheetState extends ConsumerState<_AddMachinesSheet> {
  final _startController = TextEditingController();
  final _countController = TextEditingController(text: '50');
  final _specialController = TextEditingController();
  String _variantCode = '';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _startController.dispose();
    _countController.dispose();
    _specialController.dispose();
    super.dispose();
  }

  /// Builds the serial list. A numeric start increments; anything else gets a
  /// `-1`, `-2` suffix, which is how the plant names project units (ATS44-01).
  List<String> _serials() {
    final start = _startController.text.trim();
    final count = int.tryParse(_countController.text.trim()) ?? 0;
    if (start.isEmpty || count <= 0) return const [];

    final asNumber = int.tryParse(start);
    if (asNumber != null) {
      final width = start.length;
      return [
        for (var i = 0; i < count; i++)
          (asNumber + i).toString().padLeft(start.startsWith('0') ? width : 0, '0'),
      ];
    }
    return [
      for (var i = 0; i < count; i++)
        count == 1 ? start : '$start-${(i + 1).toString().padLeft(2, '0')}',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final variants = widget.line.variants;
    final preview = _serials();

    return Padding(
      padding: EdgeInsets.only(
        left: VSpace.xl,
        right: VSpace.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + VSpace.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add machines to ${widget.line.code}', style: context.text.headlineSmall),
            const SizedBox(height: VSpace.xs),
            Text(
              'They are appended in this order, and that order IS the plan order the coverage '
              'walk follows. Serials already in the plan are skipped.',
              style: context.text.bodySmall?.copyWith(color: v.txt3, height: 1.5),
            ),
            const SizedBox(height: VSpace.lg),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: VInput(
                    controller: _startController,
                    label: 'First serial',
                    hint: 'e.g. 693 or ATS44',
                    large: true,
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
                const SizedBox(width: VSpace.md),
                Expanded(
                  flex: 2,
                  child: VInput(
                    controller: _countController,
                    label: 'How many',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    large: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),

            if (variants.isNotEmpty) ...[
              const SizedBox(height: VSpace.md),
              VDropdown<String>(
                label: 'Variant BOM',
                hint: 'Line standard',
                items: ['', ...variants.map((x) => x.code)],
                value: _variantCode,
                itemLabel: (code) => code.isEmpty
                    ? 'Line standard BOM'
                    : variants.firstWhere((x) => x.code == code).name,
                onChanged: (next) => setState(() => _variantCode = next ?? ''),
              ),
            ],

            const SizedBox(height: VSpace.md),
            VInput(
              controller: _specialController,
              label: 'Project label (optional)',
              hint: 'e.g. ATS44 — marks these as project units',
              helper: 'Leave blank for ordinary machines.',
            ),

            if (preview.isNotEmpty) ...[
              const SizedBox(height: VSpace.lg),
              Container(
                padding: const EdgeInsets.all(VSpace.md),
                decoration: BoxDecoration(
                  color: v.surface2,
                  borderRadius: VRadius.allSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WILL ADD ${preview.length}',
                      style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9.5),
                    ),
                    const SizedBox(height: VSpace.xs),
                    Text(
                      preview.length <= 6
                          ? preview.join(', ')
                          : '${preview.take(3).join(', ')} … ${preview.last}',
                      style: context.text.labelMedium?.copyWith(
                        color: v.txt,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: VSpace.md),
              Text(
                _error!,
                style: context.text.bodySmall?.copyWith(color: v.bad, fontWeight: FontWeight.w600),
              ),
            ],

            const SizedBox(height: VSpace.xl),
            VButton(
              label: 'Add to the plan',
              icon: Icons.playlist_add_rounded,
              size: VButtonSize.large,
              expand: true,
              loading: _saving,
              onPressed: _saving || preview.isEmpty ? null : _save,
            ),
            const SizedBox(height: VSpace.md),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final serials = _serials();
    if (serials.isEmpty) {
      setState(() => _error = 'Enter a first serial and how many to add.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final special = _specialController.text.trim();
      final result = await ref.read(planRepositoryProvider).bulkMachines(
            lineId: widget.line.id,
            machines: [
              for (final serial in serials)
                {
                  'serial_no': serial,
                  'variant_code': _variantCode,
                  'is_special': special.isNotEmpty,
                  if (special.isNotEmpty) 'special_label': special,
                },
            ],
          );

      if (!mounted) return;
      Navigator.pop(context);
      VToast.success(
        context,
        '${result.inserted} machine(s) added',
        detail: result.skipped.isEmpty
            ? null
            : '${result.skipped.length} already in the plan and skipped.',
      );
      ref.invalidate(machinePlanProvider);
      ref.invalidate(coverageProvider);
      ref.invalidate(dashboardProvider);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
