extends SceneTree

const TICK_RATE := 60
const LANTERN_POSITIONS := [
	Vector3(0, 0, 25),
	Vector3(23.776, 0, 7.725),
	Vector3(14.695, 0, -20.225),
	Vector3(-14.695, 0, -20.225),
	Vector3(-23.776, 0, 7.725)
]

var rng := RandomNumberGenerator.new()
var tuning: Dictionary
var player := {}
var motes: Array[Dictionary] = []
var shades: Array[Dictionary] = []
var lanterns: Array[Dictionary] = []
var inputs: Array = []
var events: Array[Dictionary] = []
var current_input := {"move": [0.0, 0.0], "cam_yaw_deg": 0.0}
var state := "playing"
var score := 0
var time_left := 0.0
var tick := 0
var last_json_error := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var options := _parse_args(args)

	if not options.get("ok", false):
		_fail(str(options.get("error", "Tham số dòng lệnh không hợp lệ.")), 2)
		return

	var project_root := ProjectSettings.globalize_path("res://").simplify_path()
	var contract_path := project_root.path_join("..").path_join("game.contract.json").simplify_path()
	var contract := _read_json(contract_path)
	if contract.is_empty():
		contract = _read_json("res://game.contract.json")
	if contract.is_empty():
		_fail("Không đọc được game.contract.json tại gốc repo.", 1)
		return

	tuning = contract.get("tuning", {})
	if tuning.is_empty():
		_fail("game.contract.json thiếu mục tuning.", 1)
		return

	rng.seed = int(options["seed"])
	if not _setup_game(options):
		return

	var total_ticks: int = int(options["ticks"])
	var snapshot_every: int = int(options["snapshot_every"])
	var output_lines: Array[String] = []
	var emitted_event_count := 0

	output_lines.append(JSON.stringify(_snapshot()))

	for step in range(total_ticks):
		if state != "playing":
			break

		_apply_input_for_tick(step)
		_simulate_tick()
		tick += 1

		while emitted_event_count < events.size():
			output_lines.append(JSON.stringify(events[emitted_event_count]))
			emitted_event_count += 1

		if state != "playing":
			output_lines.append(JSON.stringify({
				"type": "event",
				"tick": tick,
				"name": "game_over",
				"data": {
					"result": state,
					"reason": _end_reason()
				}
			}))

		if tick % snapshot_every == 0:
			output_lines.append(JSON.stringify(_snapshot()))

	var output_path: String = str(options["out"])
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		_fail("Không thể ghi file output: " + output_path, 1)
		return

	for line in output_lines:
		file.store_line(line)

	file.store_line(JSON.stringify({
		"type": "end",
		"ticks": tick,
		"state": state,
		"score": score
	}))
	file.close()
	quit(0)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var result := {
		"ok": true,
		"seed": 1,
		"night": 1,
		"ticks": 600,
		"out": "user://headless-output.jsonl",
		"snapshot_every": 10,
		"scenario": "",
		"inputs": ""
	}

	var i := 0
	while i < args.size():
		var key := args[i]
		if i + 1 >= args.size():
			return {"ok": false, "error": "Thiếu giá trị cho " + key}

		var value := args[i + 1]
		match key:
			"--seed":
				result["seed"] = value.to_int()
			"--night":
				result["night"] = value.to_int()
			"--ticks":
				result["ticks"] = value.to_int()
			"--out":
				result["out"] = value
			"--snapshot-every":
				result["snapshot_every"] = value.to_int()
			"--scenario":
				result["scenario"] = value
			"--inputs":
				result["inputs"] = value
			_:
				return {"ok": false, "error": "Tham số không hỗ trợ: " + key}
		i += 2

	if result["night"] != 1:
		return {"ok": false, "error": "Phase 1 chỉ hỗ trợ --night 1."}
	if result["ticks"] < 0 or result["snapshot_every"] <= 0:
		return {"ok": false, "error": "--ticks phải >= 0 và --snapshot-every phải > 0."}

	return result


