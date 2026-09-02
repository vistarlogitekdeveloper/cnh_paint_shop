import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/models.dart';
import '../design/design.dart';
import '../features/admin/admin_screen.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/canbuild/can_build_screen.dart';
import '../features/coverage/coverage_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/lookup/lookup_screen.dart';
import '../features/matrix/matrix_screen.dart';
import '../features/nesting/nesting_screen.dart';
import '../features/patterns/patterns_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/requests/requests_screen.dart';
import '../features/runs/runs_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/sync/sync_queue_screen.dart';
import '../providers/providers.dart';

/// ---------------------------------------------------------------------------
/// Routing, with role guards.
///
/// Two guards, both in one redirect so there is a single place to reason about
/// who can be where:
///
///   1. AUTH — no session → /login. A signed-in user on /login → their role's
///      default route (server-driven, from config/roles.js).
///   2. ROLE — a route whose permission the user lacks → their default route,
///      not a 403 screen. A Nesting Operator who deep-links into the Machine
///      Plan should land somewhere useful, not on an apology.
///
/// The server enforces all of this independently; these guards exist so the UI
/// never shows a control that would be refused.
/// ---------------------------------------------------------------------------

abstract final class Routes {
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const matrix = '/matrix';
  static const coverage = '/coverage';
  static const lookup = '/lookup';
  static const patterns = '/patterns';
  static const nesting = '/nesting';
  static const runs = '/pattern-runs';
  static const requests = '/requests';
  static const approvals = '/approvals';
  static const plan = '/plan';
  static const alerts = '/alerts';
  static const reports = '/reports';
  static const canBuild = '/can-build';
  static const admin = '/admin';
  static const syncQueue = '/sync-queue';
}

/// The permission each route needs. A route absent from this map is open to any
/// signed-in user.
const Map<String, String> _routePermissions = {
  Routes.dashboard: Perm.dashboardView,
  Routes.matrix: Perm.matrixView,
  Routes.coverage: Perm.coverageView,
  Routes.lookup: Perm.partView,
  Routes.patterns: Perm.patternView,
  Routes.nesting: Perm.nestingCreate,
  Routes.runs: Perm.runCreate,
  Routes.requests: Perm.requestView,
  Routes.approvals: Perm.requestApprove,
  Routes.plan: Perm.machineView,
  Routes.alerts: Perm.alertView,
  Routes.reports: Perm.reportView,
  Routes.canBuild: Perm.coverageView,
  Routes.admin: Perm.masterManage,
};

/// Rebuilds the router when auth state flips, so a logout tears the shell down
/// immediately instead of leaving a screen mounted over a dead session.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ValueNotifier(0);
  ref.listen(authControllerProvider, (previous, next) {
    if (previous?.status != next.status) notifier.value++;
  });
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: Routes.dashboard,
    refreshListenable: notifier,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.matchedLocation;

      if (!auth.isAuthenticated) {
        return path == Routes.login ? null : Routes.login;
      }

      final user = auth.user!;

      // Already signed in: bounce off login to where this role belongs.
      if (path == Routes.login) return _landing(user);

      final needed = _routePermissions[path];
      if (needed != null && !user.can(needed)) return _landing(user);

      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        pageBuilder: (context, state) => const NoTransitionPage(child: LoginScreen()),
      ),
      // Everything else lives inside the shell (sidebar + topbar + ambient bg).
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          _shellRoute(Routes.dashboard, const DashboardScreen()),
          _shellRoute(Routes.matrix, const MatrixScreen()),
          _shellRoute(Routes.coverage, const CoverageScreen()),
          _shellRoute(Routes.lookup, const LookupScreen()),
          _shellRoute(Routes.patterns, const PatternsScreen()),
          _shellRoute(Routes.nesting, const NestingScreen()),
          _shellRoute(Routes.runs, const RunsScreen()),
          _shellRoute(Routes.requests, const RequestsScreen()),
          // The Planner's inbox is the same screen with the approver lens on —
          // one implementation, two entry points, no drift between them.
          _shellRoute(Routes.approvals, const RequestsScreen(approvalsMode: true)),
          _shellRoute(Routes.plan, const PlanScreen()),
          _shellRoute(Routes.alerts, const AlertsScreen()),
          _shellRoute(Routes.reports, const ReportsScreen()),
          _shellRoute(Routes.canBuild, const CanBuildScreen()),
          _shellRoute(Routes.admin, const AdminScreen()),
          _shellRoute(Routes.syncQueue, const SyncQueueScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => _RouteNotFound(location: state.uri.toString()),
  );
});

/// Where a role belongs. Prefers the server-supplied route and falls back to a
/// permission-derived choice if it is unusable — a client that has been upgraded
/// past the server should still land somewhere it is allowed to be.
String _landing(AppUser user) {
  final serverRoute = user.defaultRoute;
  final needed = _routePermissions[serverRoute];
  if (needed == null || user.can(needed)) return serverRoute;

  if (user.can(Perm.dashboardView)) return Routes.dashboard;
  if (user.can(Perm.nestingCreate)) return Routes.nesting;
  if (user.can(Perm.runCreate)) return Routes.runs;
  return Routes.alerts;
}

/// A shell child with a fade-through transition.
///
/// Fade rather than slide: the sidebar and topbar are persistent, so a sliding
/// canvas reads as the whole app moving. The route loader (see AppShell) covers
/// the same beat.
GoRoute _shellRoute(String path, Widget child) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: VMotion.base,
      reverseTransitionDuration: VMotion.fast,
      transitionsBuilder: (context, animation, secondary, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: VMotion.enter),
          child: SlideTransition(
            // A 10px rise, matching the design system's `@keyframes fade`.
            position: Tween<Offset>(
              begin: const Offset(0, 0.012),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: VMotion.enter)),
            child: child,
          ),
        );
      },
    ),
  );
}

class _RouteNotFound extends ConsumerWidget {
  const _RouteNotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      body: AmbientBackground(
        child: VEmptyState(
          title: 'That screen does not exist',
          message: location,
          icon: Icons.explore_off_rounded,
          actionLabel: 'Go to my home screen',
          onAction: () => context.go(user == null ? Routes.login : _landing(user)),
        ),
      ),
    );
  }
}
