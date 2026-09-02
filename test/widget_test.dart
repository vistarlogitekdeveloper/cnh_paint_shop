import 'package:cnh_paint_shop/core/config/env.dart';
import 'package:cnh_paint_shop/core/db/app_database.dart';
import 'package:cnh_paint_shop/core/network/api_client.dart';
import 'package:cnh_paint_shop/core/storage/token_store.dart';
import 'package:cnh_paint_shop/data/repositories/repositories.dart';
import 'package:drift/drift.dart' show LazyDatabase;
import 'package:cnh_paint_shop/data/models/models.dart';
import 'package:cnh_paint_shop/design/design.dart';
import 'package:cnh_paint_shop/features/auth/login_screen.dart';
import 'package:cnh_paint_shop/features/auth/role_screens.dart';
import 'package:cnh_paint_shop/features/shell/nav_items.dart';
import 'package:cnh_paint_shop/providers/providers.dart';
import 'package:cnh_paint_shop/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests that need no backend, database or signed-in session.
///
/// What is worth testing here is the code where a wrong answer would be
/// invisible: the model layer's tolerance of what Postgres actually sends, the
/// permission map the UI hides controls with, and the status vocabulary that
/// must not drift between screens.
///
/// The coverage engine itself is tested on the backend (`npm run cnh:test`,
/// 29 assertions) because that is where it lives — the client only renders it.
/// Keeps the logout tests off the network. The real implementation already
/// swallows its own failures, so stubbing it changes nothing under test.
class _SilentAuthRepository extends AuthRepository {
  _SilentAuthRepository(super.api);

  @override
  Future<void> logout({String? refreshToken, String? fcmToken}) async {}
}

/// An auth controller that starts already holding a rejection, so the banner
/// can be tested without a server to be rejected by.
class _RejectedAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.unauthenticated,
    error: 'Employee code or password is incorrect.',
  );
}

