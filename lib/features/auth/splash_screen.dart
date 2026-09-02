import 'package:flutter/material.dart';

import '../../design/design.dart';

/// The splash: radial dark glow, the orbit S loader, the wordmark, an uppercase
/// tagline, and the ribbon progress bar. Auto-hides after ~2.2s.
///
/// Always dark, regardless of theme. The splash is the brand's moment and the
/// ribbon needs a near-black field to read the way it was designed to; a light
/// splash would make the mark look washed out for the two seconds it is the only
/// thing on screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: VMotion.slow,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    // Fade the splash OUT over the already-built app underneath, so the
    // transition is a reveal rather than a cut.
    await _fade.reverse(from: 1);
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, _) {
        if (_fade.value == 0) return const SizedBox.shrink();
        return Opacity(
          opacity: _fade.value,
          child: Theme(
            // Force the dark palette so `context.v` inside resolves dark tokens
            // even when the device is in light mode.
            data: VTheme.dark(),
            child: const _SplashBody(),
          ),
        );
      },
    );
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    final v = context.v;

    return Material(
      color: v.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // A tighter, brighter ambient than the app's: on the splash the glow IS
          // the composition, so the watermark would compete with the orbit mark.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.95,
                colors: [
                  VRibbon.purple.withValues(alpha: 0.26),
                  VRibbon.magenta.withValues(alpha: 0.10),
                  v.bg,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          const AmbientBackground(showWatermark: false),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SOrbitLoader(size: 200),
                const SizedBox(height: VSpace.xxl),
                Image.asset(VBrand.wordmark, width: 232, fit: BoxFit.contain),
                const SizedBox(height: VSpace.md),
                Text(
                  'PAINT SHOP OPERATIONS',
                  style: context.text.labelSmall?.copyWith(
                    color: v.txt3,
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: VSpace.xxl),
                const RibbonBar(width: 200),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: VSpace.xxl,
            child: Column(
              children: [
                Text(
                  'CNH Plant · Paint Shop',
                  style: context.text.bodySmall?.copyWith(color: v.txt3),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vistar Logitek Pvt. Ltd.',
                  style: context.text.labelSmall?.copyWith(
                    color: v.txt3.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
