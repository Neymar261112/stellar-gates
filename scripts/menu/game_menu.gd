extends CanvasLayer
## GameMenu (autoload) : le MENU DU JEU, façon Anthem. Bouton Vue (les deux carrés) ou Échap, partout où
## l'on pilote le Solaris (Terre, expéditions). Même style que la Forge, mais on y CONSULTE seulement :
## l'équipement se change à la Forge de l'Atelier (décision de cyril, 28 oct). Start reste la pause tactique.
## Onglets : ÉQUIPEMENT (loadout, puissance, bonus), INVENTAIRE (butin, verrouiller, marquer à recycler),
## PILOTE (niveau, déblocages), DÉFIS, CARTE, OPTIONS (volume, plein écran, quitter).
## Manette : LB / RB onglets, stick ou croix pour parcourir, A valider, X verrouiller, Y marquer, B fermer.
## Clavier : E / R ou Page préc. / suiv. onglets, ZQSD ou flèches, Entrée, X, C, Échap.

const TABS := ["ÉQUIPEMENT", "INVENTAIRE", "PILOTE", "DÉFIS", "CARTE", "OPTIONS"]
const FILTERS := [["TOUT", ""], ["ARMES", "weapon"], ["CAPACITÉS", "ability"], ["COMPOSANTS", "component"]]
const OPTIONS_FILE := "user://options.json"
const LIST_ROWS := 15

const GOLD := Color(1.0, 0.8, 0.4)
const ORANGE := Color(1.0, 0.58, 0.16)
const BLUE := Color(0.35, 0.68, 1.0)
const MUTED := Color(0.6, 0.66, 0.74)
const LOCKED := Color(0.4, 0.43, 0.48)
const PANEL_BG := Color(0.025, 0.05, 0.085, 0.86)
const PANEL_EDGE := Color(0.3, 0.6, 0.95, 0.5)
const ROW_ON := Color(0.08, 0.16, 0.26, 0.95)
const SLOT_NAMES := { "weapon0": "ARME 1", "weapon1": "ARME 2", "grenade": "GRENADE · LB", "launcher": "LANCEUR · RB",
	"comp0": "COMPOSANT 1", "comp1": "COMPOSANT 2", "comp2": "COMPOSANT 3", "comp3": "COMPOSANT 4", "comp4": "COMPOSANT 5", "comp5": "COMPOSANT 6" }

var is_open := false
var tab := 0
var filter := 0
var cursor := { 0: 0, 1: 0, 2: 0, 3: 0, 5: 0 }
var _scroll := 0
var options := { "volume": 1.0, "fullscreen": false }

var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _quit_confirm := false
var _rep_dir := Vector2i.ZERO
var _rep_t := 0.0
var _toast_t := 0.0

var _root: Control
var _tabs_box: HBoxContainer
var _pilot: Label
var _where: Label
var _help: Label
var _body: Control
var _toast: Label


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_options()
	_build()
	visible = false


# ---------------------------------------------------------------- ouverture
func can_open() -> bool:
	var cs := get_tree().current_scene
	return cs != null and not get_tree().paused and cs.get_node_or_null("Player") != null


func open(t := -1) -> void:
	if is_open:
		return
	is_open = true
	if t >= 0:
		tab = t
	_quit_confirm = false
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	visible = true
	_rep_dir = _held_dir()          # le stick tenu à l'ouverture ne fait pas défiler
	_refresh()
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.15)


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = _mouse_before
	Progression.save()


func _input(event: InputEvent) -> void:
	if not is_open:
		if event.is_action_pressed("menu") and can_open():
			open()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return                          # l'interface gère les clics (onglets, lignes)
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("menu"):
		close()
		return
	if event.is_action_pressed("power1"):
		_set_tab(tab - 1)
		return
	if event.is_action_pressed("power2"):
		_set_tab(tab + 1)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_PAGEUP: _set_tab(tab - 1)
			KEY_PAGEDOWN: _set_tab(tab + 1)
			KEY_BACKSPACE: close()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _accept()
			KEY_X: _x()
			KEY_C: _y()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B: close()
			JOY_BUTTON_A: _accept()
			JOY_BUTTON_X: _x()
			JOY_BUTTON_Y: _y()
			JOY_BUTTON_DPAD_UP: _nav(Vector2i(0, -1))
			JOY_BUTTON_DPAD_DOWN: _nav(Vector2i(0, 1))
			JOY_BUTTON_DPAD_LEFT: _nav(Vector2i(-1, 0))
			JOY_BUTTON_DPAD_RIGHT: _nav(Vector2i(1, 0))


## Stick gauche, ZQSD et flèches : un pas, puis répétition si on maintient.
func _held_dir() -> Vector2i:
	var y := int(Input.get_action_strength("move_back") > 0.5) - int(Input.get_action_strength("move_forward") > 0.5)
	var x := int(Input.get_action_strength("move_right") > 0.5) - int(Input.get_action_strength("move_left") > 0.5)
	return Vector2i(0, y) if y != 0 else Vector2i(x, 0)


