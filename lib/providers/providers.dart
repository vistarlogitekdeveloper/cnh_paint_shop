import 'dart:async';

// material (not foundation) for ThemeMode, which the theme controller stores.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/storage/token_store.dart';
import '../core/sync/sync_service.dart';
import '../data/models/models.dart';
import '../data/repositories/repositories.dart';

/// ---------------------------------------------------------------------------
/// Riverpod graph.
///
/// Layered the same way the app is: infrastructure (db, tokens, api) → services
/// (sync) → repositories → screen state. Nothing above reaches around a layer.
///
/// Written without the generator on purpose — every provider here is a plain
/// Notifier or FutureProvider, and skipping codegen keeps
/// `flutter pub get && flutter run` as the whole setup story.
/// ---------------------------------------------------------------------------

// ===========================================================================
// Infrastructure. Overridden in main() with the instances opened at boot, so the
// app never awaits a keystore or a disk open inside a build().
// ===========================================================================

final tokenStoreProvider = Provider<TokenStore>((ref) {
  throw UnimplementedError('tokenStoreProvider must be overridden in main()');
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('appDatabaseProvider must be overridden in main()');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    tokens: ref.watch(tokenStoreProvider),
    // The refresh token is dead. Clearing auth state flips the router's
    // redirect, so the user lands on login without any screen having to check.
    onSessionExpired: () => ref.read(authControllerProvider.notifier).onSessionExpired(),
  );
  return client;
});

// ===========================================================================
// Repositories
// ===========================================================================

final authRepositoryProvider =
    Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));
final masterRepositoryProvider =
    Provider((ref) => MasterRepository(ref.watch(apiClientProvider)));
final coverageRepositoryProvider =
    Provider((ref) => CoverageRepository(ref.watch(apiClientProvider)));
final dashboardRepositoryProvider =
    Provider((ref) => DashboardRepository(ref.watch(apiClientProvider)));
final nestingRepositoryProvider =
    Provider((ref) => NestingRepository(ref.watch(apiClientProvider)));
final runRepositoryProvider =
    Provider((ref) => RunRepository(ref.watch(apiClientProvider)));
final requestRepositoryProvider =
    Provider((ref) => RequestRepository(ref.watch(apiClientProvider)));
final planRepositoryProvider =
    Provider((ref) => PlanRepository(ref.watch(apiClientProvider)));
final alertRepositoryProvider =
    Provider((ref) => AlertRepository(ref.watch(apiClientProvider)));
final reportRepositoryProvider =
    Provider((ref) => ReportRepository(ref.watch(apiClientProvider)));
final importRepositoryProvider =
    Provider((ref) => ImportRepository(ref.watch(apiClientProvider)));
final userRepositoryProvider =
    Provider((ref) => UserRepository(ref.watch(apiClientProvider)));
final syncRepositoryProvider =
    Provider((ref) => SyncRepository(ref.watch(apiClientProvider)));

// ===========================================================================
// Sync
// ===========================================================================

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    db: ref.watch(appDatabaseProvider),
    sync: ref.watch(syncRepositoryProvider),
    nesting: ref.watch(nestingRepositoryProvider),
    tokens: ref.watch(tokenStoreProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Live sync status for the offline banner.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(syncServiceProvider);
  // Seed with the current value: a StreamProvider would otherwise sit in
  // `loading` until the first connectivity event, and the banner would flicker.
  return service.status.startWith(service.currentStatus);
});

/// The unsynced badge count.
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  return ref.watch(syncServiceProvider).watchPendingCount();
});

final syncQueueProvider = StreamProvider<List<OutboxRow>>((ref) {
  return ref.watch(syncServiceProvider).watchQueue();
});

extension _StartWith<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}

// ===========================================================================
// Auth
// ===========================================================================

@immutable
class AuthState {
  const AuthState({
    this.user,
    this.lines = const [],
    this.status = AuthStatus.unknown,
    this.error,
    this.busy = false,
  });

  final AppUser? user;

  /// The active lines, delivered by the login response so the app bar's selector
  /// needs no extra round-trip.
  final List<ProductionLine> lines;

