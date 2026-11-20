extends "res://scripts/headless.gd"

var soak_seed := 7
var soak_nights := 10
var soak_out := "soak.json"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var arg := str(args[i])
		if arg == "--seed" and i + 1 < args.size():
			soak_seed = int(args[i + 1])
			i += 2
		elif arg == "--nights" and i + 1 < args.size():
			soak_nights = int(args[i + 1])
			i += 2
		elif arg == "--out" and i + 1 < args.size():
			soak_out = str(args[i + 1])
			i += 2
		else:
			i += 1

	var project_root := ProjectSettings.globalize_path("res://").simplify_path()
	var contract := _read_json(project_root.path_join("..").path_join("game.contract.json").simplify_path())
	if not last_json_error.is_empty() or contract.is_empty():
		contract = _read_json("res://game.contract.json")
	if not last_json_error.is_empty() or contract.is_empty():
		_fail("Cannot read game.contract.json: " + last_json_error, 1)
		return
	tuning = contract.get("tuning", {})
	if tuning.is_empty():
		_fail("game.contract.json is missing tuning.", 1)
		return

	var start_ms := Time.get_ticks_msec()
	var crashes := 0
	var results: Array[String] = []
	var mem_start_mb := 0

	var move_x := 0.0
	var move_y := 0.0

	for night_idx in range(soak_nights):
		var n_num := (night_idx % 3) + 1
		var n_seed := soak_seed + night_idx
		night = n_num
		rng.seed = n_seed

		# Reset simulation variables for clean night setup
		tick = 0
		sim_tick = 0
		state = "playing"
		score = 0
		events.clear()
		input_frames.clear()
		current_input = {"move": [0.0, 0.0], "cam_yaw_deg": 0.0}
		motes.clear()
		lanterns.clear()
		shades.clear()
		drifters.clear()
		charms.clear()
		mote_points.clear()
		shade_points.clear()
		mote_serial = 0
		shade_serial = 0
		drifter_serial = 0
		wind_active = false
		wind_dir_deg = 0.0

		var opts := {
			"night": n_num,
			"seed": n_seed,
			"ticks": 21600,
			"out": "",
			"scenario": "",
			"inputs": ""
		}
		if not _setup_game(opts):
			crashes += 1
			results.append("crash")
			continue

		if night_idx == 0:
			mem_start_mb = int(round(float(OS.get_static_memory_usage()) / (1024.0 * 1024.0)))

		var night_duration_s := int(tuning.get("night%d_duration_s" % n_num, 300))
		var max_ticks := night_duration_s * HZ

		for t in range(max_ticks):
			if state == "won" or state == "lost":
				break
			tick += 1

			# Seeded random input per Ticket-04 specification:
			# Every 30 ticks pick new movement direction
			if t % 30 == 0:
				var ang := rng.randf_range(0.0, TAU)
				move_x = cos(ang)
				move_y = sin(ang)

			# Per-tick probability checks
			var jmp := rng.randf() < 0.05
			var dsh := rng.randf() < 0.03
			var pls := rng.randf() < 0.02
			var itc := rng.randf() < 0.10

			current_input["move"] = [move_x, move_y]
			current_input["jump"] = jmp
			current_input["dash"] = dsh
			current_input["pulse"] = pls
			current_input["interact"] = itc

			_simulate_tick()

		results.append(state)

	# Clean up last night state before final memory reading
	motes.clear()
	lanterns.clear()
	shades.clear()
	drifters.clear()
	charms.clear()

	var mem_end_mb := int(round(float(OS.get_static_memory_usage()) / (1024.0 * 1024.0)))
	var total_dur_s := (Time.get_ticks_msec() - start_ms) / 1000.0

	var output_dict := {
		"nights": soak_nights,
		"crashes": crashes,
		"results": results,
		"mem_start_mb": mem_start_mb,
		"mem_end_mb": mem_end_mb,
		"duration_s": snappedf(total_dur_s, 0.1)
	}

	var json_str := JSON.stringify(output_dict, "  ")
	var global_out := ProjectSettings.globalize_path(soak_out)
	var parent_dir := global_out.get_base_dir()
	if not parent_dir.is_empty() and not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)

	var f := FileAccess.open(soak_out, FileAccess.WRITE)
	if f != null:
		f.store_string(json_str)
		f.close()
		print("Soak test output saved to ", soak_out)
	else:
		print("ERROR: Failed to write soak output to ", soak_out)
	var root_soak := "res://../" + soak_out
	var f_root := FileAccess.open(root_soak, FileAccess.WRITE)
	if f_root != null:
		f_root.store_string(json_str)
		f_root.close()
	quit(0)