func _process(delta: float) -> void:
	if not is_open:
		return
	var d := _held_dir()
	if d != _rep_dir:
		_rep_dir = d
		_rep_t = 0.38
		if d != Vector2i.ZERO:
			_nav(d)
	elif d != Vector2i.ZERO:
		_rep_t -= delta
		if _rep_t <= 0.0:
			_rep_t = 0.08
			_nav(d)
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)


# ---------------------------------------------------------------- actions
func _set_tab(t: int) -> void:
	tab = wrapi(t, 0, TABS.size())
	_quit_confirm = false
	_scroll = 0
	_refresh()


func _nav(d: Vector2i) -> void:
	match TABS[tab]:
		"INVENTAIRE":
			if d.x != 0:
				filter = wrapi(filter + d.x, 0, FILTERS.size())
				cursor[1] = 0
			else:
				cursor[1] = clampi(cursor[1] + d.y, 0, maxi(0, _inv_items().size() - 1))
		"ÉQUIPEMENT":
			cursor[0] = clampi(cursor[0] + d.y, 0, Inventory.ALL_SLOTS.size() - 1)
		"PILOTE":
			cursor[2] = clampi(cursor[2] + d.y, 0, maxi(0, _reward_levels().size() - 1))
		"DÉFIS":
			cursor[3] = clampi(cursor[3] + d.y, 0, maxi(0, Progression.challenges().size() - 1))
		"OPTIONS":
			if d.y != 0:
				cursor[5] = clampi(cursor[5] + d.y, 0, 3)
				_quit_confirm = false
			elif cursor[5] == 0:
				_set_volume(float(options["volume"]) + 0.1 * d.x)
			elif cursor[5] == 1:
				_set_fullscreen(not options["fullscreen"])
		_:
			return
	_refresh()


func _accept() -> void:
	match TABS[tab]:
		"ÉQUIPEMENT", "INVENTAIRE":
			_toast_msg("En mission, on consulte. Pour changer d'équipement : la Forge de l'Atelier, sur l'Aster.")
		"OPTIONS":
			match cursor[5]:
				1: _set_fullscreen(not options["fullscreen"])
				2: close()
				3:
					if _quit_confirm:
						Progression.save()
						get_tree().quit()
					else:
						_quit_confirm = true
						_toast_msg("A encore une fois pour quitter le jeu (la progression est sauvegardée).")
						_refresh()


func _x() -> void:
	var it := _inv_current()
	if TABS[tab] != "INVENTAIRE" or it.is_empty():
		return
	var locked := Inventory.toggle_lock(it["uid"])
	_toast_msg("Verrouillé : il ne sera pas recyclé" if locked else "Déverrouillé")
	_refresh()


func _y() -> void:
	var it := _inv_current()
	if TABS[tab] != "INVENTAIRE" or it.is_empty():
		return
	if it.get("locked", false):
		_toast_msg("Objet verrouillé : déverrouille-le (X) avant de le marquer")
		return
	if Inventory.is_equipped(it["uid"]):
		_toast_msg("Objet équipé : il ne peut pas être recyclé")
		return
	var junk := Inventory.toggle_junk(it["uid"])
	_toast_msg("Marqué à recycler : la Forge le recyclera (RECYCLAGE > les marqués)" if junk else "Marque retirée")
	_refresh()


func _toast_msg(t: String, secs := 2.6) -> void:
	_toast.text = t
	_toast_t = secs
	_toast.modulate.a = 1.0


