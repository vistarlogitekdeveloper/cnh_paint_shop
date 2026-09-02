import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// The page header pattern from the design system: a breadcrumb (with one
/// ribbon-gradient accent word), a big display title, a description, and
/// right-aligned actions.
class VPageHeader extends StatelessWidget {
  const VPageHeader({
    super.key,
    required this.title,
    this.breadcrumb = const [],
    this.accentWord,
    this.description,
    this.actions = const [],
    this.padding = const EdgeInsets.only(bottom: VSpace.xl),
  });

  final String title;

  /// e.g. `['Operations', 'Coverage']`.
  final List<String> breadcrumb;

  /// The one word in the title rendered with the ribbon via a shader mask. Kept
  /// to a single word on purpose — the design system's restraint rule.
  final String? accentWord;

  final String? description;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Below ~700px the actions wrap under the title instead of competing
          // with it for width — a phone header with three buttons beside a
          // title truncates both.
          final stacked = constraints.maxWidth < 700;

          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (breadcrumb.isNotEmpty) ...[
                Row(
                  children: [
                    for (var i = 0; i < breadcrumb.length; i++) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.chevron_right_rounded, size: 14, color: v.txt3),
                        ),
                      Text(
                        breadcrumb[i],
                        style: context.text.labelSmall?.copyWith(
                          color: i == breadcrumb.length - 1 ? v.txt2 : v.txt3,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: VSpace.sm),
              ],
              _RibbonAccentTitle(title: title, accentWord: accentWord),
              if (description != null) ...[
                const SizedBox(height: VSpace.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Text(
                    description!,
                    style: context.text.bodyMedium?.copyWith(color: v.txt3, height: 1.5),
                  ),
                ),
              ],
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: VSpace.md),
                  Wrap(spacing: VSpace.sm, runSpacing: VSpace.sm, children: actions),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: VSpace.lg),
                Wrap(
                  spacing: VSpace.sm,
                  runSpacing: VSpace.sm,
                  alignment: WrapAlignment.end,
                  children: actions,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Renders the title with one word masked by the ribbon gradient.
///
/// Implemented as a Wrap of separate Text widgets rather than a RichText with a
/// shader span, because a ShaderMask over a whole paragraph would tint every
/// word — the effect only works when it is confined to the accent word's own
/// glyph bounds.
class _RibbonAccentTitle extends StatelessWidget {
  const _RibbonAccentTitle({required this.title, this.accentWord});

  final String title;
  final String? accentWord;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final style = context.text.headlineMedium!.copyWith(color: v.txt, height: 1.15);

    if (accentWord == null || !title.contains(accentWord!)) {
      return Text(title, style: style);
    }

    final words = title.split(' ');
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < words.length; i++) ...[
          if (words[i] == accentWord)
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => VRibbon.gradient.createShader(bounds),
              child: Text(words[i], style: style.copyWith(color: Colors.white)),
            )
          else
            Text(words[i], style: style),
          if (i < words.length - 1) Text(' ', style: style),
        ],
      ],
    );
  }
}

/// A scrollable page body with the app's standard gutters and max width.
///
/// The max width matters on desktop: a 2560px-wide monitor showing a
/// full-bleed form is unreadable, and the design system's "generous negative
/// space" only reads as generous if the content is actually constrained.
class VPageBody extends StatelessWidget {
  const VPageBody({
    super.key,
    required this.children,
    this.maxWidth = 1320,
    this.padding,
    this.scrollable = true,
    this.controller,
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = constraints.maxWidth < 640 ? VSpace.lg : VSpace.xl;
        final resolved = padding ??
            EdgeInsets.fromLTRB(gutter, gutter, gutter, gutter + VSpace.xl);

        final column = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );

        final constrained = Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(padding: resolved, child: column),
          ),
        );

        if (!scrollable) return constrained;

        return SingleChildScrollView(
          controller: controller,
          // Always scrollable so pull-to-refresh works even when the content
          // fits — an operator refreshing a short list should not have to
          // discover that the gesture only works on long ones.
          physics: const AlwaysScrollableScrollPhysics(),
          child: constrained,
        );
      },
    );
  }
}

/// Responsive breakpoints, named for what they mean in this app rather than for
/// device classes.
abstract final class VBreak {
  /// Phone. Operator entry screens go single-column, stacked cards.
  static const double phone = 600;

  /// Tablet / small laptop. Two-column forms, sidebar collapses to icons.
  static const double tablet = 960;

  /// Desktop. Full sidebar, wide data grids like the Excel prototype.
  static const double desktop = 1280;

  static bool isPhone(BuildContext c) => MediaQuery.sizeOf(c).width < phone;
  static bool isTablet(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return w >= phone && w < tablet;
  }

  static bool isDesktop(BuildContext c) => MediaQuery.sizeOf(c).width >= tablet;

  /// How many cards fit in a KPI row at this width.
  static int kpiColumns(double width) {
    if (width >= 1180) return 4;
    if (width >= 860) return 3;
    if (width >= 520) return 2;
    return 1;
  }
}

/// A responsive grid of equal-width cards. Uses [Wrap] with computed widths
/// rather than GridView so rows of differing heights do not force a uniform
/// aspect ratio on every tile.
class VCardGrid extends StatelessWidget {
  const VCardGrid({
    super.key,
    required this.children,
    this.spacing = VSpace.md,
    this.columns,
    this.minTileWidth = 250,
  });

  final List<Widget> children;
  final double spacing;
  final int? columns;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = columns ??
            (width / minTileWidth).floor().clamp(1, VBreak.kpiColumns(width).clamp(1, 6));
        final tileWidth = (width - (cols - 1) * spacing) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}
