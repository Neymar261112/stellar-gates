extends Node
## Vidéo du menu du jeu : bouton Vue / Échap en pleine expédition, puis les six onglets (Équipement,
## Inventaire avec verrou et marquage, Pilote, Défis, Carte, Options), et retour au jeu.
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --write-movie out/f.png --fixed-fps 24 tests/showcase_menu.tscn
## Captures rapides des onglets : MENU_SHOTS=out/shots xvfb-run godot --path . --rendering-driver opengl3 tests/showcase_menu.tscn

var t := 0.0
var _done := {}
var _fade: ColorRect
var _title: Label
var main: Node
var player: CharacterBody3D


func _ready() -> void:
	Appearance.persist = false
	Appearance.reset()
	Progression.reset_for_test()
	Inventory.demo(7)
	Progression.level = 6
	Progression.xp = 820
	Progression.missions_done = 4
	Progression.pity = 3
	Progression.apply_systems(false)
	Progression.stats = { "kills": 37, "crates": 6, "missions": 4, "salvaged": 9, "masterworks": 2 }
	Progression.challenges_done = ["premiere_expedition"]
	for s in Inventory.ALL_SLOTS:
		var best: Array = Inventory.compatible(s).filter(func(it): return not Inventory.is_equipped(it["uid"]) or Inventory.slot_of(it["uid"]) == s)
		if not best.is_empty() and Inventory.slot_open(s):
			Inventory.equip(s, best[0]["uid"])
	Inventory.changed.emit()
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	var layer := CanvasLayer.new()
	layer.layer = 50
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title.add_theme_constant_override("outline_size", 8)
	_title.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_title.offset_left = -600
	_title.offset_right = 600
	_title.offset_top = -250
	_title.offset_bottom = -200
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_title)
	add_child(layer)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = main
	player = main.get_node("Player")
	var shots := OS.get_environment("MENU_SHOTS")
	if shots != "":
		_fade.color.a = 0.0
		await get_tree().create_timer(2.0).timeout
		DirAccess.make_dir_recursive_absolute(shots)
		GameMenu.open(0)
		for i in GameMenu.TABS.size():
			GameMenu._set_tab(i)
			if i == 1:
				GameMenu.cursor[1] = 3
				GameMenu._refresh()
			for f in 4:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s/tab%d.png" % [shots, i])
		GameMenu._set_tab(1)
		GameMenu.filter = 2
		GameMenu.cursor[1] = 1
		GameMenu._refresh()
		for f in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/abilities.png" % shots)
		get_tree().quit()


func at(time: float, key: String, f: Callable) -> void:
	if t >= time and not _done.has(key):
		_done[key] = true
		f.call()


func fade(to_alpha: float, dur: float) -> void:
	create_tween().tween_property(_fade, "color:a", to_alpha, dur)


func caption(text: String, secs := 3.0) -> void:
	_title.text = text
	_title.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_property(_title, "modulate:a", 0.0, 0.4)


func nav(d: Vector2i) -> void:
	GameMenu._nav(d)


func _process(delta: float) -> void:
	if OS.get_environment("MENU_SHOTS") != "" or player == null:
		return
	t += delta
	at(0.0, "in", func(): fade(0.0, 0.8))
	at(0.6, "cap", func(): caption("En expédition : bouton Vue (Échap) = menu du jeu", 2.4))
	at(3.2, "open", func(): GameMenu.open(0))
	# Équipement : on parcourt les emplacements
	for i in 5:
		at(4.4 + i * 0.5, "eq%d" % i, func(): nav(Vector2i(0, 1)))
	at(7.2, "eqA", func(): GameMenu._accept())
	# Inventaire
	at(9.6, "inv", func(): GameMenu._set_tab(1))
	for i in 8:
		at(10.4 + i * 0.3, "iv%d" % i, func(): nav(Vector2i(0, 1)))
	at(13.0, "lock", func(): GameMenu._x())
	at(14.2, "down", func(): nav(Vector2i(0, 1)))
	at(14.8, "junk", func(): GameMenu._y())
	at(16.6, "f1", func(): nav(Vector2i(1, 0)))
	at(17.6, "f2", func(): nav(Vector2i(1, 0)))
	at(18.2, "f2d", func(): nav(Vector2i(0, 1)))
	at(19.2, "f3", func(): nav(Vector2i(1, 0)))
	at(20.4, "f0", func(): nav(Vector2i(1, 0)))
	# Pilote
	at(21.4, "pil", func(): GameMenu._set_tab(2))
	for i in 6:
		at(22.4 + i * 0.4, "pl%d" % i, func(): nav(Vector2i(0, 1)))
	# Défis
	at(26.0, "def", func(): GameMenu._set_tab(3))
	for i in 3:
		at(27.0 + i * 0.5, "df%d" % i, func(): nav(Vector2i(0, 1)))
	# Carte
	at(29.6, "map", func(): GameMenu._set_tab(4))
	# Options
	at(33.0, "opt", func(): GameMenu._set_tab(5))
	at(34.0, "v1", func(): nav(Vector2i(-1, 0)))
	at(34.5, "v2", func(): nav(Vector2i(1, 0)))
	at(35.2, "o1", func(): nav(Vector2i(0, 1)))
	at(35.8, "o2", func(): nav(Vector2i(0, 1)))
	at(37.4, "close", func(): GameMenu.close())
	at(37.8, "cap2", func(): caption("B ou Vue : retour au jeu · changer d'équipement : la Forge", 2.6))
	at(40.6, "out", func(): fade(1.0, 0.6))
	at(41.4, "quit", func(): get_tree().quit())
