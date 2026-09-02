import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Vistar Premium — design tokens.
///
/// The dark scale is the canonical one from the Vistar design system and is
/// reproduced verbatim. The light scale is DERIVED from it rather than invented:
/// the ribbon is unchanged (it is the brand), the surface/line/text scales are
/// inverted around a warm off-white, and only the status colours are re-tuned,
/// because a colour that reads correctly on #070611 does not carry on #FFFFFF.
///
/// Rules that hold in BOTH modes:
///   * The rainbow ribbon is the signature accent — thin accents and small
///     highlights only. Never a large flat fill. The canvas stays quiet so the
///     ribbon pops.
///   * Hairline borders, generous negative space, radii from one scale.
///   * Status is always 🟢 ready / 🟡 warning / 🔴 critical, everywhere.
/// ---------------------------------------------------------------------------

/// The brand ribbon. Identical in both themes — this is the one thing that must
/// never drift.
abstract final class VRibbon {
  static const purple = Color(0xFF7A1FB0);
  static const violet = Color(0xFF9B30C9);
  static const magenta = Color(0xFFC018C0);
  static const pink = Color(0xFFE0218A);
  static const red = Color(0xFFC8102E);
  static const orangeRed = Color(0xFFF0480C);
  static const orange = Color(0xFFF06000);
  static const amber = Color(0xFFF0C000);
  static const yellow = Color(0xFFF0E060);
  static const cream = Color(0xFFFFF6CC);

  /// The full ribbon at 115°, matching the CSS `--ribbon`.
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment(-0.9, -0.55),
    end: Alignment(0.9, 0.55),
    colors: [
      Color(0xFF7A1FB0),
      Color(0xFFB81FB8),
      Color(0xFFE0218A),
      Color(0xFFD11630),
      Color(0xFFF0480C),
      Color(0xFFF06000),
      Color(0xFFF0C000),
      Color(0xFFF7EE9A),
    ],
    stops: [0.0, 0.22, 0.40, 0.56, 0.70, 0.80, 0.92, 1.0],
  );

  /// `--ribbon-soft` — for wider fills where the full ribbon would shout.
  static const LinearGradient soft = LinearGradient(
    begin: Alignment(-0.9, -0.55),
    end: Alignment(0.9, 0.55),
    colors: [
      Color(0xE69B30C9),
      Color(0xE6E0218A),
      Color(0xE6F0480C),
      Color(0xE6F0C000),
    ],
  );

  /// A short slice of the ribbon, for narrow elements (a 3px nav bar, a 5px
  /// section accent) where the full eight-stop sweep would compress to mud.
  static const LinearGradient bar = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF9B30C9), Color(0xFFE0218A), Color(0xFFF06000)],
  );
}

/// The radius scale (`--r`, `--r-sm`, `--r-lg`).
abstract final class VRadius {
  static const double sm = 11;
  static const double md = 16;
  static const double lg = 22;
  static const double pill = 999;

  static const BorderRadius allSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius allMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius allLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius allPill = BorderRadius.all(Radius.circular(pill));
}

/// A 4pt spacing scale. Named rather than numeric so layout code reads as
/// intent ("gutter", "section") instead of arithmetic.
abstract final class VSpace {
  static const double xxs = 4;
  static const double xs = 6;
  static const double sm = 9;
  static const double md = 13;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 34;
  static const double section = 44;
}

/// Motion. Every duration here is deliberately short: this app is used with
/// gloves on a shop floor, and an operator tapping Save wants the confirmation
/// now, not after a tasteful 400ms.
abstract final class VMotion {
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);

  /// The route-change loader flash from the design system.
  static const Duration routeLoader = Duration(milliseconds: 360);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasis = Curves.easeOutBack;
}

/// Status semantics. One place, so 🟢/🟡/🔴 cannot drift between screens.
enum VStatus { ready, warning, critical, neutral, info }

/// ---------------------------------------------------------------------------
/// The palette, resolved per theme mode.
///
/// Exposed through a [ThemeExtension] so any widget can read the exact token it
/// needs off `Theme.of(context).extension<VColors>()!` (or the `context.v`
/// shorthand in theme.dart) without threading brightness through constructors.
/// ---------------------------------------------------------------------------
@immutable
class VColors extends ThemeExtension<VColors> {
  const VColors({
    required this.brightness,
    required this.bg,
    required this.bg2,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.line2,
    required this.txt,
    required this.txt2,
    required this.txt3,
    required this.ok,
    required this.warn,
    required this.bad,
    required this.info,
    required this.okTint,
    required this.warnTint,
    required this.badTint,
    required this.infoTint,
    required this.neutralTint,
    required this.accent,
    required this.accentTint,
    required this.shadow,
    required this.glow,
    required this.ambient,
    required this.watermarkOpacity,
    required this.grainOpacity,
    required this.cardGradient,
    required this.scrim,
  });

  final Brightness brightness;

