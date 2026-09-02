import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../common/common_widgets.dart';

/// ---------------------------------------------------------------------------
/// Spares (SPD) requests, and the Planner's approvals inbox.
///
/// ONE screen with two lenses rather than two screens, because they render the
/// same rows from the same endpoint and differ only in which actions are
/// offered. Two implementations would drift the moment a field is added.
///
///   approvalsMode: false → "requests" — the Supervisor's view, with Raise.
///   approvalsMode: true  → "approvals" — the Planner's queue, with Approve/Reject.
///
/// The thing worth understanding here: approving an SPD issue moves stock in the
/// SAME database transaction as the status change. A request that reads
/// "approved" while the pieces are still on the rack is exactly the ambiguity
/// the paper register suffered from, and the server closes it — so the UI must
/// not imply the two steps are separate.
/// ---------------------------------------------------------------------------
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key, this.approvalsMode = false});

  final bool approvalsMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(requestsProvider);
    final filter = ref.watch(requestsFilterProvider);
    final canRaise = ref.watch(canProvider(Perm.requestCreate));
    final canApprove = ref.watch(canProvider(Perm.requestApprove));

    return AsyncBody<List<SpdRequest>>(
      value: async,
      onRefresh: () async => ref.invalidate(requestsProvider),
      isEmpty: (rows) => rows.isEmpty,
      emptyTitle: approvalsMode
          ? 'Nothing waiting for approval'
          : (filter == 'pending' ? 'No pending requests' : 'No requests yet'),
      emptyMessage: approvalsMode
          ? 'When a Supervisor raises an SPD issue or a special load, it lands here.'
          : 'Requests to divert parts to spares, or to load a non-standard frame, appear here.',
      builder: (context, rows) {
        final pending = rows.where((r) => r.isPending).toList();
        final decided = rows.where((r) => !r.isPending).toList();

        return VPageBody(
          children: [
            VPageHeader(
              breadcrumb: ['Planning', approvalsMode ? 'Approvals' : 'Spares (SPD)'],
              title: approvalsMode ? 'Approvals' : 'Spares & special loads',
              description: approvalsMode
                  ? 'Approving an SPD issue moves the pieces out of stock in the same step — '
                      'the ledger and the decision can never disagree.'
                  : 'Ask for parts to be diverted to spares, or for a non-standard frame to be '
                      'loaded. A Planner decides.',
              actions: [
                if (canRaise && !approvalsMode)
                  VButton(
                    label: 'Raise a request',
                    icon: Icons.add_rounded,
                    size: VButtonSize.small,
                    onPressed: () => _openRaiseSheet(context, ref),
                  ),
                VButton.ghost(
                  label: 'Refresh',
                  icon: Icons.refresh_rounded,
                  size: VButtonSize.small,
                  onPressed: () => ref.invalidate(requestsProvider),
                ),
              ],
            ),

            _CountsRow(rows: rows),
            const SizedBox(height: VSpace.lg),

            VSegmented<String>(
              value: filter,
              onChanged: (next) => ref.read(requestsFilterProvider.notifier).state = next,
              segments: const [
                (value: 'pending', label: 'Pending', icon: Icons.hourglass_top_rounded),
                (value: 'approved', label: 'Approved', icon: Icons.check_circle_rounded),
                (value: 'rejected', label: 'Rejected', icon: Icons.cancel_rounded),
                (value: 'all', label: 'All', icon: null),
              ],
            ),
            const SizedBox(height: VSpace.lg),

            if (pending.isNotEmpty) ...[
              VSectionTitle(
                title: approvalsMode ? 'Waiting for your decision' : 'Pending',
                subtitle: '${pending.length} request(s)',
              ),
              for (final request in pending)
                Padding(
                  padding: const EdgeInsets.only(bottom: VSpace.sm),
                  child: _RequestCard(
                    request: request,
                    canApprove: canApprove,
                    canRaise: canRaise,
                  ),
                ),
            ],

            if (decided.isNotEmpty) ...[
              if (pending.isNotEmpty) const SizedBox(height: VSpace.lg),
              VSectionTitle(title: 'Decided', subtitle: '${decided.length} request(s)'),
              for (final request in decided)
                Padding(
                  padding: const EdgeInsets.only(bottom: VSpace.sm),
                  child: _RequestCard(
                    request: request,
                    canApprove: canApprove,
                    canRaise: canRaise,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  static void _openRaiseSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.v.bg2,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (_) => const _RaiseRequestSheet(),
    );
  }
}

class _CountsRow extends StatelessWidget {
  const _CountsRow({required this.rows});

  final List<SpdRequest> rows;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final pending = rows.where((r) => r.status == RequestStatus.pending).length;
    final approved = rows.where((r) => r.status == RequestStatus.approved).length;
    final rejected = rows.where((r) => r.status == RequestStatus.rejected).length;
    final pieces = rows
        .where((r) => r.type == RequestType.spdIssue && r.status == RequestStatus.approved)
        .fold<int>(0, (sum, r) => sum + (r.quantity ?? 0));

    return VCardGrid(
      minTileWidth: 190,
      children: [
        VKpiCard(
          label: 'Pending',
          value: '$pending',
          icon: Icons.hourglass_top_rounded,
          iconColor: v.warn,
          iconBackground: v.warnTint,
          valueColor: pending > 0 ? v.warn : null,
        ),
        VKpiCard(
          label: 'Approved',
          value: '$approved',
          icon: Icons.check_circle_rounded,
          iconColor: v.ok,
          iconBackground: v.okTint,
        ),
        VKpiCard(
          label: 'Rejected',
          value: '$rejected',
          icon: Icons.cancel_rounded,
          iconColor: v.txt3,
        ),
        VKpiCard(
          label: 'Pieces issued to spares',
          value: '$pieces',
          icon: Icons.outbox_rounded,
          caption: 'From approved SPD issues on this list',
        ),
      ],
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({
    required this.request,
    required this.canApprove,
    required this.canRaise,
  });

  final SpdRequest request;
  final bool canApprove;
  final bool canRaise;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _busy = false;

  SpdRequest get request => widget.request;

  VStatus get _statusTone => switch (request.status) {
        RequestStatus.pending => VStatus.warning,
        RequestStatus.approved => VStatus.ready,
        RequestStatus.rejected => VStatus.critical,
        RequestStatus.cancelled => VStatus.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final me = ref.watch(currentUserProvider);
    final isMine = me != null && request.requestedByName == me.fullName;

    return VCard(
      accentEdge: request.isPending ? v.warn : null,
      padding: const EdgeInsets.fromLTRB(VSpace.lg, VSpace.md, VSpace.md, VSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: v.tintFor(_statusTone),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  request.type == RequestType.spdIssue
                      ? Icons.outbox_rounded
                      : Icons.view_module_rounded,
                  size: 17,
                  color: v.forStatus(_statusTone),
                ),
              ),
              const SizedBox(width: VSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            request.type.label,
                            style: context.text.titleSmall?.copyWith(fontSize: 14),
                          ),
                        ),
                        if (request.lineCode != null) ...[
                          const SizedBox(width: VSpace.xs),
                          VPill(
                            label: request.lineCode!,
                            status: VStatus.info,
                            showDot: false,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Raised by ${request.requestedByName ?? 'someone'} · '
                      '${fmtRelative(request.createdAt)}',
                      style: context.text.bodySmall?.copyWith(color: v.txt3, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              VPill(label: request.status.label, status: _statusTone),
            ],
          ),

          const SizedBox(height: VSpace.md),

          // The subject: a part + quantity for an SPD issue, a frame for a
          // special load.
          if (request.part != null)
            Container(
              padding: const EdgeInsets.all(VSpace.sm),
              decoration: BoxDecoration(
                color: v.surface2,
                borderRadius: VRadius.allSm,
              ),
              child: Row(
                children: [
                  Expanded(child: PartIdentity(part: request.part!, dense: true)),
                  if (request.quantity != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${request.quantity}',
                          style: context.text.titleMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          'PIECES',
                          style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9),
                        ),
                      ],
                    ),
                ],
              ),
            )
          else if (request.patternCode != null)
            Container(
              padding: const EdgeInsets.all(VSpace.sm),
              decoration: BoxDecoration(color: v.surface2, borderRadius: VRadius.allSm),
              child: Row(
                children: [
                  Icon(Icons.view_module_rounded, size: 15, color: v.txt3),
                  const SizedBox(width: VSpace.xs),
                  Text(
                    'Pattern ${request.patternCode}',
                    style: context.text.labelMedium?.copyWith(color: v.txt),
                  ),
                ],
              ),
            ),

          if (request.reason != null && request.reason!.isNotEmpty) ...[
            const SizedBox(height: VSpace.sm),
            Text(
              request.reason!,
              style: context.text.bodySmall?.copyWith(color: v.txt2, height: 1.45),
            ),
          ],

          // The decision trail. Always shown once decided, because "who decided
          // and why" is half the point of putting this in the app at all.
          if (!request.isPending && request.status != RequestStatus.cancelled) ...[
            const SizedBox(height: VSpace.sm),
            Container(
              padding: const EdgeInsets.all(VSpace.sm),
              decoration: BoxDecoration(
                color: v.tintFor(_statusTone),
                borderRadius: VRadius.allSm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    request.status == RequestStatus.approved
                        ? Icons.verified_rounded
                        : Icons.block_rounded,
                    size: 14,
                    color: v.forStatus(_statusTone),
                  ),
                  const SizedBox(width: VSpace.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${request.status.label} by ${request.approvedByName ?? 'a planner'}'
                          '${request.decidedAt != null ? ' · ${fmtDateTime(request.decidedAt!)}' : ''}',
                          style: context.text.bodySmall?.copyWith(
                            color: v.forStatus(_statusTone),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                        if (request.decisionNote != null && request.decisionNote!.isNotEmpty)
                          Text(
                            request.decisionNote!,
                            style: context.text.bodySmall?.copyWith(color: v.txt2, fontSize: 11.5),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (request.isPending && (widget.canApprove || isMine)) ...[
            const SizedBox(height: VSpace.md),
            Wrap(
              spacing: VSpace.sm,
              runSpacing: VSpace.sm,
              children: [
                if (widget.canApprove) ...[
                  VButton(
                    label: 'Approve',
                    icon: Icons.check_rounded,
                    size: VButtonSize.small,
                    loading: _busy,
                    onPressed: _busy ? null : () => _decide(approve: true),
                  ),
                  VButton.danger(
                    label: 'Reject',
                    icon: Icons.close_rounded,
                    size: VButtonSize.small,
                    onPressed: _busy ? null : () => _decide(approve: false),
                  ),
                ],
                if (isMine)
                  VButton.quiet(
                    label: 'Withdraw',
                    size: VButtonSize.small,
                    onPressed: _busy ? null : _cancel,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _decide({required bool approve}) async {
    final note = await _askForNote(approve: approve);
    // A null note means the dialog was dismissed — that is a cancel, not an
    // empty note.
    if (note == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(requestRepositoryProvider);
      if (approve) {
        await repo.approve(request.id, note: note.isEmpty ? null : note);
      } else {
        await repo.reject(request.id, note: note.isEmpty ? null : note);
      }

      if (!mounted) return;
      VToast.success(
        context,
        approve ? 'Approved' : 'Rejected',
        detail: approve && request.type == RequestType.spdIssue
            ? '${request.quantity} pieces have left stock.'
            : null,
      );

      // Approving an SPD issue moved the ledger, so coverage, alerts and the
      // dashboard are all stale.
      ref
        ..invalidate(requestsProvider)
        ..invalidate(badgeCountsProvider)
        ..invalidate(coverageProvider)
        ..invalidate(alertsProvider)
        ..invalidate(dashboardProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      // 409 means someone else decided first; 422 means stock moved since the
      // request was raised. Both are real states, not bugs — say what happened
      // and refresh so the screen stops lying.
      VToast.error(
        context,
        e.isConflict ? 'Someone decided this first' : 'Could not ${approve ? 'approve' : 'reject'}',
        detail: e.message,
      );
      ref.invalidate(requestsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askForNote({required bool approve}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'Approve this request?' : 'Reject this request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (approve && request.type == RequestType.spdIssue)
              Padding(
                padding: const EdgeInsets.only(bottom: VSpace.md),
                child: Text(
                  '${request.quantity} pieces of ${request.part?.description ?? 'this part'} '
                  'will leave stock immediately and coverage will be recalculated.',
                  style: context.text.bodySmall?.copyWith(color: context.v.txt2, height: 1.5),
                ),
              ),
            VInput(
              controller: controller,
              label: approve ? 'Note (optional)' : 'Reason for rejecting',
              hint: approve ? 'Anything the requester should know' : 'Why not?',
              maxLines: 3,
              minLines: 2,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            style: approve
                ? null
                : FilledButton.styleFrom(backgroundColor: context.v.bad),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await ref.read(requestRepositoryProvider).cancel(request.id);
      if (!mounted) return;
      VToast.info(context, 'Request withdrawn');
      ref.invalidate(requestsProvider);
      ref.invalidate(badgeCountsProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      VToast.error(context, 'Could not withdraw', detail: e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Raise an SPD issue or a special load.
class _RaiseRequestSheet extends ConsumerStatefulWidget {
  const _RaiseRequestSheet();

  @override
  ConsumerState<_RaiseRequestSheet> createState() => _RaiseRequestSheetState();
}

class _RaiseRequestSheetState extends ConsumerState<_RaiseRequestSheet> {
  RequestType _type = RequestType.spdIssue;

  Part? _part;
  Pattern? _pattern;
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _searchController = TextEditingController();

  List<Part> _results = const [];
  bool _searching = false;
  bool _submitting = false;
  String? _error;
  String? _quantityError;

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int get _quantity => int.tryParse(_quantityController.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final line = ref.watch(selectedLineProvider);

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
            Text('Raise a request', style: context.text.headlineSmall),
            const SizedBox(height: VSpace.xs),
            Text(
              'A Planner decides. Nothing moves until they approve.',
              style: context.text.bodySmall?.copyWith(color: v.txt3),
            ),
            const SizedBox(height: VSpace.lg),

            VSegmented<RequestType>(
              expand: true,
              value: _type,
              onChanged: (next) => setState(() {
                _type = next;
                _error = null;
              }),
              segments: const [
                (
                  value: RequestType.spdIssue,
                  label: 'SPD issue',
                  icon: Icons.outbox_rounded,
                ),
                (
                  value: RequestType.specialLoad,
                  label: 'Special load',
                  icon: Icons.view_module_rounded,
                ),
              ],
            ),
            const SizedBox(height: VSpace.lg),

            if (_type == RequestType.spdIssue) ..._spdFields(line) else ..._loadFields(),

            const SizedBox(height: VSpace.lg),
            VInput(
              controller: _reasonController,
              label: 'Reason',
              hint: _type == RequestType.spdIssue
                  ? 'e.g. Spares order SO-2026-4471'
                  : 'Why this frame combination is needed',
              maxLines: 3,
              minLines: 2,
            ),

            if (_error != null) ...[
              const SizedBox(height: VSpace.md),
              Container(
                padding: const EdgeInsets.all(VSpace.md),
                decoration: BoxDecoration(
                  color: v.badTint,
                  borderRadius: VRadius.allSm,
                  border: Border.all(color: v.bad.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 16, color: v.bad),
                    const SizedBox(width: VSpace.sm),
                    Expanded(
                      child: Text(
                        _error!,
                        style: context.text.bodySmall?.copyWith(
                          color: v.bad,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: VSpace.xl),
            VButton(
              label: 'Send for approval',
              icon: Icons.send_rounded,
              size: VButtonSize.large,
              expand: true,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: VSpace.md),
          ],
        ),
      ),
    );
  }

  List<Widget> _spdFields(ProductionLine? line) {
    final v = context.v;
    return [
      if (_part == null) ...[
        VSearchField(
          controller: _searchController,
          hint: 'Search a part number or description',
          onChanged: _search,
        ),
        const SizedBox(height: VSpace.sm),
        if (_searching)
          const Padding(
            padding: EdgeInsets.all(VSpace.md),
            child: Center(child: VSpinner()),
          )
        else
          for (final part in _results.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: VSpace.xs),
              child: VCard(
                onTap: () => setState(() {
                  _part = part;
                  _results = const [];
                }),
                padding: const EdgeInsets.all(VSpace.sm),
                child: Row(
                  children: [
                    Expanded(child: PartIdentity(part: part, dense: true)),
                    Text(
                      '${fmtQty(part.availableStock)} pcs',
                      style: context.text.labelMedium?.copyWith(
                        color: v.txt2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ] else ...[
        VCard(
          padding: const EdgeInsets.all(VSpace.md),
          child: Row(
            children: [
              Expanded(child: PartIdentity(part: _part!)),
              VIconButton(
                icon: Icons.close_rounded,
                size: 32,
                iconSize: 16,
                filled: false,
                tooltip: 'Choose a different part',
                onPressed: () => setState(() {
                  _part = null;
                  _quantityError = null;
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSpace.md),
        VInput(
          controller: _quantityController,
          label: 'Pieces to issue',
          hint: '0',
          large: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          errorText: _quantityError,
          onChanged: (_) => setState(() => _quantityError = null),
        ),
        const SizedBox(height: VSpace.sm),
        // The decision the supervisor is actually making, stated plainly before
        // they commit to it.
        _ImpactPreview(part: _part!, quantity: _quantity, line: line),
      ],
    ];
  }

  List<Widget> _loadFields() {
    final patterns = ref.watch(patternsProvider).valueOrNull ?? const [];
    return [
      VDropdown<Pattern>(
        label: 'Pattern to load',
        hint: patterns.isEmpty ? 'No patterns on this line' : 'Choose a frame',
        items: patterns,
        value: _pattern,
        itemLabel: (p) => '${p.code}${p.name != null ? ' · ${p.name}' : ''}',
        large: true,
        onChanged: (next) => setState(() => _pattern = next),
      ),
    ];
  }

  Future<void> _search(String term) async {
    if (term.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _searching = true);
    try {
      final rows = await ref.read(masterRepositoryProvider).searchParts(term, limit: 8);
      if (mounted) setState(() => _results = rows);
    } on ApiException {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _submit() async {
    final line = ref.read(selectedLineProvider);

    if (_type == RequestType.spdIssue) {
      if (_part == null) {
        setState(() => _error = 'Choose the part to issue.');
        return;
      }
      if (_quantity <= 0) {
        setState(() => _quantityError = 'How many pieces?');
        return;
      }
      if (_quantity > _part!.availableStock) {
        setState(() => _quantityError =
            'Only ${fmtQty(_part!.availableStock)} pieces are available.');
        return;
      }
    } else if (_pattern == null) {
      setState(() => _error = 'Choose the pattern to load.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(requestRepositoryProvider).create({
        'type': _type.wire,
        if (line != null) 'line_id': line.id,
        if (_type == RequestType.spdIssue) ...{
          'part_id': _part!.id,
          'quantity': _quantity,
        } else
          'pattern_id': _pattern!.id,
        if (_reasonController.text.trim().isNotEmpty) 'reason': _reasonController.text.trim(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      VToast.success(
        context,
        'Sent for approval',
        detail: 'A Planner will decide. You will be notified.',
      );
      ref.invalidate(requestsProvider);
      ref.invalidate(badgeCountsProvider);
    } on ApiException catch (e) {
      // Keep the sheet open on a server refusal — the operator has typed a
      // reason and should not lose it to a closed sheet.
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

/// What issuing these pieces does to the part's cover.
class _ImpactPreview extends ConsumerWidget {
  const _ImpactPreview({required this.part, required this.quantity, required this.line});

  final Part part;
  final int quantity;
  final ProductionLine? line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final after = part.availableStock - quantity;
    final tooMuch = quantity > part.availableStock;

    return Container(
      padding: const EdgeInsets.all(VSpace.md),
      decoration: BoxDecoration(
        color: tooMuch ? v.badTint : v.surface2,
        borderRadius: VRadius.allSm,
        border: Border.all(color: tooMuch ? v.bad.withValues(alpha: 0.35) : v.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ImpactFigure(label: 'Available now', value: fmtQty(part.availableStock)),
          ),
          Icon(Icons.arrow_forward_rounded, size: 16, color: v.txt3),
          Expanded(
            child: _ImpactFigure(
              label: 'After issuing',
              value: fmtQty(after),
              color: tooMuch ? v.bad : (after <= 0 ? v.bad : v.txt),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactFigure extends StatelessWidget {
  const _ImpactFigure({required this.label, required this.value, this.color});

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
          style: context.text.titleMedium?.copyWith(
            color: color ?? v.txt,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
