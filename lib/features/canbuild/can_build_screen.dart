import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../../router/app_router.dart';
import '../common/common_widgets.dart';

/// ---------------------------------------------------------------------------
/// "Can I build machine N?" — SRS step 7.
///
/// One question, one answer, readable from arm's length: Ready, or the exact
/// parts that stop it. Anyone can ask — the screen is gated on COVERAGE_VIEW,
/// not on a build permission, because the point is to check BEFORE committing to
/// a machine, and the person who asks is often not the person who marks it built.
///
/// The answer is not a stock check. The server walks the plan from the first
/// pending machine up to and including the one asked about, subtracting each
/// machine's real requirement on the way (project units and Rotavator variants
/// consume different quantities). That walk is why `available_at_machine` is a
/// FUTURE balance, and why a part sitting on the shelf today can still be the
/// reason machine 640 cannot be built. The UI says so out loud — it is the one
/// number people misread.
/// ---------------------------------------------------------------------------

/// The question, as a value. A record so the family key gets structural equality
/// for free, and so the line is part of the key: the same serial checked against
/// a different line is a genuinely different question, not a cache hit.
typedef _Ask = ({String lineId, String serial});

final _canBuildProvider = FutureProvider.autoDispose.family<CanBuildResult, _Ask>((ref, ask) {
  return ref.watch(coverageRepositoryProvider).canBuild(
        lineId: ask.lineId,
        serialNo: ask.serial,
      );
});

class CanBuildScreen extends ConsumerStatefulWidget {
  const CanBuildScreen({super.key});

  @override
  ConsumerState<CanBuildScreen> createState() => _CanBuildScreenState();
}

class _CanBuildScreenState extends ConsumerState<CanBuildScreen> {
  /// A supervisor checks the same handful of machines all shift — the two either
  /// side of the current one, and whatever the alerts screen flagged. Keeping the
  /// list on the screen turns a re-check into one tap.
  static const int _recentLimit = 8;

  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// The serial the answer on screen belongs to. Null until something is asked.
  String? _checked;
  String? _error;

  final List<String> _recent = [];

  /// The `?serial=` we have already acted on. Without this, every rebuild would
  /// re-run the deep-linked check and stomp on whatever the user typed since.
  String? _deepLinked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Several screens land here with the machine already chosen — the coverage
    // row's "Check", the dashboard's first-affected card, the alerts list. They
    // all deserve the answer without a second tap.
    final fromRoute = GoRouterState.of(context).uri.queryParameters['serial']?.trim();
    if (fromRoute == null || fromRoute.isEmpty || fromRoute == _deepLinked) return;

    _deepLinked = fromRoute;
    _setText(fromRoute);
    // Mutating fields directly rather than through setState: didChangeDependencies
    // runs immediately before build, so the frame already picks this up.
    _stage(fromRoute);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setText(String serial) {
    _controller.value = TextEditingValue(
      text: serial,
      selection: TextSelection.collapsed(offset: serial.length),
    );
  }

  /// Records the question. Returns false when there is nothing to ask.
  bool _stage(String raw) {
    final serial = raw.trim();
    if (serial.isEmpty) {
      _error = 'Enter a machine serial number.';
      return false;
    }
    _error = null;
    _checked = serial;
    _recent
      ..removeWhere((s) => s.toLowerCase() == serial.toLowerCase())
      ..insert(0, serial);
    if (_recent.length > _recentLimit) _recent.removeLast();
    return true;
  }

  void _submit(String raw, ProductionLine line) {
    final serial = raw.trim();
    // Re-asking the same serial has to hit the server again: the plan moves
    // during a shift, and "I checked it ten minutes ago" is not an answer.
    final isRecheck = serial.isNotEmpty && serial == _checked;

    setState(() => _stage(raw));

    if (isRecheck) {
      ref.invalidate(_canBuildProvider((lineId: line.id, serial: serial)));
    }
    if (serial.isNotEmpty) {
      _setText(serial);
      // The answer is the point; on a phone the keyboard would cover it.
      _focus.unfocus();
    }
  }

