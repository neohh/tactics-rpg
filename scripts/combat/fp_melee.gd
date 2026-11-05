extends Node3D
class_name FPMelee

signal attack_hit(target, damage, is_crit, is_heavy)
signal kick_hit(target)
signal parry_success(attacker)
signal block_hit(attacker, absorbed_dmg)
signal guard_broken()

enum State {
	IDLE,
	WINDUP,
	CHARGING,
	ACTIVE,
	RECOVERY,
	KICK,
	PARRY,
	BLOCKING,
	STAGGER
}

var current_state: int = State.IDLE

# Viewmodel nodes
var viewmodel_root: Node3D
var weapon_node: Node3D
var anim_player: AnimationPlayer = null

# Offsets for procedural animation
var rest_pos: Vector3 = Vector3(0.32, -0.28, -0.55)
var rest_rot: Vector3 = Vector3(deg_to_rad(10), deg_to_rad(-15), deg_to_rad(5))

var cur_sway_pos: Vector3 = Vector3.ZERO
var cur_sway_rot: Vector3 = Vector3.ZERO
var mouse_delta: Vector2 = Vector2.ZERO

# Combat parameters
var base_damage: float = 1.0
var heavy_damage: float = 2.5
var crit_multiplier: float = 2.0
var attack_range: float = 3.2
var parry_window_dur: float = 0.45
var parry_timer: float = 0.0
var last_block_press_time: int = 0
var charge_timer: float = 0.0
var is_fully_charged: bool = false
var tween_anim: Tween = null

# Hitbox checking
var targets_hit: Array = []

func _ready():
	_build_viewmodel()

func _build_viewmodel():
	viewmodel_root = Node3D.new()
	viewmodel_root.name = "ViewmodelRoot"
	add_child(viewmodel_root)

	weapon_node = Node3D.new()
	weapon_node.name = "WeaponHolder"
	weapon_node.position = rest_pos
	weapon_node.rotation = rest_rot
	viewmodel_root.add_child(weapon_node)

	_create_sword_mesh()

func _create_sword_mesh():
	# 1. Blade
	var blade = MeshInstance3D.new()
	blade.name = "Blade"
	var bm = BoxMesh.new()
	bm.size = Vector3(0.04, 0.75, 0.015)
	var blade_mat = StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.85, 0.88, 0.95)
	blade_mat.metallic = 0.9
	blade_mat.roughness = 0.2
	blade.mesh = bm
	blade.material_override = blade_mat
	blade.position = Vector3(0, 0.45, 0)
	weapon_node.add_child(blade)

	# 2. Crossguard
	var guard = MeshInstance3D.new()
	guard.name = "Guard"
	var gm = BoxMesh.new()
	gm.size = Vector3(0.18, 0.03, 0.04)
	var guard_mat = StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.8, 0.65, 0.2) # Brass/Gold
	guard_mat.metallic = 0.8
	guard_mat.roughness = 0.35
	guard.mesh = gm
	guard.material_override = guard_mat
	guard.position = Vector3(0, 0.08, 0)
	weapon_node.add_child(guard)

	# 3. Handle
	var handle = MeshInstance3D.new()
	handle.name = "Handle"
	var hm = CylinderMesh.new()
	hm.top_radius = 0.016
	hm.bottom_radius = 0.016
	hm.height = 0.16
	var handle_mat = StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.2, 0.12, 0.08) # Dark leather
	handle_mat.roughness = 0.8
	handle.mesh = hm
	handle.material_override = handle_mat
	handle.position = Vector3(0, -0.01, 0)
	weapon_node.add_child(handle)

	# 4. Pommel
	var pommel = MeshInstance3D.new()
	pommel.name = "Pommel"
	var pm = SphereMesh.new()
	pm.radius = 0.026
	pm.height = 0.052
	pommel.mesh = pm
	pommel.material_override = guard_mat
	pommel.position = Vector3(0, -0.1, 0)
	weapon_node.add_child(pommel)

func set_mouse_delta(delta: Vector2):
	mouse_delta = delta

func _process(delta: float):
	_update_sway(delta)
	_update_parry_timer(delta)
	_update_charge(delta)

func _update_charge(delta: float):
	if current_state == State.CHARGING:
		charge_timer += delta
		if charge_timer >= 0.35 and not is_fully_charged:
			is_fully_charged = true
			if weapon_node != null:
				var tw = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(weapon_node, "position:z", rest_pos.z + 0.08, 0.06)
				tw.tween_property(weapon_node, "position:z", rest_pos.z + 0.12, 0.06)

