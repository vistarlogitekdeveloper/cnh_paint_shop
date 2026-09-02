import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../../router/app_router.dart';

/// The navigation model.
///
/// Declared as data rather than built inline in the sidebar so that the SRS's
/// role→screen mapping is readable in one place, and so the same list drives
/// both the desktop sidebar and the phone bottom bar without them drifting.
@immutable
class NavItem {
  const NavItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.permission,
    this.shortLabel,
    this.badgeKind,
  });

  final String route;
  final String label;

  /// For the phone bottom bar, where "Shortage Matrix" will not fit.
  final String? shortLabel;

  final IconData icon;

  /// The permission required to see it. Matches the router's guard, so a visible
  /// item is always a reachable one.
  final String permission;

  final NavBadge? badgeKind;

  String get compactLabel => shortLabel ?? label;
}

/// Which live counter decorates an item.
enum NavBadge { alerts, approvals, pendingSync }

@immutable
class NavGroup {
  const NavGroup({required this.title, required this.items});

  final String title;
  final List<NavItem> items;
}

/// The full navigation, in the order the SRS lists the screens.
const List<NavGroup> kNavGroups = [
  NavGroup(
    title: 'Overview',
    items: [
      NavItem(
        route: Routes.dashboard,
        label: 'Dashboard',
        icon: Icons.space_dashboard_rounded,
        permission: Perm.dashboardView,
      ),
      NavItem(
        route: Routes.alerts,
        label: 'Alerts',
        icon: Icons.notifications_active_rounded,
        permission: Perm.alertView,
        badgeKind: NavBadge.alerts,
      ),
    ],
  ),
  NavGroup(
    title: 'Shortage',
    items: [
      NavItem(
        route: Routes.matrix,
        label: 'Shortage Matrix',
        shortLabel: 'Matrix',
        icon: Icons.grid_on_rounded,
        permission: Perm.matrixView,
      ),
      NavItem(
        route: Routes.coverage,
        label: 'Part Coverage',
        shortLabel: 'Coverage',
        icon: Icons.inventory_2_rounded,
        permission: Perm.coverageView,
      ),
      NavItem(
        route: Routes.canBuild,
        label: 'Can I build?',
        shortLabel: 'Can build',
        icon: Icons.fact_check_rounded,
        permission: Perm.coverageView,
      ),
      NavItem(
        route: Routes.lookup,
        label: 'Part / Rack Lookup',
        shortLabel: 'Lookup',
        icon: Icons.search_rounded,
        permission: Perm.partView,
      ),
    ],
  ),
  NavGroup(
    title: 'Shop floor',
    items: [
      NavItem(
        route: Routes.nesting,
        label: 'Daily Nesting',
        shortLabel: 'Nesting',
        icon: Icons.move_to_inbox_rounded,
        permission: Perm.nestingCreate,
      ),
      NavItem(
        route: Routes.runs,
        label: 'Pattern Runs',
        shortLabel: 'Runs',
        icon: Icons.dynamic_feed_rounded,
        permission: Perm.runCreate,
      ),
      NavItem(
        route: Routes.patterns,
        label: 'Patterns',
        icon: Icons.view_module_rounded,
        permission: Perm.patternView,
      ),
    ],
  ),
  NavGroup(
    title: 'Planning',
    items: [
      NavItem(
        route: Routes.plan,
        label: 'Machine Plan',
        shortLabel: 'Plan',
        icon: Icons.timeline_rounded,
        permission: Perm.machineView,
      ),
      NavItem(
        route: Routes.approvals,
        label: 'Approvals',
        icon: Icons.approval_rounded,
        permission: Perm.requestApprove,
        badgeKind: NavBadge.approvals,
      ),
      NavItem(
        route: Routes.requests,
        label: 'Spares (SPD)',
        shortLabel: 'Requests',
        icon: Icons.outbox_rounded,
        permission: Perm.requestView,
      ),
    ],
  ),
  NavGroup(
    title: 'Records',
    items: [
      NavItem(
        route: Routes.reports,
        label: 'Reports',
        icon: Icons.summarize_rounded,
        permission: Perm.reportView,
      ),
      NavItem(
        route: Routes.admin,
        label: 'Admin & Setup',
        shortLabel: 'Admin',
        icon: Icons.settings_rounded,
        permission: Perm.masterManage,
      ),
    ],
  ),
];

/// The groups this user can actually see, with empty groups dropped.
List<NavGroup> navGroupsFor(AppUser? user) {
  if (user == null) return const [];
  return navGroupsForPermissions(user.permissions);
}

/// The same filter, driven by a bare permission set.
///
/// Exists so the login screen's role legend can show what a role opens without
/// inventing a second copy of the mapping — one filter, so the preview and the
/// real sidebar cannot disagree.
List<NavGroup> navGroupsForPermissions(Set<String> permissions) {
  final out = <NavGroup>[];
  for (final group in kNavGroups) {
    final items = group.items.where((i) => permissions.contains(i.permission)).toList();
    if (items.isNotEmpty) out.add(NavGroup(title: group.title, items: items));
  }
  return out;
}

/// The nav item that owns a route, or null if the route has no sidebar entry.
NavItem? navItemForRoute(String route) {
  for (final group in kNavGroups) {
    for (final item in group.items) {
      if (item.route == route) return item;
    }
  }
  return null;
}

/// A flat list, for the phone bottom bar.
///
/// Capped at five: more than that and the labels become unreadable at phone
/// width. The rest stay reachable from the "More" sheet.
List<NavItem> primaryNavFor(AppUser? user, {int max = 5}) {
  final all = navGroupsFor(user).expand((g) => g.items).toList();
  return all.take(max).toList();
}

List<NavItem> overflowNavFor(AppUser? user, {int skip = 5}) {
  final all = navGroupsFor(user).expand((g) => g.items).toList();
  return all.length > skip ? all.sublist(skip) : const [];
}
