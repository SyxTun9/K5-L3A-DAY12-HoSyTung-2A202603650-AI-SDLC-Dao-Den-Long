extends SceneTree

const HZ := 60
const SHADE_STATES := ["spawning", "wander", "chase", "recoil", "stunned", "drain"]

var rng := RandomNumberGenerator.new()
var tuning: Dictionary = {}
var night := 1
var tick := 0
var sim_tick := 0
var state := "playing"
var score := 0
var time_left_s := 0.0
var player: Dictionary = {}
var motes: Array[Dictionary] = []
var lanterns: Array[Dictionary] = []
var shades: Array[Dictionary] = []
var drifters: Array[Dictionary] = []
var charms: Array[Dictionary] = []
var mote_points: Array[Vector3] = []
var shade_points: Array[Vector3] = []
var events: Array[Dictionary] = []
var input_frames: Array = []
var current_input: Dictionary = {"move": [0.0, 0.0], "cam_yaw_deg": 0.0}
var last_json_error := ""
var mote_serial := 0
var shade_serial := 0
var drifter_serial := 0
var wind_enabled := true
var wind_active := false
var wind_dir_deg := 0.0
var allow_random_motes := true
var allow_random_shades := true
var allow_random_drifters := true


func _initialize() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	if not options.get("ok", false):
		_fail(str(options.get("error", "Invalid command line.")), 2)
		return

	var project_root := ProjectSettings.globalize_path("res://").simplify_path()
	var contract := _read_json(project_root.path_join("..").path_join("game.contract.json").simplify_path())
	if not last_json_error.is_empty() or contract.is_empty():
		contract = _read_json("res://game.contract.json")
	if not last_json_error.is_empty() or contract.is_empty():
		_fail("Cannot read game.contract.json: " + last_json_error, 1)
		return
	if not (str(contract.get("contract_version", "")) in ["1.2", "1.3"]):
		_fail("Expected game.contract.json contract_version 1.2 or 1.3.", 1)
		return
	tuning = contract.get("tuning", {})
	if tuning.is_empty():
		_fail("game.contract.json is missing tuning.", 1)
		return

	night = int(options["night"])
	rng.seed = int(options["seed"])
	if not _setup_game(options):
		return

	var output_lines: Array[String] = []
	var snapshot_every: int = int(options["snapshot_every"])
	output_lines.append(JSON.stringify(_snapshot()))
	_emit("night_start", {"night": night}, 0)
	var emitted_events := 0
	while emitted_events < events.size():
		output_lines.append(JSON.stringify(events[emitted_events]))
		emitted_events += 1

	for input_tick in range(int(options["ticks"])):
		if state == "won" or state == "lost":
			break
		tick += 1
		_apply_input(input_tick)
		if state == "paused":
			if _pressed("pause"):
				state = "playing"
				_emit("resumed", {}, tick)
		elif _pressed("pause"):
			state = "paused"
			_emit("paused", {}, tick)
		else:
			_simulate_tick()

		while emitted_events < events.size():
			output_lines.append(JSON.stringify(events[emitted_events]))
			emitted_events += 1
		if tick % snapshot_every == 0:
			output_lines.append(JSON.stringify(_snapshot()))

	var output_path: String = str(options["out"])
	var global_out := ProjectSettings.globalize_path(output_path)
	var parent_dir := global_out.get_base_dir()
	if not parent_dir.is_empty() and not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		_fail("Cannot write output file: " + output_path, 1)
		return
	for line in output_lines:
		output.store_line(line)
	output.store_line(JSON.stringify({"type": "end", "ticks": tick, "state": state, "score": score}))
	output.close()
	quit(0)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var result := {"ok": true, "seed": 1, "night": 1, "ticks": 600, "out": "user://headless-output.jsonl", "snapshot_every": 10, "scenario": "", "inputs": ""}
	var i := 0
	while i < args.size():
		var key := str(args[i])
		if key == "--help" or key == "-h":
			print("--seed N --night 1|2|3 [--scenario FILE] [--inputs FILE] --ticks N --out FILE [--snapshot-every N]")
			quit(0)
			return {"ok": false, "error": ""}
		if i + 1 >= args.size():
			return {"ok": false, "error": "Missing value for " + key}
		var value := str(args[i + 1])
		match key:
			"--seed": result["seed"] = value.to_int()
			"--night": result["night"] = value.to_int()
			"--ticks": result["ticks"] = value.to_int()
			"--out": result["out"] = value
			"--snapshot-every": result["snapshot_every"] = value.to_int()
			"--scenario": result["scenario"] = value
			"--inputs": result["inputs"] = value
			_: return {"ok": false, "error": "Unknown argument " + key}
		i += 2
	if int(result["night"]) < 1 or int(result["night"]) > 3:
		return {"ok": false, "error": "--night must be 1, 2, or 3."}
	if int(result["ticks"]) < 0 or int(result["ticks"]) > 21600 or int(result["snapshot_every"]) <= 0:
		return {"ok": false, "error": "ticks must be 0..21600 and snapshot interval must be positive."}
	return result


func _setup_game(options: Dictionary) -> bool:
	var scenario: Dictionary = {}
	_set_map()
	var duration_key := "night%d_duration_s" % night
	time_left_s = float(tuning[duration_key])
	var player_start := Vector3(0, 6, 0) if night == 3 else Vector3.ZERO
	player = {"pos": player_start, "vel": Vector3.ZERO, "grounded": true, "flames": int(tuning["flames"]), "carried": 0, "successful_lights": 0, "invuln_ticks": 0, "dash_cd_ticks": 0, "dash_ticks": 0, "dash_dir": Vector3(0, 0, 1), "pulse_cd_ticks": 0, "charm_ticks": 0, "respawn_ticks": 0, "respawn_pending": false, "pad_airborne": false, "facing": Vector3(0, 0, 1)}
	lanterns.clear()
	var lantern_count := int(tuning["lantern_count_night%d" % night])
	var lamp_positions := _lantern_positions()
	for i in range(lantern_count):
		lanterns.append({"id": "L%d" % (i + 1), "pos": lamp_positions[i], "deposited": 0, "lit": false, "fuel_u": 0, "ever_lit": false, "relit_count": 0})
	_mote_spawn_points()
	_shade_spawn_points()
	_setup_charms()
	input_frames.clear()
	if not str(options["scenario"]).is_empty():
		scenario = _read_json(str(options["scenario"]))
		if not last_json_error.is_empty():
			_fail("Invalid scenario: " + last_json_error, 2)
			return false
	allow_random_motes = bool(scenario.get("random_motes", true))
	allow_random_shades = bool(scenario.get("random_shades", true))
	allow_random_drifters = bool(scenario.get("random_drifters", true))
	if allow_random_motes:
		_spawn_initial_motes()
	if not scenario.is_empty():
		_apply_scenario(scenario)
		if not last_json_error.is_empty():
			_fail("Invalid scenario: " + last_json_error, 2)
			return false
	wind_enabled = bool(scenario.get("wind_enabled", true))
	if not str(options["inputs"]).is_empty():
		var input_object: Dictionary = _read_json(str(options["inputs"]))
		if not last_json_error.is_empty() or not input_object.get("frames", null) is Array:
			_fail("Invalid inputs: expected an object with a frames array. " + last_json_error, 2)
			return false
		input_frames = input_object["frames"]
		if not _validate_inputs():
			return false
	return true


