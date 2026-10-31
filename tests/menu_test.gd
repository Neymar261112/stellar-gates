extends Node
## Test automatique du menu du jeu (sans écran) : godot --headless --path . tests/menu_test.tscn
## Ouverture par Vue / Échap, six onglets, consultation seule (rien ne s'équipe), verrou et marquage
## « à recycler », recyclage des marqués à la Forge, défis, pause tactique sans équipement.

var fails := 0


func check(cond: bool, what: String) -> void:
	print(("[menu] OK   " if cond else "[menu] ÉCHEC ") + what)
	if not cond:
		fails += 1


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _ready() -> void:
	Appearance.persist = false
	Progression.reset_for_test()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for b in ["avantgarde", "vipers", "givre", "lance", "tuyeres", "lentille"]:
		Inventory.add(LootRoll.make(rng, b, rng.randi_range(1, 5), 4, "Test"))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(1.5).timeout
	get_tree().current_scene = main
	Expedition.enabled = false
	check(not GameMenu.is_open and GameMenu.can_open(), "en jeu, le menu peut s'ouvrir")
	await press("menu")
	check(GameMenu.is_open and get_tree().paused, "Vue / Échap ouvre le menu et fige le jeu")
	for t in GameMenu.TABS.size():
		GameMenu._set_tab(t)
		await get_tree().process_frame
		check(GameMenu._body.get_child_count() > 0, "onglet %s dessiné" % GameMenu.TABS[t])
	# Inventaire : consulter, verrouiller, marquer
	GameMenu._set_tab(1)
	var before := Inventory.equipped.duplicate()
	var free_it: Dictionary = {}
	for i in GameMenu._inv_items().size():
		if not Inventory.is_equipped(GameMenu._inv_items()[i]["uid"]):
			GameMenu.cursor[1] = i
			free_it = GameMenu._inv_items()[i]
			break
	GameMenu._accept()
	check(Inventory.equipped == before, "A dans l'inventaire n'équipe rien (consultation)")
	GameMenu._y()
	check(free_it.get("junk", false), "Y marque l'objet « à recycler »")
	GameMenu._x()
	check(free_it.get("locked", false) and not free_it.get("junk", false), "X verrouille et retire la marque")
	GameMenu._y()
	check(not free_it.get("junk", false), "un objet verrouillé ne se marque pas")
	GameMenu._x()
	GameMenu._y()
	check(free_it.get("junk", false), "déverrouillé puis marqué")
	GameMenu._nav(Vector2i(1, 0))
	check(GameMenu.filter == 1 and GameMenu._inv_items().all(func(it): return LootDB.item_category(it) == "weapon"), "filtre ARMES")
	GameMenu.filter = 0
	# Carte : le monde d'expédition est relevé
	check(GameMenu._world() != null and GameMenu._world().get("grid") is Array, "la carte trouve le relevé d'Élyra")
	# Fermeture
	await press("menu")
	check(not GameMenu.is_open and not get_tree().paused, "Vue / Échap referme et relance le jeu")
	# Recyclage des marqués (Forge)
	var n_before := Inventory.items.size()
	var gain := Inventory.salvage_marked()
	check(int(gain.get("_count", 0)) == 1 and Inventory.items.size() == n_before - 1, "la Forge recycle les objets marqués")
	check(int(Progression.stats.get("salvaged", 0)) == 1, "le recyclage compte pour les défis")
	# Défis
	var lvl := Progression.level
	var xp := Progression.xp
	Progression.count("kills", 50)
	check("chasseur" in Progression.challenges_done, "défi Chasseur réussi à 50 ennemis")
	check(Progression.level > lvl or Progression.xp > xp, "le défi verse son XP")
	Progression.count("kills", 1)
	check(Progression.challenges_done.count("chasseur") == 1, "un défi ne paie qu'une fois")
	# Pause tactique : consultation seulement
	var powers := Loadout.powers.duplicate()
	await press("pause")
	check(get_tree().paused, "Start ouvre la pause tactique")
	await press("arsenal_next")
	await press("power2")
	check(Loadout.powers == powers, "la pause tactique n'équipe plus rien")
	await press("menu")
	check(not get_tree().paused, "Vue / Échap ferme aussi la pause tactique")
	check(not GameMenu.is_open, "et n'ouvre pas le menu par-dessus")
	print("[menu] %s (%d échec%s)" % ["RÉUSSI" if fails == 0 else "ÉCHOUÉ", fails, "s" if fails > 1 else ""])
	get_tree().quit(1 if fails > 0 else 0)
