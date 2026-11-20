"""Run Phase 1 regressions plus Phase 2 contract scenarios. Requires Godot 4.7 on PATH."""

import json
import os
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "dao-den-"
GODOT = os.environ.get("GODOT_BIN", "godot")


def run_case(name, scenario, inputs=None, seed=11, ticks=3, output_dir=None, night=1):
    output = output_dir / f"{name}.jsonl"
    log = output_dir / f"{name}.log"
    command = [
        GODOT,
        "--headless",
        "--log-file",
        str(log),
        "--path",
        str(PROJECT),
        "--script",
        "res://scripts/headless.gd",
        "--",
        "--seed",
        str(seed),
        "--night",
        str(night),
        "--ticks",
        str(ticks),
        "--scenario",
        str(ROOT / scenario),
        "--out",
        str(output),
    ]
    if inputs:
        command.extend(["--inputs", str(ROOT / inputs)])
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        raise AssertionError(f"{name} exited {result.returncode}: {result.stderr}\n{result.stdout}")
    records = [json.loads(line) for line in output.read_text(encoding="utf-8").splitlines()]
    return records


def event_names(records):
    return [record["name"] for record in records if record["type"] == "event"]


def main():
    with tempfile.TemporaryDirectory(prefix="dao-den-phase1-") as temp:
        temp_dir = Path(temp)

        pickup = run_case("pickup", "tests/scenarios/pickup.json", output_dir=temp_dir)
        assert "mote_picked" in event_names(pickup)
        assert pickup[-1]["type"] == "end" and pickup[-1]["score"] == 0

        deposit = run_case(
            "deposit", "tests/scenarios/deposit.json", "tests/inputs/deposit.json", output_dir=temp_dir
        )
        assert {"deposit", "lantern_lit"}.issubset(set(event_names(deposit)))

        pulse = run_case(
            "pulse", "tests/scenarios/pulse.json", "tests/inputs/pulse.json", output_dir=temp_dir
        )
        pulse_event = next(record for record in pulse if record.get("name") == "pulse")
        assert pulse_event["data"]["stunned_ids"] == ["S1"]

        dash = run_case("dash", "tests/scenarios/dash.json", "tests/inputs/dash.json", output_dir=temp_dir)
        assert event_names(dash).count("dash") == 1

        pause = run_case("pause", "tests/scenarios/pause.json", "tests/inputs/pause.json", ticks=4, output_dir=temp_dir)
        assert {"paused", "resumed"}.issubset(set(event_names(pause)))
        assert pause[-1]["state"] == "playing" and pause[0]["sim_tick"] == 0

        steal = run_case("drifter-steal", "tests/scenarios/drifter-steal.json", night=2, output_dir=temp_dir)
        assert "drifter_steal" in event_names(steal)
        drop = run_case("drifter-drop", "tests/scenarios/drifter-drop.json", "tests/inputs/pulse.json", night=2, output_dir=temp_dir)
        assert "drifter_drop" in event_names(drop)

        charm = run_case("charm", "tests/scenarios/charm.json", night=2, output_dir=temp_dir)
        assert "charm_picked" in event_names(charm)

        pad_night2 = run_case("pad-night2", "tests/scenarios/pad-night2.json", night=2, ticks=120, output_dir=temp_dir)
        assert pad_night2[-2]["player"]["pos"][0] > 40

        pad_night3 = run_case("pad-night3", "tests/scenarios/pad-night3.json", night=3, ticks=120, output_dir=temp_dir)
        assert pad_night3[-2]["player"]["pos"][2] < 8

        wind = run_case("wind", "tests/scenarios/wind.json", night=3, ticks=1800, output_dir=temp_dir)
        assert wind[-2]["night"] == 3 and wind[-2]["wind"]["active"] is True

        hit = run_case("hit", "tests/scenarios/hit.json", output_dir=temp_dir)
        hit_event = next(record for record in hit if record.get("name") == "player_hit")
        assert hit_event["data"]["flames"] == 2 and hit_event["data"]["dropped"] == 2
        assert "mote_picked" not in event_names(hit)

        win = run_case("win", "tests/scenarios/win.json", output_dir=temp_dir)
        assert win[-1]["state"] == "won" and "game_over" in event_names(win)

        lose = run_case("lose", "tests/scenarios/lose.json", output_dir=temp_dir)
        assert lose[-1]["state"] == "lost" and "game_over" in event_names(lose)

        det_a = run_case("det-a", "tests/scenarios/pickup.json", seed=2026, ticks=600, output_dir=temp_dir)
        det_b = run_case("det-b", "tests/scenarios/pickup.json", seed=2026, ticks=600, output_dir=temp_dir)
        assert (temp_dir / "det-a.jsonl").read_bytes() == (temp_dir / "det-b.jsonl").read_bytes()

        invalid_out = temp_dir / "invalid.jsonl"
        invalid = subprocess.run(
            [
                GODOT, "--headless", "--log-file", str(temp_dir / "invalid.log"),
                "--path", str(PROJECT), "--script", "res://scripts/headless.gd", "--",
                "--seed", "1", "--night", "1", "--ticks", "3",
                "--scenario", str(ROOT / "tests/scenarios/pickup.json"),
                "--inputs", str(ROOT / "tests/inputs/invalid-move.json"),
                "--out", str(invalid_out),
            ],
            capture_output=True,
            text=True,
        )
        assert invalid.returncode == 2, f"invalid input returned {invalid.returncode}, expected 2"

    print("Phase 2 contract checks passed: pickup, deposit, pulse, dash, pause, drifter, charm, wind, hit, win, lose, determinism, invalid input.")


if __name__ == "__main__":
    main()
