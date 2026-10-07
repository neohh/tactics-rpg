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
	# Downward drop allowed up to 0.85m (allows stepping down columns, blocks jumping off 2.4m cliffs)
	if diff < -0.85:
		return false
	return true

# Raycast from camera to detect elevated surfaces (hills, columns, bridge)
static func raycast_surface(from: Vector3, dir: Vector3, terrain: Node = null) -> Variant:
	if abs(dir.y) < 0.0001:
		return null

	var best_t = INF
	var best_pt = null

	var surfaces = [
		{"y": HILL_HEIGHT, "min_x": 7.0, "max_x": 9.0, "min_z": 4.0, "max_z": 7.0},
		{"y": HILL_HEIGHT, "min_x": 11.0, "max_x": 13.0, "min_z": 4.0, "max_z": 7.0},
		{"y": BRIDGE_HEIGHT, "min_x": 8.8, "max_x": 11.2, "min_z": 4.8, "max_z": 6.2},
		{"y": 0.8, "min_x": 6.0, "max_x": 7.0, "min_z": 4.0, "max_z": 5.0},
		{"y": 1.6, "min_x": 6.0, "max_x": 7.0, "min_z": 5.0, "max_z": 6.0},
		{"y": 1.6, "min_x": 13.0, "max_x": 14.0, "min_z": 6.0, "max_z": 7.0},
		{"y": 0.8, "min_x": 13.0, "max_x": 14.0, "min_z": 7.0, "max_z": 8.0}
	]

	for s in surfaces:
		var t = (s["y"] - from.y) / dir.y
		if t > 0 and t < best_t:
			var p = from + dir * t
			if p.x >= s["min_x"] and p.x <= s["max_x"] and p.z >= s["min_z"] and p.z <= s["max_z"]:
				best_t = t
				best_pt = p

	# Ground plane (y = 0.0)
	var t_ground = -from.y / dir.y
	if t_ground > 0 and t_ground < best_t:
		var p_ground = from + dir * t_ground
		if terrain == null or not terrain.has_method("has_cell") or terrain.has_cell(int(floor(p_ground.x)), int(floor(p_ground.z))):
			var c = Vector2i(int(floor(p_ground.x)), int(floor(p_ground.z)))
			if not is_hill_cell(c) and not is_column_cell(c):
				best_t = t_ground
				best_pt = p_ground

	return best_pt

# Multi-height pathfinding: returns array of Vector2i cells from (from_c) to (to_c)
static func find_path_3d(from_c: Vector2i, from_y: float, to_c: Vector2i, to_y: float, gw: int, gh: int, is_free_fn: Callable) -> Array:
	if from_c == to_c:
		return [to_c]

	var start_layer = 1 if (from_y >= 1.2 or is_hill_cell(from_c) or from_c == Vector2i(6, 5) or from_c == Vector2i(13, 6)) else 0
	var target_layer = 1 if (to_y >= 1.2 or is_hill_cell(to_c) or to_c == Vector2i(6, 5) or to_c == Vector2i(13, 6)) else 0

	var start_state = Vector3i(from_c.x, from_c.y, start_layer)
	var visited = {start_state: true}
	var parent = {}
	var q: Array = [start_state]
	var found = false
	var end_state = null

	while q.size() > 0:
		var cur = q.pop_front()
		if cur.x == to_c.x and cur.y == to_c.y and cur.z == target_layer:
			found = true
			end_state = cur
			break

		for nxt in _get_neighbors_3d(cur):
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= gw or nxt.y >= gh:
				continue
			if visited.has(nxt):
				continue
			if not is_free_fn.call(nxt.x, nxt.y):
				continue
			visited[nxt] = true
			parent[nxt] = cur
			q.append(nxt)

	if not found:
		return []

	var path: Array = []
	var curr = end_state
	while curr != start_state:
		path.append(Vector2i(curr.x, curr.y))
		curr = parent[curr]
	path.reverse()
	return path

