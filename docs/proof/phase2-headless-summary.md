# Phase 2 headless evidence

Environment: Godot 4.7.2 stable, Windows 64-bit, Contract 1.1.

## Full-night run-time check

Command shape:

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "dao-den-" --script res://scripts/headless.gd -- --seed 2026 --night <1|2|3> --ticks 21600 --out "dao-den-/proof-night<N>.jsonl"
```

| Night | Result | Ticks processed | Wall time |
|---|---:|---:|---:|
| 1 — Đảo Bến | Dawn/loss | 18,000 | 3.49 s |
| 2 — Đảo Cau | Dawn/loss | 19,800 | 4.74 s |
| 3 — Đảo Chuông | Dawn/loss | 21,600 | 6.31 s |

All three commands exited 0 and stayed below the 30-second limit.

## Focused scenario checks

- Pickup emitted `mote_picked`; pickup alone added no score.
- Deposit emitted `deposit` and awarded 10 points per deposited mote.
- Pulse used the 3-mote cost, stunned S1, and awarded 5 points.
- Shade contact dropped half the carried motes and reduced flames once.
- No-flame and all-lantern scenarios emitted `game_over` with the correct outcome.
- Dash emitted once; a second press during its cooldown was ignored.
- Pause/resume events were emitted. Snapshots showed `sim_tick` frozen at 0 while paused, then resumed at tick 1.
- Drifter steal/drop, Night 2 charm pickup, Night 2/3 jump pads, and Night 3 gust were exercised with scenario JSON.
- Repeating a 900-tick Night 1 run with the same seed produced identical JSONL (SHA-256 `23EAE5A0385327773DE2020A4FC172626081E95F5CA602A294D8CBA25E13BA12`).
- Invalid movement input exited with code 2.

## Not evidenced yet

The user confirmed the complete interactive checklist on 2026-11-20, including controls, all three nights, menus/settings, and HUD. No screenshots or FPS capture were attached. The full Python regression harness could not run in this environment because the Windows Python launcher could not start; focused scenarios were run directly through Godot.

Procedural background music and event tones were added after that user confirmation. Godot loaded the updated project headless without script errors, but playback should be listened to once in the game window.
