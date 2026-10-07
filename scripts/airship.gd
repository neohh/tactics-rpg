extends Node3D

# Airship (Дирижабль) - Transport object with NFS Most Wanted flight physics
# Supports boarding the deck via ladder, walking on deck, and piloting at the helm.

enum State { GROUNDED, ON_DECK, PILOTING }

var current_state: int = State.GROUNDED
var terrain = null

# Physics & flight variables (NFS Most Wanted style)
var fwd_speed: float = 0.0
var max_fwd_speed: float = 16.0
var max_rev_speed: float = -5.0
var acceleration: float = 8.5
var brake_force: float = 12.0
var natural_drag: float = 2.2
var turn_rate: float = 1.35
var roll_rate: float = 0.22
var vertical_speed: float = 0.0
var max_vert_speed: float = 5.0

# Node references
var gondola_n: Node3D
var balloon_n: Node3D
var helm_n: Node3D
var ladder_n: Node3D
var props_left: Node3D
var props_right: Node3D
var prop_spin: float = 0.0

# Dimensions & offsets
const DECK_Y = 0.35
const HELM_LOCAL = Vector3(0.0, 0.35, -2.4)
const LADDER_TOP_LOCAL = Vector3(1.75, 0.35, 0.2)
const LADDER_BOTTOM_LOCAL = Vector3(2.1, -1.8, 0.2)
const DECK_MIN_X = -1.45
const DECK_MAX_X = 1.45
const DECK_MIN_Z = -3.2
const DECK_MAX_Z = 3.2

func _ready():
	_build_airship_model()