# ---------------------------------------------------------------- options
func _load_options() -> void:
	if FileAccess.file_exists(OPTIONS_FILE):
		var f := FileAccess.open(OPTIONS_FILE, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else null
		if d is Dictionary:
			options["volume"] = clampf(float(d.get("volume", 1.0)), 0.0, 1.0)
			options["fullscreen"] = bool(d.get("fullscreen", false))
	_apply_options()


func _save_options() -> void:
	var f := FileAccess.open(OPTIONS_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(options, "\t"))


func _apply_options() -> void:
	var v := float(options["volume"])
	AudioServer.set_bus_mute(0, v <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001)))
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if options["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and (options["fullscreen"] or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(want)


func _set_volume(v: float) -> void:
	options["volume"] = clampf(snappedf(v, 0.1), 0.0, 1.0)
	_apply_options()
	_save_options()


func _set_fullscreen(on: bool) -> void:
	options["fullscreen"] = on
	_apply_options()
	_save_options()
	_refresh()


# ---------------------------------------------------------------- données
func _inv_items() -> Array:
	var cat: String = FILTERS[filter][1]
	var order := { "weapon": 0, "ability": 1, "component": 2 }
	var list := Inventory.items.filter(func(it): return cat == "" or LootDB.item_category(it) == cat)
	list.sort_custom(func(a, b):
		var ca: int = order.get(LootDB.item_category(a), 3)
		var cb: int = order.get(LootDB.item_category(b), 3)
		if ca != cb:
			return ca < cb
		if a["power"] != b["power"]:
			return a["power"] > b["power"]
		return a["rarity"] > b["rarity"])
	return list


func _inv_current() -> Dictionary:
	var list := _inv_items()
	if list.is_empty():
		return {}
	return list[clampi(cursor[1], 0, list.size() - 1)]


## Objet équipé avec lequel comparer (même emplacement) ; vide pour un composant.
func _compare_with(it: Dictionary) -> Dictionary:
	if LootDB.item_category(it) == "component":
		return {}
	for s in Inventory.WEAPON_SLOTS + Inventory.ABILITY_SLOTS:
		if Inventory.fits(s, it):
			var eq := Inventory.equipped_item(s)
			return {} if eq.get("uid", "") == it["uid"] else eq
	return {}


func _reward_levels() -> Array:
	var out := []
	for l in range(1, Progression.max_level() + 1):
		if Progression.reward_text(l) != "":
			out.append(l)
	return out


func _comp_level(slot: String) -> int:
	var idx := Inventory.COMP_SLOTS.find(slot)
	for l in range(1, Progression.max_level() + 1):
		if int(Progression.reward(l).get("comp_slots", 0)) > idx:
			return l
	return 99


func _world() -> Node:
	var cs := get_tree().current_scene
	var p := cs.get_node_or_null("Player") if cs else null
	return p.get("world") if p else null


# ---------------------------------------------------------------- construction
func _label(text: String, size: int, color: Color, wide := false) -> Label:
	return LootUI.label(text, size, color, wide)


func _place(c: Control, al: float, at: float, ar: float, ab: float, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


## Panneau façon Forge : [PanelContainer, VBoxContainer du contenu].
func _panel(title: String, info := "") -> Array:
	var p := PanelContainer.new()
	var sb := LootUI.box(PANEL_BG, PANEL_EDGE, 1, 4)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var h := HBoxContainer.new()
	var t := _label(title, 14, Color(0.85, 0.9, 0.97), true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if info != "":
		h.add_child(_label(info, 12, MUTED))
	v.add_child(h)
	var line := ColorRect.new()
	line.color = Color(PANEL_EDGE.r, PANEL_EDGE.g, PANEL_EDGE.b, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	return [p, v]


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = "shader_type canvas_item;\nvoid fragment() { float x = abs(UV.x - 0.5) * 2.0; COLOR = vec4(0.01, 0.025, 0.05, 0.86 + smoothstep(0.4, 1.0, x) * 0.1); }"
	dim.material = sm
	_root.add_child(dim)
	# Fines lignes d'interface (scanlines) pour l'ambiance HUD
	var scan := ColorRect.new()
	scan.set_anchors_preset(Control.PRESET_FULL_RECT)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ss := ShaderMaterial.new()
	ss.shader = Shader.new()
	ss.shader.code = "shader_type canvas_item;\nvoid fragment() { float l = step(0.5, fract(FRAGCOORD.y / 3.0)); COLOR = vec4(0.3, 0.6, 1.0, l * 0.025); }"
	scan.material = ss
	_root.add_child(scan)
	# En-tête : losange, titre, onglets, pilote
	var logo := Panel.new()
	logo.add_theme_stylebox_override("panel", LootUI.box(Color(0.05, 0.1, 0.16, 0.9), BLUE, 2, 4))
	logo.size = Vector2(38, 38)
	logo.position = Vector2(38, 18)
	logo.rotation = PI / 4
	logo.pivot_offset = Vector2(19, 19)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(logo)
	var core := ColorRect.new()
	core.color = ORANGE
	core.size = Vector2(12, 12)
	core.position = Vector2(13, 13)
	logo.add_child(core)
	var title := _label("RANGER", 34, Color.WHITE, true)
	title.position = Vector2(92, 8)
	_root.add_child(title)
	_root.add_child(_at(_label("MENU DU PILOTE · CONSULTATION", 12, MUTED, true), Vector2(94, 52)))
	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 0)
	_tabs_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_place(_tabs_box, 0.5, 0, 0.5, 0, -420, 16, 420, 58)
	_root.add_child(_tabs_box)
	_pilot = _label("", 20, Color.WHITE, true)
	_pilot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_pilot, 1, 0, 1, 0, -420, 10, -24, 36)
	_root.add_child(_pilot)
	_where = _label("", 13, MUTED)
	_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_where, 1, 0, 1, 0, -420, 38, -24, 58)
	_root.add_child(_where)
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_body, 0, 0, 1, 1, 20, 92, -20, -52)
	_root.add_child(_body)
	_help = _label("", 13, MUTED)
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_help, 0, 1, 1, 1, 20, -40, -20, -14)
	_root.add_child(_help)
	_toast = _label("", 19, GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_place(_toast, 0.5, 1, 0.5, 1, -520, -84, 520, -52)
	_root.add_child(_toast)


func _at(c: Control, pos: Vector2) -> Control:
	c.position = pos
	return c


func _key_chip(t: String) -> Control:
	var p := PanelContainer.new()
	var sb := LootUI.box(Color(0.1, 0.14, 0.2, 0.95), Color(0.55, 0.62, 0.72), 1, 4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(_label(t, 12, Color.WHITE, true))
	return p


func _draw_tabs() -> void:
	for ch in _tabs_box.get_children():
		ch.queue_free()
	_tabs_box.add_child(_key_chip("LB"))
	for i in TABS.size():
		var on := i == tab
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.16, 0.26, 0.6) if on else Color(0, 0, 0, 0)
		sb.border_color = GOLD
		sb.border_width_bottom = 3 if on else 0
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		p.add_theme_stylebox_override("panel", sb)
		var txt: String = TABS[i]
		if txt == "INVENTAIRE" and Inventory.unseen_count() > 0:
			txt += "  ●"
		p.add_child(_label(txt, 14, Color.WHITE if on else MUTED, true))
		p.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _set_tab(i))
		_tabs_box.add_child(p)
	_tabs_box.add_child(_key_chip("RB"))


