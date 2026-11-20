"""Run the Phase 1 headless contract scenarios. Requires Godot 4.7 on PATH."""

import json
import os
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "dao-den-"
GODOT = os.environ.get("GODOT_BIN", "godot")


def run_case(name, scenario, inputs=None, seed=11, ticks=3, output_dir=None):
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
        "1",
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
        assert pickup[-1]["type"] == "end" and pickup[-1]["score"] == 10

        deposit = run_case(
            "deposit", "tests/scenarios/deposit.json", "tests/inputs/deposit.json", output_dir=temp_dir
        )
        assert {"deposit", "lantern_lit"}.issubset(set(event_names(deposit)))

        pulse = run_case(
            "pulse", "tests/scenarios/pulse.json", "tests/inputs/pulse.json", output_dir=temp_dir
        )
        pulse_event = next(record for record in pulse if record.get("name") == "pulse")
        assert pulse_event["data"]["stunned_ids"] == ["S1"]

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

    print("Phase 1 headless checks passed: pickup, deposit, pulse, hit, win, lose, determinism, invalid input.")


if __name__ == "__main__":
    main()
