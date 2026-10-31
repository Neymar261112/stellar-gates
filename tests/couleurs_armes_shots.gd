extends Node
## Captures des couleurs d'armes (29 oct) : textures Meshy d'origine, lumières Énergie, liseré de rareté,
## Tacticien et Minuit réduits. Le Solaris épaule chaque arme (la Forge : tests/couleurs_armes_forge.tscn).
## Lancer (fenêtre affichée) : godot --path . tests/couleurs_armes_shots.tscn  -> videos/armes_29oct/couleurs/*.png
@onready var player: CharacterBody3D = $Main/Player
var cam: Camera3D
const OUT := "res://videos/armes_29oct/couleurs/"
## [id, emplacement, rareté]
const IDS := [["tacticien", 0, 2], ["minuit", 0, 2], ["titan", 1, 2], ["tacticien", 0, 5], ["sentinelle", 1, 4], ["vipers", 1, 3]]


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
	print("[couleurs] capture ", name)


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func frame(side_k: float, back_k: float, dist := 1.8, h := 1.3) -> void:
	var c: Vector3 = player.global_position + Vector3(0, h, 0)
	var fwd: Vector3 = -player.model.global_basis.z
	var right: Vector3 = player.model.global_basis.x
	cam.look_at_from_position(c + (fwd * (1.0 - back_k) - fwd * back_k + right * side_k).normalized() * dist + Vector3(0, 0.15, 0), c)


func _ready() -> void:
	Appearance.persist = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await wait(1.5)
	player.global_position = Vector3(23.75, 0.2, 76.25)
	player.cam_yaw = 0.0
	player.cam_pitch = 0.05
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 50.0
	await wait(0.8)
	cam.current = true
	var c = player.combat
	var rng := RandomNumberGenerator.new()
	for e in IDS:
		var it: Dictionary = Inventory.add(LootRoll.make(rng, e[0], e[2], 0, "Captures"))
		Inventory.equip("weapon%d" % e[1], it["uid"])
		if c.weapon_index != e[1]:
			c._select(e[1])
		Input.action_press("aim")
		await wait(0.9)
		var tag := "%s_%s" % [e[0], LootDB.rarity(e[2])["id"]]
		frame(1.0, 0.35)
		await shot(tag + "_vise_cote")
		frame(0.45, 0.0, 2.0)
		await shot(tag + "_vise_face")
		Input.action_release("aim")
		await wait(0.4)
	get_tree().quit()