  /// Page backgrounds (`--bg`, `--bg2`).
  final Color bg;
  final Color bg2;

  /// Raised surfaces (`--surface`, `--surface2`, `--surface3`).
  final Color surface;
  final Color surface2;
  final Color surface3;

  /// Hairlines (`--line`, `--line2`).
  final Color line;
  final Color line2;

  /// Text scale (`--txt`, `--txt2`, `--txt3`).
  final Color txt;
  final Color txt2;
  final Color txt3;

  /// Status foregrounds.
  final Color ok;
  final Color warn;
  final Color bad;
  final Color info;

  /// Status backgrounds for pills and matrix cells — translucent tints, so they
  /// sit on any surface without being recomputed per background.
  final Color okTint;
  final Color warnTint;
  final Color badTint;
  final Color infoTint;
  final Color neutralTint;

  /// The single brand accent used for focus rings, links and selection. Pink in
  /// both modes; it is the ribbon's centre of gravity.
  final Color accent;
  final Color accentTint;

  final List<Shadow> shadow;
  final List<Shadow> glow;

  /// Radial washes for the ambient page background.
  final List<({Alignment at, double radius, Color color})> ambient;

  /// How strongly the S watermark and film grain read in this mode. Light mode
  /// needs a fainter watermark: dark ink on white is far more assertive than
  /// light ink on near-black at the same alpha.
  final double watermarkOpacity;
  final double grainOpacity;

  /// The subtle top-to-bottom card wash from the design system's `.card`.
  final LinearGradient cardGradient;

  /// Overlay behind modals and the route loader.
  final Color scrim;

  bool get isDark => brightness == Brightness.dark;

  /// Foreground colour for a status.
  Color forStatus(VStatus s) => switch (s) {
        VStatus.ready => ok,
        VStatus.warning => warn,
        VStatus.critical => bad,
        VStatus.info => info,
        VStatus.neutral => txt3,
      };

  /// Translucent background for a status.
  Color tintFor(VStatus s) => switch (s) {
        VStatus.ready => okTint,
        VStatus.warning => warnTint,
        VStatus.critical => badTint,
        VStatus.info => infoTint,
        VStatus.neutral => neutralTint,
      };

