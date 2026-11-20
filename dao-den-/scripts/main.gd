extends Node3D

const HZ := 60.0
const NIGHT_NAMES := ["Đảo Bến", "Đảo Cau", "Đảo Chuông"]

var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var game_camera: Camera3D
var world_environment: WorldEnvironment
var shade: Node3D
var hud: Label
var result_label: Label
var lanterns: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var flames := 3
var carried := 0
var successful_lights := 0
var score := 0
var time_left := 300.0
var invulnerable := 0.0
var pulse_cooldown := 0.0
var shade_stunned := 0.0
var shade_drain_lamp := -1
var shade_push_lamp := -1
var game_state := "playing"
var camera_yaw := 0.0
var camera_pitch := 1.27
var night := 1
var total_score := 0
var dash_cooldown := 0.0
var dash_time := 0.0
var dash_direction := Vector3.FORWARD
var charms_left := 0.0
var map_root: Node3D
var ground_radius := 40.0
var sim_ticks := 0
var drifters: Array[Dictionary] = []
var charms: Array[Dictionary] = []
var wind_dir := Vector3.ZERO
var wind_active := false
var gust_warned := false
var pause_panel: PanelContainer
var settings_box: VBoxContainer
var mouse_sensitivity := 0.004
var master_volume_db := 0.0
var colorblind_mode := false
var bgm_player: AudioStreamPlayer
var countdown_mark := -1


func _ready() -> void:
	rng.randomize()
	_setup_inputs()
	_load_settings()
	_build_world()
	_build_night_map()
	_start_background_music()
	game_state = "menu"
	result_label.text = "ĐẢO ĐÈN LỒNG\nĐêm tối đang phủ lên ba hòn đảo\nNhấn Enter để bắt đầu"


func _setup_inputs() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("interact", KEY_E)
	_add_key_action("pulse", KEY_Q)
	_add_key_action("dash", KEY_SHIFT)
	_add_key_action("restart", KEY_R)
	_add_key_action("pause", KEY_P)
	_add_key_action("pause", KEY_ESCAPE)
	_add_key_action("start", KEY_ENTER)


