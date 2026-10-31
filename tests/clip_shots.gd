extends Node3D
## Planche de contrôle du transfert d'animation : CLIP=walk VIEW=cote OUT=/chemin.png
func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/anim/locomotion.json"))
	var clip: Dictionary = data["clips"][OS.get_environment("CLIP")]
	var frames: Array = clip["frames"]
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.15, 0.17, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	add_child(sun)
	var n := 6
	for k in n:
		var root: Node3D = load("res://assets/solaris/aegis_rig.glb").instantiate()
		root.position.x = (k - (n - 1) / 2.0) * 1.3 if OS.get_environment("VIEW") == "face" else 0.0
		root.position.z = (k - (n - 1) / 2.0) * 1.3 if OS.get_environment("VIEW") != "face" else 0.0
		add_child(root)
		var sk: Skeleton3D = root.find_children("*", "Skeleton3D")[0]
		var fr: Dictionary = frames[int(k * frames.size() / float(n))]
		for i in sk.get_bone_count():
			var q: Array = fr["q"][i]
			sk.set_bone_pose_rotation(i, Quaternion(q[0], q[1], q[2], q[3]))
		sk.set_bone_pose_position(0, sk.get_bone_rest(0).origin + Vector3(fr["hips"][0], fr["hips"][1], 0))
	var cam := Camera3D.new()
	cam.fov = 45
	add_child(cam)
	cam.position = Vector3(0, 0.2, 7.5) if OS.get_environment("VIEW") == "face" else Vector3(7.5, 0.2, 0)
	cam.look_at(Vector3(0, -0.1, 0))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
	get_tree().quit()
