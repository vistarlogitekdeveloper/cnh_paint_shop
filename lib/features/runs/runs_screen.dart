import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../common/common_widgets.dart';
import '../common/pattern_photo.dart';

/// ---------------------------------------------------------------------------
/// Pattern Runs — "we hung pattern P and ran N frames."
///
/// One run stands in for a whole grid of receipts: the server expands it through
/// the pattern's parts list (qty-per-frame × frames) rather than asking the
/// loading operator to key ten quantities that are already known. That expansion
/// is previewed here BEFORE saving, because a wrong frame count silently
/// multiplies across every part on the pattern and is the easiest mistake on
/// this screen to make and the hardest to spot afterwards.
///
/// Whether a run also CONSUMES stock is a per-line setting
/// (`runs_drive_consumption`) — some lines book consumption from runs, others
/// from machine builds. The card says which, so nobody has to remember.
/// ---------------------------------------------------------------------------
class RunsScreen extends ConsumerWidget {
  const RunsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(nestingRegisterDateProvider);
    final async = ref.watch(patternRunsProvider);
    final canEnter = ref.watch(canProvider(Perm.runCreate));

    return LineRequired(
      builder: (context, line) => AsyncBody<List<PatternRun>>(
        value: async,
        onRefresh: () async => ref.invalidate(patternRunsProvider),
        builder: (context, runs) => VPageBody(
          children: [
            VPageHeader(
              breadcrumb: const ['Shop floor', 'Pattern Runs'],
              title: 'Pattern runs',
              accentWord: 'runs',
              description: '${line.name} · ${line.runsDriveConsumption ? 'runs on this line '
                      'drive consumption as well as receipts' : 'runs on this line record '
                      'receipts; consumption is booked when a machine is built'}.',
              actions: [
                VButton.ghost(
                  label: 'Refresh',
                  icon: Icons.refresh_rounded,
                  size: VButtonSize.small,
                  onPressed: () => ref.invalidate(patternRunsProvider),
                ),
              ],
            ),

            if (canEnter) ...[
              _RunEntryCard(line: line),
              const SizedBox(height: VSpace.xl),
            ],

            VSectionTitle(
              title: 'Runs on ${fmtDate(date)}',
              subtitle: runs.isEmpty
                  ? 'Nothing yet.'
                  : '${runs.length} ${runs.length == 1 ? 'run' : 'runs'} · '
                      '${runs.fold<int>(0, (sum, run) => sum + run.frameCount)} frames.',
            ),

            if (runs.isEmpty)
              const VEmptyState(
                title: 'No runs recorded',
                message: 'Record the first frame of the shift above. The register updates '
                    'as soon as it is saved.',
                icon: Icons.dynamic_feed_rounded,
                compact: true,
              )
            else
              for (final run in runs)
                Padding(
                  padding: const EdgeInsets.only(bottom: VSpace.sm),
                  child: _RunRow(run: run),
                ),
          ],
        ),
      ),
    );
  }
}

class _RunEntryCard extends ConsumerStatefulWidget {
  const _RunEntryCard({required this.line});

  final ProductionLine line;

  @override
  ConsumerState<_RunEntryCard> createState() => _RunEntryCardState();
}

class _RunEntryCardState extends ConsumerState<_RunEntryCard> {
  final _framesController = TextEditingController(text: '1');

  Pattern? _pattern;
  bool _saving = false;
  String? _error;

  int get _frames => int.tryParse(_framesController.text.trim()) ?? 0;

