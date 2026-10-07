class_name CliffBridge
extends Node

# CliffBridge: Rocky cliffs, stepped ascending columns, and traversable bridge (top & underpass)
# For bandit_road and other elevated locations.

const HILL1_CELLS = [
	Vector2i(7, 4), Vector2i(7, 5), Vector2i(7, 6),
	Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6)
]

const HILL2_CELLS = [
	Vector2i(11, 4), Vector2i(11, 5), Vector2i(11, 6),
	Vector2i(12, 4), Vector2i(12, 5), Vector2i(12, 6)
]

const BRIDGE_CELLS = [
	Vector2i(9, 5), Vector2i(10, 5)
]

const STEPPED_COLUMNS = {
	Vector2i(6, 4): 0.8,
	Vector2i(6, 5): 1.6,
	Vector2i(13, 6): 1.6,
	Vector2i(13, 7): 0.8
}

const HILL_HEIGHT = 2.4
const BRIDGE_HEIGHT = 2.4

static func is_hill1_cell(c: Vector2i) -> bool:
	return HILL1_CELLS.has(c)

static func is_hill2_cell(c: Vector2i) -> bool:
	return HILL2_CELLS.has(c)

static func is_hill_cell(c: Vector2i) -> bool:
	return is_hill1_cell(c) or is_hill2_cell(c)

static func is_bridge_cell(c: Vector2i) -> bool:
	return BRIDGE_CELLS.has(c)

static func is_column_cell(c: Vector2i) -> bool:
	return STEPPED_COLUMNS.has(c)

# Get target surface height at world coordinates given current entity Y
static func get_surface_y(x: float, z: float, cur_y: float, terrain: Node = null) -> float:
	var gh = terrain.sample_h(x, z) if terrain != null and terrain.has_method("sample_h") else 0.0
	var c = Vector2i(int(floor(x)), int(floor(z)))

	# 1. Bridge span
	if is_bridge_cell(c):
		# If entity is on bridge level (above 1.2m), walk on deck
		if cur_y >= gh + 1.2:
			return gh + BRIDGE_HEIGHT
		else:
			# Otherwise walk underneath on ground
			return gh

	# 2. Hill cliffs
	if is_hill_cell(c):
		return gh + HILL_HEIGHT

	# 3. Stepped columns
	if STEPPED_COLUMNS.has(c):
		return gh + STEPPED_COLUMNS[c]

	# 4. Ground terrain
	return gh

# Check if vertical step from current surface to target surface is passable
static func can_step_height(from_x: float, from_z: float, to_x: float, to_z: float, cur_y: float, terrain: Node = null) -> bool:
	var from_surf = get_surface_y(from_x, from_z, cur_y, terrain)
	var to_surf = get_surface_y(to_x, to_z, cur_y, terrain)
	var diff = to_surf - from_surf
	# Upward step allowed up to 0.85m (allows stepping onto columns)
	if diff > 0.85:
		return false
	# Downward drop allowed up to 3.0m
	if diff < -3.0:
		return false
	return true

