extends Node3D

const HZ := 60.0
const NIGHT_NAMES := ["Đảo Bến", "Đảo Cau", "Đảo Chuông"]
const SHADE_DETECT_RADIUS := 12.0
const SHADE_LOSE_RADIUS := 24.0
const SHADE_SPEED := 4.0

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
var shade_state := "wander"
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
var reduce_motion := false
var large_ui := false
var bgm_player: AudioStreamPlayer
var countdown_mark := -1

var subtitle_banner: Label
var leaderboard_panel: PanelContainer
var leaderboard_text: Label
var name_entry_dialog: PanelContainer
var name_input: LineEdit
var pending_score := 0
var pending_nights_won := 0
var awaiting_name := false
var round_seed := 1
var key_rebind_action := ""
var keybind_buttons: Dictionary = {}
var keybind_alert: Label

const LEADERBOARD_PATH := "user://leaderboard.json"
const DEFAULT_KEY_BINDINGS: Dictionary = {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"dash": KEY_SHIFT,
	"interact": KEY_E,
	"pulse": KEY_Q,
	"pause": KEY_P
}
var key_bindings: Dictionary = DEFAULT_KEY_BINDINGS.duplicate()


func _ready() -> void:
	_check_cli()
	rng.randomize()
	round_seed = rng.randi()
	_load_settings()
	_setup_inputs()
	_build_world()
	_build_night_map()
	_start_background_music()
	game_state = "menu"
	result_label.text = "ĐẢO ĐÈN LỒNG\nĐêm tối đang phủ lên ba hòn đảo\nNhấn Enter để bắt đầu | Nhấn L: Bảng xếp hạng"


func _check_cli() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--export-leaderboard" and i + 1 < args.size():
			var out_file := str(args[i + 1])
			var board := _load_leaderboard()
			var data := {"entries": board}
			var json_text := JSON.stringify(data, "  ")
			var global_out := ProjectSettings.globalize_path(out_file)
			var parent_dir := global_out.get_base_dir()
			if not parent_dir.is_empty() and not DirAccess.dir_exists_absolute(parent_dir):
				DirAccess.make_dir_recursive_absolute(parent_dir)
			var f := FileAccess.open(out_file, FileAccess.WRITE)
			if f != null:
				f.store_string(json_text)
				f.close()
				print("Leaderboard exported to: ", out_file)
			else:
				push_error("Failed to write leaderboard export to: " + out_file)
			get_tree().quit(0)
			return


