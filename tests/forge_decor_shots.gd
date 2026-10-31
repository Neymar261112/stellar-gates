extends Node
## Captures du nouveau décor de la Forge (intérieur, d'après la maquette v2) et mesure des images par seconde.
## Lancer (fenêtre affichée, 1600x900) : godot --path . --resolution 1600x900 tests/forge_decor_shots.tscn
## -> videos/forge_decor/*.png
var f: Node3D
const OUT := "res://videos/forge_decor/"


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
	print("[decor] capture ", name)


func fps(label: String, seconds := 3.0) -> void:
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await get_tree().process_frame
		frames += 1
	print("[decor] FPS %s : %.1f" % [label, frames / ((Time.get_ticks_msec() - t0) / 1000.0)])


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	f = load("res://scenes/atelier.tscn").instantiate()
	add_child(f)
	await get_tree().create_timer(12.0).timeout
	f._yaw = 0.0
	f._idle = 0.0
	await fps("APPARENCE", 2.0)
	await shot("forge_apparence")
	f.goto("ARSENAL", "loot_weapon0")
	f._refresh()
	f._yaw = 0.0
	f._idle = 0.0
	await get_tree().create_timer(2.5).timeout
	await fps("ARSENAL", 2.0)
	await shot("forge_arsenal")
	# le décor seul, sans l'interface, sous plusieurs angles
	f._ui.visible = false
	f.set_process_input(false)
	for e in [["face", 0.0, 3.8], ["recul", 0.0, 6.5], ["trois_quarts", 0.7, 5.0], ["cote", 1.5, 5.5], ["dos", PI, 4.5]]:
		f._yaw = e[1]
		f._want_dist = e[2]
		f._dist = e[2]
		f._idle = -999.0
		await get_tree().create_timer(0.6).timeout
		f._yaw = e[1]
		await shot("decor_" + e[0])
	await fps("decor seul")
	get_tree().quit()