func _set_map() -> void:
	lanterns.clear()
	shades.clear()
	drifters.clear()
	motes.clear()
	charms.clear()
	events.clear()
	mote_serial = 0
	shade_serial = 0
	drifter_serial = 0
	tick = 0
	sim_tick = 0
	score = 0
	state = "playing"
	wind_active = false
	wind_dir_deg = 0.0
	allow_random_motes = true
	allow_random_shades = true
	allow_random_drifters = true


func _lantern_positions() -> Array[Vector3]:
	match night:
		1:
			return [Vector3(0, 0, 25), Vector3(23.8, 0, 7.7), Vector3(14.7, 0, -20.2), Vector3(-14.7, 0, -20.2), Vector3(-23.8, 0, 7.7)]
		2:
			return [Vector3(0, 0, 20), Vector3(17, 0, -10), Vector3(-17, 0, -10), Vector3(70, 0, 20), Vector3(87, 0, -10), Vector3(53, 0, -10)]
		_:
			return [Vector3(0, 6, 6), Vector3(18, 3, 10), Vector3(-18, 3, 10), Vector3(35, 0, -10), Vector3(-35, 0, -10), Vector3(20, 0, -35), Vector3(-20, 0, -35)]


func _mote_spawn_points() -> void:
	mote_points.clear()
	if night == 1:
		for i in range(8):
			mote_points.append(_polar(12.0, i * 45.0))
		for i in range(16):
			mote_points.append(_polar(33.0, i * 22.5))
	elif night == 2:
		for center_x in [0.0, 70.0]:
			for i in range(4):
				mote_points.append(_polar(10.0, i * 90.0, Vector3(center_x, 0, 0)))
			for i in range(8):
				mote_points.append(_polar(22.0, i * 45.0, Vector3(center_x, 0, 0)))
	else:
		for i in range(18):
			mote_points.append(_polar(34.0, i * 20.0))
		for i in range(8):
			mote_points.append(_polar(18.0, 20.0 + i * 20.0))
		for deg in [45.0, 135.0, 225.0, 315.0]:
			mote_points.append(_polar(5.0, deg, Vector3(0, 6, 0)))


func _shade_spawn_points() -> void:
	shade_points.clear()
	if night == 1:
		for i in range(12):
			shade_points.append(_polar(37.0, 15.0 + i * 30.0))
	elif night == 2:
		for center_x in [0.0, 70.0]:
			for i in range(8):
				shade_points.append(_polar(26.0, 22.5 + i * 45.0, Vector3(center_x, 0, 0)))
	else:
		for i in range(16):
			shade_points.append(_polar(43.0, i * 22.5))


func _setup_charms() -> void:
	if night == 2:
		charms.append({"id": "C1", "pos": Vector3(35, 0, 0), "available": true, "respawn_ticks": 0})
	elif night == 3:
		charms.append({"id": "C1", "pos": Vector3(30, 0, 25), "available": true, "respawn_ticks": 0})
		charms.append({"id": "C2", "pos": Vector3(-30, 0, 25), "available": true, "respawn_ticks": 0})


func _spawn_initial_motes() -> void:
	var indices: Array[int] = []
	for i in range(mote_points.size()):
		indices.append(i)
	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	for i in range(mini(int(tuning["mote_initial_count"]), indices.size())):
		_spawn_mote(mote_points[indices[i]], "random", indices[i], -1, 0)