func _setup_game(options: Dictionary) -> bool:
	player = {
		"pos": Vector3.ZERO,
		"carried": 0,
		"flames": int(tuning.get("flames", 3)),
		"invuln_ticks": 0,
		"pulse_cooldown_ticks": 0
	}

	lanterns.clear()
	for i in range(int(tuning.get("lantern_count_night1", 5))):
		lanterns.append({
			"id": "L%d" % (i + 1),
			"pos": LANTERN_POSITIONS[i],
			"lit": false,
			"deposited": 0
		})

	motes.clear()
	shades.clear()
	time_left = float(tuning.get("night1_duration_s", 300))

	if not str(options["scenario"]).is_empty():
		var scenario: Dictionary = _read_json(str(options["scenario"]))
		if not last_json_error.is_empty():
			_fail("Scenario không hợp lệ: " + last_json_error, 2)
			return false
		_apply_scenario(scenario)
	else:
		_spawn_default_motes()
		_spawn_default_shades()

	if not str(options["inputs"]).is_empty():
		var input_file: Dictionary = _read_json(str(options["inputs"]))
		if not last_json_error.is_empty() or not input_file.get("frames", null) is Array:
			_fail("Inputs không hợp lệ: cần object có mảng frames.", 2)
			return false
		inputs = input_file["frames"]
		if not _validate_inputs():
			return false
	return true


func _apply_scenario(scenario: Dictionary) -> void:
	var p: Dictionary = scenario.get("player", {})
	var p_pos: Array = p.get("pos", [0, 0, 0])
	player["pos"] = _vector_from_array(p_pos)
	player["carried"] = int(p.get("carried", 0))
	player["flames"] = int(p.get("flames", tuning.get("flames", 3)))
	time_left = float(scenario.get("time_left_s", tuning.get("night1_duration_s", 300)))

	if scenario.has("motes"):
		for item in scenario["motes"]:
			motes.append({"id": "M%d" % (motes.size() + 1), "pos": _vector_from_array(item)})
	elif bool(scenario.get("random_motes", true)):
		_spawn_default_motes()

	if scenario.has("shades"):
		for item in scenario["shades"]:
			shades.append({
				"id": str(item.get("id", "S%d" % (shades.size() + 1))),
				"pos": _vector_from_array(item.get("pos", [10, 0, 0])),
				"state": "chase",
				"stun_ticks": 0
			})
	elif bool(scenario.get("random_shades", true)):
		_spawn_default_shades()

	for update in scenario.get("lanterns", []):
		for lantern in lanterns:
			if lantern["id"] == str(update.get("id", "")):
				if update.has("pos"):
					lantern["pos"] = _vector_from_array(update["pos"])
				lantern["deposited"] = int(update.get("deposited", lantern["deposited"]))
				lantern["lit"] = bool(update.get("lit", false))


func _spawn_default_motes() -> void:
	for i in range(30):
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(3.0, 22.0)
		motes.append({
			"id": "M%d" % (i + 1),
			"pos": Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		})


func _spawn_default_shades() -> void:
	shades.append({
		"id": "S1",
		"pos": Vector3(12, 0, 12),
		"state": "chase",
		"stun_ticks": 0
	})


func _validate_inputs() -> bool:
	var previous_tick := -1
	for frame in inputs:
		if not frame is Dictionary or not frame.has("tick"):
			_fail("Mỗi input frame phải có tick.", 2)
			return false
		var frame_tick := int(frame["tick"])
		if frame_tick <= previous_tick:
			_fail("Tick trong inputs phải tăng nghiêm ngặt.", 2)
			return false
		previous_tick = frame_tick

		if frame.has("move"):
			var move: Array = frame["move"]
			if move.size() != 2 or absf(float(move[0])) > 1.0 or absf(float(move[1])) > 1.0:
				_fail("move phải là [x,z], mỗi thành phần trong [-1,1].", 2)
				return false
	return true


func _apply_input_for_tick(step: int) -> void:
	for frame in inputs:
		if int(frame["tick"]) == step:
			for key in frame:
				if key != "tick":
					current_input[key] = frame[key]