# ---------------------------------------------------------------- dessin
func _refresh() -> void:
	if _root == null:
		return
	_draw_tabs()
	_pilot.text = "PILOTE %d · PUISSANCE %d" % [Progression.level, BuildStats.exo_power()]
	var w := _world()
	var place := "Terre · base Horizon"
	if w != null and w.get("def") is Dictionary:
		place = "Expédition · %s" % w.def.get("name", "")
	elif get_tree().current_scene and get_tree().current_scene.scene_file_path.ends_with("elyra_clairiere.tscn"):
		place = "Expédition · clairière d'Élyra"
	_where.text = "%s · %s" % [place, Progression.difficulty_def().get("name", "")]
	for ch in _body.get_children():
		_body.remove_child(ch)
		ch.queue_free()
	match TABS[tab]:
		"ÉQUIPEMENT": _draw_equipment()
		"INVENTAIRE": _draw_inventory()
		"PILOTE": _draw_pilot()
		"DÉFIS": _draw_challenges()
		"CARTE": _draw_map_tab()
		"OPTIONS": _draw_options()
	var help := {
		"ÉQUIPEMENT": "↕ parcourir les emplacements  ·  A : où changer d'équipement  ·  B : fermer",
		"INVENTAIRE": "↔ filtrer  ·  ↕ parcourir  ·  X : verrouiller  ·  Y (C) : marquer à recycler  ·  B : fermer",
		"PILOTE": "↕ parcourir les déblocages  ·  B : fermer",
		"DÉFIS": "↕ parcourir les défis  ·  B : fermer",
		"CARTE": "B : fermer",
		"OPTIONS": "↕ choisir  ·  ↔ régler  ·  A : valider  ·  B : fermer",
	}
	_help.text = "LB / RB : onglets  ·  " + help[TABS[tab]]


func _row_box(on: bool, edge := BLUE) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := LootUI.box(ROW_ON if on else Color(0.04, 0.07, 0.11, 0.7), edge if on else Color(0.2, 0.3, 0.42, 0.4), 2 if on else 1, 3)
	sb.content_margin_left = 0
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _click_row(p: Control, t: int, i: int) -> void:
	p.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			cursor[t] = i
			_refresh())


func _item_row(it: Dictionary, label_left: String, on: bool, tags := "") -> PanelContainer:
	var p := _row_box(on)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var rc := LootDB.rarity_color(int(it["rarity"])) if not it.is_empty() else LOCKED
	var bar := ColorRect.new()
	bar.color = rc
	bar.custom_minimum_size = Vector2(4, 0)
	h.add_child(bar)
	if label_left != "":
		var sl := _label(label_left, 11, MUTED, true)
		sl.custom_minimum_size = Vector2(130, 0)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sl)
	if it.is_empty():
		var e := _label(tags, 14, LOCKED)
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(e)
		return p
	h.add_child(LootUI.symbol(it, 19, rc))
	var n := _label(LootDB.item_name(it), 16, rc if int(it["rarity"]) >= 4 else Color.WHITE)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	h.add_child(n)
	if tags != "":
		h.add_child(_label(tags, 11, GOLD, true))
	var pw := _label("%d" % int(it["power"]), 17, Color.WHITE, true)
	pw.custom_minimum_size = Vector2(40, 0)
	pw.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pw)
	return p


func _tags(it: Dictionary) -> String:
	var t := []
	if not it.get("seen", false):
		t.append("NOUVEAU")
	if Inventory.is_equipped(it["uid"]):
		t.append("ÉQUIPÉ")
	if it.get("locked", false):
		t.append("VERROUILLÉ")
	if it.get("junk", false):
		t.append("À RECYCLER")
	return "  ".join(t)


