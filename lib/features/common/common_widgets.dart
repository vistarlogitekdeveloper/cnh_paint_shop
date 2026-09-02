import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../../router/app_router.dart';

/// Widgets shared across screens. Kept here rather than in `design/` because they
/// know about this app's DOMAIN (parts, coverage, alerts), which the design
/// system deliberately does not.

/// Maps a domain alert level onto the design system's status vocabulary, so
/// 🟢/🟡/🔴 is decided in exactly one place.
VStatus statusFor(AlertLevel? level) => switch (level) {
      AlertLevel.red => VStatus.critical,
      AlertLevel.yellow => VStatus.warning,
      null => VStatus.ready,
    };

String levelLabel(AlertLevel? level) => switch (level) {
      AlertLevel.red => 'Critical',
      AlertLevel.yellow => 'Warning',
      null => 'Ready',
    };

/// Number formatting. Quantities are pieces, so trailing `.0` is noise; a stock
/// count correction can legitimately carry decimals, so they are kept when real.
String fmtQty(num value) {
  if (value == value.roundToDouble()) return NumberFormat.decimalPattern().format(value.round());
  return NumberFormat('#,##0.###').format(value);
}

String fmtDateTime(DateTime dt) => DateFormat('dd-MM-yyyy HH:mm').format(dt);
String fmtDate(DateTime dt) => DateFormat('dd MMM yyyy').format(dt);
String fmtTime(DateTime dt) => DateFormat('HH:mm').format(dt);

/// "2 minutes ago" — used on alert and register rows where the exact second does
/// not matter but the recency does.
String fmtRelative(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return fmtDate(dt);
}

/// Guards a screen that cannot render without a production line.
///
/// Every coverage-derived screen needs one, and a bare "something went wrong"
/// would be a poor answer when the real problem is that no line is selected.
class LineRequired extends ConsumerWidget {
  const LineRequired({super.key, required this.builder});

  final Widget Function(BuildContext context, ProductionLine line) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linesAsync = ref.watch(linesProvider);

    return linesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(VSpace.xl),
        child: VSkeletonList(rows: 5),
      ),
      error: (error, _) => VErrorState(
        message: error is Exception ? error.toString() : 'Could not load the production lines.',
        onRetry: () => ref.invalidate(linesProvider),
      ),
      data: (lines) {
        if (lines.isEmpty) {
          return const VBrandedEmptyState(
            title: 'No production lines yet',
            message: 'An admin needs to set up at least one line (ID-10 Cabin, TR, SCH…) '
                'before coverage can be calculated.',
          );
        }
        final line = ref.watch(selectedLineProvider) ?? lines.first;
        return builder(context, line);
      },
    );
  }
}

/// A part identity block: number, description, and the metadata that helps
/// someone FIND it — rack first, because "where is this part kept?" is the
/// question the SRS calls out by name.
class PartIdentity extends StatelessWidget {
  const PartIdentity({
    super.key,
    required this.part,
    this.dense = false,
    this.showRack = true,
    this.showPainted = true,
  });

  final Part part;
  final bool dense;
  final bool showRack;
  final bool showPainted;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                part.unpaintedPn,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall?.copyWith(
                  fontSize: dense ? 13 : 14,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (part.isBulky) ...[
              const SizedBox(width: VSpace.xs),
              const VPill(label: 'Bulky', status: VStatus.info, showDot: false, compact: true),
            ],
          ],
        ),
        const SizedBox(height: 1),
        Text(
          part.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall?.copyWith(
            color: v.txt2,
            fontSize: dense ? 11.5 : 12.5,
          ),
        ),
        if (!dense) ...[
          const SizedBox(height: VSpace.xxs),
          Wrap(
            spacing: VSpace.sm,
            runSpacing: 2,
            children: [
              if (showRack && part.rackCode != null)
                _MetaBit(icon: Icons.shelves, text: part.rackCode!),
              if (showPainted && part.paintedPn != null)
                _MetaBit(icon: Icons.format_paint_rounded, text: part.paintedPn!),
              if (part.colorShade != null)
                _MetaBit(icon: Icons.palette_rounded, text: part.colorShade!),
              if (part.station != null)
                _MetaBit(icon: Icons.precision_manufacturing_rounded, text: part.station!),
            ],
          ),
        ],
      ],
    );
  }
}

class _MetaBit extends StatelessWidget {
  const _MetaBit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: v.txt3),
        const SizedBox(width: 3),
        Text(text, style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 10.5, letterSpacing: 0.2)),
      ],
    );
  }
}

/// A coverage row as a card: part identity, the status pill, the horizon
/// sentence, and the numbers that let someone act.
class CoverageRowCard extends StatelessWidget {
  const CoverageRowCard({super.key, required this.row, this.onTap, this.onCheckMachine});

