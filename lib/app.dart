import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/push_service.dart';
import 'design/design.dart';
import 'features/auth/splash_screen.dart';
import 'providers/providers.dart';
import 'router/app_router.dart';

/// The app root.
///
/// Shows the splash for ~2.2s over the real app while the brand assets are
/// precached and the router settles. It is not a stall for its own sake: on a
/// cold start the token read, the master-cache open and the first dashboard
/// fetch all land inside that window, so the first screen the operator sees is
/// already populated.
class CnhPaintShopApp extends ConsumerStatefulWidget {
  const CnhPaintShopApp({super.key});

  @override
  ConsumerState<CnhPaintShopApp> createState() => _CnhPaintShopAppState();
}

class _CnhPaintShopAppState extends ConsumerState<CnhPaintShopApp> {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    // Push wiring needs a BuildContext-free hook into the router, which only
    // exists once the first frame is scheduled.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;

    await VBrand.precache(context);
    if (!mounted) return;

    // Deep-links from a tapped notification are routed through the router the
    // app is actually using, so a push can open the exact alert.
    PushService.attachRouter(
      go: (route) {
        if (!mounted) return;
        ref.read(routerProvider).go(route);
      },
      registerToken: (token) async {
        // The token is stored locally and pushed to the server, but only once
        // there is a session to attach it to.
        await ref.read(tokenStoreProvider).saveFcmToken(token);
        if (ref.read(authControllerProvider).isAuthenticated) {
          try {
            await ref.read(authRepositoryProvider).registerFcmToken(token);
          } catch (_) {
            // Best effort — a failed registration only costs notifications.
          }
        }
      },
    );

    // A push that arrives while the app is open should refresh the badges and
    // the alert list rather than leaving stale numbers on screen.
    PushService.onMessage(() {
      if (!mounted) return;
      ref.invalidate(badgeCountsProvider);
      ref.invalidate(alertsProvider);
      ref.invalidate(dashboardProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'CNH Paint Shop',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: VTheme.light(),
      darkTheme: VTheme.dark(),
      themeMode: themeMode,
      // A gentle theme cross-fade rather than a hard cut when the toggle is used.
      themeAnimationDuration: VMotion.base,
      themeAnimationCurve: VMotion.enter,
      builder: (context, child) {
        return Stack(
          children: [
            // The real app is built underneath the splash, so it is warm and
            // laid out by the time the splash lifts.
            if (child != null) child,
            if (!_splashDone)
              SplashScreen(onComplete: () => setState(() => _splashDone = true)),
          ],
        );
      },
    );
  }
}
