# Phase 3 — “Đèn cạn dầu”

Contract version: **1.2**. This phase replaces the previous all-lamps/early-win objective with a fuel management loop and dawn survival.

## Acceptance checklist

- [x] Fuel max 100, decays 1/sec while lit; fuel tracked in deterministic integer subunits.
- [x] Refuel a lit, non-full nearby lamp at 10 fuel per mote; first ignition costs 10, relight costs 5.
- [x] Lamp exhaustion turns it off and resets deposit progress while preserving `ever_lit`.
- [x] Weak lamps below 30 lose their safety radius; wandering shades target them and drain 5/sec in range.
- [x] Dawn requires 60% of lamps, rounded up, and an alive player. No-flame loss has priority.
- [x] Capacity grows by two for each successful ignition/relight, capped at 20.
- [x] Updated scoring and colorblind setting; lamp fuel bar and low-fuel blinking are visible.
- [x] Refuel, relight, shade drain, dawn win, and dawn loss cases added to scenario checks.

See [ADR-001](adr-001-lamp-fuel-and-dawn-win.md) for the state and win-model decision. Historical Phase 1/2 proof files remain as records of their original contracts; Phase 3 checks run from `tests/run_phase1_checks.py`.
