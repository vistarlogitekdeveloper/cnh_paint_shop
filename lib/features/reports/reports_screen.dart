import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../design/design.dart';
import '../../providers/providers.dart';
import '../../router/app_router.dart';
import '../common/common_widgets.dart';
import 'report_delivery.dart';

/// ---------------------------------------------------------------------------
/// Reports — "all of today's reports; view on screen or export the familiar
/// Excel", one tap, shareable on WhatsApp or e-mail.
///
/// The catalogue is SERVER-DRIVEN (`GET /reports`). Each entry carries its own
/// title, description, supported formats and whether it needs a line, so adding
/// a report to the backend needs no client release — which matters for a plant
/// that will ask for a new sheet layout eventually.
///
/// Column layouts on the backend are copied from the real trackers, in the real
/// order, so what comes out lands on the same eyes that read the sheet today.
/// ---------------------------------------------------------------------------
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  /// Which report is currently exporting, keyed `type|format` so the two format
  /// buttons on one card show their busy state independently.
  final Set<String> _busy = {};

  /// Download progress per busy key, for the large machine-wise exports.
  final Map<String, double> _progress = {};

  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(reportCatalogueProvider);
    final line = ref.watch(selectedLineProvider);

    return AsyncBody<List<ReportDefinition>>(
      value: async,
      onRefresh: () async => ref.invalidate(reportCatalogueProvider),
      isEmpty: (rows) => rows.isEmpty,
      emptyTitle: 'No reports available',
      emptyMessage: 'The server did not offer any report types.',
      builder: (context, reports) => VPageBody(
        children: [
          VPageHeader(
            breadcrumb: const ['Records', 'Reports'],
            title: 'Reports',
            description: 'The same layouts your team circulates today. Export to Excel or PDF '
                'and share straight to WhatsApp or e-mail.',
            actions: [
              VButton.ghost(
                label: fmtDate(_date),
                icon: Icons.event_rounded,
                size: VButtonSize.small,
                onPressed: _pickDate,
              ),
            ],
          ),

          if (line != null)
            Padding(
              padding: const EdgeInsets.only(bottom: VSpace.lg),
              child: _ScopeBanner(line: line, date: _date),
            ),

          VCardGrid(
            minTileWidth: 330,
            children: [
              for (final report in reports)
                _ReportCard(
                  report: report,
                  line: line,
                  busyFormats: {
                    for (final format in report.formats)
                      if (_busy.contains('${report.type}|$format')) format,
                  },
                  progress: {
                    for (final format in report.formats)
                      if (_progress.containsKey('${report.type}|$format'))
                        format: _progress['${report.type}|$format']!,
                  },
                  onExport: (format) => _export(report, format, line),
                  onPreview: _previewRouteFor(report) == null
                      ? null
                      : () => context.go(_previewRouteFor(report)!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Two reports have a live on-screen equivalent already; the rest are export
  /// only. Sending the user to the real screen beats building a second, worse
  /// renderer of the same data.
  String? _previewRouteFor(ReportDefinition report) => switch (report.type) {
        'shortage-tracker' => Routes.matrix,
        'part-coverage' => Routes.coverage,
        _ => null,
      };

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now(),
      helpText: 'Date for the register reports',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _export(ReportDefinition report, String format, ProductionLine? line) async {
    if (report.needsLine && line == null) {
      VToast.warning(
        context,
        'Pick a production line first',
        detail: '${report.title} is calculated per line.',
      );
      return;
    }

    final key = '${report.type}|$format';
    setState(() {
      _busy.add(key);
      _progress.remove(key);
    });

    try {
      final file = await ref.read(reportRepositoryProvider).export(
            type: report.type,
            format: format,
            lineId: report.needsLine ? line!.id : line?.id,
            date: report.supportsDateRange ? _isoDate(_date) : null,
            onProgress: (received, total) {
              if (!mounted || total <= 0) return;
              setState(() => _progress[key] = received / total);
            },
          );

      final message = await deliverReport(
        bytes: file.bytes,
        filename: file.filename,
        mimeType: file.contentType,
        subject: '${report.title}'
            '${line != null && report.needsLine ? ' — ${line.name}' : ''}'
            ' · CNH Paint Shop',
      );

      if (!mounted) return;
      VToast.success(context, message, detail: '${_kb(file.bytes.length)} · ${file.filename}');
    } on ApiException catch (e) {
      if (!mounted) return;
      // The server says WHY a report could not be generated (no line, unknown
      // format, nothing to export). Passing that through beats a generic failure.
      VToast.error(context, 'Could not generate ${report.title}', detail: e.message);
    } catch (e) {
      if (!mounted) return;
      VToast.error(context, 'Could not share the file', detail: e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(key);
          _progress.remove(key);
        });
      }
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _kb(int bytes) => bytes < 1024
      ? '$bytes B'
      : (bytes < 1024 * 1024
          ? '${(bytes / 1024).toStringAsFixed(0)} KB'
          : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB');
}

/// States what the exports will actually be scoped to, so nobody sends the
/// wrong line's sheet to management.
class _ScopeBanner extends StatelessWidget {
  const _ScopeBanner({required this.line, required this.date});

  final ProductionLine line;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Container(
      padding: const EdgeInsets.all(VSpace.md),
      decoration: BoxDecoration(
        color: v.surface2,
        borderRadius: VRadius.allSm,
        border: Border.all(color: v.line),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt_rounded, size: 16, color: v.txt3),
          const SizedBox(width: VSpace.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: context.text.bodySmall?.copyWith(color: v.txt3),
                children: [
                  const TextSpan(text: 'Line-scoped reports will use '),
                  TextSpan(
                    text: '${line.code} · ${line.name}',
                    style: context.text.bodySmall?.copyWith(
                      color: v.txt,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: '. Register reports will use '),
                  TextSpan(
                    text: fmtDate(date),
                    style: context.text.bodySmall?.copyWith(
                      color: v.txt,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.line,
    required this.busyFormats,
    required this.progress,
    required this.onExport,
    this.onPreview,
  });

  final ReportDefinition report;
  final ProductionLine? line;
  final Set<String> busyFormats;
  final Map<String, double> progress;
  final void Function(String format) onExport;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final blocked = report.needsLine && line == null;
    final anyBusy = busyFormats.isNotEmpty;

    return VCard(
      cornerMark: true,
      padding: const EdgeInsets.all(VSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: v.accentTint,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(_iconFor(report.type), size: 19, color: v.accent),
              ),
              const SizedBox(width: VSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(report.title, style: context.text.titleSmall?.copyWith(fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: VSpace.xs,
                      runSpacing: 2,
                      children: [
                        if (report.needsLine)
                          VPill(
                            label: line?.code ?? 'Needs a line',
                            status: blocked ? VStatus.warning : VStatus.info,
                            showDot: false,
                            compact: true,
                          ),
                        if (report.supportsDateRange)
                          const VPill(
                            label: 'By date',
                            status: VStatus.neutral,
                            showDot: false,
                            compact: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: VSpace.md),
          Text(
            report.description,
            style: context.text.bodySmall?.copyWith(color: v.txt3, height: 1.5),
          ),

          if (anyBusy) ...[
            const SizedBox(height: VSpace.md),
            _ExportProgress(progress: progress.values.first),
          ],

          const SizedBox(height: VSpace.md),
          Wrap(
            spacing: VSpace.sm,
            runSpacing: VSpace.sm,
            children: [
              for (final format in report.formats)
                VButton(
                  label: format.toUpperCase(),
                  icon: format == 'pdf'
                      ? Icons.picture_as_pdf_rounded
                      : Icons.table_chart_rounded,
                  variant: format == 'xlsx' ? VButtonVariant.gradient : VButtonVariant.ghost,
                  size: VButtonSize.small,
                  loading: busyFormats.contains(format),
                  onPressed: blocked || anyBusy ? null : () => onExport(format),
                ),
              if (onPreview != null)
                VButton.quiet(
                  label: 'View on screen',
                  icon: Icons.open_in_new_rounded,
                  size: VButtonSize.small,
                  onPressed: onPreview,
                ),
            ],
          ),

          if (blocked) ...[
            const SizedBox(height: VSpace.sm),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 13, color: v.warn),
                const SizedBox(width: VSpace.xs),
                Expanded(
                  child: Text(
                    'Choose a production line in the top bar to enable this report.',
                    style: context.text.labelSmall?.copyWith(color: v.warn, fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(String type) => switch (type) {
        'shortage-tracker' => Icons.grid_on_rounded,
        'part-coverage' => Icons.inventory_2_rounded,
        'nesting-register' => Icons.move_to_inbox_rounded,
        'spd-register' => Icons.outbox_rounded,
        'pattern-master' => Icons.view_module_rounded,
        'rotavator-tracker' => Icons.agriculture_rounded,
        'bulky-parts' => Icons.inventory_rounded,
        _ => Icons.summarize_rounded,
      };
}

class _ExportProgress extends StatelessWidget {
  const _ExportProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          progress <= 0 ? 'Generating…' : 'Downloading ${(progress * 100).round()}%',
          style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 10),
        ),
        const SizedBox(height: VSpace.xxs),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 4,
            child: progress <= 0
                // The server is still building the workbook — there is no
                // percentage to show yet, so the ribbon bar sweeps instead.
                ? const RibbonBar(width: double.infinity, height: 4)
                : Stack(
                    children: [
                      Positioned.fill(child: ColoredBox(color: v.surface3)),
                      FractionallySizedBox(
                        widthFactor: progress.clamp(0, 1),
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