  // -------------------------------------------------------------------------
  // DARK — the canonical Vistar Premium scale.
  // -------------------------------------------------------------------------
  static const VColors dark = VColors(
    brightness: Brightness.dark,
    bg: Color(0xFF070611),
    bg2: Color(0xFF0B0A18),
    surface: Color(0xFF110F1E),
    surface2: Color(0xFF16142A),
    surface3: Color(0xFF1D1A33),
    line: Color(0x14FFFFFF),
    line2: Color(0x21FFFFFF),
    txt: Color(0xFFF2EEFB),
    txt2: Color(0xFFB9B2D6),
    txt3: Color(0xFF7E769B),
    ok: Color(0xFF34D399),
    warn: Color(0xFFFBBF24),
    bad: Color(0xFFFB6F84),
    info: Color(0xFF5BA8FF),
    okTint: Color(0x2434D399),
    warnTint: Color(0x24FBBF24),
    badTint: Color(0x24FB6F84),
    infoTint: Color(0x245BA8FF),
    neutralTint: Color(0x12FFFFFF),
    accent: Color(0xFFE0218A),
    accentTint: Color(0x1FE0218A),
    shadow: [
      Shadow(color: Color(0xD9000000), offset: Offset(0, 24), blurRadius: 60),
    ],
    glow: [
      Shadow(color: Color(0x0DFFFFFF), blurRadius: 1),
      Shadow(color: Color(0x66C018C0), offset: Offset(0, 18), blurRadius: 50),
    ],
    ambient: [
      (at: Alignment(-0.76, -1.16), radius: 800, color: Color(0x387A1FB0)),
      (at: Alignment(1.10, -0.84), radius: 700, color: Color(0x29E0218A)),
      (at: Alignment(0.60, 1.20), radius: 900, color: Color(0x1FF06000)),
    ],
    watermarkOpacity: 0.05,
    grainOpacity: 0.045,
    cardGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xB316142A), Color(0xB3110F1E)],
    ),
    scrim: Color(0x8C070611),
  );

  // -------------------------------------------------------------------------
  // LIGHT — derived, not invented.
  //
  // The surfaces are a warm off-white with a faint violet cast (a pure #FFF
  // canvas makes the ribbon look like a sticker). Hairlines become low-alpha
  // INK rather than low-alpha white. Status colours are darkened until they
  // clear 4.5:1 against `surface`; the mint/amber/rose used in dark mode wash
  // out completely on white, so `ok`/`warn`/`bad` are genuinely different
  // values here rather than the same ones reused.
  // -------------------------------------------------------------------------
  static const VColors light = VColors(
    brightness: Brightness.light,
    bg: Color(0xFFF7F5FB),
    bg2: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF4F1FA),
    surface3: Color(0xFFEBE6F5),
    line: Color(0x14171029),
    line2: Color(0x29171029),
    txt: Color(0xFF17102A),
    txt2: Color(0xFF544C6B),
    txt3: Color(0xFF8A8299),
    // Darkened for contrast on white.
    ok: Color(0xFF0E8F62),
    warn: Color(0xFF9A6207),
    bad: Color(0xFFC01B36),
    info: Color(0xFF1C63C4),
    okTint: Color(0x1F0E8F62),
    warnTint: Color(0x24C98A0A),
    badTint: Color(0x1FC01B36),
    infoTint: Color(0x1F1C63C4),
    neutralTint: Color(0x0F171029),
    accent: Color(0xFFC0176F),
    accentTint: Color(0x16C0176F),
    shadow: [
      Shadow(color: Color(0x1A2A1B4A), offset: Offset(0, 12), blurRadius: 32),
    ],
    glow: [
      Shadow(color: Color(0x0A171029), blurRadius: 1),
      Shadow(color: Color(0x2EC018C0), offset: Offset(0, 14), blurRadius: 36),
    ],
    ambient: [
      (at: Alignment(-0.76, -1.16), radius: 800, color: Color(0x1F9B30C9)),
      (at: Alignment(1.10, -0.84), radius: 700, color: Color(0x17E0218A)),
      (at: Alignment(0.60, 1.20), radius: 900, color: Color(0x14F0C000)),
    ],
    // Dark ink on white is far more assertive than light ink on near-black at
    // the same alpha, so both textures are pulled well back here.
    watermarkOpacity: 0.028,
    grainOpacity: 0.022,
    cardGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFFFFF), Color(0xFFFBF9FE)],
    ),
    scrim: Color(0x662A1B4A),
  );

  @override
  VColors copyWith({
    Brightness? brightness,
    Color? bg,
    Color? bg2,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? line,
    Color? line2,
    Color? txt,
    Color? txt2,
    Color? txt3,
    Color? ok,
    Color? warn,
    Color? bad,
    Color? info,
    Color? okTint,
    Color? warnTint,
    Color? badTint,
    Color? infoTint,
    Color? neutralTint,
    Color? accent,
    Color? accentTint,
    List<Shadow>? shadow,
    List<Shadow>? glow,
    List<({Alignment at, double radius, Color color})>? ambient,
    double? watermarkOpacity,
    double? grainOpacity,
    LinearGradient? cardGradient,
    Color? scrim,
  }) {
    return VColors(
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      bg2: bg2 ?? this.bg2,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      txt: txt ?? this.txt,
      txt2: txt2 ?? this.txt2,
      txt3: txt3 ?? this.txt3,
      ok: ok ?? this.ok,
      warn: warn ?? this.warn,
      bad: bad ?? this.bad,
      info: info ?? this.info,
      okTint: okTint ?? this.okTint,
      warnTint: warnTint ?? this.warnTint,
      badTint: badTint ?? this.badTint,
      infoTint: infoTint ?? this.infoTint,
      neutralTint: neutralTint ?? this.neutralTint,
      accent: accent ?? this.accent,
      accentTint: accentTint ?? this.accentTint,
      shadow: shadow ?? this.shadow,
      glow: glow ?? this.glow,
      ambient: ambient ?? this.ambient,
      watermarkOpacity: watermarkOpacity ?? this.watermarkOpacity,
      grainOpacity: grainOpacity ?? this.grainOpacity,
      cardGradient: cardGradient ?? this.cardGradient,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  VColors lerp(ThemeExtension<VColors>? other, double t) {
    if (other is! VColors) return this;
    // Brightness and the texture opacities cross at the halfway point rather
    // than interpolating: a half-lerped grain reads as a glitch, and the
    // theme-switch animation is short enough that the snap is invisible.
    return VColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: Color.lerp(bg, other.bg, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      txt: Color.lerp(txt, other.txt, t)!,
      txt2: Color.lerp(txt2, other.txt2, t)!,
      txt3: Color.lerp(txt3, other.txt3, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      bad: Color.lerp(bad, other.bad, t)!,
      info: Color.lerp(info, other.info, t)!,
      okTint: Color.lerp(okTint, other.okTint, t)!,
      warnTint: Color.lerp(warnTint, other.warnTint, t)!,
      badTint: Color.lerp(badTint, other.badTint, t)!,
      infoTint: Color.lerp(infoTint, other.infoTint, t)!,
      neutralTint: Color.lerp(neutralTint, other.neutralTint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      shadow: t < 0.5 ? shadow : other.shadow,
      glow: t < 0.5 ? glow : other.glow,
      ambient: t < 0.5 ? ambient : other.ambient,
      watermarkOpacity: t < 0.5 ? watermarkOpacity : other.watermarkOpacity,
      grainOpacity: t < 0.5 ? grainOpacity : other.grainOpacity,
      cardGradient: LinearGradient.lerp(cardGradient, other.cardGradient, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}
