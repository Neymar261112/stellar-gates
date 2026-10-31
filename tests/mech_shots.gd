extends Node
## Captures du Solaris en pièces Meshy (« Mech orange ») : face, profil, dos, 3/4, et une pose animée.
var f: Node3D
func _ready() -> void:
	f = load("res://scenes/atelier.tscn").instantiate()
	add_child(f)
	await get_tree().create_timer(1.0).timeout
	f._ui.visible = false
	var want := OS.get_environment("LOOK_PRESET") if OS.get_environment("LOOK_PRESET") != "" else "Aegis"
	for i in Appearance.presets["ranger"].size():
		if Appearance.presets["ranger"][i]["name"] == want:
			Appearance.load_preset(i)
	for s in [["face", 0.0], ["profil", PI / 2], ["dos", PI], ["tq", 0.7], ["jambes", 1.2]]:
		f._yaw = s[1]
		f._idle = 0.0
		f._want_focus = Vector3(0, 0.75, 0)
		f._want_dist = 4.6
		f._focus = f._want_focus
		f._dist = f._want_dist
		for k in 20:
			f._want_focus = Vector3(0, 0.85, 0) if s[0] != "jambes" else Vector3(0, 0.35, 0)
			f._want_dist = 4.4 if s[0] != "jambes" else 2.2
			f._focus = f._want_focus
			f._dist = f._want_dist
			f._yaw = s[1]
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://out/mech_%s.png" % s[0])
	f._yaw = 0.5
	f._play("salute")
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/mech_anim.png")
	print("legs ", Appearance.piece("legs"), " parts ", f.solaris.look._pieces["legs"].size())
	get_tree().quit()
