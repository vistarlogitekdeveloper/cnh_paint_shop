import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../brand_assets.dart';
import '../theme.dart';
import '../tokens.dart';

/// ---------------------------------------------------------------------------
/// The three S loaders from the design system.
///
///   [SOrbitLoader]  — splash: two counter-spinning rings + a breathing S.
///   [RouteLoader]   — a ~360ms overlay on every screen switch.
///   [RibbonBar]     — the indeterminate ribbon progress bar.
///
/// All three drive from a SINGLE [AnimationController] each and paint with
/// [CustomPainter] / [Transform] rather than rebuilding subtrees, so the
/// animation costs a repaint and not a layout pass. Each is wrapped in a
/// [RepaintBoundary] so a spinner can never dirty the screen behind it.
/// ---------------------------------------------------------------------------

class SOrbitLoader extends StatefulWidget {
  const SOrbitLoader({super.key, this.size = 200});

  final double size;

  @override
  State<SOrbitLoader> createState() => _SOrbitLoaderState();
}

class _SOrbitLoaderState extends State<SOrbitLoader> with TickerProviderStateMixin {
  // Three tempos from the CSS: 1.6s outer ring, 2.2s inner ring (reversed),
  // 2.2s breathe on the mark. One controller per tempo; `breathe` doubles as
  // the inner ring's clock since they share a period.
  late final AnimationController _outer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  late final AnimationController _inner = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _outer.dispose();
    _inner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markSize = widget.size * 0.48;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring: pink top + orange right, clockwise.
            AnimatedBuilder(
              animation: _outer,
              builder: (_, _) => Transform.rotate(
                angle: _outer.value * 2 * math.pi,
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: const _ArcRingPainter(
                    topColor: Color(0xA6E0218A),
                    rightColor: Color(0x66F06000),
                    strokeWidth: 1.5,
                  ),
                ),
              ),
            ),

            // Inner ring: violet bottom + amber left, counter-clockwise, inset 22.
            Padding(
              padding: const EdgeInsets.all(22),
              child: AnimatedBuilder(
                animation: _inner,
                builder: (_, _) => Transform.rotate(
                  angle: -_inner.value * 2 * math.pi,
                  child: CustomPaint(
                    size: Size.square(widget.size - 44),
                    painter: const _ArcRingPainter(
                      topColor: Color(0x739B30C9),
                      rightColor: Color(0x73F0C000),
                      strokeWidth: 1.5,
                      startAtBottom: true,
                    ),
                  ),
                ),
              ),
            ),

            // The breathing mark: scale .92 → 1.04 with a 4px vertical drift,
            // and a pink drop-shadow glow underneath it.
            AnimatedBuilder(
              animation: _inner,
              builder: (_, _) {
                final t = math.sin(_inner.value * 2 * math.pi);
                final scale = 0.98 + t * 0.06;
                final dy = -t * 2.0;
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.scale(
                    scale: scale,
                    child: _GlowingMark(size: markSize),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The S mark with the design system's pink glow behind it.
///
/// Flutter cannot apply a CSS `drop-shadow` to an image's alpha directly, so the
/// glow is a blurred radial behind the mark. Cheaper than a shader and visually
/// identical at these sizes.
class _GlowingMark extends StatelessWidget {
  const _GlowingMark({required this.size, this.glowAlpha = 0.55});

  final double size;
  final double glowAlpha;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.86,
            height: size * 0.86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: VRibbon.pink.withValues(alpha: glowAlpha),
                  blurRadius: size * 0.30,
                  spreadRadius: size * 0.02,
                ),
              ],
            ),
          ),
          Image.asset(VBrand.mark, width: size, height: size, fit: BoxFit.contain),
        ],
      ),
    );
  }
}

/// Two coloured arcs on a circle, the rest transparent — the CSS
/// `border-top-color` + `border-right-color` trick.
class _ArcRingPainter extends CustomPainter {
  const _ArcRingPainter({
    required this.topColor,
    required this.rightColor,
    this.strokeWidth = 1.5,
    this.startAtBottom = false,
  });

  final Color topColor;
  final Color rightColor;
  final double strokeWidth;
  final bool startAtBottom;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Quarter-turn offset so the inner ring's arcs sit opposite the outer's,
    // which is what makes the counter-rotation legible.
    final base = startAtBottom ? math.pi / 2 : -math.pi / 2;

    canvas.drawArc(rect, base, math.pi / 2, false, paint..color = topColor);
    canvas.drawArc(rect, base + math.pi / 2, math.pi / 2.4, false, paint..color = rightColor);
  }

  @override
  bool shouldRepaint(_ArcRingPainter old) =>
      old.topColor != topColor || old.rightColor != rightColor;
}

/// The indeterminate ribbon bar (`.splash-bar`): a 40%-wide ribbon slug that
/// sweeps across a translucent track.
class RibbonBar extends StatefulWidget {
  const RibbonBar({super.key, this.width = 200, this.height = 4});

  final double width;
  final double height;

  @override
  State<RibbonBar> createState() => _RibbonBarState();
}

class _RibbonBarState extends State<RibbonBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    const slugFraction = 0.4;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.height * 2.5),
          child: ColoredBox(
            color: v.isDark ? const Color(0x12FFFFFF) : const Color(0x14171029),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) {
                // easeInOut on the sweep, so the slug decelerates at each end
                // instead of scrolling at a constant, mechanical rate.
                final t = Curves.easeInOut.transform(_c.value);
                final travel = widget.width * (1 + slugFraction);
                return Transform.translate(
                  offset: Offset(-widget.width * slugFraction + t * travel, 0),
                  child: Container(
                    width: widget.width * slugFraction,
                    height: widget.height,
                    decoration: const BoxDecoration(
                      gradient: VRibbon.gradient,
                      borderRadius: VRadius.allPill,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The route-change overlay (`#routeload`): a blurred scrim with a breathing S.
///
/// Shown for ~360ms on a screen switch. It exists so navigation feels
/// deliberate rather than jumpy, and so a screen whose first frame needs data
/// does not flash an empty layout.
class RouteLoader extends StatefulWidget {
  const RouteLoader({super.key, this.visible = true, this.markSize = 64});

  final bool visible;
  final double markSize;

  @override
  State<RouteLoader> createState() => _RouteLoaderState();
}

class _RouteLoaderState extends State<RouteLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: VMotion.fast,
        child: RepaintBoundary(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: ColoredBox(
                color: v.bg.withValues(alpha: 0.55),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, _) {
                      final t = math.sin(_c.value * 2 * math.pi);
                      return Transform.scale(
                        scale: 0.98 + t * 0.06,
                        child: _GlowingMark(size: widget.markSize, glowAlpha: 0.5),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small inline spinner for buttons and list footers — the S mark is too
/// detailed below ~40px, so this is a ribbon-tinted arc instead.
class VSpinner extends StatefulWidget {
  const VSpinner({super.key, this.size = 18, this.strokeWidth = 2.2, this.color});

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  State<VSpinner> createState() => _VSpinnerState();
}

class _VSpinnerState extends State<VSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.v.accent;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Transform.rotate(
            angle: _c.value * 2 * math.pi,
            child: CustomPaint(
              painter: _SpinnerPainter(color: color, strokeWidth: widget.strokeWidth),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 1.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        // A sweep gradient across the visible arc gives the spinner the ribbon's
        // colour shift without needing a second layer.
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          colors: [color.withValues(alpha: 0.15), color],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) => old.color != color;
}
