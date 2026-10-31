extends Node
## Captures du casque Meshy sur le Solaris (xvfb-run, opengl3) : 4 angles + 2 peintures.
var f: Node3D
var shots := [
	["face", 0.0, 0, 1.0], ["profil", PI / 2, 0, 1.0], ["dos", PI, 0, 1.0], ["troisquarts", 0.6, 0, 1.0],
	["ivoire", 0.5, 2, 1.0], ["eclipse", 0.5, 3, 1.0], ["corps", 0.4, 0, 3.0],
]

func _ready() -> void:
	f = load("res://scenes/atelier.tscn").instantiate()
	add_child(f)
	await get_tree().create_timer(1.0).timeout
	f._ui.visible = false
	var mech := 0
	for i in Appearance.presets["ranger"].size():
		if Appearance.presets["ranger"][i]["name"] == "Mech orange":
			mech = i
	for s in shots:
		Appearance.load_preset(mech if s[2] == 0 else s[2])
		Appearance.set_piece("helmet", "ranger.mech.helmet")
		f._yaw = s[1]
		f._idle = 0.0
		f._want_focus = Vector3(0, 1.75, 0) if s[3] < 2.0 else Vector3(0, 1.1, 0)
		f._want_dist = s[3]
		f._focus = f._want_focus
		f._dist = f._want_dist
		await get_tree().create_timer(0.7).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://out/helmet_%s.png" % s[0])
	get_tree().quit()