func _setup_inputs() -> void:
	for action in key_bindings:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = key_bindings[action]
		InputMap.action_add_event(action, event)
	# Secondary default fallbacks
	_add_key_action("pause", KEY_ESCAPE)
	_add_key_action("restart", KEY_R)
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
	var coat := MeshInstance3D.new()
	var coat_mesh := CylinderMesh.new()
	coat_mesh.top_radius = 0.25
	coat_mesh.bottom_radius = 0.43
	coat_mesh.height = 0.92
	coat_mesh.radial_segments = 8
	coat.mesh = coat_mesh
	coat.position.y = 0.77
	coat.material_override = _material(Color("2c7775"), 0.0)
	player.add_child(coat)
	var scarf := MeshInstance3D.new()
	var scarf_mesh := TorusMesh.new()
	scarf_mesh.inner_radius = 0.22
	scarf_mesh.outer_radius = 0.29
	scarf.mesh = scarf_mesh
	scarf.position.y = 1.48
	scarf.material_override = _material(Color("e56f55"), 0.15)
	player.add_child(scarf)
	var coat_trim := MeshInstance3D.new()
	var trim_mesh := CylinderMesh.new()
	trim_mesh.top_radius = 0.255
	trim_mesh.bottom_radius = 0.34
	trim_mesh.height = 0.08
	trim_mesh.radial_segments = 8
	coat_trim.mesh = trim_mesh
	coat_trim.position.y = 0.35
	coat_trim.material_override = _material(Color("e4b866"), 0.0)
	player.add_child(coat_trim)
	for side in [-1.0, 1.0]:
		var sleeve := MeshInstance3D.new()
		var sleeve_mesh := CapsuleMesh.new()
		sleeve_mesh.radius = 0.15
		sleeve_mesh.height = 0.62
		sleeve.mesh = sleeve_mesh
		sleeve.position = Vector3(side * 0.38, 1.03, 0.0)
		sleeve.rotation.z = deg_to_rad(side * -28.0)
		sleeve.material_override = _material(Color("3d8f87"), 0.0)
		player.add_child(sleeve)
		var boot := MeshInstance3D.new()
		var boot_mesh := BoxMesh.new()
		boot_mesh.size = Vector3(0.25, 0.16, 0.38)
		boot.mesh = boot_mesh
		boot.position = Vector3(side * 0.17, 0.12, -0.06)
		boot.material_override = _material(Color("493d3c"), 0.0)
		player.add_child(boot)
	var backpack := MeshInstance3D.new()
	var pack_mesh := BoxMesh.new()
	pack_mesh.size = Vector3(0.46, 0.56, 0.25)
	backpack.mesh = pack_mesh
	backpack.position = Vector3(0, 1.02, 0.34)
	backpack.material_override = _material(Color("9a6743"), 0.0)
	player.add_child(backpack)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.055
		eye_mesh.height = 0.11
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.13, 1.37, -0.345)
		eye.material_override = _material(Color("382c36"), 0.0)
		player.add_child(eye)
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
	shade_mesh.radial_segments = 12
	shade_mesh.rings = 6
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
	var shade_face := Node3D.new()
	shade_face.name = "Face"
	shade.add_child(shade_face)
	for side in [-1.0, 1.0]:
		var eye_glow := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.16
		eye_mesh.height = 0.24
		eye_glow.mesh = eye_mesh
		eye_glow.position = Vector3(side * 0.24, 0.45, -0.52)
		eye_glow.material_override = _material(Color("ff579a"), 2.8)
		shade_face.add_child(eye_glow)
		var pupil := MeshInstance3D.new()
		var pupil_mesh := SphereMesh.new()
		pupil_mesh.radius = 0.065
		pupil_mesh.height = 0.1
		pupil.mesh = pupil_mesh
		pupil.position = Vector3(side * 0.24, 0.45, -0.65)
		pupil.material_override = _material(Color("fff1cb"), 1.4)
		shade_face.add_child(pupil)
	for i in range(7):
		var angle := TAU * float(i) / 7.0
		var tendril := MeshInstance3D.new()
		var tendril_mesh := CylinderMesh.new()
		tendril_mesh.top_radius = 0.015
		tendril_mesh.bottom_radius = 0.13
		tendril_mesh.height = 0.9
		tendril_mesh.radial_segments = 5
		tendril.mesh = tendril_mesh
		tendril.position = Vector3(cos(angle) * 0.54, 0.06, sin(angle) * 0.54)
		tendril.rotation = Vector3(cos(angle) * 0.9, 0.0, sin(angle) * -0.9)
		tendril.material_override = _material(Color("171426"), 0.25)
		shade.add_child(tendril)
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
	hud.add_theme_font_size_override("font_size", 25 if large_ui else 20)
	hud.add_theme_color_override("font_color", Color("fff1cb"))
	layer.add_child(hud)

	subtitle_banner = Label.new()
	subtitle_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	subtitle_banner.position = Vector2(0, 110)
	subtitle_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_banner.add_theme_font_size_override("font_size", 22 if large_ui else 18)
	subtitle_banner.add_theme_color_override("font_color", Color("ffeb3b"))
	layer.add_child(subtitle_banner)

	result_label = Label.new()
	result_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 34)
	result_label.add_theme_color_override("font_color", Color("ffe2a0"))
	layer.add_child(result_label)

	# Pause Panel
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.custom_minimum_size = Vector2(400, 380)
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

	var leaderboard_btn := Button.new()
	leaderboard_btn.text = "Bảng xếp hạng (Top 10)"
	leaderboard_btn.pressed.connect(_show_leaderboard)
	menu.add_child(leaderboard_btn)

	var settings_button := Button.new()
	settings_button.text = "Cài đặt & Dễ tiếp cận"
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

	var motion_toggle := CheckButton.new()
	motion_toggle.text = "Giảm rung chấn / chuyển động"
	motion_toggle.button_pressed = reduce_motion
	motion_toggle.toggled.connect(_on_reduce_motion_toggled)
	settings_box.add_child(motion_toggle)

	var large_ui_toggle := CheckButton.new()
	large_ui_toggle.text = "Chữ lớn UI (×1.25)"
	large_ui_toggle.button_pressed = large_ui
	large_ui_toggle.toggled.connect(_on_large_ui_toggled)
	settings_box.add_child(large_ui_toggle)

	# Key rebind header & list
	var key_header := Label.new()
	key_header.text = "-- Đổi phím điều khiển --"
	settings_box.add_child(key_header)

	keybind_alert = Label.new()
	keybind_alert.add_theme_color_override("font_color", Color("ff5252"))
	settings_box.add_child(keybind_alert)

	var actions_labels := {
		"move_forward": "Tiến",
		"move_back": "Lùi",
		"move_left": "Trái",
		"move_right": "Phải",
		"jump": "Nhảy",
		"dash": "Lướt",
		"interact": "Nạp đèn",
		"pulse": "Xung sáng",
		"pause": "Tạm dừng"
	}
	for act in actions_labels:
		var btn := Button.new()
		var key_code: int = key_bindings.get(act, KEY_NONE)
		btn.text = "%s: %s" % [actions_labels[act], OS.get_keycode_string(key_code)]
		btn.pressed.connect(_start_key_rebind.bind(act))
		keybind_buttons[act] = btn
		settings_box.add_child(btn)

	var reset_keys_btn := Button.new()
	reset_keys_btn.text = "Khôi phục phím mặc định"
	reset_keys_btn.pressed.connect(_reset_default_keybinds)
	settings_box.add_child(reset_keys_btn)

	var menu_button := Button.new()
	menu_button.text = "Về màn hình chính"
	menu_button.pressed.connect(_return_to_menu)
	menu.add_child(menu_button)
	pause_panel.visible = false

	# Leaderboard Modal
	leaderboard_panel = PanelContainer.new()
	leaderboard_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	leaderboard_panel.custom_minimum_size = Vector2(500, 360)
	leaderboard_panel.visible = false
	layer.add_child(leaderboard_panel)
	var lb_vbox := VBoxContainer.new()
	leaderboard_panel.add_child(lb_vbox)
	var lb_title := Label.new()
	lb_title.text = "BẢNG XẾP HẠNG (TOP 10)"
	lb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb_title.add_theme_font_size_override("font_size", 22)
	lb_vbox.add_child(lb_title)
	leaderboard_text = Label.new()
	leaderboard_text.add_theme_font_size_override("font_size", 16)
	lb_vbox.add_child(leaderboard_text)
	var lb_close := Button.new()
	lb_close.text = "Đóng"
	lb_close.pressed.connect(func(): leaderboard_panel.visible = false)
	lb_vbox.add_child(lb_close)

	# Name Entry Modal
	name_entry_dialog = PanelContainer.new()
	name_entry_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	name_entry_dialog.custom_minimum_size = Vector2(360, 200)
	name_entry_dialog.visible = false
	layer.add_child(name_entry_dialog)
	var ne_vbox := VBoxContainer.new()
	name_entry_dialog.add_child(ne_vbox)
	var ne_title := Label.new()
	ne_title.text = "LƯU ĐIỂM BẢNG XẾP HẠNG"
	ne_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ne_vbox.add_child(ne_title)
	var ne_hint := Label.new()
	ne_hint.text = "Nhập tên (3–12 ký tự [A-Za-z0-9_]):"
	ne_vbox.add_child(ne_hint)
	name_input = LineEdit.new()
	name_input.text = "Player"
	name_input.max_length = 12
	ne_vbox.add_child(name_input)
	var ne_btn_box := HBoxContainer.new()
	ne_vbox.add_child(ne_btn_box)
	var ne_submit := Button.new()
	ne_submit.text = "Lưu điểm"
	ne_submit.pressed.connect(_on_name_submitted)
	ne_btn_box.add_child(ne_submit)
	var ne_skip := Button.new()
	ne_skip.text = "Bỏ qua"
	ne_skip.pressed.connect(func(): name_entry_dialog.visible = false; awaiting_name = false)
	ne_btn_box.add_child(ne_skip)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		master_volume_db = float(config.get_value("audio", "master_db", 0.0))
		mouse_sensitivity = float(config.get_value("input", "mouse_sensitivity", 0.004))
		colorblind_mode = bool(config.get_value("accessibility", "colorblind_mode", false))
		reduce_motion = bool(config.get_value("accessibility", "reduce_motion", false))
		large_ui = bool(config.get_value("accessibility", "large_ui", false))
		for action in DEFAULT_KEY_BINDINGS:
			key_bindings[action] = int(config.get_value("keybinds", action, DEFAULT_KEY_BINDINGS[action]))
	AudioServer.set_bus_volume_db(0, master_volume_db)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_db", master_volume_db)
	config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("accessibility", "colorblind_mode", colorblind_mode)
	config.set_value("accessibility", "reduce_motion", reduce_motion)
	config.set_value("accessibility", "large_ui", large_ui)
	for action in key_bindings:
		config.set_value("keybinds", action, key_bindings[action])
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