  final CoverageRow row;
  final VoidCallback? onTap;
  final void Function(String serialNo)? onCheckMachine;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final status = statusFor(row.level);
    final accent = v.forStatus(status);

    return VCard(
      onTap: onTap,
      glow: onTap != null,
      accentEdge: row.level == null ? null : accent,
      padding: const EdgeInsets.fromLTRB(VSpace.lg, VSpace.md, VSpace.md, VSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: PartIdentity(part: row.part)),
              const SizedBox(width: VSpace.sm),
              VPill(label: levelLabel(row.level), status: status),
            ],
          ),
          const SizedBox(height: VSpace.md),

          // The horizon sentence — the whole point of the app, in words.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: VSpace.sm, vertical: VSpace.xs),
            decoration: BoxDecoration(
              color: row.level == null ? v.surface2 : v.tintFor(status),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  row.firstBlockedSerial == null
                      ? Icons.check_circle_outline_rounded
                      : Icons.report_problem_rounded,
                  size: 14,
                  color: row.level == null ? v.txt3 : accent,
                ),
                const SizedBox(width: VSpace.xs),
                Expanded(
                  child: Text(
                    row.horizonLabel,
                    style: context.text.bodySmall?.copyWith(
                      color: row.level == null ? v.txt2 : accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (row.firstBlockedSerial != null && onCheckMachine != null)
                  VButton.quiet(
                    label: 'Check',
                    size: VButtonSize.small,
                    onPressed: () => onCheckMachine!(row.firstBlockedSerial!),
                  ),
              ],
            ),
          ),

          const SizedBox(height: VSpace.md),
          Row(
            children: [
              _Metric(label: 'In stock', value: fmtQty(row.availableStock), emphasise: true),
              _Metric(label: 'QPV', value: '${row.qpv}'),
              _Metric(label: 'Covers', value: '${row.machinesCovered}', suffix: 'machines'),
              if (row.shortfallQty > 0)
                _Metric(
                  label: 'Short by',
                  value: fmtQty(row.shortfallQty),
                  color: v.bad,
                ),
              if (row.part.dailyNesting > 0)
                _Metric(
                  label: 'Today in',
                  value: '+${fmtQty(row.part.dailyNesting)}',
                  color: v.ok,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.suffix,
    this.color,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final String? suffix;
  final Color? color;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Padding(
      padding: const EdgeInsets.only(right: VSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9),
          ),
          const SizedBox(height: 1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: (emphasise ? context.text.titleMedium : context.text.titleSmall)?.copyWith(
                  color: color ?? v.txt,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 3),
                Text(suffix!, style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 10)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A refreshable async body: skeleton while loading, error state with retry,
/// pull-to-refresh on the data.
///
/// Every list screen wants exactly this, and hand-rolling it per screen is how
/// loading states end up inconsistent.
class AsyncBody<T> extends ConsumerWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.onRefresh,
    required this.builder,
    this.loading,
    this.emptyTitle,
    this.emptyMessage,
    this.isEmpty,
  });

  final AsyncValue<T> value;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loading;
  final String? emptyTitle;
  final String? emptyMessage;
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return value.when(
      loading: () => loading ?? const Padding(
        padding: EdgeInsets.all(VSpace.xl),
        child: VSkeletonList(rows: 6),
      ),
      error: (error, _) => VErrorState(
        message: describeError(error),
        code: error is ApiException ? error.code : null,
        onRetry: onRefresh,
      ),
      data: (data) {
        if (isEmpty?.call(data) ?? false) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
                VEmptyState(
                  title: emptyTitle ?? 'Nothing here yet',
                  message: emptyMessage,
                  actionLabel: 'Refresh',
                  onAction: onRefresh,
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          color: context.v.accent,
          backgroundColor: context.v.surface2,
          child: builder(context, data),
        );
      },
    );
  }
}

/// The server's own message when there is one.
///
/// This matters more than it looks: an operator reporting "it says the pattern is
/// awaiting Planner approval" gets help far faster than one reporting "it says
/// something went wrong".
String describeError(Object error) {
  if (error is ApiException) return error.message;
  return error.toString().replaceFirst('Exception: ', '');
}

/// A compact "go to alerts / coverage" action row, reused by the dashboard cards.
class DrillInRow extends StatelessWidget {
  const DrillInRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: VSpace.xs, runSpacing: VSpace.xs, children: children);
  }
}

/// Navigates to the coverage screen filtered to one level. Used by the KPI tiles,
/// so tapping "3 critical" lands on exactly those three parts.
void goToCoverageFiltered(BuildContext context, WidgetRef ref, {String level = 'all'}) {
  ref.read(coverageFiltersProvider.notifier).setLevel(level);
  context.go(Routes.coverage);
}
