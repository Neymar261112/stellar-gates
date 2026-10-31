extends Node
## Captures avant / après de la Forge (1600x900) : onglets ARSENAL, COMPOSANTS et APPARENCE.
## Lancer : godot --path . --resolution 1600x900 tests/forge_avant_apres.tscn -- avant   (ou « apres »)
var f: Node3D


func _ready() -> void:
	var tag := "avant"
	for a in OS.get_cmdline_user_args():
		tag = a
	get_window().size = Vector2i(1600, 900)
	f = load("res://scenes/atelier.tscn").instantiate()
	add_child(f)
	await get_tree().create_timer(10.0).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://videos/forge_avant_apres"))
	for t in [["ARSENAL", "loot_weapon0"], ["COMPOSANTS", ""], ["APPARENCE", "piece_helmet"]]:
		if t[1] != "":
			f.goto(t[0], t[1])
		else:
			f._set_tab(f.TABS.find(t[0]))
		await get_tree().create_timer(3.0).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://videos/forge_avant_apres/%s_%s.png" % [tag, t[0].to_lower()])
		print("[captures] ", tag, " ", t[0])
	get_tree().quit()
