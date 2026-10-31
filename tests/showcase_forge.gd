extends Node
## Démo de la Forge (écran « FORGE RANGER ») avec le Solaris refait à partir de l'Aegis Sentinel (Meshy) :
## pièces, ensembles, couleurs, matériaux, curseur d'usure, presets, équipement et modes,
## puis sortie sur la Terre (animation d'arrivée, emotes, tir et vol aux couleurs du preset).
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --write-movie out/f.png --fixed-fps 24 tests/showcase_forge.tscn

var t := 0.0
var _done := {}
var f: Node3D
var terre: Node3D
var _cap: Label
var _fade: ColorRect


func _ready() -> void:
	Appearance.persist = false
	f = load("res://scenes/atelier.tscn").instantiate()
	add_child(f)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_cap = Label.new()
	_cap.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_cap.position = Vector2(-550, -250)
	_cap.size = Vector2(1100, 50)
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap.add_theme_font_size_override("font_size", 30)
	_cap.add_theme_color_override("font_color", Color(1, 1, 1))
	_cap.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_cap.add_theme_constant_override("outline_size", 10)
	layer.add_child(_cap)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func say(text: String) -> void:
	_cap.text = text


func at(time: float, key: String, fn: Callable) -> void:
	if t >= time and not _done.has(key):
		_done[key] = true
		fn.call()


func every(start: float, end: float, step: float, key: String, fn: Callable) -> void:
	if t < start or t > end:
		return
	var n := int((t - start) / step)
	at(start + n * step, "%s%d" % [key, n], fn)


## Le preset « Aegis » : le Solaris refait à partir du modèle Aegis Sentinel de cyril.
func aegis() -> void:
	for i in Appearance.presets["ranger"].size():
		if Appearance.presets["ranger"][i]["name"] == "Aegis":
			Appearance.load_preset(i)
	if f and is_instance_valid(f):
		f._refresh()


func nav_x(n: int) -> void:
	for i in absi(n):
		f._nav(Vector2i(signi(n), 0))


func _process(delta: float) -> void:
	t += delta
	if f and is_instance_valid(f):
		_forge()
	else:
		_outside()


func _forge() -> void:
	at(0.1, "start", func():
		aegis()
		f._toast_msg("", 0.1)
		say("Le Solaris refait à partir de ton Aegis Sentinel"))
	at(4.0, "bras", func():
		say("Tes bras gauche et droit « Exo Ranger »")
		f._want_focus = Vector3(0, 1.25, 0)
		f._want_dist = 2.4
		f._yaw = 0.6
		f.goto("APPARENCE", "piece_arms")
		for i in 6:
			if Appearance.piece("arms") == "ranger.exo.arms":
				break
			nav_x(1))
	at(7.5, "mech", func():
		say("Les pièces « Mech orange » se portent par-dessus")
		f._want_focus = Vector3(0, 1.05, 0)
		f._want_dist = 3.6
		f.goto("APPARENCE", "packs")
		for i in 8:
			if Appearance.piece("helmet") == "ranger.mech.helmet":
				break
			nav_x(1))
	at(10.5, "ens", func():
		say("Gauche / droite : on essaie en direct")
		aegis()
		f.goto("APPARENCE", "presets"))
	every(11.5, 16.0, 1.5, "ensc", func(): nav_x(1))
	at(17.0, "back", func():
		aegis()
		say("Peinture : 6 zones, une couleur chacune")
		f.goto("APPARENCE", "color"))
	every(17.8, 21.0, 0.5, "colc", func(): nav_x(1))
	at(21.4, "z2", func():
		f.goto("APPARENCE", "zone")
		nav_x(1))
	at(22.0, "z2c", func(): f.goto("APPARENCE", "color"))
	every(22.4, 24.4, 0.5, "colc2", func(): nav_x(-1))
	at(25.0, "mat", func():
		say("Matériaux : un type par zone")
		f.goto("APPARENCE", "mat"))
	every(25.6, 28.6, 0.7, "matc", func(): nav_x(1))
	at(29.5, "usure", func():
		aegis()
		say("Usure : un curseur, de neuf à vétéran")
		f._want_focus = Vector3(0, 1.3, 0)
		f._want_dist = 2.3
		f.goto("APPARENCE", "wear_amount")
		Appearance.set_wear_amount(0.0)
		f._refresh())
	every(30.2, 34.0, 0.2, "wearc", func(): f._nav(Vector2i(1, 0)))
	at(34.6, "weart", func():
		say("… et le type d'usure : sale, rayé, écaillé, usé")
		f._nav(Vector2i(0, 1)))
	every(35.2, 38.0, 0.9, "wtc", func(): nav_x(1))
	at(39.0, "presets", func():
		say("Préréglages : 10 looks par mode")
		f._want_focus = Vector3(0, 1.05, 0)
		f._want_dist = 3.8
		f.goto("PRÉRÉGLAGES", "presets_0"))
	every(39.8, 44.0, 1.4, "pc", func(): nav_x(1))
	at(44.6, "p0", func():
		aegis()
		f._refresh())
	at(45.5, "equip", func():
		say("Équipement : les stats ne viennent que d'ici")
		f.goto("SYSTÈMES", "comp_propulseurs"))
	every(46.2, 49.0, 0.7, "compc", func():
		nav_x(1)
		f._nav(Vector2i(0, 1)))
	at(49.8, "modes", func():
		say("Un Solaris, 4 modes : on change de mode ici seulement")
		f.goto(2, "modes"))
	every(50.6, 53.0, 0.8, "modec", func(): nav_x(1))
	at(53.6, "out", func():
		say("")
		aegis()
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, 0.6)
		tw.tween_callback(func():
			f.queue_free()
			f = null
			Appearance.came_from_atelier = true
			terre = load("res://scenes/terre.tscn").instantiate()
			add_child(terre)
			var p = terre.get_node("Player")
			p.camera.current = true
			p.cam_pitch = 0.3
			var tw2 := create_tween()
			tw2.tween_property(_fade, "color:a", 0.0, 0.6)))


func _outside() -> void:
	if terre == null:
		return
	var p = terre.get_node("Player")
	at(54.6, "o1", func(): say("Retour sur la Terre : animation d'arrivée du preset"))
	at(58.1, "o2", func():
		say("Emotes : croix de la manette ou 1 / 2 / 3")
		p.anim.play(Appearance.current["emotes"][0]))
	at(60.6, "o3", func(): p.anim.play(Appearance.current["emotes"][2]))
	at(63.2, "o4", func():
		say("Ton fusil Meshy, épaulé en visée, aux couleurs du preset")
		p.cam_yaw += 2.6
		Input.action_press("aim"))
	every(64.0, 65.6, 0.25, "fire", func(): p.combat.fire())
	at(66.0, "o5", func():
		Input.action_release("aim")
		say("Ta grenade Meshy (Brasier)")
		p.cam_yaw -= 2.6)
	at(66.6, "o5b", func(): p.combat._brasier())
	at(69.0, "o6", func():
		say("")
		p._fly_press())
	at(69.3, "o6b", func(): p._fly_press())
	at(69.4, "o7", func(): Input.action_press("move_forward"))
	at(74.0, "end", func():
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, 0.8))
	at(75.0, "quit", func(): get_tree().quit())
