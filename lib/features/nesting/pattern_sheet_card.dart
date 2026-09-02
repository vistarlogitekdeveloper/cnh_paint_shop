import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import 'pallet_photo_field.dart';
import '../common/common_widgets.dart';
import '../common/pattern_photo.dart';

/// ---------------------------------------------------------------------------
/// Pattern sheet entry — the paper form, on a screen.
///
/// The plant's nesting patterns are issued as controlled documents (ID10Cab-01,
/// RB-01, RTR-01 …): a header the operator fills by hand — Date, Nesting Person,
/// PF No — and then a numbered list of positions, each a part with an expected
/// "Pattern Qty". An operator loads a whole frame and books a whole frame.
///
/// Entering that one part at a time is the thing this replaces. The single-part
/// form still exists, for a correction or an odd piece; this is for the frame
/// the operator just ran.
///
/// Three decisions worth stating:
///
///   1. THE QUANTITIES ARE PRE-FILLED with the sheet's own Pattern Qty. A full
///      frame is the normal case, so the normal case is zero typing — the
///      operator checks the numbers and saves. A short frame is edited down.
///
///   2. A BLANK ROW IS NOT AN ERROR, it is a position that did not run. Only
///      rows carrying a quantity are saved, so a partly-loaded frame books
///      cleanly without anyone having to type zeros.
///
///   3. EVERY ROW OF ONE SAVE SHARES A `pattern_txn_id`. That is what makes the
///      sheet provable afterwards: these fourteen receipts were one frame, not
///      fourteen unrelated entries that happen to share a timestamp.
///
/// Like every other write in this app the save goes to the outbox first and is
/// confirmed immediately — one queued row per position, each with its own
/// `client_uuid`, so a replay after a dead link cannot double-count a frame.
/// ---------------------------------------------------------------------------
class PatternSheetCard extends ConsumerStatefulWidget {
  const PatternSheetCard({super.key, required this.line});

  final ProductionLine line;

  @override
  ConsumerState<PatternSheetCard> createState() => _PatternSheetCardState();
}

class _PatternSheetCardState extends ConsumerState<PatternSheetCard> {
  final _pfController = TextEditingController();
  final _machineController = TextEditingController();
  Pattern? _pattern;

