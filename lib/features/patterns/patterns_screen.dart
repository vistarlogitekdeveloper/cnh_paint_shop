import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../common/common_widgets.dart';

/// ---------------------------------------------------------------------------
/// Patterns — the nesting recipes: which parts hang on a frame, and how many of
/// each comes off it.
///
/// The one rule this screen exists to make visible: a SPECIAL pattern cannot be
/// loaded until the Planner approves it. The server refuses either way, but an
/// operator who discovers that at the moment of saving has already hung the
/// frame. So an unapproved pattern is marked as such everywhere it appears, and
/// the approval action sits right next to the warning.
/// ---------------------------------------------------------------------------

/// The list filter. Local to this screen — `providers.dart` deliberately owns
/// only the fetch, so a filter added here cannot collide with one there.
final _patternFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');

class PatternsScreen extends ConsumerWidget {
  const PatternsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(patternsProvider);
    final filter = ref.watch(_patternFilterProvider);

    return LineRequired(
      builder: (context, line) => AsyncBody<List<Pattern>>(
        value: async,
        onRefresh: () async => ref.invalidate(patternsProvider),
        isEmpty: (rows) => rows.isEmpty,
        emptyTitle: 'No patterns for ${line.code} yet',
        emptyMessage: 'Patterns come from the nesting pattern master. An admin can import '
            'them from Admin & Setup.',
        builder: (context, all) {
          final rows = switch (filter) {
            'special' => all.where((p) => p.isSpecial).toList(),
            'awaiting' => all.where((p) => p.awaitingApproval).toList(),
            _ => all,
          };
          final awaiting = all.where((p) => p.awaitingApproval).length;

          return VPageBody(
            children: [
              VPageHeader(
                breadcrumb: const ['Shop floor', 'Patterns'],
                title: 'Nesting patterns',
                accentWord: 'patterns',
                description: '${line.name} · ${all.length} patterns. Open one to see the '
                    'parts on the frame and how many pieces each run produces.',
                actions: [
                  VButton.ghost(
                    label: 'Refresh',
                    icon: Icons.refresh_rounded,
                    size: VButtonSize.small,
                    onPressed: () => ref.invalidate(patternsProvider),
                  ),
                ],
              ),

              if (awaiting > 0) ...[
                _AwaitingBanner(count: awaiting),
                const SizedBox(height: VSpace.md),
              ],

              VSegmented<String>(
                value: filter,
                onChanged: (next) => ref.read(_patternFilterProvider.notifier).state = next,
                segments: const [
                  (value: 'all', label: 'All', icon: null),
                  (value: 'special', label: 'Special', icon: Icons.star_rounded),
                  (value: 'awaiting', label: 'Awaiting approval', icon: Icons.pending_rounded),
                ],
              ),
              const SizedBox(height: VSpace.md),

              if (rows.isEmpty)
                const VEmptyState(
                  title: 'Nothing at this filter',
                  message: 'Switch back to All to see every pattern on this line.',
                  icon: Icons.filter_alt_off_rounded,
                  compact: true,
                )
              else
                VCardGrid(
                  minTileWidth: 280,
                  children: [
                    for (final pattern in rows) _PatternCard(pattern: pattern),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AwaitingBanner extends StatelessWidget {
  const _AwaitingBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Container(
      padding: const EdgeInsets.all(VSpace.md),
      decoration: BoxDecoration(
        color: v.warnTint,
        borderRadius: VRadius.allSm,
        border: Border.all(color: v.warn.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.pending_rounded, size: 17, color: v.warn),
          const SizedBox(width: VSpace.sm),
          Expanded(
            child: Text(
              '$count special ${count == 1 ? 'pattern is' : 'patterns are'} waiting for the '
              "Planner. Until then they cannot be loaded, and an operator's entry against "
              'them will be refused.',
              style: context.text.bodySmall?.copyWith(
                color: v.warn,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternCard extends ConsumerWidget {
  const _PatternCard({required this.pattern});

  final Pattern pattern;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final blocked = pattern.awaitingApproval;

    return VCard(
      glow: true,
      onTap: () => _open(context, ref),
      accentEdge: blocked ? v.warn : null,
      padding: const EdgeInsets.fromLTRB(VSpace.lg, VSpace.md, VSpace.md, VSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pattern.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(
                        fontSize: 14,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (pattern.name != null)
                      Text(
                        pattern.name!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: v.txt2, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: VSpace.xs),
              if (blocked)
                const VPill(label: 'Awaiting approval', status: VStatus.warning, compact: true)
              else if (pattern.isSpecial)
                const VPill(
                  label: 'Special',
                  status: VStatus.info,
                  compact: true,
                  icon: Icons.star_rounded,
                )
              else if (!pattern.isActive)
                const VPill(label: 'Inactive', status: VStatus.neutral, compact: true)
              else
                const VPill(label: 'Loadable', status: VStatus.ready, compact: true),
            ],
          ),
          const SizedBox(height: VSpace.sm),
          Wrap(
            spacing: VSpace.md,
            runSpacing: 2,
            children: [
              if (pattern.shade != null)
                _Meta(icon: Icons.palette_rounded, text: pattern.shade!),
              if (pattern.plannedSurface != null)
                _Meta(icon: Icons.square_foot_rounded, text: '${fmtQty(pattern.plannedSurface!)} m²'),
              if (pattern.items.isNotEmpty)
                _Meta(icon: Icons.widgets_rounded, text: '${pattern.items.length} parts'),
            ],
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.v.bg2,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (sheetContext) => _PatternSheet(pattern: pattern),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: v.txt3),
        const SizedBox(width: 4),
        Text(text, style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 11)),
      ],
    );
  }
}

class _PatternSheet extends ConsumerStatefulWidget {
  const _PatternSheet({required this.pattern});

  final Pattern pattern;

  @override
  ConsumerState<_PatternSheet> createState() => _PatternSheetState();
}

class _PatternSheetState extends ConsumerState<_PatternSheet> {
  bool _approving = false;

  Future<void> _approve() async {
    setState(() => _approving = true);
    try {
      await ref.read(masterRepositoryProvider).approvePattern(widget.pattern.id);
      if (!mounted) return;
      VToast.success(
        context,
        'Pattern approved',
        detail: 'Operators can load ${widget.pattern.code} from now on.',
      );
      ref.invalidate(patternsProvider);
      ref.invalidate(patternDetailProvider(widget.pattern.id));
    } catch (error) {
      if (!mounted) return;
      VToast.error(context, describeError(error));
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final pattern = widget.pattern;
    final async = ref.watch(patternDetailProvider(pattern.id));
    final canApprove = ref.watch(canProvider(Perm.patternManage));

    return Padding(
      padding: const EdgeInsets.fromLTRB(VSpace.xl, 0, VSpace.xl, VSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          VSectionTitle(
            title: pattern.code,
            subtitle: pattern.name ?? pattern.lineCode,
          ),

          if (pattern.awaitingApproval) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(VSpace.md),
              decoration: BoxDecoration(color: v.warnTint, borderRadius: VRadius.allSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This special pattern is not approved',
                    style: context.text.titleSmall?.copyWith(color: v.warn, fontSize: 13.5),
                  ),
                  const SizedBox(height: VSpace.xs),
                  Text(
                    'Loading it will be refused until the Planner signs it off. That refusal '
                    'happens on the server, so it holds offline too — a queued entry against '
                    'an unapproved pattern will come back as a conflict.',
                    style: context.text.bodySmall?.copyWith(color: v.txt2, height: 1.5),
                  ),
                  if (canApprove) ...[
                    const SizedBox(height: VSpace.md),
                    VButton(
                      label: 'Approve this pattern',
                      icon: Icons.verified_rounded,
                      size: VButtonSize.small,
                      loading: _approving,
                      onPressed: _approving ? null : _approve,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: VSpace.lg),
          ],

          const VSectionTitle(
            title: 'On the frame',
            subtitle: 'Pieces produced per frame, and what is on the shelf now.',
          ),

          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
            child: async.when(
              loading: () => const VSkeletonList(rows: 4, height: 58),
              error: (error, _) => VErrorState(
                message: describeError(error),
                compact: true,
                onRetry: () => ref.invalidate(patternDetailProvider(pattern.id)),
              ),
              data: (detail) {
                if (detail.items.isEmpty) {
                  return const VEmptyState(
                    title: 'No parts on this pattern',
                    message: 'The pattern master has no lines for it yet, so a run would '
                        'produce nothing.',
                    icon: Icons.widgets_rounded,
                    compact: true,
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: detail.items.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: v.line),
                  itemBuilder: (context, index) => _ItemRow(item: detail.items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final PatternItem item;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final part = item.part;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VSpace.sm),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              item.seqNo == null ? '—' : '${item.seqNo}',
              style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 11),
            ),
          ),
          Expanded(
            child: part == null
                ? Text(item.partId, style: context.text.bodySmall?.copyWith(color: v.txt2))
                : PartIdentity(part: part, dense: true),
          ),
          const SizedBox(width: VSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '×${item.qtyPerFrame}',
                style: context.text.titleSmall?.copyWith(
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '${fmtQty(item.availableStock)} in stock',
                style: context.text.labelSmall?.copyWith(
                  color: item.availableStock <= 0 ? v.bad : v.txt3,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
