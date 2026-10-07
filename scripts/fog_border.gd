# scripts/fog_border.gd
# Плотный туман / кучевые облака по границе карты с мягким налезанием на край.
# Каждый узел — 3 комбинированных пуфа, которые ВСЕГДА повернуты лицом к игроку (Billboard).
class_name FogBorder
extends RefCounted

const CLOUD_SCENE_PATH = "res://CloudBorder.tscn"
const CLOUD_SCENE_PATH_ALT = "res://scenes/CloudBorder.tscn"
const CLOUD_TEX_PATH = "res://art/cloud_dense.png"

static var _cached_scene: PackedScene = null
static var _cached_tex: Texture2D = null
static var _cached_mat: Material = null

static func _get_cloud_scene() -> PackedScene:
	if _cached_scene != null and is_instance_valid(_cached_scene):
		return _cached_scene
	if ResourceLoader.exists(CLOUD_SCENE_PATH):
		_cached_scene = load(CLOUD_SCENE_PATH) as PackedScene
	elif ResourceLoader.exists(CLOUD_SCENE_PATH_ALT):
		_cached_scene = load(CLOUD_SCENE_PATH_ALT) as PackedScene
	return _cached_scene

static func _get_cloud_tex() -> Texture2D:
	if _cached_tex != null and is_instance_valid(_cached_tex):
		return _cached_tex
	if ResourceLoader.exists(CLOUD_TEX_PATH):
		_cached_tex = load(CLOUD_TEX_PATH) as Texture2D
	return _cached_tex

static func _get_cloud_material() -> Material:
	if _cached_mat != null and is_instance_valid(_cached_mat):
		return _cached_mat
	_cached_mat = DayNight.get_cloud_material(_get_cloud_tex())
	return _cached_mat

