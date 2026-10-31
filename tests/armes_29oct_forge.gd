extends Node
## Captures de la Forge, onglet ARSENAL, avec les armes du 29 oct sous le curseur (fiche de l'objet).
## Lancer (fenêtre affichée) : godot --path . tests/armes_29oct_forge.tscn  -> videos/armes_29oct/forge_*.png
var f: Node3D
const OUT := "res://videos/armes_29oct/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	f = load("res://scenes/atelier.tscn").instantiate()
	add_child(f)
	await get_tree().create_timer(14.0).timeout
	Inventory.demo()
	for e in [["loot_weapon0", "tacticien"], ["loot_weapon0", "minuit"], ["loot_weapon0", "repetiteur"], ["loot_weapon0", "ivoire"],
			["loot_weapon1", "titan"], ["loot_weapon1", "sentinelle"], ["loot_weapon1", "silencieux"]]:
		f.goto("ARSENAL", e[0])
		var items: Array = f._cur_row()["items"]
		for i in items.size():
			if items[i].has("loot") and items[i]["loot"]["base"] == e[1]:
				f._cursor[e[0]] = i
				break
		f._refresh()
		# le modèle de la fiche tourne (un tour en 9 s) : à 3,4 s on le voit de 3/4
		await get_tree().create_timer(3.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + "forge_%s.png" % e[1])
		print("[armes] forge ", e[1])
	get_tree().quit()