func _add_key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _build_world() -> void:
	world_environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0e1430")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("77718f")
	env.ambient_light_energy = 0.55
	world_environment.environment = env
	add_child(world_environment)

	var moonlight := DirectionalLight3D.new()
	moonlight.rotation_degrees = Vector3(-55, -25, 0)
	moonlight.light_color = Color("a8a4d8")
	moonlight.light_energy = 0.65
	add_child(moonlight)

	map_root = Node3D.new()
	map_root.name = "NightMap"
	add_child(map_root)

	var water := MeshInstance3D.new()
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(260, 200)
	water.mesh = water_mesh
	water.position.y = -3.2
	water.material_override = _material(Color("12384a"), 0.0)
	add_child(water)

	var star_rng := RandomNumberGenerator.new()
	star_rng.seed = 12012
	for i in range(90):
		var star := MeshInstance3D.new()
		var star_mesh := SphereMesh.new()
		star_mesh.radius = 0.055
		star_mesh.height = 0.11
		star.mesh = star_mesh
		star.position = Vector3(star_rng.randf_range(-65, 65), star_rng.randf_range(18, 48), star_rng.randf_range(-65, 65))
		star.material_override = _material(Color("f7e9b0"), 1.4)
		add_child(star)

	player = CharacterBody3D.new()
	player.name = "May"
	player.position = Vector3(0, 6.05, 0) if night == 3 else Vector3(0, 0.05, 0)
	var capsule := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.42
	capsule_shape.height = 1.8
	capsule.shape = capsule_shape
	capsule.position.y = 0.9
	player.add_child(capsule)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = 1.8
	body.mesh = body_mesh
	body.position.y = 0.9
	body.material_override = _material(Color("e9c8a0"), 0.0)
	player.add_child(body)
	var hat := MeshInstance3D.new()
	var hat_mesh := CylinderMesh.new()
	hat_mesh.top_radius = 0.08
	hat_mesh.bottom_radius = 0.62
	hat_mesh.height = 0.22
	hat.mesh = hat_mesh
	hat.position.y = 1.94
	hat.material_override = _material(Color("b98951"), 0.0)
	player.add_child(hat)
	var player_marker := MeshInstance3D.new()
	var marker_mesh := TorusMesh.new()
	marker_mesh.inner_radius = 0.48
	marker_mesh.outer_radius = 0.62
	marker_mesh.rings = 24
	marker_mesh.ring_segments = 8
	player_marker.mesh = marker_mesh
	player_marker.position.y = 0.12
	player_marker.material_override = _material(Color("5cf0cf"), 1.5)
	player.add_child(player_marker)
	var tiny_lantern := MeshInstance3D.new()
	var tiny_mesh := SphereMesh.new()
	tiny_mesh.radius = 0.16
	tiny_mesh.height = 0.32
	tiny_lantern.mesh = tiny_mesh
	tiny_lantern.position = Vector3(0.48, 1.12, -0.12)
	tiny_lantern.material_override = _material(Color("ffca68"), 1.8)
	player.add_child(tiny_lantern)
	var player_light := OmniLight3D.new()
	player_light.position = Vector3(0.48, 1.15, -0.12)
	player_light.light_color = Color("ffcc73")
	player_light.light_energy = 0.7
	player_light.omni_range = 4.0
	player.add_child(player_light)
	add_child(player)

	game_camera = Camera3D.new()
	game_camera.name = "TopDownCamera"
	game_camera.fov = 70
	game_camera.current = true
	add_child(game_camera)

	shade = Node3D.new()
	shade.name = "BongMuc"
	var shade_mesh := SphereMesh.new()
	shade_mesh.radius = 0.72
	shade_mesh.height = 1.44
	var shade_visual := MeshInstance3D.new()
	shade_visual.mesh = shade_mesh
	shade_visual.material_override = _material(Color("241a3a"), 0.2)
	shade.add_child(shade_visual)
	var shade_outline := MeshInstance3D.new()
	var outline_mesh := TorusMesh.new()
	outline_mesh.inner_radius = 0.48
	outline_mesh.outer_radius = 0.62
	shade_outline.mesh = outline_mesh
	shade_outline.position.y = 0.08
	shade_outline.material_override = _material(Color("7a3cff"), 1.0)
	shade.add_child(shade_outline)
	var shade_light := OmniLight3D.new()
	shade_light.light_color = Color("8a42c9")
	shade_light.light_energy = 0.7
	shade_light.omni_range = 3.0
	shade_light.position.y = 0.4
	shade.add_child(shade_light)
	add_child(shade)

	_build_hud()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 20)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_color_override("font_color", Color("fff1cb"))
	layer.add_child(hud)
	result_label = Label.new()
	result_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 34)
	result_label.add_theme_color_override("font_color", Color("ffe2a0"))
	layer.add_child(result_label)
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.custom_minimum_size = Vector2(360, 300)
	layer.add_child(pause_panel)
	var menu := VBoxContainer.new()
	pause_panel.add_child(menu)
	var title := Label.new()
	title.text = "TẠM DỪNG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(title)
	var resume_button := Button.new()
	resume_button.text = "Tiếp tục"
	resume_button.pressed.connect(_resume_game)
	menu.add_child(resume_button)
	var restart_button := Button.new()
	restart_button.text = "Chơi lại đêm này"
	restart_button.pressed.connect(_restart_night)
	menu.add_child(restart_button)
	var settings_button := Button.new()
	settings_button.text = "Cài đặt âm lượng / độ nhạy"
	settings_button.pressed.connect(func(): settings_box.visible = not settings_box.visible)
	menu.add_child(settings_button)
	settings_box = VBoxContainer.new()
	settings_box.visible = false
	menu.add_child(settings_box)
	var volume_label := Label.new()
	volume_label.text = "Âm lượng tổng"
	settings_box.add_child(volume_label)
	var volume_slider := HSlider.new()
	volume_slider.min_value = -40.0
	volume_slider.max_value = 0.0
	volume_slider.value = master_volume_db
	volume_slider.value_changed.connect(_on_volume_changed)
	settings_box.add_child(volume_slider)
	var sensitivity_label := Label.new()
	sensitivity_label.text = "Độ nhạy chuột"
	settings_box.add_child(sensitivity_label)
	var sensitivity_slider := HSlider.new()
	sensitivity_slider.min_value = 0.001
	sensitivity_slider.max_value = 0.01
	sensitivity_slider.step = 0.0005
	sensitivity_slider.value = mouse_sensitivity
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	settings_box.add_child(sensitivity_slider)
	var colorblind_toggle := CheckButton.new()
	colorblind_toggle.text = "Chế độ phân biệt màu"
	colorblind_toggle.button_pressed = colorblind_mode
	colorblind_toggle.toggled.connect(_on_colorblind_toggled)
	settings_box.add_child(colorblind_toggle)
	var menu_button := Button.new()
	menu_button.text = "Về màn hình chính"
	menu_button.pressed.connect(_return_to_menu)
	menu.add_child(menu_button)
	pause_panel.visible = false


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		master_volume_db = float(config.get_value("audio", "master_db", 0.0))
		mouse_sensitivity = float(config.get_value("input", "mouse_sensitivity", 0.004))
		colorblind_mode = bool(config.get_value("accessibility", "colorblind_mode", false))
	AudioServer.set_bus_volume_db(0, master_volume_db)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_db", master_volume_db)
	config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("accessibility", "colorblind_mode", colorblind_mode)
	config.save("user://settings.cfg")


func _on_volume_changed(value: float) -> void:
	master_volume_db = value
	AudioServer.set_bus_volume_db(0, value)
	_save_settings()


func _on_sensitivity_changed(value: float) -> void:
	mouse_sensitivity = value
	_save_settings()


func _on_colorblind_toggled(enabled: bool) -> void:
	colorblind_mode = enabled
	_save_settings()


func _resume_game() -> void:
	game_state = "playing"
	pause_panel.visible = false
	result_label.text = ""


func _restart_night() -> void:
	pause_panel.visible = false
	_start_round()


func _return_to_menu() -> void:
	pause_panel.visible = false
	night = 1
	total_score = 0
	game_state = "menu"
	result_label.text = "ĐẢO ĐÈN LỒNG\nĐêm tối đang phủ lên ba hòn đảo\nNhấn Enter để bắt đầu"