func _draw_equipment() -> void:
	var left: Array = _panel("ÉQUIPEMENT · %s" % _loadout_name(), "à changer à la Forge")
	_place(left[0], 0, 0, 0, 1, 0, 0, 620, 0)
	_body.add_child(left[0])
	var v: VBoxContainer = left[1]
	var sections := [["ARMES", Inventory.WEAPON_SLOTS], ["CAPACITÉS", Inventory.ABILITY_SLOTS],
		["COMPOSANTS · %d / 6 OUVERTS" % Progression.comp_slots(), Inventory.COMP_SLOTS]]
	var i := 0
	for sec in sections:
		v.add_child(_label(sec[0], 12, GOLD, true))
		for s in sec[1]:
			var on: bool = i == cursor[0]
			var it := Inventory.equipped_item(s)
			var empty_txt := "— vide —"
			if not Inventory.slot_open(s):
				empty_txt = "VERROUILLÉ · niveau pilote %d" % _comp_level(s) if s in Inventory.COMP_SLOTS else "VERROUILLÉ · Noyau Horizon (niveau pilote 3)"
				it = {}
			var row := _item_row(it, SLOT_NAMES[s], on, empty_txt if it.is_empty() else "")
			_click_row(row, 0, i)
			v.add_child(row)
			i += 1
	# Centre : puissance, bonus, systèmes
	var mid: Array = _panel("PUISSANCE DE L'EXO")
	_place(mid[0], 0, 0, 1, 1, 640, 0, -560, 0)
	_body.add_child(mid[0])
	var mv: VBoxContainer = mid[1]
	var big := _label("%d" % BuildStats.exo_power(), 64, Color.WHITE, true)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(big)
	var dl := _label("moyenne des objets équipés", 11, MUTED)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(dl)
	mv.add_child(_label("BONUS DE L'EXO", 12, GOLD, true))
	var keys := BuildStats.totals.keys()
	keys.sort()
	if keys.is_empty():
		mv.add_child(_label("Aucun bonus global : les inscriptions des objets s'ajoutent ici.", 12, MUTED))
	for k in keys:
		if absf(float(BuildStats.totals[k])) > 0.0005:
			mv.add_child(_label(LootDB.describe(k, float(BuildStats.totals[k])), 14, Color(0.45, 0.95, 0.5)))
	mv.add_child(_label("SYSTÈMES DU SOLARIS", 12, GOLD, true))
	for s in Loadout.SLOTS:
		var h := HBoxContainer.new()
		var a := _label(Loadout.SLOT_NAMES[s].to_upper(), 11, MUTED, true)
		a.custom_minimum_size = Vector2(130, 0)
		h.add_child(a)
		h.add_child(_label(Loadout.part(s)["name"], 14, [Color(0.75, 0.75, 0.75), BLUE, GOLD][clampi(int(Loadout.tier[s]), 0, 2)]))
		mv.add_child(h)
	# Droite : fiche de l'objet sous le curseur
	var slot: String = Inventory.ALL_SLOTS[cursor[0]]
	var it := Inventory.equipped_item(slot) if Inventory.slot_open(slot) else {}
	var holder := VBoxContainer.new()
	_place(holder, 1, 0, 1, 1, -540, 0, 0, 0)
	_body.add_child(holder)
	if it.is_empty():
		var e: Array = _panel(SLOT_NAMES[slot])
		e[1].add_child(_label("Emplacement vide." if Inventory.slot_open(slot) else "Emplacement verrouillé : il s'ouvre en montant en niveau pilote.", 14, MUTED))
		holder.add_child(e[0])
	else:
		Inventory.mark_seen(it["uid"])
		holder.add_child(LootUI.card(it, {}, 540.0, SLOT_NAMES[slot] + " · ÉQUIPÉ"))


func _loadout_name() -> String:
	var lo: Array = Loadout.loadouts.get(Loadout.mode, [])
	if Loadout.active_loadout < lo.size():
		return String(lo[Loadout.active_loadout].get("name", "")).to_upper()
	return ""


