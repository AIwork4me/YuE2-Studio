# Report 48 — FINAL OPERATION HIP-FINAL-HARDENING (2026-11-15)

Mission: stability, real export, latest-head CI, upstream closure. Working area `C:\dev\yue2-hip-nightly`.
Deliverables: reports 41–47 + this report + updated `evidence-ledger.json` (key `hip_final_hardening_2026_11_15`).

## The mission's 12 questions, answered

1. **最新 Studio CI 是否全绿？对应 SHA？** — **NO.** The CI for `4a8186eb` could not run at all: the
   `AIwork4me/YuE2-Studio` fork's Actions backend is dead (dispatch → 422 "Actions has been disabled",
   push → check-suites stuck `queued` with zero runs for 40+ min, rerun reverts; permissions/workflow re-enable,
   off→on cycle, and branch re-push all tried; control dispatch on the same account's yue2.cpp fork executed
   fine; githubstatus green). Last green CI remains `dab746e1` (run 43601262629). **Owner action required**
   (browser → the fork's Actions tab). Everything runnable without CI is green locally (Vitest 213/213, build,
   tsc; watchdog code review clean). `cargo fmt/clippy` are not repo CI gates and are SAC-blocked locally.
2. **两次 0xc0000409 的真正根因是否找到？** — **YES (resolved as misattribution).** Application event log
   (ID 1000, read-only) records faulting-process **paths**: all 10 native crashes in the 36 h window belong to
   `iso-no-kernel-pack` harness copies of the engine; the two "GUI-session crashes" (10:35:52 / 10:38:58) were
   the nokp-repro and window2 negative-test engines — byte-identical exes → same WER bucket → indistinguishable
   by folder name. **The GUI engine has zero native-crash events.**
3. **如果未找到，做了哪些调查，风险是什么？** — Found; but the residual real finding: missing rocBLAS
   kernel pack ⇒ CRT `abort()` (fail-fast subcode 7, ucrtbase+0xa527e, every event identical) instead of a
   clean exit. Bounded by the Studio watchdog; yue2.cpp preflight candidate filed (report 42 §10.3). Also
   corrected on the record: the six prior "controlled repros" replayed the successful job's seeds, not the
   crashed jobs' (moot now, but the public "same seeds" claim was inaccurate).
4. **Windows Radeon 上的真实 FLAC Download 是否完成？** — **YES.** 5 real external exports from the real GUI
   (Tauri shell, live app, native 另存为 dialog), byte-identical SHA256 `f2127bfb…c07` to the library original
   in every case; FLAC structure independently verified (fLaC, 48 kHz/2ch/23-bit/57.24 s).
5. **用户是否真正获得外部文件？** — **YES**: `qa/gui-final-run/export/` and `qa/manualexport/` files on disk,
   produced through the dialog (user-answered runs 1–3; fully scripted runs 4–5 including one on a freshly
   restarted app). Not library originals — external copies verified by SHA against the source.
6. **Watchdog 是否消除了持续重启风暴？** — Code-verified at `4a8186eb` (5-attempt bound per config, backoff
   5/15/30/60 s, suspension with honest error retained, settings/model change resets, manual restart bypass,
   no double-start race). **Behavioral fault-injection NOT RUN** — needs a `4a8186eb` binary (CI outage).
7. **最新 Studio HEAD 的 GUI 是否完整通过？** — **NOT RUN** at `4a8186eb` (no binary). At `dab746e1`
   (identical export/dialog/UI code): today's physical session adds export ×5 + cancel + restart-then-export
   to the prior 20-item E2E.
8. **Engine 旧的五轮 33/33 是否受新代码影响？** — **NO.** No engine C++ or GGML code was modified this
   session; the watchdog commits touch only the Studio supervisor. The five 33-PASS runs and their SHAs stand.
9. **是否新增或修改了上游 Issue/PR？** — No new PRs/issues; no pushes; no comments (owner authorization +
   human review required first). Correction drafts prepared in reports 45 §3 / 46. One candidate NEW minimal
   follow-up (yue2.cpp kernel-pack preflight) filed for owner decision — not appended to any existing PR.
10. **各仓库 CONTRIBUTING/AGENTS/LICENSE 是否遵守？** — Re-verified: Studio AGENTS.md (no Python/Node runtime
    deps, adapter pattern, capability-level providers, no user data committed) ✓; MIT license intact ✓;
    ggml CONTRIBUTING routes core changes to ggml-org/llama.cpp (no GGML changes made) ✓; Ultralytics guide
    used as engineering reference only ✓; CODEOWNERS / CONTRIBUTING.md / PR templates: NOT PRESENT (recorded,
    not assumed). No commits made anywhere this session, so no commit/PR policy was exercised.
11. **哪些任务仍依赖签名/Maintainer/干净机？** — (a) fork Actions re-provisioning (owner, web UI) → unblocks
    CI, the `4a8186eb` build, watchdog fault-injection, current-head E2E; (b) code-signing cert → SAC
    real-world validation, installer, updater; (c) maintainer merges → ggml/yue2.cpp pins; (d) clean machine →
    release acceptance; (e) owner approval before any upstream comment posting.
12. **Developer Preview / Signed Beta / Stable？** — Preview: **CONDITIONAL GO** (stronger than yesterday:
    crash risk reclassified with proof, export gate closed physically); Signed Beta: **NO-GO**; Stable:
    **NO-GO** (report 47).

## Session facts that will save the next session time (also saved to memory)

- Fork Actions quirk: API state lies (enabled/active) while dispatch 422s and runs never start; only the
  browser UI can re-provision. Pushing the exact SHA to a temp branch creates suites but not runs.
- Native dialog automation on this build: EnumWindows (not UIA tree) to find `#32770`; the filename Edit is
  ctrl-id 1001 and Save is Button ctrl-id 1; **programmatic text on a dialog <~6 s old is silently discarded**
  (use default-name save, or wait minutes); dialogs never time out; FilesPanel covers the row buttons after a
  save; 1–2 choose POSTs fire per click.
- The owner was physically present this afternoon (answered three dialogs on-screen — attributed honestly in
  report 43).

## Honest NOT-RUN / BLOCKED list

- `cargo test -p music-server` (Windows+Linux) at `4a8186eb` — BLOCKED (SAC locally; CI outage remotely).
- Watchdog fault-injection (mission 4.2) — BLOCKED on binary.
- Current-head full GUI E2E (mission 4.1/4.3) — BLOCKED on binary.
- Permission-denied export E2E error chip — PARTIAL (OS deny + code-review evidence only).
- GPU stability matrix (P50/P95 etc., mission 4.3) — NOT RUN (also blocked on binary; prior-session perf runs
  unaffected).
- No dumps were collected; no registry or security settings were touched; elevation was not used (owner had
  cancelled a similar request earlier; the event log made it unnecessary).
