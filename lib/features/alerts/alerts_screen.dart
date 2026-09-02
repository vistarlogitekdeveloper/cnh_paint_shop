import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../../router/app_router.dart';
import '../common/common_widgets.dart';

/// ---------------------------------------------------------------------------
/// Alerts — every warning in one place, as the SRS asks.
///
/// Deliberately NOT scoped to the selected production line. A red alert on TR
/// still stops the plant when you are standing in front of SCH, and a supervisor
/// who has to switch the line selector to discover a problem will discover it
/// too late.
///
/// Acknowledging is an ownership signal, not a dismissal: the alert stays open
/// until the coverage engine says the shortage has actually cleared. Nothing on
/// this screen can make a red row disappear by hand — that is what makes the
/// list trustworthy.
/// ---------------------------------------------------------------------------
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(alertsProvider);
    final filter = ref.watch(alertsFilterProvider);
    final canAck = ref.watch(canProvider(Perm.alertAck));

    return AsyncBody<List<ShortageAlert>>(
      value: async,
      onRefresh: () async => ref.invalidate(alertsProvider),
      isEmpty: (rows) => rows.isEmpty,
      emptyTitle: switch (filter) {
        'open' => 'Nothing is short right now',
        'acknowledged' => 'Nothing acknowledged',
        _ => 'No alerts yet',
      },
      emptyMessage: filter == 'open'
          ? 'Every tracked part covers the machines still queued. The engine re-checks '
              'after each nesting entry, run and build — you will be told before this changes.'
          : 'Switch the filter to see the alerts that are currently open.',
      builder: (context, rows) {
        final red = rows.where((a) => a.isRed).length;
        final unacknowledged = rows.where((a) => !a.isAcknowledged).length;

        return VPageBody(
          children: [
            VPageHeader(
              breadcrumb: const ['Overview', 'Alerts'],
              title: 'Shortage alerts',
              accentWord: 'alerts',
              description: 'All lines, most urgent first. Red means a machine in the plan '
                  'cannot be built; yellow means it is close enough to act on now.',
              actions: [
                VButton.ghost(
                  label: 'Refresh',
                  icon: Icons.refresh_rounded,
                  size: VButtonSize.small,
                  onPressed: () => ref.invalidate(alertsProvider),
                ),
              ],
            ),

            VCardGrid(
              minTileWidth: 200,
              children: [
                VKpiCard(
                  label: 'Critical',
                  value: '$red',
                  icon: Icons.error_rounded,
                  iconColor: context.v.bad,
                  iconBackground: context.v.badTint,
                  valueColor: red > 0 ? context.v.bad : null,
                ),
                VKpiCard(
                  label: 'Warning',
                  value: '${rows.length - red}',
                  icon: Icons.warning_amber_rounded,
                  iconColor: context.v.warn,
                  iconBackground: context.v.warnTint,
                ),
                VKpiCard(
                  label: 'Not yet acknowledged',
                  value: '$unacknowledged',
                  icon: Icons.pending_actions_rounded,
                  caption: unacknowledged == 0 ? 'Someone has eyes on all of these' : null,
                ),
              ],
            ),

            const SizedBox(height: VSpace.lg),
            VSegmented<String>(
              value: filter,
              onChanged: (next) => ref.read(alertsFilterProvider.notifier).state = next,
              segments: const [
                (value: 'open', label: 'Open', icon: Icons.notifications_active_rounded),
                (value: 'acknowledged', label: 'Acknowledged', icon: Icons.visibility_rounded),
                (value: 'all', label: 'All', icon: null),
              ],
            ),
            const SizedBox(height: VSpace.md),

            for (final alert in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: VSpace.sm),
                child: _AlertCard(alert: alert, canAck: canAck),
              ),
          ],
        );
      },
    );
  }
}

class _AlertCard extends ConsumerStatefulWidget {
  const _AlertCard({required this.alert, required this.canAck});

  final ShortageAlert alert;
  final bool canAck;

