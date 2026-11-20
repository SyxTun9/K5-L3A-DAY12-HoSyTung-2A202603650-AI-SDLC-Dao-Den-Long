# Agent instructions

- This is a Godot 4.7 GDScript game. The project is in `dao-den-`.
- Phase 3 uses Contract v1.2. Keep gameplay, headless simulation, `game.contract.json`, and the phase notes aligned.
- Run the game with `godot --path dao-den-`.
- Run headless with `godot --headless --path dao-den- --script res://scripts/headless.gd -- --seed 1 --night 1 --ticks 600 --out user://run.jsonl`.
- Headless simulation uses fixed 60 Hz ticks and deterministic seeded randomness. Do not use frame delta in headless gameplay.
- Keep event names, JSONL fields, coordinate conventions, night maps, tuning values, and tick ordering in sync with the current contract.
- Preserve earlier behavior where later phases do not explicitly change it; later contract values replace prior values.
- Add at least one headless scenario for each new feature and run the Phase 1 regression suite after simulation changes.
- A full night (21,600 ticks) must finish in 30 seconds or less.
- Do not claim a requirement passed without a reproducible run or visual evidence.
