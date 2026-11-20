# Phase 1 verification summary

Date: 2026-11-20 (ICT)

Engine: Godot 4.7.2 stable, Windows local run

## Results

- `tests/run_phase1_checks.py`: passed pickup, deposit, pulse/stun, hit/drop, win, lose, deterministic output, and invalid movement input checks.
- Same seed, scenario and inputs produced byte-identical JSONL on two 600-tick runs. SHA-256: `5ED65FDE97F44A2B98252CD2F5D83C2A57E216E2027D363361B4096CD70E6A09`.
- Invalid move component `[2, 0]` returned exit code `2`.
- Interactive scene initialized in headless mode for 5 frames without script errors.
- Visual inspection found the camera and WASD mapping defects; both were corrected. The running scene shows the island, motes, shade, and player marker.

## Evidence files

- `phase1-smoke.jsonl`: 120-tick headless smoke output.
- `phase1-pickup.jsonl`, `phase1-deposit.jsonl`, `phase1-pulse.jsonl`, `phase1-hit.jsonl`: behavior scenarios.
- `phase1-win.jsonl`, `phase1-lose.jsonl`: terminal outcomes and events.
- `phase1-determinism-a.jsonl`, `phase1-determinism-b.jsonl`: matching seeded outputs.
- `phase1-invalid-input.log`: malformed move rejected with exit code 2.

## Remaining verification

- A human playthrough from a fresh game through victory and a separate defeat has not been recorded.
- The project has not been executed on macOS/Linux in this environment. It uses standard Godot/GDScript APIs and the README provides the cross-platform Godot command, but target-OS evidence should be added when available.
- Add actual AI token/cost estimate from account usage data before final submission; it is not available in local project logs.
