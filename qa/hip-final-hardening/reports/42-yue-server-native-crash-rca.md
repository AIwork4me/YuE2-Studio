# Report 42 — yue-server native crash (0xc0000409) root-cause investigation

Status: **RESOLVED (misattribution) — see §10.** The two crashes reported as "GUI-session native crashes" were
never the GUI engine: Application event log (ID 1000, read-only, no elevation needed) records the faulting
process **path**, and all native-crash events in the 36 h window belong to `iso-no-kernel-pack` harness copies.
The GUI engine never natively crashed; its job failures that morning were clean fail-closed exits (exit code 0x1,
GPU-contention root cause already documented in report 22 §5). A real but separate finding stands: the
no-kernel-pack path terminates via CRT `abort()` (fast-fail subcode 7) rather than a clean error exit — §10.3.

Date: 2026-11-15 (all local times UTC+8). Working area `C:\dev\yue2-hip-nightly\`. No original evidence moved, modified or deleted; hashes recorded below at 2026-11-15 ~12:30 local.

## 1. Scope

Two native terminations of `yue-server.exe` during the GUI session of 2026-11-15 morning, disclosed in
[timoncool/YuE2-Studio#242 comment 6888778731](https://github.com/timoncool/YuE2-Studio/pull/242#issuecomment-6888778731):

- Exception code `0xc0000409` (fail-fast; **not** diagnosable as stack buffer overrun from the code alone)
- Faulting module reported by WER: `ucrtbase.dll`
- Context: 9-track / 130 s generation, NAR-related stage, GUI-supervised engine

`0xc0000409` is a fail-fast class exception raised by `__fastfail`/`__report_gsfailure`/CRT abort paths; the WER
"faulting module" is the module where the fast-fail was raised, which for CRT-initiated termination is almost always
`ucrtbase.dll` regardless of the true origin. A call stack is required for attribution; none exists (§3 gap G1).

## 2. Per-crash records (mission 2.2 fields, filled to the extent evidence allows)

### Crash #1 — 2026-11-15 10:35:52 local (02:35:52 UTC)

| Field | Value | Source |
|---|---|---|
| Crash timestamp | 10:35:52 local (±1 s; bracketed by progress screenshots 10:35:46.46 → 10:35:55.62) | `qa/gui-final-run/shots-phase2/b20-progress-14/15.png` mtimes |
| Engine SHA | `3c8b35b7` (runtime.json commit); binary below | `app/resources/yue2-cpp/runtime.json` |
| EXE SHA256 | `449ea33dbf201562fdd1475920793b48b4b985c1bfc26169d5dbbd79d10e44e7` (yue-server.exe, 2,822,656 B) | direct hash 2026-11-15 |
| GGML SHA256 | `5031256c20d5b7ebe9a0df1254a9d208470eb356538de245dc41d5b96cf0e06f` (ggml-hip.dll, 74,918,400 B; override `39927eae`) | direct hash |
| Exception code | 0xc0000409 | WER record quoted in report 18 §5 |
| Exception address | **NOT RECORDED** (WER .wer ACL-locked, no dump) | gap G1/G2 |
| Faulting module | ucrtbase.dll | WER record quoted in report 18 §5 |
| Thread ID | **NOT RECORDED** | gap G1 |
| Call stack | **NONE EXISTS** (no .dmp anywhere; stdout buffered & lost — engine.log truncates at `[NAR] Step 24/32, 1185 ms`) | gaps G1/G3 |
| Loaded modules | not captured | gap G1 |
| Current stage | mid-NAR (step ~24/32 of final NAR pass), job `b84393eb614c90ae` (auto-resumed from `51e1bde55a2c04ff` ← `1c03a2dea0ea0704`) | engine.log L1195+, library.sqlite `music_jobs` |
| Request ID (DB) | `1c03a2dea0ea0704` (orig, 10:31:57.090) → `b84393eb614c90ae` (10:33:39.679, status failed: "The engine stopped during this song (exit code 0x1) … last line `[AR] Semantic 600/3250`") | library.sqlite |
| Song duration | 130.0 s | engine.log job JSON |
| Track count | 9 (`synth_batch_size: 9`) | engine.log job JSON |
| synth_batch_size | 9 | engine.log job JSON |
| Model type | YuE2-3B-Q8_0 backbone + F32 VAE, companion NAR LoRA v9 | `logs/gui-engine-cmdline.txt` |
| Memory usage | **NOT RECORDED** (no perf capture at crash instant) | gap |
| GPU activity | NAR stage on ROCm0; **concurrent GPU consumers running (nokp iso engines, see §4)** | timeline §4 |
| Concurrent engine processes | ≥1 no-kernel-pack iso engine on ports 18123+ (started 10:30:46 / 10:32:00 / 10:33:45 / 10:35:42) | qa/nokp-repro, logs |
| Seeds | `lm_seed 2251192151`, `seed 3460034790` | engine.log job JSON |
| WER folder | `AppCrash_yue-server.exe_faad627d…_575d8a44-…` (dir mtime 10:35) | ReportArchive listing |
| Second-precision correlate | iso engine `qa/nokp-repro/repro-103542/engine-err.log` last write **10:35:51.91**, dying with `rocBLAS error: Cannot read …TensileLibrary.dat … for GPU arch : gfx1100` | §4 |

### Crash #2 — 2026-11-15 10:38:58 local (02:38:58 UTC)

| Field | Value |
|---|---|
| Context | supervisor auto-restart cycle after crash #1 (engine.log restart lines 1394/1410/1426; DB jobs failed with exit code 0x1) |
| Same binary / same signature | yes (same SHA, same 0xc0000409 + ucrtbase.dll) |
| WER folder | `AppCrash_yue-server.exe_faad627d…_18cdf584-…` (dir mtime 10:39) |
| Second-precision correlate | `qa/final-physical-validation-window2/logs/no-kernel-pack-server.log` last write **10:38:58.07** — window2 harness's negative-test iso engine (byte-identical exe) died at first VAE GEMM with the identical rocBLAS TensileLibrary error |
| Recovery | next GUI job `2d5a7238190f45b7` 10:43:06 completed 9 tracks / 515.1 s in 85.8 s; FLAC written 10:44 |
| Other fields | as crash #1 (no stack, no dump, no address) |

## 3. Evidence manifest (SHA256 recorded 2026-11-15)

Primary session evidence:

| Path | Size (B) | mtime (local) | SHA-256 |
|---|---:|---|---|
| `qa/gui-final-run/dataroot/engine.log` | 109,580 | 11-15 11:45 | `a63030bcfbe287ba0a29a0220c0350d10ffe90cc24f66990bfc943c1d64a03a0` |
| `qa/gui-final-run/dataroot/logs/yue2-studio.log` | 2,194 | 11:45 | `d76b8b9d7812131501b4fc09539dbf66b3cacd232a5305da3475caa26bdf72e3` |
| `qa/gui-final-run/dataroot/library.sqlite` | 253,952 | 10:50 | `5aa4af95fcd0cf1b84a8dad11d330a575927b3080be06ceee945d1283b54ee7` |
| `qa/gui-final-run/dataroot/studio-hub.json` | 44,670 | **12:15 (still live)** | `ab29e30954c7dd3c19704faf68464174af3d9695e3f8ee023ba0c8d24e665d5e` |
| `logs/gui-engine-cmdline.txt` | 619 | 11:35 | `f2ed7ad2aa479f897d9a08f00dfea343b00157357db15075367f0439a26a9ae0` |
| `qa/gui-final-run/shots-phase2/engine-song1.log` | 80,506 | 10:33:47 | `aef04cce26df9efe2d5b6dd317aabbba0f13a563d3181ada23b073bd42906877` |
| `qa/gui-final-run/shots-phase2/engine-phase2c-final.log` | 72,892 | 10:32:32 | `cd71b5b11a55a91426dcb7321106c0632caca48f1e27cd8dc6696ac0dc4a1b95` |
| `qa/gui-final-run/shots-phase2/engine-phase2e-final.log` | 92,198 | 10:44:42 | `09678363e84fee51856021c023b4452ca7232168af5e6a164dcf93bde720490d` |
| `qa/gui-final-run/shots-phase2/b20-progress-14.png` | 218,571 | 10:35:46.46 | `3bde5e341cfc5bcaa72d06d9ddca83bdae461ab5ac285f6c6fcaf0939d6ce6a0ff` |
| `qa/gui-final-run/shots-phase2/b20-progress-15.png` | 218,406 | 10:35:55.62 | `37c96b37cc7dc002c9cc5bdf5d96e8b929244fbeebf0f5a9ea411dc8c79f7df` |

Engine binary + provenance: `yue-server.exe` SHA256 `449ea33d…44e7` (above), `ggml-hip.dll` `5031256c…e06f`,
`runtime.json` `35e18ea4…7f37` (commit `3c8b35b7`, ggml_override `39927eae`, hip_archs `gfx1100`).

WER-adjacent correlates: `qa/nokp-repro/repro-103542/engine-err.log` `f38241b1…61f4` (10:35:51.91);
`qa/final-physical-validation-window2/logs/no-kernel-pack-server.log` `bd656d98…6519` (10:38:58.07).

Six controlled-reproduction artifacts (all clean): `logs/repro-crash-130x9.log` (`e106a97f…`), `logs/repro2-130x9.log` (`66ecbb63…`) + verdict, `logs/repro3-130x9-full-lyrics.log` (`763d2f29…`), `logs/repro4-130x9.log` (`b6a45449…`) + verdict + launch.cmd, `logs/repro5-130x9.log` (`1049b180…`) + verdict + launch.cmd, `logs/repro6-guiflags.log` (`d8fac7cf…`) + verdict + launch.cmd.

Prior documentation: reports 18 §5 (primary), 20, 21, 22 §5, 23; `reports/pr-bodies/pr-c-final-comment.md` (the disclosure text); `reports/evidence-ledger.json`.

System locations:

- `C:\ProgramData\Microsoft\Windows\WER\ReportArchive` — 10 `AppCrash_yue-server.exe` folders:
  2× Nov 14 20:37/20:39 (kernelpack-probe binary — separate WER bucket `461bcb28…`) and 8× `faad627d…` bucket (this exe): dir mtimes 10:25, 10:34, 10:35 (crash #1), 10:39 (crash #2), **10:55, 10:57, 10:59, 11:01 (unexplained — see gap G4)**. All subfolders ACL-locked (SYSTEM/admins); inner `Report.wer` not readable without elevation.
- `C:\ProgramData\Microsoft\Windows\WER\ReportQueue` — empty. `C:\Windows\Minidump` — empty. `%LOCALAPPDATA%\CrashDumps` — does not exist (**LocalDumps was never enabled → no per-app dump was ever written**).
- Code Integrity exports `qa/codeintegrity/` (1,096 events; SAC/CI channel only; coverage ends 08:23 local — 2 h 12 m **before** crash #1).

**PRIVACY FLAG — must never be uploaded:** 4 WebView2 Crashpad minidumps under
`qa/gui-final-run/app/webview-data/EBWebView/Crashpad/reports/` (mtime 11-15 00:50, pre-session, Chromium not
yue-server): `2087d9af…dmp` (`f701373b…`), `494f6183…dmp` (`67702aec…`), `828697ea…dmp` (`30be5021…`),
`8b081a1a…dmp` (`6adcf5b2…`). Full-memory snapshots; may embed URLs/tokens. Also do not upload raw
`library.sqlite`/`studio-hub.json` (contain full lyrics/personal state) — upload extracted job rows only.

## 4. Session timeline around the crashes (all local, UTC+8)

- 10:14:44 SAC all-allow window opens (gentle-window-watch cycle 11); window1 harness auto-fires
- 10:16:36 window1 harness exit=0 (32 PASS / 1 FAIL: `negative/no-kernel-pack`)
- 10:17–10:19 phase2a GUI relaunch
- 10:23:06–10:27:45 phase2b run #1 (progress shots 26–30)
- 10:24 **first GUI generation completes** (job `59e23fcdb662a0d1`, seeds `138707761/12307929`, 9 tracks 419.4 s in 78.2 s)
- 10:30:46 / 10:32:00 / 10:33:45 / 10:35:42 **nokp repro iso engines start** (ports 18123…, concurrent GPU consumers)
- 10:31:40–10:32:43 phase2c cancel + resubmit → the jobs that later fail
- 10:33:42–10:37:27 phase2b run #2 (b20 progress 1–25)
- **10:35:52 crash #1** (iso-engine err-log flush 10:35:51.91)
- 10:37–10:39:03 window2 exclusive harness (33 PASS / 0 FAIL) — overlapping crash #2
- **10:38:58 crash #2** (window2 nokp negative-test death 10:38:58.07)
- 10:40:58 / 10:42:39 app restarts; 10:43:06 recovery job completes; 10:44 FLAC lands
- 10:47–11:37 six controlled repros (see §5); 11:45–11:52 reports 18/20 finalized

Key structural fact: both WER crash timestamps land **within 0.15 s** of the logged deaths of *byte-identical*
iso engines (same `yue-server.exe` SHA → same WER bucket signature `faad627d`) that were running as **concurrent
GPU consumers** and died with an explicit `rocBLAS … TensileLibrary.dat … gfx1100` error — the exact
resource-contention signature report 22 §5 root-caused for the window1 nokp FAIL (GPU/VRAM preemption under
overlapping automation). This is a strong *correlation*, not a proof: without readable WER records or stacks,
whether the two GUI-engine WER folders are the GUI engines themselves or the iso engines' reports landing in the
same bucket **cannot be distinguished from disk mtimes alone** (gap G2/G4).

## 5. Corrections to prior claims (material for PR #242 reconciliation)

1. **"Six controlled reproductions — the exact request (same seeds)" is not supported by the preserved artifacts.**
   The six repro logs/verdicts replay seeds `lm_seed 138707761 / seed 12307929` — job `59e23fcdb662a0d1`, the
   10:24 **successful** generation — plus four random seeds (`317467937 / 880045827 / 1056887034 / 756365321`)
   and the GUI flags (repro6). The actually-crashed jobs' seeds (`2251192151/3460034790` and
   `3808600514/1033658158`) were **never replayed**. Reproduction matrix row A (original request, original
   seeds) therefore remains **NOT RUN**.
2. **The "two crashes" count is not fully resolved.** The DB shows 4 failed/lost jobs from that session
   (`1c03`, `51e1`, `b8439`, `edaa`) with supervisor messages citing `exit code 0x1` (which can be a clean
   fail-closed exit, not necessarily a native crash), while the `faad627d` WER bucket holds **8** folders,
   of which only 2 are documented as GUI crashes and ≥2 coincide to the second with iso-engine deaths.
   4 folders (10:55, 10:57, 10:59, 11:01) post-date the GUI session and overlap the repro window whose logs show
   clean completions — unexplained on disk (gap G4).
3. The two issues must remain separate (mission 2.6): the no-kernel-pack negative-test anomaly (root-caused:
   concurrent GPU consumers) and the two GUI native crashes (unresolved). Time overlap exists (§4) but identical
   timing ≠ identical cause; exit codes differ (`0xc0000409` WER vs `exit code 0x1` supervisor messages);
   requests differ (failed jobs were 130 s/multi-track under cancel+resubmit churn).

## 6. Gaps preventing closure

| # | Gap | Consequence | Path to close |
|---|---|---|---|
| G1 | No yue-server `.dmp/.mdmp/.hdmp` exists anywhere; LocalDumps never configured | no stack, address, thread, module list → no fault-origin attribution | owner approval for LocalDumps (HKLM, mission 2.4 pre-authorization required) + one instrumented repro cycle |
| G2 | WER `Report.wer` files ACL-locked (SYSTEM/admins) | cannot map 8 same-bucket folders → processes; no EventTime/Sig per record | one elevated read-only pass over the 10 folders (owner-approved; the 11-15 `citool` elevation was cancelled by owner — re-ask, do not retry silently) |
| G3 | engine.log has no timestamps and no exception lines (buffered stdout lost at fast-fail) | crash instant per GUI engine is approximate (±s) | instrumented repro with line timestamps + stderr unbuffered |
| G4 | 4 unexplained WER folders (10:55–11:01) in the repro window | crash count/session attribution uncertain | closed together with G2 |
| G5 | No Application event-log export for the crash window (only CI channel, ends 08:23) | WER 1000/1001 records not in preserved set | read-only `Get-WinEvent Application` export for 10:00–12:00 local |
| G6 | repros replayed wrong seeds (§5.1) | row A of the matrix NOT RUN | replay true crashed seeds in the GPU phase |

## 7. Reproduction matrix (GPU phase — to run only with exclusive GPU, fixed provenance)

Fixed per run: engine `3c8b35b7` / exe `449ea33d…` / ggml-hip `5031256c…` / driver+ROCm as installed / request JSON
verbatim from engine.log job blocks / GPU exclusive (memory: NEVER run a 2nd GPU consumer during a harness).

| Row | Condition | Original seeds? | Status |
|---|---|---|---|
| A | exact crashed request `1c03a2dea0ea0704` (`2251192151/3460034790`), GUI flags | YES | **NOT RUN** |
| A′ | exact crashed request `edaa2dd16383929e` (`3808600514/1033658158`) | YES | NOT RUN |
| B | same requests, exclusive GPU (no iso engines, no window harness) | YES | NOT RUN |
| C | cold start vs warm start of A | YES | NOT RUN |
| D | 1-track short vs 9-track load | variant | partial (prior 6 repros used 9-track success seeds) |
| E | short (30 s) vs 130 s duration | variant | NOT RUN |
| F | GUI-initiated vs direct engine API | — | prior repros were direct API only; GUI path NOT RUN under exclusive GPU |
| G | cancel/resubmit churn before submit (phase2c pattern) | YES | NOT RUN (this matches the actual pre-crash sequence — highest-value row) |
| H | explicit HIP vs Auto start config | — | prior repros used explicit GUI flags |

Abort rule (mission 2.5): if the same fault reproduces twice, stop batch experiments, preserve the dump, analyze.

## 8. Root-cause routing (preliminary, unchanged)

No fix has been made; nothing to route yet. Working hypotheses in evidential order:
1. rocBLAS/TensileLibrary resource contention from concurrent GPU consumers (correlated to the second for both
   crashes; would route to **AMD HIP Runtime/rocBLAS** via minimal repro if proven under row B/A exclusivity);
2. fail-fast from a CRT abort path inside engine C++ under OOM/VRAM-preemption conditions (would route to
   **yue2.cpp**; needs G1 stack);
3. Studio-side job churn (cancel/resubmit during NAR) triggering an engine-side lifetime bug (row G; would route
   per finding — engine or Studio).
Not adopted without evidence: "ucrtbase.dll is broken" (module ≠ origin); "SAC did it" (SAC blocks produce
3077/3033/3118 + error 4551, not 0xc0000409; no such events correlate).

## 9. Release gate impact

Superseded by §10; kept for the audit trail of what was believed before the event-log pass.

## 10. Resolution (2026-11-15, application event log pass — no elevation used)

New evidence: `qa/crash-evidence/application-errors-0900-1230.json` — Application log, Event ID 1000/1001,
2026-11-15 09:00–12:30 (then widened to 2026-11-14 00:00 → 2026-11-15 12:30). Event 1000 carries the **full path
of the faulting process**, which WER folder names never did. Result (all ten yue-related events, full window):

| Time (local) | PID | Faulting process path |
|---|---|---|
| 11-14 20:36:59 | — | `qa\run-kernelpack-probe\iso\yue-server.exe` |
| 11-14 20:39:22 | — | `qa\run-df4b193-final-harness\iso-no-kernel-pack\yue-server.exe` |
| 11-15 10:25:24 | 0x2910 | `qa\pre-pr-final-engine\iso-no-kernel-pack\yue-server.exe` |
| 11-15 10:33:58 | 0x4694 | `qa\nokp-repro\iso-no-kernel-pack\yue-server.exe` |
| 11-15 10:35:52 | 0x5C98 | `qa\nokp-repro\iso-no-kernel-pack\yue-server.exe` ← "crash #1" |
| 11-15 10:38:58 | 0x425C | `qa\final-physical-validation-window2\iso-no-kernel-pack\yue-server.exe` ← "crash #2" |
| 11-15 10:55:34 | 0x39D0 | `qa\perf-zh-3c8b35b7\iso-no-kernel-pack\yue-server.exe` |
| 11-15 10:57:39 | 0x4A8C | `qa\perf-bf16-3c8b35b7\iso-no-kernel-pack\yue-server.exe` |
| 11-15 10:59:16 | 0x4A90 | `qa\perf-abc-3c8b35b7\iso-no-kernel-pack\yue-server.exe` |
| 11-15 11:01:35 | 0x5A9C | `qa\perf-bf16b-3c8b35b7\iso-no-kernel-pack\yue-server.exe` |

**Events with the GUI engine path (`qa\gui-final-run\app\resources\yue2-cpp\yue-server.exe`): 0 (zero).**

Every event: exception `0xc0000409`, module `ucrtbase.dll` 10.0.26100.9711, **offset always `0xa527e`**, WER
problem signature `BEX64` with **P9 = 7** — the fail-fast subcode `FAST_FAIL_FATAL_APP_EXIT`, i.e. a CRT
`abort()`-initiated termination (not a stack-cookie overrun, which raises a different subcode). One deterministic
abort site, hit by every iso copy whose rocBLAS kernel pack (`TensileLibrary.dat`) was removed — matching the
`rocBLAS error: Cannot read …TensileLibrary.dat … gfx1100` last line in each iso engine's log.

### 10.1 What the "two GUI crashes" actually were

WER buckets key on the module set, not the path: byte-identical exe → same bucket `faad627d…`. The GUI session's
engine and the harness iso copies share the same `yue-server.exe` SHA256 (`449ea33d…`), so the iso engines'
crash folders were indistinguishable from GUI-engine folders by name, and their timestamps (10:35:52 / 10:38:58)
fell inside the GUI session window. Report 18 §5 connected those two folders to the GUI session; the event log
now proves the processes were `qa\nokp-repro\iso-no-kernel-pack\…` (pid 5C98) and
`qa\final-physical-validation-window2\iso-no-kernel-pack\…` (pid 425C) — the negative-test engines running as
concurrent GPU consumers at exactly those instants. Misattribution, corrected.

### 10.2 The GUI session's actual failures (separate issue, unchanged)

The four failed/lost GUI jobs (`1c03`, `51e1`, `b8439`, `edaa`) ended with the supervisor recording
**exit code 0x1** — the engine's own fail-closed exit, no WER event, no native crash. This is the
concurrent-GPU-consumer contention already root-caused (report 22 §5: overlapping automation — GUI engine +
nokp iso engines on one card). Recovery at 10:43 succeeded. Issue remains closed as "QA-orchestration-induced";
product exposure is bounded by the watchdog (bounded retries at `4a8186eb`).

### 10.3 Real finding that remains: no-kernel-pack terminates via abort()

A user whose rocBLAS kernel pack is missing/corrupt (or blocked by an App Control verdict on a rocBLAS DLL —
report 21's family) gets an abort-style engine death (WER dialog, `0xc0000409`) instead of a clean error exit.
Functionally the Studio handles it (fail-closed, bounded retries, readable error), and the engine harness's
negative test already expects a nonzero exit. Improvement candidate, **engine-side, yue2.cpp**: preflight the
kernel-pack/library files before rocBLAS initialization and exit with the existing clean error path
(indicating the missing file) — removes the WER noise, gives users a precise message. Per mission 5.3 this is a
separate, minimal follow-up (do not expand PR #242); belongs in yue2.cpp's scope. Not fixed in this session.

### 10.4 Corrected verdict

- "Two native crashes of the GUI engine during the session" — **did not occur** (misattributed WER records).
- Native-crash exposure of the product binary — one deterministic path: rocBLAS-init abort on missing kernel
  pack (§10.3), bounded by the Studio watchdog; no other native-crash signature exists in the 36 h record.
- The six controlled repros' wrong-seed flaw (§5.1) is now moot for the *crash* question (there was no GUI
  crash to reproduce) but stands as a record-accuracy correction; rows A/A′ need no GPU time for this purpose.
- G2 gate: **native-crash risk reclassified from "unresolved stability risk" to "known, bounded, single-path
  abort on missing runtime data + engine-side preflight improvement candidate"** — disclosed as such.

### 10.5 Evidence addendum

`qa/crash-evidence/application-errors-0900-1230.json` (24 events 09:00–12:30 incl. 1001 WER-report records;
extracted read-only via `Get-WinEvent`, 2026-11-15 ~13:05 local). The wide-window pass (11-14 00:00 → 11-15
12:30, 12 events / 10 yue-related) was read live and is reproduced in the table above.

Per the GO/NO-GO contract: G2 remains **NOT MET (open risk, disclosed)**. Stable Release NO-GO stands while the
crash is unresolved; Developer Preview may carry an explicit limitation note at owner discretion.
