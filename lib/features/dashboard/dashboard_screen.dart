import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../../router/app_router.dart';
import '../common/common_widgets.dart';

/// "The health of the line at a glance."
///
/// The layout is ordered by what the plant actually needs to know, in order:
///   1. How many parts are critical / warning — the headline.
///   2. WHICH MACHINE STOPS FIRST, and because of what. This is the question the
///      SRS says they ask every morning, so it gets a card of its own rather than
///      being buried in a list.
///   3. Today's activity, so a supervisor can see the shift is being recorded.
///   4. The worst parts, actionable without a drill-in.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);
    final user = ref.watch(currentUserProvider);

    return AsyncBody<DashboardData>(
      value: async,
      onRefresh: () async => ref.invalidate(dashboardProvider),
      loading: const Padding(
        padding: EdgeInsets.all(VSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VSkeletonKpiRow(count: 4),
            SizedBox(height: VSpace.xl),
            VSkeletonList(rows: 3, height: 140),
          ],
        ),
      ),
      builder: (context, data) => VPageBody(
        children: [
          VPageHeader(
            breadcrumb: const ['Operations', 'Dashboard'],
            title: _greeting(user),
            accentWord: 'stops',
            description: data.lines.length == 1
                ? 'Live coverage for ${data.lines.first.line.name}. '
                    'Every number here derives from the stock ledger.'
                : 'Live coverage across ${data.lines.length} lines. '
                    'Every number here derives from the stock ledger.',
            actions: [
              VButton.ghost(
                label: 'Refresh',
                icon: Icons.refresh_rounded,
                size: VButtonSize.small,
                onPressed: () => ref.invalidate(dashboardProvider),
              ),
              if (user?.can(Perm.reportView) ?? false)
                VButton(
                  label: 'Reports',
                  icon: Icons.summarize_rounded,
                  size: VButtonSize.small,
                  onPressed: () => context.go(Routes.reports),
                ),
            ],
          ),

          _HeadlineRow(data: data),

          const SizedBox(height: VSpace.xl),

          // The first-affected card, per line. Wide because the sentence it
          // carries is the most consequential one on the screen.
          for (final line in data.lines) ...[
            _LineHealthCard(health: line),
            const SizedBox(height: VSpace.md),
          ],

          const SizedBox(height: VSpace.lg),
          VSectionTitle(
            title: 'Today',
            subtitle: 'Recorded so far this shift, plant-local time',
          ),
          _TodayRow(today: data.today),

          const SizedBox(height: VSpace.xl),
          Center(
            child: Text(
              'Generated ${fmtTime(data.generatedAt)} · pull down to refresh',
              style: context.text.labelSmall?.copyWith(color: context.v.txt3),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting(AppUser? user) {
    final hour = DateTime.now().hour;
    final part = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final first = user?.fullName.split(' ').first ?? '';
    return first.isEmpty ? '$part — know which machine stops first' : '$part, $first';
  }
}

/// The four headline tiles. Each is a drill-in.
class _HeadlineRow extends ConsumerWidget {
  const _HeadlineRow({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final totals = data.totals;
    final firstAffected = data.lines
        .map((l) => l.firstAffected)
        .whereType<FirstAffected>()
        .fold<FirstAffected?>(null, (worst, candidate) {
      if (worst == null) return candidate;
      return candidate.machinesAhead < worst.machinesAhead ? candidate : worst;
    });

    return VCardGrid(
      minTileWidth: 250,
      children: [
        VKpiCard(
          label: 'Critical parts',
          value: '${totals.red}',
          icon: Icons.error_rounded,
          iconColor: v.bad,
          iconBackground: v.badTint,
          valueColor: totals.red > 0 ? v.bad : null,
          caption: totals.red == 0
              ? 'Nothing is blocking a machine'
              : 'Immediate action — a machine cannot be built',
          captionColor: totals.red > 0 ? v.bad : null,
          onTap: () => goToCoverageFiltered(context, ref, level: 'red'),
        ),
        VKpiCard(
          label: 'Warning parts',
          value: '${totals.yellow}',
          icon: Icons.warning_amber_rounded,
          iconColor: v.warn,
          iconBackground: v.warnTint,
          valueColor: totals.yellow > 0 ? v.warn : null,
          caption: totals.yellow == 0 ? 'None running low' : 'Arrange material now',
          onTap: () => goToCoverageFiltered(context, ref, level: 'yellow'),
        ),
        VKpiCard(
          label: 'First machine affected',
          // The ribbon treatment is spent HERE, on the one figure that matters
          // most on the screen. One per screen is the restraint rule.
          value: firstAffected?.serialNo ?? '—',
          gradientValue: firstAffected != null,
          icon: Icons.report_problem_rounded,
          caption: firstAffected == null
              ? 'Every planned machine is covered'
              : '${firstAffected.machinesAhead} machine(s) away · ${firstAffected.partLabel}',
          captionColor: firstAffected == null ? v.ok : v.txt2,
          onTap: firstAffected == null
              ? null
              : () => context.go('${Routes.canBuild}?serial=${firstAffected.serialNo}'),
        ),
        VKpiCard(
          label: 'Waiting for approval',
          value: '${data.today.pendingApprovals}',
          icon: Icons.approval_rounded,
          iconColor: v.info,
          iconBackground: v.infoTint,
          caption: data.today.pendingApprovals == 0
              ? 'Nothing in the queue'
              : 'SPD issues and special loads',
          onTap: () => context.go(
            (ref.read(currentUserProvider)?.can(Perm.requestApprove) ?? false)
                ? Routes.approvals
                : Routes.requests,
          ),
        ),
      ],
    );
  }
}

/// One line's health: counts, plan progress, the first-affected sentence, and
/// the five worst parts.
class _LineHealthCard extends ConsumerWidget {
  const _LineHealthCard({required this.health});

  final LineHealth health;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final worst = health.worstLevel;
    final accent = worst == null ? v.ok : v.forStatus(statusFor(worst));

    return VCard(
      cornerMark: true,
      accentEdge: accent,
      padding: const EdgeInsets.fromLTRB(VSpace.xl, VSpace.lg, VSpace.lg, VSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  gradient: VRibbon.gradient,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  health.line.code,
                  style: context.text.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: VSpace.sm),
              Expanded(
                child: Text(health.line.name, style: context.text.titleMedium),
              ),
              VPill(
                label: worst == null ? 'All covered' : levelLabel(worst),
                status: statusFor(worst),
              ),
            ],
          ),

          const SizedBox(height: VSpace.md),

          // The first-affected sentence.
          if (health.firstAffected != null)
            _FirstAffectedBanner(affected: health.firstAffected!, line: health.line)
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(VSpace.md),
              decoration: BoxDecoration(
                color: v.okTint,
                borderRadius: VRadius.allSm,
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded, size: 17, color: v.ok),
                  const SizedBox(width: VSpace.sm),
                  Expanded(
                    child: Text(
                      health.planPending == 0
                          ? 'No machines left in the plan — the Planner needs to extend it.'
                          : 'Every one of the ${health.planPending} planned machines can be built '
                              'with the stock on hand.',
                      style: context.text.bodySmall?.copyWith(
                        color: v.ok,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: VSpace.md),

          // Counts + plan progress.
          Wrap(
            spacing: VSpace.xl,
            runSpacing: VSpace.md,
            children: [
              _MiniStat(
                label: 'Critical',
                value: '${health.counts.red}',
                color: health.counts.red > 0 ? v.bad : v.txt3,
              ),
              _MiniStat(
                label: 'Warning',
                value: '${health.counts.yellow}',
                color: health.counts.yellow > 0 ? v.warn : v.txt3,
              ),
              _MiniStat(label: 'Covered', value: '${health.counts.ok}', color: v.ok),
              _MiniStat(label: 'Parts tracked', value: '${health.counts.total}'),
              _MiniStat(
                label: 'Next machine',
                value: health.nextMachineSerial ?? '—',
              ),
              _MiniStat(
                label: 'Thresholds',
                value: '${health.line.yellowThreshold} / ${health.line.redThreshold}',
              ),
            ],
          ),

          const SizedBox(height: VSpace.md),
          _PlanProgress(health: health),

          if (health.criticalParts.isNotEmpty) ...[
            const SizedBox(height: VSpace.lg),
            Text(
              'MOST CRITICAL',
              style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9.5),
            ),
            const SizedBox(height: VSpace.xs),
            for (final part in health.criticalParts) _CriticalPartRow(part: part),
          ],

          const SizedBox(height: VSpace.md),
          DrillInRow(
            children: [
              VButton.ghost(
                label: 'Shortage matrix',
                icon: Icons.grid_on_rounded,
                size: VButtonSize.small,
                onPressed: () async {
                  await ref.read(selectedLineIdProvider.notifier).select(health.line.id);
                  if (context.mounted) context.go(Routes.matrix);
                },
              ),
              VButton.ghost(
                label: 'Part coverage',
                icon: Icons.inventory_2_rounded,
                size: VButtonSize.small,
                onPressed: () async {
                  await ref.read(selectedLineIdProvider.notifier).select(health.line.id);
                  if (context.mounted) context.go(Routes.coverage);
                },
              ),
              if (health.redAlerts + health.yellowAlerts > 0)
                VButton.ghost(
                  label: 'Alerts (${health.redAlerts + health.yellowAlerts})',
                  icon: Icons.notifications_active_rounded,
                  size: VButtonSize.small,
                  onPressed: () => context.go(Routes.alerts),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FirstAffectedBanner extends StatelessWidget {
  const _FirstAffectedBanner({required this.affected, required this.line});

  final FirstAffected affected;
  final ProductionLine line;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    // Red when it is imminent (inside the red threshold), amber otherwise.
    final imminent = affected.machinesAhead <= line.redThreshold;
    final color = imminent ? v.bad : v.warn;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSpace.md),
      decoration: BoxDecoration(
        color: imminent ? v.badTint : v.warnTint,
        borderRadius: VRadius.allSm,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.dangerous_rounded, size: 19, color: color),
          const SizedBox(width: VSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Machine ${affected.serialNo}',
                        style: context.text.titleSmall?.copyWith(color: color, fontSize: 14),
                      ),
                      TextSpan(
                        text: ' cannot be built — ${affected.machinesAhead} machine(s) away.',
                        style: context.text.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Blocked by ${affected.partLabel}'
                  '${affected.rackCode != null ? ' · rack ${affected.rackCode}' : ''}'
                  '${affected.shortfallQty > 0 ? ' · short by ${fmtQty(affected.shortfallQty)} pcs' : ''}',
                  style: context.text.bodySmall?.copyWith(color: v.txt2, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanProgress extends StatelessWidget {
  const _PlanProgress({required this.health});

  final LineHealth health;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PLAN PROGRESS',
              style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9.5),
            ),
            const Spacer(),
            Text(
              '${health.planBuilt} built · ${health.planPending} to go',
              style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 10.5),
            ),
          ],
        ),
        const SizedBox(height: VSpace.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: v.surface3)),
                FractionallySizedBox(
                  widthFactor: health.planProgress.clamp(0, 1),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: VRibbon.gradient),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CriticalPartRow extends StatelessWidget {
  const _CriticalPartRow({required this.part});

  final CriticalPart part;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final color = v.forStatus(statusFor(part.level));

    return Padding(
      padding: const EdgeInsets.only(bottom: VSpace.xs),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: VSpace.sm),
          Expanded(
            child: Text(
              part.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(color: v.txt2, fontSize: 12),
            ),
          ),
          if (part.rackCode != null) ...[
            Text(
              part.rackCode!,
              style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 10),
            ),
            const SizedBox(width: VSpace.sm),
          ],
          Text(
            '${fmtQty(part.availableStock)} pcs',
            style: context.text.labelSmall?.copyWith(
              color: v.txt2,
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: VSpace.sm),
          SizedBox(
            width: 74,
            child: Text(
              part.firstBlockedSerial == null
                  ? '${part.machinesCovered} left'
                  : '→ ${part.firstBlockedSerial}',
              textAlign: TextAlign.right,
              style: context.text.labelSmall?.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: context.text.titleMedium?.copyWith(
            color: color ?? v.txt,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Today's activity — proof the shift is being recorded.
class _TodayRow extends ConsumerWidget {
  const _TodayRow({required this.today});

  final TodayCounters today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final user = ref.watch(currentUserProvider);

    return VCardGrid(
      minTileWidth: 210,
      children: [
        VKpiCard(
          label: 'Nesting entries',
          value: '${today.nestingEntries}',
          icon: Icons.move_to_inbox_rounded,
          caption: '${fmtQty(today.nestingQty)} pieces received',
          onTap: (user?.can(Perm.nestingView) ?? false) ? () => context.go(Routes.nesting) : null,
        ),
        VKpiCard(
          label: 'Pattern runs',
          value: '${today.patternRuns}',
          icon: Icons.dynamic_feed_rounded,
          caption: '${today.frames} frame(s) loaded',
          onTap: (user?.can(Perm.runView) ?? false) ? () => context.go(Routes.runs) : null,
        ),
        VKpiCard(
          label: 'Machines built',
          value: '${today.machinesBuilt}',
          icon: Icons.precision_manufacturing_rounded,
          iconColor: v.ok,
          iconBackground: v.okTint,
          caption: 'Consumed from the ledger',
          onTap: (user?.can(Perm.machineView) ?? false) ? () => context.go(Routes.plan) : null,
        ),
      ],
    );
  }
}
