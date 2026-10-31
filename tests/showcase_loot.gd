extends Node
## Vidéo du butin (étape 7) : diamants lâchés par les ennemis et les caisses (on ne voit que la rareté),
## écran de fin de mission (XP, niveau pilote, révélation), puis la Forge : Arsenal et comparaison,
## composants, recyclage, difficulté.
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --write-movie out/f.png --fixed-fps 24 tests/showcase_loot.tscn

var t := 0.0
var _done := {}
var _fade: ColorRect
var _title: Label
var _hold_yaw := INF
var _hold_pitch := INF
var _enemies: Array = []
var _forge: Node3D
var main: Node
var player: CharacterBody3D
const DROP_RARITIES := [1, 2, 3, 5]
const DROP_BASES := ["avantgarde", "givre", "avantgarde", "vipers"]


func _ready() -> void:
	Appearance.persist = false
	Appearance.reset()
	Progression.reset_for_test()
	Expedition.force = true
	Expedition.rng.seed = 5
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	player = main.get_node("Player")
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
	_title.anchor_left = 0.5
	_title.anchor_right = 0.5
	_title.anchor_top = 1.0
	_title.anchor_bottom = 1.0
	_title.offset_left = -600
	_title.offset_right = 600
	_title.offset_top = -250
	_title.offset_bottom = -200
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_title)
	add_child(layer)


func at(time: float, key: String, f: Callable) -> void:
	if t >= time and not _done.has(key):
		_done[key] = true
		f.call()


func fade(to_alpha: float, dur: float) -> void:
	create_tween().tween_property(_fade, "color:a", to_alpha, dur)


func title(text: String, secs := 2.6) -> void:
	_title.text = text
	_title.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_property(_title, "modulate:a", 0.0, 0.6)


func tp(pos: Vector3, yaw: float, pitch := 0.3) -> void:
	for a in ["move_forward", "aim", "fire"]:
		Input.action_release(a)
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.state = player.State.GROUND
	player.cam_yaw = yaw
	player.cam_pitch = pitch
	player.model.rotation.y = yaw
	player.pivot.rotation.y = yaw
	_hold_yaw = yaw
	_hold_pitch = pitch


func yaw_to(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)


func _spawn_enemies() -> void:
	var w: Node3D = main.world
	var fwd := Vector3(-sin(player.cam_yaw), 0, -cos(player.cam_yaw))
	var right := fwd.cross(Vector3.UP)
	var kinds := ["soldier", "soldier", "drone", "brute"]
	for i in kinds.size():
		var e := Enemy.new()
		var pos: Vector3 = player.global_position + fwd * (11.0 + i * 1.5) + right * (-4.5 + i * 3.0) + Vector3(0, 0.3, 0)
		if kinds[i] == "drone":
			pos.y += 4.0
		e.setup(kinds[i], pos)
		e.player = player
		w.add_child(e)
		_enemies.append(e)


func _kill(i: int) -> void:
	var e = _enemies[i]
	if not is_instance_valid(e) or not e.alive:
		return
	var pos: Vector3 = e.center()
	var parent: Node = e.get_parent()
	e.take_damage(99999.0, pos, false)
	# Pour la vidéo, on choisit la rareté du diamant (en jeu : tirage selon la table de l'ennemi)
	var it := LootRoll.roll(Expedition.rng, { "difficulty": Progression.difficulty, "rarity": DROP_RARITIES[i], "base": DROP_BASES[i], "category": LootDB.base(DROP_BASES[i])["category"], "mission": "Champ de tir d'Élyra" })
	LootDrop.spawn(parent, it, pos)