## Строит плотную стену объёмных облаков прямо по периметру карты
static func build_for_terrain(parent: Node3D, terr: Object, world_offset: Vector3 = Vector3.ZERO) -> Node3D:
	if parent == null or terr == null:
		return null

	var old_root = parent.get_node_or_null("FOG_BORDER_ROOT")
	if old_root != null:
		old_root.name = "FOG_BORDER_OLD"
		old_root.queue_free()

	GraphicsSettings.load_settings()
	if not GraphicsSettings.fog_enabled:
		return null

	var root = Node3D.new()
	root.name = "FOG_BORDER_ROOT"
	parent.add_child(root)

	var c_sz: float = 8.0
	if "CHUNK" in terr:
		c_sz = float(terr.CHUNK)

	var ox: float = 0.0
	if "OX" in terr:
		ox = float(terr.OX)
	var oy: float = 0.0
	if "OY" in terr:
		oy = float(terr.OY)

	# 1. Собираем активные чанки
	var active_chunks := {}
	var has_explicit_mask = false

	if "chunk_mask" in terr and terr.chunk_mask is Dictionary and terr.chunk_mask.size() > 0:
		for k in terr.chunk_mask.keys():
			var parts = str(k).split(",")
			if parts.size() >= 2:
				var cx = int(parts[0])
				var cy = int(parts[1])
				active_chunks[Vector2i(cx, cy)] = true
				has_explicit_mask = true

	if not has_explicit_mask:
		var gw: int = int(terr.GW) if "GW" in terr else 8
		var gh: int = int(terr.GH) if "GH" in terr else 6
		var max_cx = int(ceil(float(gw) / c_sz))
		var max_cy = int(ceil(float(gh) / c_sz))
		for cx in range(0, max_cx):
			for cy in range(0, max_cy):
				active_chunks[Vector2i(cx, cy)] = true

	if active_chunks.is_empty():
		return root

	# 2. Собираем точки спавна облаков вдоль всех открытых граней
	var cloud_points := {} # key: Vector3i -> { pos: Vector3, scale: float }

	var edge_steps = 4
	var outward_distances = [0.2, 2.2, 4.8, 7.8]
	var heights = [0.4, 0.9, 1.6, 2.4]
	var scales = [1.0, 1.25, 1.5, 1.8]

	for c in active_chunks.keys():
		var x0 = float(c.x) * c_sz - ox + world_offset.x
		var x1 = x0 + c_sz
		var z0 = float(c.y) * c_sz - oy + world_offset.z
		var z1 = z0 + c_sz

		# 4 грани: проверяем отсутствие соседа
		var sides = [
			{ "dir": Vector2i(1, 0), "pA": Vector2(x1, z0), "pB": Vector2(x1, z1), "norm": Vector2(1, 0) },
			{ "dir": Vector2i(-1, 0), "pA": Vector2(x0, z0), "pB": Vector2(x0, z1), "norm": Vector2(-1, 0) },
			{ "dir": Vector2i(0, 1), "pA": Vector2(x0, z1), "pB": Vector2(x1, z1), "norm": Vector2(0, 1) },
			{ "dir": Vector2i(0, -1), "pA": Vector2(x0, z0), "pB": Vector2(x1, z0), "norm": Vector2(0, -1) }
		]

		for s in sides:
			if not active_chunks.has(c + s.dir):
				for i in range(edge_steps):
					var t = (float(i) + 0.5) / float(edge_steps)
					var edge_p = s.pA.lerp(s.pB, t)

					for row in range(outward_distances.size()):
						var dist = outward_distances[row]
						var p2d = edge_p + s.norm * dist
						var qk = Vector3i(int(round(p2d.x / 1.5)), row, int(round(p2d.y / 1.5)))
						if not cloud_points.has(qk):
							cloud_points[qk] = {
								"pos": Vector3(p2d.x, world_offset.y + heights[row], p2d.y),
								"scale": scales[row]
							}

		# Внешние углы (диагонали)
		var corners = [
			{ "dir": Vector2i(1, 1), "corner": Vector2(x1, z1), "norm": Vector2(1, 1).normalized(), "adj": [Vector2i(1, 0), Vector2i(0, 1)] },
			{ "dir": Vector2i(-1, 1), "corner": Vector2(x0, z1), "norm": Vector2(-1, 1).normalized(), "adj": [Vector2i(-1, 0), Vector2i(0, 1)] },
			{ "dir": Vector2i(1, -1), "corner": Vector2(x1, z0), "norm": Vector2(1, -1).normalized(), "adj": [Vector2i(1, 0), Vector2i(0, -1)] },
			{ "dir": Vector2i(-1, -1), "corner": Vector2(x0, z0), "norm": Vector2(-1, -1).normalized(), "adj": [Vector2i(-1, 0), Vector2i(0, -1)] }
		]

		for cor in corners:
			if not active_chunks.has(c + cor.dir) and not active_chunks.has(c + cor.adj[0]) and not active_chunks.has(c + cor.adj[1]):
				for row in range(outward_distances.size()):
					var dist = outward_distances[row]
					var p2d = cor.corner + cor.norm * dist
					var qk = Vector3i(int(round(p2d.x / 1.5)), row, int(round(p2d.y / 1.5)))
					if not cloud_points.has(qk):
						cloud_points[qk] = {
							"pos": Vector3(p2d.x, world_offset.y + heights[row], p2d.y),
							"scale": scales[row]
						}

	# 3. Инстанцируем кластеры (каждый узел смотрит в камеру к игроку)
	var pscene = _get_cloud_scene()
	var mat = _get_cloud_material()
	var tex = _get_cloud_tex()

	for pt in cloud_points.values():
		var node: Node3D = null
		if pscene != null:
			node = pscene.instantiate() as Node3D
		if node == null:
			node = Node3D.new()
			# Центральный пуф
			var sp1 = Sprite3D.new()
			sp1.material_override = mat
			sp1.texture = tex
			sp1.pixel_size = 0.025
			sp1.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sp1.shaded = true
			node.add_child(sp1)

			# Левый пуф
			var sp2 = Sprite3D.new()
			sp2.material_override = mat
			sp2.texture = tex
			sp2.pixel_size = 0.025
			sp2.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sp2.shaded = true
			sp2.position = Vector3(-0.7, 0.25, -0.3)
			sp2.scale = Vector3(0.85, 0.85, 0.85)
			node.add_child(sp2)

			# Правый пуф
			var sp3 = Sprite3D.new()
			sp3.material_override = mat
			sp3.texture = tex
			sp3.pixel_size = 0.025
			sp3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sp3.shaded = true
			sp3.position = Vector3(0.7, -0.2, 0.3)
			sp3.scale = Vector3(0.85, 0.85, 0.85)
			node.add_child(sp3)

		var pos: Vector3 = pt.pos
		var ox_rand = randf_range(-0.5, 0.5)
		var oz_rand = randf_range(-0.5, 0.5)
		var oy_rand = randf_range(-0.15, 0.25)
		node.position = Vector3(pos.x + ox_rand, pos.y + oy_rand, pos.z + oz_rand)
		
		var s = pt.scale * randf_range(0.9, 1.15)
		node.scale = Vector3(s, s, s)

		root.add_child(node)

	return root
