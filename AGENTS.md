# Agent instructions

- This is a Godot 4.7 GDScript game. The project is in `dao-den-`.
- Keep the playable game and `scripts/headless.gd` behavior aligned with `game.contract.json`.
- Run the game with `godot --path dao-den-`.
- Run the headless contract with `godot --headless --path dao-den- --script res://scripts/headless.gd -- --seed 1 --night 1 --ticks 600 --out user://run.jsonl`.
- Headless simulation uses fixed 60 Hz ticks and deterministic seeded randomness. Do not use frame delta in headless gameplay.
- Keep event names, JSONL field names, coordinate conventions, and tuning values in sync with the contract.
- Preserve prior phase behavior unless the next ticket explicitly changes it; update scenarios and evidence when behavior changes.
- Do not claim a requirement passed without a reproducible run or visual evidence.
