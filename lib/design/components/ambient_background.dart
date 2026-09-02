import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../brand_assets.dart';
import '../theme.dart';
import '../tokens.dart';

/// ---------------------------------------------------------------------------
/// The page's ambient background: aurora glows + a faint rotated S watermark +
/// film grain. Reproduces `#ambient` from the design system.
///
/// PERFORMANCE. This sits behind every screen, so it must cost nothing per
/// frame. Three choices make that true:
///   * It is a single [CustomPaint] with `isComplex: true` + `willChange: false`,
///     which lets the engine raster-cache the whole thing to a texture. The
///     alternative — nested Containers with gradient decorations plus an Opacity
///     over an Image — allocates and composites several layers every frame.
///   * The grain is a 128×128 procedural tile generated ONCE and drawn with a
///     repeat shader, not a per-pixel noise pass.
///   * Nothing here animates. The premium feel comes from the still composition;
///     an animated background behind a data grid is a battery tax on a device
///     that lives on a shop floor all shift.
/// ---------------------------------------------------------------------------
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    this.child,
    this.showWatermark = true,
    this.showGrain = true,
    this.watermarkAlignment = const Alignment(1.06, 0),
    this.watermarkScale = 0.62,
  });

  final Widget? child;

  /// The big rotated S. Off for dense data screens, where even 5% opacity
  /// behind a 270-column grid is visual noise rather than atmosphere.
  final bool showWatermark;
  final bool showGrain;

  final Alignment watermarkAlignment;

  /// Fraction of the viewport's larger side (`62vmax` in the CSS).
  final double watermarkScale;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _AmbientPainter(
              colors: v,
              showGrain: showGrain,
              grainTile: _GrainTile.instance.image,
            ),
            isComplex: true,
            willChange: false,
          ),
          if (showWatermark)
            IgnorePointer(
              child: _Watermark(
                alignment: watermarkAlignment,
                scale: watermarkScale,
                opacity: v.watermarkOpacity,
              ),
            ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _Watermark extends StatelessWidget {
  const _Watermark({required this.alignment, required this.scale, required this.opacity});

  final Alignment alignment;
  final double scale;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(constraints.maxWidth, constraints.maxHeight) * scale;
        return Align(
          alignment: alignment,
          child: Transform.rotate(
            angle: 4 * math.pi / 180, // the CSS `rotate(4deg)`
            child: Opacity(
              opacity: opacity,
              child: ImageFiltered(
                // The CSS applies `saturate(1.2) blur(.4px)`. A sub-pixel blur
                // is what stops the mark's hard ribbon edges from reading as a
                // second, competing shape at this size.
                imageFilter: ui.ImageFilter.blur(sigmaX: 0.6, sigmaY: 0.6),
                child: Image.asset(
                  VBrand.mark,
                  width: side,
                  height: side,
                  fit: BoxFit.contain,
                  // Decoding the 360px asset at watermark size (often 800px+)
                  // would upscale from cache; letting the engine pick keeps it
                  // sharp without a second copy in memory.
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.colors, required this.showGrain, required this.grainTile});

  final VColors colors;
  final bool showGrain;
  final ui.Image? grainTile;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base fill.
    canvas.drawRect(rect, Paint()..color = colors.bg);

    // Aurora washes. Each is a radial gradient that fades to transparent at
    // 55–60% of its radius, matching the CSS stops.
    for (final wash in colors.ambient) {
      final center = Offset(
        (wash.at.x + 1) / 2 * size.width,
        (wash.at.y + 1) / 2 * size.height,
      );
      // The CSS radii are in px against a desktop viewport; scale with the
      // canvas so a phone gets a proportionally similar glow rather than one
      // that swallows the screen.
      final radius = wash.radius * (math.max(size.width, size.height) / 1440).clamp(0.55, 1.6);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            radius,
            [wash.color, wash.color.withValues(alpha: 0)],
            const [0.0, 0.6],
          ),
      );
    }

    // Grain, tiled via a repeat shader — one draw call regardless of viewport.
    if (showGrain && grainTile != null && colors.grainOpacity > 0) {
      final paint = Paint()
        ..shader = ui.ImageShader(
          grainTile!,
          TileMode.repeated,
          TileMode.repeated,
          Matrix4.identity().storage,
        )
        ..blendMode = BlendMode.overlay
        ..color = Colors.white.withValues(alpha: colors.grainOpacity);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) =>
      old.colors.bg != colors.bg ||
      old.colors.grainOpacity != colors.grainOpacity ||
      old.showGrain != showGrain ||
      old.grainTile != grainTile;
}

/// A 128×128 monochrome noise tile, generated once per process.
///
/// The CSS uses an inline `feTurbulence` SVG. Flutter has no SVG filter, so the
/// tile is synthesised from a seeded PRNG — seeded so the texture is identical
/// across runs and across hot reloads, which matters because an unstable grain
/// pattern is visible as a shimmer when the theme animates.
class _GrainTile {
  _GrainTile._() {
    _generate();
  }

  static final _GrainTile instance = _GrainTile._();

  ui.Image? image;

  void _generate() {
    const size = 128;
    final rng = math.Random(0x5E7A1FB0);
    final pixels = Uint8List(size * size * 4);

    for (var i = 0; i < size * size; i++) {
      // Two octaves averaged, which reads closer to film grain than flat white
      // noise does.
      final a = rng.nextDouble();
      final b = rng.nextDouble();
      final n = ((a * 0.65 + b * 0.35) * 255).round().clamp(0, 255);
      final o = i * 4;
      pixels[o] = n;
      pixels[o + 1] = n;
      pixels[o + 2] = n;
      pixels[o + 3] = 255;
    }

    // The closure keeps `pixels` alive until the decode completes.
    ui.decodeImageFromPixels(
      pixels,
      size,
      size,
      ui.PixelFormat.rgba8888,
      (result) => image = result,
    );
  }
}