  final AuthStatus status;
  final String? error;
  final bool busy;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AppUser? user,
    List<ProductionLine>? lines,
    AuthStatus? status,
    String? error,
    bool? busy,
  }) {
    return AuthState(
      user: user ?? this.user,
      lines: lines ?? this.lines,
      status: status ?? this.status,
      error: error,
      busy: busy ?? this.busy,
    );
  }
}

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Restore synchronously from the cached user so the very first frame already
    // knows the role — the router needs it to pick a landing route, and an async
    // restore here would show a login flash to an already-signed-in operator.
    final tokens = ref.read(tokenStoreProvider);
    final cached = tokens.cachedUser;

    if (cached != null && !tokens.refreshExpired) {
      // Revalidate in the background; the cached session is good enough to
      // render with.
      Future.microtask(_revalidate);
      return AuthState(
        user: AppUser.fromJson(cached),
        status: AuthStatus.authenticated,
      );
    }
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _revalidate() async {
    try {
      final user = await ref.read(authRepositoryProvider).me();
      await ref.read(tokenStoreProvider).saveUser(user.toJson());
      // A role change or a deactivation server-side takes effect here.
      state = state.copyWith(user: user, status: AuthStatus.authenticated);
      await _afterAuthenticated();
    } on ApiException catch (e) {
      // Offline is NOT a reason to sign someone out — the cached session stands
      // and the app keeps working from the local cache.
      if (e.isAuth) {
        await _clear();
      }
    } catch (_) {
      // Same reasoning.
    }
  }

  Future<bool> login({required String empCode, required String password}) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final result = await ref.read(authRepositoryProvider).login(
            empCode: empCode,
            password: password,
          );

      final tokens = ref.read(tokenStoreProvider);
      await tokens.saveTokens(
        access: result.access,
        refresh: result.refresh,
        refreshExpiresAt: result.refreshExpiresAt,
      );
      await tokens.saveUser(result.user.toJson());

      state = AuthState(
        user: result.user,
        lines: result.lines,
        status: AuthStatus.authenticated,
      );

      await _afterAuthenticated();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Could not sign in. $e');
      return false;
    }
  }

  /// Warm the offline cache and drain anything queued from a previous session.
  Future<void> _afterAuthenticated() async {
    final sync = ref.read(syncServiceProvider);
    sync.start();
    // Not awaited: the dashboard should paint immediately, not after a bootstrap.
    sync.refreshMasters();
    sync.flush();
  }

  /// Signs out. Returns false if the local queue could not be wiped, so the
  /// caller can say so — the session is ended either way.
  ///
  /// Nothing in here is allowed to abort the logout. Signing out is the one
  /// action that has to work when the device is already in a bad state, and a
  /// shared shop-floor tablet that cannot be handed to the next operator is
  /// worse than useless.
  Future<bool> logout() async {
    final tokens = ref.read(tokenStoreProvider);

    String? refresh;
    try {
      refresh = await tokens.refreshToken();
    } catch (error) {
      // A locked or unavailable keystore must not strand someone in a session
      // they asked to leave. Without the token the server keeps one dangling
      // refresh row, which expires on its own.
      debugPrint('[auth] could not read the refresh token for logout: $error');
    }

    // Already best-effort internally — a logout must succeed locally even if
    // the server is unreachable.
    await ref.read(authRepositoryProvider).logout(
          refreshToken: refresh,
          fcmToken: tokens.fcmToken,
        );

    // Wipe the local queue and cache: a shared shop-floor tablet must not carry
    // one operator's pending entries into the next operator's session.
    //
    // This threw for real on the web build. Drift opens lazily, so the wasm
    // database is not touched until the first query — and the first query in a
    // user-blocking path is this wipe. With web/sqlite3.wasm absent it 404s,
    // and because the throw landed before _clear() the session survived: the
    // Log out button did nothing, silently. The wipe is now attempted and
    // reported, never depended on.
    var wiped = true;
    try {
      await ref.read(syncServiceProvider).wipe();
    } catch (error) {
      wiped = false;
      debugPrint('[auth] local wipe failed during logout: $error');
    }

    await _clear();
    return wiped;
  }

  /// Called by the API client when a refresh finally fails.
  void onSessionExpired() {
    if (state.status != AuthStatus.unauthenticated) {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        error: 'Your session expired. Please sign in again.',
      );
    }
  }

  Future<void> _clear() async {
    try {
      await ref.read(tokenStoreProvider).clearSession();
    } catch (error) {
      // Same reasoning as logout(): the in-memory session must end even if the
      // keystore refuses. Tokens left on disk would restore the session on the
      // next launch, which is why this is logged rather than swallowed.
      debugPrint('[auth] clearing the keystore failed: $error');
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> changePassword({required String oldPassword, required String newPassword}) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await ref.read(authRepositoryProvider).changePassword(
            oldPassword: oldPassword,
            newPassword: newPassword,
          );
      // The server revoked every other session; this one keeps its tokens.
      final user = state.user;
      state = state.copyWith(
        busy: false,
        user: user == null
            ? null
            : AppUser(
                id: user.id,
                empCode: user.empCode,
                fullName: user.fullName,
                role: user.role,
                permissions: user.permissions,
                defaultRoute: user.defaultRoute,
                phone: user.phone,
                email: user.email,
                shift: user.shift,
                forcePasswordChange: false,
                lastLoginAt: user.lastLoginAt,
              ),
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// The signed-in user, or null.
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authControllerProvider).user;
});