func _apply_scenario(scenario: Dictionary) -> void:
	if scenario.has("player"):
		if not scenario["player"] is Dictionary:
			last_json_error = "player must be an object"
			return
		var setup: Dictionary = scenario["player"]
		player["pos"] = _read_vec(setup.get("pos", [0, 6 if night == 3 else 0, 0]))
		player["carried"] = int(setup.get("carried", 0))
		player["flames"] = int(setup.get("flames", tuning["flames"]))
		player["invuln_ticks"] = int(setup.get("invuln_ticks", 0))
		player["dash_cd_ticks"] = int(setup.get("dash_cd_ticks", 0))
		player["pulse_cd_ticks"] = int(setup.get("pulse_cd_ticks", 0))
		player["charm_ticks"] = int(setup.get("charm_ticks", 0))
		player["dash_ticks"] = int(setup.get("dash_ticks", 0))
		player["respawn_ticks"] = int(setup.get("respawn_ticks", 0))
		player["vel"] = _read_vec(setup.get("vel", [0, 0, 0]))
		player["facing"] = _read_vec(setup.get("facing", [0, 0, 1]))
		var ground = _ground_height(player["pos"])
		player["grounded"] = bool(setup.get("grounded", ground != null and absf(player["pos"].y - float(ground)) < 0.05))
		time_left_s = float(scenario.get("time_left_s", time_left_s))
	if scenario.has("motes"):
		if not scenario["motes"] is Array:
			last_json_error = "motes must be an array"
			return
		motes.clear()
		for item in scenario["motes"]:
			var pos: Vector3
			var kind := "random"
			var id := ""
			if item is Dictionary:
				pos = _read_vec(item.get("pos", [0, 0, 0]))
				kind = str(item.get("kind", "random"))
				id = str(item.get("id", ""))
			else:
				pos = _read_vec(item)
			_spawn_mote(pos, kind, -1, -1, 0, id)
		if not last_json_error.is_empty():
			return
	if scenario.has("shades"):
		if not scenario["shades"] is Array:
			last_json_error = "shades must be an array"
			return
		shades.clear()
		for item in scenario["shades"]:
			if not item is Dictionary:
				last_json_error = "each shade must be an object"
				return
			var shade_state := str(item.get("state", "wander"))
			if not SHADE_STATES.has(shade_state):
				last_json_error = "unknown shade state " + shade_state
				return
			shade_serial += 1
			var left := int(item.get("state_ticks_left", 0))
			shades.append({"id": str(item.get("id", "S%d" % shade_serial)), "pos": _read_vec(item.get("pos", [10, 0, 0])), "state": shade_state, "state_ticks_left": left, "stun_ticks": left if shade_state == "stunned" else 0, "recoil_dir": Vector3.ZERO, "recoil_ticks": left if shade_state == "recoil" else 0, "safe_target": Vector3.ZERO, "safe_ticks": 0, "spawn_ticks": left if shade_state == "spawning" else 0, "target_lantern_id": str(item.get("target_lantern_id", "")), "drain_event_ticks": 0})
	if scenario.has("lanterns"):
		if not scenario["lanterns"] is Array:
			last_json_error = "lanterns must be an array"
			return
		for update in scenario["lanterns"]:
			if not update is Dictionary:
				last_json_error = "each lantern update must be an object"
				return
			for lantern in lanterns:
				if lantern["id"] == str(update.get("id", "")):
					if update.has("pos"):
						lantern["pos"] = _read_vec(update["pos"])
					lantern["deposited"] = int(update.get("deposited", lantern["deposited"]))
					lantern["lit"] = bool(update.get("lit", lantern["lit"]))
					lantern["ever_lit"] = bool(update.get("ever_lit", lantern["ever_lit"] or lantern["lit"]))
					var initial_fuel := int(round(float(update.get("fuel", float(tuning["fuel_max"]) if lantern["lit"] else 0.0)) * HZ))
					lantern["fuel_u"] = initial_fuel if lantern["lit"] else 0
					lantern["relit_count"] = int(update.get("relit_count", lantern["relit_count"]))
	if scenario.has("player") and scenario["player"] is Dictionary:
		var player_update: Dictionary = scenario["player"]
		player["successful_lights"] = int(player_update.get("successful_lights", 0))
		player["carried"] = int(player_update.get("carried", player["carried"]))
		player["flames"] = int(player_update.get("flames", player["flames"]))
		if player_update.has("pos"): player["pos"] = _read_vec(player_update["pos"])
	if scenario.has("time_left_s"):
		time_left_s = clampf(float(scenario["time_left_s"]), 0.0, float(tuning["night%d_duration_s" % night]))
	if scenario.has("drifters"):
		if not scenario["drifters"] is Array:
			last_json_error = "drifters must be an array"
			return
		drifters.clear()
		for item in scenario["drifters"]:
			if not item is Dictionary:
				last_json_error = "each drifter must be an object"
				return
			drifter_serial += 1
			drifters.append({"id": str(item.get("id", "D%d" % drifter_serial)), "pos": _read_vec(item.get("pos", [15, 0, 0])), "state": str(item.get("state", "idle")), "stolen": int(item.get("stolen", 0)), "state_ticks_left": int(item.get("state_ticks_left", 0)), "target": Vector3.ZERO, "spawn_ticks": 0})
	if scenario.has("charms"):
		if not scenario["charms"] is Array:
			last_json_error = "charms must be an array"
			return
		charms.clear()
		for item in scenario["charms"]:
			if not item is Dictionary:
				last_json_error = "each charm must be an object"
				return
			charms.append({"id": str(item.get("id", "C%d" % (charms.size() + 1))), "pos": _read_vec(item.get("pos", [0, 0, 0])), "available": bool(item.get("available", true)), "respawn_ticks": int(item.get("respawn_ticks", 0))})
	if scenario.has("wind_enabled"):
		wind_enabled = bool(scenario["wind_enabled"])


func _validate_inputs() -> bool:
	var previous_tick := -1
	for frame in input_frames:
		if not frame is Dictionary or not frame.has("tick"):
			_fail("Each input frame must have an integer tick.", 2)
			return false
		var frame_tick := int(frame["tick"])
		if frame_tick <= previous_tick:
			_fail("Input ticks must increase strictly.", 2)
			return false
		previous_tick = frame_tick
		if frame.has("move"):
			if not frame["move"] is Array or frame["move"].size() != 2:
				_fail("move must be [x,z].", 2)
				return false
			for v in frame["move"]:
				if not (v is int or v is float) or absf(float(v)) > 1.0:
					_fail("move components must be in [-1,1].", 2)
					return false
		for action in ["jump", "dash", "interact", "pulse", "pause"]:
			if frame.has(action) and not frame[action] is bool:
				_fail(action + " must be boolean.", 2)
	return true


func _apply_input(input_tick: int) -> void:
	for frame in input_frames:
		if int(frame["tick"]) == input_tick:
			for key in frame:
				if key != "tick":
					current_input[key] = frame[key]


func _simulate_tick() -> void:
	sim_tick += 1
	time_left_s = maxf(0.0, time_left_s - 1.0 / HZ)
	var was_respawning := int(player["respawn_ticks"]) > 0
	_decrement_counters()
	_apply_lamp_fuel_tick()
	_update_wind()
	if was_respawning and int(player["respawn_ticks"]) == 0 and bool(player["respawn_pending"]):
		player["pos"] = Vector3.ZERO
		player["vel"] = Vector3.ZERO
		player["grounded"] = true
		player["invuln_ticks"] = int(tuning["invuln_ticks"])
		player["respawn_pending"] = false
	_move_player()
	if int(player["respawn_ticks"]) == 0 and not was_respawning:
		_pickup_motes()
		_pickup_charms()
		_interact_lantern()
		_update_safe_zones()
		_try_pulse()
		_update_drifters()
		_update_shades()
		_check_contacts()
		_spawn_scheduled_entities()
	_check_game_end()


func _decrement_counters() -> void:
	for key in ["invuln_ticks", "dash_cd_ticks", "pulse_cd_ticks", "charm_ticks", "respawn_ticks"]:
		player[key] = maxi(0, int(player[key]) - 1)
	for mote in motes:
		if str(mote["kind"]) == "dropped":
			mote["ttl_ticks"] = int(mote["ttl_ticks"]) - 1
	for charm in charms:
		if not bool(charm["available"]):
			charm["respawn_ticks"] = maxi(0, int(charm["respawn_ticks"]) - 1)
			if int(charm["respawn_ticks"]) == 0:
				charm["available"] = true
	for shade in shades:
		if str(shade["state"]) == "stunned":
			shade["stun_ticks"] = maxi(0, int(shade["stun_ticks"]) - 1)
			shade["state_ticks_left"] = shade["stun_ticks"]
			if int(shade["stun_ticks"]) == 0:
				shade["state"] = "wander"
		elif str(shade["state"]) == "recoil":
			shade["recoil_ticks"] = maxi(0, int(shade["recoil_ticks"]) - 1)
			shade["safe_ticks"] = maxi(0, int(shade["safe_ticks"]) - 1)
			shade["state_ticks_left"] = maxi(int(shade["recoil_ticks"]), int(shade["safe_ticks"]))
			if int(shade["state_ticks_left"]) == 0:
				shade["state"] = "wander"
		elif str(shade["state"]) == "spawning":
			shade["spawn_ticks"] = maxi(0, int(shade["spawn_ticks"]) - 1)
			if int(shade["spawn_ticks"]) == 0:
				shade["state"] = "wander"
	for drifter in drifters:
		if str(drifter["state"]) == "flee":
			drifter["state_ticks_left"] = maxi(0, int(drifter["state_ticks_left"]) - 1)
		if str(drifter["state"]) == "removed":
			drifter["state_ticks_left"] = maxi(0, int(drifter["state_ticks_left"]) - 1)
	motes = motes.filter(func(m: Dictionary) -> bool: return str(m["kind"]) != "dropped" or int(m["ttl_ticks"]) > 0)
	drifters = drifters.filter(func(d: Dictionary) -> bool: return str(d["state"]) != "removed" or int(d["state_ticks_left"]) > 0)


