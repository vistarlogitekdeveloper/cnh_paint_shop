import '../../data/models/models.dart';
import '../../router/app_router.dart';
import '../shell/nav_items.dart';

/// What each role opens — for the signed-out legend on the login screen.
///
/// **This gates nothing.** The authoritative permission set arrives with the
/// login response (`AppUser.permissions`) and the landing route with it
/// (`AppUser.defaultRoute`); both come from the backend's `config/roles.js`, and
/// the server enforces the matrix independently. This mirror exists only so an
/// operator who has not signed in yet can check the app knows their job before
/// they type a code — a legend, not a role picker.
///
/// Keep it in step with `config/roles.js` if that matrix ever changes. If it
/// drifts, the cost is a slightly wrong preview on the login screen, never a
/// wrongly granted screen.
abstract final class RoleScreens {
  /// Granted to everyone who can log in. The Viewer role gets exactly this.
  static const Set<String> _readOnly = {
    Perm.dashboardView,
    Perm.coverageView,
    Perm.matrixView,
    Perm.partView,
    Perm.patternView,
    Perm.machineView,
    Perm.nestingView,
    Perm.runView,
    Perm.requestView,
    Perm.alertView,
    Perm.reportView,
  };

  static const Map<UserRole, Set<String>> _permissions = {
    UserRole.viewer: _readOnly,

    UserRole.nestingOperator: {..._readOnly, Perm.nestingCreate},

    UserRole.loadingOperator: {..._readOnly, Perm.runCreate},

    UserRole.supervisor: {
      ..._readOnly,
      Perm.ledgerView,
      Perm.nestingCreate,
      Perm.runCreate,
      Perm.alertAck,
      Perm.requestCreate,
      Perm.machineBuild,
    },

    UserRole.planner: {
      ..._readOnly,
      Perm.ledgerView,
      Perm.alertAck,
      Perm.requestCreate,
      Perm.requestApprove,
      Perm.machineManage,
      Perm.machineBuild,
      Perm.patternManage,
      Perm.thresholdManage,
    },

    // Everything.
    UserRole.admin: {
      ..._readOnly,
      Perm.ledgerView,
      Perm.auditView,
      Perm.nestingCreate,
      Perm.runCreate,
      Perm.alertAck,
      Perm.requestCreate,
      Perm.requestApprove,
      Perm.patternManage,
      Perm.machineManage,
      Perm.machineBuild,
      Perm.masterManage,
      Perm.thresholdManage,
      Perm.stockAdjust,
      Perm.importManage,
      Perm.userManage,
    },
  };

  static const Map<UserRole, String> _landing = {
    UserRole.nestingOperator: Routes.nesting,
    UserRole.loadingOperator: Routes.runs,
    UserRole.supervisor: Routes.dashboard,
    UserRole.planner: Routes.dashboard,
    UserRole.admin: Routes.admin,
    UserRole.viewer: Routes.dashboard,
  };

  static Set<String> permissionsFor(UserRole role) => _permissions[role] ?? _readOnly;

  /// The screens this role opens, in sidebar order. Run through the same filter
  /// the real sidebar uses, so the two cannot disagree.
  static List<NavItem> screensFor(UserRole role) =>
      navGroupsForPermissions(permissionsFor(role)).expand((g) => g.items).toList();

  /// The screen this role lands on after signing in.
  static NavItem? landingFor(UserRole role) {
    final route = _landing[role];
    return route == null ? null : navItemForRoute(route);
  }

  /// A one-line summary of what the role may do beyond reading, or null for the
  /// Viewer, whose whole story is "reads everything, changes nothing".
  static String? writesFor(UserRole role) => switch (role) {
        UserRole.nestingOperator => 'Records nesting receipts',
        UserRole.loadingOperator => 'Records pattern runs',
        UserRole.supervisor => 'Records receipts and runs, acknowledges alerts, raises requests',
        UserRole.planner => 'Owns the machine plan, approves requests, tunes thresholds',
        UserRole.admin => 'Full setup: users, masters, thresholds, imports',
        UserRole.viewer => null,
      };
}