void main() {
  group('Quantity parsing', () {
    // node-postgres returns NUMERIC as a STRING to avoid silently truncating
    // large values. Every quantity goes through asDouble for exactly that
    // reason; if it regressed, stock would render as 0 across the whole app.
    test('accepts the string form Postgres sends for NUMERIC', () {
      expect(asDouble('225'), 225);
      expect(asDouble('225.500'), 225.5);
      expect(asDouble('-4'), -4);
    });

    test('accepts real numbers unchanged', () {
      expect(asDouble(225), 225);
      expect(asDouble(225.5), 225.5);
    });

    test('falls back rather than throwing on null or junk', () {
      expect(asDouble(null), 0);
      expect(asDouble(''), 0);
      expect(asDouble('not a number'), 0);
      expect(asDouble(null, 7), 7);
    });

    test('asInt truncates rather than rounding', () {
      expect(asInt('3'), 3);
      expect(asInt(3.9), 3);
      expect(asIntOrNull(null), isNull);
    });
  });

  group('Part.fromJson', () {
    test('reads a rack whether it arrives nested or flattened', () {
      // Sequelize `include` gives a nested object; the raw-SQL endpoints give
      // flat columns. Both shapes reach the same screens.
      final nested = Part.fromJson({
        'id': 'p1',
        'unpainted_pn': '47659644',
        'description': 'LEVER',
        'rack': {'code': 'R-A-01', 'zone': 'Zone A'},
      });
      final flat = Part.fromJson({
        'id': 'p1',
        'unpainted_pn': '47659644',
        'description': 'LEVER',
        'rack_code': 'R-A-01',
        'rack_zone': 'Zone A',
      });

      expect(nested.rackCode, 'R-A-01');
      expect(flat.rackCode, 'R-A-01');
      expect(nested.rackZone, 'Zone A');
      expect(flat.rackZone, 'Zone A');
    });

    test('survives a bare master row with no stock context', () {
      final part = Part.fromJson({
        'id': 'p1',
        'unpainted_pn': '47465759',
        'description': 'COVER',
      });

      expect(part.availableStock, 0);
      expect(part.dailyNesting, 0);
      expect(part.patterns, isEmpty);
      expect(part.paintedPn, isNull);
      expect(part.partType, PartType.buy);
    });

    test('displayLabel is what pickers and toasts show', () {
      final part = Part.fromJson({
        'id': 'p1',
        'unpainted_pn': '47465759',
        'description': 'COVER',
      });
      expect(part.displayLabel, '47465759 · COVER');
    });
  });

  group('CoverageRow', () {
    Map<String, dynamic> rowJson({
      String? blocked,
      String? safeUntil,
      int planLength = 300,
      int covered = 225,
    }) => {
      'part': {'id': 'p1', 'unpainted_pn': '47465759', 'description': 'COVER'},
      'qpv': 1,
      'available_stock': '225',
      'machines_covered': covered,
      'safe_until_serial': safeUntil,
      'first_blocked_serial': blocked,
      'plan_length': planLength,
    };

    test('names the wall when the plan blocks', () {
      final row = CoverageRow.fromJson(
        rowJson(blocked: '618', safeUntil: '617'),
      );
      expect(row.horizonLabel, 'Safe up to 617 · runs out at 618');
    });

    test('reads as good news when nothing blocks', () {
      final row = CoverageRow.fromJson(rowJson());
      expect(row.firstBlockedSerial, isNull);
      expect(row.horizonLabel, 'Covered for all 300 planned machines');
    });

    test('says so plainly when the very next machine is blocked', () {
      final row = CoverageRow.fromJson(rowJson(blocked: '393', covered: 0));
      expect(row.horizonLabel, 'Cannot build the next machine (393)');
    });

    test('distinguishes an empty plan from full coverage', () {
      final row = CoverageRow.fromJson(rowJson(planLength: 0));
      expect(row.horizonLabel, 'No machine plan loaded');
    });
  });

  group('Roles and permissions', () {
    test('an unknown role from a newer server degrades to viewer', () {
      // A login must not fail because a role was added server-side.
      expect(UserRole.fromWire('something_new'), UserRole.viewer);
      expect(UserRole.fromWire(null), UserRole.viewer);
    });

    test('known roles map exactly', () {
      expect(UserRole.fromWire('nesting_operator'), UserRole.nestingOperator);
      expect(UserRole.fromWire('planner'), UserRole.planner);
      expect(UserRole.nestingOperator.isOperator, isTrue);
      expect(UserRole.viewer.isReadOnly, isTrue);
      expect(UserRole.supervisor.isOperator, isFalse);
    });

    test('permission checks drive what the UI renders', () {
      final viewer = AppUser.fromJson({
        'id': 'u1',
        'emp_code': 'MGT01',
        'full_name': 'CNH Management Viewer',
        'role': 'viewer',
        'permissions': [Perm.dashboardView, Perm.coverageView, Perm.reportView],
        'default_route': '/dashboard',
      });

      expect(viewer.can(Perm.dashboardView), isTrue);
      expect(viewer.can(Perm.nestingCreate), isFalse);
      expect(viewer.can(Perm.machineBuild), isFalse);
      expect(viewer.canAny([Perm.nestingCreate, Perm.reportView]), isTrue);
      expect(viewer.canAny([Perm.nestingCreate, Perm.userManage]), isFalse);
    });
  });

  group('Login role legend', () {
    // The legend previews a role's screens BEFORE anyone signs in, so it cannot
    // read AppUser.permissions and has to mirror config/roles.js. What is worth
    // testing is that the mirror still agrees with the sidebar and still lands
    // every role somewhere it is allowed to be.

    test('every role opens at least one screen', () {
      for (final role in UserRole.values) {
        expect(RoleScreens.screensFor(role), isNotEmpty, reason: role.wire);
      }
    });

    test('a role always lands on a screen it can actually open', () {
      // The router bounces a user off a route they lack; if a landing route
      // were not in the role's own screen list, login would ping-pong.
      for (final role in UserRole.values) {
        final landing = RoleScreens.landingFor(role);
        expect(landing, isNotNull, reason: role.wire);
        expect(
          RoleScreens.screensFor(role).map((i) => i.route),
          contains(landing!.route),
          reason: role.wire,
        );
      }
    });

    test('the preview and the real sidebar cannot disagree', () {
      // Both go through navGroupsForPermissions. If someone reintroduces a
      // second copy of the mapping, this catches it.
      for (final role in UserRole.values) {
        final user = AppUser(
          id: 'u1',
          empCode: 'X',
          fullName: 'X',
          role: role,
          permissions: RoleScreens.permissionsFor(role),
          defaultRoute: RoleScreens.landingFor(role)!.route,
        );
        expect(
          navGroupsFor(user).expand((g) => g.items).map((i) => i.route),
          RoleScreens.screensFor(role).map((i) => i.route),
          reason: role.wire,
        );
      }
    });

    test('the roles differ from one another in the way the SRS says', () {
      Set<String> routes(UserRole r) =>
          RoleScreens.screensFor(r).map((i) => i.route).toSet();

      // Viewer is the floor: every other role sees everything it does.
      for (final role in UserRole.values) {
        expect(
          routes(role),
          containsAll(routes(UserRole.viewer)),
          reason: role.wire,
        );
      }
      // Admin is the ceiling.
      for (final role in UserRole.values) {
        expect(
          routes(UserRole.admin),
          containsAll(routes(role)),
          reason: role.wire,
        );
      }

      // The distinguishing screens, straight out of the role matrix.
      expect(routes(UserRole.viewer), isNot(contains(Routes.nesting)));
      expect(routes(UserRole.nestingOperator), contains(Routes.nesting));
      expect(routes(UserRole.nestingOperator), isNot(contains(Routes.runs)));
      expect(routes(UserRole.loadingOperator), contains(Routes.runs));
      expect(
        routes(UserRole.supervisor),
        containsAll([Routes.nesting, Routes.runs]),
      );
      expect(routes(UserRole.supervisor), isNot(contains(Routes.approvals)));
      expect(routes(UserRole.planner), contains(Routes.approvals));
      expect(routes(UserRole.planner), isNot(contains(Routes.admin)));
      expect(routes(UserRole.admin), contains(Routes.admin));
    });

    testWidgets(
      'tapping a chip reveals that role’s screens, tapping it again hides them',
      (tester) async {
        // Tall and narrow: the compact layout, with room for the panel to open
        // without the tap landing off-screen.
        tester.view.physicalSize = const Size(520, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // No cached user in prefs, so AuthController.build() settles on
              // unauthenticated without ever reaching the keystore or the network.
              tokenStoreProvider.overrideWithValue(
                TokenStore(const FlutterSecureStorage(), prefs),
              ),
            ],
            child: MaterialApp(theme: VTheme.dark(), home: const LoginScreen()),
          ),
        );
        await tester.pump();

        // Closed to start with: the legend must not push the two fields down for
        // an operator who only wants to sign in.
        expect(find.text('Supervisor'), findsOneWidget); // the chip
        expect(find.text('Paint Shop Supervisor'), findsNothing);

        await tester.ensureVisible(find.text('Supervisor'));
        await tester.tap(find.text('Supervisor'));
        await tester.pumpAndSettle();

        expect(find.text('Paint Shop Supervisor'), findsOneWidget);
        expect(find.text('12 screens'), findsOneWidget);
        expect(find.text('Daily Nesting'), findsOneWidget);
        expect(find.text('Signs in straight to Dashboard'), findsOneWidget);
        // A Supervisor does not manage masters, so Admin must not be listed.
        expect(find.text('Admin & Setup'), findsNothing);

        // Switching roles swaps the panel rather than opening a second one.
        await tester.tap(find.text('Viewer'));
        await tester.pumpAndSettle();
        expect(find.text('Paint Shop Supervisor'), findsNothing);
        expect(find.text('Viewer (Mgmt / CNH)'), findsOneWidget);
        expect(find.text('Reads everything, changes nothing'), findsOneWidget);

        // Tapping the open chip puts the legend back the way it was found.
        await tester.tap(find.text('Viewer'));
        await tester.pumpAndSettle();
        expect(find.text('Viewer (Mgmt / CNH)'), findsNothing);
      },
    );

    testWidgets('the open panel overflows neither layout', (tester) async {
      // The panel is the tallest thing the legend can add, and Admin is the
      // tallest panel — 14 screens. Both breakpoints must absorb it: the phone
      // at a short viewport, and the desktop split at a laptop height.
      for (final size in const [Size(390, 720), Size(1280, 800)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStoreProvider.overrideWithValue(
                TokenStore(const FlutterSecureStorage(), prefs),
              ),
            ],
            child: MaterialApp(
              theme: VTheme.light(),
              home: const LoginScreen(),
            ),
          ),
        );
        await tester.pump();

        await tester.ensureVisible(find.text('Admin'));
        await tester.tap(find.text('Admin'));
        await tester.pumpAndSettle();

        expect(find.text('14 screens'), findsOneWidget, reason: '$size');
        // A RenderFlex overflow surfaces here rather than only as a yellow
        // stripe someone has to notice by eye.
        expect(tester.takeException(), isNull, reason: '$size');
      }
      addTearDown(tester.view.reset);
    });
  });

  group('API base URL', () {
    test('the default points at a host that actually answers', () {
      // This regressed once and cost a debugging session: the client defaulted
      // to a port nothing listened on, and the failure surfaced as the offline
      // banner — indistinguishable from a dead server. The default is now the
      // deployed CRM, so a fresh checkout works with no backend running.
      expect(Env.host, 'https://api.vistarlogitek.com');
      expect(
        Env.apiBaseUrl,
        'https://api.vistarlogitek.com/api/v1/cnh-paint-shop',
      );
    });

    test('the default is absolute and carries no trailing slash', () {
      // Dio concatenates baseUrl + path rather than resolving them as URIs, so
      // a trailing slash here would produce a double slash in every request.
      expect(Env.host, startsWith('https://'));
      expect(Env.host, isNot(endsWith('/')));
      expect(Env.apiBaseUrl, isNot(contains('//api')));
    });

    test('the module path is appended, not substituted', () {
      expect(Env.apiBaseUrl, startsWith(Env.host));
      expect(Env.apiBaseUrl, endsWith(Env.modulePath));
    });
  });

  group('Logout resilience', () {
    // The bug this pins: logout awaited the local queue wipe BEFORE clearing the
    // session, so anything that made the database unavailable stranded the
    // operator in a session they had asked to leave — silently, because the
    // exception went nowhere. It happened for real on the web build, where
    // drift opens lazily and web/sqlite3.wasm was missing: the first awaited
    // query in the whole app was this wipe.
    //
    // A shared shop-floor tablet that cannot be handed to the next operator is
    // worse than useless, so signing out must not depend on local storage.

    /// Reproduces the real failure: drift opens lazily and throws on first use.
    AppDatabase brokenDatabase() => AppDatabase(
      LazyDatabase(() async => throw StateError('sqlite3.wasm 404')),
    );

    Future<ProviderContainer> containerWith(AppDatabase db) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final tokens = TokenStore(const FlutterSecureStorage(), prefs);
      return ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          appDatabaseProvider.overrideWithValue(db),
          // Keeps the test off the network. The real one already swallows its
          // own failures, so this changes nothing about what is under test.
          authRepositoryProvider.overrideWith(
            (ref) => _SilentAuthRepository(ApiClient(tokens: tokens)),
          ),
        ],
      );
    }

    test('a failing local wipe still ends the session', () async {
      final container = await containerWith(brokenDatabase());
      addTearDown(container.dispose);

      final auth = container.read(authControllerProvider.notifier);
      final wiped = await auth.logout();

      // Reported, not hidden — the caller warns that device data survived.
      expect(wiped, isFalse);
      // And the session is over regardless. This is the assertion that failed
      // before the fix: logout() threw and the status stayed put.
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(container.read(authControllerProvider).user, isNull);
    });

    test('logout does not throw when the database is unavailable', () async {
      final container = await containerWith(brokenDatabase());
      addTearDown(container.dispose);
      await expectLater(
        container.read(authControllerProvider.notifier).logout(),
        completes,
      );
    });
  });

  group('Login error clearing', () {
    // The bug this pins: errors were written only by _submit and never cleared,
    // so "Enter your password" sat under a field the operator had already
    // filled, next to a server banner explaining an attempt they had since
    // retyped. Two frozen artifacts of two different past attempts.

    Future<void> pumpLogin(
      WidgetTester tester, {
      List<Override> overrides = const [],
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStoreProvider.overrideWithValue(
              TokenStore(const FlutterSecureStorage(), prefs),
            ),
            ...overrides,
          ],
          child: MaterialApp(theme: VTheme.dark(), home: const LoginScreen()),
        ),
      );
      await tester.pump();
    }

    testWidgets('an inline error clears as soon as that field is corrected', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(520, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpLogin(tester);

      // byType, not text: "Sign in" is also the page heading.
      await tester.tap(find.byType(VButton));
      await tester.pumpAndSettle();
      expect(find.text('Enter your employee code'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);

      // Correcting ONE field clears only that field's message — the other is
      // still true and must keep saying so.
      await tester.enterText(find.byType(VInput).first, 'NES01');
      await tester.pumpAndSettle();
      expect(find.text('Enter your employee code'), findsNothing);
      expect(find.text('Enter your password'), findsOneWidget);

      await tester.enterText(find.byType(VInput).last, '123456');
      await tester.pumpAndSettle();
      expect(find.text('Enter your password'), findsNothing);
    });

    testWidgets('the server banner clears once the operator retypes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(520, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpLogin(
        tester,
        overrides: [
          authControllerProvider.overrideWith(_RejectedAuthController.new),
        ],
      );

      const banner = 'Employee code or password is incorrect.';
      expect(find.text(banner), findsOneWidget);

      await tester.enterText(find.byType(VInput).last, '123456');
      await tester.pumpAndSettle();
      expect(find.text(banner), findsNothing);
    });
  });

  group('Pattern approval', () {
    test('a standard pattern is loadable immediately', () {
      final p = Pattern.fromJson({'id': 'x', 'line_id': 'l', 'code': 'TRT-01'});
      expect(p.isSpecial, isFalse);
      expect(p.awaitingApproval, isFalse);
      expect(p.isLoadable, isTrue);
    });

    test('a non-standard pattern is refused until a Planner approves it', () {
      final pending = Pattern.fromJson({
        'id': 'x',
        'line_id': 'l',
        'code': 'SPECIAL-1',
        'is_special': true,
      });
      expect(pending.awaitingApproval, isTrue);
      expect(pending.isLoadable, isFalse);

      final approved = Pattern.fromJson({
        'id': 'x',
        'line_id': 'l',
        'code': 'SPECIAL-1',
        'is_special': true,
        'approved_at': '2026-07-31T10:00:00.000Z',
      });
      expect(approved.awaitingApproval, isFalse);
      expect(approved.isLoadable, isTrue);
    });
  });

  group('Sync results', () {
    test('a duplicate counts as accepted', () {
      // The basis of the offline promise: a replayed client_uuid means the
      // server already has the entry, so the queue row is done — not an error.
      final duplicate = SyncItemResult.fromJson({
        'client_uuid': 'abc',
        'status': 'duplicate',
      });
      expect(duplicate.isAccepted, isTrue);
      expect(duplicate.isConflict, isFalse);
    });

    test('a conflict is neither accepted nor silently dropped', () {
      final conflict = SyncItemResult.fromJson({
        'client_uuid': 'abc',
        'status': 'conflict',
        'error': 'Machine 400 can no longer be built.',
        'code': 'INSUFFICIENT_STOCK',
      });
      expect(conflict.isAccepted, isFalse);
      expect(conflict.isConflict, isTrue);
      expect(conflict.code, 'INSUFFICIENT_STOCK');
    });
  });

  group('Design tokens', () {
    test('both themes expose a full palette', () {
      expect(VColors.dark.isDark, isTrue);
      expect(VColors.light.isDark, isFalse);

      for (final palette in [VColors.dark, VColors.light]) {
        for (final status in VStatus.values) {
          expect(palette.forStatus(status), isA<Color>());
          expect(palette.tintFor(status), isA<Color>());
        }
      }
    });

    test('status colours differ between the modes where contrast demands it', () {
      // A mint that reads on #070611 washes out on white. If these ever became
      // equal, someone has flattened the light palette back onto the dark one.
      expect(VColors.dark.ok, isNot(VColors.light.ok));
      expect(VColors.dark.bad, isNot(VColors.light.bad));
      expect(VColors.dark.warn, isNot(VColors.light.warn));
    });

    test('the ribbon is identical in both modes — it is the brand', () {
      expect(VRibbon.gradient.colors.first, const Color(0xFF7A1FB0));
      expect(VRibbon.pink, const Color(0xFFE0218A));
    });

    test('lerp does not produce a half-rendered texture', () {
      // Grain and watermark opacity cross at the midpoint rather than blending;
      // a half-lerped grain reads as a glitch during the theme animation.
      final quarter = VColors.dark.lerp(VColors.light, 0.25);
      final threeQuarter = VColors.dark.lerp(VColors.light, 0.75);
      expect(quarter.grainOpacity, VColors.dark.grainOpacity);
      expect(threeQuarter.grainOpacity, VColors.light.grainOpacity);
    });
  });

  group('Theme construction', () {
    testWidgets('both themes build and expose VColors through context.v', (
      tester,
    ) async {
      for (final (theme, expectDark) in [
        (VTheme.dark(), true),
        (VTheme.light(), false),
      ]) {
        late VColors resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                resolved = context.v;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        // MaterialApp cross-fades between themes, so the frame straight after
        // pumpWidget is still mid-lerp — and VColors.lerp deliberately holds the
        // OLD brightness until the halfway point (see the grain/watermark
        // reasoning in tokens.dart). Settle the animation before asserting, or
        // this reads the previous theme and looks like a bug in the palette.
        await tester.pumpAndSettle();
        expect(resolved.isDark, expectDark);
      }
    });
  });
}