func _draw_inventory() -> void:
	var list := _inv_items()
	cursor[1] = clampi(cursor[1], 0, maxi(0, list.size() - 1))
	var left: Array = _panel("INVENTAIRE", "%d objets · %d marqués à recycler" % [Inventory.items.size(), Inventory.junk_count()])
	_place(left[0], 0, 0, 0, 1, 0, 0, 760, 0)
	_body.add_child(left[0])
	var v: VBoxContainer = left[1]
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	for f in FILTERS.size():
		var on := f == filter
		var n := Inventory.items.filter(func(it): return FILTERS[f][1] == "" or LootDB.item_category(it) == FILTERS[f][1]).size()
		var c := PanelContainer.new()
		var sb := LootUI.box(Color(0.08, 0.16, 0.26, 0.9) if on else Color(0.04, 0.07, 0.11, 0.7), GOLD if on else Color(0.2, 0.3, 0.42, 0.5), 1, 12)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		c.add_theme_stylebox_override("panel", sb)
		c.add_child(_label("%s  %d" % [FILTERS[f][0], n], 12, Color.WHITE if on else MUTED, true))
		c.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: filter = f; cursor[1] = 0; _refresh())
		chips.add_child(c)
	v.add_child(chips)
	if list.is_empty():
		v.add_child(_label("Rien ici pour l'instant : le butin des expéditions arrive dans l'inventaire.", 14, MUTED))
	# Fenêtre de défilement qui suit le curseur
	if cursor[1] < _scroll:
		_scroll = cursor[1]
	elif cursor[1] >= _scroll + LIST_ROWS:
		_scroll = cursor[1] - LIST_ROWS + 1
	_scroll = clampi(_scroll, 0, maxi(0, list.size() - LIST_ROWS))
	if _scroll > 0:
		v.add_child(_label("▲ %d de plus" % _scroll, 11, MUTED))
	for i in range(_scroll, mini(list.size(), _scroll + LIST_ROWS)):
		var row := _item_row(list[i], "", i == cursor[1], _tags(list[i]))
		_click_row(row, 1, i)
		v.add_child(row)
	if list.size() > _scroll + LIST_ROWS:
		v.add_child(_label("▼ %d de plus" % (list.size() - _scroll - LIST_ROWS), 11, MUTED))
	# Centre : matériaux
	var mid: Array = _panel("MATÉRIAUX")
	_place(mid[0], 0, 0, 1, 0, 780, 0, -560, 200)
	_body.add_child(mid[0])
	for k in Inventory.materials:
		var h := HBoxContainer.new()
		var n := _label(LootDB.material(k).get("name", k), 14, Color(0.85, 0.9, 0.97))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(_label("%d" % int(Inventory.materials[k]), 16, Color.WHITE, true))
		mid[1].add_child(h)
	var rar: Array = _panel("PAR RARETÉ")
	_place(rar[0], 0, 0, 1, 0, 780, 216, -560, 470)
	_body.add_child(rar[0])
	for r in range(5, -1, -1):
		var n := Inventory.items.filter(func(it): return int(it["rarity"]) == r).size()
		var h := HBoxContainer.new()
		var a := _label("◆ " + LootDB.rarity_name(r), 13, LootDB.rarity_color(r))
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(_label("%d" % n, 14, Color.WHITE, true))
		rar[1].add_child(h)
	# Droite : fiche comparée
	var it := _inv_current()
	if it.is_empty():
		return
	Inventory.mark_seen(it["uid"])
	var other := _compare_with(it)
	var title := "ÉQUIPÉ" if Inventory.is_equipped(it["uid"]) else ("COMPARÉ À : " + LootDB.item_name(other) if not other.is_empty() else "FICHE")
	var card := LootUI.card(it, other, 540.0, title)
	_place(card, 1, 0, 1, 0, -540, 0, 0, 0)
	_body.add_child(card)


func _draw_pilot() -> void:
	var left: Array = _panel("PILOTE")
	_place(left[0], 0, 0, 0.5, 1, 0, 0, -10, 0)
	_body.add_child(left[0])
	var v: VBoxContainer = left[1]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var lv := _label("%d" % Progression.level, 72, Color.WHITE, true)
	h.add_child(lv)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_child(_label("NIVEAU PILOTE · RANGER", 13, GOLD, true))
	var maxed := Progression.level >= Progression.max_level()
	var need := Progression.xp_to_next()
	hv.add_child(_bar(1.0 if maxed else float(Progression.xp) / float(need), BLUE, 10))
	hv.add_child(_label("NIVEAU MAXIMUM" if maxed else "%d / %d XP vers le niveau %d" % [Progression.xp, need, Progression.level + 1], 13, MUTED))
	h.add_child(hv)
	v.add_child(h)
	var pity: Dictionary = LootDB.tables()["pity"]
	for line in [
		["Difficulté des expéditions", Progression.difficulty_def().get("name", "")],
		["Expéditions terminées", "%d" % Progression.missions_done],
		["Garantie de légendaire", "%d / %d missions sans or" % [Progression.pity, int(pity["missions"])]],
		["Défis réussis", "%d / %d" % [Progression.challenges_done.size(), Progression.challenges().size()]],
	]:
		var r := HBoxContainer.new()
		var a := _label(line[0], 14, Color(0.85, 0.9, 0.97))
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(a)
		r.add_child(_label(line[1], 14, Color.WHITE, true))
		v.add_child(r)
	v.add_child(_label("SYSTÈMES DU SOLARIS", 12, GOLD, true))
	for s in Loadout.SLOTS:
		var r := HBoxContainer.new()
		var a := _label(Loadout.SLOT_NAMES[s].to_upper(), 11, MUTED, true)
		a.custom_minimum_size = Vector2(130, 0)
		r.add_child(a)
		var t := clampi(int(Loadout.tier[s]), 0, 2)
		var n := _label(Loadout.part(s)["name"], 15, [Color(0.75, 0.75, 0.75), BLUE, GOLD][t])
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(n)
		r.add_child(_label(Loadout.TIER_NAMES[t].to_upper(), 11, MUTED, true))
		v.add_child(r)
		var d := _label(Loadout.part(s).get("desc", ""), 12, MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		v.add_child(d)
	# Droite : déblocages par niveau
	var right: Array = _panel("DÉBLOCAGES DU NIVEAU PILOTE", "niveaux 1 à 10 : grand tutoriel")
	_place(right[0], 0.5, 0, 1, 1, 10, 0, 0, 0)
	_body.add_child(right[0])
	var levels := _reward_levels()
	var next_found := false
	for i in levels.size():
		var l: int = levels[i]
		var done := Progression.level >= l
		var nxt := not done and not next_found
		if nxt:
			next_found = true
		var row := _row_box(i == cursor[2], GOLD if nxt else BLUE)
		var rh := HBoxContainer.new()
		rh.add_theme_constant_override("separation", 12)
		rh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rh)
		var bar := ColorRect.new()
		bar.color = GOLD if done else (BLUE if nxt else LOCKED)
		bar.custom_minimum_size = Vector2(4, 0)
		rh.add_child(bar)
		var ln := _label("NIV %d" % l, 14, Color.WHITE if done or nxt else LOCKED, true)
		ln.custom_minimum_size = Vector2(70, 0)
		rh.add_child(ln)
		var tx := _label(Progression.reward_text(l), 14, Color(0.85, 0.9, 0.97) if done else (Color.WHITE if nxt else MUTED))
		tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tx.clip_text = true
		rh.add_child(tx)
		rh.add_child(_label("✓" if done else ("PROCHAIN" if nxt else ""), 12, GOLD if done else BLUE, true))
		_click_row(row, 2, i)
		right[1].add_child(row)


