# Phase 2 spec — Ticket-02 “Ba hòn đảo”

## Acceptance criteria

### Normalized simulation and Contract v1.1

- [x] `game.contract.json` is version 1.1 and the standard tuning values match Ticket-02.
- [x] 60 Hz fixed-step simulation supports `--night 1|2|3`, tick-based inputs, seeded spawning, and identical JSONL for identical seeds/inputs.
- [x] Paused wall ticks increment `tick` while `sim_tick` and simulation timers freeze.
- [x] Snapshots include `night`, `wind`, player velocity/grounding/status timers, motes, drifters and charms; shade state names use the v1.1 values.
- [x] Invalid movement input exits 2. Full nights completed in 3.49 s, 4.74 s, and 6.31 s.
- [x] Phase 1 scenarios were rerun directly through Godot with normalized values; the Python regression harness itself was unavailable in this environment.

### Shared mechanics

- [ ] Running speed 6 m/s (7.2 while charmed), acceleration/damping within 0.1 s, full air control; jump 7 m/s under 20 m/s² gravity.
- [ ] Dash: 14 m/s for 12 ticks, 90-tick cooldown from activation, movement direction or facing direction while idle, fixed height in air, no invulnerability.
- [ ] Motes auto-pick at horizontal distance ≤1 m and vertical gap ≤1.5 m; start with 20 distinct map points, cap 30, respawn one on each 240th tick if a point is free.
- [ ] Lanterns cost 10, allow partial deposits, retain progress; interact within 2 m with nearest unlit lantern, id tie-break.
- [ ] Lit lantern safety radius 6 m; a shade inside on ignition is displaced within 30 ticks and cannot hit during that displacement.
- [ ] Pulse costs 3, cooldown 180 ticks, targets shades within 5 m 3D from player feet +0.8 m, stuns 120 ticks, pushes 4 m over first 15 ticks; each hit shade scores once per pulse.
- [ ] Shade movement, detection, hit height/range, one-hit-per-tick, recoil, invulnerability, mote drop/TTL, fall/recovery, and end-of-tick win/loss match Ticket-02.

### Night 1 — Đảo Bến

- [ ] Radius 40 m, spawn at origin facing +Z; five specified lantern coordinates.
- [ ] Mote points use radii 12 m/33 m; shade spawn points use radius 37 m and ≥15 m player separation.
- [ ] Two shades spawn at tick 300; one more every 480 ticks after; maximum six.

### Night 2 — Đảo Cau

- [ ] Two radius-28 m islands centered at (0,0,0) and (70,0,0), connected by the specified trestle bridge.
- [ ] Two jump pads preserve launch velocity and land on the opposite island; six lanterns use the specified order/positions.
- [ ] Mote and shade spawn points match both islands; shades spawn every 420 ticks, maximum eight.
- [ ] Drifters and Wind Charm behave as specified; charm C1 respawns after 2700 ticks.

### Night 3 — Đảo Chuông

- [ ] Radius 45 m map includes base, raised ring, central platform, cliffs, two ramps, jump pad and bell tower.
- [ ] Seven lanterns, 30 mote spawn points, shade points, 4.5 m/s shades, 360-second duration and 360-tick shade cadence.
- [ ] Gust direction is seeded/deterministic; gust occurs every 1800 ticks for 300 ticks, with 120-tick warning and 2 m/s push.
- [ ] Drifters and both charms match the ticket.

### Menus, HUD, settings, sound and performance

- [ ] Main menu → night intro → play → result → next night; defeat retries the same night; Night 3 victory shows dawn and total score.
- [ ] Esc/P pause menu offers resume, restart night, settings, and main menu. Simulation timers and spawns freeze while paused.
- [ ] Settings persist volume and mouse sensitivity. Required gameplay/background sounds are present.
- [ ] HUD displays flames, timer with low-time alert, lantern progress, score, 10-slot mote bar, dash/pulse cooldown, lantern interaction hint and offscreen lantern direction.
- [ ] Ticket palette is used within the stated tolerance; environment light follows `0.15 + 0.55 × lit/total`.
- [ ] Normal game averages at least 30 FPS at 1280×720.

## Phase 2 evaluation log

Core v1.1 simulation, scenario hooks, three-night maps, menu/intro/result flow, pause menu, persistent volume/mouse sensitivity, and procedural background/effect audio are implemented. The user confirmed the full interactive checklist on 2026-11-20. Headless timing/scenario evidence and the remaining machine-generated evidence gaps are recorded in [`../proof/phase2-headless-summary.md`](../proof/phase2-headless-summary.md). Token/cost estimates must be copied from account usage data; local logs do not provide that measurement.
