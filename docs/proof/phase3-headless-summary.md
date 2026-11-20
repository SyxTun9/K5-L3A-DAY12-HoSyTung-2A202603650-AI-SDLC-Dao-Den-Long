# Phase 3 headless evidence

Contract version: 1.2. Godot 4.7.2 direct runs produced the outcomes below.

| Scenario | Evidence |
|---|---|
| Refuel | Pass: two motes added 20 fuel; `refuel` emitted. |
| Relight and capacity growth | Pass: `lantern_lit` had `relight: true`; capacity rose to 12. |
| Shade drain and periodic event | Pass: after 60 ticks fuel was 14 and `fuel_drain` emitted. |
| Lamp exhaustion | Pass: `lantern_out` emitted at tick 1. |
| Dawn victory | Pass: `game_over.reason` was `dawn_survived`. |
| Dawn loss | Pass: `game_over.reason` was `dawn`. |

The Python regression harness was not executable in this environment: `py.exe` failed to start from the WindowsApps shim. Thus these direct Godot scenarios and project launch are verified, while the complete Python orchestration remains unverified here.

The previous Phase 2 win check expected an early `all_lanterns` win. It is intentionally replaced because Phase 3 makes dawn the only victory check. The win scenario now starts one second before dawn and verifies `dawn_survived`; dawn loss and zero-flame outcomes remain distinct.