func _bar(f: float, color: Color, h := 8) -> Control:
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(0, h)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("panel", LootUI.box(Color(0.1, 0.14, 0.2), Color(0, 0, 0, 0), 0, 2))
	var fill := Panel.new()
	fill.add_theme_stylebox_override("panel", LootUI.box(color, color, 0, 2))
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(f, 0.0, 1.0)
	bar.add_child(fill)
	return bar


func _draw_challenges() -> void:
	var list := Progression.challenges()
	var p: Array = _panel("DÉFIS", "%d / %d réussis · récompense : XP pilote" % [Progression.challenges_done.size(), list.size()])
	_place(p[0], 0.5, 0, 0.5, 1, -520, 0, 520, 0)
	_body.add_child(p[0])
	for i in list.size():
		var c: Dictionary = list[i]
		var done: bool = c["id"] in Progression.challenges_done
		var prog := mini(Progression.challenge_progress(c), int(c["goal"]))
		var row := _row_box(i == cursor[3], GOLD if done else BLUE)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(h)
		var bar := ColorRect.new()
		bar.color = GOLD if done else BLUE
		bar.custom_minimum_size = Vector2(4, 0)
		h.add_child(bar)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 1)
		tv.custom_minimum_size = Vector2(380, 0)
		tv.add_child(_label(c["name"].to_upper(), 14, GOLD if done else Color.WHITE, true))
		tv.add_child(_label(c["desc"], 12, MUTED))
		h.add_child(tv)
		var bv := VBoxContainer.new()
		bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bv.alignment = BoxContainer.ALIGNMENT_CENTER
		bv.add_child(_bar(float(prog) / float(c["goal"]), GOLD if done else BLUE))
		bv.add_child(_label("%d / %d" % [prog, int(c["goal"])], 12, MUTED))
		h.add_child(bv)
		var r := _label("✓ RÉUSSI" if done else "+%d XP" % int(c.get("xp", 0)), 13, GOLD if done else Color.WHITE, true)
		r.custom_minimum_size = Vector2(96, 0)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(r)
		_click_row(row, 3, i)
		p[1].add_child(row)


func _draw_map_tab() -> void:
	var w := _world()
	var has_grid: bool = w != null and w.get("grid") is Array and not (w.get("grid") as Array).is_empty()
	var title := "CARTE · " + (String(w.def.get("name", "")).to_upper() if has_grid else "INDISPONIBLE")
	var p: Array = _panel(title, "relevé du Solaris" if has_grid else "")
	_place(p[0], 0, 0, 1, 1, 0, 0, 0, 0)
	_body.add_child(p[0])
	if not has_grid:
		p[1].add_child(_label("Pas encore de relevé de cette zone. La carte s'affiche pendant les expéditions sur les planètes.", 15, MUTED))
		return
	var map := Control.new()
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.draw.connect(_draw_map.bind(map, w))
	p[1].add_child(map)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 22)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	for l in [["▲", Color.WHITE, "Solaris"], ["◆", GOLD, "Balises"], ["⬡", Color(0.55, 0.4, 1.0), "Arche"], ["●", Color(1.0, 0.42, 0.38), "Champ de tir"]]:
		var h := HBoxContainer.new()
		h.add_child(_label(l[0], 15, l[1]))
		h.add_child(_label(l[2], 13, MUTED))
		legend.add_child(h)
	p[1].add_child(legend)


