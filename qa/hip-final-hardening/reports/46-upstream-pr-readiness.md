# Report 46 — Upstream PR readiness state (2026-11-15 afternoon session)

All three PRs re-verified live today; no maintainer comments/reviews exist on any of them.

| PR | Head (verified) | State | CI | This session's change |
|---|---|---|---|---|
| ggml #1 (`fix/hip-windows-fa-quants-stringify`) | `39927eae` | OPEN | last run 43595253167 success (prior session) | none — no GGML code changes; canonical-upstream routing (llama.cpp) remains the maintainer's call per its CONTRIBUTING |
| yue2.cpp #1 (`fix/native-hip-build-portability`) | **`81f3200e`** (moved since `18dcb8a`; local checkout stale) | OPEN | prior runs green at earlier heads; **81f3200e not CI-verified in this session** | none by us; local checkout must be re-fetched before any further engine work |
| Studio #242 (`fix/native-hip-pr-readiness`) | `4a8186eb` | OPEN, MERGEABLE, checks empty | **none on head — fork Actions outage (report 41 §4)** | watchdog head reviewed + local interface gates green; CI BLOCKED |

## Actions taken toward readiness today

- Evidence conflicts resolved by artifacts, not narrative: report 45 (comment-by-comment reconciliation of
  #6888314249 vs #6888778731; the library-original-as-export and no-native-dialog claims corrected; the
  "same seeds" repro claim corrected by report 42 §5.1).
- Crash disclosure updated: report 42 §10 reclassifies the two native crashes as harness-iso aborts with
  event-log path proof — this materially improves the PR's stability story and must reach the PR record.
- Nothing was pushed to any PR branch; no comments posted (owner authorization + human review required before
  any public communication, per standing policy; Studio AGENTS.md rules re-verified — no new runtime deps, no
  hardcoded model behavior, no user data committed; MIT license intact; CODEOWNERS/CONTRIBUTING/PR template:
  NOT PRESENT in all three repos, recorded).

## Recommended upstream posts (drafted, awaiting owner approval — human-reviewed before posting)

1. Studio #242: correction of the export evidence (real external FLAC exports now exist, byte-verified; the
   "no native dialog" claim withdrawn with root cause) + crash reattribution summary + pointer to the watchdog
   head CI (once Actions returns).
2. yue2.cpp #1: optional minimal follow-up — kernel-pack preflight before rocBLAS init (turns the abort-style
   death into the engine's clean error path; removes WER noise). Separate commit, owner decision.
3. ggml #1: no change.

## Outstanding before "Ready for Review" can be claimed for #242

- Green CI on `4a8186eb` (fork Actions must be re-provisioned by the owner — browser visit to the repo's
  Actions tab; API-side exhausted, report 41).
- Watchdog fault-injection physical test (mission 4.2) on a `4a8186eb` binary.
- One current-head GUI E2E re-run (mission 4) on the same binary.
- FLAC export re-verification on that binary (formality; code path identical — report 43).
