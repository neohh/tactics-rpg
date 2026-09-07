extends Node3D
func _ready():
	var cam = Camera3D.new()
	cam.position = Vector3(1.5, 2.6, 5.2)
	cam.look_at(Vector3(1.5, 0, 0), Vector3.UP)
	add_child(cam)
	var dl = DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-50, 30, 0)
	add_child(dl)
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.08)
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var tex = null
	var path = ""
	for p in ["res://art/grass.png", "res://art/kust.png", "res://art/Tree1.jpg"]:
		if FileAccess.file_exists(p):
			var im = Image.new()
			if im.load(p) == OK:
				tex = ImageTexture.create_from_image(im)
				path = p
				print("TEST TEX: ", p, " size=", im.get_size(), " format=", im.get_format())
				break
	if tex == null:
		print("TEST: текстура не найдена")
		return
	_plane(0, "A Standard", _std_mat(tex))
	_plane(1, "B shader lit", _sh_lit(tex, false))
	_plane(2, "C unshaded", _sh_lit(tex, true))
	_plane(3, "D splat", _sh_splat(tex))
func _plane(x, title, mat):
	var m = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	m.mesh = q
	q.material = mat
	m.rotation_degrees = Vector3(-90, 0, 0)
	m.position = Vector3(x, 0, 0)
	add_child(m)
	var lb = Label3D.new()
	lb.text = title
	lb.pixel_size = 0.01
	lb.position = Vector3(x, 0.3, 0.8)
	add_child(lb)
func _std_mat(tex):
	var mi = StandardMaterial3D.new()
	mi.albedo_texture = tex
	mi.texture_repeat = 1
	return mi
func _sh_lit(tex, unsh):
	var mat = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = ("shader_type spatial;\n" + ("render_mode unshaded;\n" if unsh else "") + "uniform sampler2D t : source_color, repeat_enable;\nvoid fragment() { ALBEDO = texture(t, UV * 1.0).rgb; ROUGHNESS = 1.0; SPECULAR = 0.0; }\n")
	mat.shader = sh
	mat.set_shader_parameter("t", tex)
	return mat
func _sh_splat(tex):
	var mat = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = "shader_type spatial;
uniform sampler2D t : source_color, repeat_enable;
void fragment() {
	ALBEDO = texture(t, UV).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}"
	mat.shader = sh
	mat.set_shader_parameter("t", tex)
	return mat
