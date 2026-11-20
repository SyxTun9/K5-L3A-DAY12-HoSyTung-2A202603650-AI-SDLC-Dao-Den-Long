# Phase 1 notes — PRD-0

## Assumptions and tuning

The PRD leaves most gameplay numbers open. These are the Phase 1 choices, also recorded in `game.contract.json`:

- Mây starts with 3 flames; losing all 3 loses the night. The night also ends in a loss after 300 seconds.
- Each of the 5 lanterns costs 5 motes. Carry capacity is 10.
- Pickup radius is 1.5 m; lantern interaction radius is 2.5 m.
- A pulse spends 1 carried mote, affects shades within 8 m, stuns them for 2 s, pushes them 3 m, and has a 1 s cooldown.
- A shade moves at 2.5 m/s, hits within 1.2 m, and cannot enter a 3 m radius around a lit lantern.
- A hit grants 1.5 s invulnerability and drops floor(half of carried motes). Dropped motes scatter beyond the pickup radius.
- Falling off the island is disabled; the player is clamped to the circular island edge.
- Score: 10 per mote, 100 per lit lantern, 5 per shade stunned, 1 per second remaining on victory, and 25 per flame remaining.
- Movement uses camera-relative WASD; Space jumps, E interacts, Q pulses, right mouse drag rotates the top-down camera, and R restarts after game over.

## Acceptance and verification

| Requirement | Verification | Evidence | Status |
|---|---|---|---|
| Headless startup and JSONL snapshots/end | 120 tick smoke run | `docs/proof/phase1-smoke.jsonl` | Pass |
| Mote pickup event and score | pickup scenario | `docs/proof/phase1-pickup.jsonl` | Pass |
| Deposit and light a lantern | deposit scenario with interact input | `docs/proof/phase1-deposit.jsonl` | Pass |
| Pulse stuns a shade | pulse scenario | `docs/proof/phase1-pulse.jsonl` | Pass |
| Shade hit, flames and drop ratio | hit scenario | `docs/proof/phase1-hit.jsonl` | Pass |
| Win and loss termination events | pre-lit and no-flames scenarios | `docs/proof/phase1-win.jsonl`, `docs/proof/phase1-lose.jsonl` | Pass |
| Determinism | same seed and default scenario run twice, SHA-256 comparison | `docs/proof/phase1-determinism-a.jsonl`, `phase1-determinism-b.jsonl` | Pass |
| Invalid input exit code | out-of-range movement input | `docs/proof/phase1-invalid-input.log` | Pass, exit 2 |
| Full interactive playthrough to both outcomes | manual play | Not captured yet | Pending |
| Linux/macOS launch | run on target OS | Not captured in this environment | Pending |

## AI use log and evaluation

- Used ChatGPT/Codex for requirement interpretation, GDScript implementation, camera and movement debugging, and headless scenario checks.
- AI issues found and corrected: camera orientation initially looked away from the player; camera collision compressed the view; WASD axes were mapped with incorrect signs; headless event records were not emitted; hit-dropped motes spawned close enough to be picked up immediately.
- Detection: reviewed the running game screenshots and inspected JSONL scenario output.
- Harness improvement: added `AGENTS.md` with contract commands and invariants; added reusable headless scenarios under `tests/`.
- Token count/cost: unavailable from the local project logs. Add the estimate from the AI product's usage page before submission; do not invent a figure.

## Phase 1 review

The headless scenarios pass locally and repeated seeded output is byte-identical. Interactive scene initialization also passes a short headless startup. A complete human playthrough and macOS/Linux run remain to be recorded before treating Phase 1 as fully verified.