# Build 3D visual structures in the scene
static func build_3d(parent: Node, terrain: Node = null) -> Node3D:
	var root = Node3D.new()
	root.name = "CliffBridgeFeatures"
	parent.add_child(root)

	# Materials
	var rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.38, 0.36, 0.34) # Rugged mountain granite
	rock_mat.roughness = 0.85

	var plateau_mat = StandardMaterial3D.new()
	plateau_mat.albedo_color = Color(0.44, 0.42, 0.38) # Weathered stone ledge
	plateau_mat.roughness = 0.8

	var wood_deck_mat = StandardMaterial3D.new()
	wood_deck_mat.albedo_color = Color(0.48, 0.32, 0.18) # Sturdy wooden bridge planks
	wood_deck_mat.roughness = 0.75

	var wood_rail_mat = StandardMaterial3D.new()
	wood_rail_mat.albedo_color = Color(0.30, 0.20, 0.12) # Dark timber railings
	wood_rail_mat.roughness = 0.7

	var col_mat = StandardMaterial3D.new()
	col_mat.albedo_color = Color(0.42, 0.40, 0.38) # Natural rock column
	col_mat.roughness = 0.82

	# 1. Build Hill 1 & Hill 2 (Rock plateaus)
	for c in HILL1_CELLS + HILL2_CELLS:
		var gh = terrain.sample_h(c.x + 0.5, c.y + 0.5) if terrain != null and terrain.has_method("sample_h") else 0.0
		var h = HILL_HEIGHT
		
		# Rock body
		var m = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(1.0, h, 1.0)
		m.mesh = bm
		m.material_override = rock_mat
		m.position = Vector3(c.x + 0.5, gh + h * 0.5, c.y + 0.5)
		root.add_child(m)

		# Top slab highlight
		var slab = MeshInstance3D.new()
		var sbm = BoxMesh.new()
		sbm.size = Vector3(0.96, 0.08, 0.96)
		slab.mesh = sbm
		slab.material_override = plateau_mat
		slab.position = Vector3(c.x + 0.5, gh + h + 0.04, c.y + 0.5)
		root.add_child(slab)

	# 2. Build Stepped Ascending Columns
	for c in STEPPED_COLUMNS:
		var ch = STEPPED_COLUMNS[c]
		var gh = terrain.sample_h(c.x + 0.5, c.y + 0.5) if terrain != null and terrain.has_method("sample_h") else 0.0
		
		# Stepped rock column pillar
		var col_m = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.44
		cm.bottom_radius = 0.48
		cm.height = ch
		cm.radial_segments = 8 # Faceted basalt-style rock pillar
		col_m.mesh = cm
		col_m.material_override = col_mat
		col_m.position = Vector3(c.x + 0.5, gh + ch * 0.5, c.y + 0.5)
		root.add_child(col_m)

		# Top step cap
		var cap = MeshInstance3D.new()
		var cap_m = CylinderMesh.new()
		cap_m.top_radius = 0.46
		cap_m.bottom_radius = 0.46
		cap_m.height = 0.08
		cap_m.radial_segments = 8
		cap.mesh = cap_m
		cap.material_override = plateau_mat
		cap.position = Vector3(c.x + 0.5, gh + ch + 0.04, c.y + 0.5)
		root.add_child(cap)

	# 3. Build Bridge across canyon
	var b_gh = terrain.sample_h(9.5, 5.5) if terrain != null and terrain.has_method("sample_h") else 0.0
	var bridge_y = b_gh + BRIDGE_HEIGHT

	# Stone Support Piers at left & right cliff edges
	for px in [8.9, 10.1]:
		var pier = MeshInstance3D.new()
		var p_bm = BoxMesh.new()
		p_bm.size = Vector3(0.24, BRIDGE_HEIGHT, 1.0)
		pier.mesh = p_bm
		pier.material_override = rock_mat
		pier.position = Vector3(px, b_gh + BRIDGE_HEIGHT * 0.5, 5.5)
		root.add_child(pier)

	# Main Bridge Deck (planks)
	var deck = MeshInstance3D.new()
	var d_bm = BoxMesh.new()
	d_bm.size = Vector3(2.2, 0.12, 1.05)
	deck.mesh = d_bm
	deck.material_override = wood_deck_mat
	deck.position = Vector3(9.5, bridge_y - 0.06, 5.5)
	root.add_child(deck)

	# Crossbeams under deck
	for bx in [8.8, 9.2, 9.5, 9.8, 10.2]:
		var beam = MeshInstance3D.new()
		var b_m = BoxMesh.new()
		b_m.size = Vector3(0.12, 0.15, 1.15)
		beam.mesh = b_m
		beam.material_override = wood_rail_mat
		beam.position = Vector3(bx, bridge_y - 0.18, 5.5)
		root.add_child(beam)

	# Wooden Railings (North and South)
	for rz in [4.95, 6.05]:
		# Handrail
		var rail = MeshInstance3D.new()
		var r_bm = BoxMesh.new()
		r_bm.size = Vector3(2.2, 0.08, 0.08)
		rail.mesh = r_bm
		rail.material_override = wood_rail_mat
		rail.position = Vector3(9.5, bridge_y + 0.5, rz)
		root.add_child(rail)

		# Vertical Balusters / Posts
		for post_x in [8.6, 9.05, 9.5, 9.95, 10.4]:
			var post = MeshInstance3D.new()
			var p_mesh = BoxMesh.new()
			p_mesh.size = Vector3(0.08, 0.52, 0.08)
			post.mesh = p_mesh
			post.material_override = wood_rail_mat
			post.position = Vector3(post_x, bridge_y + 0.26, rz)
			root.add_child(post)

	return root

