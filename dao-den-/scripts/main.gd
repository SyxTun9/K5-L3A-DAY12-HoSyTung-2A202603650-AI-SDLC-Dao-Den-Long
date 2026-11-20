extends Node3D

const ISLAND_RADIUS := 30.0
const LANTERN_POSITIONS := [
	Vector3(0, 0, 23), Vector3(21.85, 0, 7.1), Vector3(13.5, 0, -18.6),
	Vector3(-13.5, 0, -18.6), Vector3(-21.85, 0, 7.1)
]

var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var game_camera: Camera3D
var shade: Node3D
var hud: Label
var result_label: Label
var lanterns: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var flames := 3
var carried := 0
var score := 0
var time_left := 300.0
var invulnerable := 0.0
var pulse_cooldown := 0.0
var shade_stunned := 0.0
var game_state := "playing"
var camera_yaw := 0.0
var camera_pitch := 1.27


func _ready() -> void:
	rng.randomize()
	_setup_inputs()
	_build_world()
	_start_round()


func _setup_inputs() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("interact", KEY_E)
	_add_key_action("pulse", KEY_Q)
	_add_key_action("restart", KEY_R)


func _add_key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101226")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("77718f")
	env.ambient_light_energy = 0.55
	environment.environment = env
	add_child(environment)

	var moonlight := DirectionalLight3D.new()
	moonlight.rotation_degrees = Vector3(-55, -25, 0)
	moonlight.light_color = Color("a8a4d8")
	moonlight.light_energy = 0.65
	add_child(moonlight)

	var island := MeshInstance3D.new()
	var island_mesh := CylinderMesh.new()
	island_mesh.top_radius = ISLAND_RADIUS
	island_mesh.bottom_radius = ISLAND_RADIUS + 1.0
	island_mesh.height = 2.0
	island_mesh.radial_segments = 64
	island.mesh = island_mesh
	island.position.y = -1.0
	island.material_override = _material(Color("334b55"), 0.0)
	add_child(island)
	var island_body := StaticBody3D.new()
	var island_collision := CollisionShape3D.new()
	var island_shape := CylinderShape3D.new()
	island_shape.radius = ISLAND_RADIUS
	island_shape.height = 2.0
	island_collision.shape = island_shape
	island_collision.position.y = -1.0
	island_body.add_child(island_collision)
	add_child(island_body)

	var rim := MeshInstance3D.new()
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = ISLAND_RADIUS - 0.6
	rim_mesh.outer_radius = ISLAND_RADIUS + 0.3
	rim_mesh.rings = 64
	rim_mesh.ring_segments = 12
	rim.mesh = rim_mesh
	rim.position.y = -0.25
	rim.material_override = _material(Color("466f78"), 0.1)
	add_child(rim)

	var water := MeshInstance3D.new()
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(180, 180)
	water.mesh = water_mesh
	water.position.y = -3.2
	water.material_override = _material(Color("111b36"), 0.0)
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
	player.position = Vector3(0, 0.05, 0)
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


func _start_round() -> void:
	for lantern in lanterns:
		if is_instance_valid(lantern.get("node")):
			lantern["node"].queue_free()
	for mote in motes:
		if is_instance_valid(mote.get("node")):
			mote["node"].queue_free()
	lanterns.clear()
	for i in range(LANTERN_POSITIONS.size()):
		lanterns.append({
			"id": "L%d" % (i + 1), "pos": LANTERN_POSITIONS[i],
			"deposited": 0, "lit": false, "node": _make_lantern(i)
		})

	motes.clear()
	for i in range(36):
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(4.0, 25.0)
		var pos := Vector3(cos(angle) * radius, 0.45, sin(angle) * radius)
		motes.append({"id": "M%d" % (i + 1), "pos": pos, "node": _make_mote(pos)})

	player.position = Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	shade.position = Vector3(12, 0.7, 12)
	flames = 3
	carried = 0
	score = 0
	time_left = 300.0
	invulnerable = 0.0
	pulse_cooldown = 0.0
	shade_stunned = 0.0
	game_state = "playing"
	result_label.text = ""
	_update_hud()


func _make_lantern(index: int) -> Node3D:
	var root := Node3D.new()
	root.position = LANTERN_POSITIONS[index]
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
	root.set_meta("flame", flame)
	root.set_meta("light", light)
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
		camera_yaw -= event.relative.x * 0.004
		camera_pitch = clampf(camera_pitch - event.relative.y * 0.0025, 0.95, 1.4)
		_aim_camera()


