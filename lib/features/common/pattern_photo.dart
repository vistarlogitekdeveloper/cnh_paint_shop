import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../../design/design.dart';

/// The numbered nesting-pattern photograph the operator confirms against the
/// frame they just hung or are about to load. Loaded from the pattern-master
/// library bundled with the app; if a code has no photo (imported later, or a
/// one-off special) the widget renders nothing — no error, no empty gap.
///
/// Reused between the Pattern Runs screen and both Daily Nesting modes so the
/// same picture appears wherever the operator has a pattern in hand.
class PatternPhoto extends StatelessWidget {
  const PatternPhoto({super.key, required this.pattern, this.caption});

  final Pattern pattern;

  /// Optional label under the picture — e.g. the pattern's shade — so the
  /// operator sees the same identifiers the paper sheet carries.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final asset = patternPhotoAsset(pattern.code);
    if (asset == null) return const SizedBox.shrink();
    final v = context.v;

    return Semantics(
      label: 'Nesting pattern photo for ${pattern.code}',
      image: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: VRadius.allSm,
        child: InkWell(
          borderRadius: VRadius.allSm,
          onTap: () => _showFullscreen(context, asset),
          child: Container(
            decoration: BoxDecoration(
              color: v.surface2,
              borderRadius: VRadius.allSm,
              border: Border.all(color: v.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.asset(asset, fit: BoxFit.contain),
                    ),
                    Positioned(
                      right: VSpace.xs,
                      top: VSpace.xs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: VSpace.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: v.surface.withValues(alpha: 0.82),
                          borderRadius: VRadius.allSm,
                          border: Border.all(color: v.line2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_out_map_rounded, size: 12, color: v.txt2),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to enlarge',
                              style: context.text.labelSmall?.copyWith(
                                color: v.txt2,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (caption != null && caption!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: VSpace.sm,
                      vertical: VSpace.xs,
                    ),
                    decoration: BoxDecoration(
                      color: v.surface,
                      border: Border(top: BorderSide(color: v.line)),
                    ),
                    child: Text(
                      caption!,
                      style: context.text.labelSmall?.copyWith(
                        color: v.txt2,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showFullscreen(BuildContext context, String asset) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(VSpace.md),
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(child: Image.asset(asset, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pattern code → bundled photograph. Extracted from the plant's issued
/// nesting-pattern decks under `D:\Vistar\CNH Plant Operations\`:
///
/// * **TR** — `Carraro Tractor Nesting Pattern Rev-7 March-26.pdf` → TRT-01..09
/// * **ID-10** — `ID-10 & Domestic Cabin Nesting Pattern_Rev 4 Feb'26.pdf`
///               → ID10Cab-01..08 + Straw Walker Domestic Cabin-01
/// * **BLR (Baler)** — `Baler Nesting Pattern-Rev 05_March'26.pdf` → BLR-01..12
/// * **SCH** — `SCH Nesting Pattern Rev8 March'26.pdf` → SCH-01..33
/// * **RTV (Rotavator)** — `RTR HD/XHD NESTING PATTERN.pptx` → RTR-01/02
///
/// Keys are normalised (uppercase, alphanumerics only) so `TRT-01`, `TRT 01`
/// and `trt01` all resolve to the same asset. The map also carries a few
/// aliases: the seeded ID-10 pattern is a bare `'1'`, the sheets call it
/// `ID10Cab-01`, and both should hit the same photo.
const Map<String, String> _patternPhotoAssets = {
  // ---- TR (Carraro Tractor) ----
  'TRT01': 'assets/patterns/TRT-01.jpg',
  'TRT02': 'assets/patterns/TRT-02.jpg',
  'TRT03': 'assets/patterns/TRT-03.jpg',
  'TRT04': 'assets/patterns/TRT-04.jpg',
  'TRT05': 'assets/patterns/TRT-05.jpg',
  'TRT06': 'assets/patterns/TRT-06.jpg',
  'TRT07': 'assets/patterns/TRT-07.jpg',
  'TRT08': 'assets/patterns/TRT-08.jpg',
  'TRT09': 'assets/patterns/TRT-09.jpg',

  // ---- ID-10 Cabin ----
  'ID10CAB01': 'assets/patterns/ID10Cab-01.jpg',
  'ID10CAB02': 'assets/patterns/ID10Cab-02.jpg',
  'ID10CAB03': 'assets/patterns/ID10Cab-03.jpg',
  'ID10CAB04': 'assets/patterns/ID10Cab-04.jpg',
  'ID10CAB05': 'assets/patterns/ID10Cab-05.jpg',
  'ID10CAB06': 'assets/patterns/ID10Cab-06.jpg',
  'ID10CAB07': 'assets/patterns/ID10Cab-07.jpg',
  'ID10CAB08': 'assets/patterns/ID10Cab-08.jpg',
  'STRAWWALKERDOMESTICCABIN01':
      'assets/patterns/StrawWalkerDomesticCabin-01.jpg',
  // Seed calls the first ID-10 pattern simply "1".
  '1': 'assets/patterns/ID10Cab-01.jpg',

  // ---- BLR (Baler) ----
  'BLR01': 'assets/patterns/BLR-01.jpg',
  'BLR02': 'assets/patterns/BLR-02.jpg',
  'BLR03': 'assets/patterns/BLR-03.jpg',
  'BLR04': 'assets/patterns/BLR-04.jpg',
  'BLR05': 'assets/patterns/BLR-05.jpg',
  'BLR06': 'assets/patterns/BLR-06.jpg',
  'BLR07': 'assets/patterns/BLR-07.jpg',
  'BLR08': 'assets/patterns/BLR-08.jpg',
  'BLR09': 'assets/patterns/BLR-09.jpg',
  'BLR10': 'assets/patterns/BLR-10.jpg',
  'BLR11': 'assets/patterns/BLR-11.jpg',
  'BLR12': 'assets/patterns/BLR-12.jpg',

  // ---- SCH ----
  'SCH01': 'assets/patterns/SCH-01.jpg',
  'SCH02': 'assets/patterns/SCH-02.jpg',
  'SCH03': 'assets/patterns/SCH-03.jpg',
  'SCH04': 'assets/patterns/SCH-04.jpg',
  'SCH05': 'assets/patterns/SCH-05.jpg',
  'SCH06': 'assets/patterns/SCH-06.jpg',
  'SCH07': 'assets/patterns/SCH-07.jpg',
  'SCH08': 'assets/patterns/SCH-08.jpg',
  'SCH09': 'assets/patterns/SCH-09.jpg',
  'SCH10': 'assets/patterns/SCH-10.jpg',
  'SCH11': 'assets/patterns/SCH-11.jpg',
  'SCH12': 'assets/patterns/SCH-12.jpg',
  'SCH13': 'assets/patterns/SCH-13.jpg',
  'SCH14': 'assets/patterns/SCH-14.jpg',
  'SCH15': 'assets/patterns/SCH-15.jpg',
  'SCH16': 'assets/patterns/SCH-16.jpg',
  'SCH17': 'assets/patterns/SCH-17.jpg',
  'SCH18': 'assets/patterns/SCH-18.jpg',
  'SCH19': 'assets/patterns/SCH-19.jpg',
  'SCH20': 'assets/patterns/SCH-20.jpg',
  'SCH21': 'assets/patterns/SCH-21.jpg',
  'SCH22': 'assets/patterns/SCH-22.jpg',
  'SCH23': 'assets/patterns/SCH-23.jpg',
  'SCH24': 'assets/patterns/SCH-24.jpg',
  'SCH25': 'assets/patterns/SCH-25.jpg',
  'SCH26': 'assets/patterns/SCH-26.jpg',
  'SCH27': 'assets/patterns/SCH-27.jpg',
  'SCH28': 'assets/patterns/SCH-28.jpg',
  'SCH29': 'assets/patterns/SCH-29.jpg',
  'SCH30': 'assets/patterns/SCH-30.jpg',
  'SCH31': 'assets/patterns/SCH-31.jpg',
  'SCH32': 'assets/patterns/SCH-32.jpg',
  'SCH33': 'assets/patterns/SCH-33.jpg',

  // ---- RTV (Rotavator) ----
  'RTR01': 'assets/patterns/RTR-01.jpg',
  'RTR02': 'assets/patterns/RTR-02.jpg',
  'RTR01XHD': 'assets/patterns/RTR-01-XHD.jpg',
  'RTR02XHD': 'assets/patterns/RTR-02-XHD.jpg',
};

String? patternPhotoAsset(String code) {
  final key = code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  return _patternPhotoAssets[key];
}