func _apply_lamp_fuel_tick() -> void:
	var drain_by_lamp: Dictionary = {}
	for shade in shades:
		if str(shade.get("state", "")) != "drain":
			continue
		var lamp_id := str(shade.get("target_lantern_id", ""))
		if not drain_by_lamp.has(lamp_id): drain_by_lamp[lamp_id] = []
		drain_by_lamp[lamp_id].append(shade)
	for lamp in lanterns:
		if not bool(lamp["lit"]): continue
		lamp["fuel_u"] = int(lamp["fuel_u"]) - 1
		for shade in drain_by_lamp.get(str(lamp["id"]), []):
			lamp["fuel_u"] = int(lamp["fuel_u"]) - 5
			shade["drain_event_ticks"] = int(shade.get("drain_event_ticks", 0)) + 1
			if int(shade["drain_event_ticks"]) % HZ == 0:
				_emit("fuel_drain", {"lantern_id": lamp["id"], "shade_id": shade["id"], "fuel": _fuel(lamp)}, tick)
		if int(lamp["fuel_u"]) <= 0:
			lamp["fuel_u"] = 0
			lamp["lit"] = false
			lamp["deposited"] = 0
			_emit("lantern_out", {"lantern_id": lamp["id"]}, tick)


func _update_wind() -> void:
	wind_active = false
	if night != 3 or not wind_enabled:
		return
	var interval := int(tuning["wind_interval_ticks"])
	var phase := sim_tick % interval
	if phase == interval - int(tuning["wind_warning_ticks"]):
		wind_dir_deg = float(rng.randi_range(0, 359))
	wind_active = sim_tick >= interval and phase < int(tuning["wind_active_ticks"])


func _move_player() -> void:
	if int(player["respawn_ticks"]) > 0:
		return
	var move: Array = current_input.get("move", [0.0, 0.0])
	var x := float(move[0])
	var z := float(move[1])
	var direction := Vector3(x, 0, z)
	if direction.length() > 1.0:
		direction = direction.normalized()
	var yaw := deg_to_rad(float(current_input.get("cam_yaw_deg", 0.0)))
	direction = Vector3(direction.x * cos(yaw) + direction.z * sin(yaw), 0, -direction.x * sin(yaw) + direction.z * cos(yaw))
	if direction.length_squared() > 0.001:
		player["facing"] = direction.normalized()
	var dash_pressed := _pressed("dash")
	if dash_pressed and int(player["dash_cd_ticks"]) == 0 and int(player["dash_ticks"]) == 0:
		var dash_dir: Vector3 = direction.normalized() if direction.length_squared() > 0.001 else player["facing"]
		player["dash_dir"] = dash_dir
		player["dash_ticks"] = int(round(float(tuning["dash_duration_s"]) * HZ))
		if int(player["charm_ticks"]) == 0:
			player["dash_cd_ticks"] = int(round(float(tuning["dash_cooldown_s"]) * HZ))
		if not bool(player["grounded"]):
			player["vel"].y = 0.0
		_emit("dash", {}, tick)
	if _pressed("jump") and bool(player["grounded"]):
		player["vel"].y = float(tuning["jump_speed"])
		player["grounded"] = false

	var pos: Vector3 = player["pos"]
	var vel: Vector3 = player["vel"]
	var speed := float(tuning["charm_player_speed"]) if int(player["charm_ticks"]) > 0 else float(tuning["player_speed"])
	if night == 2 and bool(player["grounded"]) and not bool(player["pad_airborne"]):
		for pair in [[Vector3(20, 0, 18), Vector3(70, 0, 0)], [Vector3(50, 0, -18), Vector3.ZERO]]:
			if _distance_xz(pos, pair[0]) <= 1.0:
				var launch: Vector3 = pair[1] - pair[0]
				launch.y = 0
				launch = launch.normalized() * 24.0
				vel = Vector3(launch.x, 14.0, launch.z)
				player["pad_airborne"] = true
				player["grounded"] = false
				break
	elif night == 3 and bool(player["grounded"]) and not bool(player["pad_airborne"]) and _distance_xz(pos, Vector3(0, 3, 13)) <= 1.0:
		vel = Vector3(0, 12.0, -8.0)
		player["pad_airborne"] = true
		player["grounded"] = false
	if bool(player["pad_airborne"]):
		vel.y -= float(tuning["gravity"]) / HZ
	elif int(player["dash_ticks"]) > 0:
		var dash_direction: Vector3 = player["dash_dir"]
		vel.x = dash_direction.x * float(tuning["dash_speed"])
		vel.z = dash_direction.z * float(tuning["dash_speed"])
		vel.y = 0.0
		player["dash_ticks"] = int(player["dash_ticks"]) - 1
	else:
		vel.x = direction.x * speed
		vel.z = direction.z * speed
		if not bool(player["grounded"]):
			vel.y -= float(tuning["gravity"]) / HZ
	if wind_active:
		var wind_angle := deg_to_rad(wind_dir_deg)
		vel.x += cos(wind_angle) * float(tuning["wind_speed"])
		vel.z += sin(wind_angle) * float(tuning["wind_speed"])
	var dt := 1.0 / HZ
	var next := pos + vel * dt
	var next_ground = _ground_height(next)
	var old_ground = _ground_height(pos)
	if bool(player["grounded"]) and next_ground != null:
		var ground_y := float(next_ground)
		if ground_y > pos.y + 0.11:
			next.x = pos.x
			next.z = pos.z
			next.y = pos.y
			vel.x = 0
			vel.z = 0
		elif ground_y >= pos.y - 0.11:
			next.y = ground_y
			vel.y = 0
			player["grounded"] = true
		else:
			player["grounded"] = false
	elif next_ground != null and vel.y <= 0.0 and next.y <= float(next_ground) and pos.y >= float(next_ground) - 0.05:
		next.y = float(next_ground)
		vel.y = 0
		player["grounded"] = true
	else:
		player["grounded"] = false
	if bool(player["grounded"]) and old_ground != null and next_ground != null and float(next_ground) < float(old_ground) - 0.11:
		player["grounded"] = false
	player["pos"] = next
	player["vel"] = vel
	if bool(player["grounded"]):
		player["pad_airborne"] = false
	if next.y < float(tuning["fall_y"]):
		_player_fall()


