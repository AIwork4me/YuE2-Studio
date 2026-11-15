# Report 45 — Upstream evidence reconciliation (PR #242 comments 6888314249 vs 6888778731)

Date: 2026-11-15. Both comments by the PR author's account (AIwork4me); no maintainer (timoncool) comments exist
on any of the three PRs as of 2026-11-15 ~12:50 local.

| | #6888314249 | #6888778731 |
|---|---|---|
| Posted (UTC / local) | 2026-11-15T03:04:20Z / **11:04 local** | 2026-11-15T03:49:55Z / **11:49 local** |
| Studio HEAD | `dab746e1` | `dab746e1` |
| Engine | `3c8b35b7` / exe `449ea33d…` | same |
| Headline | "Full GUI E2E — all 20 checklist items PASS" | "Final-head GUI evidence COMPLETE" + honest residuals |
| Data root | `qa/gui-final-run/` | same |

## 1. Per-item reconciliation (artifacts on disk are the referee)

### Playback
- Artifacts: `shots-phase2/play-verdict.json` (10:46:46 — `playing: false`, no samples → player-bar literal click **failed**);
  `shots-phase2/phase2i-verdict.json` (10:53:06 — per-track `Play:` aria control → `playAdvances: true`,
  12 transport samples `0:02→0:30 / 0:57` → **PASS via alternate control**).
- #6888314249 cites the success artifact (phase2i) — accurate for what it cites.
- #6888778731's residual "the literal Play-transport … clicks did not complete under automation (WebAudio path,
  no `<audio>` element)" — accurate for the player-bar path (play-verdict.json).
- **Resolution:** both statements are true but describe different controls. Playback is PASS on the evidence
  (phase2i), with the player-bar control disclosed as automation-limited. #6888314249's "all 20 PASS" framing
  without the per-control caveat overstated uniformity; the caveat arrived in #6888778731.

### Export / FLAC download
- Artifacts: `shots-phase2/p2-menu-verdict.json` (11:46:54 — `exportItemClicked: "Download"`, **`newFiles: []`**);
  `qa/gui-final-run/export/` directory **empty since creation 10:17:30**; the cited FLAC
  `dataroot/media/01a1dd17-c083-755f-a591-39083422aa5a.flac` (SHA256 `F2127BFB…D1597C07`, 10,689,060 B) is the
  **library original** written by generation at 10:44, not an export product.
- #6888314249's claim "Export: … verified artifact media/01a1dd17….flac … This UI build triggers no native save
  dialog — OS window enumeration confirmed empty" is **wrong on both counts** by code review at this head:
  the native save dialog **does exist** (`desktop/src-tauri/src/lib.rs:714-729` registers
  `music_server::set_save_dialog` → `tauri_plugin_dialog` `blocking_save_file()`, parented to the main window);
  it is a Win32 window that DOM-level automation cannot see or drive, which fully explains
  "OS window enumeration (of the WebView) found nothing" and `newFiles: []` (dialog unanswered → no write).
  Citing the library original as the export artifact conflates generation output with user export.
- #6888778731's residual ("Export-dialog clicks did not complete under automation") is **accurate**.
- **Resolution:** Export at `dab746e1` = **NOT COMPLETED** (physical external file never produced). The earlier
  `d2af77bb` human click-through export remains the only true export PASS and stays attributed to that head.
  The "no native dialog in this UI build" statement must be corrected on the record (see §3).

### Native crashes
- Timeline: crashes at **10:35:52 / 10:38:58 local**; #6888314249 posted **11:04** (26 min after crash #2) with no
  mention; report 18 §5 (the crash documentation) mtime **11:49**; #6888778731 posted **11:49:55** with full
  disclosure.
- **Resolution:** #6888314249's omission is explained (not excused without note) by attribution still being in
  progress at 11:04; the disclosure followed as soon as the WER record was connected. Both comments are
  time-consistent with the analysis artifacts.
- One inaccuracy inside #6888778731: "Six controlled reproduction attempts — the exact request (same seeds)…"
  The preserved repro artifacts replay the **successful** job's seeds (`138707761/12307929`) + 4 random seeds +
  GUI flags — **not** the crashed jobs' seeds (`2251192151/3460034790`, `3808600514/1033658158`). See report 42 §5.1.
  Matrix row A therefore remains NOT RUN.

### Session identity
Both comments describe the same physical session family (`qa/gui-final-run/`, phases 1–2, engine `3c8b35b7`,
exe `449ea33d…`, isolated data root, SDK env scrubbed, WebView2 CDP automation) — not two different runs.
Sub-phases differ (phase2i playback 10:53; p2-menu export click 11:46); no contradiction in session identity.

## 2. Final acceptance matrix (per task × version × session)

| Task | Head | Session | Result | Evidence |
|---|---|---|---|---|
| GUI generation (9-track, real GPU) | `dab746e1` + engine `3c8b35b7` | gui-final-run phase2b | PASS | engine.log `[Pipeline] Done: 9 tracks, 419.4 s in 78.2 s`; b20 shot series |
| GUI cancel + resubmit | `dab746e1` | phase2c | PASS (but the resubmitted jobs are the ones that later died — see report 42) | phase2c-verdict.json |
| GUI recovery after crashes | `dab746e1` | phase2e | PASS | 10:43 job completed 515.1 s in 85.8 s |
| Playback (per-track control) | `dab746e1` | phase2i | PASS | phase2i-verdict.json (playAdvances true) |
| Playback (player-bar literal click) | `dab746e1` | play attempt | NOT COMPLETED (automation limit, disclosed) | play-verdict.json |
| **Export — external file** | `dab746e1` | p2-menu | **NOT COMPLETED** (dialog invisible to DOM automation; `newFiles: []`; export dir empty) | p2-menu-verdict.json |
| Export (human click-through) | `d2af77bb` (older head) | manual session | PASS — bit-exact FLAC | attributed to that head, unchanged |
| Engine 33-check harness ×5 | engine `3c8b35b7` | window2/perf runs | 5× 33 PASS / 0 FAIL | reports 22/25 |
| Native crash stability | `dab746e1` | gui-final-run | **2 crashes, unresolved** | report 42 |
| Watchdog (bounded retries) | `4a8186eb` | — | code-reviewed + unit tests committed; **CI pending (stalled)** | report 41 |
| Studio CI | `4a8186eb` | fork CI | **PENDING — Actions stalled on fork account** | report 41 §CI |

## 3. Required public-record corrections (to post only with owner authorization)

1. Correct the export wording in the record superseding #6888314249: the library FLAC is generation output; the
   native save dialog exists but is invisible to DOM-level automation; external export at this head is NOT
   COMPLETED until Mission 3's physical UIA-driven test passes.
2. Correct the "same seeds" wording in the record superseding #6888778731 once the true-seed repros run
   (report 42 §7 row A/A′), or immediately if the owner prefers accuracy now.
3. Keep both original comments untouched — history is not edited; corrections go forward in new comments.

## 4. Rules honored

No comment deletion, no cherry-picking one report over the other, no transfer of `dab746e1` results to `4a8186eb`,
no relabeling of the library original as an export, "six non-reproductions" never reported as a fix.
