import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../common/common_widgets.dart';
import 'pallet_photo_field.dart';
import '../common/pattern_photo.dart';
import 'pattern_sheet_card.dart';

/// How the operator is booking: a whole pattern sheet, or one part.
enum _EntryMode { sheet, single }

/// Defaults to the sheet because that is what the plant actually runs — a frame
/// is loaded and unloaded whole, and the paper the operator already holds is a
/// pattern sheet. The single-part form stays one tap away for a correction, an
/// odd piece, or a part that belongs to no frame.
///
/// A provider rather than widget state so the choice survives the register
/// reloading underneath it.
final _entryModeProvider = StateProvider<_EntryMode>((ref) => _EntryMode.sheet);

class _EntryModeSwitch extends ConsumerWidget {
  const _EntryModeSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(_entryModeProvider);
    void select(_EntryMode next) => ref.read(_entryModeProvider.notifier).state = next;

    return Wrap(
      spacing: VSpace.xs,
      runSpacing: VSpace.xs,
      children: [
        VChip(
          label: 'Pattern sheet',
          icon: Icons.grid_view_rounded,
          selected: mode == _EntryMode.sheet,
          onTap: () => select(_EntryMode.sheet),
        ),
        VChip(
          label: 'Single part',
          icon: Icons.add_box_rounded,
          selected: mode == _EntryMode.single,
          onTap: () => select(_EntryMode.single),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Daily Nesting — the receipt an operator records when painted pieces come off
/// a frame. This is where every positive stock movement in the app is born.
///
/// Two rules shape the whole screen:
///
///   1. THE SAVE NEVER TOUCHES THE NETWORK. Everything goes through the outbox
///      (see SyncService) and is confirmed immediately. Whether it has reached
///      the server yet is a separate, visible concern — the pending badge and
///      the queue screen — and never something the operator has to wait for
///      with a frame in their hands.
///
///   2. GLOVE-SIZED TARGETS. Large fields and large buttons throughout; the
///      quantity field is numeric-only and autofocused, because the number is
///      the only thing that changes between one save and the next.
///
/// The register underneath is the proof: what was entered today, by whom, and
/// at what time. A wrong entry is corrected with an offsetting row, never a
/// delete — the SRS's complaint about Excel was that nobody could tell who had
/// changed a number.
/// ---------------------------------------------------------------------------
class NestingScreen extends ConsumerWidget {
  const NestingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(nestingRegisterDateProvider);
    final async = ref.watch(nestingRegisterProvider);
    final canEnter = ref.watch(canProvider(Perm.nestingCreate));

    return LineRequired(
      builder: (context, line) => AsyncBody<({List<NestingEntry> rows, int total, Map<String, dynamic> totals})>(
        value: async,
        onRefresh: () async => ref.invalidate(nestingRegisterProvider),
        builder: (context, data) => VPageBody(
          children: [
            VPageHeader(
              breadcrumb: const ['Shop floor', 'Daily Nesting'],
              title: 'Daily nesting',
              accentWord: 'nesting',
              description: '${line.name} · pieces received off the paint line. Saved on this '
                  'device first, then uploaded — so a dead link never costs you an entry.',
              actions: [
                _DateButton(date: date),
                VButton.ghost(
                  label: 'Refresh',
                  icon: Icons.refresh_rounded,
                  size: VButtonSize.small,
                  onPressed: () => ref.invalidate(nestingRegisterProvider),
                ),
              ],
            ),

            if (canEnter) ...[
              const _EntryModeSwitch(),
              const SizedBox(height: VSpace.md),
              if (ref.watch(_entryModeProvider) == _EntryMode.sheet)
                PatternSheetCard(line: line)
              else
                _EntryCard(line: line),
              const SizedBox(height: VSpace.xl),
            ],

            VSectionTitle(
              title: 'Register for ${fmtDate(date)}',
              subtitle: '${data.total} ${data.total == 1 ? 'entry' : 'entries'} · '
                  '${fmtQty(_totalQty(data.totals, data.rows))} pieces received.',
            ),

            if (data.rows.isEmpty)
              const VEmptyState(
                title: 'Nothing recorded yet',
                message: 'The first receipt of the shift goes in above. Entries appear here '
                    'the moment they are saved, whether or not the network is up.',
                icon: Icons.move_to_inbox_rounded,
                compact: true,
              )
            else
              for (final entry in data.rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: VSpace.sm),
                  child: _RegisterRow(entry: entry),
                ),
          ],
        ),
      ),
    );
  }

  /// The server sends a totals block; falling back to summing the page keeps the
  /// header honest on an older build rather than showing a bare zero.
  static double _totalQty(Map<String, dynamic> totals, List<NestingEntry> rows) {
    final quantity = totals['quantity'];
    if (quantity is num) return quantity.toDouble();
    return rows.fold<double>(0, (sum, entry) => sum + entry.quantity);
  }
}

class _DateButton extends ConsumerWidget {
  const _DateButton({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateUtils.dateOnly(DateTime.now());
    final isToday = DateUtils.isSameDay(date, today);

    return VButton.ghost(
      label: isToday ? 'Today' : fmtDate(date),
      icon: Icons.calendar_today_rounded,
      size: VButtonSize.small,
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: today.subtract(const Duration(days: 365)),
          // No future register: a receipt cannot be recorded before it happens.
          lastDate: today,
        );
        if (picked == null) return;
        ref.read(nestingRegisterDateProvider.notifier).state = picked;
      },
    );
  }
}

// ===========================================================================
// Entry
// ===========================================================================

class _EntryCard extends ConsumerStatefulWidget {
  const _EntryCard({required this.line});

