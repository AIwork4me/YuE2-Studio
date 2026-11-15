# Report 43 — Studio FLAC Download / real external export (physical GUI, Windows Radeon)

Date: 2026-11-15, 13:05–13:58 local (UTC+8). Bundle under test: the physically-verified `dab746e1` Tauri build
(`qa/gui-final-run/app`, engine `3c8b35b7` / exe `449ea33d…` in `app/resources/yue2-cpp`) — the export-flow code
is byte-identical between `dab746e1` and the PR head `4a8186eb` (verified: `git diff d2af77bb..dab746e1` touches
no desktop/app/saving code; watchdog commits touch none either), so this evidence transfers to the current code
path; re-verification at the `4a8186eb` binary itself remains listed as pending (needs a CI build — see report 41).

Test song: "Small steps, bright heart (1)" — library media `01a1dd17-c083-755f-a591-39083422aa5a.flac`,
10,689,060 B, SHA256 `F2127BFBFBE519BB54E52688E572B9749E77F0C65727747F4110094DD1597C07` (library original
re-hashed before the run — matches the recorded value). Because the server path is a byte-for-byte stream copy
(`saving.rs::copy`, no re-encode), export PASS requires the exported SHA to equal the source SHA exactly.

## 1. Why prior automation saw "no dialog" — root cause (closes the R2 mystery)

The native Save dialog **does exist and does open**. Two independent blind spots caused every earlier miss:

1. **UIA desktop-tree enumeration does not list the dialog** (`RootElement.FindAll(Children)` never returned it —
   reproduced repeatedly today), while raw `EnumWindows` sees it immediately (`#32770`, title `另存为`, owned by
   the app pid). The prior session's "OS window enumeration confirmed empty" (comment 6888778731's sibling claim)
   used the blind method. Win32 `EnumWindows` is the reliable observer.
2. **The dialog blocks the HTTP layer, not the DOM**: `POST /v1/files/save` stays pending for as long as the
   dialog is open (no timeout on either side — verified live: a request whose client died left the dialog open
   for 6+ minutes until closed). DOM-based automation sees zero state change and times out.

