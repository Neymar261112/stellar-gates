extends Node
## Vignettes des armes (modèles Meshy de cyril) pour l'Arsenal : 512 px, fond transparent, vue de 3/4,
## même cadrage que les vignettes de tools/meshy_loot.py -> assets/loot/icons/<id>.png.
## Lancer : godot --path . tools/weapon_icons.tscn

const SIZE := 512
const WEAPONS := [["avantgarde", "res://assets/weapons/rifle"], ["vipers", "res://assets/weapons/vipers"],
	["tacticien", "res://assets/weapons/tacticien"], ["ivoire", "res://assets/weapons/ivoire"],
	["minuit", "res://assets/weapons/minuit"], ["repetiteur", "res://assets/weapons/repetiteur"],
	["sentinelle", "res://assets/weapons/sentinelle"], ["silencieux", "res://assets/weapons/silencieux"],
	["titan", "res://assets/weapons/titan"]]


func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.9
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	for l in [[Vector3(-0.8, -0.5, 0), 2.2, Color(1.0, 0.96, 0.9)], [Vector3(-0.4, 2.4, 0), 1.4, Color(0.7, 0.8, 1.0)], [Vector3(0.6, 1.2, 0), 0.6, Color.WHITE]]:
		var d := DirectionalLight3D.new()
		d.rotation = l[0]
		d.light_energy = l[1]
		d.light_color = l[2]
		vp.add_child(d)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/loot/icons"))
	for w in WEAPONS:
		var mi := MeshInstance3D.new()
		mi.mesh = load(w[1] + ".res")
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(w[1] + "_albedo.png")
		m.normal_enabled = true
		m.normal_texture = load(w[1] + "_normal.png")
		m.roughness_texture = load(w[1] + "_roughness.png")
		m.metallic_texture = load(w[1] + "_metallic.png")
		m.metallic = 1.0
		m.roughness = 1.0
		mi.material_override = m
		# canon vers -X dans le modèle : on le tourne de 3/4, canon vers la gauche de l'image
		mi.rotation = Vector3(0.0, -0.55, 0.12)
		vp.add_child(mi)
		var box := mi.global_transform * mi.mesh.get_aabb()
		var c := box.get_center()
		var r := box.size.length() * 0.5
		var dist := r / tan(deg_to_rad(cam.fov * 0.5)) * 0.94
		cam.look_at_from_position(c + Vector3(0, 0.35, 1).normalized() * dist, c)
		for i in 4:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		# recadré au plus près de l'arme (vignettes larges et basses de la Forge)
		img = img.get_region(img.get_used_rect().grow(6).intersection(Rect2i(0, 0, SIZE, SIZE)))
		img.save_png("res://assets/loot/icons/%s.png" % w[0])
		print("[icones] ", w[0])
		mi.queue_free()
		await get_tree().process_frame
	get_tree().quit()
