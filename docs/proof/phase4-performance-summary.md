# Phase 4 Performance & Soak Evidence

Environment: Godot 4.7.2 stable, Windows 64-bit, Test Contract v1.3.
Host Specs:
- OS: Windows 11 64-bit
- Engine: Godot Engine v4.7.2.stable.official.ed1daf0bf
- Renderer: GL Compatibility (NVIDIA GeForce RTX 3050 Laptop GPU)

---

## 1. Benchmark Results (`bench.json`)

Command executed:
```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path dao-den- --script res://scripts/bench.gd -- --seed 42 --duration 30 --out bench.json
```

Output:
```json
{
  "avg_fps": 161.7,
  "contract_version": "1.3",
  "frame_ms_p95": 9.9,
  "frames": 4852,
  "load_ms": 286,
  "os": "Windows",
  "p1_low_fps": 69.0,
  "peak_mem_mb": 75,
  "renderer": "Godot 4.7.2 GL Compatibility",
  "vsync_off": true
}
```

| Metric | Measured | Threshold | Status |
|---|---:|---:|:---:|
| `avg_fps` | 161.7 FPS | ≥ 60.0 FPS | PASS |
| `p1_low_fps` | 69.0 FPS | ≥ 30.0 FPS | PASS |
| `frame_ms_p95` | 9.9 ms | — | Healthy |
| `load_ms` | 286 ms | ≤ 10,000 ms | PASS |
| `peak_mem_mb` | 75 MB | — | Healthy |
| `vsync_off` | true | true | PASS |

---

## 2. Soak Test Results (`soak.json`)

Command executed:
```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path dao-den- --script res://scripts/soak.gd -- --seed 7 --nights 10 --out soak.json
```

Output:
```json
{
  "nights": 10,
  "crashes": 0,
  "results": [
    "lost", "lost", "lost", "lost", "lost",
    "lost", "lost", "lost", "lost", "lost"
  ],
  "mem_start_mb": 56,
  "mem_end_mb": 56,
  "duration_s": 2.5
}
```

| Metric | Measured | Threshold | Status |
|---|---:|---:|:---:|
| `crashes` | 0 | 0 | PASS |
| `mem_end_mb` vs `mem_start_mb` | 56 MB vs 56 MB (1.0x) | ≤ 1.2 × `mem_start_mb` (67.2 MB) | PASS |
| `duration_s` | 2.5 s | — | PASS |

---

## 3. Leaderboard Export CLI Check

Command executed:
```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path dao-den- -- --export-leaderboard out.json
```
Leaderboard correctly outputs ordered entries with fields:
`{"entries": [{"name": "...", "score": ..., "nights_won": ..., "achieved_at": "...", "seed": ...}]}`.
Sorted by `score` descending, with ties broken by earliest `achieved_at`.