  @override
  ConsumerState<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends ConsumerState<_AlertCard> {
  bool _busy = false;

  Future<void> _acknowledge() async {
    setState(() => _busy = true);
    try {
      await ref.read(alertRepositoryProvider).acknowledge(widget.alert.id);
      if (!mounted) return;
      VToast.success(
        context,
        'Acknowledged',
        detail: 'The alert stays open until the shortage actually clears.',
      );
      ref.invalidate(alertsProvider);
      ref.invalidate(badgeCountsProvider);
    } catch (error) {
      if (!mounted) return;
      VToast.error(context, describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final alert = widget.alert;
    final status = statusFor(alert.level);
    final accent = v.forStatus(status);

    return VCard(
      accentEdge: accent,
      padding: const EdgeInsets.fromLTRB(VSpace.lg, VSpace.md, VSpace.md, VSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: alert.part != null
                    ? PartIdentity(part: alert.part!, dense: true)
                    : Text(
                        alert.message ?? 'Shortage',
                        style: context.text.titleSmall?.copyWith(fontSize: 14),
                      ),
              ),
              const SizedBox(width: VSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  VPill(label: levelLabel(alert.level), status: status),
                  const SizedBox(height: 3),
                  Text(
                    fmtRelative(alert.createdAt),
                    style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 10.5),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: VSpace.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: VSpace.sm, vertical: VSpace.xs),
            decoration: BoxDecoration(
              color: v.tintFor(status),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              alert.message ?? _fallbackMessage(alert),
              style: context.text.bodySmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),

          const SizedBox(height: VSpace.md),
          Wrap(
            spacing: VSpace.lg,
            runSpacing: VSpace.xs,
            children: [
              if (alert.lineCode != null) _Fact(label: 'Line', value: alert.lineCode!),
              if (alert.availableStock != null)
                _Fact(label: 'In stock', value: fmtQty(alert.availableStock!)),
              if (alert.machinesCovered != null)
                _Fact(label: 'Covers', value: '${alert.machinesCovered} machines'),
              if (alert.shortfallQty != null && alert.shortfallQty! > 0)
                _Fact(label: 'Short by', value: fmtQty(alert.shortfallQty!), color: v.bad),
              if (alert.firstBlockedSerial != null)
                _Fact(label: 'Blocks', value: alert.firstBlockedSerial!, color: accent),
            ],
          ),

          if (alert.isAcknowledged) ...[
            const SizedBox(height: VSpace.sm),
            Row(
              children: [
                Icon(Icons.visibility_rounded, size: 13, color: v.txt3),
                const SizedBox(width: VSpace.xs),
                Expanded(
                  child: Text(
                    'Acknowledged'
                    '${alert.acknowledgedByName != null ? ' by ${alert.acknowledgedByName}' : ''}'
                    '${alert.acknowledgedAt != null ? ' · ${fmtRelative(alert.acknowledgedAt!)}' : ''}',
                    style: context.text.bodySmall?.copyWith(color: v.txt3, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: VSpace.sm),
          Wrap(
            spacing: VSpace.sm,
            runSpacing: VSpace.xs,
            children: [
              if (widget.canAck && !alert.isAcknowledged)
                VButton(
                  label: 'Acknowledge',
                  icon: Icons.check_rounded,
                  size: VButtonSize.small,
                  loading: _busy,
                  onPressed: _busy ? null : _acknowledge,
                ),
              if (alert.firstBlockedSerial != null)
                VButton.ghost(
                  label: 'Check ${alert.firstBlockedSerial}',
                  icon: Icons.fact_check_rounded,
                  size: VButtonSize.small,
                  onPressed: () =>
                      context.go('${Routes.canBuild}?serial=${alert.firstBlockedSerial}'),
                ),
              if (alert.part != null)
                VButton.quiet(
                  label: 'Find this part',
                  icon: Icons.search_rounded,
                  onPressed: () =>
                      context.go('${Routes.lookup}?q=${alert.part!.unpaintedPn}'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The server always sends a message; this is only for a row that predates it.
  static String _fallbackMessage(ShortageAlert alert) {
    final part = alert.part?.unpaintedPn ?? 'This part';
    if (alert.firstBlockedSerial != null) {
      return '$part runs out at machine ${alert.firstBlockedSerial}.';
    }
    return '$part is below the threshold for this line.';
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.color});

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
        Text(
          value,
          style: context.text.titleSmall?.copyWith(
            fontSize: 13,
            color: color ?? v.txt,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
