import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../common/common_widgets.dart';

/// ---------------------------------------------------------------------------
/// The pending queue — the offline promise, made inspectable.
///
/// An operator who saved twenty receipts on a dead link needs to be able to SEE
/// that all twenty are still there. "It will sync eventually" is not something
/// anyone believes about a shop-floor app, so this screen shows every queued
/// row, what it is, how many times it has been tried, and what the server said
/// when it refused.
///
/// Nothing here can edit a payload. A conflicted row is either retried (after
/// the cause is fixed — the Planner approved the pattern, the material arrived)
/// or abandoned. Silently rewriting what an operator entered would defeat the
/// point of the register being provable.
/// ---------------------------------------------------------------------------
class SyncQueueScreen extends ConsumerWidget {
  const SyncQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(syncQueueProvider);
    final status = ref.watch(syncStatusProvider).valueOrNull ?? const SyncStatus();

    return AsyncBody<List<OutboxRow>>(
      value: queue,
      onRefresh: () async => ref.read(syncServiceProvider).flush(force: true),
      isEmpty: (rows) => rows.isEmpty,
      emptyTitle: 'Nothing waiting',
      emptyMessage: 'Every entry made on this device has reached the server. '
          'You can keep working offline — anything saved will show up here until it uploads.',
      builder: (context, rows) {
        final conflicts = rows.where((r) => r.state == OutboxState.conflict).toList();
        final waiting = rows.where((r) => r.state != OutboxState.conflict).toList();

        return VPageBody(
          children: [
            VPageHeader(
              breadcrumb: const ['Device', 'Pending sync'],
              title: 'Waiting to sync',
              accentWord: 'sync',
              description: 'Entries are saved on this device the moment you tap Save. '
                  'They upload on their own; this is the proof that none of them were lost.',
              actions: [
                VButton.ghost(
                  label: status.syncing ? 'Syncing…' : 'Sync now',
                  icon: Icons.cloud_upload_rounded,
                  size: VButtonSize.small,
                  loading: status.syncing,
                  onPressed: status.syncing
                      ? null
                      : () => ref.read(syncServiceProvider).flush(force: true),
                ),
              ],
            ),

            _StatusStrip(status: status, queued: waiting.length, conflicts: conflicts.length),

            if (conflicts.isNotEmpty) ...[
              const SizedBox(height: VSpace.xl),
              const VSectionTitle(
                title: 'Needs your attention',
                subtitle: 'The server refused these. Retrying alone will not fix them.',
              ),
              for (final row in conflicts)
                Padding(
                  padding: const EdgeInsets.only(bottom: VSpace.sm),
                  child: _QueueCard(row: row),
                ),
            ],

            if (waiting.isNotEmpty) ...[
              const SizedBox(height: VSpace.xl),
              VSectionTitle(
                title: 'In the queue',
                subtitle: '${waiting.length} ${waiting.length == 1 ? 'entry' : 'entries'} '
                    'waiting to upload.',
              ),
              for (final row in waiting)
                Padding(
                  padding: const EdgeInsets.only(bottom: VSpace.sm),
                  child: _QueueCard(row: row),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.status, required this.queued, required this.conflicts});

  final SyncStatus status;
  final int queued;
  final int conflicts;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return VCardGrid(
      minTileWidth: 200,
      children: [
        VKpiCard(
          label: 'Connection',
          value: status.online ? 'Online' : 'Offline',
          icon: status.online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
          iconColor: status.online ? v.ok : v.warn,
          iconBackground: status.online ? v.okTint : v.warnTint,
          valueColor: status.online ? v.ok : v.warn,
          caption: status.lastError,
          captionColor: status.lastError == null ? null : v.bad,
        ),
        VKpiCard(
          label: 'Waiting to upload',
          value: '$queued',
          icon: Icons.schedule_send_rounded,
          valueColor: queued > 0 ? v.warn : null,
        ),
        VKpiCard(
          label: 'Refused',
          value: '$conflicts',
          icon: Icons.report_problem_rounded,
          iconColor: conflicts > 0 ? v.bad : null,
          iconBackground: conflicts > 0 ? v.badTint : null,
          valueColor: conflicts > 0 ? v.bad : null,
        ),
        VKpiCard(
          label: 'Last successful sync',
          value: status.lastSyncAt == null ? '—' : fmtTime(status.lastSyncAt!),
          icon: Icons.history_rounded,
          caption: status.lastSyncAt == null ? 'Not yet this session' : fmtDate(status.lastSyncAt!),
        ),
      ],
    );
  }
}

class _QueueCard extends ConsumerWidget {
  const _QueueCard({required this.row});

  final OutboxRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final conflict = row.state == OutboxState.conflict;
    final failed = row.state == OutboxState.failed;
    final status = conflict
        ? VStatus.critical
        : failed
            ? VStatus.warning
            : VStatus.info;

    return VCard(
      accentEdge: conflict || failed ? v.forStatus(status) : null,
      padding: const EdgeInsets.fromLTRB(VSpace.lg, VSpace.md, VSpace.md, VSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      row.summary.isEmpty ? _kindLabel(row.kind) : row.summary,
                      style: context.text.titleSmall?.copyWith(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_kindLabel(row.kind)} · queued ${fmtRelative(row.queuedAt)}'
                      '${row.attempts > 0 ? ' · ${row.attempts} attempt(s)' : ''}',
                      style: context.text.bodySmall?.copyWith(color: v.txt3, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: VSpace.sm),
              VPill(label: _stateLabel(row.state), status: status, compact: true),
            ],
          ),

          if (row.lastError != null) ...[
            const SizedBox(height: VSpace.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: VSpace.sm, vertical: VSpace.xs),
              decoration: BoxDecoration(
                color: v.tintFor(status),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                row.errorCode == null ? row.lastError! : '${row.lastError!} (${row.errorCode})',
                style: context.text.bodySmall?.copyWith(
                  color: v.forStatus(status),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],

          if (conflict) ...[
            const SizedBox(height: VSpace.md),
            Wrap(
              spacing: VSpace.sm,
              runSpacing: VSpace.xs,
              children: [
                VButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  size: VButtonSize.small,
                  onPressed: () => ref.read(syncServiceProvider).retryConflict(row.id),
                ),
                VButton.danger(
                  label: 'Discard',
                  icon: Icons.delete_outline_rounded,
                  size: VButtonSize.small,
                  onPressed: () => _confirmDiscard(context, ref),
                ),
                VButton.quiet(
                  label: 'What was saved',
                  icon: Icons.data_object_rounded,
                  onPressed: () => _showPayload(context),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.v.surface,
        title: const Text('Discard this entry?'),
        content: const Text(
          'It has never reached the server, so nothing will change in the register — '
          'but what was entered on this device will be gone for good.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Discard', style: TextStyle(color: context.v.bad)),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await ref.read(syncServiceProvider).discardConflict(row.id);
    if (!context.mounted) return;
    VToast.info(context, 'Entry discarded');
  }

  void _showPayload(BuildContext context) {
    String pretty;
    try {
      pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(row.payload));
    } catch (_) {
      pretty = row.payload;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.v.bg2,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(VSpace.xl, 0, VSpace.xl, VSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const VSectionTitle(title: 'Exactly what this device saved'),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.5,
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  pretty,
                  style: VType.mono(color: sheetContext.v.txt2, size: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _kindLabel(OutboxKind kind) => switch (kind) {
        OutboxKind.nesting => 'Nesting receipt',
        OutboxKind.patternRun => 'Pattern run',
        OutboxKind.request => 'Request',
        OutboxKind.machineBuilt => 'Machine built',
      };

  static String _stateLabel(OutboxState state) => switch (state) {
        OutboxState.pending => 'Waiting',
        OutboxState.inFlight => 'Uploading',
        OutboxState.synced => 'Synced',
        OutboxState.conflict => 'Refused',
        OutboxState.failed => 'Will retry',
      };
}
