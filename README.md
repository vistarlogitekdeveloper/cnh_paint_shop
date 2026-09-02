# CNH Paint Shop Operations — Flutter client

The plant's shortage tracker: automatic, always up to date, and in everyone's pocket.
One codebase for Android, iOS, Web and Windows.

Backend: the `cnh-paint-shop` module in the Vistar CRM
(`D:/Vistar/vistar_CRM/src/modules/cnh-paint-shop`), mounted at `/api/v1/cnh-paint-shop`.
Reference: SRS `VLPL-CNH-SRS-001-CL` · Vistar Logitek Pvt. Ltd.

---

## Running it

```bash
flutter pub get

# Drift is the one thing that needs code generation.
dart run build_runner build --delete-conflicting-outputs

# Brand assets: keys the black background out of the two Vistar logos,
# autocrops, and emits the three variants the design system uses.
dart run tool/process_logos.dart

# Nothing else to start — the default points at the deployed CRM.
flutter run
```

`API_BASE_URL` is the CRM **host**; the `/api/v1/cnh-paint-shop` path is appended by
`Env.apiBaseUrl`. It defaults to the deployed CRM so a fresh checkout runs on any machine and
any target with no backend of your own.

| dart-define | Default | Purpose |
|---|---|---|
| `API_BASE_URL` | `https://api.vistarlogitek.com` | CRM host. |
| `ENABLE_PUSH` | `true` | Set `false` to skip Firebase entirely. |
| `USE_MOCK_API` | `false` | Reserved for the fixtures-only dev mode. |

### Working against a local CRM

```bash
# From D:/Vistar/vistar_CRM — binds port 3000.
node src/server.js
# NOT `npm start`: its prestart hook runs 133 migrations against the remote
# Render Postgres first, and if that host is asleep the server never binds.
```

Then point the app at it. `localhost` does not mean the same thing on every target:

| Target | Command |
|---|---|
| Desktop / Chrome | `flutter run --dart-define=API_BASE_URL=http://localhost:3000` |
| Android emulator | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000` |
| Physical device on the plant Wi-Fi | `flutter run --dart-define=API_BASE_URL=http://<your-PC-LAN-IP>:3000` |

A local CRM accepts any loopback origin outside production (`DEV_CORS_PATTERNS` in
`src/app.js`), so `flutter run -d chrome` works on whichever random port it picks. Worth
knowing why that matters: a blocked CORS preflight reaches Dio as a *connection* error, so it
shows up as the offline banner and looks exactly like a dead server.

### Seeded logins

One per role, password `123456` for all of them. A shared test credential on a development
database — rotate it before the plant depends on this.

| Code | Name | Role | Lands on |
|---|---|---|---|
| `NES01` | Ramesh Patil | Nesting Operator | Daily Nesting |
| `NES02` | Sunil Kadam | Nesting Operator (shift 2) | Daily Nesting |
| `LOD01` | Amit Jadhav | Loading Operator | Pattern Runs |
| `SUP01` | Vikas Deshmukh | Paint Shop Supervisor | Dashboard |
| `PLN01` | Anil Kulkarni | Planner | Dashboard |
| `ADM01` | Plant IT Administrator | Admin | Admin & Setup |
| `MGT01` | CNH Management Viewer | Viewer (Mgmt / CNH) | Dashboard |

Codes are matched case-insensitively. To reset them after a change:
`node scripts/cnh-set-passwords.js` in the CRM repo.

### Platform notes

- **Android / iOS / Windows** — offline queue in a real on-disk SQLite file via
  `drift/native`. This is the shop-floor target.
- **Web** — needs `sqlite3.wasm` + `drift_worker.js` in `web/`; see
  [web/README-drift.md](web/README-drift.md). Without them the queue does not survive a page
  reload, which is acceptable for the desk-based dashboards the web build is for.
- **Push** — optional. Drop `google-services.json` / `GoogleService-Info.plist` in place.
  Without them the app runs fine and only loses notifications; a missing Firebase config must
  never stop the plant from recording receipts.

---

## Architecture