func _on_reduce_motion_toggled(enabled: bool) -> void:
	reduce_motion = enabled
	_save_settings()


func _on_large_ui_toggled(enabled: bool) -> void:
	large_ui = enabled
	if is_instance_valid(hud):
		hud.add_theme_font_size_override("font_size", 25 if large_ui else 20)
	if is_instance_valid(subtitle_banner):
		subtitle_banner.add_theme_font_size_override("font_size", 22 if large_ui else 18)
	_save_settings()


func _start_key_rebind(action: String) -> void:
	key_rebind_action = action
	if keybind_buttons.has(action):
		keybind_buttons[action].text = "... Nhấn phím mới ..."
	keybind_alert.text = "Nhấn phím mới cho hành động này (Esc để hủy)..."


func _refresh_keybind_buttons() -> void:
	var actions_labels := {
		"move_forward": "Tiến",
		"move_back": "Lùi",
		"move_left": "Trái",
		"move_right": "Phải",
		"jump": "Nhảy",
		"dash": "Lướt",
		"interact": "Nạp đèn",
		"pulse": "Xung sáng",
		"pause": "Tạm dừng"
	}
	for act in keybind_buttons:
		var key_code: int = key_bindings.get(act, KEY_NONE)
		keybind_buttons[act].text = "%s: %s" % [actions_labels.get(act, act), OS.get_keycode_string(key_code)]