func _ground_height(pos: Vector3):
	if night == 1:
		return 0.0 if Vector2(pos.x, pos.z).length() <= 40.0 else null
	if night == 2:
		if Vector2(pos.x, pos.z).length() <= 28.0 or Vector2(pos.x - 70.0, pos.z).length() <= 28.0:
			return 0.0
		if pos.x >= 26.0 and pos.x <= 44.0 and absf(pos.z) <= 2.0:
			return 0.0
		return null
	var r := Vector2(pos.x, pos.z).length()
	if r > 45.0:
		return null
	if r <= 8.0:
		return 6.0
	if pos.z > 0.0 and r >= 12.0 and r <= 24.0:
		return 3.0
	var ramp_y: Variant = _ramp_height(pos)
	if ramp_y != null:
		return ramp_y
	return 0.0


func _ramp_height(pos: Vector3):
	var point := Vector2(pos.x, pos.z)
	var r := point.length()
	if r < 24.0 or r > 30.0:
		return null
	var angle := rad_to_deg(atan2(pos.z, pos.x))
	var diff30 := absf(wrapf(angle - 30.0, -180.0, 180.0))
	var diff150 := absf(wrapf(angle - 150.0, -180.0, 180.0))
	var width_at_r := 1.5 / maxf(r, 1.0) * 57.2958
	if diff30 <= width_at_r or diff150 <= width_at_r:
		return 3.0 * (30.0 - r) / 6.0
	return null


func _player_fall() -> void:
	var lost := int(player["carried"])
	player["flames"] = int(player["flames"]) - 1
	player["carried"] = 0
	player["vel"] = Vector3.ZERO
	player["grounded"] = false
	_emit("player_hit", {"by": "fall", "flames": player["flames"], "dropped": 0, "lost": lost}, tick)
	if int(player["flames"]) <= 0:
		state = "lost"
		_emit("game_over", {"result": "lost", "reason": "no_flames"}, tick)
	else:
		player["respawn_ticks"] = int(tuning["fall_recovery_ticks"])
		player["respawn_pending"] = true


func _pickup_motes() -> void:
	var i := motes.size() - 1
	while i >= 0:
		var mote: Dictionary = motes[i]
		if int(player["carried"]) < _player_capacity() and _can_pickup(mote["pos"]):
			player["carried"] = int(player["carried"]) + 1
			_emit("mote_picked", {"mote_id": mote["id"], "carried": player["carried"]}, tick)
			motes.remove_at(i)
		i -= 1


func _pickup_charms() -> void:
	for charm in charms:
		if bool(charm["available"]) and _can_pickup(charm["pos"]):
			charm["available"] = false
			charm["respawn_ticks"] = int(tuning["charm_respawn_ticks"])
			player["charm_ticks"] = int(tuning["charm_duration_ticks"])
			_emit("charm_picked", {"charm_id": charm["id"], "charm_ticks": player["charm_ticks"]}, tick)


func _can_pickup(item_pos: Vector3) -> bool:
	var p: Vector3 = player["pos"]
	var horizontal := Vector2(p.x - item_pos.x, p.z - item_pos.z).length()
	return horizontal <= float(tuning["mote_pickup_radius"]) and absf(p.y - item_pos.y) <= float(tuning["mote_pickup_height"])


func _interact_lantern() -> void:
	if not _pressed("interact"):
		return
	var nearest_index := -1
	var nearest_distance := INF
	for i in range(lanterns.size()):
		var lamp: Dictionary = lanterns[i]
		if bool(lamp["lit"]) and int(lamp["fuel_u"]) >= int(tuning["fuel_max"]) * HZ:
			continue
		var d := _distance_xz(player["pos"], lamp["pos"])
		if d < nearest_distance or (is_equal_approx(d, nearest_distance) and (nearest_index < 0 or str(lamp["id"]) < str(lanterns[nearest_index]["id"]))):
			nearest_distance = d
			nearest_index = i
	if nearest_index < 0 or nearest_distance > float(tuning["interact_radius"]):
		return
	var lamp: Dictionary = lanterns[nearest_index]
	if bool(lamp["lit"]):
		var missing := int(tuning["fuel_max"]) * HZ - int(lamp["fuel_u"])
		var used := mini(int(player["carried"]), ceili(float(missing) / (int(tuning["fuel_per_mote"]) * HZ)))
		if used <= 0: return
		lamp["fuel_u"] = mini(int(tuning["fuel_max"]) * HZ, int(lamp["fuel_u"]) + used * int(tuning["fuel_per_mote"]) * HZ)
		player["carried"] = int(player["carried"]) - used
		score += used * int(tuning["score"]["per_mote"])
		_emit("refuel", {"lantern_id": lamp["id"], "amount": used, "fuel": _fuel(lamp)}, tick)
		return
	var cost := int(tuning["relight_cost"]) if bool(lamp["ever_lit"]) else int(tuning["lantern_cost"])
	var amount := mini(int(player["carried"]), cost - int(lamp["deposited"]))
	if amount <= 0: return
	player["carried"] = int(player["carried"]) - amount
	lamp["deposited"] = int(lamp["deposited"]) + amount
	score += amount * int(tuning["score"]["per_mote"])
	_emit("deposit", {"lantern_id": lamp["id"], "amount": amount, "deposited": lamp["deposited"]}, tick)
	if int(lamp["deposited"]) >= cost:
		var relight := bool(lamp["ever_lit"])
		lamp["lit"] = true
		lamp["ever_lit"] = true
		lamp["fuel_u"] = int(tuning["fuel_max"]) * HZ
		lamp["deposited"] = 0
		if relight: lamp["relit_count"] = int(lamp["relit_count"]) + 1
		player["successful_lights"] = int(player["successful_lights"]) + 1
		score += int(tuning["score"]["per_lantern"]) if not relight else int(tuning["score"]["per_relight"])
		_emit("lantern_lit", {"lantern_id": lamp["id"], "relight": relight}, tick)


func _fuel(lamp: Dictionary) -> float:
	return snappedf(float(lamp.get("fuel_u", 0)) / HZ, 0.1)


func _player_capacity() -> int:
	return mini(int(tuning.get("capacity_max", 20)), int(tuning["carry_capacity"]) + 2 * int(player.get("successful_lights", 0)))


