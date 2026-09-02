import 'package:flutter/material.dart';

/// The three processed brand variants, and where each is allowed to appear.
///
/// Placements are FIXED by the design system. Listing them here (rather than
/// leaving each screen to choose) is what keeps the mark from creeping into
/// places that would cheapen it.
abstract final class VBrand {
  /// S mark, 360px — splash orbit loader, route-change loader, page watermark,
  /// card bottom-right corner accent, sidebar brand glyph.
  static const String mark = 'assets/images/logo_mark_360.png';

  /// S mark, 140px — small UI spots (login mini-mark, compact app bar).
  static const String markSmall = 'assets/images/logo_mark_140.png';

  /// Wordmark, 486px wide — splash screen and the login left panel ONLY.
  static const String wordmark = 'assets/images/logo_wordmark_486.png';

  /// Warms the image cache before the splash paints.
  ///
  /// Without this the orbit loader's S pops in a frame or two late — on the very
  /// first screen the user ever sees, which is exactly where a stutter reads as
  /// "cheap app".
  static Future<void> precache(BuildContext context) async {
    await Future.wait([
      precacheImage(const AssetImage(mark), context),
      precacheImage(const AssetImage(markSmall), context),
      precacheImage(const AssetImage(wordmark), context),
    ]);
  }
}