  final ProductionLine line;

  @override
  ConsumerState<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends ConsumerState<_EntryCard> {
  final _quantityController = TextEditingController();
  final _frameController = TextEditingController();
  final _quantityFocus = FocusNode();

  Part? _part;
  PalletPhoto? _photo;
  Pattern? _pattern;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _quantityController.dispose();
    _frameController.dispose();
    _quantityFocus.dispose();
    super.dispose();
  }

  Future<void> _pickPart() async {
    final chosen = await showModalBottomSheet<Part>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.v.bg2,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (sheetContext) => const PartPickerSheet(),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _part = chosen;
      _error = null;
    });
    _quantityFocus.requestFocus();
  }

  Future<void> _save() async {
    final part = _part;
    if (part == null) {
      setState(() => _error = 'Pick the part that came off the frame.');
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Enter how many pieces were received.');
      return;
    }

    // A special pattern that has not been approved will be refused server-side.
    // Saying so here means the operator finds out now rather than when the queue
    // comes back with a conflict hours later.
    if (_pattern != null && _pattern!.awaitingApproval) {
      setState(() => _error =
          '${_pattern!.code} is a special pattern still waiting for the Planner. '
          'It cannot be loaded yet.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Queued BEFORE the entry so the bytes are on disk the moment the entry
      // that references them exists. Both are keyed by uuid, so the upload
      // order does not matter — only that neither can be lost.
      final photo = _photo;
      if (photo != null) {
        await ref.read(syncServiceProvider).queuePhoto(
              clientUuid: photo.clientUuid,
              bytes: photo.bytes,
              mimeType: photo.mimeType,
              capturedAt: photo.capturedAt,
              lineId: widget.line.id,
              patternId: _pattern?.id,
              nestingFrameNo: _frameController.text.trim(),
            );
      }

      await ref.read(syncServiceProvider).queueNesting(
            partId: part.id,
            quantity: quantity,
            summary: '${part.unpaintedPn} ×$quantity',
            lineId: widget.line.id,
            patternId: _pattern?.id,
            nestingFrameNo: _frameController.text.trim(),
            photoClientUuid: photo?.clientUuid,
            shade: _pattern?.shade ?? part.colorShade,
            plannedSurface: _pattern?.plannedSurface,
            userId: ref.read(currentUserProvider)?.id,
          );

      if (!mounted) return;
      VToast.success(
        context,
        'Saved · ${part.unpaintedPn} ×$quantity',
        detail: 'Recorded on this device. It uploads on its own.',
      );

      // Keep the pattern and the frame number: an operator books a whole frame
      // part by part, and re-picking the pattern every time is the difference
      // between four taps a row and one.
      setState(() {
        _part = null;
        _quantityController.clear();
        // The pattern and frame number persist across saves; the photo does
        // not. It is evidence of one pallet, and silently reattaching it to the
        // next one would be a lie.
        _photo = null;
      });
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
    final patterns = ref.watch(patternsProvider).valueOrNull ?? const <Pattern>[];

    return VCard(
      cornerMark: true,
      padding: const EdgeInsets.all(VSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VSectionTitle(
            title: 'Record a receipt',
            subtitle: 'Part and quantity are all that is required.',
          ),

          _PartSlot(part: _part, onPick: _pickPart, onClear: () => setState(() => _part = null)),
          const SizedBox(height: VSpace.md),

          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 620;
              final quantityField = VInput(
                controller: _quantityController,
                focusNode: _quantityFocus,
                label: 'Pieces received',
                hint: '0',
                large: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              );
              final frameField = VInput(
                controller: _frameController,
                label: 'Frame number',
                hint: 'Optional',
                large: true,
                textCapitalization: TextCapitalization.characters,
              );

              if (stacked) {
                return Column(
                  children: [
                    quantityField,
                    const SizedBox(height: VSpace.md),
                    frameField,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: quantityField),
                  const SizedBox(width: VSpace.md),
                  Expanded(child: frameField),
                ],
              );
            },
          ),

          if (patterns.isNotEmpty) ...[
            const SizedBox(height: VSpace.md),
            VDropdown<Pattern>(
              label: 'Pattern (optional)',
              hint: 'Not tied to a pattern',
              large: true,
              value: _pattern,
              items: patterns,
              itemLabel: (pattern) => pattern.awaitingApproval
                  ? '${pattern.code} · awaiting approval'
                  : pattern.code,
              onChanged: (next) => setState(() => _pattern = next),
              prefixIcon: Icons.view_module_rounded,
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
          ],

          const SizedBox(height: VSpace.md),
          PalletPhotoField(
            photo: _photo,
            enabled: !_saving,
            onChanged: (next) => setState(() => _photo = next),
          ),

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
            label: 'Save receipt',
            icon: Icons.check_rounded,
            size: VButtonSize.large,
            expand: true,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _PartSlot extends StatelessWidget {
  const _PartSlot({required this.part, required this.onPick, required this.onClear});

  final Part? part;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    if (part == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: VSpace.md, vertical: VSpace.lg),
          decoration: BoxDecoration(
            color: v.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: v.line),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 22, color: v.txt3),
              const SizedBox(width: VSpace.sm),
              Expanded(
                child: Text(
                  'Choose the part',
                  style: context.text.bodyLarge?.copyWith(color: v.txt3, fontSize: 17),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 22, color: v.txt3),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSpace.md),
      decoration: BoxDecoration(
        color: v.accentTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: PartIdentity(part: part!)),
          VIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Choose a different part',
            filled: false,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

/// A search-and-pick sheet, returning the chosen [Part] via `Navigator.pop`.
///
/// Public so the runs and requests screens use the same picker — an operator
/// should not have to learn two ways of finding a part.
class PartPickerSheet extends ConsumerStatefulWidget {
  const PartPickerSheet({super.key});

  @override
  ConsumerState<PartPickerSheet> createState() => _PartPickerSheetState();
}

class _PartPickerSheetState extends ConsumerState<PartPickerSheet> {
  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  List<Part> _results = const [];
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () => _run(value));
  }

  Future<void> _run(String value) async {
    final query = value.trim();
    setState(() {
      _query = query;
      _error = null;
    });

    if (query.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    try {
      final rows = await ref.read(masterRepositoryProvider).searchParts(query, limit: 30);
      if (!mounted) return;
      setState(() => _results = rows);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const VSectionTitle(title: 'Which part?'),
          VSearchField(
            hint: 'Part number or description',
            autofocus: true,
            large: true,
            onChanged: _onChanged,
          ),
          const SizedBox(height: VSpace.md),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
            child: _body(context, v),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, VColors v) {
    if (_error != null) {
      return VErrorState(message: _error!, compact: true, onRetry: () => _run(_query));
    }
    if (_searching) {
      return const VSkeletonList(rows: 3, height: 54);
    }
    if (_query.length < 2) {
      return const VEmptyState(
        title: 'Start typing',
        message: 'Two characters is enough to search.',
        icon: Icons.search_rounded,
        compact: true,
      );
    }
    if (_results.isEmpty) {
      return VEmptyState(
        title: 'Nothing matches “$_query”',
        message: 'A part that has not been imported cannot be received against.',
        icon: Icons.search_off_rounded,
        compact: true,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _results.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: v.line),
      itemBuilder: (context, index) {
        final part = _results[index];
        return InkWell(
          onTap: () => Navigator.pop(context, part),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: VSpace.sm),
            child: Row(
              children: [
                Expanded(child: PartIdentity(part: part, dense: true)),
                Text(
                  fmtQty(part.availableStock),
                  style: context.text.titleSmall?.copyWith(
                    fontSize: 13,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: VSpace.xs),
                Icon(Icons.chevron_right_rounded, size: 18, color: v.txt3),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ===========================================================================
// Register
// ===========================================================================

class _RegisterRow extends ConsumerWidget {
  const _RegisterRow({required this.entry});

  final NestingEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final canReverse = ref.watch(canProvider(Perm.stockAdjust));

    return VCard(
      padding: const EdgeInsets.fromLTRB(VSpace.lg, VSpace.md, VSpace.md, VSpace.md),
      accentEdge: entry.isShort ? v.warn : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.part != null)
                  PartIdentity(part: entry.part!, dense: true)
                else
                  Text(entry.partId, style: context.text.titleSmall?.copyWith(fontSize: 13)),
                const SizedBox(height: VSpace.xs),
                Wrap(
                  spacing: VSpace.sm,
                  runSpacing: 2,
                  children: [
                    _Tag(icon: Icons.schedule_rounded, text: fmtTime(entry.entryTime)),
                    if (entry.patternCode != null)
                      _Tag(icon: Icons.view_module_rounded, text: entry.patternCode!),
                    if (entry.nestingFrameNo != null && entry.nestingFrameNo!.isNotEmpty)
                      _Tag(icon: Icons.crop_square_rounded, text: 'Frame ${entry.nestingFrameNo}'),
                    if (entry.enteredByName != null)
                      _Tag(icon: Icons.person_rounded, text: entry.enteredByName!),
                  ],
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
                '+${fmtQty(entry.quantity)}',
                style: context.text.titleMedium?.copyWith(
                  color: v.ok,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (entry.isShort)
                Text(
                  'of ${entry.requiredQty} planned',
                  style: context.text.labelSmall?.copyWith(color: v.warn, fontSize: 10),
                ),
              if (canReverse)
                VButton.quiet(
                  label: 'Correct',
                  onPressed: () => _reverse(context, ref),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reverse(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.v.surface,
        title: const Text('Correct this entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This writes an offsetting row. The original stays in the register, with '
              'who entered it — that is what makes the number provable.',
              style: dialogContext.text.bodySmall?.copyWith(color: dialogContext.v.txt3),
            ),
            const SizedBox(height: VSpace.md),
            VInput(
              controller: controller,
              label: 'Why',
              hint: 'Miscount, wrong part, …',
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Post correction'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (note == null || note.isEmpty) return;

    try {
      await ref.read(nestingRepositoryProvider).reverse(entry.id, note: note);
      if (!context.mounted) return;
      VToast.success(context, 'Correction posted');
      ref.invalidate(nestingRegisterProvider);
    } catch (error) {
      if (!context.mounted) return;
      VToast.error(context, describeError(error));
    }
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});

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
        Text(text, style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 10.5)),
      ],
    );
  }
}