func _physics_process(delta: float) -> void:
	t += delta
	if _forge == null and player:
		if _hold_yaw != INF:
			player.cam_yaw = lerp_angle(player.cam_yaw, _hold_yaw, minf(1.0, delta * 5.0))
		if _hold_pitch != INF:
			player.cam_pitch = lerpf(player.cam_pitch, _hold_pitch, minf(1.0, delta * 4.0))
		var c = player.combat
		c.health = c.max_health
		c.shield = c.max_shield
	at(0.05, "setup", func():
		var start: Vector3 = main.world.start_position()
		tp(start, player.cam_yaw, 0.15)
		_spawn_enemies())
	at(0.6, "f0", func(): fade(0.0, 0.8); title("Les ennemis lâchent du butin : un diamant à la couleur de sa rareté"))
	at(1.4, "aim", func(): Input.action_press("aim"); Input.action_press("fire"))
	at(1.9, "k0", func(): _kill(0))
	at(2.5, "k1", func(): _kill(1))
	at(3.1, "k2", func(): _kill(2))
	at(3.8, "k3", func(): _kill(3))
	at(4.3, "walk", func():
		Input.action_release("fire")
		Input.action_release("aim")
		title("On ramasse en passant : seule la rareté s'affiche")
		Input.action_press("move_forward"))
	if _done.has("walk") and not _done.has("stop"):
		# On marche vers le diamant le plus proche
		var best: Node3D = null
		for d in get_tree().get_nodes_in_group("loot_drops"):
			if best == null or d.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
				best = d
		if best:
			_hold_yaw = yaw_to(player.global_position, best.global_position)
	at(9.0, "stop", func(): Input.action_release("move_forward"))
	at(9.2, "cut", func(): fade(1.0, 0.35))
	at(9.6, "crate", func():
		var p := Vector3(43.75, 0.3, 74.0)
		tp(p, yaw_to(p, Vector3(43.75, 0.3, 83.75)), 0.25)
		fade(0.0, 0.5)
		title("Les caisses d'Élyra : du butin au hasard (Peu commun ou mieux)")
		Input.action_press("move_forward"))
	at(11.6, "crate_stop", func(): Input.action_release("move_forward"))
	at(13.0, "end_mission", func():
		title("")
		Expedition.debrief_delay = 0.0
		Expedition.complete_mission("elyra"))
	# Écran de fin : on le laisse dérouler, puis la Forge
	at(26.0, "to_forge", func(): fade(1.0, 0.5))
	at(26.6, "forge", func():
		for a in ["move_forward", "aim", "fire"]:
			Input.action_release(a)
		if Expedition._debrief and is_instance_valid(Expedition._debrief):
			Expedition._debrief.queue_free()
		get_tree().paused = false
		Expedition.force = false
		main.queue_free()
		Appearance.return_to = "res://scenes/main.tscn"     # pas de mode démo : on garde le vrai butin
		Expedition.forge_tab = "ARSENAL"
		_forge = load("res://scenes/atelier.tscn").instantiate()
		add_child(_forge)
		fade(0.0, 0.6))
	if _forge == null:
		return
	var f = _forge
	at(27.4, "a0", func(): f.goto("ARSENAL", "loot_weapon0"); title("La Forge : l'Arsenal, triés par puissance", 3.0))
	at(29.2, "a1", func(): f._nav(Vector2i(-1, 0)); title("Comparaison avec l'arme équipée : vert = mieux, rouge = moins bien", 3.5))
	at(30.8, "a2", func(): f._nav(Vector2i(-1, 0)))
	at(32.4, "a3", func(): f._nav(Vector2i(-1, 0)))
	at(34.0, "a4", func(): f._accept(); title("A : équiper. La puissance de l'exo monte"))
	at(35.8, "g0", func(): f.goto("ARSENAL", "loot_grenade"); title("Capacités : amorce ou détonateur, le jeu prévient si on en perd une"))
	at(37.0, "g1", func(): f._nav(Vector2i(-1, 0)))
	at(38.4, "g2", func(): f._nav(Vector2i(-1, 0)))
	at(39.8, "c0", func(): f._main(1); title("Composants : bonus pour tout l'exo, emplacements ouverts par le niveau pilote"))
	at(41.2, "c1", func(): f._nav(Vector2i(1, 0)))
	at(42.4, "c2", func(): f._nav(Vector2i(1, 0)))
	at(43.6, "c3", func(): f._accept())
	at(45.0, "r0", func(): f._main(1); title("Recyclage : matériaux d'Arche (A deux fois)"))
	at(46.0, "r1a", func(): f._nav(Vector2i(1, 0)))
	at(46.4, "r1", func(): f._nav(Vector2i(1, 0)))
	at(47.4, "r2", func(): f._accept())
	at(48.0, "r3", func(): f._accept())
	at(49.6, "r4", func(): f.goto("RECYCLAGE", "salvage_bulk"); title("Ou en lot : tous les Communs d'un coup"))
	at(50.6, "r5", func(): f._accept())
	at(52.4, "s0", func(): f._main(1); f.goto("SYSTÈMES", "difficulty"); title("Systèmes du Solaris et difficulté : Grand Maître 1 à 3 plus tard"))
	at(53.8, "s1", func(): f._nav(Vector2i(1, 0)))
	at(54.8, "s2", func(): f._nav(Vector2i(1, 0)))
	at(55.8, "s3", func(): f._nav(Vector2i(1, 0)))
	at(57.6, "end", func(): fade(1.0, 0.8))
	at(58.6, "quit", func(): get_tree().quit())