func _update_sway(delta: float):
	if weapon_node == null:
		return
	
	# Mouse sway (drag behind camera look)
	var target_sway_rot = Vector3(
		clampf(-mouse_delta.y * 0.001, -0.15, 0.15),
		clampf(-mouse_delta.x * 0.001, -0.15, 0.15),
		clampf(mouse_delta.x * 0.001, -0.1, 0.1)
	)
	var target_sway_pos = Vector3(
		clampf(-mouse_delta.x * 0.0003, -0.04, 0.04),
		clampf(mouse_delta.y * 0.0003, -0.04, 0.04),
		0.0
	)
	
	cur_sway_rot = cur_sway_rot.lerp(target_sway_rot, delta * 10.0)
	cur_sway_pos = cur_sway_pos.lerp(target_sway_pos, delta * 10.0)
	mouse_delta = Vector2.ZERO
	
	viewmodel_root.position = cur_sway_pos
	viewmodel_root.rotation = cur_sway_rot

func _update_parry_timer(delta: float):
	if current_state == State.PARRY:
		parry_timer -= delta
		if parry_timer <= 0.0:
			current_state = State.BLOCKING

# ==================== ACTIONS ====================

func can_attack() -> bool:
	return current_state == State.IDLE or current_state == State.RECOVERY

func is_charging() -> bool:
	return current_state == State.CHARGING

func start_charge():
	if not can_attack():
		return
	current_state = State.CHARGING
	charge_timer = 0.0
	is_fully_charged = false
	targets_hit.clear()
	
	if tween_anim != null and tween_anim.is_valid():
		tween_anim.kill()
	
	var charge_pos = rest_pos + Vector3(0.08, 0.14, 0.12)
	var charge_rot = rest_rot + Vector3(deg_to_rad(25), deg_to_rad(35), deg_to_rad(-25))
	
	tween_anim = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_anim.tween_property(weapon_node, "position", charge_pos, 0.14)
	tween_anim.parallel().tween_property(weapon_node, "rotation", charge_rot, 0.14)

func release_charge(potential_targets: Array = []) -> Dictionary:
	if current_state != State.CHARGING:
		return {}
	
	var is_heavy = charge_timer >= 0.30
	var dur_charged = charge_timer
	charge_timer = 0.0
	is_fully_charged = false
	targets_hit.clear()
	
	if tween_anim != null and tween_anim.is_valid():
		tween_anim.kill()
	
	tween_anim = create_tween().set_trans(Tween.TRANS_CUBIC)
	
	if not is_heavy:
		# Fast Light Strike (быстрый слабый удар)
		var slash_pos = rest_pos + Vector3(-0.45, -0.15, -0.2)
		var slash_rot = rest_rot + Vector3(deg_to_rad(-35), deg_to_rad(-65), deg_to_rad(55))
		
		tween_anim.tween_callback(func():
			current_state = State.ACTIVE
			_check_strike_hits(potential_targets, false)
		)
		tween_anim.tween_property(weapon_node, "position", slash_pos, 0.08).set_ease(Tween.EASE_IN)
		tween_anim.parallel().tween_property(weapon_node, "rotation", slash_rot, 0.08).set_ease(Tween.EASE_IN)
		
		tween_anim.tween_callback(func():
			current_state = State.RECOVERY
		)
		tween_anim.tween_property(weapon_node, "position", rest_pos, 0.12).set_ease(Tween.EASE_OUT)
		tween_anim.parallel().tween_property(weapon_node, "rotation", rest_rot, 0.12).set_ease(Tween.EASE_OUT)
		tween_anim.tween_callback(func():
			current_state = State.IDLE
		)
		return {"is_heavy": false, "stamina_cost": 8.0, "charge_time": dur_charged}
	else:
		# Heavy Charged Strike (мощный сильный удар)
		var heavy_pos = rest_pos + Vector3(-0.55, -0.25, -0.3)
		var heavy_rot = rest_rot + Vector3(deg_to_rad(-45), deg_to_rad(-80), deg_to_rad(70))
		
		tween_anim.tween_callback(func():
			current_state = State.ACTIVE
			_check_strike_hits(potential_targets, true)
		)
		tween_anim.tween_property(weapon_node, "position", heavy_pos, 0.14).set_ease(Tween.EASE_IN)
		tween_anim.parallel().tween_property(weapon_node, "rotation", heavy_rot, 0.14).set_ease(Tween.EASE_IN)
		
		tween_anim.tween_callback(func():
			current_state = State.RECOVERY
		)
		tween_anim.tween_property(weapon_node, "position", rest_pos, 0.22).set_ease(Tween.EASE_OUT)
		tween_anim.parallel().tween_property(weapon_node, "rotation", rest_rot, 0.22).set_ease(Tween.EASE_OUT)
		tween_anim.tween_callback(func():
			current_state = State.IDLE
		)
		return {"is_heavy": true, "stamina_cost": 18.0, "charge_time": dur_charged}

