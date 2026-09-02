import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// ---------------------------------------------------------------------------
/// Typography.
///
///   Bricolage Grotesque → all display text: h1–h4, page titles, KPI numbers,
///                         brand name. letter-spacing −0.4.
///   Manrope             → all body, labels, table text, inputs.
///                         letter-spacing +0.1.
///
/// google_fonts resolves both at runtime and caches them. A shop-floor tablet
/// with no internet falls back to the platform sans, which is why every style
/// here also sets an explicit [fontFamilyFallback] — without it the fallback
/// picks up a serif on some Android builds and the whole app changes character.
/// ---------------------------------------------------------------------------
abstract final class VType {
  static const List<String> _fallback = [
    'Segoe UI',
    'Roboto',
    'SF Pro Text',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  /// Display face — page titles, KPI numbers, the brand wordmark in the sidebar.
  static TextStyle display({
    required double size,
    FontWeight weight = FontWeight.w800,
    Color? color,
    double? height,
    double letterSpacing = -0.4,
  }) {
    return GoogleFonts.bricolageGrotesque(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    ).copyWith(fontFamilyFallback: _fallback);
  }

  /// Body face — everything else.
  static TextStyle body({
    required double size,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
    double letterSpacing = 0.1,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    ).copyWith(fontFamilyFallback: _fallback);
  }

  /// Tabular figures for grids and KPI numbers.
  ///
  /// The shortage matrix is columns of changing numbers; without tabular
  /// spacing the digits jitter horizontally on every refresh and the eye cannot
  /// scan down a column. This matters more here than almost anywhere else in
  /// the app.
  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    ).copyWith(fontFamilyFallback: _fallback);
  }

  /// The uppercase micro-label used on table headers and sidebar group titles.
  static TextStyle overline({Color? color, double size = 11}) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: 0.6,
    ).copyWith(fontFamilyFallback: _fallback);
  }

  /// Builds the Material text theme so stock widgets inherit the right faces
  /// even where this app does not style them explicitly.
  static TextTheme themeFor(VColors c) {
    return TextTheme(
      displayLarge: display(size: 44, color: c.txt, height: 1.05),
      displayMedium: display(size: 36, color: c.txt, height: 1.08),
      displaySmall: display(size: 30, color: c.txt, height: 1.1),
      headlineLarge: display(size: 27, color: c.txt, height: 1.15),
      headlineMedium: display(size: 23, color: c.txt, height: 1.2),
      headlineSmall: display(size: 19, weight: FontWeight.w700, color: c.txt, height: 1.25),
      titleLarge: display(size: 17, weight: FontWeight.w700, color: c.txt),
      titleMedium: body(size: 15, weight: FontWeight.w700, color: c.txt),
      titleSmall: body(size: 13.5, weight: FontWeight.w700, color: c.txt),
      bodyLarge: body(size: 15, color: c.txt2, height: 1.5),
      bodyMedium: body(size: 14, color: c.txt2, height: 1.5),
      bodySmall: body(size: 12.5, color: c.txt3, height: 1.45),
      labelLarge: body(size: 14, weight: FontWeight.w700, color: c.txt),
      labelMedium: body(size: 12.5, weight: FontWeight.w600, color: c.txt2),
      labelSmall: overline(color: c.txt3),
    );
  }
}
