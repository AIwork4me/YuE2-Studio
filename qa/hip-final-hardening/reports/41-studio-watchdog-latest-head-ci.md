# Report 41 — Studio watchdog @ latest head: review, local gates, CI status

Head under review: `4a8186eb1008b96b229f3cd640a9d4080aba8c86` (`fix/native-hip-pr-readiness`, PR
[timoncool/YuE2-Studio#242](https://github.com/timoncool/YuE2-Studio/pull/242) head, confirmed OPEN/MERGEABLE,
base `main`). Watchdog commits under review: `1c5502df` → `4a6411c3` → `bb5befef` → `4a8186eb`
(+176/−1 across `engine_start_backoff.rs` (new, 114 lines), `lib.rs` (+37), `docs/windows-native-hip-gfx1100.md`).

## 1. Code review findings (mission 1.1 checklist)

| Check | Result | Evidence |
|---|---|---|
| Type errors | none found by inspection; compile proof awaits CI (§4) | retry-key members all `Clone + PartialEq`: `EngineOptions` (derives `PartialEq, Eq`, lib.rs:771), `Option<String>`, `Option<Vec<String>>`, `Option<String>` |
| Backoff boundary safety | PASS | `finish()` indexes `RETRY_DELAYS_SECONDS[failures-1]` only for failures 1..=4 (array len 4); `saturating_add`; `>= MAX` → `Suspended`; unit test walks every delay edge (`repeated_failure_is_bounded_and_does_not_busy_loop`) |
| Same failing config stops retrying | PASS | 5 failed automatic attempts → `Suspended`; `allow()` false forever after; only a key change or a running engine resets |
| Settings change resets failures | PASS | `observe()` resets on key change; identical key does not (tested) |
| Model-selection change recovers | PASS | `selected_profile_id` + `selected_component_ids` + `own_backbone` are key members |
| Manual restart bypasses watchdog | PASS (by design) | `/engine/restart` → `restart_local_engine` (lib.rs:5693) takes `engine_use.write()` and calls `start_engine_again` directly — backoff state not consulted; after a successful manual start the loop's `running` reset clears suspension |
| Double-start race | PASS | watchdog requires `engine_use.try_write()` success to attempt; manual paths hold `write()` — mutually exclusive; no path starts the engine without the guard |
| Real error still shown after suspend | PASS | `engine_start_error` retains the last failure and is served as `engine_error` (lib.rs:6845); suspension adds an engine-log note telling the user to use Restart |
| Auto backend logic | untouched | diff wraps start attempts only; Auto's device chain iterates inside one `start_engine_again` call (lib.rs:5847) |
| Explicit HIP fail-closed | untouched | no fallback code modified; diff predates nothing in that path |
| Not a second supervisor | PASS | one loop, one new pure-state module; no second restart mechanism |

Documented behavior (not a defect): `retry_after_memory` (lib.rs:10858) inserts `fitted_max_seq` into
`engine_options` automatically after a `lost_vram` job — the retry key then changes and the new configuration
receives a fresh budget of 5 attempts. Bounded (per distinct config), intentional per the module's contract
("a change … means the underlying problem may be fixed"), and requires a job failure, not a start failure.

Review verdict: **sound; no code changes required from review.**

## 2. Local gates at `4a8186eb` (this machine, 2026-11-15)

| Gate (mirrors `.github/workflows/ci.yml`) | Result |
|---|---|
| `interface`: `npm ci` | PASS (install-scripts warnings only, core-js postinstall notes) |
| `interface`: `npm test` (Vitest) | **PASS — 62 files / 213 tests, 0 failed** |
| `interface`: `npm run build` (incl. `prebuild` changelog generation) | PASS (exit 0; chunk-size + dynamic-import warnings only) |
| `interface`: `npx tsc --noEmit -p .` (after build, CI order) | **PASS (exit 0)** |
| `service` / `service-linux`: `cargo test -p music-server --locked` | **NOT RUN locally — BLOCKED by Smart App Control** (see §3) |
| PS syntax + HIP audit contract steps | NOT RUN locally (run in CI; PowerShell parser steps are CI jobs) |

Note on ordering: `tsc` before `prebuild` fails with `TS2307: Cannot find module '../data/changelog.json'` —
`changelog.json` is generated from git history by `scripts/changelog.mjs` (prebuild/predev). CI's order
(build → tsc) is correct; a standalone tsc run must follow a build. Not a defect.

## 3. Why cargo cannot run on this host (established, re-confirmed today)

Smart App Control (evaluation mode, per-file cloud verdicts) blocks freshly-exercised rustc-built binaries:
today `cargo fmt --check` failed with `应用程序控制策略已阻止此文件。 (os error 4551)` for `cargo-fmt.exe`;
prior sessions established build scripts never pass (71/71 blocks for `quote`). Policy is never modified
(owner rule). `cargo fmt`/`clippy` are additionally **not gates in this repository's CI** — imposing them would
manufacture a lint bar inconsistent with upstream (mission 1.2 forbids that).

## 4. Fork CI status for `4a8186eb` — **BLOCKED (account/repo-side Actions outage), evidence below**

At 2026-11-15 ~04:37Z–05:05Z (12:37–13:05 local) every trigger path was attempted:

1. `workflow_dispatch` → HTTP 422 "Actions has been disabled for this repository" (repeatedly, including after
   permissions/workflow re-enable, and after a full off→on permissions cycle).
2. API state contradicts the 422: `GET /actions/permissions` → `{"enabled":true,"allowed_actions":"all"}`;
   workflow 417501835 state `active`.
3. Push of the exact SHA to `ci/watchdog-4a8186eb` (twice, incl. delete + re-push): check-suites created
   (`status: queued`) but **zero workflow runs ever materialized** (watcher polled 40 min:
   `logs/ci-watch-4a8186eb.log`).
4. `gh run rerun 43601262629`: request accepted, then reverted to its original completed state — never executed.
5. Control experiment on the **same account**: `AIwork4me/yue2.cpp` `workflow_dispatch` → 204 **and run created
   and completed** (run 43678643861). The block is specific to the `AIwork4me/YuE2-Studio` repository backend,
   not the account token, plan or GitHub platform (status page all-green 2026-11-15T00:54Z).

Owner action required: open `https://github.com/AIwork4me/YuE2-Studio/actions` in a browser and click the
workflows-enable banner (fork re-provisioning only happens through the web UI), or Settings → Actions → General;
if no banner shows, GitHub Support (repo backend flag). A background watcher keeps polling; the moment runs
appear, the three CI jobs (service / service-linux / interface) will be recorded here and in the ledger.

## 5. Test counts and provenance

- Vitest: 213 tests / 62 files PASS at `4a8186eb` (local, node 26.13.0, `npm ci` from `package-lock.json`).
- Rust unit tests for the backoff module: 3 tests in `engine_start_backoff.rs` (`repeated_failure…`,
  `settings_change_resets_suspension…`, `healthy_engine_resets…`) + supervisor tests at `bb5befef` —
  **execution pending CI** (§4).
- No `dab746e1` result is counted for `4a8186eb` anywhere in this report.

## 6. Physical (GPU) verification still owed at this head

Native Engine Startup with the new watchdog, Watchdog fault-injection (mission 4.2: 5-attempt bound, no
25-restart storm, manual recovery, settings-change recovery), and the full Studio E2E re-run (mission 4) — all
require a `4a8186eb` binary, which requires the fork's `hip-gui-build` workflow (same blocked Actions backend)
or an owner-authorized build path. Recorded as NOT RUN, not deferred silently.

## 7. Verdict

- G1 (latest-head CI): **BLOCKED** — not met until fork Actions is re-provisioned and the three jobs pass at
  `4a8186eb`; everything achievable without it is green (review + interface gates locally).
- Watchdog code itself: review-clean; behavioral proof pending CI + physical fault-injection.