func _physics_process(delta: float) -> void:
	if game_state != "playing":
		if Input.is_action_just_pressed("restart"):
			_start_round()
		return

	time_left = maxf(0.0, time_left - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
	shade_stunned = maxf(0.0, shade_stunned - delta)
	_move_player(delta)
	_aim_camera()
	_update_motes(delta)
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
	player.velocity.x = direction.x * 6.0
	player.velocity.z = direction.z * 6.0
	if not player.is_on_floor():
		player.velocity.y -= 22.0 * delta
	else:
		player.velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			player.velocity.y = 7.0
	player.move_and_slide()
	var flat_position := Vector3(player.position.x, 0, player.position.z)
	if flat_position.length() > ISLAND_RADIUS - 0.6:
		var flat := flat_position.normalized()
		player.position.x = flat.x * (ISLAND_RADIUS - 0.6)
		player.position.z = flat.z * (ISLAND_RADIUS - 0.6)


func _aim_camera() -> void:
	if is_instance_valid(game_camera) and is_instance_valid(player):
		var distance := 24.0
		var horizontal := cos(camera_pitch) * distance
		var vertical := sin(camera_pitch) * distance
		var offset := Vector3(0, vertical, -horizontal).rotated(Vector3.UP, camera_yaw)
		game_camera.global_position = player.global_position + offset
		game_camera.look_at(player.global_position + Vector3(0, 0.9, 0), Vector3.UP)


func _update_motes(delta: float) -> void:
	for i in range(motes.size() - 1, -1, -1):
		var mote: Dictionary = motes[i]
		var node: Node3D = mote["node"]
		node.position.y = 0.45 + sin(Time.get_ticks_msec() * 0.002 + i) * 0.12
		if carried < 10 and _flat_distance(player.position, mote["pos"]) <= 1.5:
			carried += 1
			score += 10
			node.queue_free()
			motes.remove_at(i)


func _interact_lantern() -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	var nearest_index := -1
	var nearest_distance := INF
	for i in range(lanterns.size()):
		if lanterns[i]["lit"]:
			continue
		var d: float = _flat_distance(player.position, lanterns[i]["pos"])
		if d < nearest_distance:
			nearest_distance = d
			nearest_index = i
	if nearest_index < 0 or nearest_distance > 2.5 or carried <= 0:
		return
	var lantern: Dictionary = lanterns[nearest_index]
	var amount := mini(5 - int(lantern["deposited"]), carried)
	carried -= amount
	lantern["deposited"] += amount
	if int(lantern["deposited"]) >= 5:
		lantern["lit"] = true
		score += 100
		var root: Node3D = lantern["node"]
		var flame: MeshInstance3D = root.get_meta("flame")
		var light: OmniLight3D = root.get_meta("light")
		flame.material_override = _material(Color("ffca5e"), 2.2)
		light.light_energy = 2.4


func _try_pulse() -> void:
	if not Input.is_action_just_pressed("pulse") or pulse_cooldown > 0 or carried < 1:
		return
	carried -= 1
	pulse_cooldown = 1.0
	if _flat_distance(player.position, shade.position) <= 8.0:
		shade_stunned = 2.0
		var away := shade.position - player.position
		away.y = 0
		if away.length_squared() > 0:
			shade.position += away.normalized() * 3.0
		score += 5
		shade.get_child(0).material_override = _material(Color("8062a0"), 1.1)
	else:
		shade.get_child(0).material_override = _material(Color("241a3a"), 0.2)


func _update_shade(delta: float) -> void:
	if shade_stunned > 0:
		return
	for lantern in lanterns:
		if lantern["lit"] and _flat_distance(shade.position, lantern["pos"]) <= 3.0:
			return
	var direction: Vector3 = player.position - shade.position
	direction.y = 0
	if direction.length_squared() > 0.01:
		shade.position += direction.normalized() * 2.5 * delta
	if invulnerable <= 0 and _flat_distance(player.position, shade.position) <= 1.2:
		flames -= 1
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
	var all_lit := true
	for lantern in lanterns:
		if not lantern["lit"]:
			all_lit = false
			break
	if all_lit:
		game_state = "won"
		score += floori(time_left) + flames * 25
		result_label.text = "ĐẢO SÁNG RỒI!\nĐiểm: %d\nNhấn R để chơi lại" % score
	elif flames <= 0:
		game_state = "lost"
		result_label.text = "ĐÊM TỐI QUÁ!\nĐiểm: %d\nNhấn R để chơi lại" % score
	elif time_left <= 0:
		game_state = "lost"
		result_label.text = "BÌNH MINH ĐÃ LÊN\nĐiểm: %d\nNhấn R để chơi lại" % score


func _update_hud() -> void:
	var lit_count := 0
	for lantern in lanterns:
		if lantern["lit"]:
			lit_count += 1
	hud.text = "ĐÊM 1 — ĐẢO BẾN\nĐom đóm: %d / 10     Đèn: %d / 5\nLửa: %s     Điểm: %d     Còn: %s\nWASD di chuyển · Space nhảy · E thắp đèn · Q tỏa sáng · Giữ chuột phải để xoay camera" % [carried, lit_count, "✦ ".repeat(maxi(flames, 0)), score, _format_time(time_left)]


func _format_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%02d:%02d" % [total / 60, total % 60]


func _flat_distance(a: Vector3, b: Vector3) -> float:
	var delta := a - b
	delta.y = 0
	return delta.length()