  void _checkAnother() {
    setState(() {
      _checked = null;
      _error = null;
      _controller.clear();
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return LineRequired(builder: _bodyFor);
  }

  Widget _bodyFor(BuildContext context, ProductionLine line) {
    final serial = _checked;

    return VPageBody(
      children: [
        VPageHeader(
          breadcrumb: const ['Shortage', 'Can I build?'],
          title: 'Can I build this machine?',
          accentWord: 'build',
          description: 'Checking against ${line.name} (${line.code}). Enter the serial number as '
              'it appears in the plan — the app walks every machine queued ahead of it before '
              'answering.',
          actions: [
            VButton.ghost(
              label: 'Matrix view',
              icon: Icons.grid_on_rounded,
              size: VButtonSize.small,
              onPressed: () => context.go(Routes.matrix),
            ),
            VButton.ghost(
              label: 'Part coverage',
              icon: Icons.query_stats_rounded,
              size: VButtonSize.small,
              onPressed: () => context.go(Routes.coverage),
            ),
          ],
        ),

        _AskCard(
          controller: _controller,
          focusNode: _focus,
          errorText: _error,
          line: line,
          // A deep link arrives with the answer already wanted; stealing focus
          // would pop the keyboard over the very thing the caller came to read.
          autofocus: _deepLinked == null,
          onSubmit: (value) => _submit(value, line),
        ),

        if (_recent.length > 1) ...[
          const SizedBox(height: VSpace.md),
          _RecentStrip(
            serials: _recent,
            current: serial,
            onTap: (value) {
              _setText(value);
              _submit(value, line);
            },
          ),
        ],

        const SizedBox(height: VSpace.xl),

        if (serial == null)
          _IdlePrompt(line: line)
        else
          _AnswerSection(
            line: line,
            serial: serial,
            onCheckAnother: _checkAnother,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Asking
// ---------------------------------------------------------------------------

class _AskCard extends StatelessWidget {
  const _AskCard({
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.line,
    required this.autofocus,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final ProductionLine line;
  final bool autofocus;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final stacked = MediaQuery.sizeOf(context).width < VBreak.phone;

    final field = VInput(
      controller: controller,
      focusNode: focusNode,
      label: 'Machine serial number',
      hint: 'e.g. 617 or ATS44-01',
      helper: 'Press Enter to check.',
      errorText: errorText,
      prefixIcon: Icons.precision_manufacturing_rounded,
      large: true,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      // Serials are typed in upper case on the shop floor ('ATS44-01'), and a
      // phone keyboard will happily send 'ats44-01' otherwise.
      textCapitalization: TextCapitalization.characters,
      onSubmitted: onSubmit,
    );

    final checkButton = VButton(
      label: 'Check',
      icon: Icons.fact_check_rounded,
      size: VButtonSize.large,
      expand: stacked,
      onPressed: () => onSubmit(controller.text),
    );

    return VCard(
      padding: const EdgeInsets.all(VSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VSectionTitle(
            title: 'Check a machine',
            trailing: VPill(label: line.code, status: VStatus.info, showDot: false),
          ),
          if (stacked)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: VSpace.md),
                checkButton,
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: field),
                const SizedBox(width: VSpace.md),
                // Nudged down past the field's label so the two line up on the
                // input's own top edge rather than on the label's.
                Padding(padding: const EdgeInsets.only(top: 27), child: checkButton),
              ],
            ),
          const SizedBox(height: VSpace.sm),
          Text(
            'Thresholds on this line: warning at ${line.yellowThreshold} machines of cover, '
            'critical at ${line.redThreshold}.',
            style: context.text.bodySmall?.copyWith(color: v.txt3),
          ),
        ],
      ),
    );
  }
}

class _RecentStrip extends StatelessWidget {
  const _RecentStrip({required this.serials, required this.current, required this.onTap});

  final List<String> serials;
  final String? current;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 9, right: VSpace.sm),
          child: Row(
            children: [
              Icon(Icons.history_rounded, size: 14, color: v.txt3),
              const SizedBox(width: 5),
              Text(
                'Recent',
                style: context.text.labelSmall?.copyWith(color: v.txt3),
              ),
            ],
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: VSpace.xs,
            runSpacing: VSpace.xs,
            children: [
              for (final serial in serials)
                VChip(
                  label: serial,
                  selected: serial == current,
                  onTap: () => onTap(serial),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown before the first question. Says what the answer will contain, so nobody
/// has to ask a machine to find out whether this screen is the one they wanted.
class _IdlePrompt extends StatelessWidget {
  const _IdlePrompt({required this.line});

  final ProductionLine line;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return VCard(
      cornerMark: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VSectionTitle(title: 'What you get back'),
          for (final (icon, color, text) in [
            (
              Icons.check_circle_rounded,
              v.ok,
              'Ready — every part the machine needs is still covered by the time the plan '
                  'reaches it.',
            ),
            (
              Icons.report_problem_rounded,
              v.bad,
              'Blocked — the exact parts, how many pieces short, and which rack they live on.',
            ),
            (
              Icons.help_outline_rounded,
              v.txt3,
              'Already built, or not in ${line.name}\'s plan at all — so a mistyped serial is '
                  'obvious straight away.',
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: VSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: VSpace.sm),
                  Expanded(
                    child: Text(
                      text,
                      style: context.text.bodyMedium?.copyWith(color: v.txt2, height: 1.5),
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

// ---------------------------------------------------------------------------
// The answer
// ---------------------------------------------------------------------------

class _AnswerSection extends ConsumerWidget {
  const _AnswerSection({
    required this.line,
    required this.serial,
    required this.onCheckAnother,
  });

  final ProductionLine line;
  final String serial;
  final VoidCallback onCheckAnother;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ask = (lineId: line.id, serial: serial);
    final async = ref.watch(_canBuildProvider(ask));

    return async.when(
      loading: () => const _AnswerSkeleton(),
      // The server's own words: "no machine plan loaded for this line" is a
      // different problem from "no connection", and the operator needs to know
      // which one they have.
      error: (error, _) => VErrorState(
        title: 'Could not check machine $serial',
        message: describeError(error),
        code: error is ApiException ? error.code : null,
        onRetry: () => ref.invalidate(_canBuildProvider(ask)),
      ),
      data: (result) => _Answer(
        result: result,
        asked: serial,
        line: line,
        onCheckAnother: onCheckAnother,
        onRecheck: () => ref.invalidate(_canBuildProvider(ask)),
      ),
    );
  }
}

class _Answer extends ConsumerWidget {
  const _Answer({
    required this.result,
    required this.asked,
    required this.line,
    required this.onCheckAnother,
    required this.onRecheck,
  });

  final CanBuildResult result;

  /// What the user actually typed. Used verbatim if the server echoed nothing —
  /// an answer headed "Machine  is ready" would be worse than no answer.
  final String asked;

  final ProductionLine line;
  final VoidCallback onCheckAnother;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serial = result.serialNo.isEmpty ? asked : result.serialNo;

    // Order matters. A serial that is not in the plan also comes back with
    // ready == false, and answering "blocked" there would send someone hunting
    // for parts that were never required.
    if (result.notInPlan) {
      return _BigAnswer(
        status: VStatus.warning,
        icon: Icons.help_outline_rounded,
        headline: '$serial is not in this line\'s plan',
        body: 'Nothing on ${line.name} is planned with that serial, so there is no requirement '
            'to check it against. Either the serial is mistyped, or the unit belongs to another '
            'line or has not been loaded into the plan yet.',
        actions: [
          VButton.ghost(
            label: 'Check another',
            icon: Icons.restart_alt_rounded,
            onPressed: onCheckAnother,
          ),
          if (ref.watch(canProvider(Perm.machineView)))
            VButton.ghost(
              label: 'Open the Machine Plan',
              icon: Icons.list_alt_rounded,
              onPressed: () => context.go(Routes.plan),
            ),
        ],
      );
    }

    if (result.alreadyBuilt) {
      return _BigAnswer(
        status: VStatus.info,
        icon: Icons.task_alt_rounded,
        headline: 'Machine $serial has already been built',
        body: result.builtAt == null
            ? 'The plan already shows this unit as built, so its parts have been consumed.'
            : 'Marked built on ${fmtDateTime(result.builtAt!)}. Its parts have already been '
                'consumed from stock.',
        pill: _specialPill(result),
        footnotes: const ['Nothing to check — pick the next unbuilt serial.'],
        actions: [
          VButton.ghost(
            label: 'Check another',
            icon: Icons.restart_alt_rounded,
            onPressed: onCheckAnother,
          ),
        ],
      );
    }

    if (result.ready) {
      return _BigAnswer(
        status: VStatus.ready,
        icon: Icons.check_circle_rounded,
        headline: 'Machine $serial is ready to build',
        body: 'Every part it needs is covered — including the pieces taken by the machines '
            'queued ahead of it.',
        pill: _specialPill(result),
        footnotes: [
          result.machinesAhead == 0
              ? 'It is the next machine in the plan.'
              : '${result.machinesAhead} machine(s) ahead of it in the plan.',
          'Checked against ${line.name} just now.',
        ],
        actions: [
          VButton.ghost(
            label: 'Check another',
            icon: Icons.restart_alt_rounded,
            onPressed: onCheckAnother,
          ),
          VButton.quiet(
            label: 'Re-check',
            icon: Icons.refresh_rounded,
            onPressed: onRecheck,
          ),
        ],
      );
    }

    return _Blocked(
      result: result,
      serial: serial,
      line: line,
      onCheckAnother: onCheckAnother,
      onRecheck: onRecheck,
    );
  }

  /// Project units (ATS44 / Indigo) and variant units consume a different BOM,
  /// which is usually why their answer surprises someone.
  Widget? _specialPill(CanBuildResult r) {
    if (!r.isSpecial && r.specialLabel == null) return null;
    return VPill(
      label: r.specialLabel ?? 'Project unit',
      status: VStatus.info,
      icon: Icons.star_rounded,
    );
  }
}

class _Blocked extends ConsumerWidget {
  const _Blocked({
    required this.result,
    required this.serial,
    required this.line,
    required this.onCheckAnother,
    required this.onRecheck,
  });

  final CanBuildResult result;
  final String serial;
  final ProductionLine line;
  final VoidCallback onCheckAnother;
  final VoidCallback onRecheck;

  /// Worst first: the biggest shortfall is the one that takes longest to clear,
  /// so it is the one to act on. Ties break on the per-machine requirement,
  /// because a part consumed four at a time recovers more slowly than one
  /// consumed singly.
  List<BlockingPart> get _worstFirst {
    final sorted = [...result.blockingParts];
    sorted.sort((a, b) {
      final byShortfall = b.shortfallQty.compareTo(a.shortfallQty);
      if (byShortfall != 0) return byShortfall;
      return b.requiredQty.compareTo(a.requiredQty);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final parts = _worstFirst;
    final canRequest = ref.watch(canProvider(Perm.requestCreate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BigAnswer(
          status: VStatus.critical,
          icon: Icons.report_problem_rounded,
          headline: 'Machine $serial cannot be built yet',
          body: parts.length == 1
              ? 'One part is short by the time the plan reaches this machine.'
              : '${parts.length} parts are short by the time the plan reaches this machine.',
          pill: result.isSpecial || result.specialLabel != null
              ? VPill(
                  label: result.specialLabel ?? 'Project unit',
                  status: VStatus.info,
                  icon: Icons.star_rounded,
                )
              : null,
          footnotes: [
            result.machinesAhead == 0
                ? 'It is the next machine in the plan.'
                : '${result.machinesAhead} machine(s) ahead of it in the plan.',
            if (parts.isNotEmpty)
              'Worst: ${parts.first.part.unpaintedPn} — short by '
                  '${fmtQty(parts.first.shortfallQty)}.',
          ],
        ),

        const SizedBox(height: VSpace.lg),
        VSectionTitle(
          title: parts.length == 1 ? 'The blocking part' : 'Blocking parts',
          subtitle: 'Worst shortfall first',
          trailing: VButton.quiet(
            label: 'Re-check',
            icon: Icons.refresh_rounded,
            onPressed: onRecheck,
          ),
        ),

        // The single most misread number in the app. `available_at_machine` is
        // the balance the part will have WHEN THE PLAN REACHES this machine —
        // every unit queued ahead has already taken its pieces by then. Without
        // this sentence, someone walks to the rack, counts the stock that is
        // physically there, and concludes the app is wrong.
        Container(
          padding: const EdgeInsets.all(VSpace.md),
          decoration: BoxDecoration(
            color: v.infoTint,
            borderRadius: VRadius.allSm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 16, color: v.info),
              const SizedBox(width: VSpace.sm),
              Expanded(
                child: Text(
                  '"Will have" is not today\'s shelf count. It is the balance left AFTER every '
                  'machine queued ahead of $serial has taken its pieces — which is why a part '
                  'you can see on the rack right now can still stop a machine forty units out. '
                  'The shortfall is what has to arrive before then.',
                  style: context.text.bodySmall?.copyWith(color: v.txt2, height: 1.55),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSpace.md),

        LayoutBuilder(
          builder: (context, constraints) {
            // Below ~800px the five numeric columns stop fitting and start
            // truncating part numbers, which is the one thing that must stay
            // readable — so the phone/narrow layout is cards, not a squeezed
            // table.
            if (constraints.maxWidth < 800) {
              return Column(
                children: [
                  for (final part in parts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: VSpace.sm),
                      child: _BlockingCard(
                        blocking: part,
                        onCoverage: () => _openCoverage(context, ref, part),
                      ),
                    ),
                ],
              );
            }
            return _BlockingTable(
              parts: parts,
              onCoverage: (part) => _openCoverage(context, ref, part),
            );
          },
        ),

        const SizedBox(height: VSpace.lg),
        VCard(
          padding: const EdgeInsets.all(VSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const VSectionTitle(
                title: 'What now',
                subtitle: 'Acting on the worst part first',
              ),
              Wrap(
                spacing: VSpace.sm,
                runSpacing: VSpace.sm,
                children: [
                  if (canRequest && parts.isNotEmpty)
                    VButton(
                      label: 'Raise SPD request',
                      icon: Icons.note_add_rounded,
                      onPressed: () => _raiseRequest(context, parts.first),
                    ),
                  if (parts.isNotEmpty)
                    VButton.ghost(
                      label: 'Coverage for ${parts.first.part.unpaintedPn}',
                      icon: Icons.query_stats_rounded,
                      onPressed: () => _openCoverage(context, ref, parts.first),
                    ),
                  VButton.ghost(
                    label: 'Open the matrix',
                    icon: Icons.grid_on_rounded,
                    onPressed: () => context.go(Routes.matrix),
                  ),
                  VButton.ghost(
                    label: 'Check another',
                    icon: Icons.restart_alt_rounded,
                    onPressed: onCheckAnother,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The coverage list, pre-filtered to this part. Reuses the shared filter
  /// notifier rather than a query parameter so the two screens cannot disagree
  /// about what "filtered" means.
  void _openCoverage(BuildContext context, WidgetRef ref, BlockingPart part) {
    ref.read(coverageFiltersProvider.notifier)
      ..setLevel('all')
      ..setSearch(part.part.unpaintedPn);
    context.go(Routes.coverage);
  }

  /// Hands the shortfall to the Requests screen with the part and quantity
  /// pre-filled. The request itself is raised there — that screen owns the
  /// spd_issue / special_load distinction and the approval copy, and duplicating
  /// the form here is how the two would drift apart. `part`/`qty` are a hint it
  /// can honour; the navigation is correct either way.
  void _raiseRequest(BuildContext context, BlockingPart worst) {
    final qty = worst.shortfallQty.ceil();
    context.go('${Routes.requests}?part=${Uri.encodeComponent(worst.part.id)}&qty=$qty');
  }
}

// ---------------------------------------------------------------------------
// Blocking parts, two layouts
// ---------------------------------------------------------------------------

class _BlockingTable extends StatelessWidget {
  const _BlockingTable({required this.parts, required this.onCoverage});

  final List<BlockingPart> parts;
  final ValueChanged<BlockingPart> onCoverage;

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    return VTableShell(
      header: const VTableHeader(
        columns: [
          VColumn(label: 'Part', flex: 4),
          VColumn(label: 'Rack', width: 96),
          VColumn(
            label: 'Needs',
            width: 84,
            align: TextAlign.right,
            tooltip: 'Pieces this machine consumes',
          ),
          VColumn(
            label: 'Will have',
            width: 108,
            align: TextAlign.right,
            tooltip: 'Balance when the plan reaches this machine — not today\'s shelf count',
          ),
          VColumn(
            label: 'Short by',
            width: 100,
            align: TextAlign.right,
            tooltip: 'Pieces that must arrive before this machine',
          ),
          VColumn(label: '', width: 30),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < parts.length; i++)
            VTableRow(
              last: i == parts.length - 1,
              accentEdge: v.bad,
              onTap: () => onCoverage(parts[i]),
              children: [
                VWidgetCell(flex: 4, child: PartIdentity(part: parts[i].part, dense: true)),
                VCell(text: parts[i].part.rackCode ?? '—', width: 96),
                VCell(
                  text: '${parts[i].requiredQty}',
                  width: 84,
                  align: TextAlign.right,
                  numeric: true,
                  color: v.txt,
                ),
                VCell(
                  text: fmtQty(parts[i].availableAtMachine),
                  width: 108,
                  align: TextAlign.right,
                  numeric: true,
                  // Zero or negative is the whole story: the pieces are gone
                  // before this machine gets to them.
                  color: parts[i].availableAtMachine <= 0 ? v.bad : v.txt2,
                ),
                VCell(
                  text: '−${fmtQty(parts[i].shortfallQty)}',
                  width: 100,
                  align: TextAlign.right,
                  numeric: true,
                  bold: true,
                  color: v.bad,
                ),
                VWidgetCell(
                  width: 30,
                  align: Alignment.centerRight,
                  child: Icon(Icons.chevron_right_rounded, size: 18, color: v.txt3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BlockingCard extends StatelessWidget {
  const _BlockingCard({required this.blocking, required this.onCoverage});

  final BlockingPart blocking;
  final VoidCallback onCoverage;

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    return VCard(
      onTap: onCoverage,
      glow: true,
      accentEdge: v.bad,
      padding: const EdgeInsets.fromLTRB(VSpace.lg, VSpace.md, VSpace.md, VSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: PartIdentity(part: blocking.part)),
              const SizedBox(width: VSpace.sm),
              VPill(
                label: 'Short ${fmtQty(blocking.shortfallQty)}',
                status: VStatus.critical,
                showDot: false,
              ),
            ],
          ),
          const SizedBox(height: VSpace.md),
          Wrap(
            spacing: VSpace.xl,
            runSpacing: VSpace.sm,
            children: [
              _Figure(label: 'Needs', value: '${blocking.requiredQty}'),
              _Figure(
                label: 'Will have',
                value: fmtQty(blocking.availableAtMachine),
                color: blocking.availableAtMachine <= 0 ? v.bad : null,
                tooltip: 'The balance when the plan reaches this machine, not today\'s count.',
              ),
              _Figure(
                label: 'Short by',
                value: fmtQty(blocking.shortfallQty),
                color: v.bad,
                emphasise: true,
              ),
              if (blocking.part.rackCode != null)
                _Figure(label: 'Rack', value: blocking.part.rackCode!),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.color,
    this.tooltip,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final Color? color;
  final String? tooltip;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final content = Column(
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
          style: (emphasise ? context.text.titleMedium : context.text.titleSmall)?.copyWith(
            color: color ?? v.txt,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
    return tooltip == null ? content : Tooltip(message: tooltip!, child: content);
  }
}

// ---------------------------------------------------------------------------
// The answer card, and its loading stand-in
// ---------------------------------------------------------------------------

/// The unmissable part. Deliberately oversized: this is read across a bay, often
/// by someone who is already holding a torque wrench.
class _BigAnswer extends StatelessWidget {
  const _BigAnswer({
    required this.status,
    required this.icon,
    required this.headline,
    required this.body,
    this.pill,
    this.footnotes = const [],
    this.actions = const [],
  });

  final VStatus status;
  final IconData icon;
  final String headline;
  final String body;
  final Widget? pill;
  final List<String> footnotes;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final fg = v.forStatus(status);
    final compact = MediaQuery.sizeOf(context).width < VBreak.phone;
    final iconBox = compact ? 54.0 : 70.0;

    return VCard(
      padding: EdgeInsets.all(compact ? VSpace.lg : VSpace.xl),
      accentEdge: fg,
      borderColor: fg.withValues(alpha: 0.35),
      // Blended to an OPAQUE tint rather than laid over the card as a
      // translucent wash: this card sits on the ambient page gradient, and a
      // see-through fill would let the background decide how green "green" reads.
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.alphaBlend(v.tintFor(status), v.surface), v.surface],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: iconBox,
                height: iconBox,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(compact ? 16 : 20),
                ),
                child: Icon(icon, size: compact ? 28 : 36, color: fg),
              ),
              SizedBox(width: compact ? VSpace.md : VSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pill != null) ...[
                      pill!,
                      const SizedBox(height: VSpace.xs),
                    ],
                    Text(
                      headline,
                      style: (compact ? context.text.titleLarge : context.text.headlineSmall)
                          ?.copyWith(color: v.txt, height: 1.15),
                    ),
                    const SizedBox(height: VSpace.xs),
                    Text(
                      body,
                      style: context.text.bodyMedium?.copyWith(color: v.txt2, height: 1.55),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (footnotes.isNotEmpty) ...[
            const SizedBox(height: VSpace.md),
            for (final note in footnotes)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: VSpace.sm),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                    ),
                    Expanded(
                      child: Text(
                        note,
                        style: context.text.bodySmall?.copyWith(
                          color: v.txt2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: VSpace.lg),
            Wrap(spacing: VSpace.sm, runSpacing: VSpace.sm, children: actions),
          ],
        ],
      ),
    );
  }
}

/// Mirrors the answer card's geometry so the layout does not jump when the real
/// answer lands — on a slow plant connection that jump is the difference between
/// reading the answer and re-reading the screen.
class _AnswerSkeleton extends StatelessWidget {
  const _AnswerSkeleton();

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final compact = MediaQuery.sizeOf(context).width < VBreak.phone;

    return VShimmerScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? VSpace.lg : VSpace.xl),
            decoration: BoxDecoration(
              color: v.surface,
              borderRadius: VRadius.allMd,
              border: Border.all(color: v.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VSkeleton(width: compact ? 54 : 70, height: compact ? 54 : 70, radius: 20),
                SizedBox(width: compact ? VSpace.md : VSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const VSkeleton(height: 26, radius: 8),
                      const SizedBox(height: VSpace.sm),
                      const VSkeleton.text(width: 260),
                      const SizedBox(height: VSpace.xs),
                      const VSkeleton.text(width: 180, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.lg),
          const VSkeletonList(rows: 3, height: 64),
        ],
      ),
    );
  }
}
