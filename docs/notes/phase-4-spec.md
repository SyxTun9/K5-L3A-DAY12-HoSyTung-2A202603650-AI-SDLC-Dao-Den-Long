# Phase 4 Spec — Ticket-04 “Bình minh: phát hành v1.0.0”

Contract version: **1.3**. Type: Non-functional + Release.

## Acceptance Criteria

### 1. Benchmark Mode
- [x] Command: `<bench_cmd> --seed 42 --duration 30 --out bench.json`
- [x] Scene: 1280×720 windowed, V-Sync disabled.
- [x] Spawns 200 wandering shades, 100 motes, 3 lit lanterns with 100 fuel.
- [x] Camera rotates in 30 m radius at 15 m height, looking at (0,0,0), period 15 s.
- [x] Warmup 3 s ignored, measures 30 s.
- [x] Metrics met: `avg_fps` ≥ 60 (measured 161.7), `p1_low_fps` ≥ 30 (measured 69.0), `load_ms` ≤ 10000 (measured 286 ms).

### 2. Soak Test
- [x] Command: `<soak_cmd> --seed 7 --nights 10 --out soak.json`
- [x] Headless 10 consecutive nights cycling Night 1 → 2 → 3.
- [x] Seeded random inputs (movement direction change every 30 ticks; probabilities: 5% jump, 3% dash, 2% pulse, 10% interact).
- [x] 0 crashes, memory growth within threshold (`mem_end_mb` ≤ 1.2 × `mem_start_mb`, measured 56 MB → 56 MB).

### 3. Local Leaderboard
- [x] Persistent storage in `user://leaderboard.json`.
- [x] Prompts for player name (3–12 alphanumeric characters + underscore) upon defeat or Night 3 victory.
- [x] Stores: `name`, `score`, `nights_won`, `achieved_at` (ISO 8601 with timezone offset), `seed`.
- [x] Top 10 sorted by score descending, ties broken by earliest achieved date.
- [x] In-game leaderboard viewer accessible from main menu and pause screen.
- [x] CLI export supported via `<run_cmd> --export-leaderboard out.json`.

### 4. Accessibility
- [x] Key remapping for all actions (movement 4 directions, jump, dash, interact, pulse, pause). Duplicate detection with user warnings. "Reset to default" button provided. Persisted in settings.
- [x] Visual indicators & subtitles:
  - Shade spawned warning banner & HUD direction arrow.
  - Wind gust warning banner ("⚠ Gió mạnh đang nổi lên!").
  - Final 10 seconds countdown alert banner.
  - Low lamp fuel (<30) warning banner and blinking beacon.
- [x] Reduce motion toggle: disables camera trauma and screen flashes.
- [x] UI font size: default ≥ 18 px at 1280×720, with large text toggle (×1.25).

### 5. Packaging & Documentation
- [x] Clean README with clone-to-play within 3 commands.
- [x] Comprehensive retro note covering all 4 phases, AI errors, harness improvements, and token management.
- [x] `bench.json` and `soak.json` committed to repository.
- [x] Tag `phase-4` and Release `v1.0.0` with standalone run script / export package.
