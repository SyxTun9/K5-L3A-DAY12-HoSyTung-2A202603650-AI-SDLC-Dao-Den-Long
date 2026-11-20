extends SceneTree

const HZ := 60.0
const WARMUP_DURATION := 3.0

var rng := RandomNumberGenerator.new()
var bench_duration := 30.0
var output_path := "bench.json"
var seed_val := 42

var root_node: Node3D
var camera: Camera3D
var shades: Array[Node3D] = []
var shade_dirs: Array[Vector3] = []
var motes: Array[Node3D] = []
var lanterns: Array[Node3D] = []

var elapsed_total := 0.0
var elapsed_measured := 0.0
var frames_measured := 0
var dt_samples_ms: Array[float] = []
var peak_mem_bytes := 0
var start_tick_ms := 0
var first_frame := true
var load_ms := 0.0


func _initialize() -> void:
	start_tick_ms = Time.get_ticks_msec()
	_parse_cli()
	rng.seed = seed_val

	# Window settings: 1280x720 windowed, vsync off
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	root_node = Node3D.new()
	root_node.name = "BenchmarkScene"
	root.add_child(root_node)

	_build_scene()


func _parse_cli() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var arg := str(args[i])
		if arg == "--seed" and i + 1 < args.size():
			seed_val = int(args[i + 1])
			i += 2
		elif arg == "--duration" and i + 1 < args.size():
			bench_duration = float(args[i + 1])
			i += 2
		elif arg == "--out" and i + 1 < args.size():
			output_path = str(args[i + 1])
			i += 2
		else:
			i += 1


func _build_scene() -> void:
	# Environment lighting (gl_compatibility)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0d1117")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a4659")
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	root_node.add_child(world_env)

	var dir_light := DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-55, 35, 0)
	dir_light.light_color = Color("c4d7ed")
	dir_light.light_energy = 0.9
	root_node.add_child(dir_light)

	# Island mesh (Radius 40m, center 0,0,0)
	var ground := MeshInstance3D.new()
	var ground_mesh := CylinderMesh.new()
	ground_mesh.top_radius = 40.0
	ground_mesh.bottom_radius = 40.0
	ground_mesh.height = 1.0
	ground_mesh.radial_segments = 48
	ground.mesh = ground_mesh
	ground.position = Vector3(0, -0.5, 0)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("1e2a38")
	ground_mat.roughness = 0.85
	ground.material_override = ground_mat
	root_node.add_child(ground)

	# Player stands at (0, 0, 0)
	var player_mesh := MeshInstance3D.new()
	var p_capsule := CapsuleMesh.new()
	p_capsule.radius = 0.35
	p_capsule.height = 1.7
	player_mesh.mesh = p_capsule
	player_mesh.position = Vector3(0, 0.85, 0)
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color("2c7775")
	player_mesh.material_override = p_mat
	root_node.add_child(player_mesh)

	# Camera at (30, 15, 0) looking at (0, 0, 0)
	camera = Camera3D.new()
	camera.look_at_from_position(Vector3(30, 15, 0), Vector3.ZERO, Vector3.UP)
	camera.current = true
	camera.fov = 55.0
	root_node.add_child(camera)

	# 3 Lanterns L1-L3 lit with fuel 100
	var lamp_positions := [
		Vector3(0.0, 0.0, 25.0),
		Vector3(23.8, 0.0, 7.7),
		Vector3(14.7, 0.0, -20.2)
	]
	for pos in lamp_positions:
		var lamp := _make_lantern(pos)
		lanterns.append(lamp)
		root_node.add_child(lamp)

	# 100 Motes distributed on island
	for i in range(100):
		var r := rng.randf_range(2.0, 38.0)
		var th := rng.randf_range(0.0, TAU)
		var m_pos := Vector3(cos(th) * r, 0.45, sin(th) * r)
		var mote := _make_mote(m_pos)
		motes.append(mote)
		root_node.add_child(mote)

	# 200 Shades in wander state distributed evenly on island
	for i in range(200):
		var r := rng.randf_range(3.0, 38.0)
		var th := rng.randf_range(0.0, TAU)
		var s_pos := Vector3(cos(th) * r, 0.72, sin(th) * r)
		var s_node := _make_shade(s_pos)
		shades.append(s_node)
		root_node.add_child(s_node)
		var dir_angle := rng.randf_range(0.0, TAU)
		shade_dirs.append(Vector3(cos(dir_angle), 0, sin(dir_angle)).normalized())


func _make_lantern(pos: Vector3) -> Node3D:
	var lamp := Node3D.new()
	lamp.position = pos
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.12
	post_mesh.bottom_radius = 0.18
	post_mesh.height = 2.0
	post.mesh = post_mesh
	post.position.y = 1.0
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color("4a3b32")
	post.material_override = post_mat
	lamp.add_child(post)

	var glow := MeshInstance3D.new()
	var g_mesh := BoxMesh.new()
	g_mesh.size = Vector3(0.6, 0.8, 0.6)
	glow.mesh = g_mesh
	glow.position.y = 2.1
	var g_mat := StandardMaterial3D.new()
	g_mat.albedo_color = Color("ffcc66")
	g_mat.emission_enabled = true
	g_mat.emission = Color("ffaa33")
	g_mat.emission_energy_multiplier = 3.0
	glow.material_override = g_mat
	lamp.add_child(glow)

	var light := OmniLight3D.new()
	light.position.y = 2.1
	light.light_color = Color("ffbb55")
	light.light_energy = 2.5
	light.omni_range = 10.0
	lamp.add_child(light)
	return lamp