func _make_tone(frequency: float, duration: float, looping: bool = false) -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	var frame_count := int(SAMPLE_RATE * duration)
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 2)
	for i in range(frame_count):
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0
		if not looping:
			envelope = pow(maxf(0.0, 1.0 - float(i) / frame_count), 2.0)
		var signal_value := sin(TAU * frequency * t) + 0.22 * sin(TAU * frequency * 1.5 * t)
		pcm.encode_s16(i * 2, int(clampf(signal_value * envelope * 10000.0, -32767.0, 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = frame_count
	return stream


func _start_background_music() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "ProceduralNightMusic"
	bgm_player.stream = _make_tone(110.0, 4.0, true)
	bgm_player.volume_db = -28.0
	add_child(bgm_player)
	bgm_player.play()


func _play_sfx(kind: String) -> void:
	var tones := {
		"pickup": [880.0, 0.10], "deposit": [540.0, 0.12], "lamp": [740.0, 0.32],
		"pulse": [240.0, 0.28], "hit": [130.0, 0.30], "jump": [430.0, 0.08],
		"dash": [360.0, 0.12], "win": [920.0, 0.60], "loss": [170.0, 0.55],
		"warning": [560.0, 0.20], "shade": [150.0, 0.22]
	}
	if not tones.has(kind): return
	var tone: Array = tones[kind]
	var player_sfx := AudioStreamPlayer.new()
	player_sfx.stream = _make_tone(float(tone[0]), float(tone[1]))
	player_sfx.volume_db = -8.0
	add_child(player_sfx)
	player_sfx.finished.connect(player_sfx.queue_free)
	player_sfx.play()


func _start_round() -> void:
	pause_panel.visible = false
	for child in map_root.get_children():
		child.queue_free()
	_build_night_map()
	for lantern in lanterns:
		if is_instance_valid(lantern.get("node")):
			lantern["node"].queue_free()
	for mote in motes:
		if is_instance_valid(mote.get("node")):
			mote["node"].queue_free()
	lanterns.clear()
	var lamp_positions := _night_lantern_positions()
	for i in range(lamp_positions.size()):
		lanterns.append({
			"id": "L%d" % (i + 1), "pos": lamp_positions[i],
			"deposited": 0, "lit": false, "fuel": 0.0, "ever_lit": false, "relit_count": 0, "node": _make_lantern(i)
		})

	motes.clear()
	var points := _night_mote_points()
	var point_order: Array[int] = []
	for i in range(points.size()): point_order.append(i)
	point_order.shuffle()
	for i in range(mini(20, point_order.size())):
		var pos: Vector3 = points[point_order[i]]
		motes.append({"id": "M%d" % (i + 1), "pos": pos, "node": _make_mote(pos)})

	player.position = Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	shade.position = _night_shade_start()
	flames = 3
	carried = 0
	successful_lights = 0
	score = 0
	time_left = [240.0, 270.0, 300.0][night - 1]
	invulnerable = 0.0
	pulse_cooldown = 0.0
	dash_cooldown = 0.0
	dash_time = 0.0
	charms_left = 0.0
	countdown_mark = -1
	sim_ticks = 0
	wind_active = false
	gust_warned = false
	for drifter in drifters:
		if is_instance_valid(drifter.get("node")): drifter["node"].queue_free()
	drifters.clear()
	for charm in charms:
		if is_instance_valid(charm.get("node")): charm["node"].queue_free()
	charms.clear()
	if night == 2:
		_add_charm("C1", Vector3(35, 0, 0))
	elif night == 3:
		_add_charm("C1", Vector3(30, 0, 25))
		_add_charm("C2", Vector3(-30, 0, 25))
	shade_stunned = 0.0
	game_state = "playing"
	result_label.text = ""
	_play_sfx("shade")
	_update_hud()


func _night_lantern_positions() -> Array[Vector3]:
	match night:
		1: return [Vector3(0, 0, 25), Vector3(23.8, 0, 7.7), Vector3(14.7, 0, -20.2), Vector3(-14.7, 0, -20.2), Vector3(-23.8, 0, 7.7)]
		2: return [Vector3(0, 0, 20), Vector3(17, 0, -10), Vector3(-17, 0, -10), Vector3(70, 0, 20), Vector3(87, 0, -10), Vector3(53, 0, -10)]
		_: return [Vector3(0, 6, 6), Vector3(18, 3, 10), Vector3(-18, 3, 10), Vector3(35, 0, -10), Vector3(-35, 0, -10), Vector3(20, 0, -35), Vector3(-20, 0, -35)]


func _night_mote_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	if night == 1:
		for i in range(8): points.append(_polar(12, i * 45.0))
		for i in range(16): points.append(_polar(33, i * 22.5))
	elif night == 2:
		for cx in [0.0, 70.0]:
			for i in range(4): points.append(_polar(10, i * 90.0, Vector3(cx, 0, 0)))
			for i in range(8): points.append(_polar(22, i * 45.0, Vector3(cx, 0, 0)))
	else:
		for i in range(18): points.append(_polar(34, i * 20.0))
		for i in range(8): points.append(_polar(18, 20.0 + i * 20.0, Vector3(0, 3, 0)))
		for angle in [45.0, 135.0, 225.0, 315.0]: points.append(_polar(5, angle, Vector3(0, 6, 0)))
	return points


func _night_shade_start() -> Vector3:
	if night == 1: return Vector3(30, 0.7, 22)
	if night == 2: return Vector3(25, 0.7, 16)
	return Vector3(39, 0.7, 18)


func _polar(radius: float, degrees: float, center: Vector3 = Vector3.ZERO) -> Vector3:
	var angle := deg_to_rad(degrees)
	return center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)


func _build_night_map() -> void:
	var water_material := _material(Color("12384a"), 0.0)
	if night == 1:
		ground_radius = 40.0
		_add_platform(Vector3.ZERO, 40.0, 0.0, 2.0, Color("2f5d50"))
	elif night == 2:
		ground_radius = 28.0
		_add_platform(Vector3.ZERO, 28.0, 0.0, 2.0, Color("2f5d50"))
		_add_platform(Vector3(70, 0, 0), 28.0, 0.0, 2.0, Color("2f5d50"))
		_add_box_platform(Vector3(35, -0.1, 0), Vector3(18, 0.2, 4), Color("6b4a2f"))
		for pad_pos in [Vector3(20, 0.12, 18), Vector3(50, 0.12, -18)]:
			_add_marker(pad_pos, Color("f2c14e"), 1.15)
	else:
		ground_radius = 45.0
		_add_platform(Vector3.ZERO, 45.0, 0.0, 2.0, Color("2f5d50"))
		_add_platform(Vector3(0, 3, 0), 24.0, 3.0, 0.65, Color("c9b48a"))
		_add_platform(Vector3(0, 6, 0), 8.0, 6.0, 0.65, Color("2f5d50"))
		_add_ramp(30.0)
		_add_ramp(150.0)
		_add_box_platform(Vector3(0, 10, 0), Vector3(4, 8, 4), Color("6b4a2f"))
		_add_marker(Vector3(0, 3.12, 13), Color("f2c14e"), 1.1)
	for water_center in [Vector3.ZERO, Vector3(70, 0, 0)]:
		var water := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(280, 220)
		water.mesh = mesh
		water.position = Vector3(water_center.x, -3.2, water_center.z)
		water.material_override = water_material
		map_root.add_child(water)


func _add_platform(center: Vector3, radius: float, top: float, depth: float, color: Color) -> void:
	var root := Node3D.new()
	root.position = center + Vector3(0, top, 0)
	map_root.add_child(root)
	var mesh_node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius + 1.0
	mesh.height = depth
	mesh.radial_segments = 64
	mesh_node.mesh = mesh
	mesh_node.position.y = -depth * 0.5
	mesh_node.material_override = _material(color, 0.0)
	root.add_child(mesh_node)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = depth
	collision.shape = shape
	collision.position.y = -depth * 0.5
	body.add_child(collision)
	root.add_child(body)


func _add_box_platform(center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	map_root.add_child(body)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = center
	mesh_node.material_override = _material(color, 0.0)
	map_root.add_child(mesh_node)


func _add_marker(pos: Vector3, color: Color, radius: float) -> void:
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.25
	marker.mesh = mesh
	marker.position = pos
	marker.material_override = _material(color, 1.2)
	map_root.add_child(marker)


func _add_ramp(angle_deg: float) -> void:
	var angle := deg_to_rad(angle_deg)
	var center := Vector3(cos(angle) * 27.0, 1.5, sin(angle) * 27.0)
	var body := StaticBody3D.new()
	body.position = center
	body.rotation = Vector3(deg_to_rad(-26.565), deg_to_rad(90.0 - angle_deg), 0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 0.35, 6.0)
	collision.shape = shape
	body.add_child(collision)
	map_root.add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	visual.mesh = mesh
	visual.position = center
	visual.rotation = body.rotation
	visual.material_override = _material(Color("c9b48a"), 0.0)
	map_root.add_child(visual)


func _make_lantern(index: int) -> Node3D:
	var root := Node3D.new()
	root.position = _night_lantern_positions()[index]
	add_child(root)
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.15
	post_mesh.bottom_radius = 0.23
	post_mesh.height = 2.4
	post.mesh = post_mesh
	post.position.y = 1.2
	post.material_override = _material(Color("704c43"), 0.0)
	root.add_child(post)
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.38
	flame_mesh.height = 0.76
	flame.mesh = flame_mesh
	flame.position.y = 2.75
	flame.material_override = _material(Color("6d6271"), 0.0)
	root.add_child(flame)
	var light := OmniLight3D.new()
	light.position.y = 2.8
	light.light_color = Color("ffb94f")
	light.light_energy = 0.0
	light.omni_range = 12.0
	root.add_child(light)
	var fuel_bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(1.0, 0.09, 0.12)
	fuel_bar.mesh = bar_mesh
	fuel_bar.position = Vector3(0, 3.45, 0)
	fuel_bar.material_override = _material(Color("8be08b"), 0.8)
	root.add_child(fuel_bar)
	root.set_meta("flame", flame)
	root.set_meta("light", light)
	root.set_meta("fuel_bar", fuel_bar)
	return root


func _make_mote(pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	add_child(node)
	var orb := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	orb.mesh = mesh
	orb.material_override = _material(Color("ffe783"), 2.0)
	node.add_child(orb)
	var light := OmniLight3D.new()
	light.light_color = Color("ffdb73")
	light.light_energy = 0.45
	light.omni_range = 2.0
	node.add_child(light)
	return node


func _add_charm(id: String, pos: Vector3) -> void:
	var node := _make_mote(pos + Vector3(0, 0.35, 0))
	node.reparent(map_root)
	var orb: MeshInstance3D = node.get_child(0)
	orb.material_override = _material(Color("c8102e"), 2.0)
	charms.append({"id": id, "pos": pos, "node": node, "available": true, "respawn": 0.0})


func _make_drifter() -> Node3D:
	var node := Node3D.new()
	var orb := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 1.2
	orb.mesh = mesh
	orb.material_override = _material(Color("8fa3b8"), 0.8)
	node.add_child(orb)
	add_child(node)
	return node


func _material(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_yaw -= event.relative.x * mouse_sensitivity
		camera_pitch = clampf(camera_pitch - event.relative.y * mouse_sensitivity * 0.625, 0.95, 1.4)
		_aim_camera()


func _physics_process(delta: float) -> void:
	if game_state == "menu":
		if Input.is_action_just_pressed("start"):
			game_state = "intro"
			result_label.text = "ĐÊM %d — %s\nÔng Đặng nhờ Mây thắp lại những chiếc đèn trước bình minh.\nNhấn Enter để lên đường" % [night, NIGHT_NAMES[night - 1]]
		return
	if game_state == "intro":
		if Input.is_action_just_pressed("start") or Input.is_action_just_pressed("restart"):
			_start_round()
		return
	if game_state == "paused":
		if Input.is_action_just_pressed("pause"):
			_resume_game()
		elif Input.is_action_just_pressed("restart"):
			_start_round()
		return
	if game_state != "playing":
		if Input.is_action_just_pressed("restart"):
			if game_state == "won" and night < 3:
				total_score += score
				night += 1
				game_state = "intro"
				result_label.text = "ĐÊM %d — %s\nÔng Đặng chỉ đường sang hòn đảo tiếp theo.\nNhấn Enter để tiếp tục" % [night, NIGHT_NAMES[night - 1]]
			elif game_state == "won" and night == 3:
				var completed_score := total_score + score
				night = 1
				total_score = 0
				game_state = "menu"
				result_label.text = "BÌNH MINH TRÊN BA ĐẢO!\nTổng điểm: %d\nNhấn Enter để chơi lại" % completed_score
			else:
				_start_round()
		return
	if Input.is_action_just_pressed("pause"):
		game_state = "paused"
		pause_panel.visible = true
		result_label.text = ""
		return

	time_left = maxf(0.0, time_left - delta)
	sim_ticks += 1
	var seconds_mark := ceili(time_left)
	if seconds_mark <= 10 and seconds_mark != countdown_mark:
		countdown_mark = seconds_mark
		_play_sfx("warning")
	invulnerable = maxf(0.0, invulnerable - delta)
	pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_time = maxf(0.0, dash_time - delta)
	charms_left = maxf(0.0, charms_left - delta)
	shade_stunned = maxf(0.0, shade_stunned - delta)
	_move_player(delta)
	_aim_camera()
	_update_motes(delta)
	_update_charms(delta)
	_update_drifters(delta)
	_update_gust(delta)
	_update_lantern_fuel(delta)
	_interact_lantern()
	_try_pulse()
	_update_shade(delta)
	_check_end()
	_update_hud()


func _move_player(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := Vector3(sin(camera_yaw), 0, cos(camera_yaw))
	var right := Vector3(-forward.z, 0, forward.x)
	var direction := right * input_vector.x - forward * input_vector.y
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	if direction.length_squared() > 0.001:
		dash_direction = direction.normalized()
	if Input.is_action_just_pressed("dash") and dash_time <= 0.0 and (dash_cooldown <= 0.0 or charms_left > 0.0):
		dash_direction = direction.normalized() if direction.length_squared() > 0.001 else forward
		dash_time = 0.2
		_play_sfx("dash")
		if charms_left <= 0.0: dash_cooldown = 1.5
	var pad_launch := player.has_meta("pad_lock")
	if pad_launch:
		player.velocity.y -= 20.0 * delta
	elif dash_time > 0.0:
		player.velocity.x = dash_direction.x * 14.0
		player.velocity.z = dash_direction.z * 14.0
		player.velocity.y = 0.0
	else:
		var run_speed := 7.2 if charms_left > 0.0 else 6.0
		player.velocity.x = direction.x * run_speed
		player.velocity.z = direction.z * run_speed
		if not player.is_on_floor():
			player.velocity.y -= 20.0 * delta
		else:
			player.velocity.y = 0.0
			if Input.is_action_just_pressed("jump"):
				player.velocity.y = 7.0
				_play_sfx("jump")
	player.move_and_slide()
	if night == 2 and not player.has_meta("pad_lock"):
		for pair in [[Vector3(20, 0, 18), Vector3(70, 0, 0)], [Vector3(50, 0, -18), Vector3.ZERO]]:
			if _flat_distance(player.position, pair[0]) <= 1.0 and player.is_on_floor():
				var launch: Vector3 = pair[1] - pair[0]
				launch.y = 0
				launch = launch.normalized() * 24.0
				player.velocity = Vector3(launch.x, 14.0, launch.z)
				player.set_meta("pad_lock", true)
	elif night == 3 and not player.has_meta("pad_lock") and _flat_distance(player.position, Vector3(0, 3, 13)) <= 1.0 and player.is_on_floor():
		player.velocity = Vector3(0, 12.0, -8.0)
		player.set_meta("pad_lock", true)
	if pad_launch and player.is_on_floor(): player.remove_meta("pad_lock")
	if player.global_position.y < -10.0:
		_play_sfx("hit")
		flames -= 1
		carried = 0
		if flames <= 0:
			game_state = "lost"
		else:
			player.position = Vector3.ZERO
			player.velocity = Vector3.ZERO
			invulnerable = 1.5


func _aim_camera() -> void:
	if is_instance_valid(game_camera) and is_instance_valid(player):
		var distance := 42.0 if night == 2 else 32.0
		var horizontal := cos(camera_pitch) * distance
		var vertical := sin(camera_pitch) * distance
		var offset := Vector3(0, vertical, -horizontal).rotated(Vector3.UP, camera_yaw)
		game_camera.global_position = player.global_position + offset
		game_camera.look_at(player.global_position + Vector3(0, 0.9, 0), Vector3.UP)


func _update_motes(delta: float) -> void:
	if sim_ticks > 0 and sim_ticks % 240 == 0 and motes.size() < 30:
		var spawn_pos := _polar(12.0 + float((sim_ticks / 240) % 2) * 21.0, float(sim_ticks % 360))
		if night == 2 and sim_ticks % 2 == 0: spawn_pos.x += 70.0
		var mote_node := _make_mote(spawn_pos)
		motes.append({"id": "M%d" % (motes.size() + 1), "pos": spawn_pos, "node": mote_node})
	for i in range(motes.size() - 1, -1, -1):
		var mote: Dictionary = motes[i]
		var node: Node3D = mote["node"]
		node.position.y = float(mote["pos"].y) + 0.45 + sin(Time.get_ticks_msec() * 0.002 + i) * 0.12
		if carried < 10 and _flat_distance(player.position, mote["pos"]) <= 1.0 and absf(player.position.y - mote["pos"].y) <= 1.5:
			carried += 1
			_play_sfx("pickup")
			node.queue_free()
			motes.remove_at(i)


func _update_charms(delta: float) -> void:
	for charm in charms:
		if not charm["available"]:
			charm["respawn"] = maxf(0.0, float(charm["respawn"]) - delta)
			if charm["respawn"] <= 0.0:
				charm["available"] = true
				charm["node"].visible = true
		elif _flat_distance(player.position, charm["pos"]) <= 1.0 and absf(player.position.y - charm["pos"].y) <= 1.5:
			charm["available"] = false
			charm["respawn"] = 45.0
			charm["node"].visible = false
			charms_left = 10.0


func _update_drifters(delta: float) -> void:
	if night >= 2 and sim_ticks > 0 and sim_ticks % 1200 == 0 and drifters.size() < 2:
		var start := Vector3(-20, 0.6, 18) if night == 2 else Vector3(20, 0.6, -38)
		var node := _make_drifter()
		node.position = start
		drifters.append({"node": node, "state": "idle", "stolen": 0, "ticks": 0.0})
	for i in range(drifters.size() - 1, -1, -1):
		var drifter: Dictionary = drifters[i]
		var node: Node3D = drifter["node"]
		if drifter["state"] == "removed":
			drifter["ticks"] = maxf(0.0, float(drifter["ticks"]) - delta)
			if drifter["ticks"] <= 0.0:
				node.queue_free()
				drifters.remove_at(i)
			continue
		var distance := _flat_distance(player.position, node.position)
		if drifter["state"] == "idle" and carried >= 5 and distance <= 15.0:
			drifter["state"] = "chase"
		elif drifter["state"] == "chase" and (carried < 5 or distance > 22.5):
			drifter["state"] = "idle"
		var target: Vector3 = player.position if drifter["state"] == "chase" else node.position + Vector3(0.1, 0, 0)
		if drifter["state"] == "flee":
			target = node.position + (node.position - player.position).normalized() * 10.0
		var speed := 7.0 if drifter["state"] in ["flee", "chase"] else 2.0
		var toward := target - node.position
		toward.y = 0
		if toward.length_squared() > 0.01: node.position += toward.normalized() * speed * delta
		if drifter["state"] == "chase" and distance <= 1.2:
			var stolen := mini(3, carried)
			carried -= stolen
			drifter["stolen"] = stolen
			drifter["state"] = "flee"
			drifter["ticks"] = 4.0
		if drifter["state"] == "flee":
			drifter["ticks"] = maxf(0.0, float(drifter["ticks"]) - delta)
			if drifter["ticks"] <= 0.0:
				drifter["state"] = "removed"
				drifter["ticks"] = 2.0


func _update_gust(delta: float) -> void:
	if night != 3: return
	var phase := sim_ticks % 1800
	wind_active = sim_ticks >= 1800 and phase < 300
	if phase == 1680 and not gust_warned:
		wind_dir = Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0)).normalized()
		gust_warned = true
		result_label.text = "CẢNH BÁO: GIÓ LỚN!"
		_play_sfx("warning")
	if phase == 0:
		gust_warned = false
		result_label.text = ""
	if wind_active: player.velocity += wind_dir * 2.0 * delta


func _interact_lantern() -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	var nearest_index := -1
	var nearest_distance := INF
	for i in range(lanterns.size()):
		if lanterns[i]["lit"] and float(lanterns[i]["fuel"]) >= 100.0:
			continue
		var d: float = _flat_distance(player.position, lanterns[i]["pos"])
		if d < nearest_distance:
			nearest_distance = d
			nearest_index = i
	if nearest_index < 0 or nearest_distance > 2.0 or carried <= 0:
		return
	var lantern: Dictionary = lanterns[nearest_index]
	if lantern["lit"]:
		var refuel_amount := mini(carried, ceili((100.0 - float(lantern["fuel"])) / 10.0))
		if refuel_amount <= 0: return
		carried -= refuel_amount
		lantern["fuel"] = minf(100.0, float(lantern["fuel"]) + refuel_amount * 10.0)
		if float(lantern["fuel"]) >= 30.0 and _flat_distance(shade.position, lantern["pos"]) <= 6.0:
			shade_push_lamp = nearest_index
			shade_drain_lamp = -1
		score += refuel_amount * 5
		_play_sfx("deposit")
		_update_lantern_visual(lantern)
		return
	var relight := bool(lantern["ever_lit"])
	var cost := 5 if relight else 10
	var amount := mini(cost - int(lantern["deposited"]), carried)
	carried -= amount
	lantern["deposited"] += amount
	score += amount * 5
	_play_sfx("deposit")
	if int(lantern["deposited"]) >= cost:
		lantern["lit"] = true
		lantern["ever_lit"] = true
		lantern["fuel"] = 100.0
		lantern["deposited"] = 0
		if _flat_distance(shade.position, lantern["pos"]) <= 6.0:
			shade_push_lamp = nearest_index
			shade_drain_lamp = -1
		lantern["relit_count"] = int(lantern["relit_count"]) + (1 if relight else 0)
		successful_lights += 1
		score += 40 if relight else 100
		_update_lantern_visual(lantern)
		_play_sfx("lamp")


func _update_lantern_fuel(delta: float) -> void:
	for lantern in lanterns:
		if lantern["lit"]:
			lantern["fuel"] = maxf(0.0, float(lantern["fuel"]) - delta)
			if lantern["fuel"] <= 0.0:
				lantern["lit"] = false
				lantern["deposited"] = 0
				if shade_drain_lamp >= 0 and shade_drain_lamp == lanterns.find(lantern): shade_drain_lamp = -1
		_update_lantern_visual(lantern)


func _update_lantern_visual(lantern: Dictionary) -> void:
	var root: Node3D = lantern["node"]
	var flame: MeshInstance3D = root.get_meta("flame")
	var light: OmniLight3D = root.get_meta("light")
	var bar: MeshInstance3D = root.get_meta("fuel_bar")
	var lit := bool(lantern["lit"])
	var weak := lit and float(lantern["fuel"]) < 30.0
	var visible_lit := lit and (not weak or int(sim_ticks / 30) % 2 == 0)
	flame.scale = Vector3.ONE if visible_lit else Vector3(1.0, 0.8, 1.0)
	light.light_energy = 2.4 * float(lantern["fuel"]) / 100.0 if lit else 0.0
	bar.visible = lit
	bar.scale.x = maxf(0.02, float(lantern["fuel"]) / 100.0)
	var visual_key := "%s:%s:%s" % [lit, visible_lit, weak]
	if str(root.get_meta("visual_key", "")) != visual_key:
		flame.material_override = _material(Color("ffca5e") if visible_lit else Color("6d6271"), 2.2 if visible_lit else 0.0)
		bar.material_override = _material(Color("ff5a5f") if weak else Color("8be08b"), 0.8)
		root.set_meta("visual_key", visual_key)


func _try_pulse() -> void:
	if not Input.is_action_just_pressed("pulse") or pulse_cooldown > 0 or carried < 3:
		return
	carried -= 3
	pulse_cooldown = 3.0
	_play_sfx("pulse")
	if player.position.distance_to(shade.position) <= 5.0:
		var was_draining := shade_drain_lamp >= 0
		shade_stunned = 2.0
		shade_drain_lamp = -1
		shade_push_lamp = -1
		var away := shade.position - player.position
		away.y = 0
		if away.length_squared() > 0:
			shade.position += away.normalized() * 4.0
		score += 15 if was_draining else 5
		shade.get_child(0).material_override = _material(Color("8062a0"), 1.1)
	else:
		shade.get_child(0).material_override = _material(Color("241a3a"), 0.2)
	for drifter in drifters:
		var node: Node3D = drifter["node"]
		if player.position.distance_to(node.position) > 5.0: continue
		if drifter["state"] == "chase":
			drifter["state"] = "flee"
			drifter["ticks"] = 4.0
		elif drifter["state"] == "flee" and int(drifter["stolen"]) > 0:
			for i in range(int(drifter["stolen"])):
				var dropped_pos: Vector3 = node.position + _polar(1.8 + rng.randf() * 0.6, rng.randf() * 360.0)
				motes.append({"id": "M%d" % (motes.size() + 1), "pos": dropped_pos, "node": _make_mote(dropped_pos)})
			drifter["stolen"] = 0
			drifter["state"] = "removed"
			drifter["ticks"] = 2.0


func _update_shade(delta: float) -> void:
	var outline: MeshInstance3D = shade.get_child(1)
	if bool(outline.get_meta("colorblind", false)) != colorblind_mode:
		outline.material_override = _material(Color("00b3ff") if colorblind_mode else Color("7a3cff"), 1.0)
		outline.set_meta("colorblind", colorblind_mode)
	if shade_stunned > 0:
		shade_drain_lamp = -1
		return
	if shade_push_lamp >= 0 and shade_push_lamp < lanterns.size():
		var pushed_lamp: Dictionary = lanterns[shade_push_lamp]
		var outward: Vector3 = shade.position - pushed_lamp["pos"]
		outward.y = 0
		if outward.length() < 6.0 and pushed_lamp["lit"] and float(pushed_lamp["fuel"]) >= 30.0:
			if outward.length_squared() < 0.001: outward = Vector3.RIGHT
			shade.position += outward.normalized() * 12.0 * delta
			return
		shade_push_lamp = -1
	var weak_index := -1
	var weak_distance := INF
	for i in range(lanterns.size()):
		var lantern: Dictionary = lanterns[i]
		if lantern["lit"] and float(lantern["fuel"]) < 30.0 and _flat_distance(shade.position, lantern["pos"]) < weak_distance:
			weak_index = i
			weak_distance = _flat_distance(shade.position, lantern["pos"])
	if weak_index >= 0:
		var weak_lamp: Dictionary = lanterns[weak_index]
		var to_lamp: Vector3 = weak_lamp["pos"] - shade.position
		to_lamp.y = 0
		if to_lamp.length() > 2.0:
			shade_drain_lamp = -1
			shade.position += to_lamp.normalized() * 4.0 * delta
		else:
			shade_drain_lamp = weak_index
			weak_lamp["fuel"] = maxf(0.0, float(weak_lamp["fuel"]) - 5.0 * delta)
		return
	shade_drain_lamp = -1
	for lantern in lanterns:
		if lantern["lit"] and float(lantern["fuel"]) >= 30.0 and _flat_distance(shade.position, lantern["pos"]) <= 6.0:
			return
	var direction: Vector3 = player.position - shade.position
	direction.y = 0
	var distance := direction.length()
	if distance > 18.0: return
	if distance <= 12.0 and direction.length_squared() > 0.01:
		shade.position += direction.normalized() * (4.5 if night == 3 else 4.0) * delta
	if invulnerable <= 0 and _flat_distance(player.position, shade.position) <= 1.0 and absf(player.position.y - shade.position.y) <= 1.5:
		flames -= 1
		_play_sfx("hit")
		invulnerable = 1.5
		shade_stunned = 1.5
		var dropped := floori(carried * 0.5)
		carried -= dropped
		var knockback: Vector3 = shade.position - player.position
		knockback.y = 0
		if knockback.length_squared() > 0.0:
			shade.position += knockback.normalized() * 4.0
		for i in range(dropped):
			var angle := rng.randf_range(0.0, TAU)
			var radius := rng.randf_range(1.8, 2.4)
			var offset := Vector3(cos(angle) * radius, 0.45, sin(angle) * radius)
			var pos: Vector3 = player.position + offset
			motes.append({"id": "M%d" % (motes.size() + 1), "pos": pos, "node": _make_mote(pos)})


func _check_end() -> void:
	if flames <= 0:
		game_state = "lost"
		_play_sfx("loss")
		result_label.text = "ĐÊM TỐI QUÁ!\nĐiểm: %d\nNhấn R để thử lại" % score
		return
	if time_left > 0.0: return
	var lit_count := 0
	for lantern in lanterns:
		if lantern["lit"]: lit_count += 1
	if lit_count >= ceili(lanterns.size() * 0.6):
		game_state = "won"
		_play_sfx("win")
		for lantern in lanterns:
			if lantern["lit"]: score += 50 + floori(float(lantern["fuel"]))
		score += flames * 50
		if night < 3:
			result_label.text = "%s ĐÃ SÁNG!\nĐiểm đêm: %d\nNhấn R sang đêm tiếp theo" % [NIGHT_NAMES[night - 1], score]
		else:
			result_label.text = "BÌNH MINH TRÊN BA ĐẢO!\nTổng điểm: %d\nNhấn R để chơi lại" % (total_score + score)
	else:
		game_state = "lost"
		_play_sfx("loss")
		result_label.text = "BÌNH MINH ĐÃ LÊN\nĐiểm: %d\nNhấn R để chơi lại" % score


func _update_hud() -> void:
	var lit_count := 0
	for lantern in lanterns:
		if lantern["lit"]:
			lit_count += 1
	var total_lamps := lanterns.size()
	var shown_time := _format_time(time_left)
	if time_left <= 30.0:
		hud.add_theme_color_override("font_color", Color.WHITE if colorblind_mode else Color("ff5a5f"))
	else:
		hud.add_theme_color_override("font_color", Color("f5f1e6"))
	var nearest_hint := ""
	var nearest_distance := INF
	for lamp in lanterns:
		if lamp["lit"] and float(lamp["fuel"]) >= 100.0: continue
		var d := _flat_distance(player.position, lamp["pos"])
		if d < nearest_distance:
			nearest_distance = d
			var delta: Vector3 = lamp["pos"] - player.position
			delta = delta.rotated(Vector3.UP, -camera_yaw)
			var arrow_index := posmod(roundi(wrapf(rad_to_deg(atan2(delta.x, delta.z)), 0.0, 360.0) / 45.0), 8)
			var arrows := ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
			nearest_hint = "%s Đèn gần nhất · E nạp (%d/10) · %.0fm" % [arrows[arrow_index], floori(float(lamp["fuel"])) if lamp["lit"] else int(lamp["deposited"]), d]
	var capacity := mini(20, 10 + 2 * successful_lights)
	var mote_bar := "●".repeat(carried) + "○".repeat(maxi(0, capacity - carried))
	world_environment.environment.ambient_light_energy = 0.15 + 0.55 * float(lit_count) / float(maxi(total_lamps, 1))
	hud.text = "ĐÊM %d — %s\nĐom đóm: %s %d/%d     Đèn: %d/%d\nLửa: %s     Điểm: %d     Còn: %s%s\nLướt: %.1fs · Xung sáng: %.1fs · Gió: %s\nWASD · Space nhảy · Shift lướt · E nạp đèn · Q xung sáng · P/Esc tạm dừng\n%s" % [night, NIGHT_NAMES[night - 1], mote_bar, carried, capacity, lit_count, total_lamps, "✦ ".repeat(maxi(flames, 0)), score + total_score, " ⚠" if time_left <= 30.0 else "", shown_time, dash_cooldown, pulse_cooldown, "đang thổi" if wind_active else "lặng", nearest_hint]


func _format_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%02d:%02d" % [total / 60, total % 60]


func _flat_distance(a: Vector3, b: Vector3) -> float:
	var delta := a - b
	delta.y = 0
	return delta.length()
