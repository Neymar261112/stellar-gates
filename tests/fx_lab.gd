extends Node3D
## Banc d'essai des effets, un par un, sur fond neutre (images dans out/lab_*.png).

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/lab_%s.png" % name)


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.55, 0.65)
	e.ambient_light_color = Color(0.7, 0.7, 0.7)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	add_child(sun)
	var ground := StaticBody3D.new()
	ground.name = "TerrainBody"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(200, 1, 200)
	cs.shape = bs
	cs.position.y = -0.5
	ground.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	mi.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.5, 0.42)
	mi.material_override = gm
	ground.add_child(mi)
	add_child(ground)
	var cam := Camera3D.new()
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.6, 6), Vector3(0, 1.0, 0))
	cam.current = true
	await get_tree().create_timer(0.3).timeout
	var which := OS.get_environment("LAB")
	if which == "" or which == "muzzle":
		Fx.muzzle(Vector3(-1.5, 1.2, 0), Vector3(1, 0, 0), Color(1, 0.8, 0.45), 0.5)
		await get_tree().process_frame
		await shot("muzzle")
		await get_tree().create_timer(0.3).timeout
		await shot("muzzle_smoke")
	if which == "" or which == "impact":
		Fx.impact(Vector3(-2, 0, 0), Vector3.UP, "dirt")
		Fx.impact(Vector3(0, 0, 0), Vector3.UP, "stone")
		Fx.impact(Vector3(2, 0.8, 0), Vector3(0, 0, 1), "metal")
		await get_tree().create_timer(0.06).timeout
		await shot("impact_0")
		await get_tree().create_timer(0.4).timeout
		await shot("impact_1")
	if which == "" or which == "bullet":
		Fx.bullet(Vector3(-6, 1.2, 2), Vector3(6, 1.0, -2), Color(1, 0.8, 0.5), 40.0, 0.03)
		await get_tree().create_timer(0.15).timeout
		await shot("bullet")
	if which == "fire":
		cam.look_at_from_position(Vector3(0, 2, 10), Vector3(0, 1.5, 0))
		Fx.fireball(Vector3(0, 1.5, 0), 3.0, 14, 1.0)
		await get_tree().create_timer(0.1).timeout
		await shot("fire_0")
		await get_tree().create_timer(0.3).timeout
		await shot("fire_1")
	if which == "" or which == "explo":
		await get_tree().create_timer(1.0).timeout
		cam.look_at_from_position(Vector3(0, 3, 18), Vector3(0, 2.0, 0))
		Fx.explosion(Vector3(0, 0.5, 0), 5.5, Color(1.0, 0.55, 0.2), 1.4)
		for k in [0.05, 0.2, 0.5, 1.2, 2.5]:
			await get_tree().create_timer(k if k == 0.05 else 0.3 if k == 0.2 else 0.3 if k == 0.5 else 0.7 if k == 1.2 else 1.3).timeout
			await shot("explo_%s" % str(k))
	get_tree().quit()
