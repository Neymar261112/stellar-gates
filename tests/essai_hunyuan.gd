extends Node3D
## Essai d'une pièce Hunyuan3D (assets/essais/hunyuan) repeinte par plusieurs presets, à côté d'une arme Meshy
## (Minuit) peinte pareil pour comparer. -> videos/essai_hunyuan/<preset>.png

const LOOK := preload("res://scripts/solaris_look.gd")


func _piece(mesh: Mesh, tex: String, x: float, label: String) -> ShaderMaterial:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m: ShaderMaterial = LOOK.meshy_material({ "tex": tex })
	mi.material_override = m
	var ab := mesh.get_aabb()
	var k := 0.55 / maxf(ab.size.x, maxf(ab.size.y, ab.size.z))     # même encombrement pour les deux
	var holder := Node3D.new()
	holder.position = Vector3(x, 0, 0)
	holder.rotation = Vector3(0.15, 0.7, 0)
	add_child(holder)
	mi.scale = Vector3.ONE * k
	mi.position = -ab.get_center() * k
	holder.add_child(mi)
	var l := Label3D.new()
	l.text = label
	l.font_size = 40
	l.pixel_size = 0.0012
	l.position = Vector3(x, -0.3, 0.2)
	add_child(l)
	return m


func _ready() -> void:
	var dir := ProjectSettings.globalize_path("res://videos/essai_hunyuan")
	DirAccess.make_dir_recursive_absolute(dir)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.14, 0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	sun.light_energy = 1.6
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, -2.4, 0)
	fill.light_energy = 0.6
	add_child(fill)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.12, 1.25)
	cam.fov = 40
	add_child(cam)
	cam.make_current()
	var hun := (load("res://assets/essais/hunyuan/src/essai.glb") as PackedScene).instantiate()
	var hmesh: Mesh = hun.find_children("*", "MeshInstance3D", true, false)[0].mesh
	var mats := [_piece(hmesh, "res://assets/essais/hunyuan/essai", -0.33, "Hunyuan3D 2.1"),
		_piece(load("res://assets/weapons/minuit.res"), "res://assets/weapons/minuit", 0.33, "Meshy (Minuit)")]
	var looks := [["texture_origine", {}]]
	for p in Catalog.starter_presets():
		looks.append([p["name"].to_lower().replace(" ", "_").replace("é", "e"), p])
	for lk in looks:
		for m in mats:
			m.set_shader_parameter("repaint", not lk[1].is_empty())
			if not lk[1].is_empty():
				LOOK.meshy_params(m, lk[1], Catalog.look_wear(lk[1]))
		for k in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, lk[0]])
	print("essai_hunyuan ok")
	get_tree().quit()
