# Report 47 — Windows HIP release readiness (status delta, 2026-11-15)

Carries forward report 19/24/25 + SAC-RESOLUTION.md; only today's deltas are new.

## Improved today

1. **Stability risk downgraded with evidence (report 42 §10):** the only native-crash signature on the product
   binary in a 36-hour, 10-event record is a deterministic CRT-abort when the rocBLAS kernel pack is missing
   (all events were harness iso copies; the GUI engine never crashed). Combined with the bounded watchdog at
   the PR head, the "unexplained native crash" release blocker is closed as misattribution; remaining exposure
   is a known single-path abort with bounded retries and a candidate engine-side preflight (yue2.cpp).
2. **Export gate closed physically (report 43):** real external FLAC export via the real GUI + native dialog,
   byte-verified ×5, cancel + restart-then-export negatives included. One product experience gap (silent HEAD
   failure) and one quirk (1–2 save dialogs per click) filed as findings, not blockers.
3. **Interface gates at the PR head `4a8186eb`:** Vitest 213/213, build, tsc — green locally.

## Unchanged / still blocking Signed Beta & Stable (report 19 items)

1. Trusted code signing (cert still pending; signer infra ready — SAC-RESOLUTION.md).
2. Smart App Control real-world allowance of signed installers (needs the cert first).
3. AMD driver-provided HIP runtime delivery plan (docs-only so far).
4. GGML / yue2.cpp formal upstream pins (maintainer merges).
5. Clean-machine install + first-run generation/export (needs installer + signing).
6. Updater signature + isolation validation (build scripts exist, unsigned path only).
7. Third-party license/SBOM pass for the shipped closure.
8. **NEW blocker: fork Actions outage** — no CI/build path for `4a8186eb` until the owner re-provisions
   (report 41 §4); blocks watchdog fault-injection and current-head GUI E2E.

## Gate ladder (unchanged contract, today's values)

- Developer Preview: **CONDITIONAL GO** (stronger than yesterday: crash risk reclassified, export closed at
  `dab746e1`; still carries the SAC-on-clean-machines caveat and no `4a8186eb` binary yet).
- Signed Beta: **NO-GO** (cert, clean machine, updater — report 19 items 1–7).
- Stable Release: **NO-GO** (all of the above + maintainer authorization).