# Setup elevations and climb paths for world3d turn-based combat
static func setup_for_combat(w3d: Node):
	if w3d == null:
		return

	# 1. Register Hill elevations in ELEV
	for c in HILL1_CELLS + HILL2_CELLS:
		var k = str(c.x) + "," + str(c.y)
		w3d.ELEV[k] = HILL_HEIGHT

	# 2. Register Stepped Columns in ELEV
	for c in STEPPED_COLUMNS:
		var k = str(c.x) + "," + str(c.y)
		w3d.ELEV[k] = STEPPED_COLUMNS[c]

	# 3. Register Bridge cells in ELEV
	for c in BRIDGE_CELLS:
		var k = str(c.x) + "," + str(c.y)
		w3d.ELEV[k] = BRIDGE_HEIGHT

	# 4. Register Climb connections in climb
	# West Ascent:
	_add_climb_pair(w3d, Vector2i(6, 3), Vector2i(6, 4)) # ground -> col 1
	_add_climb_pair(w3d, Vector2i(6, 4), Vector2i(6, 5)) # col 1 -> col 2
	_add_climb_pair(w3d, Vector2i(6, 5), Vector2i(7, 5)) # col 2 -> Hill 1

	# East Descent:
	_add_climb_pair(w3d, Vector2i(12, 6), Vector2i(13, 6)) # Hill 2 -> col 3
	_add_climb_pair(w3d, Vector2i(13, 6), Vector2i(13, 7)) # col 3 -> col 4
	_add_climb_pair(w3d, Vector2i(13, 7), Vector2i(13, 8)) # col 4 -> ground

	# Bridge span connections (on top):
	_add_climb_pair(w3d, Vector2i(8, 5), Vector2i(9, 5)) # Hill 1 -> Bridge
	_add_climb_pair(w3d, Vector2i(9, 5), Vector2i(10, 5)) # Bridge span
	_add_climb_pair(w3d, Vector2i(10, 5), Vector2i(11, 5)) # Bridge -> Hill 2

	# Underpass connections (underneath):
	_add_climb_pair(w3d, Vector2i(9, 4), Vector2i(9, 5)) # North ground -> under bridge
	_add_climb_pair(w3d, Vector2i(9, 5), Vector2i(9, 6)) # under bridge -> South ground
	_add_climb_pair(w3d, Vector2i(10, 4), Vector2i(10, 5)) # North ground -> under bridge
	_add_climb_pair(w3d, Vector2i(10, 5), Vector2i(10, 6)) # under bridge -> South ground

	# 5. Build 3D visuals
	build_3d(w3d, w3d.terrain)

static func _add_climb_pair(w3d: Node, a: Vector2i, b: Vector2i):
	w3d.climb[str(a.x) + "," + str(a.y) + "->" + str(b.x) + "," + str(b.y)] = true
	w3d.climb[str(b.x) + "," + str(b.y) + "->" + str(a.x) + "," + str(a.y)] = true

# Combat movement validation for bridge & multi-height
static func combat_can_step(a: Vector2i, b: Vector2i, cur_unit_y: float) -> bool:
	# If stepping on/across bridge
	if is_bridge_cell(a) or is_bridge_cell(b):
		var on_top = cur_unit_y > 1.2
		if on_top:
			# On top: can step along bridge row Y = 5 between X = 8, 9, 10, 11
			if (a.y == 5 and b.y == 5) and abs(a.x - b.x) == 1:
				return true
			return false
		else:
			# Underneath: can step along underpass columns X = 9 and X = 10 between Y = 4, 5, 6
			if (a.x == b.x) and (a.x == 9 or a.x == 10) and abs(a.y - b.y) == 1:
				return true
			return false
	return true