  @override
  void dispose() {
    _framesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pattern = _pattern;
    if (pattern == null) {
      setState(() => _error = 'Pick the pattern that was hung.');
      return;
    }
    if (_frames <= 0) {
      setState(() => _error = 'How many frames were run?');
      return;
    }
    if (pattern.awaitingApproval) {
      setState(() => _error = '${pattern.code} is a special pattern and the Planner has not '
          'approved it yet. The server will refuse this run.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(syncServiceProvider).queuePatternRun(
            patternId: pattern.id,
            frameCount: _frames,
            summary: '${pattern.code} × $_frames frames',
            lineId: widget.line.id,
            shade: pattern.shade,
            userId: ref.read(currentUserProvider)?.id,
          );

      if (!mounted) return;
      VToast.success(
        context,
        'Run saved · ${pattern.code} × $_frames',
        detail: 'Recorded on this device. It uploads on its own.',
      );
      setState(() => _framesController.text = '1');
      ref.invalidate(patternRunsProvider);
      ref.invalidate(nestingRegisterProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final patternsAsync = ref.watch(patternsProvider);
    final patterns = patternsAsync.valueOrNull ?? const <Pattern>[];

    return VCard(
      cornerMark: true,
      padding: const EdgeInsets.all(VSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VSectionTitle(
            title: 'Record a run',
            subtitle: 'The pattern decides which parts are produced; you supply the frames.',
          ),

          if (patternsAsync.isLoading)
            const VSkeletonList(rows: 1, height: 56)
          else if (patterns.isEmpty)
            const VEmptyState(
              title: 'No patterns on this line',
              message: 'A run needs a pattern. An admin can import the pattern master.',
              icon: Icons.view_module_rounded,
              compact: true,
            )
          else
            VDropdown<Pattern>(
              label: 'Pattern',
              hint: 'Which pattern was hung?',
              large: true,
              value: _pattern,
              items: patterns,
              itemLabel: (pattern) => pattern.awaitingApproval
                  ? '${pattern.code} · awaiting approval'
                  : pattern.code,
              prefixIcon: Icons.view_module_rounded,
              onChanged: (next) => setState(() {
                _pattern = next;
                _error = null;
              }),
            ),

          if (_pattern != null) ...[
            const SizedBox(height: VSpace.md),
            PatternPhoto(
              pattern: _pattern!,
              caption: _pattern!.shade != null && _pattern!.shade!.isNotEmpty
                  ? 'Shade · ${_pattern!.shade}'
                  : null,
            ),
          ],

          const SizedBox(height: VSpace.md),
          VInput(
            controller: _framesController,
            label: 'Frames run',
            large: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),

          if (_pattern != null && _frames > 0) ...[
            const SizedBox(height: VSpace.md),
            _RunPreview(pattern: _pattern!, frames: _frames),
          ],

          if (_error != null) ...[
            const SizedBox(height: VSpace.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(VSpace.sm),
              decoration: BoxDecoration(color: v.badTint, borderRadius: VRadius.allSm),
              child: Text(
                _error!,
                style: context.text.bodySmall?.copyWith(
                  color: v.bad,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
          ],

          const SizedBox(height: VSpace.lg),
          VButton(
            label: 'Save run',
            icon: Icons.check_rounded,
            size: VButtonSize.large,
            expand: true,
            loading: _saving,
            onPressed: _saving || patterns.isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }
}

/// What this run will actually produce. Reads the pattern's parts list and does
/// the multiplication in front of the operator.
class _RunPreview extends ConsumerWidget {
  const _RunPreview({required this.pattern, required this.frames});

  final Pattern pattern;
  final int frames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final detail = ref.watch(patternDetailProvider(pattern.id));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSpace.md),
      decoration: BoxDecoration(color: v.surface2, borderRadius: VRadius.allSm),
      child: detail.when(
        loading: () => const VSkeleton(height: 40),
        error: (error, _) => Text(
          'Could not load what this pattern produces — ${describeError(error)}',
          style: context.text.bodySmall?.copyWith(color: v.txt3),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return Text(
              'This pattern has no parts on it, so the run would produce nothing.',
              style: context.text.bodySmall?.copyWith(color: v.warn, fontWeight: FontWeight.w600),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will record',
                style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9.5),
              ),
              const SizedBox(height: VSpace.xs),
              Wrap(
                spacing: VSpace.sm,
                runSpacing: VSpace.xs,
                children: [
                  for (final item in data.items)
                    VPill(
                      label: '${item.part?.unpaintedPn ?? item.partId} '
                          '+${item.qtyPerFrame * frames}',
                      status: VStatus.ready,
                      showDot: false,
                      compact: true,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.run});

  final PatternRun run;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return VCard(
      padding: const EdgeInsets.fromLTRB(VSpace.lg, VSpace.md, VSpace.md, VSpace.md),
      accentEdge: run.isNonStandard ? v.warn : null,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: v.accentTint, borderRadius: BorderRadius.circular(11)),
            child: Icon(Icons.dynamic_feed_rounded, size: 18, color: v.accent),
          ),
          const SizedBox(width: VSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  run.patternCode ?? run.patternId,
                  style: context.text.titleSmall?.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${fmtTime(run.runTime)}'
                  '${run.shade != null ? ' · ${run.shade}' : ''}'
                  '${run.enteredByName != null ? ' · ${run.enteredByName}' : ''}',
                  style: context.text.bodySmall?.copyWith(color: v.txt3, fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: VSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${run.frameCount}',
                style: context.text.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                run.frameCount == 1 ? 'frame' : 'frames',
                style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