func _make_mote(pos: Vector3) -> Node3D:
	var mote := MeshInstance3D.new()
	var s_mesh := SphereMesh.new()
	s_mesh.radius = 0.22
	s_mesh.height = 0.44
	mote.mesh = s_mesh
	mote.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffe57f")
	mat.emission_enabled = true
	mat.emission = Color("ffea88")
	mat.emission_energy_multiplier = 2.0
	mote.material_override = mat
	return mote


func _make_shade(pos: Vector3) -> Node3D:
	var shade := Node3D.new()
	shade.position = pos
	var body := MeshInstance3D.new()
	var b_mesh := SphereMesh.new()
	b_mesh.radius = 0.72
	b_mesh.height = 1.44
	body.mesh = b_mesh
	body.position.y = 0.72
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = Color("241a3a")
	b_mat.roughness = 0.9
	body.material_override = b_mat
	shade.add_child(body)

	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.14
	eye_mesh.height = 0.2
	eye.mesh = eye_mesh
	eye.position = Vector3(0, 1.1, -0.6)
	var e_mat := StandardMaterial3D.new()
	e_mat.albedo_color = Color("ff579a")
	e_mat.emission_enabled = true
	e_mat.emission = Color("ff3377")
	e_mat.emission_energy_multiplier = 2.5
	eye.material_override = e_mat
	shade.add_child(eye)
	return shade


func _process(delta: float) -> bool:
	if first_frame:
		first_frame = false
		load_ms = float(Time.get_ticks_msec() - start_tick_ms)

	elapsed_total += delta

	# Track peak memory
	var current_mem := OS.get_static_memory_usage()
	if current_mem > peak_mem_bytes:
		peak_mem_bytes = current_mem

	# Camera circular rotation: radius 30m, height 15m, center (0,0,0), period 15s
	# counter-clockwise when viewed from top: angle increases
	var cam_angle := (elapsed_total / 15.0) * TAU
	camera.position = Vector3(cos(cam_angle) * 30.0, 15.0, sin(cam_angle) * 30.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	# Move 200 shades in wander state
	for i in range(shades.size()):
		var s := shades[i]
		var dir := shade_dirs[i]
		s.position += dir * 4.0 * delta
		s.position.y = 0.72
		var dist := Vector2(s.position.x, s.position.z).length()
		if dist > 38.0:
			# Bounce back toward center
			var to_center := -Vector3(s.position.x, 0, s.position.z).normalized()
			shade_dirs[i] = to_center
		elif rng.randf() < 0.02:
			# Random wander steering
			var new_angle := rng.randf_range(0.0, TAU)
			shade_dirs[i] = Vector3(cos(new_angle), 0, sin(new_angle)).normalized()

	# Warmup check: first 3 seconds are warmup
	if elapsed_total <= WARMUP_DURATION:
		return false

	# Measurement phase
	elapsed_measured += delta
	frames_measured += 1
	dt_samples_ms.append(delta * 1000.0)

	if elapsed_measured >= bench_duration:
		_finish_benchmark()
		quit(0)
		return true

	return false


func _finish_benchmark() -> void:
	var n := dt_samples_ms.size()
	if n == 0:
		n = 1
		dt_samples_ms.append(16.67)

	var sum_dt_ms := 0.0
	for d in dt_samples_ms:
		sum_dt_ms += d

	var avg_fps := 1000.0 * float(n) / maxf(sum_dt_ms, 0.001)

	# p1_low_fps: k = max(1, ceil(0.01 * N)); average of k largest dt values
	var sorted_dt_desc := dt_samples_ms.duplicate()
	sorted_dt_desc.sort()
	sorted_dt_desc.reverse()
	var k := maxi(1, int(ceil(0.01 * float(n))))
	var sum_k := 0.0
	for i in range(k):
		sum_k += sorted_dt_desc[i]
	var avg_k_dt := sum_k / float(k)
	var p1_low_fps := 1000.0 / maxf(avg_k_dt, 0.001)

	# frame_ms_p95: 95th percentile of dt
	var sorted_dt_asc := dt_samples_ms.duplicate()
	sorted_dt_asc.sort()
	var p95_index := mini(n - 1, int(round(0.95 * float(n - 1))))
	var frame_ms_p95: float = sorted_dt_asc[p95_index]

	var peak_mem_mb := int(round(float(peak_mem_bytes) / (1024.0 * 1024.0)))

	var result := {
		"contract_version": "1.3",
		"avg_fps": snappedf(avg_fps, 0.1),
		"p1_low_fps": snappedf(p1_low_fps, 0.1),
		"frame_ms_p95": snappedf(frame_ms_p95, 0.1),
		"frames": n,
		"load_ms": int(round(load_ms)),
		"peak_mem_mb": peak_mem_mb,
		"vsync_off": true,
		"renderer": "Godot 4.7.2 GL Compatibility",
		"os": OS.get_name()
	}

	var json_str := JSON.stringify(result, "  ")

	var global_out := ProjectSettings.globalize_path(output_path)
	var parent_dir := global_out.get_base_dir()
	if not parent_dir.is_empty() and not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)

	var f := FileAccess.open(output_path, FileAccess.WRITE)
	if f != null:
		f.store_string(json_str)
		f.close()
		print("Benchmark saved to ", output_path)
	else:
		print("ERROR: Failed to write benchmark output to ", output_path)
	var root_bench := "res://../" + output_path
	var f_root := FileAccess.open(root_bench, FileAccess.WRITE)
	if f_root != null:
		f_root.store_string(json_str)
		f_root.close()
