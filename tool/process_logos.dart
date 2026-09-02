// Prepares the two Vistar brand assets for the app.
//
// The source PNGs ship on an opaque BLACK background. Every placement in the
// design system (splash orbit, route loader, page watermark, card corner,
// sidebar glyph) composites the mark over a coloured surface, so the black has
// to become real transparency first — otherwise the mark reads as a black tile.
//
// What this does, once, at build-prep time rather than per frame:
//   1. Keys out the near-black background to alpha, feathering the edge so the
//      glow around the swoosh survives instead of being hard-clipped.
//   2. Autocrops to the remaining opaque bounds.
//   3. Emits the three variants the design system asks for:
//        logo_mark_360.png    — loaders, watermark, card corner
//        logo_mark_140.png    — small UI spots
//        logo_wordmark_486.png — splash + login only
//
// Run:  dart run tool/process_logos.dart
//
// Idempotent: re-running just overwrites the outputs. The sources are read from
// the project's parent folder and are never modified.

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

// The key is on the BRIGHTEST CHANNEL, not on luminance.
//
// Keying on luma leaves the source's wide purple bloom behind: the bloom is
// saturated (so a saturation test keeps it) and mid-luma (so a luma test keeps
// it), and it renders as a blotchy cloud around the mark — unusable as a
// watermark or a card-corner accent.
//
// Every colour in the actual ribbon has at least one channel near-maximal:
// magenta and violet peak in R+B, red/orange in R, amber/yellow in R+G, cream
// in all three. The bloom peaks far lower. So `max(r,g,b)` separates ink from
// bloom cleanly where luma cannot.
const int _bgMaxChannel = 118; // at or below → background
const int _inkMaxChannel = 178; // at or above → ink

// The wordmark needs a tighter key than the S mark.
//
// Its "Vistar" letters are a flat mid-magenta whose brightest channel sits at
// roughly the same level as the surrounding bloom, so max-channel alone cannot
// tell them apart. Saturation can: the letters are near-pure magenta (R and B
// high, G very low → saturation ~0.87) while the bloom is washed out toward
// white (G lifted → saturation ~0.6). Hence a saturation floor here, and a
// higher brightness floor to match.
const int _wordBgMaxChannel = 140;
const int _wordInkMaxChannel = 186;
const double _wordMinSaturation = 0.70;

void main(List<String> args) async {
  final root = Directory.current.path;
  final sourceDir = args.isNotEmpty ? args.first : Directory(root).parent.path;

  final jobs = <_Job>[
    _Job(
      source: '$sourceDir/logo.png',
      outputs: [
        _Output('assets/images/logo_mark_360.png', 360),
        _Output('assets/images/logo_mark_140.png', 140),
      ],
    ),
    _Job(
      source: '$sourceDir/logo_name.png',
      bgMaxChannel: _wordBgMaxChannel,
      inkMaxChannel: _wordInkMaxChannel,
      minSaturation: _wordMinSaturation,
      outputs: [_Output('assets/images/logo_wordmark_486.png', 486)],
    ),
  ];

  for (final job in jobs) {
    final file = File(job.source);
    if (!file.existsSync()) {
      stderr.writeln('✗ missing source: ${job.source}');
      exitCode = 1;
      continue;
    }

    final decoded = img.decodePng(await file.readAsBytes());
    if (decoded == null) {
      stderr.writeln('✗ could not decode: ${job.source}');
      exitCode = 1;
      continue;
    }

    stdout.writeln('• ${job.source}  ${decoded.width}×${decoded.height}');

    final keyed = _keyOutBackground(
      decoded,
      bgMaxChannel: job.bgMaxChannel,
      inkMaxChannel: job.inkMaxChannel,
      minSaturation: job.minSaturation,
    );
    final cropped = _autoCrop(keyed);
    stdout.writeln('  keyed + cropped → ${cropped.width}×${cropped.height}');

    for (final output in job.outputs) {
      final resized = img.copyResize(
        cropped,
        width: output.width,
        interpolation: img.Interpolation.cubic,
      );
      final target = File(output.path);
      await target.parent.create(recursive: true);
      await target.writeAsBytes(img.encodePng(resized, level: 9));
      final kb = (await target.length() / 1024).toStringAsFixed(1);
      stdout.writeln('  ✓ ${output.path}  ${resized.width}×${resized.height}  ${kb}KB');
    }
  }

  stdout.writeln('\nDone. Assets are referenced from lib/design/brand_assets.dart.');
}

/// Converts the dark backdrop to transparency with a soft ramp.
///
/// Straight `luma < threshold ? transparent : opaque` produces stair-stepped
/// edges on a diagonal swoosh at 360px. Ramping alpha across the two thresholds
/// preserves the antialiasing that is already in the source.
img.Image _keyOutBackground(
  img.Image src, {
  int bgMaxChannel = _bgMaxChannel,
  int inkMaxChannel = _inkMaxChannel,
  double minSaturation = 0.15,
}) {
  final out = img.Image(width: src.width, height: src.height, numChannels: 4);

  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();

      final maxC = math.max(r, math.max(g, b));

      int alpha;
      if (maxC <= bgMaxChannel) {
        alpha = 0;
      } else if (maxC >= inkMaxChannel) {
        alpha = 255;
      } else {
        // Ramp, then square it. The linear ramp alone leaves a visible halo of
        // ~40% alpha bloom pixels; squaring pushes those toward transparent
        // while leaving pixels close to the ink threshold nearly solid.
        final t = (maxC - bgMaxChannel) / (inkMaxChannel - bgMaxChannel);
        alpha = (t * t * 255).round();
      }

      // Saturation gate. Removes the grey vignette on both assets, and on the
      // wordmark (where the floor is raised) the washed-out magenta bloom too.
      final minC = math.min(r, math.min(g, b));
      final saturation = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
      if (saturation < minSaturation && maxC < 235) {
        final ratio = saturation / minSaturation;
        alpha = (alpha * ratio * ratio).round().clamp(0, 255);
      }

      if (alpha < 6) {
        out.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }

      if (alpha == 0) {
        out.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }

      // Un-premultiply against the black we just removed, so a half-transparent
      // edge pixel keeps its true colour instead of reading muddy.
      final scale = 255 / alpha;
      out.setPixelRgba(
        x,
        y,
        (r * scale).round().clamp(0, 255),
        (g * scale).round().clamp(0, 255),
        (b * scale).round().clamp(0, 255),
        alpha,
      );
    }
  }
  return out;
}

/// Trims fully/near-transparent margins so the mark fills its box.
img.Image _autoCrop(img.Image src, {int alphaFloor = 8}) {
  var minX = src.width;
  var minY = src.height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      if (src.getPixel(x, y).a.toInt() > alphaFloor) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }

  if (maxX < 0) return src; // fully transparent — nothing to crop to

  return img.copyCrop(
    src,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}

class _Job {
  const _Job({
    required this.source,
    required this.outputs,
    this.bgMaxChannel = _bgMaxChannel,
    this.inkMaxChannel = _inkMaxChannel,
    this.minSaturation = 0.15,
  });
  final String source;
  final List<_Output> outputs;
  final int bgMaxChannel;
  final int inkMaxChannel;
  final double minSaturation;
}

class _Output {
  const _Output(this.path, this.width);
  final String path;
  final int width;
}