static func _get_neighbors_3d(cur: Vector3i) -> Array:
	var res: Array = []
	var c = Vector2i(cur.x, cur.y)
	var layer = cur.z

	if layer == 0:
		# Layer 0 (Ground level, Y < 1.2)
		if c == Vector2i(6, 4):
			# Col 1: can step down to ground or step up to Col 2 (layer 1)
			res.append(Vector3i(6, 3, 0))
			res.append(Vector3i(5, 4, 0))
			res.append(Vector3i(6, 5, 1))
		elif c == Vector2i(13, 7):
			# Col 4: can step down to ground or step up to Col 3 (layer 1)
			res.append(Vector3i(13, 8, 0))
			res.append(Vector3i(14, 7, 0))
			res.append(Vector3i(13, 6, 1))
		elif c == Vector2i(9, 5):
			# Underpass under bridge
			res.append(Vector3i(9, 4, 0))
			res.append(Vector3i(9, 6, 0))
			res.append(Vector3i(10, 5, 0))
		elif c == Vector2i(10, 5):
			# Underpass under bridge
			res.append(Vector3i(10, 4, 0))
			res.append(Vector3i(10, 6, 0))
			res.append(Vector3i(9, 5, 0))
		else:
			# Open ground
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nc = c + d
				if nc == Vector2i(6, 4):
					if c == Vector2i(6, 3) or c == Vector2i(5, 4):
						res.append(Vector3i(nc.x, nc.y, 0))
				elif nc == Vector2i(13, 7):
					if c == Vector2i(13, 8) or c == Vector2i(14, 7):
						res.append(Vector3i(nc.x, nc.y, 0))
				elif nc == Vector2i(9, 5):
					if c == Vector2i(9, 4) or c == Vector2i(9, 6):
						res.append(Vector3i(nc.x, nc.y, 0))
				elif nc == Vector2i(10, 5):
					if c == Vector2i(10, 4) or c == Vector2i(10, 6):
						res.append(Vector3i(nc.x, nc.y, 0))
				elif not is_hill_cell(nc) and not is_column_cell(nc) and not is_bridge_cell(nc):
					res.append(Vector3i(nc.x, nc.y, 0))
	else:
		# Layer 1 (Elevated level, Y >= 1.2)
		if c == Vector2i(6, 5):
			# Col 2: can step down to Col 1 (layer 0) or step up to Hill 1 (layer 1)
			res.append(Vector3i(6, 4, 0))
			res.append(Vector3i(7, 5, 1))
		elif c == Vector2i(13, 6):
			# Col 3: can step down to Col 4 (layer 0) or step up to Hill 2 (layer 1)
			res.append(Vector3i(13, 7, 0))
			res.append(Vector3i(12, 6, 1))
		elif c == Vector2i(9, 5):
			# Bridge deck
			res.append(Vector3i(8, 5, 1))
			res.append(Vector3i(10, 5, 1))
		elif c == Vector2i(10, 5):
			# Bridge deck
			res.append(Vector3i(9, 5, 1))
			res.append(Vector3i(11, 5, 1))
		elif is_hill1_cell(c):
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nc = c + d
				if is_hill1_cell(nc):
					res.append(Vector3i(nc.x, nc.y, 1))
				elif c == Vector2i(7, 5) and nc == Vector2i(6, 5):
					res.append(Vector3i(6, 5, 1))
				elif c == Vector2i(8, 5) and nc == Vector2i(9, 5):
					res.append(Vector3i(9, 5, 1))
		elif is_hill2_cell(c):
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nc = c + d
				if is_hill2_cell(nc):
					res.append(Vector3i(nc.x, nc.y, 1))
				elif c == Vector2i(12, 6) and nc == Vector2i(13, 6):
					res.append(Vector3i(13, 6, 1))
				elif c == Vector2i(11, 5) and nc == Vector2i(10, 5):
					res.append(Vector3i(10, 5, 1))

	return res

