extends Node3D
## Images de contrôle du rig : pose de marche extrême, vues de face, de côté et de 3/4.
## RIG=res://assets/solaris/xxx.glb OUT=/chemin/prefixe godot --path . tests/rig_pose_shots.tscn

func _ready() -> void:
	var path := OS.get_environment("RIG")
	var out := OS.get_environment("OUT")
	var root: Node3D = load(path).instantiate()
	add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.8, 0.82)
	mat.roughness = 0.6
	for mi in root.find_children("*", "MeshInstance3D"):
		mi.material_override = mat
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D")[0]
	var pose := { "upper_arm_L": Vector3(-0.9, 0, 0.12), "upper_arm_R": Vector3(0.9, 0, -0.12),
		"forearm_L": Vector3(-0.9, 0, 0), "forearm_R": Vector3(-0.6, 0, 0),
		"thigh_L": Vector3(0.7, 0, 0), "thigh_R": Vector3(-0.7, 0, 0), "shin_L": Vector3(1.0, 0, 0), "shin_R": Vector3(0.2, 0, 0) }
	for b in pose:
		sk.set_bone_pose_rotation(sk.find_bone(b), Quaternion.from_euler(pose[b]))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.15, 0.17, 0.2)
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	var views := { "face": Vector3(0, 0.1, 3.2), "cote": Vector3(3.2, 0.1, 0), "trois_quarts": Vector3(2.0, 0.4, 2.4), "dos": Vector3(-1.6, 0.2, -2.6) }
	for k in views:
		cam.position = views[k]
		cam.look_at(Vector3(0, -0.05, 0))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "_" + k + ".png")
	get_tree().quit()