func _draw_map(c: Control, w: Node) -> void:
	var grid: Array = w.grid
	var H := grid.size()
	var W := (grid[0] as String).length() if grid[0] is String else (grid[0] as Array).size()
	var cell := minf(c.size.x / W, c.size.y / H)
	var off := (c.size - Vector2(W, H) * cell) / 2.0
	var pal: Dictionary = w.def.get("palette", {})
	c.draw_rect(Rect2(off - Vector2(6, 6), Vector2(W, H) * cell + Vector2(12, 12)), Color(0.3, 0.6, 0.95, 0.35), false, 1.0)
	for j in H:
		for i in W:
			var t: String = grid[j][i]
			var col: Color = pal.get(t, Color(0.4, 0.4, 0.4))
			col = col.lerp(Color(0.05, 0.12, 0.2), 0.35)
			c.draw_rect(Rect2(off + Vector2(i, j) * cell, Vector2(cell, cell) + Vector2(0.6, 0.6)), col)
	var T: float = w.T
	var f := c.get_theme_default_font()
	for b in w.def.get("beacons", []):
		var pos: Vector2 = off + (Vector2(b["cell"]) + Vector2(0.5, 0.5)) * cell
		_diamond(c, pos, 7.0, GOLD)
		c.draw_string(f, pos + Vector2(10, 5), b.get("label", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)
	var ar: Dictionary = w.def.get("arche", {})
	if ar.has("cell"):
		var pos: Vector2 = off + (Vector2(ar["cell"]) + Vector2(0.5, 0.5)) * cell
		c.draw_circle(pos, 9.0, Color(0.55, 0.4, 1.0, 0.35))
		c.draw_arc(pos, 9.0, 0, TAU, 24, Color(0.7, 0.55, 1.0), 2.0)
		c.draw_string(f, pos + Vector2(12, 5), "Arche", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.62, 1.0))
	for t in w.def.get("targets", []):
		c.draw_circle(off + (Vector2(t["cell"]) + Vector2(0.5, 0.5)) * cell, 3.0, Color(1.0, 0.42, 0.38))
	var player := get_tree().current_scene.get_node_or_null("Player") as Node3D
	if player:
		var pp := off + Vector2(player.global_position.x, player.global_position.z) / T * cell
		var cam := get_viewport().get_camera_3d()
		var fwd := Vector2(0, -1)
		if cam:
			var z := -cam.global_transform.basis.z
			fwd = Vector2(z.x, z.z).normalized() if Vector2(z.x, z.z).length() > 0.01 else fwd
		var side := Vector2(-fwd.y, fwd.x)
		c.draw_circle(pp, 14.0, Color(1, 1, 1, 0.12))
		c.draw_colored_polygon(PackedVector2Array([pp + fwd * 11.0, pp - fwd * 7.0 + side * 7.0, pp - fwd * 3.0, pp - fwd * 7.0 - side * 7.0]), Color.WHITE)


func _diamond(c: Control, p: Vector2, r: float, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), col)


func _draw_options() -> void:
	var p: Array = _panel("OPTIONS")
	_place(p[0], 0.5, 0, 0.5, 0, -380, 0, 380, 330)
	_body.add_child(p[0])
	var rows := [
		["VOLUME GÉNÉRAL", "%d %%" % roundi(float(options["volume"]) * 100.0)],
		["PLEIN ÉCRAN", "OUI" if options["fullscreen"] else "NON"],
		["REPRENDRE LA PARTIE", ""],
		["QUITTER LE JEU", "A encore une fois pour confirmer" if _quit_confirm else "progression sauvegardée"],
	]
	for i in rows.size():
		var row := _row_box(i == cursor[5], Color(1.0, 0.42, 0.38) if i == 3 and _quit_confirm else BLUE)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(h)
		var bar := ColorRect.new()
		bar.color = BLUE if i == cursor[5] else LOCKED
		bar.custom_minimum_size = Vector2(4, 0)
		h.add_child(bar)
		var n := _label(rows[i][0], 16, Color.WHITE, true)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		if i == 0:
			var b := _bar(float(options["volume"]), BLUE, 8)
			b.custom_minimum_size = Vector2(220, 8)
			b.size_flags_horizontal = Control.SIZE_SHRINK_END
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(b)
		h.add_child(_label(rows[i][1], 14, GOLD if i == 3 and _quit_confirm else MUTED))
		row.custom_minimum_size = Vector2(0, 48)
		_click_row(row, 5, i)
		p[1].add_child(row)
	var hint := _label("Manette façon Anthem : Start = pause tactique · Vue = ce menu · la Forge de l'Atelier sert à changer d'équipement.", 12, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	p[1].add_child(hint)
