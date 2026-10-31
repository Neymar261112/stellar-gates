extends Node
## Forge, onglet ARSENAL : un Tacticien légendaire (liseré or sur le modèle de la fiche) puis un Vigile.
## Lancer (fenêtre affichée) : godot --path . tests/couleurs_armes_forge.tscn  -> videos/armes_29oct/couleurs/forge_*.png
var f: Node3D
const OUT := "res://videos/armes_29oct/couleurs/"


func _ready() -> void:
	Appearance.persist = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	f = load("res://scenes/atelier.tscn").instantiate()
	add_child(f)
	await get_tree().create_timer(14.0).timeout
	Inventory.demo()
	var rng := RandomNumberGenerator.new()
	var leg: Dictionary = Inventory.add(LootRoll.make(rng, "tacticien", 5, 0, "Captures"))
	for e in [["tacticien", leg["uid"]], ["ivoire", ""]]:
		f.goto("ARSENAL", "loot_weapon0")
		var items: Array = f._cur_row()["items"]
		for i in items.size():
			if items[i].has("loot") and items[i]["loot"]["base"] == e[0] and (e[1] == "" or items[i]["loot"]["uid"] == e[1]):
				f._cursor["loot_weapon0"] = i
				break
		f._refresh()
		await get_tree().create_timer(3.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + "forge_arsenal_%s.png" % e[0])
		print("[couleurs] forge ", e[0])
	get_tree().quit()