func try_attack(potential_targets: Array = []) -> bool:
	if not can_attack():
		return false
	start_charge()
	release_charge(potential_targets)
	return true

func can_kick() -> bool:
	return current_state == State.IDLE or current_state == State.RECOVERY

func try_kick(potential_targets: Array = []) -> bool:
	if not can_kick():
		return false
	
	current_state = State.KICK
	if tween_anim != null and tween_anim.is_valid():
		tween_anim.kill()
	
	var kick_pos = rest_pos + Vector3(-0.04, -0.06, 0.18)
	var kick_rot = rest_rot + Vector3(deg_to_rad(-18), 0, deg_to_rad(-12))
	
	tween_anim = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_anim.tween_property(weapon_node, "position", kick_pos, 0.08)
	tween_anim.parallel().tween_property(weapon_node, "rotation", kick_rot, 0.08)
	tween_anim.tween_callback(func():
		_check_kick_hits(potential_targets)
	)
	tween_anim.tween_property(weapon_node, "position", rest_pos, 0.18).set_ease(Tween.EASE_OUT)
	tween_anim.parallel().tween_property(weapon_node, "rotation", rest_rot, 0.18).set_ease(Tween.EASE_OUT)
	tween_anim.tween_callback(func():
		current_state = State.IDLE
	)
	return true

func _check_kick_hits(potential_targets: Array):
	if potential_targets.is_empty():
		return
	var cam = get_parent() as Camera3D
	if cam == null:
		return
	var cam_pos = cam.global_position
	var forward = -cam.global_transform.basis.z.normalized()
	
	for target in potential_targets:
		if target == null:
			continue
		var t_pos = target.global_position if target is Node3D else (target.get("root").global_position if target is Dictionary and target.has("root") else Vector3.ZERO)
		var t_center = t_pos + Vector3(0, 0.8, 0)
		var to_target = t_center - cam_pos
		var dist = to_target.length()
		if dist <= 2.8:
			var dot = forward.dot(to_target.normalized())
			if dot > 0.35:
				kick_hit.emit(target)
				_spawn_hit_spark(t_center)
				break

func _check_strike_hits(potential_targets: Array, is_heavy: bool = false):
	if potential_targets.is_empty():
		return
	
	var cam = get_parent() as Camera3D
	if cam == null:
		return
	
	var cam_pos = cam.global_position
	var forward = -cam.global_transform.basis.z.normalized()
	
	for target in potential_targets:
		if target == null:
			continue
		var t_pos = target.global_position if target is Node3D else (target.get("root").global_position if target is Dictionary and target.has("root") else Vector3.ZERO)
		var t_center = t_pos + Vector3(0, 0.9, 0)
		var to_target = t_center - cam_pos
		var dist = to_target.length()
		
		# Check range and forward cone
		if dist <= attack_range:
			var dot = forward.dot(to_target.normalized())
			if dot > 0.35: # Within generous ~70 degree cone in front of camera
				targets_hit.append(target)
				var is_staggered = target.get("staggered", false) if target is Dictionary else false
				var eff_dmg = heavy_damage if is_heavy else base_damage
				var dmg = eff_dmg * (crit_multiplier if is_staggered else 1.0)
				attack_hit.emit(target, dmg, is_staggered, is_heavy)
				_spawn_hit_spark(t_center)

func start_block():
	if current_state == State.WINDUP or current_state == State.ACTIVE or current_state == State.STAGGER:
		return
	
	current_state = State.PARRY
	parry_timer = parry_window_dur
	last_block_press_time = Time.get_ticks_msec()
	
	if tween_anim != null and tween_anim.is_valid():
		tween_anim.kill()
	
	# Raise weapon horizontally in front of chest/eyes
	var block_pos = Vector3(0.0, -0.15, -0.38)
	var block_rot = Vector3(deg_to_rad(-10), deg_to_rad(-70), deg_to_rad(85))
	
	tween_anim = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_anim.tween_property(weapon_node, "position", block_pos, 0.1)
	tween_anim.parallel().tween_property(weapon_node, "rotation", block_rot, 0.1)

func stop_block():
	if current_state == State.PARRY or current_state == State.BLOCKING:
		current_state = State.IDLE
		if tween_anim != null and tween_anim.is_valid():
			tween_anim.kill()
		
		tween_anim = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween_anim.tween_property(weapon_node, "position", rest_pos, 0.15)
		tween_anim.parallel().tween_property(weapon_node, "rotation", rest_rot, 0.15)

func is_parrying() -> bool:
	return current_state == State.PARRY

func is_blocking() -> bool:
	return current_state == State.BLOCKING or current_state == State.PARRY

