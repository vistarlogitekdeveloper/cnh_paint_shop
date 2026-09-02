import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/design.dart';
import '../../providers/providers.dart';
import '../../router/app_router.dart';
import 'nav_items.dart';

/// The 248px sidebar: brand row, grouped nav with uppercase group labels, and a
/// user block in the footer.
///
/// The active item is the design system's signature: a soft ribbon tint plus a
/// 3px ribbon bar on the leading edge.
class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    this.collapsed = false,
    this.onToggleCollapse,
    this.onNavigate,
  });

  /// Icons only, for tablet widths where 248px is too much of a phone-sized
  /// screen to give to navigation.
  final bool collapsed;

  final VoidCallback? onToggleCollapse;

  /// Called after a tap, so the phone drawer can close itself.
  final VoidCallback? onNavigate;

  static const double expandedWidth = 248;
  static const double collapsedWidth = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final user = ref.watch(currentUserProvider);
    final groups = navGroupsFor(user);
    final location = GoRouterState.of(context).matchedLocation;

    final badges = ref.watch(badgeCountsProvider).valueOrNull;
    final pendingSync = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;

    int? badgeFor(NavBadge? kind) => switch (kind) {
          NavBadge.alerts => badges?.totalAlerts,
          NavBadge.approvals => badges?.pendingApprovals,
          NavBadge.pendingSync => pendingSync,
          null => null,
        };

    return AnimatedContainer(
      duration: VMotion.base,
      curve: VMotion.enter,
      width: collapsed ? collapsedWidth : expandedWidth,
      decoration: BoxDecoration(
        color: v.bg2,
        border: Border(right: BorderSide(color: v.line)),
      ),
      child: Column(
        children: [
          _BrandRow(collapsed: collapsed, onToggleCollapse: onToggleCollapse),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: VSpace.sm),
              children: [
                for (final group in groups) ...[
                  if (!collapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(VSpace.lg, VSpace.md, VSpace.lg, VSpace.xs),
                      child: Text(
                        group.title.toUpperCase(),
                        style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 10),
                      ),
                    )
                  else
                    // A hairline stands in for the group label when collapsed, so
                    // the grouping is still legible without text.
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: VSpace.lg,
                        vertical: VSpace.sm,
                      ),
                      child: Container(height: 1, color: v.line),
                    ),
                  for (final item in group.items)
                    _NavTile(
                      item: item,
                      active: location == item.route,
                      collapsed: collapsed,
                      badge: badgeFor(item.badgeKind),
                      onTap: () {
                        context.go(item.route);
                        onNavigate?.call();
                      },
                    ),
                ],
                if (pendingSync > 0) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: VSpace.lg,
                      vertical: VSpace.sm,
                    ),
                    child: Container(height: 1, color: v.line),
                  ),
                  _NavTile(
                    item: const NavItem(
                      route: Routes.syncQueue,
                      label: 'Waiting to sync',
                      shortLabel: 'Sync',
                      icon: Icons.cloud_upload_rounded,
                      permission: '',
                      badgeKind: NavBadge.pendingSync,
                    ),
                    active: location == Routes.syncQueue,
                    collapsed: collapsed,
                    badge: pendingSync,
                    onTap: () {
                      context.go(Routes.syncQueue);
                      onNavigate?.call();
                    },
                  ),
                ],
                const SizedBox(height: VSpace.lg),
              ],
            ),
          ),
          _UserFooter(collapsed: collapsed),
        ],
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.collapsed, this.onToggleCollapse});

  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: collapsed ? VSpace.lg : VSpace.lg),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: v.line)),
      ),
      child: Row(
        children: [
          // The sidebar brand glyph — one of the design system's fixed S
          // placements.
          Image.asset(VBrand.markSmall, width: 26, height: 26),
          if (!collapsed) ...[
            const SizedBox(width: VSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Vistar',
                    style: VType.display(size: 17, weight: FontWeight.w800, color: v.txt),
                  ),
                  Text(
                    'CNH Paint Shop',
                    style: context.text.labelSmall?.copyWith(
                      color: v.txt3,
                      fontSize: 9.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (onToggleCollapse != null)
              VIconButton(
                icon: Icons.menu_open_rounded,
                size: 30,
                iconSize: 16,
                filled: false,
                tooltip: 'Collapse sidebar',
                onPressed: onToggleCollapse,
              ),
          ],
        ],
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.item,
    required this.active,
    required this.collapsed,
    required this.onTap,
    this.badge,
  });

  final NavItem item;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;
  final int? badge;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final active = widget.active;
    final color = active ? v.txt : (_hovered ? v.txt2 : v.txt3);

    Widget tile = AnimatedContainer(
      duration: VMotion.fast,
      curve: VMotion.enter,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: VSpace.sm, vertical: 1.5),
      decoration: BoxDecoration(
        // The active item's soft ribbon tint. A full ribbon fill here would
        // break the restraint rule — the canvas has to stay quiet.
        color: active
            ? v.accentTint
            : (_hovered ? v.surface2 : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          if (active)
            Positioned(
              left: 0,
              top: 9,
              bottom: 9,
              child: Container(
                width: 3,
                decoration: const BoxDecoration(
                  gradient: VRibbon.bar,
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : VSpace.md),
            child: Row(
              mainAxisAlignment:
                  widget.collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(widget.item.icon, size: 19, color: active ? v.accent : color),
                if (!widget.collapsed) ...[
                  const SizedBox(width: VSpace.md),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium?.copyWith(
                        color: color,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  if (widget.badge != null && widget.badge! > 0) _CountBadge(count: widget.badge!),
                ],
              ],
            ),
          ),
          // Collapsed: the count becomes a dot, since there is no room for a
          // number beside the icon.
          if (widget.collapsed && widget.badge != null && widget.badge! > 0)
            Positioned(
              top: 8,
              right: 16,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: v.bad,
                  shape: BoxShape.circle,
                  border: Border.all(color: v.bg2, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.collapsed) {
      tile = Tooltip(message: widget.item.label, child: tile);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(onTap: widget.onTap, child: tile),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20),
      decoration: BoxDecoration(
        color: v.badTint,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: context.text.labelSmall?.copyWith(
          color: v.bad,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// The footer user block, with the ribbon avatar.
class _UserFooter extends ConsumerWidget {
  const _UserFooter({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.v;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(VSpace.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: v.line)),
      ),
      child: collapsed
          ? Center(
              child: Tooltip(
                message: '${user.fullName}\n${user.role.label}',
                child: VAvatar(name: user.fullName, size: 34),
              ),
            )
          : Row(
              children: [
                VAvatar(name: user.fullName, size: 36),
                const SizedBox(width: VSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(fontSize: 13),
                      ),
                      Text(
                        user.role.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: v.txt3, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                VIconButton(
                  icon: Icons.logout_rounded,
                  size: 32,
                  iconSize: 15,
                  filled: false,
                  tooltip: 'Log out',
                  onPressed: () => _confirmLogout(context, ref),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final pending = ref.read(pendingSyncCountProvider).valueOrNull ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(
          pending > 0
              // This matters: logging out wipes the local queue, so an operator
              // with unsynced entries must be told before, not after.
              ? 'You have $pending ${pending == 1 ? 'entry' : 'entries'} still waiting to sync. '
                  'Logging out will discard them. Sync first if you can.'
              : 'You will need your employee code and password to sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay signed in'),
          ),
          if (pending > 0)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
                ref.read(syncServiceProvider).flush(force: true);
              },
              child: const Text('Sync now'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: context.v.bad),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final wiped = await ref.read(authControllerProvider.notifier).logout();
    // The router's redirect tears the shell down as soon as the status flips,
    // so this widget is usually gone by now — hence the mounted check before
    // touching its context.
    if (!wiped && context.mounted) {
      VToast.warning(
        context,
        'Signed out',
        detail: 'Entries stored on this device could not be cleared.',
      );
    }
  }
}