func _update_safe_zones() -> void:
	for shade in shades:
		if str(shade["state"]) == "stunned" or int(shade["safe_ticks"]) > 0:
			continue
		for lamp in lanterns:
			if not bool(lamp["lit"]) or _fuel(lamp) < float(tuning["low_fuel_threshold"]):
				continue
			var delta: Vector3 = shade["pos"] - lamp["pos"]
			delta.y = 0
			if delta.length() < float(tuning["safe_radius"]):
				if delta.length_squared() < 0.0001:
					delta = Vector3(1, 0, 0)
				shade["safe_target"] = lamp["pos"] + delta.normalized() * float(tuning["safe_radius"])
				shade["safe_ticks"] = int(tuning["safe_push_ticks"])
				shade["state"] = "recoil"
				shade["state_ticks_left"] = int(tuning["safe_push_ticks"])
				break


func _try_pulse() -> void:
	if not _pressed("pulse") or int(player["pulse_cd_ticks"]) > 0 or int(player["carried"]) < int(tuning["pulse_cost"]):
		return
	player["carried"] = int(player["carried"]) - int(tuning["pulse_cost"])
	player["pulse_cd_ticks"] = int(round(float(tuning["pulse_cooldown_s"]) * HZ))
	var center: Vector3 = player["pos"] + Vector3(0, float(tuning["pulse_center_height"]), 0)
	var hit_ids: Array[String] = []
	for shade in shades:
		if center.distance_to(shade["pos"]) <= float(tuning["pulse_target_radius_3d"]):
			var was_draining := str(shade["state"]) == "drain"
			shade["state"] = "stunned"
			shade["stun_ticks"] = int(tuning["pulse_stun_ticks"])
			shade["state_ticks_left"] = int(tuning["pulse_stun_ticks"])
			shade["safe_ticks"] = 0
			var away: Vector3 = shade["pos"] - player["pos"]
			away.y = 0
			if away.length_squared() < 0.0001:
				away = Vector3(1, 0, 0)
			shade["recoil_dir"] = away.normalized()
			shade["recoil_ticks"] = int(tuning["pulse_push_ticks"])
			score += int(tuning["score"]["per_stun"]) + (10 if was_draining else 0)
			hit_ids.append(str(shade["id"]))
	for drifter in drifters:
		if Vector2(center.x - drifter["pos"].x, center.z - drifter["pos"].z).length() > float(tuning["pulse_target_radius_3d"]):
			continue
		if str(drifter["state"]) == "chase":
			drifter["state"] = "flee"
			drifter["state_ticks_left"] = int(tuning["drifter_flee_ticks"])
		elif str(drifter["state"]) == "flee" and int(drifter["stolen"]) > 0:
			var amount := int(drifter["stolen"])
			_spawn_dropped_motes(drifter["pos"], amount)
			drifter["stolen"] = 0
			drifter["state"] = "removed"
			drifter["state_ticks_left"] = int(tuning["drifter_drop_remove_ticks"])
			_emit("drifter_drop", {"drifter_id": drifter["id"], "amount": amount}, tick)
	_emit("pulse", {"stunned_ids": hit_ids}, tick)


func _move_shade(shade: Dictionary) -> void:
	var pos: Vector3 = shade["pos"]
	if str(shade["state"]) == "stunned":
		if int(shade["recoil_ticks"]) > 0:
			var push_step := float(tuning["pulse_push_m"]) / float(tuning["pulse_push_ticks"])
			var pushed: Vector3 = pos + shade["recoil_dir"] * push_step
			if _ground_height(pushed) != null:
				pos = pushed
			shade["recoil_ticks"] -= 1
	elif str(shade["state"]) == "recoil":
		if int(shade["safe_ticks"]) > 0:
			var target: Vector3 = shade["safe_target"]
			var delta: Vector3 = target - pos
			delta.y = 0
			var step := minf(delta.length(), float(tuning["safe_radius"]) / float(tuning["safe_push_ticks"]))
			if delta.length_squared() > 0.0001:
				pos += delta.normalized() * step
		else:
			var recoil_step := float(tuning["shade_recoil_m"]) / float(tuning["shade_recoil_ticks"])
			pos += shade["recoil_dir"] * recoil_step
	elif str(shade["state"]) not in ["spawning"]:
		if str(shade["state"]) == "drain":
			var target_lamp := _lamp_by_id(str(shade.get("target_lantern_id", "")))
			if target_lamp.is_empty() or not bool(target_lamp["lit"]) or _fuel(target_lamp) >= float(tuning["low_fuel_threshold"]):
				shade["state"] = "wander"
			elif _distance_xz(pos, player["pos"]) <= 6.0:
				shade["state"] = "chase"
			elif _distance_xz(pos, target_lamp["pos"]) > 2.0:
				shade["state"] = "wander"
			else:
				shade["pos"] = pos
				return
		if str(shade["state"]) == "wander":
			var weak := _nearest_lamp(pos, true)
			if not weak.is_empty():
				shade["target_lantern_id"] = weak["id"]
				var to_weak: Vector3 = weak["pos"] - pos
				to_weak.y = 0
				if to_weak.length() <= 2.0:
					shade["state"] = "drain"
					shade["drain_event_ticks"] = 0
					shade["pos"] = pos
					return
				pos += to_weak.normalized() * float(tuning["shade_speed"]) / HZ
				shade["pos"] = pos
				return
			var unlit := _nearest_lamp(pos, false)
			if not unlit.is_empty():
				var to_unlit: Vector3 = unlit["pos"] - pos
				to_unlit.y = 0
				if to_unlit.length() > 2.0:
					pos += to_unlit.normalized() * float(tuning["shade_speed"]) / HZ
					shade["pos"] = pos
					return
		var distance := _distance_xz(pos, player["pos"])
		if str(shade["state"]) == "wander" and distance <= float(tuning["shade_detect_radius"]):
			shade["state"] = "chase"
		elif str(shade["state"]) == "chase" and distance > float(tuning["shade_lose_radius"]):
			shade["state"] = "wander"
		if str(shade["state"]) == "chase" and distance > 0.0001:
			var direction: Vector3 = player["pos"] - pos
			direction.y = 0
			var speed := float(tuning["shade_speed_night3"]) if night == 3 else float(tuning["shade_speed"])
			var proposed: Vector3 = pos + direction.normalized() * speed / HZ
			if _inside_lit_safe_zone(pos, proposed):
				pos = proposed
	shade["pos"] = pos


func _lamp_by_id(lamp_id: String) -> Dictionary:
	for lamp in lanterns:
		if str(lamp["id"]) == lamp_id: return lamp
	return {}


func _nearest_lamp(from: Vector3, weak_only: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for lamp in lanterns:
		var eligible := bool(lamp["lit"]) and _fuel(lamp) < float(tuning["low_fuel_threshold"]) if weak_only else not bool(lamp["lit"])
		if not eligible: continue
		var d := _distance_xz(from, lamp["pos"])
		if d < best_d or (is_equal_approx(d, best_d) and (best.is_empty() or str(lamp["id"]) < str(best["id"]))):
			best = lamp
			best_d = d
	return best


func _update_shades() -> void:
	shades.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _numeric_suffix(str(a["id"])) < _numeric_suffix(str(b["id"])))
	for shade in shades:
		_move_shade(shade)


