# Drift on the web — required assets

The web build stores the offline queue in SQLite compiled to WebAssembly. Two files must be
served from this `web/` directory alongside the app:

| File | Where to get it |
|---|---|
| `sqlite3.wasm` | https://github.com/simolus3/sqlite3.dart/releases — the release matching the `sqlite3` version in `pubspec.lock` |
| `drift_worker.js` | https://github.com/simolus3/drift/releases — the release matching the `drift` version in `pubspec.lock` |

Currently pinned: `sqlite3` 2.9.4, `drift` 2.28.2.

```bash
curl -L -o web/sqlite3.wasm \
  https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-2.9.4/sqlite3.wasm
curl -L -o web/drift_worker.js \
  https://github.com/simolus3/drift/releases/download/drift-2.28.2/drift_worker.js
```

Re-download both whenever either version changes in `pubspec.lock`.

## What happens without them

They are **required**, not optional, and this was mis-documented here until it caused a bug.

`WasmDatabase.open()` *fetches* both URIs. If they 404 it **throws** — there is no in-memory
fallback. Because drift opens lazily, the throw does not surface at startup: it surfaces
wherever the first query happens to run. In practice the app logged in normally and then the
Log out button did nothing at all, because the first awaited query was the logout's queue
wipe, and the exception landed before the session was cleared.

`WasmDatabase.missingFeatures` is the unrelated, benign case: once the files load, it reports
which browser capabilities (OPFS, SharedWorker, IndexedDB) were unavailable, logs
`[db] web storage degraded`, and the queue then does not survive a page reload.

That degradation is acceptable **only** on the web build. The web target is for the Planner's
and management's dashboards on a desk, where entries are made online. The shop-floor
operators who actually depend on offline entry run the Android build, which uses a real
on-disk SQLite file via `drift/native` and has no such caveat.