Also: the FilesPanel auto-opens docked right and **covers the row's overflow button** after a successful save —
subsequent coordinate clicks hit the panel (a real-user annoyance worth a look, and the trap that ate several
of today's click attempts).

## 2. Positive export — real GUI click → native dialog → external file (PASS ×5)

| # | Time | Initiation | Dialog answer | Result file | SHA256 == source |
|---|---|---|---|---|---|
| 1 | 13:17–13:19 | direct API POST `/v1/files/save` (chain probe) | on-screen user clicked 保存 (default name) | `qa/manualexport/probe-fresh.flac` 10,689,060 B | **YES** |
| 2 | 13:26–13:32 | GUI row menu → Download (CDP click) | on-screen user, default name | `qa/manualexport/Small steps, bright heart (1).flac` | **YES** |
| 3 | 13:28 | GUI click (stacked 2nd dialog) | on-screen user (typed `test1`) | `qa/manualexport/test1.flac` (overwritten) | **YES** |
| 4 | 13:39 | GUI click (dialog open since 13:37) | **scripted**: SetWindowText(edit id 1001) + WM_COMMAND save btn id 1 | `qa/gui-final-run/export/01a1dd17-export..flac` | **YES** |
| 5 | 13:57 | GUI click, **fresh app after restart** | **scripted**: settle 3.5 s → WM_COMMAND save (default name, no text edit) | `qa/gui-final-run/export/Small steps, bright heart (1).flac` | **YES** |

Evidence per run: dialog hwnd + control tree (`win32-answer-gui.log`, `win32-answer4-live.log`,
`default-save.log`), HTTP trace (`trace-2.json`: `HEAD /v1/library/media/01a1dd17…` → 200, `POST /v1/files/save`
pending while dialog open), FilesPanel done chip (panel text captured: name + 10.7 MB + path), and the files
themselves (retained: `export/`, `export/verified/`, `qa/manualexport/`).

Independent file verification of run 5: magic `fLaC`; STREAMINFO 48 000 Hz, 2 ch, 23-bit, 2 747 456 samples =
**57.24 s** (matches the Library's "0:57"); size 10 689 060 B; SHA256 `f2127bfb…c07` — **byte-identical to the
library original**, as the byte-copy contract requires. Runs 1–4 same SHA (table).

Answerer attribution is recorded honestly: runs 1–3's dialog answers were on-screen user actions (the owner was
present); runs 4–5 were fully scripted (logs show the exact SetWindowText/WM_COMMAND sequence and the
sub-second dialog close).

## 3. Negative tests

| Case | Result | Evidence |
|---|---|---|
| Cancel Save Dialog | **PASS** — no file created, no error shown (cancel is silent by design), POST resolved `{"cancelled":true}` | `win32-answer4-cancel.log` (dialog hwnd 1968564 → WM_CLOSE → `newFiles: []`) |
| Destination permission denied | **PARTIAL** — OS-level deny created and verified (`icacls /deny Rocm:(WD,AD)`, probe write → 拒绝访问); the readonly directory stayed empty after a save attempt; the server-side 500 + error-chip + `.part`-cleanup path is evidenced by code review (`saving.rs:185–205`) but was NOT cleanly demonstrated E2E — dialog-automation races (below) prevented a scripted confirm of the error chip | `make-readonly.ps1` output, `win32-answer4-denied*.log` |
| Restart → export again | **PASS** (run 5, app restarted 13:55, export 13:57) | `hybrid-restart.log` + `default-save.log` |
| Multiple downloads | **observed product quirk, not a test**: one GUI click fires `POST /v1/files/save` **1–2 times** (trace-2: 2 HEAD + 2 POST for one click; stacked dialogs observed 3×), producing stacked native dialogs; answering one leaves the other(s) open. Harmless when answered, but a real user clicking Download once can meet two dialogs. Recommend a frontend look (double-invocation of `downloadSongAudio`, likely double-mounted handler). Not fixed in this session (scope). | `trace-2.json`, `win32-answer4-live.log`, dialog counts in logs |
| Unicode title / Windows-invalid filename chars | covered by existing unit tests (`songDownload.test.ts`: Cyrillic title; `<>:"/\|?*` → `_`); server re-sanitizes (`saving.rs:58-59`); reserved device names (`CON`, `NUL`) unhandled by either layer — noted as upstream improvement. E2E not run (library titles fixed) | report of code review (§6 of review) |
| Missing source / broken URL / `.part` cleanup | error-contract documented by code review (silent console.error for HEAD failure — an observability gap; error chip for later failures); `.part` removed on any mid-write failure; E2E not run | code review table |

## 4. Dialog-automation findings (kept for the next session; also product-relevant)

- The Vista common-item dialog's `Edit` (ctrl id 1001) exists as a real HWND from the start, but its **DirectUI
  state ignores programmatic text for the first seconds** (SetWindowText and even UIA-on-HWND ValuePattern both
  verified to be silently discarded on dialogs <~6 s old; a ≥2-min-settled dialog accepted SetWindowText — run 4).
  Default-name WM_COMMAND save works at any age (run 5).
- Stacked dialogs + unanswered dialogs never time out (by design; client POST also unbounded). An abandoned
  dialog is invisible to UIA-tree watchers and survives attempted closes (one zombie `确认另存为` required an
  app restart). Product hardening candidates (out of scope here): single-flight the download click; consider a
  watchdog for unanswered dialogs.

## 5. Gate verdict

**G3 (FLAC Download) = PASS at `dab746e1` (physically, user-equivalent GUI flow, byte-verified external file,
plus cancel and restart-then-export).** Re-verification on a `4a8186eb` binary is the only remaining formality
(blocked on the fork Actions outage, report 41 §4). The old public statement "this UI build triggers no native
save dialog" is disproven and should be corrected in the upstream record (report 45 §3).