func _inside_lit_safe_zone(from: Vector3, to: Vector3) -> bool:
	for lamp in lanterns:
		if bool(lamp["lit"]) and _fuel(lamp) >= float(tuning["low_fuel_threshold"]):
			var old_d := _distance_xz(from, lamp["pos"])
			var new_d := _distance_xz(to, lamp["pos"])
			if old_d >= float(tuning["safe_radius"]) and new_d < float(tuning["safe_radius"]):
				return false
	return true


func _update_drifters() -> void:
	for drifter in drifters:
		if str(drifter["state"]) == "removed":
			continue
		var distance := _distance_xz(drifter["pos"], player["pos"])
		if str(drifter["state"]) == "idle" and int(player["carried"]) >= 5 and distance <= float(tuning["drifter_detection_radius"]):
			drifter["state"] = "chase"
		elif str(drifter["state"]) == "chase" and (int(player["carried"]) < 5 or distance > float(tuning["drifter_detection_radius"]) * 1.5):
			drifter["state"] = "idle"
		var target: Vector3 = player["pos"]
		var speed := float(tuning["drifter_idle_speed"])
		if str(drifter["state"]) == "chase":
			speed = float(tuning["drifter_speed"])
		elif str(drifter["state"]) == "flee":
			speed = float(tuning["drifter_speed"])
			var away: Vector3 = drifter["pos"] - player["pos"]
			away.y = 0
			if away.length_squared() < 0.0001:
				away = Vector3(1, 0, 0)
			target = drifter["pos"] + away.normalized() * 10.0
		var direction: Vector3 = target - drifter["pos"]
		direction.y = 0
		if direction.length_squared() > 0.0001:
			drifter["pos"] += direction.normalized() * speed / HZ
		if str(drifter["state"]) == "flee" and int(drifter["state_ticks_left"]) == 0:
			drifter["state"] = "removed"
			drifter["state_ticks_left"] = 1


func _check_contacts() -> void:
	for drifter in drifters:
		if str(drifter["state"]) == "removed" or str(drifter["state"]) != "chase" or _distance_xz(drifter["pos"], player["pos"]) > float(tuning["drifter_touch_radius"]):
			continue
		var stolen := mini(int(tuning["drifter_steal_max"]), int(player["carried"]))
		player["carried"] = int(player["carried"]) - stolen
		drifter["stolen"] = stolen
		drifter["state"] = "flee"
		drifter["state_ticks_left"] = int(tuning["drifter_flee_ticks"])
		_emit("drifter_steal", {"drifter_id": drifter["id"], "amount": stolen, "carried": player["carried"]}, tick)
	shades.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _numeric_suffix(str(a["id"])) < _numeric_suffix(str(b["id"])))
	if int(player["invuln_ticks"]) > 0 or int(player["respawn_ticks"]) > 0:
		return
	for shade in shades:
		if str(shade["state"]) in ["spawning", "stunned", "recoil"]:
			continue
		if _distance_xz(shade["pos"], player["pos"]) <= float(tuning["shade_hit_radius"]) and absf(shade["pos"].y - player["pos"].y) <= float(tuning["shade_hit_height"]):
			_player_hit(shade)
			break


func _player_hit(shade: Dictionary) -> void:
	player["flames"] = int(player["flames"]) - 1
	player["invuln_ticks"] = int(tuning["invuln_ticks"])
	var dropped := floori(float(player["carried"]) * float(tuning["hit_drop_ratio"]))
	player["carried"] = int(player["carried"]) - dropped
	_spawn_dropped_motes(player["pos"], dropped)
	var away: Vector3 = shade["pos"] - player["pos"]
	away.y = 0
	if away.length_squared() < 0.0001:
		away = Vector3(1, 0, 0)
	shade["recoil_dir"] = away.normalized()
	shade["recoil_ticks"] = int(tuning["shade_recoil_ticks"])
	shade["state"] = "recoil"
	shade["state_ticks_left"] = int(tuning["shade_recoil_ticks"])
	var lost := dropped
	_emit("player_hit", {"by": "shade", "flames": player["flames"], "dropped": dropped, "lost": lost}, tick)


func _spawn_scheduled_entities() -> void:
	if allow_random_shades and night == 1:
		if sim_tick == int(tuning["shade_spawn_initial_tick"]):
			_spawn_shade()
			_spawn_shade()
		elif sim_tick > int(tuning["shade_spawn_initial_tick"]) and (sim_tick - int(tuning["shade_spawn_initial_tick"])) % int(tuning["shade_spawn_interval_night1"]) == 0:
			_spawn_shade()
	elif allow_random_shades:
		var interval := int(tuning["shade_spawn_interval_night%d" % night])
		if sim_tick > 0 and sim_tick % interval == 0:
			_spawn_shade()
	if allow_random_drifters and night >= 2 and sim_tick > 0 and sim_tick % int(tuning["drifter_spawn_interval_ticks"]) == 0 and drifters.size() < int(tuning["drifter_max_active"]):
		_spawn_drifter()
	if allow_random_motes and sim_tick > 0 and sim_tick % int(tuning["mote_spawn_interval_ticks"]) == 0 and motes.size() < int(tuning["mote_cap"]):
		_spawn_mote_at_empty_point()


func _spawn_shade() -> void:
	if shades.size() >= int(tuning["shade_max_night%d" % night]):
		return
	var candidates: Array[int] = []
	for i in range(shade_points.size()):
		if _distance_xz(shade_points[i], player["pos"]) >= 15.0:
			candidates.append(i)
	if candidates.is_empty():
		return
	var pos: Vector3 = shade_points[candidates[rng.randi_range(0, candidates.size() - 1)]]
	shade_serial += 1
	shades.append({"id": "S%d" % shade_serial, "pos": pos, "state": "spawning", "state_ticks_left": 1, "stun_ticks": 0, "recoil_dir": Vector3.ZERO, "recoil_ticks": 0, "safe_target": Vector3.ZERO, "safe_ticks": 0, "spawn_ticks": 1})
	_emit("shade_spawned", {"id": "S%d" % shade_serial}, tick)


func _spawn_drifter() -> void:
	if shade_points.is_empty():
		return
	var pos: Vector3 = shade_points[rng.randi_range(0, shade_points.size() - 1)]
	drifter_serial += 1
	drifters.append({"id": "D%d" % drifter_serial, "pos": pos, "state": "idle", "stolen": 0, "state_ticks_left": 0, "target": pos, "spawn_ticks": 1})


