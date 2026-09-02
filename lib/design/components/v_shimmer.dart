import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// ---------------------------------------------------------------------------
/// The `.skel` skeleton shimmer: a surface2 block with a rainbow sweep across it.
///
/// One [AnimationController] drives EVERY skeleton on a screen, shared through an
/// inherited widget. A loading list of twenty rows with twenty controllers would
/// run twenty tickers, all slightly out of phase — which looks broken as well as
/// costing frames. Sharing the clock also means the sweep travels across the
/// whole screen in unison, which is what makes it read as one loading surface.
///
/// Wrap a loading screen (or subtree) in [VShimmerScope]; use [VSkeleton] for
/// individual blocks.
/// ---------------------------------------------------------------------------
class VShimmerScope extends StatefulWidget {
  const VShimmerScope({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<VShimmerScope> createState() => _VShimmerScopeState();
}

class _VShimmerScopeState extends State<VShimmerScope> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _c.repeat();
  }

  @override
  void didUpdateWidget(VShimmerScope old) {
    super.didUpdateWidget(old);
    // Stopping the ticker when the data lands matters: a screen that finished
    // loading should not keep a 60fps animation alive behind its content.
    if (widget.enabled && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.enabled && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerClock(controller: _c, child: widget.child);
  }
}

class _ShimmerClock extends InheritedWidget {
  const _ShimmerClock({required this.controller, required super.child});

  final AnimationController controller;

  static AnimationController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerClock>()?.controller;

  @override
  bool updateShouldNotify(_ShimmerClock old) => old.controller != controller;
}

/// A single skeleton block. Falls back to a static tint when there is no
/// [VShimmerScope] above it, so it is never a crash — just less animated.
class VSkeleton extends StatelessWidget {
  const VSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 10,
    this.shape = BoxShape.rectangle,
  });

  /// A circle, for avatar and icon-chip placeholders.
  const VSkeleton.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = 0,
        shape = BoxShape.circle;

  /// A line of text. `widthFactor` lets a paragraph of skeletons have ragged
  /// line ends, which reads far more like text than a block of equal bars.
  const VSkeleton.text({super.key, this.width, this.height = 13})
      : radius = 6,
        shape = BoxShape.rectangle;

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final controller = _ShimmerClock.maybeOf(context);

    final base = DecoratedBox(
      decoration: BoxDecoration(
        color: v.surface2,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
        shape: shape,
      ),
      child: SizedBox(width: width, height: height),
    );

    if (controller == null) return base;

    return ClipRRect(
      borderRadius: shape == BoxShape.circle
          ? BorderRadius.circular(height)
          : BorderRadius.circular(radius),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Stack(
            children: [
              base,
              Positioned.fill(
                child: _SweepOverlay(progress: controller.value, isDark: v.isDark),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The pink→orange sweep. Painted rather than a translated gradient container,
/// so it costs one draw op and clips to the parent without an extra layer.
class _SweepOverlay extends StatelessWidget {
  const _SweepOverlay({required this.progress, required this.isDark});

  final double progress;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SweepPainter(progress: progress, isDark: isDark));
  }
}

class _SweepPainter extends CustomPainter {
  const _SweepPainter({required this.progress, required this.isDark});

  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    // Travel from fully off-left to fully off-right so the sweep never appears
    // to be born mid-block.
    final dx = -size.width + progress * (size.width * 2);
    final rect = Rect.fromLTWH(dx, 0, size.width, size.height);
    final a = isDark ? 1.0 : 0.55; // the sweep needs pulling back on white

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            VRibbon.pink.withValues(alpha: 0),
            VRibbon.pink.withValues(alpha: 0.16 * a),
            VRibbon.orange.withValues(alpha: 0.12 * a),
            VRibbon.orange.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.42, 0.62, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.progress != progress || old.isDark != isDark;
}

/// A skeleton stand-in for a list of cards — the loading state for the coverage,
/// alerts, requests and register screens.
class VSkeletonList extends StatelessWidget {
  const VSkeletonList({super.key, this.rows = 6, this.height = 76, this.gap = VSpace.md});

  final int rows;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return VShimmerScope(
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == rows - 1 ? 0 : gap),
              child: Container(
                height: height,
                padding: const EdgeInsets.all(VSpace.md),
                decoration: BoxDecoration(
                  color: v.surface,
                  borderRadius: VRadius.allMd,
                  border: Border.all(color: v.line),
                ),
                child: Row(
                  children: [
                    const VSkeleton.circle(size: 38),
                    const SizedBox(width: VSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Ragged widths so a column of these reads as text.
                          VSkeleton.text(width: 150 + (i % 3) * 40),
                          const SizedBox(height: VSpace.sm),
                          VSkeleton.text(width: 90 + (i % 2) * 50, height: 11),
                        ],
                      ),
                    ),
                    const SizedBox(width: VSpace.md),
                    const VSkeleton(width: 62, height: 22, radius: 999),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A skeleton grid for the dashboard's KPI row.
class VSkeletonKpiRow extends StatelessWidget {
  const VSkeletonKpiRow({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return VShimmerScope(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final perRow = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 520 ? 2 : 1);
          final width = (constraints.maxWidth - (perRow - 1) * VSpace.md) / perRow;
          return Wrap(
            spacing: VSpace.md,
            runSpacing: VSpace.md,
            children: [
              for (var i = 0; i < count; i++)
                Container(
                  width: width,
                  height: 132,
                  padding: const EdgeInsets.all(VSpace.lg),
                  decoration: BoxDecoration(
                    color: v.surface,
                    borderRadius: VRadius.allMd,
                    border: Border.all(color: v.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const VSkeleton(width: 38, height: 38, radius: 11),
                          const SizedBox(width: VSpace.md),
                          Expanded(child: VSkeleton.text(width: 70 + (i % 2) * 30, height: 11)),
                        ],
                      ),
                      const Spacer(),
                      const VSkeleton(width: 74, height: 30, radius: 8),
                      const SizedBox(height: VSpace.sm),
                      const VSkeleton.text(width: 108, height: 10),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
