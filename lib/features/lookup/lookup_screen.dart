import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../../router/app_router.dart';
import '../common/common_widgets.dart';

/// ---------------------------------------------------------------------------
/// Part / Rack Lookup — "where is this part kept, and how many are there?"
///
/// The SRS names this question directly, and it is asked from the floor with one
/// hand free. So: one field, results as you type, and the rack code as the
/// biggest thing on the row. Everything else (stock, patterns, QPV per line) is
/// there, but subordinate to *where do I walk*.
///
/// The rack tab exists for the opposite direction — someone standing at rack B-12
/// wanting to know what should be in it.
/// ---------------------------------------------------------------------------

enum _LookupMode { parts, racks }

/// The live query. Kept in a provider rather than widget state so a deep link
/// (`/lookup?q=…` from a coverage row or an alert) and the field stay in step.
final _queryProvider = StateProvider.autoDispose<String>((ref) => '');

final _partSearchProvider = FutureProvider.autoDispose<List<Part>>((ref) async {
  final query = ref.watch(_queryProvider).trim();
  if (query.length < 2) return const [];
  return ref.watch(masterRepositoryProvider).searchParts(query, limit: 40);
});

final _rackPartsProvider =
    FutureProvider.autoDispose.family<({Rack rack, List<Part> parts}), String>((ref, rackId) {
  return ref.watch(masterRepositoryProvider).rackParts(rackId);
});

class LookupScreen extends ConsumerStatefulWidget {
  const LookupScreen({super.key});

  @override
  ConsumerState<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends ConsumerState<LookupScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  _LookupMode _mode = _LookupMode.parts;

  /// The `?q=` we have already consumed, so a rebuild does not overwrite what
  /// the user has typed since arriving.
  String? _deepLinked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final fromRoute = GoRouterState.of(context).uri.queryParameters['q']?.trim();
    if (fromRoute == null || fromRoute.isEmpty || fromRoute == _deepLinked) return;

    _deepLinked = fromRoute;
    _controller.value = TextEditingValue(
      text: fromRoute,
      selection: TextSelection.collapsed(offset: fromRoute.length),
    );
    // The provider is read during build; setting it here would mutate state
    // mid-build, so it is deferred by one microtask.
    Future.microtask(() {
      if (mounted) ref.read(_queryProvider.notifier).state = fromRoute;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 280ms: long enough that a full part number is one request rather than
  /// fourteen, short enough that the list feels live.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) ref.read(_queryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return VPageBody(
      children: [
        VPageHeader(
          breadcrumb: const ['Shortage', 'Part / Rack Lookup'],
          title: 'Find a part',
          accentWord: 'part',
          description: 'Search by part number, description, painted number or rack. '
              'The rack code is what gets you there; the stock figure is what the '
              'ledger says is on it right now.',
        ),

        VSegmented<_LookupMode>(
          value: _mode,
          onChanged: (next) => setState(() => _mode = next),
          segments: const [
            (value: _LookupMode.parts, label: 'By part', icon: Icons.inventory_2_rounded),
            (value: _LookupMode.racks, label: 'By rack', icon: Icons.shelves),
          ],
        ),
        const SizedBox(height: VSpace.md),

        if (_mode == _LookupMode.parts) ...[
          VSearchField(
            controller: _controller,
            hint: 'Part number, description or painted number',
            large: true,
            autofocus: _deepLinked == null,
            onChanged: _onChanged,
          ),
          const SizedBox(height: VSpace.lg),
          const _PartResults(),
        ] else
          const _RackBrowser(),
      ],
    );
  }
}