func _simulate_tick() -> void:
	var dt := 1.0 / float(TICK_RATE)
	time_left = maxf(0.0, time_left - dt)

	if int(player["invuln_ticks"]) > 0:
		player["invuln_ticks"] -= 1
	if int(player["pulse_cooldown_ticks"]) > 0:
		player["pulse_cooldown_ticks"] -= 1

	_move_player(dt)
	_pickup_motes()
	_interact_with_lantern()
	_try_pulse()
	_update_shades(dt)
	_check_game_end()


func _move_player(dt: float) -> void:
	var move: Array = current_input.get("move", [0.0, 0.0])
	var x := float(move[0])
	var z := float(move[1])
	var direction := Vector3(x, 0, z)

	if direction.length() > 1.0:
		direction = direction.normalized()

	var yaw := deg_to_rad(float(current_input.get("cam_yaw_deg", 0.0)))
	var rotated := Vector3(
		direction.x * cos(yaw) + direction.z * sin(yaw),
		0,
		-direction.x * sin(yaw) + direction.z * cos(yaw)
	)
	player["pos"] += rotated * float(tuning.get("player_speed", 6.0)) * dt


func _pickup_motes() -> void:
	var radius := float(tuning.get("pickup_radius", 1.5))
	var capacity := int(tuning.get("carry_capacity", 10))
	var i := motes.size() - 1

	while i >= 0 and int(player["carried"]) < capacity:
		if _flat_distance(player["pos"], motes[i]["pos"]) <= radius:
			motes.remove_at(i)
			player["carried"] += 1
			score += int(tuning.get("score", {}).get("per_mote", 10))
			_emit("mote_picked", {"carried": player["carried"]})
		i -= 1


func _interact_with_lantern() -> void:
	if not _pressed_this_tick("interact"):
		return

	var nearest: Dictionary = {}
	var nearest_distance := INF
	for lantern in lanterns:
		if lantern["lit"]:
			continue
		var distance := _flat_distance(player["pos"], lantern["pos"])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = lantern

	if nearest.is_empty() or nearest_distance > float(tuning.get("interact_radius", 2.5)):
		return

	var cost := int(tuning.get("lantern_cost", 5))
	var needed := cost - int(nearest["deposited"])
	var amount := mini(needed, int(player["carried"]))
	if amount <= 0:
		return

	player["carried"] -= amount
	nearest["deposited"] += amount
	_emit("deposit", {
		"lantern_id": nearest["id"],
		"amount": amount,
		"deposited": nearest["deposited"]
	})

	if int(nearest["deposited"]) >= cost:
		nearest["lit"] = true
		score += int(tuning.get("score", {}).get("per_lantern", 100))
		_emit("lantern_lit", {"lantern_id": nearest["id"]})


func _try_pulse() -> void:
	if not _pressed_this_tick("pulse"):
		return
	if int(player["pulse_cooldown_ticks"]) > 0:
		return
	if int(player["carried"]) < int(tuning.get("pulse_cost", 1)):
		return

	player["carried"] -= int(tuning.get("pulse_cost", 1))
	player["pulse_cooldown_ticks"] = int(round(float(tuning.get("pulse_cooldown_s", 1.0)) * TICK_RATE))

	var stunned: Array[String] = []
	var radius := float(tuning.get("pulse_radius", 8.0))

	for shade in shades:
		if shade["state"] == "stunned":
			continue
		if _flat_distance(player["pos"], shade["pos"]) <= radius:
			shade["state"] = "stunned"
			shade["stun_ticks"] = int(round(float(tuning.get("pulse_stun_s", 2.0)) * TICK_RATE))
			var away: Vector3 = shade["pos"] - player["pos"]
			away.y = 0
			if away.length_squared() > 0:
				shade["pos"] += away.normalized() * float(tuning.get("pulse_push_m", 3.0))
			stunned.append(str(shade["id"]))
			score += int(tuning.get("score", {}).get("per_stun", 5))

	_emit("pulse", {"stunned_ids": stunned})