func _build_airship_model():
	# 1. Gondola / Deck (Ship's Hull)
	gondola_n = Node3D.new()
	gondola_n.name = "Gondola"
	add_child(gondola_n)

	# Main wooden deck
	var deck_mesh = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(3.4, 0.6, 7.2)
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.42, 0.26, 0.14) # Rich dark wood
	wood_mat.roughness = 0.75
	deck_mesh.mesh = bm
	deck_mesh.material_override = wood_mat
	deck_mesh.position = Vector3(0, 0, 0)
	gondola_n.add_child(deck_mesh)

	# Bow (Pointed front of the ship)
	var bow_mesh = MeshInstance3D.new()
	var pm = PrismMesh.new()
	pm.size = Vector3(3.4, 0.6, 2.2)
	bow_mesh.mesh = pm
	bow_mesh.material_override = wood_mat
	bow_mesh.rotation = Vector3(0, PI, 0)
	bow_mesh.position = Vector3(0, 0, -4.7)
	gondola_n.add_child(bow_mesh)

	# Deck Floor (planks)
	var floor_m = MeshInstance3D.new()
	var fbm = BoxMesh.new()
	fbm.size = Vector3(3.2, 0.05, 8.2)
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.55, 0.38, 0.22) # Lighter plank floor
	floor_m.mesh = fbm
	floor_m.material_override = floor_mat
	floor_m.position = Vector3(0, DECK_Y, -0.6)
	gondola_n.add_child(floor_m)

	# Railings around the deck
	var rail_mat = StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.28, 0.17, 0.09)
	for side in [-1.0, 1.0]:
		var rail = MeshInstance3D.new()
		var rbm = BoxMesh.new()
		rbm.size = Vector3(0.12, 0.65, 7.8)
		rail.mesh = rbm
		rail.material_override = rail_mat
		rail.position = Vector3(side * 1.62, DECK_Y + 0.32, -0.6)
		gondola_n.add_child(rail)

	# Stern railing (back)
	var stern_rail = MeshInstance3D.new()
	var srbm = BoxMesh.new()
	srbm.size = Vector3(3.3, 0.65, 0.12)
	stern_rail.mesh = srbm
	stern_rail.material_override = rail_mat
	stern_rail.position = Vector3(0, DECK_Y + 0.32, 3.4)
	gondola_n.add_child(stern_rail)

	# Helm (Штурвал) at the front
	helm_n = Node3D.new()
	helm_n.name = "Helm"
	helm_n.position = HELM_LOCAL
	gondola_n.add_child(helm_n)

	var helm_post = MeshInstance3D.new()
	var hcm = CylinderMesh.new()
	hcm.top_radius = 0.08
	hcm.bottom_radius = 0.12
	hcm.height = 0.8
	var brass_mat = StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.85, 0.68, 0.28) # Polished brass
	brass_mat.metallic = 0.85
	brass_mat.roughness = 0.25
	helm_post.mesh = hcm
	helm_post.material_override = brass_mat
	helm_post.position = Vector3(0, 0.4, 0)
	helm_n.add_child(helm_post)

	var wheel = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.28
	tm.outer_radius = 0.38
	wheel.mesh = tm
	wheel.material_override = brass_mat
	wheel.rotation = Vector3(PI * 0.4, 0, 0)
	wheel.position = Vector3(0, 0.8, 0.1)
	helm_n.add_child(wheel)

	# Ladders / Boarding ramps on starboard and port sides
	for side in [1.0, -1.0]:
		var lad = Node3D.new()
		lad.name = "Ladder_" + ("Starboard" if side > 0 else "Port")
		lad.position = Vector3(side * 1.75, DECK_Y, 0.2)
		gondola_n.add_child(lad)

		var ladder_mesh = MeshInstance3D.new()
		var lbm = BoxMesh.new()
		lbm.size = Vector3(0.5, 2.2, 0.08)
		var lad_mat = StandardMaterial3D.new()
		lad_mat.albedo_color = Color(0.35, 0.22, 0.12)
		ladder_mesh.mesh = lbm
		ladder_mesh.material_override = lad_mat
		ladder_mesh.position = Vector3(side * 0.15, -0.9, 0)
		ladder_mesh.rotation = Vector3(0, 0, -side * 0.15)
		lad.add_child(ladder_mesh)

	# 2. Engines & Propellers on the sides
	var engine_mat = StandardMaterial3D.new()
	engine_mat.albedo_color = Color(0.3, 0.32, 0.36)
	engine_mat.metallic = 0.7
	engine_mat.roughness = 0.4

	props_left = Node3D.new()
	props_left.position = Vector3(-2.1, 0.1, 2.0)
	gondola_n.add_child(props_left)

	props_right = Node3D.new()
	props_right.position = Vector3(2.1, 0.1, 2.0)
	gondola_n.add_child(props_right)

	for p_root in [props_left, props_right]:
		# Engine nacelle
		var nacelle = MeshInstance3D.new()
		var ncm = CylinderMesh.new()
		ncm.top_radius = 0.35
		ncm.bottom_radius = 0.35
		ncm.height = 1.4
		nacelle.mesh = ncm
		nacelle.material_override = engine_mat
		nacelle.rotation = Vector3(PI * 0.5, 0, 0)
		p_root.add_child(nacelle)

		# Propeller hub and blades
		var prop_hub = Node3D.new()
		prop_hub.name = "PropHub"
		prop_hub.position = Vector3(0, 0, 0.8)
		p_root.add_child(prop_hub)

		var blade1 = MeshInstance3D.new()
		var bbm = BoxMesh.new()
		bbm.size = Vector3(1.2, 0.1, 0.02)
		blade1.mesh = bbm
		blade1.material_override = brass_mat
		prop_hub.add_child(blade1)

		var blade2 = MeshInstance3D.new()
		blade2.mesh = bbm
		blade2.material_override = brass_mat
		blade2.rotation = Vector3(0, 0, PI * 0.5)
		prop_hub.add_child(blade2)

	# 3. Gasbag Balloon (Вытянутый шар / дирижабль)
	balloon_n = Node3D.new()
	balloon_n.name = "Balloon"
	balloon_n.position = Vector3(0, 4.4, -0.4)
	add_child(balloon_n)

	var gasbag = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 2.4
	sm.height = 4.8
	var bag_mat = StandardMaterial3D.new()
	bag_mat.albedo_color = Color(0.86, 0.82, 0.72) # Canvas cream / beige
	bag_mat.roughness = 0.85
	gasbag.mesh = sm
	gasbag.material_override = bag_mat
	gasbag.scale = Vector3(1.0, 0.85, 2.6) # Stretched Zeppelin ellipsoid
	balloon_n.add_child(gasbag)

	# Tail fins (Rudders at the back)
	var fin_mat = StandardMaterial3D.new()
	fin_mat.albedo_color = Color(0.65, 0.22, 0.18) # Crimson tail fins
	for rot in [0.0, PI * 0.5, PI, PI * 1.5]:
		var fin = MeshInstance3D.new()
		var f_mesh = BoxMesh.new()
		f_mesh.size = Vector3(0.08, 1.6, 2.2)
		fin.mesh = f_mesh
		fin.material_override = fin_mat
		fin.rotation = Vector3(0, 0, rot)
		fin.position = Vector3(sin(rot) * 2.2, cos(rot) * 2.2, 5.0)
		balloon_n.add_child(fin)

	# Rigging Cables (connecting balloon to gondola)
	var cable_mat = StandardMaterial3D.new()
	cable_mat.albedo_color = Color(0.18, 0.18, 0.2)
	for cx in [-1.5, 1.5]:
		for cz in [-3.0, 2.5]:
			var cable = MeshInstance3D.new()
			var c_mesh = CylinderMesh.new()
			c_mesh.top_radius = 0.02
			c_mesh.bottom_radius = 0.02
			c_mesh.height = 3.8
			cable.mesh = c_mesh
			cable.material_override = cable_mat
			cable.position = Vector3(cx * 0.85, 2.1, cz * 0.9)
			cable.rotation = Vector3(cz * 0.02, 0, cx * -0.05)
			add_child(cable)

func get_ladder_bottom_pos(ref_pos: Vector3 = Vector3.ZERO) -> Vector3:
	var b_star = to_global(Vector3(2.1, -1.8, 0.2))
	var b_port = to_global(Vector3(-2.1, -1.8, 0.2))
	if ref_pos == Vector3.ZERO:
		return b_port # default to port (facing spawn)
	return b_star if ref_pos.distance_to(b_star) < ref_pos.distance_to(b_port) else b_port