func receive_hit(incoming_damage: float, attacker = null, is_unblockable: bool = false) -> Dictionary:
	if is_unblockable:
		if is_blocking():
			trigger_stagger()
			return {"result": "guard_break", "damage_taken": incoming_damage}
		return {"result": "hit", "damage_taken": incoming_damage}
	var now = Time.get_ticks_msec()
	var recent_parry = (now - last_block_press_time) <= 450
	if is_parrying() or recent_parry:
		# PARRY SUCCESS!
		parry_success.emit(attacker)
		_trigger_riposte_anim()
		return {"result": "parry", "damage_taken": 0.0}
	elif is_blocking():
		# BLOCKED
		var absorbed = incoming_damage * 0.75
		var taken = incoming_damage - absorbed
		block_hit.emit(attacker, absorbed)
		_trigger_block_recoil()
		return {"result": "block", "damage_taken": taken}
	else:
		return {"result": "hit", "damage_taken": incoming_damage}

func _trigger_riposte_anim():
	_spawn_parry_spark(weapon_node.global_position + Vector3(0, 0.2, -0.25))
	if tween_anim != null and tween_anim.is_valid():
		tween_anim.kill()
	
	current_state = State.ACTIVE
	var ready_pos = rest_pos + Vector3(0.08, 0.1, -0.15)
	var ready_rot = rest_rot + Vector3(deg_to_rad(15), deg_to_rad(30), deg_to_rad(-20))
	var slash_pos = rest_pos + Vector3(-0.48, -0.12, -0.25)
	var slash_rot = rest_rot + Vector3(deg_to_rad(-30), deg_to_rad(-65), deg_to_rad(55))
	
	tween_anim = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween_anim.tween_property(weapon_node, "position", ready_pos, 0.04)
	tween_anim.parallel().tween_property(weapon_node, "rotation", ready_rot, 0.04)
	tween_anim.tween_property(weapon_node, "position", slash_pos, 0.10).set_ease(Tween.EASE_IN)
	tween_anim.parallel().tween_property(weapon_node, "rotation", slash_rot, 0.10).set_ease(Tween.EASE_IN)
	tween_anim.tween_property(weapon_node, "position", rest_pos, 0.20).set_ease(Tween.EASE_OUT)
	tween_anim.parallel().tween_property(weapon_node, "rotation", rest_rot, 0.20).set_ease(Tween.EASE_OUT)
	tween_anim.tween_callback(func(): current_state = State.IDLE)

func _trigger_block_recoil():
	if tween_anim != null and tween_anim.is_valid():
		tween_anim.kill()
	
	var recoil_pos = Vector3(0.0, -0.18, -0.32)
	tween_anim = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tween_anim.tween_property(weapon_node, "position", recoil_pos, 0.06)
	tween_anim.tween_property(weapon_node, "position", Vector3(0.0, -0.15, -0.38), 0.12)

func trigger_stagger():
	current_state = State.STAGGER
	guard_broken.emit()
	if tween_anim != null and tween_anim.is_valid():
		tween_anim.kill()
	
	var drop_pos = rest_pos + Vector3(0.1, -0.35, 0.1)
	var drop_rot = rest_rot + Vector3(deg_to_rad(-45), deg_to_rad(20), deg_to_rad(-30))
	
	tween_anim = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween_anim.tween_property(weapon_node, "position", drop_pos, 0.4)
	tween_anim.parallel().tween_property(weapon_node, "rotation", drop_rot, 0.4)
	tween_anim.tween_interval(0.8) # Stagger duration
	tween_anim.tween_property(weapon_node, "position", rest_pos, 0.3)
	tween_anim.parallel().tween_property(weapon_node, "rotation", rest_rot, 0.3)
	tween_anim.tween_callback(func(): current_state = State.IDLE)

# ==================== VISUAL EFFECTS ====================

func _spawn_hit_spark(pos: Vector3):
	var mesh = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	mat.emission_energy_multiplier = 3.0
	mesh.mesh = sm
	mesh.material_override = mat
	get_tree().root.add_child(mesh)
	mesh.global_position = pos
	
	var tw = mesh.create_tween()
	tw.tween_property(mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.15)
	tw.finished.connect(func(): mesh.queue_free())

func _spawn_parry_spark(pos: Vector3):
	var mesh = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.95, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.9, 1.0)
	mat.emission_energy_multiplier = 6.0
	mesh.mesh = sm
	mesh.material_override = mat
	get_tree().root.add_child(mesh)
	mesh.global_position = pos
	
	var tw = mesh.create_tween().set_parallel(true)
	tw.tween_property(mesh, "scale", Vector3(2.5, 2.5, 2.5), 0.12)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.12)
	tw.finished.connect(func(): mesh.queue_free())
