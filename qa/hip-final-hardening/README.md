# HIP-FINAL-HARDENING — evidence & reports (2026-11-15 session)

Branch base: `4a8186eb` = PR [timoncool/YuE2-Studio#242](https://github.com/timoncool/YuE2-Studio/pull/242) head
(watchdog commits). This branch adds **review-only QA evidence**; it is not part of the PR diff and requests no
merge. Machine: Windows 11 26300, RX 7900 XTX (gfx1100), engine `3c8b35b7` / yue-server `449ea33d…` /
ggml-hip `5031256c…` (override `39927eae`).

## Read this first

| Report | Subject | One-line verdict |
|---|---|---|
| `reports/41-studio-watchdog-latest-head-ci.md` | Watchdog review + local gates + CI | review-clean; Vitest 213/213, build, tsc green locally; CI BLOCKED — fork Actions outage (all API fixes attempted) |
| `reports/42-yue-server-native-crash-rca.md` | The two `0xc0000409` "GUI crashes" | **misattributed** — event-log ID 1000 paths prove all 10 native crashes were `iso-no-kernel-pack` harness copies; the GUI engine never crashed; residual: nokp path aborts (yue2.cpp preflight candidate) |
| `reports/43-studio-flac-download-e2e.md` | Real FLAC export | **PASS** — 5 external exports via real GUI + native 另存为 dialog, all byte-identical (`f2127bfb…c07`); cancel + restart-then-export PASS; the old "no native dialog" claim disproven (UIA tree enumeration is blind to it) |
| `reports/45-upstream-evidence-reconciliation.md` | PR comments 6888314249 vs 6888778731 | per-item reconciliation by artifacts; corrections drafted, nothing deleted |
| `reports/46-upstream-pr-readiness.md` | PR states + what remains | heads: ggml `39927eae` / yue2.cpp `81f3200e` / Studio `4a8186eb`; no maintainer feedback yet |
| `reports/47-windows-hip-release-readiness.md` | Gate ladder | Preview CONDITIONAL GO; Signed Beta / Stable NO-GO |
| `reports/48-final-operation-hip-productization.md` | Final summary | the mission's 12 questions answered |
| `reports/evidence-ledger.json` | machine-readable ledger | appended key `hip_final_hardening_2026_11_15` |

(Report 44 — current-head GUI regression — intentionally absent: BLOCKED, no `4a8186eb` binary exists until the
fork's Actions is re-provisioned.)

## Directories

- `tools/` — this session's automation (Win32/UIA dialog drivers, CDP click/trace scripts). Start from
  `default-save.ps1`; see `reports/43` §4 for the quirks that shaped them.
- `evidence/export/` — dialog-driver logs + HTTP trace of the export runs (`trace-2.json` shows the exact
  `HEAD` → `POST /v1/files/save` flow).
- `evidence/crash/application-errors-0900-1230.json` — the decisive Application-log export (ID 1000 records
  faulting-process paths; 24 events incl. all ten yue-server native crashes, each an `iso-no-kernel-pack` copy).
- `evidence/pr242/` — verbatim captures of the two reconciled PR comments.
- `evidence/screenshots/` — GUI states from the export flow (`export-verdict.json` = the click script's output).
- `evidence/SHA256SUMS` / `FLAC-SHA256SUMS` — integrity of committed files, and of the exported FLACs.

## Deliberately NOT committed

Exported/library FLAC binaries (media stays out of git per AGENTS.md — every copy verified identical, see
`FLAC-SHA256SUMS`), `library.sqlite`, `studio-hub.json`, WebView2 Crashpad dumps (private memory images),
and the full screenshot series (the selected five suffice). All remain under `C:\dev\yue2-hip-nightly\` on the
test machine.
