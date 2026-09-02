import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/design.dart';
import '../../providers/providers.dart';
import '../../router/app_router.dart';
import 'nav_items.dart';
import 'sidebar.dart';
import 'topbar.dart';

/// ---------------------------------------------------------------------------
/// The app shell: `grid-template-columns: 248px 1fr` on desktop, a bottom bar on
/// a phone. Holds the ambient background, the sidebar, the topbar, the offline
/// banner and the route-change loader, so a screen only ever renders its own
/// content.
///
/// The route loader flashes for ~360ms on every screen switch, exactly as the
/// design system specifies. It is not decoration: several screens (matrix,
/// coverage, dashboard) need a server round-trip before they have anything to
/// draw, and the loader covers that beat instead of showing an empty layout.
/// ---------------------------------------------------------------------------
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _routeLoading = false;
  String? _lastLocation;

  /// Collapsed sidebar (icons only) on tablet widths, remembered for the session.
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < VBreak.phone;
    final isCompact = width < VBreak.tablet;

    _watchRouteChanges();

    final user = ref.watch(currentUserProvider);
    if (user == null) {
      // Mid-logout: the router is about to redirect. Painting the ambient
      // background keeps the transition from flashing white.
      return const Scaffold(body: AmbientBackground());
    }

    return Scaffold(
      // On a phone the sidebar becomes a drawer, so the shop-floor screens keep
      // their full width for the entry grid.
      drawer: isPhone ? Drawer(child: AppSidebar(onNavigate: () => Navigator.pop(context))) : null,
      body: AmbientBackground(
        // The watermark is turned off on the dense data screens: even at 5%,
        // a rotated S behind a 40-column grid is noise rather than atmosphere.
        showWatermark: !_isDenseScreen,
        child: SafeArea(
          child: Row(
            children: [
              if (!isPhone)
                AppSidebar(
                  collapsed: isCompact || _sidebarCollapsed,
                  onToggleCollapse: isCompact
                      ? null
                      : () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                ),
              Expanded(
                child: Column(
                  children: [
                    AppTopbar(showMenuButton: isPhone),
                    const _OfflineBannerSlot(),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(child: widget.child),
                          // The route-change overlay, above the canvas but below
                          // the topbar so the header never flickers.
                          if (_routeLoading)
                            const Positioned.fill(child: RouteLoader(visible: true)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: isPhone ? const _PhoneNavBar() : null,
    );
  }

  bool get _isDenseScreen {
    final location = GoRouterState.of(context).matchedLocation;
    return location == Routes.matrix || location == Routes.plan || location == Routes.coverage;
  }

  /// Flashes the route loader when the location changes.
  void _watchRouteChanges() {
    final location = GoRouterState.of(context).matchedLocation;
    if (_lastLocation != null && _lastLocation != location) {
      // Scheduled off the build: setState during build is illegal, and the
      // loader only needs to appear on the NEXT frame anyway.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _routeLoading = true);
        Future.delayed(VMotion.routeLoader, () {
          if (mounted) setState(() => _routeLoading = false);
        });
      });
    }
    _lastLocation = location;
  }
}

/// Shows the offline banner only when it has something to say.
class _OfflineBannerSlot extends ConsumerWidget {
  const _OfflineBannerSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).valueOrNull;
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;

    final offline = status != null && !status.online;
    // Also shown when ONLINE but with a backlog — otherwise a queue that failed
    // to upload would be invisible, which is how an entry gets lost.
    final show = offline || pending > 0;

    return AnimatedSize(
      duration: VMotion.base,
      curve: VMotion.enter,
      child: show
          ? VOfflineBanner(
              pendingCount: pending,
              syncing: status?.syncing ?? false,
              onSyncNow: offline ? null : () => ref.read(syncServiceProvider).flush(force: true),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

/// The phone bottom bar. Five primary destinations; the rest live behind "More".
class _PhoneNavBar extends ConsumerWidget {
  const _PhoneNavBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final user = ref.watch(currentUserProvider);
    final items = primaryNavFor(user, max: 4);
    final overflow = overflowNavFor(user, skip: 4);
    final location = GoRouterState.of(context).matchedLocation;

    final badges = ref.watch(badgeCountsProvider).valueOrNull;
    final pendingSync = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;

    int? badgeFor(NavBadge? kind) => switch (kind) {
          NavBadge.alerts => badges?.totalAlerts,
          NavBadge.approvals => badges?.pendingApprovals,
          NavBadge.pendingSync => pendingSync,
          null => null,
        };

    return Container(
      decoration: BoxDecoration(
        color: v.bg2,
        border: Border(top: BorderSide(color: v.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (final item in items)
                Expanded(
                  child: _PhoneNavButton(
                    item: item,
                    selected: location == item.route,
                    badge: badgeFor(item.badgeKind),
                    onTap: () => context.go(item.route),
                  ),
                ),
              if (overflow.isNotEmpty)
                Expanded(
                  child: _PhoneNavButton(
                    item: const NavItem(
                      route: '',
                      label: 'More',
                      icon: Icons.more_horiz_rounded,
                      permission: '',
                    ),
                    selected: overflow.any((i) => i.route == location),
                    onTap: () => _showMoreSheet(context, ref, overflow, location),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreSheet(
    BuildContext context,
    WidgetRef ref,
    List<NavItem> items,
    String location,
  ) {
    final v = context.v;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: v.bg2,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: VSpace.lg),
              child: VSectionTitle(title: 'More screens'),
            ),
            for (final item in items)
              ListTile(
                leading: Icon(
                  item.icon,
                  color: item.route == location ? v.accent : v.txt3,
                ),
                title: Text(item.label),
                selected: item.route == location,
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go(item.route);
                },
              ),
            const SizedBox(height: VSpace.md),
          ],
        ),
      ),
    );
  }
}

class _PhoneNavButton extends StatelessWidget {
  const _PhoneNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final color = selected ? v.accent : v.txt3;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(item.icon, size: 22, color: color),
              if (badge != null && badge! > 0)
                Positioned(
                  top: -4,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 15),
                    decoration: BoxDecoration(
                      color: v.bad,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: v.bg2, width: 1.5),
                    ),
                    child: Text(
                      badge! > 9 ? '9+' : '$badge',
                      textAlign: TextAlign.center,
                      style: context.text.labelSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            item.compactLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: color,
              fontSize: 10,
              letterSpacing: 0.1,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          // A 2px ribbon underline on the active item, echoing the sidebar's
          // 3px left bar.
          const SizedBox(height: 3),
          Container(
            width: selected ? 18 : 0,
            height: 2,
            decoration: const BoxDecoration(
              gradient: VRibbon.bar,
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
        ],
      ),
    );
  }
}