```
lib/
  main.dart          — opens the keystore + SQLite BEFORE the first frame, injects overrides
  app.dart           — MaterialApp.router, splash, push wiring
  design/            — the Vistar Premium design system. Knows nothing about the domain.
    tokens.dart      — VColors (light + dark), VRibbon, VRadius, VSpace, VMotion
    theme.dart       — ThemeData for both modes + the `context.v` extension
    typography.dart  — Bricolage Grotesque (display) + Manrope (body)
    components/      — cards, buttons, inputs, pills, table, shimmer, loaders, states, toast
  core/              — infrastructure. No domain, no widgets.
    config/env.dart
    network/         — ApiClient (auth + single-flight refresh), ApiException
    storage/         — TokenStore (keystore for tokens, prefs for the cached user)
    db/              — Drift: the outbox + the master cache
    sync/            — SyncService: the offline promise
    push/            — FCM, failure-tolerant throughout
  data/
    models/          — typed against the backend's OpenAPI, field names match the columns
    repositories/    — one per resource group; URL shapes + JSON mapping, nothing else
  providers/         — the Riverpod graph, layered the same way the app is
  router/            — go_router with auth + role guards in one redirect
  features/          — one directory per screen
```

### Why some things are the way they are

**No freezed / json_serializable / riverpod_generator.** Drift is the only thing here that
genuinely needs code generation. Every provider in this app is a plain `Notifier` or
`FutureProvider`, and every model needs a *tolerant* `fromJson` — Postgres `NUMERIC` arrives
as a string, nested objects may or may not have been included by the endpoint, and an unknown
role from a newer server must degrade rather than throw. A generator gets that leniency
wrong. Skipping it keeps `flutter pub get && flutter run` as the whole setup story.

**Model field names are snake_case-faithful** (`unpainted_pn`, `qpv`, `machines_covered`).
The point of the app is that it speaks the same language as the sheets the team already reads;
renaming `QPV` to `quantityPerVehicle` in the client would put a translation layer between the
operator's vocabulary and the code.

**Tokens are read off a `ThemeExtension`, never hardcoded.** `context.v.bad` resolves to the
right red in both modes. The light palette is *derived* from the canonical dark one — the
ribbon is unchanged because it is the brand, the surface/line/text scales invert around a warm
off-white, and only the status colours are genuinely re-tuned, because the mint/amber/rose
that read correctly on `#070611` wash out completely on white.

---

## The offline contract

This is the part worth understanding before changing anything.

**An operator's save never depends on the network.** Every entry — nesting receipt, pattern
run, request, machine-built — is written to the local Drift outbox first and acknowledged
immediately. Uploading is a separate, retryable concern handled by `SyncService`.

Screens must therefore go through `syncServiceProvider.queueNesting(...)` and friends, **not**
the repository, for writes. Reads go through the repositories as normal.

Why write locally even when online:

- The operator gets the same instant confirmation either way, so the flow never changes shape
  depending on signal — and a save that *appeared* to work must never turn out not to have.
- Plant Wi-Fi drops mid-request. A row already in the outbox survives that; a row that only
  existed in a pending HTTP call does not.

Safety comes from **`client_uuid`**: generated on the device before the row is written, and
UNIQUE server-side. The same batch can be replayed any number of times — after a crash, after
a timeout that actually succeeded, after a user taps "Sync now" twice — without double-counting
stock. The backend's `/sync/batch` returns per-item results (`synced` / `duplicate` /
`conflict` / `error`), and a `duplicate` is a *success* from the device's point of view.

Conflicts (stock moved underneath a queued machine-build, a pattern lost its approval) are
surfaced on the Sync Queue screen for a human, and they **count toward the unsynced badge** —
they are unresolved work sitting on the device, and hiding them is how an entry gets silently
lost.

Logging out wipes the local queue, so the confirm dialog warns when entries are still waiting.
A shared shop-floor tablet must not carry one operator's pending entries into the next
operator's session.

---

## Screens & roles

