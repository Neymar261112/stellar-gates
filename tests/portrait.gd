extends Node3D
## Portrait du Solaris debout, vu de face, sur fond studio. Rend une image fixe.
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --resolution 1080x1440 --write-movie out/f.png --fixed-fps 24 --quit-after 6 tests/portrait.tscn

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.13, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.6)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.95, 0.88)
	key.light_energy = 1.6
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.6, 0.75, 1.0)
	rim.light_energy = 1.2
	rim.rotation_degrees = Vector3(-20.0, 160.0, 0.0)
	add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.9, 0.9, 1.0)
	fill.light_energy = 0.5
	fill.rotation_degrees = Vector3(-10.0, -60.0, 0.0)
	add_child(fill)
	# Sol
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.16, 0.18)
	fm.roughness = 0.35
	fm.metallic = 0.2
	pm.material = fm
	floor_mi.mesh = pm
	add_child(floor_mi)
	# Le Solaris, finition d'origine
	var scene: PackedScene = load("res://assets/solaris/solaris_rig.glb" if OS.get_environment("PORTRAIT_RIG") != "" else "res://assets/solaris/solaris.glb")
	var model := scene.instantiate()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/solaris/solaris.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/solaris/normal.jpg")
	var mr: Texture2D = load("res://assets/solaris/metal-rough.jpg")
	mat.metallic = 1.0
	mat.metallic_texture = mr
	mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.roughness = 1.0
	mat.roughness_texture = mr
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	var aabb := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D"):
		mi.material_override = mat
		var a: AABB = mi.transform * mi.get_aabb()
		aabb = a if first else aabb.merge(a)
		first = false
	model.position.y = -aabb.position.y
	if OS.get_environment("PORTRAIT_RIG") == "pose":
		var sk: Skeleton3D = model.find_children("*", "Skeleton3D")[0]
		var b := func(n: String, e: Vector3): sk.set_bone_pose_rotation(sk.find_bone(n), Quaternion.from_euler(e))
		b.call("upper_arm_L", Vector3(-1.4, 0, 0.3))
		b.call("forearm_L", Vector3(-0.6, 0, 0))
		b.call("upper_arm_R", Vector3(0.6, 0, -0.4))
		b.call("thigh_R", Vector3(-0.9, 0, 0))
		b.call("shin_R", Vector3(1.0, 0, 0))
		b.call("thigh_L", Vector3(0.4, 0, 0))
		b.call("head", Vector3(0, 0.6, 0))
		b.call("spine", Vector3(0.15, 0.3, 0))
	# Le GLB regarde vers +Z : la caméra se place côté +Z pour le voir de face
	add_child(model)
	var h := aabb.size.y
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.position = Vector3(0, h * 0.5, h * 2.05)
	add_child(cam)
	cam.look_at(Vector3(0, h * 0.5, 0))
	cam.current = true
	var spot := OmniLight3D.new()
	spot.light_color = Color(1.0, 0.85, 0.6)
	spot.light_energy = 1.5
	spot.omni_range = 6.0
	spot.position = Vector3(0, h * 0.6, 2.0)
	add_child(spot)