class _PartResults extends ConsumerWidget {
  const _PartResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_queryProvider).trim();
    final results = ref.watch(_partSearchProvider);

    if (query.length < 2) {
      return const VEmptyState(
        title: 'Type at least two characters',
        message: 'Part number, description, painted number — whatever you have. '
            'Results appear as you type.',
        icon: Icons.search_rounded,
        compact: true,
      );
    }

    return results.when(
      loading: () => const VSkeletonList(rows: 4, height: 84),
      error: (error, _) => VErrorState(
        message: describeError(error),
        onRetry: () => ref.invalidate(_partSearchProvider),
      ),
      data: (parts) {
        if (parts.isEmpty) {
          return VEmptyState(
            title: 'Nothing matches “$query”',
            message: 'Check the number, or search by description instead. '
                'A part that has never been imported will not be here.',
            icon: Icons.search_off_rounded,
            compact: true,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final part in parts)
              Padding(
                padding: const EdgeInsets.only(bottom: VSpace.sm),
                child: _PartResultCard(part: part),
              ),
          ],
        );
      },
    );
  }
}

class _PartResultCard extends ConsumerWidget {
  const _PartResultCard({required this.part});

  final Part part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;

    return VCard(
      glow: true,
      onTap: () => showPartSheet(context, part),
      padding: const EdgeInsets.all(VSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rack first, and biggest — this is the answer to the question people
          // actually walked over to ask.
          _RackBadge(code: part.rackCode, zone: part.rackZone),
          const SizedBox(width: VSpace.md),
          Expanded(child: PartIdentity(part: part)),
          const SizedBox(width: VSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fmtQty(part.availableStock),
                style: context.text.titleMedium?.copyWith(
                  color: part.availableStock <= 0 ? v.bad : v.txt,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'in stock',
                style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RackBadge extends StatelessWidget {
  const _RackBadge({this.code, this.zone});

  final String? code;
  final String? zone;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final known = code != null && code!.isNotEmpty;

    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(vertical: VSpace.xs, horizontal: 4),
      decoration: BoxDecoration(
        color: known ? v.accentTint : v.surface2,
        borderRadius: VRadius.allSm,
        border: Border.all(color: known ? Colors.transparent : v.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shelves, size: 15, color: known ? v.accent : v.txt3),
          const SizedBox(height: 2),
          Text(
            known ? code! : 'No rack',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              color: known ? v.accent : v.txt3,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          if (zone != null && zone!.isNotEmpty)
            Text(
              zone!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9.5),
            ),
        ],
      ),
    );
  }
}

class _RackBrowser extends ConsumerWidget {
  const _RackBrowser();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final racks = ref.watch(racksProvider);

    return racks.when(
      loading: () => const VSkeletonList(rows: 5, height: 58),
      error: (error, _) => VErrorState(
        message: describeError(error),
        onRetry: () => ref.invalidate(racksProvider),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const VEmptyState(
            title: 'No racks set up yet',
            message: 'An admin can import the rack master, or add racks one at a time '
                'from Admin & Setup.',
            icon: Icons.shelves,
            compact: true,
          );
        }
        return VCardGrid(
          minTileWidth: 190,
          children: [
            for (final rack in rows)
              VCard(
                glow: true,
                onTap: () => _openRack(context, rack),
                padding: const EdgeInsets.all(VSpace.md),
                child: Row(
                  children: [
                    Icon(Icons.shelves, size: 18, color: context.v.accent),
                    const SizedBox(width: VSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rack.code,
                            style: context.text.titleSmall?.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (rack.zone != null || rack.description != null)
                            Text(
                              rack.zone ?? rack.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall
                                  ?.copyWith(color: context.v.txt3, fontSize: 11.5),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  void _openRack(BuildContext context, Rack rack) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.v.bg2,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => _RackSheet(rack: rack),
    );
  }
}

class _RackSheet extends ConsumerWidget {
  const _RackSheet({required this.rack});

  final Rack rack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_rackPartsProvider(rack.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(VSpace.xl, 0, VSpace.xl, VSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          VSectionTitle(
            title: 'Rack ${rack.code}',
            subtitle: rack.description ?? rack.zone,
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
            child: async.when(
              loading: () => const VSkeletonList(rows: 4, height: 58),
              error: (error, _) => VErrorState(
                message: describeError(error),
                compact: true,
                onRetry: () => ref.invalidate(_rackPartsProvider(rack.id)),
              ),
              data: (data) {
                if (data.parts.isEmpty) {
                  return const VEmptyState(
                    title: 'Nothing assigned to this rack',
                    message: 'Parts get their rack from the part master.',
                    icon: Icons.shelves,
                    compact: true,
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: data.parts.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: context.v.line),
                  itemBuilder: (context, index) {
                    final part = data.parts[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: VSpace.sm),
                      child: Row(
                        children: [
                          Expanded(child: PartIdentity(part: part, dense: true, showRack: false)),
                          Text(
                            fmtQty(part.availableStock),
                            style: context.text.titleSmall?.copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The part drill-in used by the lookup list.
///
/// Public because the nesting and runs screens open the same sheet — the "what
/// is this part, where is it, what needs it" answer should not be three
/// different layouts depending on which screen asked.
void showPartSheet(BuildContext context, Part part) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.v.bg2,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheetContext) => PartLookupSheet(part: part),
  );
}

class PartLookupSheet extends ConsumerWidget {
  const PartLookupSheet({super.key, required this.part});

  final Part part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;

    return Padding(
      padding: const EdgeInsets.fromLTRB(VSpace.xl, 0, VSpace.xl, VSpace.xl),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            PartIdentity(part: part),
            const SizedBox(height: VSpace.lg),

            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Where',
                    value: part.rackCode ?? 'No rack',
                    icon: Icons.shelves,
                    emphasise: true,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'In stock',
                    value: fmtQty(part.availableStock),
                    icon: Icons.inventory_2_rounded,
                    color: part.availableStock <= 0 ? v.bad : null,
                    emphasise: true,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Today in',
                    value: '+${fmtQty(part.dailyNesting)}',
                    icon: Icons.move_to_inbox_rounded,
                    color: part.dailyNesting > 0 ? v.ok : null,
                  ),
                ),
              ],
            ),

            if (part.lines.isNotEmpty) ...[
              const SizedBox(height: VSpace.lg),
              const VSectionTitle(
                title: 'Used by',
                subtitle: 'Quantity per vehicle, by line and variant.',
              ),
              Wrap(
                spacing: VSpace.sm,
                runSpacing: VSpace.sm,
                children: [
                  for (final line in part.lines)
                    VPill(
                      label: line.variantCode == null || line.variantCode!.isEmpty
                          ? '${line.lineCode} · ${line.qpv}/machine'
                          : '${line.lineCode} ${line.variantCode} · ${line.qpv}/machine',
                      status: VStatus.info,
                      showDot: false,
                    ),
                ],
              ),
            ],

            if (part.patterns.isNotEmpty) ...[
              const SizedBox(height: VSpace.lg),
              const VSectionTitle(
                title: 'Comes off these patterns',
                subtitle: 'Pieces produced per frame.',
              ),
              Wrap(
                spacing: VSpace.sm,
                runSpacing: VSpace.sm,
                children: [
                  for (final pattern in part.patterns)
                    VPill(
                      label: '${pattern.code} · ${pattern.qtyPerFrame}/frame',
                      status: VStatus.neutral,
                      showDot: false,
                      icon: Icons.view_module_rounded,
                    ),
                ],
              ),
            ],

            const SizedBox(height: VSpace.lg),
            Wrap(
              spacing: VSpace.sm,
              runSpacing: VSpace.sm,
              children: [
                VButton.ghost(
                  label: 'Part coverage',
                  icon: Icons.query_stats_rounded,
                  size: VButtonSize.small,
                  onPressed: () {
                    Navigator.pop(context);
                    goToCoverageFiltered(context, ref);
                  },
                ),
                VButton.quiet(
                  label: 'Shortage matrix',
                  icon: Icons.grid_on_rounded,
                  onPressed: () {
                    Navigator.pop(context);
                    context.go(Routes.matrix);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: v.txt3),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (emphasise ? context.text.titleMedium : context.text.titleSmall)?.copyWith(
            color: color ?? v.txt,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
