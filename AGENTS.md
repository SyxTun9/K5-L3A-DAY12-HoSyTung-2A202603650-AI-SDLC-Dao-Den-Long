# Agent instructions

- This is a Godot 4.7 GDScript game. The project is in `dao-den-`.
- Phase 4 uses Contract v1.3. Keep gameplay, headless simulation, benchmark, soak test, `game.contract.json`, and the phase notes aligned.
- Run the game with `godot --path dao-den-`.
- Run headless with `godot --headless --path dao-den- --script res://scripts/headless.gd -- --seed 1 --night 1 --ticks 600 --out user://run.jsonl`.
- Run benchmark with `godot --path dao-den- --script res://scripts/bench.gd -- --seed 42 --duration 30 --out bench.json`.
- Run soak test with `godot --headless --path dao-den- --script res://scripts/soak.gd -- --seed 7 --nights 10 --out soak.json`.
- Export leaderboard with `godot --headless --path dao-den- -- --export-leaderboard out.json`.
- Headless simulation uses fixed 60 Hz ticks and deterministic seeded randomness. Do not use frame delta in headless gameplay.
- Keep event names, JSONL fields, coordinate conventions, night maps, tuning values, and tick ordering in sync with Contract v1.3.
- Preserve earlier behavior where later phases do not explicitly change it; later contract values replace prior values.
- A full night (21,600 ticks) must finish in 30 seconds or less.
- Benchmark targets: avg_fps >= 60, p1_low_fps >= 30, load_ms <= 10000.
- Soak test targets: 0 crashes, mem_end_mb <= 1.2 * mem_start_mb.
- Do not claim a requirement passed without a reproducible run or visual evidence.