func _reset_default_keybinds() -> void:
	key_bindings = DEFAULT_KEY_BINDINGS.duplicate()
	key_rebind_action = ""
	keybind_alert.text = "Đã khôi phục phím mặc định!"
	_refresh_keybind_buttons()
	_setup_inputs()
	_save_settings()


func _load_leaderboard() -> Array[Dictionary]:
	if not FileAccess.file_exists(LEADERBOARD_PATH):
		return []
	var f := FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)
	if f == null:
		return []
	var text := f.get_as_text()
	f.close()
	var json = JSON.parse_string(text)
	var entries: Array[Dictionary] = []
	if json is Dictionary and json.has("entries") and json["entries"] is Array:
		for item in json["entries"]:
			if item is Dictionary:
				entries.append(item)
	elif json is Array:
		for item in json:
			if item is Dictionary:
				entries.append(item)
	_sort_leaderboard(entries)
	return entries


func _save_leaderboard(entries: Array[Dictionary]) -> void:
	_sort_leaderboard(entries)
	if entries.size() > 10:
		entries = entries.slice(0, 10)
	var global_out := ProjectSettings.globalize_path(LEADERBOARD_PATH)
	var parent_dir := global_out.get_base_dir()
	if not parent_dir.is_empty() and not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)
	var f := FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"entries": entries}, "  "))
		f.close()


func _sort_leaderboard(entries: Array[Dictionary]) -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := int(a.get("score", 0))
		var sb := int(b.get("score", 0))
		if sa != sb:
			return sa > sb
		return str(a.get("achieved_at", "")) < str(b.get("achieved_at", ""))
	)


