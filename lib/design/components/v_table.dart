import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// The `.tbl-wrap` shell: a hairline border, radius 16, clipped content, and an
/// uppercase micro-label header row on `surface2`.
///
/// Used by the registers and the plan. The shortage matrix does NOT use this —
/// it needs synchronised two-axis scrolling with frozen headers, which is a
/// different widget entirely (see features/matrix).
class VTableShell extends StatelessWidget {
  const VTableShell({
    super.key,
    required this.child,
    this.header,
    this.footer,
    this.scrollHorizontally = true,
  });

  final Widget child;
  final Widget? header;
  final Widget? footer;
  final bool scrollHorizontally;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Container(
      decoration: BoxDecoration(
        color: v.surface,
        borderRadius: VRadius.allMd,
        border: Border.all(color: v.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null) header!,
          Flexible(child: child),
          if (footer != null) ...[
            Container(height: 1, color: v.line),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// One column's definition. `flex` and `width` are mutually exclusive: a fixed
/// width for numeric/status columns that must not reflow, flex for text.
class VColumn {
  const VColumn({
    required this.label,
    this.width,
    this.flex = 1,
    this.align = TextAlign.left,
    this.tooltip,
  });

  final String label;
  final double? width;
  final int flex;
  final TextAlign align;
  final String? tooltip;
}

/// The `thead th` recipe.
class VTableHeader extends StatelessWidget {
  const VTableHeader({super.key, required this.columns, this.leading, this.trailing});

  final List<VColumn> columns;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Container(
      decoration: BoxDecoration(
        color: v.surface2,
        border: Border(bottom: BorderSide(color: v.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: VSpace.lg, vertical: VSpace.md),
      child: Row(
        children: [
          if (leading != null) leading!,
          for (final col in columns)
            if (col.width != null)
              SizedBox(width: col.width, child: _HeaderCell(column: col))
            else
              Expanded(flex: col.flex, child: _HeaderCell(column: col)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.column});

  final VColumn column;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final text = Text(
      column.label.toUpperCase(),
      textAlign: column.align,
      style: context.text.labelSmall?.copyWith(color: v.txt3),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    return column.tooltip != null ? Tooltip(message: column.tooltip!, child: text) : text;
  }
}

/// The `tbody tr` recipe, with the hover tint and a bottom hairline.
class VTableRow extends StatefulWidget {
  const VTableRow({
    super.key,
    required this.children,
    this.onTap,
    this.accentEdge,
    this.background,
    this.last = false,
    this.dense = false,
  });

  final List<Widget> children;
  final VoidCallback? onTap;

  /// A 3px leading status stripe — makes a red row scannable without reading it.
  final Color? accentEdge;

  final Color? background;
  final bool last;
  final bool dense;

  @override
  State<VTableRow> createState() => _VTableRowState();
}

class _VTableRowState extends State<VTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    Widget row = AnimatedContainer(
      duration: VMotion.instant,
      padding: EdgeInsets.symmetric(
        horizontal: VSpace.lg,
        vertical: widget.dense ? VSpace.sm : VSpace.md,
      ),
      decoration: BoxDecoration(
        color: _hovered ? v.surface2 : (widget.background ?? Colors.transparent),
        border: widget.last ? null : Border(bottom: BorderSide(color: v.line)),
      ),
      child: Row(children: widget.children),
    );

    if (widget.accentEdge != null) {
      row = Stack(
        children: [
          row,
          Positioned(
            left: 0,
            top: 4,
            bottom: 4,
            child: Container(width: 3, color: widget.accentEdge),
          ),
        ],
      );
    }

    if (widget.onTap != null) {
      row = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(onTap: widget.onTap, child: row),
      );
    } else {
      row = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: row,
      );
    }

    return row;
  }
}

/// A `tbody td`. Numeric cells get tabular figures so digits line up down a
/// column — see VType.mono for why that matters here.
class VCell extends StatelessWidget {
  const VCell({
    super.key,
    required this.text,
    this.width,
    this.flex = 1,
    this.align = TextAlign.left,
    this.color,
    this.numeric = false,
    this.bold = false,
    this.maxLines = 1,
    this.subtitle,
  });

  final String text;
  final double? width;
  final int flex;
  final TextAlign align;
  final Color? color;
  final bool numeric;
  final bool bold;
  final int maxLines;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final style = context.text.bodyMedium?.copyWith(
      color: color ?? v.txt2,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      fontSize: 13,
      fontFeatures: numeric ? const [FontFeature.tabularFigures()] : null,
    );

    final content = subtitle == null
        ? Text(text, textAlign: align, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis)
        : Column(
            crossAxisAlignment:
                align == TextAlign.right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: align, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 1),
              Text(
                subtitle!,
                textAlign: align,
                style: context.text.bodySmall?.copyWith(color: v.txt3, fontSize: 11.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );

    return width != null
        ? SizedBox(width: width, child: content)
        : Expanded(flex: flex, child: content);
  }
}

/// A widget cell (a pill, a button, an avatar) with the same width/flex contract
/// as [VCell], so header and body columns stay aligned.
class VWidgetCell extends StatelessWidget {
  const VWidgetCell({
    super.key,
    required this.child,
    this.width,
    this.flex = 1,
    this.align = Alignment.centerLeft,
  });

  final Widget child;
  final double? width;
  final int flex;
  final Alignment align;

  @override
  Widget build(BuildContext context) {
    final content = Align(alignment: align, child: child);
    return width != null
        ? SizedBox(width: width, child: content)
        : Expanded(flex: flex, child: content);
  }
}