func _spawn_mote_at_empty_point() -> void:
	var available: Array[int] = []
	for i in range(mote_points.size()):
		var occupied := false
		for mote in motes:
			if int(mote["spawn_point"]) == i:
				occupied = true
				break
		if not occupied:
			available.append(i)
	if not available.is_empty():
		var index: int = available[rng.randi_range(0, available.size() - 1)]
		_spawn_mote(mote_points[index], "random", index, sim_tick + 1)


func _spawn_mote(pos: Vector3, kind: String, spawn_point: int, born_tick: int, ttl_ticks: int = -1, custom_id: String = "") -> void:
	if custom_id.is_empty():
		mote_serial += 1
		custom_id = "M%d" % mote_serial
	else:
		mote_serial += 1
	motes.append({"id": custom_id, "pos": pos, "kind": kind, "ttl_ticks": ttl_ticks, "born_tick": born_tick, "spawn_point": spawn_point})


func _spawn_dropped_motes(pos: Vector3, amount: int) -> void:
	for i in range(amount):
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(1.5, 2.5)
		var drop_pos := pos + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var ground = _ground_height(drop_pos)
		if ground != null:
			drop_pos.y = float(ground)
		_spawn_mote(drop_pos, "dropped", -1, sim_tick + 1, int(tuning["dropped_mote_ttl_ticks"]))


func _check_game_end() -> void:
	if state == "lost":
		return
	if int(player["flames"]) <= 0:
		state = "lost"
		_emit("game_over", {"result": "lost", "reason": "no_flames"}, tick)
		return
	if time_left_s > 0.0:
		return
	var lit_count := 0
	for lamp in lanterns:
		if bool(lamp["lit"]): lit_count += 1
	var required := ceili(float(lanterns.size()) * float(tuning["win_ratio"]))
	if lit_count >= required:
		state = "won"
		for lamp in lanterns:
			if bool(lamp["lit"]): score += 50 + floori(_fuel(lamp))
		score += int(player["flames"]) * int(tuning["score"]["per_flame_left"])
		_emit("game_over", {"result": "won", "reason": "dawn_survived"}, tick)
		return
	state = "lost"
	_emit("game_over", {"result": "lost", "reason": "dawn"}, tick)


func _snapshot() -> Dictionary:
	var mote_rows: Array[Dictionary] = []
	for mote in motes:
		mote_rows.append({"id": mote["id"], "pos": _vec_array(mote["pos"]), "kind": mote["kind"], "ttl_s": null if str(mote["kind"]) == "random" else snappedf(float(mote["ttl_ticks"]) / HZ, 0.001)})
	var lamp_rows: Array[Dictionary] = []
	for lamp in lanterns:
		lamp_rows.append({"id": lamp["id"], "pos": _vec_array(lamp["pos"]), "lit": lamp["lit"], "deposited": lamp["deposited"], "fuel": _fuel(lamp) if bool(lamp["lit"]) else 0.0, "ever_lit": lamp["ever_lit"], "relit_count": lamp["relit_count"]})
	var shade_rows: Array[Dictionary] = []
	for shade in shades:
		shade_rows.append({"id": shade["id"], "pos": _vec_array(shade["pos"]), "state": shade["state"], "state_ticks_left": shade["state_ticks_left"], "target_lantern_id": shade.get("target_lantern_id", "")})
	var drifter_rows: Array[Dictionary] = []
	for drifter in drifters:
		drifter_rows.append({"id": drifter["id"], "pos": _vec_array(drifter["pos"]), "state": drifter["state"], "stolen": drifter["stolen"]})
	var charm_rows: Array[Dictionary] = []
	for charm in charms:
		charm_rows.append({"id": charm["id"], "pos": _vec_array(charm["pos"]), "available": charm["available"], "respawn_s": snappedf(float(charm["respawn_ticks"]) / HZ, 0.001)})
	return {"type": "snapshot", "tick": tick, "sim_tick": sim_tick, "night": night, "state": state, "time_left_s": snappedf(time_left_s, 0.001), "score": score,
		"wind": {"active": wind_active, "dir_deg": snappedf(wind_dir_deg, 0.001)},
		"player": {"pos": _vec_array(player["pos"]), "vel": _vec_array(player["vel"]), "grounded": player["grounded"], "flames": player["flames"], "carried": player["carried"], "capacity": _player_capacity(),
			"invuln": snappedf(float(player["invuln_ticks"]) / HZ, 0.001), "dash_cd_s": snappedf(float(player["dash_cd_ticks"]) / HZ, 0.001), "pulse_cd_s": snappedf(float(player["pulse_cd_ticks"]) / HZ, 0.001), "charm_s": snappedf(float(player["charm_ticks"]) / HZ, 0.001)},
		"lanterns": lamp_rows, "motes": mote_rows, "motes_active": motes.size(), "shades": shade_rows, "drifters": drifter_rows, "charms": charm_rows}


func _pressed(action: String) -> bool:
	var value := bool(current_input.get(action, false))
	var key := "_prev_" + action
	var previous := bool(current_input.get(key, false))
	current_input[key] = value
	return value and not previous


func _emit(name: String, data: Dictionary, event_tick: int = -1) -> void:
	events.append({"type": "event", "tick": tick if event_tick < 0 else event_tick, "name": name, "data": data})


func _inside_lit_safe_zone_check(pos: Vector3) -> bool:
	for lamp in lanterns:
		if bool(lamp["lit"]) and _fuel(lamp) >= float(tuning["low_fuel_threshold"]) and _distance_xz(pos, lamp["pos"]) < float(tuning["safe_radius"]):
			return true
	return false


func _distance_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _polar(radius: float, degrees: float, center: Vector3 = Vector3.ZERO) -> Vector3:
	var angle := deg_to_rad(degrees)
	return center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)


func _read_vec(value) -> Vector3:
	if not value is Array or value.size() < 3:
		last_json_error = "position must be a 3-element array"
		return Vector3.ZERO
	for component in value:
		if not (component is int or component is float):
			last_json_error = "position components must be numeric"
			return Vector3.ZERO
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _vec_array(value: Vector3) -> Array:
	return [snappedf(value.x, 0.001), snappedf(value.y, 0.001), snappedf(value.z, 0.001)]


func _numeric_suffix(id: String) -> int:
	var digits := ""
	for i in range(id.length()):
		if id.substr(i, 1).is_valid_int():
			digits += id.substr(i, 1)
	return digits.to_int()


func _read_json(path: String) -> Dictionary:
	last_json_error = ""
	if not FileAccess.file_exists(path):
		last_json_error = "file not found: " + path
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_json_error = "cannot open file: " + path
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		last_json_error = "line %d: %s" % [parser.get_error_line(), parser.get_error_message()]
		return {}
	if not parser.data is Dictionary:
		last_json_error = "JSON root must be an object"
		return {}
	return parser.data


func _fail(message: String, exit_code: int) -> void:
	push_error(message)
	quit(exit_code)