# Multi-height pathfinding step validation
static func is_valid_path_step(a: Vector2i, b: Vector2i) -> bool:
	if abs(a.x - b.x) + abs(a.y - b.y) != 1:
		return false

	# 1. Intra-hill movements (within Hill 1 or within Hill 2)
	if (is_hill1_cell(a) and is_hill1_cell(b)) or (is_hill2_cell(a) and is_hill2_cell(b)):
		return true

	# 2. Bridge deck span (Hill 1 <-> Bridge <-> Hill 2 at Y = 5)
	if (a == Vector2i(8, 5) and b == Vector2i(9, 5)) or (b == Vector2i(8, 5) and a == Vector2i(9, 5)):
		return true
	if (a == Vector2i(9, 5) and b == Vector2i(10, 5)) or (b == Vector2i(9, 5) and a == Vector2i(10, 5)):
		return true
	if (a == Vector2i(10, 5) and b == Vector2i(11, 5)) or (b == Vector2i(10, 5) and a == Vector2i(11, 5)):
		return true

	# 3. Underpass under bridge (Ground road north-south at X = 9 and X = 10)
	if (a.x == 9 and b.x == 9) and ((a.y == 4 and b.y == 5) or (a.y == 5 and b.y == 4) or (a.y == 5 and b.y == 6) or (a.y == 6 and b.y == 5)):
		return true
	if (a.x == 10 and b.x == 10) and ((a.y == 4 and b.y == 5) or (a.y == 5 and b.y == 4) or (a.y == 5 and b.y == 6) or (a.y == 6 and b.y == 5)):
		return true

	# 4. West Stepped Columns (Ascent):
	if (a == Vector2i(6, 4) and (b == Vector2i(6, 3) or b == Vector2i(5, 4))) or (b == Vector2i(6, 4) and (a == Vector2i(6, 3) or a == Vector2i(5, 4))):
		return true
	if (a == Vector2i(6, 4) and b == Vector2i(6, 5)) or (b == Vector2i(6, 4) and a == Vector2i(6, 5)):
		return true
	if (a == Vector2i(6, 5) and b == Vector2i(7, 5)) or (b == Vector2i(6, 5) and a == Vector2i(7, 5)):
		return true

	# 5. East Stepped Columns (Descent):
	if (a == Vector2i(12, 6) and b == Vector2i(13, 6)) or (b == Vector2i(12, 6) and a == Vector2i(13, 6)):
		return true
	if (a == Vector2i(13, 6) and b == Vector2i(13, 7)) or (b == Vector2i(13, 6) and a == Vector2i(13, 7)):
		return true
	if (a == Vector2i(13, 7) and (b == Vector2i(13, 8) or b == Vector2i(14, 7))) or (b == Vector2i(13, 7) and (a == Vector2i(13, 8) or a == Vector2i(14, 7))):
		return true

	# 6. Open Ground movement (neither is hill, column, or bridge)
	if not is_hill_cell(a) and not is_column_cell(a) and not is_bridge_cell(a):
		if not is_hill_cell(b) and not is_column_cell(b) and not is_bridge_cell(b):
			return true

	return false

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

	# 2. Build Stepped Ascending Columns (Square 1x1 Grid Cell Blocks)
	for c in STEPPED_COLUMNS:
		var ch = STEPPED_COLUMNS[c]
		var gh = terrain.sample_h(c.x + 0.5, c.y + 0.5) if terrain != null and terrain.has_method("sample_h") else 0.0
		
		# Stepped rock column block (1x1 grid cell pedestal)
		var col_m = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(1.0, ch, 1.0)
		col_m.mesh = bm
		col_m.material_override = rock_mat
		col_m.position = Vector3(c.x + 0.5, gh + ch * 0.5, c.y + 0.5)
		root.add_child(col_m)

		# Top step cell slab (identical to hill grid cells)
		var cap = MeshInstance3D.new()
		var sbm = BoxMesh.new()
		sbm.size = Vector3(0.96, 0.08, 0.96)
		cap.mesh = sbm
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
	_add_climb_pair(w3d, Vector2i(5, 4), Vector2i(6, 4)) # ground -> col 1
	_add_climb_pair(w3d, Vector2i(6, 4), Vector2i(6, 5)) # col 1 -> col 2
	_add_climb_pair(w3d, Vector2i(6, 5), Vector2i(7, 5)) # col 2 -> Hill 1

	# East Descent:
	_add_climb_pair(w3d, Vector2i(12, 6), Vector2i(13, 6)) # Hill 2 -> col 3
	_add_climb_pair(w3d, Vector2i(13, 6), Vector2i(13, 7)) # col 3 -> col 4
	_add_climb_pair(w3d, Vector2i(13, 7), Vector2i(13, 8)) # col 4 -> ground
	_add_climb_pair(w3d, Vector2i(13, 7), Vector2i(14, 7)) # col 4 -> ground

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