  @override
  void dispose() {
    _pfController.dispose();
    _machineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patterns = (ref.watch(patternsProvider).valueOrNull ?? const <Pattern>[])
        .where((pattern) => pattern.isActive)
        .toList();

    return VCard(
      cornerMark: true,
      padding: const EdgeInsets.all(VSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VSectionTitle(
            title: 'Book a whole frame',
            subtitle: 'The pattern sheet as it is issued to the shop floor. Quantities '
                'start at the sheet’s own Pattern Qty — check them and save.',
          ),

          if (patterns.isEmpty)
            const VEmptyState(
              title: 'No patterns on this line',
              message: 'A Planner sets frames up under Patterns. Until then, the '
                  'single-part form above records a receipt.',
              icon: Icons.view_module_rounded,
            )
          else ...[
            VDropdown<Pattern>(
              label: 'Pattern',
              hint: 'Choose the frame that was run',
              large: true,
              value: _pattern,
              items: patterns,
              itemLabel: (pattern) => pattern.awaitingApproval
                  ? '${pattern.code} · awaiting approval'
                  : pattern.code,
              prefixIcon: Icons.view_module_rounded,
              onChanged: (next) => setState(() => _pattern = next),
            ),
            if (_pattern != null) ...[
              const SizedBox(height: VSpace.lg),
              _PatternPositions(
                pattern: _pattern!,
                line: widget.line,
                pfController: _pfController,
                machineController: _machineController,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Loads the chosen pattern's positions, then hands them to [_Sheet].
///
/// Split from the sheet itself so the quantity controllers can be built once,
/// in `initState`, against a list that is already known — rather than being
/// reconciled inside a build against an async value.
class _PatternPositions extends ConsumerWidget {
  const _PatternPositions({
    required this.pattern,
    required this.line,
    required this.pfController,
    required this.machineController,
  });

  final Pattern pattern;
  final ProductionLine line;
  final TextEditingController pfController;
  final TextEditingController machineController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(patternDetailProvider(pattern.id));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: VSpace.xl),
        child: Center(child: VSpinner()),
      ),
      error: (error, _) => VErrorState(
        message: describeError(error),
        onRetry: () => ref.invalidate(patternDetailProvider(pattern.id)),
      ),
      data: (detail) {
        final items = [...detail.items]
          ..sort((a, b) => (a.seqNo ?? 1 << 30).compareTo(b.seqNo ?? 1 << 30));

        if (items.isEmpty) {
          return VEmptyState(
            title: '${pattern.code} has no positions yet',
            message: 'A Planner adds the parts that hang on this frame under Patterns.',
            icon: Icons.grid_off_rounded,
          );
        }

        return _Sheet(
          // Re-key on the pattern so switching frames rebuilds the quantity
          // fields rather than carrying the last frame's numbers across.
          key: ValueKey(pattern.id),
          pattern: pattern,
          line: line,
          items: items,
          pfController: pfController,
          machineController: machineController,
        );
      },
    );
  }
}

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({
    super.key,
    required this.pattern,
    required this.line,
    required this.items,
    required this.pfController,
    required this.machineController,
  });

  final Pattern pattern;
  final ProductionLine line;
  final List<PatternItem> items;
  final TextEditingController pfController;
  final TextEditingController machineController;

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  static const _uuid = Uuid();

  late List<TextEditingController> _qty;
  PalletPhoto? _photo;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-filled from the sheet's own Pattern Qty, which is why the expected
    // number stays on screen in its own column: the operator is confirming a
    // figure, not trusting one silently.
    //
    // This leans on qty_per_frame being real. It is, for every sheet that has a
    // "Pattern Qty" column — ID-10, Round, Baler, Carraro. The Rotavator decks
    // do NOT have one (their only quantity column is Qty/Mc, which is QPV), so
    // an importer that maps those decks must not let qty_per_frame fall back to
    // 1 — the deck says 2 or 4 at several positions, and a defaulted 1 would be
    // confirmed by an operator who had no way to know it was a guess.
    _qty = [
      for (final item in widget.items) TextEditingController(text: '${item.qtyPerFrame}'),
    ];
  }

  @override
  void dispose() {
    for (final controller in _qty) {
      controller.dispose();
    }
    super.dispose();
  }

  int _quantityAt(int index) {
    final raw = _qty[index].text.trim();
    if (raw.isEmpty) return 0;
    return int.tryParse(raw) ?? 0;
  }

  void _setAll({required bool full}) {
    setState(() {
      for (var i = 0; i < _qty.length; i++) {
        _qty[i].text = full ? '${widget.items[i].qtyPerFrame}' : '';
      }
    });
  }

  Future<void> _save() async {
    final pattern = widget.pattern;

    // Refused server-side anyway; saying so here means the operator finds out
    // with the frame in front of them, not hours later from the queue.
    if (pattern.awaitingApproval) {
      setState(() => _error = '${pattern.code} is a special pattern still waiting for '
          'the Planner. It cannot be loaded yet.');
      return;
    }

    final filled = <int>[
      for (var i = 0; i < widget.items.length; i++)
        if (_quantityAt(i) > 0) i,
    ];
    if (filled.isEmpty) {
      setState(() => _error = 'Enter a quantity against at least one position.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    // One id for the whole sheet: these receipts were one frame.
    final sheetId = _uuid.v4();
    final pfNo = widget.pfController.text.trim();
    final machineNo = widget.machineController.text.trim();
    final userId = ref.read(currentUserProvider)?.id;
    var pieces = 0;

    try {
      // One photo for the whole sheet: every position on it came off the same
      // pallet, so they all reference the same capture.
      final photo = _photo;
      if (photo != null) {
        await ref.read(syncServiceProvider).queuePhoto(
              clientUuid: photo.clientUuid,
              bytes: photo.bytes,
              mimeType: photo.mimeType,
              capturedAt: photo.capturedAt,
              lineId: widget.line.id,
              patternId: pattern.id,
              nestingFrameNo: pfNo,
            );
      }

      for (final index in filled) {
        final item = widget.items[index];
        final quantity = _quantityAt(index);
        pieces += quantity;
        await ref.read(syncServiceProvider).queueNesting(
              partId: item.partId,
              quantity: quantity,
              summary: '${pattern.code} #${item.seqNo ?? '-'} · '
                  '${item.part?.unpaintedPn ?? item.partId} ×$quantity',
              lineId: widget.line.id,
              patternId: pattern.id,
              nestingFrameNo: pfNo,
              machineNo: machineNo,
              photoClientUuid: photo?.clientUuid,
              patternTxnId: sheetId,
              requiredQty: item.qtyPerFrame,
              shade: pattern.shade ?? item.part?.colorShade,
              plannedSurface: pattern.plannedSurface,
              userId: userId,
            );
      }

      if (!mounted) return;
      VToast.success(
        context,
        '${pattern.code} saved · ${filled.length} '
        '${filled.length == 1 ? 'position' : 'positions'}, $pieces pieces',
        detail: 'Recorded on this device. It uploads on its own.',
      );

      // Back to a full frame, ready for the next one. The pattern and PF number
      // stay: an operator runs the same frame repeatedly through a shift. The
      // photo does not — it is evidence of one pallet, and carrying it to the
      // next frame would attach a picture to receipts it never covered.
      _setAll(full: true);
      if (mounted) setState(() => _photo = null);
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
    final items = widget.items;

    var filled = 0;
    var pieces = 0;
    for (var i = 0; i < items.length; i++) {
      final quantity = _quantityAt(i);
      if (quantity > 0) filled++;
      pieces += quantity;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetHeader(
          pattern: widget.pattern,
          pfController: widget.pfController,
          machineController: widget.machineController,
          positions: items.length,
        ),
        if (patternPhotoAsset(widget.pattern.code) != null) ...[
          const SizedBox(height: VSpace.md),
          PatternPhoto(
            pattern: widget.pattern,
            caption: widget.pattern.shade != null && widget.pattern.shade!.isNotEmpty
                ? 'Confirm the frame · shade ${widget.pattern.shade}'
                : 'Confirm the frame against this photo',
          ),
        ],
        const SizedBox(height: VSpace.lg),

        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 640;
            return Column(
              children: [
                if (wide) const _PositionHeaderRow(),
                for (var index = 0; index < items.length; index++)
                  _PositionRow(
                    item: items[index],
                    controller: _qty[index],
                    wide: wide,
                    last: index == items.length - 1,
                    // Rebuilds the running total under the sheet. Thirteen rows
                    // of text fields is nothing to rebuild, and the controllers
                    // hold the text, so nothing is lost.
                    onChanged: () => setState(() {}),
                  ),
              ],
            );
          },
        ),

        if (_error != null) ...[
          const SizedBox(height: VSpace.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(VSpace.sm),
            decoration: BoxDecoration(color: v.badTint, borderRadius: VRadius.allSm),
            child: Text(
              _error!,
              style: context.text.bodySmall
                  ?.copyWith(color: v.bad, fontWeight: FontWeight.w600, height: 1.45),
            ),
          ),
        ],

        const SizedBox(height: VSpace.lg),
        Wrap(
          spacing: VSpace.sm,
          runSpacing: VSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '$filled of ${items.length} '
              '${items.length == 1 ? 'position' : 'positions'} · $pieces pieces',
              style: context.text.bodySmall?.copyWith(color: v.txt3),
            ),
            VButton.ghost(
              label: 'Full frame',
              icon: Icons.done_all_rounded,
              size: VButtonSize.small,
              onPressed: _saving ? null : () => _setAll(full: true),
            ),
            VButton.ghost(
              label: 'Clear',
              icon: Icons.backspace_outlined,
              size: VButtonSize.small,
              onPressed: _saving ? null : () => _setAll(full: false),
            ),
          ],
        ),

        const SizedBox(height: VSpace.lg),
        PalletPhotoField(
          photo: _photo,
          enabled: !_saving,
          onChanged: (next) => setState(() => _photo = next),
        ),

        const SizedBox(height: VSpace.md),
        VButton(
          label: _saving ? 'Saving…' : 'Save sheet',
          icon: _saving ? null : Icons.check_rounded,
          size: VButtonSize.large,
          expand: true,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

/// Date · Nesting Person · Shade · Number of parts, then PF No + Machine No —
/// the boxes at the top of the paper sheet.
class _SheetHeader extends ConsumerWidget {
  const _SheetHeader({
    required this.pattern,
    required this.pfController,
    required this.machineController,
    required this.positions,
  });

  final Pattern pattern;
  final TextEditingController pfController;
  final TextEditingController machineController;
  final int positions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final user = ref.watch(currentUserProvider);
    final date = ref.watch(nestingRegisterDateProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSpace.md),
      decoration: BoxDecoration(
        color: v.surface2,
        borderRadius: VRadius.allSm,
        border: Border.all(color: v.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: VSpace.xl,
            runSpacing: VSpace.sm,
            children: [
              _HeaderFact(label: 'Date', value: fmtDate(date)),
              _HeaderFact(label: 'Nesting person', value: user?.fullName ?? '—'),
              if (pattern.shade != null && pattern.shade!.isNotEmpty)
                _HeaderFact(label: 'Shade', value: pattern.shade!),
              _HeaderFact(label: 'Number of parts', value: '$positions'),
            ],
          ),
          const SizedBox(height: VSpace.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final pf = VInput(
                controller: pfController,
                label: 'PF No.',
                hint: 'The frame this ran on — optional',
                prefixIcon: Icons.crop_square_rounded,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
              );
              final machine = VInput(
                controller: machineController,
                label: 'Machine No.',
                hint: 'M/C No. — optional',
                prefixIcon: Icons.precision_manufacturing_rounded,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
              );

              if (constraints.maxWidth < 520) {
                return Column(
                  children: [
                    pf,
                    const SizedBox(height: VSpace.md),
                    machine,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: pf),
                  const SizedBox(width: VSpace.md),
                  Expanded(child: machine),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderFact extends StatelessWidget {
  const _HeaderFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: context.text.labelSmall
              ?.copyWith(color: v.txt3, fontSize: 9.5, letterSpacing: 1.2),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: context.text.bodyMedium?.copyWith(color: v.txt, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PositionHeaderRow extends StatelessWidget {
  const _PositionHeaderRow();

  @override
  Widget build(BuildContext context) {
    return const VTableHeader(
      columns: [
        VColumn(label: '#', width: 40),
        VColumn(label: 'Unpainted PN', flex: 3),
        VColumn(label: 'Description', flex: 4),
        VColumn(label: 'Painted PN', flex: 3),
        VColumn(label: 'Pattern qty', width: 92, align: TextAlign.right),
        VColumn(label: 'Received', width: 108, align: TextAlign.right),
      ],
    );
  }
}

/// One numbered position. Wide: a table row. Phone: a stacked card, because a
/// six-column row at 390px is unreadable through safety glasses.
class _PositionRow extends StatelessWidget {
  const _PositionRow({
    required this.item,
    required this.controller,
    required this.wide,
    required this.last,
    required this.onChanged,
  });

  final PatternItem item;
  final TextEditingController controller;
  final bool wide;
  final bool last;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final part = item.part;

    final field = VInput(
      controller: controller,
      hint: '0',
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ],
      textAlign: TextAlign.right,
      onChanged: (_) => onChanged(),
    );

    final seq = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: v.surface3, shape: BoxShape.circle),
      child: Text(
        '${item.seqNo ?? '-'}',
        style: context.text.labelSmall?.copyWith(color: v.txt2, fontWeight: FontWeight.w700),
      ),
    );

    if (!wide) {
      return Container(
        margin: const EdgeInsets.only(bottom: VSpace.sm),
        padding: const EdgeInsets.all(VSpace.md),
        decoration: BoxDecoration(
          color: v.surface,
          borderRadius: VRadius.allSm,
          border: Border.all(color: v.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                seq,
                const SizedBox(width: VSpace.sm),
                Expanded(
                  child: Text(
                    part?.unpaintedPn ?? '—',
                    style: context.text.bodyMedium?.copyWith(
                      color: v.txt,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(
                  'of ${item.qtyPerFrame}',
                  style: context.text.labelSmall?.copyWith(color: v.txt3),
                ),
              ],
            ),
            const SizedBox(height: VSpace.xs),
            Text(
              part?.description ?? '',
              style: context.text.bodySmall?.copyWith(color: v.txt2),
            ),
            if (part?.paintedPn != null && part!.paintedPn!.isNotEmpty)
              Text(
                'Painted ${part.paintedPn}',
                style: context.text.labelSmall?.copyWith(color: v.txt3),
              ),
            const SizedBox(height: VSpace.sm),
            field,
          ],
        ),
      );
    }

    return VTableRow(
      last: last,
      children: [
        SizedBox(width: 40, child: Align(alignment: Alignment.centerLeft, child: seq)),
        VCell(text: part?.unpaintedPn ?? '—', flex: 3, numeric: true, bold: true),
        VCell(text: part?.description ?? '', flex: 4, subtitle: part?.station),
        VCell(text: part?.paintedPn ?? '—', flex: 3, numeric: true),
        VCell(
          text: '${item.qtyPerFrame}',
          width: 92,
          align: TextAlign.right,
          numeric: true,
          color: v.txt3,
        ),
        SizedBox(width: 108, child: field),
      ],
    );
  }
}