| Screen | Permission | Notes |
|---|---|---|
| Dashboard | `DASHBOARD_VIEW` | Line health. The "first machine affected" card is the question the plant asks every morning. |
| Shortage Matrix | `MATRIX_VIEW` | The familiar machine-wise sheet. Frozen part column + frozen machine header, two linked scroll axes, windowed on both. |
| Part Coverage | `COVERAGE_VIEW` | The ranked list form. Drill-in shows the walk in words and the ledger that proves the number. |
| Can I build machine N? | `COVERAGE_VIEW` | Ready, or the exact blocking parts. |
| Part / Rack Lookup | `PART_VIEW` | Works offline from the cached masters. |
| Daily Nesting | `NESTING_CREATE` | Two modes: **Pattern sheet** (the issued document — header, then numbered positions, one Save) and **Single part** (the four-tap flow, for a correction or an odd piece). |
| Pattern Runs | `RUN_CREATE` | The app counts the pieces; the preview table is why the operator trusts it. |
| Patterns | `PATTERN_VIEW` | Frames + their parts. Non-standard frames need Planner approval. |
| Spares (SPD) | `REQUEST_VIEW` / `REQUEST_CREATE` | Raise, then Planner approves. |
| Approvals | `REQUEST_APPROVE` | The same screen with the approver lens on. |
| Machine Plan | `MACHINE_VIEW` / `MACHINE_MANAGE` | Plan order, special units, resolved BOM, mark built. |
| Alerts | `ALERT_VIEW` | Not line-scoped: an alert on another line still stops the plant. |
| Reports | `REPORT_VIEW` | Server-driven catalogue → xlsx/pdf → share sheet. |
| Admin & Setup | `MASTER_MANAGE` | Users, thresholds, racks, parts, the two-step Excel import. |
| Sync Queue | — | Appears in the sidebar only when something is waiting. |

Role → landing route is **server-driven** (`user.defaultRoute`, from the backend's
`config/roles.js`), so the mapping has one home. The router's redirect also bounces a user off
any route whose permission they lack — to their own landing route, not to a 403 screen. A
Nesting Operator who deep-links into the Machine Plan should land somewhere useful.

The server enforces all of this independently. The client guards exist so the UI never shows a
control that would be refused.

The login screen's role legend is the one place that cannot read `AppUser.permissions` — nobody
has signed in yet — so `features/auth/role_screens.dart` mirrors `config/roles.js` to preview
what each role opens. It gates nothing; if it drifts, the cost is a wrong preview on the login
screen, never a wrongly granted screen. It runs through the same `navGroupsForPermissions`
filter as the real sidebar, and `flutter test` asserts the two agree.

---

## Design system

Reproduces the "Vistar Premium" system: the rainbow ribbon as a *thin accent only*, near-black
surfaces (or warm off-white in light mode), 1px hairlines, generous negative space, and the
five signature S treatments — ambient page watermark, splash orbit loader, route-change
loader, skeleton shimmer, card corner accent.

Performance choices that matter:

- `AmbientBackground` is a single raster-cacheable `CustomPaint` with a procedurally generated
  128×128 grain tile drawn through a repeat shader — one draw call regardless of viewport, and
  nothing animates. A moving background behind a data grid is a battery tax on a device that
  lives on a shop floor all shift.
- All skeletons on a screen share **one** `AnimationController` via `VShimmerScope`. Twenty
  rows with twenty tickers would run out of phase, which looks broken as well as costing
  frames. The ticker stops when the data lands.
- Numeric columns use `FontFeature.tabularFigures()`. Without it the digits jitter
  horizontally on every refresh and the eye cannot scan down a matrix column.
- Loaders and animated components are wrapped in `RepaintBoundary` so a spinner can never
  dirty the screen behind it.

Light and dark are both first-class. The theme toggle in the top bar cycles
system → light → dark and persists.

---

## Verification

```bash
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://your-host
flutter build apk --release --dart-define=API_BASE_URL=https://your-host
```

The backend has its own suites — `npm run cnh:test` (coverage engine, no DB) and
`npm run cnh:smoke` (93 end-to-end HTTP checks). Run those before blaming the client for a
wrong number.