func _update_shades(dt: float) -> void:
	for shade in shades:
		if shade["state"] == "stunned":
			shade["stun_ticks"] -= 1
			if int(shade["stun_ticks"]) <= 0:
				shade["state"] = "chase"
			continue

		var to_player: Vector3 = player["pos"] - shade["pos"]
		to_player.y = 0

		var protected := false
		for lantern in lanterns:
			if lantern["lit"] and _flat_distance(shade["pos"], lantern["pos"]) <= float(tuning.get("safe_radius", 3.0)):
				protected = true
				break
		if protected:
			continue

		if to_player.length_squared() > 0.001:
			shade["pos"] += to_player.normalized() * float(tuning.get("shade_speed", 2.5)) * dt

		if int(player["invuln_ticks"]) == 0 and _flat_distance(player["pos"], shade["pos"]) <= float(tuning.get("shade_hit_radius", 1.2)):
			_player_hit(shade)


func _player_hit(shade: Dictionary) -> void:
	player["flames"] -= 1
	player["invuln_ticks"] = int(round(float(tuning.get("invuln_s", 1.5)) * TICK_RATE))

	var dropped := int(floor(float(player["carried"]) * float(tuning.get("hit_drop_ratio", 0.5))))
	player["carried"] -= dropped
	for i in range(dropped):
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(1.8, 2.4)
		motes.append({
			"id": "M%d" % (motes.size() + 1),
			"pos": player["pos"] + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		})

	_emit("player_hit", {"by": "shade", "flames": player["flames"], "dropped": dropped})


func _check_game_end() -> void:
	var all_lit := true
	for lantern in lanterns:
		if not lantern["lit"]:
			all_lit = false
			break

	if all_lit:
		state = "won"
		score += int(floor(time_left)) * int(tuning.get("score", {}).get("per_second_left", 1))
		score += int(player["flames"]) * int(tuning.get("score", {}).get("per_flame_left", 25))
	elif int(player["flames"]) <= 0:
		state = "lost"
	elif time_left <= 0.0:
		state = "lost"


func _snapshot() -> Dictionary:
	var lantern_output: Array[Dictionary] = []
	for lantern in lanterns:
		lantern_output.append({
			"id": lantern["id"],
			"pos": _array_from_vector(lantern["pos"]),
			"lit": lantern["lit"],
			"deposited": lantern["deposited"]
		})

	var shade_output: Array[Dictionary] = []
	for shade in shades:
		shade_output.append({
			"id": shade["id"],
			"pos": _array_from_vector(shade["pos"]),
			"state": shade["state"]
		})

	return {
		"type": "snapshot",
		"tick": tick,
		"sim_tick": tick,
		"state": state,
		"time_left_s": snappedf(time_left, 0.001),
		"score": score,
		"player": {
			"pos": _array_from_vector(player["pos"]),
			"flames": player["flames"],
			"carried": player["carried"]
		},
		"lanterns": lantern_output,
		"shades": shade_output,
		"motes_active": motes.size()
	}


func _pressed_this_tick(action: String) -> bool:
	var pressed := bool(current_input.get(action, false))
	var was_pressed := bool(current_input.get("_previous_" + action, false))
	current_input["_previous_" + action] = pressed
	return pressed and not was_pressed


func _emit(name: String, data: Dictionary) -> void:
	events.append({"type": "event", "tick": tick + 1, "name": name, "data": data})


func _flat_distance(a: Vector3, b: Vector3) -> float:
	var delta := a - b
	delta.y = 0
	return delta.length()


func _vector_from_array(value: Array) -> Vector3:
	if value.size() < 3:
		return Vector3.ZERO
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _array_from_vector(value: Vector3) -> Array:
	return [
		snappedf(value.x, 0.001),
		snappedf(value.y, 0.001),
		snappedf(value.z, 0.001)
	]


func _read_json(path: String) -> Dictionary:
	last_json_error = ""
	if not FileAccess.file_exists(path):
		last_json_error = "không tìm thấy file " + path
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_json_error = "không mở được file " + path
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		last_json_error = "JSON lỗi dòng %d: %s" % [parser.get_error_line(), parser.get_error_message()]
		return {}
	if not parser.data is Dictionary:
		last_json_error = "nội dung JSON phải là object"
		return {}
	return parser.data


func _end_reason() -> String:
	if state == "won":
		return "all_lit"
	if int(player.get("flames", 0)) <= 0:
		return "no_flames"
	return "dawn"


func _fail(message: String, exit_code: int) -> void:
	push_error(message)
	quit(exit_code)