/// Permission check as a provider family, so a widget can `ref.watch(can(...))`
/// and rebuild if the role changes mid-session.
final canProvider = Provider.family<bool, String>((ref, permission) {
  return ref.watch(currentUserProvider)?.can(permission) ?? false;
});

// ===========================================================================
// Lines & the selected line
// ===========================================================================

/// The active lines. Seeded from the login response, refetched on demand.
final linesProvider = FutureProvider<List<ProductionLine>>((ref) async {
  final fromLogin = ref.watch(authControllerProvider).lines;
  if (fromLogin.isNotEmpty) return fromLogin;
  return ref.watch(masterRepositoryProvider).lines();
});

/// Which line the app bar is showing.
///
/// Persisted, because an operator works one line all shift and should not have
/// to reselect it every time the app is opened.
class SelectedLineController extends Notifier<String?> {
  @override
  String? build() {
    final saved = ref.read(tokenStoreProvider).lastLineId;
    if (saved != null) return saved;

    // Fall back to the first line once they load.
    ref.listen(linesProvider, (_, next) {
      final lines = next.valueOrNull;
      if (state == null && lines != null && lines.isNotEmpty) {
        state = lines.first.id;
      }
    });
    return null;
  }

  Future<void> select(String? lineId) async {
    state = lineId;
    await ref.read(tokenStoreProvider).saveLastLineId(lineId);
  }
}

final selectedLineIdProvider =
    NotifierProvider<SelectedLineController, String?>(SelectedLineController.new);

/// The selected line as an object, once the list has loaded.
final selectedLineProvider = Provider<ProductionLine?>((ref) {
  final id = ref.watch(selectedLineIdProvider);
  final lines = ref.watch(linesProvider).valueOrNull ?? const [];
  if (lines.isEmpty) return null;
  return lines.firstWhere((l) => l.id == id, orElse: () => lines.first);
});

// ===========================================================================
// Dashboard
// ===========================================================================

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  // Line-scoped: switching the selector refetches. `autoDispose` so leaving the
  // screen stops holding a stale payload in memory.
  final lineId = ref.watch(selectedLineIdProvider);
  return ref.watch(dashboardRepositoryProvider).dashboard(lineId: lineId);
});

/// App-bar badge counters. Polled while the app is in the foreground.
final badgeCountsProvider = StreamProvider<BadgeCounts>((ref) async* {
  final repo = ref.watch(dashboardRepositoryProvider);
  // Only poll for an authenticated session — otherwise this fires 401s on the
  // login screen.
  if (!ref.watch(authControllerProvider).isAuthenticated) {
    yield const BadgeCounts();
    return;
  }

  while (true) {
    try {
      yield await repo.badges();
    } on ApiException {
      // A failed poll must not tear down the stream; the next tick retries.
    }
    await Future<void>.delayed(const Duration(seconds: 45));
  }
});

// ===========================================================================
// Coverage
// ===========================================================================

/// Filters for the coverage screen, kept out of the fetch so changing a filter
/// does not need a new provider family key per combination.
@immutable
class CoverageFilters {
  const CoverageFilters({this.level = 'all', this.sort = 'critical', this.search = ''});

  final String level;
  final String sort;
  final String search;

  CoverageFilters copyWith({String? level, String? sort, String? search}) => CoverageFilters(
        level: level ?? this.level,
        sort: sort ?? this.sort,
        search: search ?? this.search,
      );
}

final coverageFiltersProvider =
    NotifierProvider<CoverageFiltersController, CoverageFilters>(CoverageFiltersController.new);

class CoverageFiltersController extends Notifier<CoverageFilters> {
  @override
  CoverageFilters build() => const CoverageFilters();

  void setLevel(String level) => state = state.copyWith(level: level);
  void setSort(String sort) => state = state.copyWith(sort: sort);
  void setSearch(String search) => state = state.copyWith(search: search);
  void reset() => state = const CoverageFilters();
}

final coverageProvider = FutureProvider.autoDispose<CoverageResult>((ref) async {
  final lineId = ref.watch(selectedLineIdProvider);
  if (lineId == null) throw const ApiException(message: 'Pick a production line first.');
  final filters = ref.watch(coverageFiltersProvider);

  return ref.watch(coverageRepositoryProvider).coverage(
        lineId: lineId,
        level: filters.level,
        sort: filters.sort,
        search: filters.search.isEmpty ? null : filters.search,
      );
});