func _add_leaderboard_entry(p_name: String, p_score: int, p_nights_won: int, p_seed: int) -> void:
	var clean_name := p_name.strip_edges()
	var regex := RegEx.new()
	regex.compile("[^A-Za-z0-9_]")
	clean_name = regex.sub(clean_name, "", true)
	if clean_name.length() < 3:
		clean_name = "Player"
	elif clean_name.length() > 12:
		clean_name = clean_name.substr(0, 12)
	var tz := Time.get_time_zone_from_system()
	var bias_mins := int(tz.get("bias", 0))
	var sign_str := "+" if bias_mins >= 0 else "-"
	var abs_mins := absi(bias_mins)
	var tz_str := "%s%02d:%02d" % [sign_str, abs_mins / 60, abs_mins % 60]
	var iso_time := Time.get_datetime_string_from_system(false, false) + tz_str
	var entry := {
		"name": clean_name,
		"score": p_score,
		"nights_won": p_nights_won,
		"achieved_at": iso_time,
		"seed": p_seed
	}
	var list := _load_leaderboard()
	list.append(entry)
	_save_leaderboard(list)


func _show_leaderboard() -> void:
	var list := _load_leaderboard()
	var lines := "HẠNG   TÊN          ĐIỂM      ĐÊM THẮNG    THỜI GIAN\n"
	lines += "--------------------------------------------------------\n"
	if list.is_empty():
		lines += "Chưa có điểm nào được lưu.\n"
	else:
		for i in range(list.size()):
			var e: Dictionary = list[i]
			lines += "%-6d %-12s %-9d %-12d %s\n" % [
				i + 1,
				str(e.get("name", "Player")),
				int(e.get("score", 0)),
				int(e.get("nights_won", 0)),
				str(e.get("achieved_at", "")).substr(0, 19)
			]
	leaderboard_text.text = lines
	leaderboard_panel.visible = true


func _show_name_entry(p_score: int, p_nights_won: int) -> void:
	pending_score = p_score
	pending_nights_won = p_nights_won
	awaiting_name = true
	name_entry_dialog.visible = true


func _on_name_submitted() -> void:
	var p_name := name_input.text
	_add_leaderboard_entry(p_name, pending_score, pending_nights_won, round_seed)
	name_entry_dialog.visible = false
	awaiting_name = false
	_show_leaderboard()


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
	shade_state = "wander"
	shade_drain_lamp = -1
	shade_push_lamp = -1
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
	_add_island_decor()


func _add_island_decor() -> void:
	var decor_rng := RandomNumberGenerator.new()
	decor_rng.seed = 8200 + night
	var centers: Array[Vector3] = [Vector3.ZERO]
	if night == 2: centers.append(Vector3(70, 0, 0))
	var lamp_positions := _night_lantern_positions()
	for center in centers:
		for i in range(24):
			var angle := decor_rng.randf_range(0.0, TAU)
			var inner_radius := ground_radius * 0.5
			var outer_radius := ground_radius * 0.82
			if night == 2:
				inner_radius = 15.0
				outer_radius = 23.0
			var radius := decor_rng.randf_range(inner_radius, outer_radius)
			var pos := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			var near_lamp := false
			for lamp_pos in lamp_positions:
				if _flat_distance(pos, lamp_pos) < 5.0:
					near_lamp = true
					break
			if near_lamp or _flat_distance(pos, player.position) < 7.0: continue
			var kind := i % 4
			if kind == 0:
				_add_lowpoly_tree(pos, decor_rng.randf_range(3.2, 4.8), decor_rng)
			elif kind == 1:
				_add_lowpoly_rock(pos, decor_rng)
			else:
				_add_grass_cluster(pos, decor_rng)


func _add_lowpoly_tree(pos: Vector3, height: float, decor_rng: RandomNumberGenerator) -> void:
	var tree := Node3D.new()
	tree.position = pos
	tree.rotation.y = decor_rng.randf_range(0.0, TAU)
	map_root.add_child(tree)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.27
	trunk_mesh.height = height
	trunk_mesh.radial_segments = 6
	trunk.mesh = trunk_mesh
	trunk.position.y = height * 0.5
	trunk.material_override = _material(Color("76503b"), 0.0)
	tree.add_child(trunk)
	var foliage_colors := [Color("3d8266"), Color("4e956e"), Color("39745f")]
	for layer in range(3):
		var crown := MeshInstance3D.new()
		var crown_mesh := CylinderMesh.new()
		crown_mesh.top_radius = 0.0
		crown_mesh.bottom_radius = height * (0.22 - layer * 0.035)
		crown_mesh.height = height * 0.48
		crown_mesh.radial_segments = 7
		crown.mesh = crown_mesh
		crown.position.y = height * (0.58 + layer * 0.16)
		crown.material_override = _material(foliage_colors[layer], 0.0)
		tree.add_child(crown)