func get_ladder_top_pos(ref_pos: Vector3 = Vector3.ZERO) -> Vector3:
	var t_star = to_global(Vector3(1.75, DECK_Y, 0.2))
	var t_port = to_global(Vector3(-1.75, DECK_Y, 0.2))
	if ref_pos == Vector3.ZERO:
		return t_port
	return t_star if ref_pos.distance_to(t_star) < ref_pos.distance_to(t_port) else t_port

func get_helm_pos() -> Vector3:
	return to_global(HELM_LOCAL)

func to_deck_local(world_pos: Vector3) -> Vector3:
	return to_local(world_pos)

func from_deck_local(local_pos: Vector3) -> Vector3:
	return to_global(local_pos)

func get_speed_kmh() -> float:
	return abs(fwd_speed) * 3.6

func get_altitude() -> float:
	var ground_h = 0.0
	if terrain != null and terrain.has_method("sample_h"):
		ground_h = terrain.sample_h(global_position.x, global_position.z)
	return maxf(0.0, global_position.y - ground_h - 1.8)


# NFS Most Wanted style flight physics update
func process_flight(d: float):
	if current_state != State.PILOTING:
		# Idle glide / settle
		fwd_speed = move_toward(fwd_speed, 0.0, natural_drag * d)
		vertical_speed = move_toward(vertical_speed, 0.0, natural_drag * d)
		rotation.z = move_toward(rotation.z, 0.0, d * 1.5)
		rotation.x = move_toward(rotation.x, 0.0, d * 1.5)
		_spin_props(d, 2.0)
		return

	# Input gathering
	var throttle_in = 0.0
	if Input.is_key_pressed(KEY_W):
		throttle_in += 1.0 # Gas
	if Input.is_key_pressed(KEY_S):
		throttle_in -= 1.0 # Brake / Reverse

	var steer_in = 0.0
	if Input.is_key_pressed(KEY_A):
		steer_in += 1.0 # Steer left
	if Input.is_key_pressed(KEY_D):
		steer_in -= 1.0 # Steer right

	var vert_in = 0.0
	if Input.is_key_pressed(KEY_SPACE):
		vert_in += 1.0 # Climb up
	if Input.is_key_pressed(KEY_SHIFT):
		vert_in -= 1.0 # Descend down

	# 1. Forward / Reverse Acceleration (NFS feel: punchy throttle and responsive braking)
	if throttle_in > 0.0:
		fwd_speed = move_toward(fwd_speed, max_fwd_speed, acceleration * d)
	elif throttle_in < 0.0:
		if fwd_speed > 0.5:
			fwd_speed = move_toward(fwd_speed, 0.0, brake_force * d) # Heavy brake
		else:
			fwd_speed = move_toward(fwd_speed, max_rev_speed, acceleration * 0.7 * d) # Reverse
	else:
		fwd_speed = move_toward(fwd_speed, 0.0, natural_drag * d)

	# 2. Steering & Banking (NFS feel: car leans into turns)
	var speed_factor = clampf(abs(fwd_speed) / 6.0, 0.35, 1.2)
	var turn_delta = steer_in * turn_rate * speed_factor * d
	rotation.y += turn_delta

	# Dynamic roll (bank into the curve)
	var target_roll = -steer_in * 0.16 * clampf(abs(fwd_speed) / 8.0, 0.2, 1.0)
	rotation.z = lerpf(rotation.z, target_roll, d * 3.5)

	# 3. Vertical Climb / Descend
	if vert_in != 0.0:
		vertical_speed = move_toward(vertical_speed, vert_in * max_vert_speed, acceleration * 1.2 * d)
	else:
		vertical_speed = move_toward(vertical_speed, 0.0, natural_drag * 1.5 * d)

	# Dynamic pitch (tilt nose up on climb, down on descend)
	var target_pitch = clampf(vertical_speed * 0.04, -0.15, 0.15)
	rotation.x = lerpf(rotation.x, -target_pitch, d * 3.0)

	# 4. Movement execution
	var forward_vec = -global_transform.basis.z
	var move_vec = forward_vec * fwd_speed + Vector3.UP * vertical_speed
	global_position += move_vec * d

	# 5. Terrain clearance check
	var ground_h = 0.0
	if terrain != null and terrain.has_method("sample_h"):
		ground_h = terrain.sample_h(global_position.x, global_position.z)
	var min_flight_y = ground_h + 1.8
	if global_position.y < min_flight_y:
		global_position.y = min_flight_y
		vertical_speed = maxf(0.0, vertical_speed)

	# 6. Propeller animation
	var prop_rpm = 6.0 + abs(fwd_speed) * 3.5
	_spin_props(d, prop_rpm)

func _spin_props(d: float, rpm: float):
	prop_spin += rpm * d * 8.0
	for pr in [props_left, props_right]:
		if pr != null:
			var hub = pr.get_node_or_null("PropHub")
			if hub != null:
				hub.rotation.z = prop_spin