// ===========================================================================
// Alerts
// ===========================================================================

final alertsFilterProvider = StateProvider<String>((ref) => 'open');

final alertsProvider = FutureProvider.autoDispose<List<ShortageAlert>>((ref) async {
  final status = ref.watch(alertsFilterProvider);
  // Deliberately NOT line-scoped: an alert on another line still stops the
  // plant, and the SRS asks for "all warnings in one place".
  final result = await ref.watch(alertRepositoryProvider).list(status: status, limit: 200);
  return result.rows;
});

// ===========================================================================
// Requests
// ===========================================================================

final requestsFilterProvider = StateProvider<String>((ref) => 'pending');

final requestsProvider = FutureProvider.autoDispose<List<SpdRequest>>((ref) async {
  final status = ref.watch(requestsFilterProvider);
  final result = await ref.watch(requestRepositoryProvider).list(
        status: status == 'all' ? 'all' : status,
        limit: 200,
      );
  return result.rows;
});

// ===========================================================================
// Machine plan
// ===========================================================================

final planFilterProvider = StateProvider<bool?>((ref) => false); // false = pending only

final machinePlanProvider = FutureProvider.autoDispose<List<Machine>>((ref) async {
  final lineId = ref.watch(selectedLineIdProvider);
  if (lineId == null) return const [];
  final built = ref.watch(planFilterProvider);
  final result = await ref.watch(planRepositoryProvider).machines(
        lineId: lineId,
        built: built,
        limit: 500,
      );
  return result.rows;
});

final machineDetailProvider =
    FutureProvider.autoDispose.family<MachineDetail, String>((ref, machineId) {
  return ref.watch(planRepositoryProvider).machine(machineId);
});

// ===========================================================================
// Patterns
// ===========================================================================

final patternsProvider = FutureProvider.autoDispose<List<Pattern>>((ref) async {
  final lineId = ref.watch(selectedLineIdProvider);
  final result = await ref.watch(masterRepositoryProvider).patterns(lineId: lineId, limit: 300);
  return result.rows;
});

final patternDetailProvider = FutureProvider.autoDispose
    .family<({Pattern pattern, List<PatternItem> items}), String>((ref, patternId) {
  return ref.watch(masterRepositoryProvider).pattern(patternId);
});

// ===========================================================================
// Registers
// ===========================================================================

final nestingRegisterDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final nestingRegisterProvider = FutureProvider.autoDispose<
    ({List<NestingEntry> rows, int total, Map<String, dynamic> totals})>((ref) async {
  final lineId = ref.watch(selectedLineIdProvider);
  final date = ref.watch(nestingRegisterDateProvider);
  return ref.watch(nestingRepositoryProvider).register(
        lineId: lineId,
        date: _isoDate(date),
        limit: 300,
      );
});

final patternRunsProvider = FutureProvider.autoDispose<List<PatternRun>>((ref) async {
  final lineId = ref.watch(selectedLineIdProvider);
  final date = ref.watch(nestingRegisterDateProvider);
  final result = await ref.watch(runRepositoryProvider).list(
        lineId: lineId,
        date: _isoDate(date),
        limit: 200,
      );
  return result.rows;
});

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ===========================================================================
// Reports
// ===========================================================================

final reportCatalogueProvider = FutureProvider<List<ReportDefinition>>((ref) {
  return ref.watch(reportRepositoryProvider).catalogue();
});

// ===========================================================================
// Admin
// ===========================================================================

final usersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) async {
  final result = await ref.watch(userRepositoryProvider).list(limit: 300);
  return result.rows;
});

final racksProvider = FutureProvider.autoDispose<List<Rack>>((ref) async {
  final result = await ref.watch(masterRepositoryProvider).racks(limit: 500);
  return result.rows;
});

final importTargetsProvider = FutureProvider<List<ImportTarget>>((ref) {
  return ref.watch(importRepositoryProvider).targets();
});

final importHistoryProvider = FutureProvider.autoDispose<List<ImportBatch>>((ref) async {
  final result = await ref.watch(importRepositoryProvider).history();
  return result.rows;
});

// ===========================================================================
// Theme
// ===========================================================================

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return switch (ref.read(tokenStoreProvider).themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(tokenStoreProvider).saveThemeMode(switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  /// Cycles system → light → dark → system, for the single app-bar toggle.
  Future<void> cycle() async {
    await set(switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    });
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