func _add_lowpoly_rock(pos: Vector3, decor_rng: RandomNumberGenerator) -> void:
	var rock := MeshInstance3D.new()
	var rock_mesh := SphereMesh.new()
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 4
	rock.mesh = rock_mesh
	rock.position = pos + Vector3(0, 0.25, 0)
	rock.scale = Vector3(decor_rng.randf_range(0.7, 1.6), decor_rng.randf_range(0.45, 0.9), decor_rng.randf_range(0.65, 1.35))
	rock.rotation.y = decor_rng.randf_range(0.0, TAU)
	rock.material_override = _material([Color("66746a"), Color("777a70"), Color("596b67")][decor_rng.randi_range(0, 2)], 0.0)
	map_root.add_child(rock)


func _add_grass_cluster(pos: Vector3, decor_rng: RandomNumberGenerator) -> void:
	var grass_colors := [Color("82a85f"), Color("b4a85c"), Color("5f9a72")]
	for blade in range(5):
		var tuft := MeshInstance3D.new()
		var blade_mesh := CylinderMesh.new()
		blade_mesh.top_radius = 0.0
		blade_mesh.bottom_radius = 0.09
		blade_mesh.height = decor_rng.randf_range(0.45, 0.9)
		blade_mesh.radial_segments = 5
		tuft.mesh = blade_mesh
		tuft.position = pos + Vector3(decor_rng.randf_range(-0.3, 0.3), blade_mesh.height * 0.5, decor_rng.randf_range(-0.3, 0.3))
		tuft.rotation.z = decor_rng.randf_range(-0.25, 0.25)
		tuft.material_override = _material(grass_colors[decor_rng.randi_range(0, grass_colors.size() - 1)], 0.0)
		map_root.add_child(tuft)


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
	var lantern_base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.34
	base_mesh.bottom_radius = 0.42
	base_mesh.height = 0.18
	base_mesh.radial_segments = 8
	lantern_base.mesh = base_mesh
	lantern_base.position.y = 2.28
	lantern_base.material_override = _material(Color("d39a51"), 0.0)
	root.add_child(lantern_base)
	for side in [-1.0, 1.0]:
		for forward in [-1.0, 1.0]:
			var cage_bar := MeshInstance3D.new()
			var bar_mesh := CylinderMesh.new()
			bar_mesh.top_radius = 0.025
			bar_mesh.bottom_radius = 0.035
			bar_mesh.height = 0.8
			bar_mesh.radial_segments = 5
			cage_bar.mesh = bar_mesh
			cage_bar.position = Vector3(side * 0.28, 2.69, forward * 0.28)
			cage_bar.material_override = _material(Color("d39a51"), 0.0)
			root.add_child(cage_bar)
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.38
	flame_mesh.height = 0.76
	flame.mesh = flame_mesh
	flame.position.y = 2.75
	flame.material_override = _material(Color("6d6271"), 0.0)
	root.add_child(flame)
	var lantern_roof := MeshInstance3D.new()
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.0
	roof_mesh.bottom_radius = 0.42
	roof_mesh.height = 0.32
	roof_mesh.radial_segments = 8
	lantern_roof.mesh = roof_mesh
	lantern_roof.position.y = 3.22
	lantern_roof.material_override = _material(Color("8c5840"), 0.0)
	root.add_child(lantern_roof)
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
	fuel_bar.position = Vector3(0, 3.78, 0)
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
	mesh.radial_segments = 8
	mesh.rings = 4
	orb.mesh = mesh
	orb.material_override = _material(Color("ffe783"), 2.0)
	node.add_child(orb)
	var crystal := MeshInstance3D.new()
	var crystal_mesh := CylinderMesh.new()
	crystal_mesh.top_radius = 0.0
	crystal_mesh.bottom_radius = 0.12
	crystal_mesh.height = 0.46
	crystal_mesh.radial_segments = 5
	crystal.mesh = crystal_mesh
	crystal.material_override = _material(Color("fff2ad"), 2.4)
	node.add_child(crystal)
	var halo := MeshInstance3D.new()
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 0.24
	halo_mesh.outer_radius = 0.29
	halo.mesh = halo_mesh
	halo.rotation.x = deg_to_rad(72.0)
	halo.material_override = _material(Color("f3c95f"), 1.2)
	node.add_child(halo)
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
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.1
		eye_mesh.height = 0.14
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.2, 0.16, -0.48)
		eye.material_override = _material(Color("ffe8ac"), 1.8)
		node.add_child(eye)
		var fin := MeshInstance3D.new()
		var fin_mesh := CylinderMesh.new()
		fin_mesh.top_radius = 0.0
		fin_mesh.bottom_radius = 0.22
		fin_mesh.height = 0.5
		fin_mesh.radial_segments = 5
		fin.mesh = fin_mesh
		fin.position = Vector3(side * 0.47, 0.12, 0.0)
		fin.rotation.z = deg_to_rad(side * -55.0)
		fin.material_override = _material(Color("71899f"), 0.45)
		node.add_child(fin)
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
	if key_rebind_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			var new_key: int = event.physical_keycode
			if new_key == KEY_NONE:
				new_key = event.keycode
			if new_key == KEY_ESCAPE:
				key_rebind_action = ""
				_refresh_keybind_buttons()
				keybind_alert.text = "Đã hủy đổi phím."
				return
			var conflict_act := ""
			for act in key_bindings:
				if act != key_rebind_action and key_bindings[act] == new_key:
					conflict_act = act
					break
			if conflict_act != "":
				keybind_alert.text = "⚠ Phím đã bị trùng với hành động khác!"
				return
			key_bindings[key_rebind_action] = new_key
			key_rebind_action = ""
			keybind_alert.text = "Đã đổi phím thành công!"
			_setup_inputs()
			_save_settings()
			_refresh_keybind_buttons()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_L and (game_state == "menu" or game_state == "paused"):
			_show_leaderboard()
			return

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
	if direction.length_squared() > 0.01:
		player.rotation.y = atan2(-direction.x, -direction.z)
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
		node.rotation.y = Time.get_ticks_msec() * 0.0007 + i
		if carried < mini(20, 10 + successful_lights * 2) and _flat_distance(player.position, mote["pos"]) <= 1.0 and absf(player.position.y - mote["pos"].y) <= 1.5:
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
		shade_state = "stunned"
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
	shade.rotation.y += delta * 0.55
	shade.get_child(0).position.y = 0.08 + sin(Time.get_ticks_msec() * 0.004) * 0.14
	shade.get_child(2).position.y = sin(Time.get_ticks_msec() * 0.004) * 0.1
	var outline: MeshInstance3D = shade.get_child(1)
	if bool(outline.get_meta("colorblind", false)) != colorblind_mode:
		outline.material_override = _material(Color("00b3ff") if colorblind_mode else Color("7a3cff"), 1.0)
		outline.set_meta("colorblind", colorblind_mode)
	if shade_stunned > 0:
		shade_state = "stunned"
		shade_drain_lamp = -1
		return
	if shade_state == "stunned": shade_state = "wander"
	if shade_push_lamp >= 0 and shade_push_lamp < lanterns.size():
		var pushed_lamp: Dictionary = lanterns[shade_push_lamp]
		var outward: Vector3 = shade.position - pushed_lamp["pos"]
		outward.y = 0
		if outward.length() < 6.0 and pushed_lamp["lit"] and float(pushed_lamp["fuel"]) >= 30.0:
			if outward.length_squared() < 0.001: outward = Vector3.RIGHT
			shade.position += outward.normalized() * 12.0 * delta
			return
		shade_push_lamp = -1
	var direction: Vector3 = player.position - shade.position
	direction.y = 0
	var distance := direction.length()
	if shade_state == "drain":
		var drain_index := shade_drain_lamp
		if drain_index < 0 or drain_index >= lanterns.size() or not lanterns[drain_index]["lit"] or float(lanterns[drain_index]["fuel"]) >= 30.0 or _flat_distance(shade.position, lanterns[drain_index]["pos"]) > 2.0:
			shade_state = "wander"
			shade_drain_lamp = -1
		elif distance <= 6.0:
			shade_state = "chase"
			shade_drain_lamp = -1
		else:
			lanterns[drain_index]["fuel"] = maxf(0.0, float(lanterns[drain_index]["fuel"]) - 5.0 * delta)
			return
	if shade_state == "chase" and distance > SHADE_LOSE_RADIUS: shade_state = "wander"
	if shade_state == "wander" and distance <= SHADE_DETECT_RADIUS: shade_state = "chase"
	if shade_state == "wander":
		shade_drain_lamp = -1
		var target_index := _nearest_shade_target(true)
		if target_index < 0: target_index = _nearest_shade_target(false)
		if target_index >= 0:
			var target_lamp: Dictionary = lanterns[target_index]
			var to_target: Vector3 = target_lamp["pos"] - shade.position
			to_target.y = 0
			if target_lamp["lit"] and float(target_lamp["fuel"]) < 30.0 and to_target.length() <= 2.0:
				shade_state = "drain"
				shade_drain_lamp = target_index
				return
			if to_target.length() > 2.0:
				shade.position += to_target.normalized() * SHADE_SPEED * delta
				return
	if shade_state == "chase" and direction.length_squared() > 0.01:
		for lantern in lanterns:
			if lantern["lit"] and float(lantern["fuel"]) >= 30.0 and _flat_distance(shade.position, lantern["pos"]) <= 6.0:
				return
		shade.position += direction.normalized() * (4.5 if night == 3 else SHADE_SPEED) * delta
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
		shade_state = "stunned"
		shade_drain_lamp = -1


