# Phase 3 headless evidence

Contract version: 1.2. Godot 4.7.2 stable + Python 3.13 direct runs produced the outcomes below.

| Scenario | Evidence | Status |
|---|---|---|
| Refuel | Pass: two motes added 20 fuel; `refuel` emitted. | Pass |
| Relight and capacity growth | Pass: `lantern_lit` had `relight: true`; capacity rose to 12. | Pass |
| Shade drain and periodic event | Pass: after 60 ticks fuel was 14 and `fuel_drain` emitted. | Pass |
| Lamp exhaustion | Pass: `lantern_out` emitted at tick 1. | Pass |
| Dawn victory | Pass: `game_over.reason` was `dawn_survived`. | Pass |
| Dawn loss | Pass: `game_over.reason` was `dawn`. | Pass |
| Determinism | Byte-identical JSONL across multiple runs with seed 2026. | Pass |
| Invalid input handling | Invalid inputs return exit code 2 as mandated by Contract 1.2. | Pass |

## Automated Regression Suite Results

All 16 test cases in `tests/run_phase1_checks.py` executed successfully in 8.35s:
`Phase 1–3 checks passed: pickup, deposit, refuel, relight, shade drain, pulse, dash, pause, drifter, charm, wind, hit, dawn win/loss, determinism, invalid input.`

The deposit scenario was updated to reflect the Contract 1.2 requirement of 10 carried motes for full ignition.
The previous Phase 2 win check expected an early `all_lanterns` win. It is intentionally replaced because Phase 3 makes dawn the only victory check. The win scenario starts one second before dawn and verifies `dawn_survived`; dawn loss and zero-flame outcomes remain distinct.