func _nearest_shade_target(weak_only: bool) -> int:
	var best_index := -1
	var best_distance := INF
	for i in range(lanterns.size()):
		var lamp: Dictionary = lanterns[i]
		var eligible := bool(lamp["lit"]) and float(lamp["fuel"]) < 30.0 if weak_only else not bool(lamp["lit"])
		if not eligible: continue
		var distance := _flat_distance(shade.position, lamp["pos"])
		if distance < best_distance or (is_equal_approx(distance, best_distance) and (best_index < 0 or str(lamp["id"]) < str(lanterns[best_index]["id"]))):
			best_index = i
			best_distance = distance
	return best_index


func _check_end() -> void:
	if flames <= 0:
		game_state = "lost"
		_play_sfx("loss")
		result_label.text = "ĐÊM TỐI QUÁ!\nĐiểm: %d\nNhấn R để thử lại" % score
		if not awaiting_name:
			_show_name_entry(score + total_score, night - 1)
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
			if not awaiting_name:
				_show_name_entry(total_score + score, 3)
	else:
		game_state = "lost"
		_play_sfx("loss")
		result_label.text = "BÌNH MINH ĐÃ LÊN\nĐiểm: %d\nNhấn R để chơi lại" % score
		if not awaiting_name:
			_show_name_entry(score + total_score, night - 1)


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

	# Offscreen indicator for Shade
	if is_instance_valid(shade) and shade.visible:
		var d_shade := _flat_distance(player.position, shade.position)
		var delta_s: Vector3 = shade.position - player.position
		delta_s = delta_s.rotated(Vector3.UP, -camera_yaw)
		var s_idx := posmod(roundi(wrapf(rad_to_deg(atan2(delta_s.x, delta_s.z)), 0.0, 360.0) / 45.0), 8)
		var arrows := ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
		nearest_hint += " | Bóng Mực: %s %.0fm" % [arrows[s_idx], d_shade]

	# Subtitle / Visual accessibility banner
	if is_instance_valid(subtitle_banner):
		var alert_text := ""
		if wind_active or gust_warned:
			alert_text = "⚠ Cảnh báo: Gió mạnh đang nổi lên!"
		elif time_left <= 10.0 and time_left > 0.0:
			alert_text = "⚠ Bình minh sắp đến: 10 giây cuối!"
		else:
			for lamp in lanterns:
				if lamp["lit"] and float(lamp["fuel"]) < 30.0:
					alert_text = "⚠ Đèn %s sắp cạn dầu (<30)!" % str(lamp.get("id", ""))
					break
		if alert_text.is_empty() and is_instance_valid(shade) and _flat_distance(player.position, shade.position) <= 15.0:
			alert_text = "⚠ Cảnh báo: Bóng Mực đang ở gần!"
		subtitle_banner.text = alert_text

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
