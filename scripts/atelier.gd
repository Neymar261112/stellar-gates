extends Node3D
## L'Atelier de l'Aster et la FORGE : le seul endroit où l'on change de mode, d'apparence et de loadout.
## Écran façon Anthem (image de référence de cyril) : en-tête « FORGE RANGER » et 4 onglets (LB / RB),
## une colonne à gauche et une à droite (LT / RT pour passer de l'une à l'autre), le Solaris au centre,
## la barre d'équipement et les statistiques en bas. Chaque ligne est une bande de vignettes rendues en 3D :
## haut / bas pour changer de ligne, gauche / droite pour essayer (aperçu immédiat), A pour valider.
## Lancer seule : ouvrir scenes/atelier.tscn puis F6 (tout est débloqué pour tester).
## Étape 7 (butin) : onglets ARSENAL (armes et capacités), COMPOSANTS, RECYCLAGE et SYSTÈMES (les 4 systèmes
## du Solaris débloqués par le niveau pilote, la difficulté et les loadouts). La colonne de droite y affiche
## la fiche de l'objet sous le curseur comparée à l'objet équipé (LootUI).

const GOLD := Color(1.0, 0.8, 0.4)
const ORANGE := Color(1.0, 0.58, 0.16)
const BLUE := Color(0.35, 0.68, 1.0)
const MUTED := Color(0.6, 0.66, 0.74)
const LOCKED := Color(0.4, 0.43, 0.48)
const PANEL_BG := Color(0.025, 0.05, 0.085, 0.8)
const PANEL_EDGE := Color(0.3, 0.6, 0.95, 0.5)
const CARD_BG := Color(0.05, 0.09, 0.14, 0.9)
# Habillage façon Anthem (polices Barlow, panneaux sans boîte, sélection blanche lumineuse)
const AnthemUI := preload("res://scripts/ui_anthem.gd")
const ACCENT := Color(0.66, 0.84, 1.0)
const DIM := Color(0.56, 0.63, 0.72)
const TILE_BG := Color(0.62, 0.76, 0.92, 0.06)

const TABS := ["ARSENAL", "COMPOSANTS", "RECYCLAGE", "SYSTÈMES", "APPARENCE", "MODES", "PRÉRÉGLAGES"]
const LOOT_TABS := ["ARSENAL", "COMPOSANTS", "RECYCLAGE"]
const SLOT_GLYPH := { "helmet": "◓", "chest": "▣", "arms": "◧", "legs": "◫" }

var tab := 4                       # onglet ouvert (APPARENCE par défaut, ARSENAL en revenant de mission)
var _salvage_confirm := ""         # objet à recycler : il faut appuyer deux fois sur A
var col := 0                       # colonne active : 0 gauche, 1 droite
var row_i := [0, 0]                # ligne active dans chaque colonne
var _cursor := {}                  # clé de ligne -> vignette sous le curseur
var _zone := 0                     # zone de peinture travaillée (Couleurs et Matériaux)
var _cols: Array = [[], []]        # colonne -> Array de sections { title, rows }
var _clipboard := ""
var _toast_t := 0.0
var _rep_t := 0.0
var _rep_dir := Vector2i.ZERO
var _lt_down := false
var _rt_down := false
var _idle := 0.0
var _leaving := false
var _dirty := true
var _dirty_t := 0.0
var standalone := true

# Caméra orbitale autour du socle
var cam: Camera3D
var _yaw := 0.0
var _pitch := 0.12
var _focus := Vector3(0, 1.05, 0)
var _dist := 3.8
var _want_focus := Vector3(0, 1.05, 0)
var _want_dist := 3.8
var _dragging := false
var _turn_back := false            # vinyle dans le dos : la caméra passe derrière

var solaris: CharacterBody3D
var _ring_mat: StandardMaterial3D
var _ring_light: OmniLight3D
var _weld: Node3D
var _weld_t := 0.0

# Interface
var _ui: CanvasLayer
var _root: Control
var _thumbs: ForgeThumbs
var _font_wide: FontVariation
var _title: Label
var _tabs_box: HBoxContainer
var _pilot: Label
var _preset_l: Label
var _help: Label
var _col_nodes: Array = []         # 2 VBoxContainer (gauche, droite)
var _equip_box: HBoxContainer
var _stats_box: VBoxContainer
var _toast: Label
var _fade: ColorRect
var _sil_shader: Shader
var _dof: CameraAttributesPractical
var _tab_line: Control             # trait sous l'onglet ouvert : il glisse d'un onglet à l'autre
var _tab_on: Control               # l'onglet ouvert (cible du trait)
var _last_sel := ""                # dernière vignette choisie : l'animation ne se joue qu'au changement
var _last_card := ""               # dernière fiche affichée à droite : elle glisse en entrant


func _ready() -> void:
	standalone = Appearance.return_to == ""
	if standalone:
		Appearance.persist = false      # lancé seul (F6) : tout débloqué pour tester, rien n'est sauvegardé
		Appearance.unlock_all()
		Loadout.set_all(2)
		Progression.persist = false     # idem pour le butin : arsenal de démonstration
		Progression.level = 12
		Inventory.demo()
	if Expedition.forge_tab != "":
		tab = maxi(0, TABS.find(Expedition.forge_tab))
		Expedition.forge_tab = ""
	Inventory.changed.connect(func(): _dirty = true)
	_build_room()
	_build_solaris()
	_build_dof()
	_thumbs = ForgeThumbs.new()
	_thumbs.name = "Thumbs"
	add_child(_thumbs)
	_thumbs.ready_thumb.connect(func(_k): _dirty = true)
	Appearance.changed.connect(func(_w): _dirty = true)
	_build_ui()
	_refresh()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.8)
	_toast_msg("Bienvenue à l'Atelier. Nadia : « Il est à toi, fais-le à ton goût. »", 3.5)


# ---------------------------------------------------------------- décor
func _mat(c: Color, rough := 0.6, metal := 0.4, glow := Color(0, 0, 0), energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = energy
	return m


func _box(size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


func _cyl(r: float, h: float, pos: Vector3, m: Material, top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r if top < 0.0 else top
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 48
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


func _build_room() -> void:
	# Intérieur de la Forge (halle, socle à gradins, anneau de maintenance, bras robots, postes, lumière
	# et air poussiéreux) : scenes/forge/forge_decor.tscn, chaque accessoire dans sa propre scène.
	var decor: Node3D = load("res://scenes/forge/forge_decor.tscn").instantiate()
	decor.name = "DecorForge"
	add_child(decor)
	_weld = decor.weld_tip
	# Anneau lumineux du plateau (couleur Énergie du preset)
	_ring_mat = _mat(Color(1, 0.8, 0.4), 0.3, 0.0, Color(1, 0.8, 0.4), 3.0)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.27
	tm.outer_radius = 1.33
	tm.rings = 64
	ring.mesh = tm
	ring.material_override = _ring_mat
	ring.position.y = 0.25
	add_child(ring)
	_ring_light = OmniLight3D.new()
	_ring_light.light_energy = 1.5
	_ring_light.omni_range = 4.0
	_ring_light.position.y = 0.4
	add_child(_ring_light)
	# Lumières du Solaris : clé chaude dorée, contre-jours froids (la douche bleue vient de l'anneau du décor)
	var key := SpotLight3D.new()
	key.light_color = Color(1.0, 0.84, 0.64)
	key.light_energy = 3.2
	key.light_volumetric_fog_energy = 0.25
	key.spot_range = 14.0
	key.spot_angle = 32.0
	key.shadow_enabled = true
	key.position = Vector3(-2.2, 4.5, -3.2)
	add_child(key)
	key.look_at(Vector3(0, 1.0, 0))
	for p in [Vector3(2.6, 3.0, 2.6), Vector3(-2.6, 2.6, 2.8)]:
		var rim := SpotLight3D.new()
		rim.light_color = Color(0.4, 0.65, 1.0)
		rim.light_energy = 4.0
		rim.light_volumetric_fog_energy = 0.2
		rim.spot_range = 10.0
		rim.spot_angle = 30.0
		rim.position = p
		add_child(rim)
		rim.look_at(Vector3(0, 1.2, 0))
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.current = true
	add_child(cam)


func _build_solaris() -> void:
	solaris = load("res://scenes/player.tscn").instantiate()
	add_child(solaris)
	solaris.position = Vector3(0, 0.25, 0)
	# Mannequin de présentation : pas de physique, pas de commandes, pas de combat
	solaris.set_physics_process(false)
	solaris.set_process_unhandled_input(false)
	solaris.camera.current = false
	solaris.combat.set_physics_process(false)
	solaris.combat.set_process(false)
	solaris.combat.set_process_unhandled_input(false)
	solaris.model.rotation.y = 0.0     # face à la caméra (-Z)
	if solaris.anim:
		solaris.anim.preview = true
	if solaris.look:
		solaris.look.pop_fx = true
		solaris.look.energy_color_changed.connect(_on_energy)
		_on_energy(Appearance.color(5))
	cam.current = true


func _on_energy(c: Color) -> void:
	_ring_mat.albedo_color = c
	_ring_mat.emission = c
	_ring_light.light_color = c


## Profondeur de champ façon Anthem : le hangar derrière le Solaris est flou, seule l'armure reste nette.
## La distance de mise au point suit la caméra (voir _process).
func _build_dof() -> void:
	_dof = CameraAttributesPractical.new()
	_dof.dof_blur_far_enabled = true
	_dof.dof_blur_far_distance = _dist + 1.0
	_dof.dof_blur_far_transition = 2.5
	_dof.dof_blur_near_enabled = true
	_dof.dof_blur_near_distance = 1.0
	_dof.dof_blur_near_transition = 0.8
	_dof.dof_blur_amount = 0.16
	cam.attributes = _dof


# ---------------------------------------------------------------- interface : briques
func _label(text: String, size: int, color: Color, wide := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 3)
	l.add_theme_font_override("font", _font_wide if wide else AnthemUI.body_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box_style(bg: Color, edge: Color, width := 1, radius := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	return sb


## Panneau façon Anthem : pas de boîte, un dégradé sombre qui s'efface vers le centre de l'écran,
## un liseré fin en haut et des crochets d'angle. side : -1 colonne gauche, 1 colonne droite, 2 bas.
func _panel(title: String, side := -1) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", AnthemUI.pad(20, 10, 20, 10))
	AnthemUI.panel(p, side, 0.85 if side == 2 else 0.62)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	if title != "":
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var tick := ColorRect.new()
		tick.color = ORANGE
		tick.custom_minimum_size = Vector2(2, 16)
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(tick)
		h.add_child(_label(title, 20, Color.WHITE, true))
		v.add_child(h)
		var sep := ColorRect.new()
		sep.color = AnthemUI.LINE
		sep.custom_minimum_size = Vector2(0, 1)
		v.add_child(sep)
	return [p, v]


func _place(c: Control, anchor_l: float, anchor_t: float, anchor_r: float, anchor_b: float, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = anchor_l
	c.anchor_top = anchor_t
	c.anchor_right = anchor_r
	c.anchor_bottom = anchor_b
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


func _build_ui() -> void:
	_font_wide = AnthemUI.title_font()
	_sil_shader = Shader.new()
	_sil_shader.code = "shader_type canvas_item;\nuniform vec4 tint : source_color = vec4(0.85, 0.92, 1.0, 1.0);\nvoid fragment() { float a = texture(TEXTURE, UV).a; COLOR = vec4(tint.rgb, a * tint.a); }"
	_ui = CanvasLayer.new()
	add_child(_ui)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_root)
	# Vignettage : les bords et le bas de l'écran s'assombrissent, le Solaris reste dans la lumière
	var vign := ColorRect.new()
	vign.set_anchors_preset(Control.PRESET_FULL_RECT)
	vign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs := ShaderMaterial.new()
	vs.shader = Shader.new()
	vs.shader.code = "shader_type canvas_item;\nvoid fragment() { vec2 d = (UV - vec2(0.5, 0.45)) * vec2(1.25, 1.0); float r = length(d) * 1.6; float a = smoothstep(0.45, 1.25, r) * 0.7 + smoothstep(0.78, 1.0, UV.y) * 0.45 + smoothstep(0.12, 0.0, UV.y) * 0.35; COLOR = vec4(0.0, 0.008, 0.02, clamp(a, 0.0, 0.88)); }"
	vign.material = vs
	_root.add_child(vign)
	# En-tête : logo, titre, onglets, niveau
	var logo := Panel.new()
	logo.add_theme_stylebox_override("panel", _box_style(Color(0, 0, 0, 0), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.8), 1, 0))
	logo.size = Vector2(30, 30)
	logo.position = Vector2(40, 26)
	logo.rotation = PI / 4
	logo.pivot_offset = Vector2(15, 15)
	_root.add_child(logo)
	var core := ColorRect.new()
	core.color = ORANGE
	core.size = Vector2(8, 8)
	core.position = Vector2(11, 11)
	logo.add_child(core)
	_title = _label("FORGE RANGER", 38, Color.WHITE, true)
	_title.position = Vector2(88, 10)
	_root.add_child(_title)
	var sub := _label("PERSONNALISATION D'EXOSQUELETTE", 13, DIM, true)
	sub.add_theme_font_override("font", AnthemUI.label_font())
	sub.position = Vector2(90, 54)
	_root.add_child(sub)
	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 4)
	_place(_tabs_box, 0.5, 0, 0.5, 0, -420, 18, 420, 56)
	_tabs_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(_tabs_box)
	# Ligne fine sous toute la barre d'onglets, et le trait lumineux de l'onglet ouvert
	var tabs_rule := ColorRect.new()
	tabs_rule.color = AnthemUI.LINE
	tabs_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(tabs_rule, 0.5, 0, 0.5, 0, -420, 57, 420, 58)
	_root.add_child(tabs_rule)
	_tab_line = Control.new()
	_tab_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_line.draw.connect(func():
		var r := Rect2(Vector2.ZERO, _tab_line.size)
		AnthemUI.glow(_tab_line, r, Color(1, 1, 1), 1.0, 6)
		_tab_line.draw_rect(r, Color.WHITE))
	_tab_line.size = Vector2(0, 2)
	_root.add_child(_tab_line)
	_pilot = _label("RANGER", 22, Color.WHITE, true)
	_place(_pilot, 1, 0, 1, 0, -360, 12, -28, 40)
	_pilot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_pilot)
	_preset_l = _label("", 13, DIM)
	_place(_preset_l, 1, 0, 1, 0, -460, 42, -28, 62)
	_preset_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_preset_l)
	_help = _label("", 13, DIM)
	_help.clip_text = true
	_place(_help, 0.5, 0, 0.5, 0, -420, 64, 420, 86)
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_help)
	# Colonnes
	for i in 2:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 0:
			_place(v, 0, 0, 0, 1, 20, 92, 556, -160)
		else:
			_place(v, 1, 0, 1, 1, -540, 92, -20, -160)
		_root.add_child(v)
		_col_nodes.append(v)
	# Bas : équipement et statistiques
	var eq: Array = _panel("ÉQUIPEMENT", 2)
	_place(eq[0], 0, 1, 1, 1, 20, -156, -560, -12)
	_root.add_child(eq[0])
	_equip_box = HBoxContainer.new()
	_equip_box.add_theme_constant_override("separation", 0)
	eq[1].add_child(_equip_box)
	var st: Array = _panel("STATISTIQUES", 2)
	_place(st[0], 1, 1, 1, 1, -540, -156, -20, -12)
	_root.add_child(st[0])
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 5)
	st[1].add_child(_stats_box)
	_toast = _label("", 20, GOLD)
	_place(_toast, 0.5, 1, 0.5, 1, -420, -196, 420, -166)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_toast)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)


func _toast_msg(text: String, secs := 2.0) -> void:
	_toast.text = text
	_toast_t = secs


# ---------------------------------------------------------------- contenu des onglets
## Une ligne : une bande de vignettes. items = [{ id, label, tex, color, glyph, locked, caption }].
## apply(i) est appelé quand on se déplace dessus (aperçu), accept(i) sur A, x(i) sur X.
func _strip(key: String, title: String, items: Array, on: int, opts := {}) -> Dictionary:
	var r := { "key": key, "title": title, "items": items, "on": on, "kind": "strip",
		"thumb": Vector2(58, 58), "visible": 6, "layout": "stack", "info": "", "help": "" }
	r.merge(opts, true)
	if not _cursor.has(key) or _cursor[key] >= items.size():
		_cursor[key] = maxi(on, 0)
	return r


func _slider(key: String, title: String, value: float, apply: Callable, help := "") -> Dictionary:
	return { "key": key, "title": title, "kind": "slider", "value": value, "apply": apply, "help": help, "items": [] }


func _build_cols() -> void:
	_cols = [[], []]
	var look := Appearance.current
	match TABS[tab]:
		"APPARENCE":
			var rows := []
			for s in Catalog.SLOTS:
				var items := []
				var on := 0
				var have := 0
				for p in Catalog.RANGER_PACKS:
					if not s in Catalog.pack_slots(p):
						continue
					var id: String = p["id"] + "." + s
					var ok := Appearance.is_unlocked(id)
					if ok:
						have += 1
					if Appearance.piece(s) == id:
						on = items.size()
					items.append({ "id": id, "tex": _thumbs.piece(id, look), "locked": not ok, "caption": p["name"] })
				var total := items.size()
				for p in Catalog.full_catalog(Appearance.mode):
					if p["name"] != "Default" and p["slotPieces"].get(s) != null:
						total += 1
				rows.append(_strip("piece_" + s, Catalog.SLOT_NAMES[s].to_upper(), items, on, {
					"layout": "side", "thumb": Vector2(76, 76), "visible": 4, "glyph": s,
					"info": "%d / %d" % [have, total],
					"apply": func(i): Appearance.set_piece(s, items[i]["id"]),
					"help": "Gauche / droite : essayer une pièce · elle se mélange librement avec les autres ensembles" }))
			var packs := []
			var pon := -1
			for p in Catalog.RANGER_PACKS:
				var ok := false
				var l := look.duplicate(true)
				var full := true
				for s in Catalog.SLOTS:
					var id: String = p["id"] + "." + s
					if Catalog.has_piece(id) and Appearance.is_unlocked(id):
						ok = true
						l[s + "_piece_id"] = id
					elif Catalog.has_piece(id):
						full = false
				if ok and full and pon < 0:
					var all := true
					for s in Catalog.pack_slots(p):
						all = all and Appearance.piece(s) == p["id"] + "." + s
					if all:
						pon = packs.size()
				packs.append({ "id": p["id"], "tex": _thumbs.preset(l, "pack_" + p["id"]), "locked": not ok, "caption": p["name"] })
			rows.append(_strip("packs", "ENSEMBLES", packs, maxi(pon, -1), {
				"layout": "side", "thumb": Vector2(76, 76), "visible": 4, "glyph": "packs",
				"info": "A : monter", "accept": func(i): _equip_pack(packs[i]["id"]),
				"help": "A : monter toutes les pièces d'un ensemble d'un coup" }))
			_cols[0].append({ "title": "PIÈCES D'ARMURE", "rows": rows })
			var right := []
			var zones := []
			for z in 6:
				zones.append({ "id": z, "color": Appearance.color(z), "caption": "%d" % (z + 1), "glyph": "" })
			right.append(_strip("zone", "ZONE", zones, _zone, { "thumb": Vector2(40, 24), "visible": 6,
				"info": Catalog.ZONES[_zone].to_upper(),
				"apply": func(i): _zone = i; _cursor.erase("color"); _cursor.erase("mat"); _dirty = true,
				"help": "Choisis la zone à peindre : la 6 (Énergie) colore les flammes, l'anneau et les traçantes" }))
			var cols := []
			var con := Catalog.PALETTE.find(look["color_slots"][_zone])
			for hex in Catalog.PALETTE:
				cols.append({ "id": hex, "color": Color(hex) })
			right.append(_strip("color", "COULEURS", cols, con, { "thumb": Vector2(42, 34), "visible": 9,
				"info": "ZONE : " + Catalog.ZONES[_zone].to_upper(),
				"apply": func(i): Appearance.set_color(_zone, cols[i]["id"]),
				"help": "Gauche / droite : teinte · Vue (C / V) : copier / coller · l'arme reprend ces couleurs" }))
			var mats := []
			var mon := 0
			for m in Catalog.MATERIALS:
				if m["id"] == look["material_slots"][_zone]:
					mon = mats.size()
				mats.append({ "id": m["id"], "tex": _thumbs.material_ball(m["id"], look, _zone), "locked": not m["id"] in Appearance.unlocked_materials, "caption": m["name"] })
			right.append(_strip("mat", "MATÉRIAUX", mats, mon, { "thumb": Vector2(46, 46), "visible": 8,
				"info": Catalog.look_material(look, _zone)["name"].to_upper(),
				"apply": func(i): Appearance.set_material(_zone, mats[i]["id"]),
				"help": "Matériau de la zone choisie · Chrome et Anodisé : finition Éclipse" }))
			right.append(_slider("wear_amount", "USURE", Appearance.wear_amount(),
				func(v): Appearance.set_wear_amount(v), "Gauche / droite : intensité de l'usure, de neuf à usé à fond"))
			var wears := []
			var won := 0
			for w in Catalog.WEAR:
				if w["id"] == look["wear_state"]:
					won = wears.size()
				wears.append({ "id": w["id"], "tex": _thumbs.wear_ball(w["id"], look), "caption": w["name"] })
			right.append(_strip("wear", "TYPE D'USURE", wears, won, { "thumb": Vector2(46, 46), "visible": 5,
				"info": Catalog.find(Catalog.WEAR, look["wear_state"])["name"].to_upper(),
				"apply": func(i): Appearance.set_wear(wears[i]["id"]),
				"help": "Le type d'usure ; le curseur au-dessus règle son intensité" }))
			var vins := []
			var von := 0
			for v in Catalog.VINYLS:
				if v["id"] == look["vinyl_id"]:
					von = vins.size()
				vins.append({ "id": v["id"], "tex": null if v["id"] == "none" else VinylArt.texture(v["id"]),
					"glyph": "⊘" if v["id"] == "none" else "", "locked": not v["id"] in Appearance.unlocked_vinyls, "caption": v["name"],
					"modulate": Appearance.color(2) })
			right.append(_strip("vinyl", "MARQUAGES", vins, von, { "thumb": Vector2(46, 46), "visible": 6,
				"info": Catalog.find(Catalog.VINYLS, look["vinyl_id"])["name"].to_upper(),
				"apply": func(i): Appearance.set_vinyl(vins[i]["id"]),
				"help": "Un marquage par preset, coloré par la zone Accent" }))
			var places := []
			for p in Catalog.VINYL_PLACES:
				places.append({ "id": p, "text": Catalog.VINYL_PLACE_NAMES[p] })
			right.append(_strip("place", "EMPLACEMENT", places, Catalog.VINYL_PLACES.find(look.get("vinyl_place", "chest")), {
				"thumb": Vector2(104, 20), "visible": 4,
				"apply": func(i): Appearance.set_vinyl_place(places[i]["id"]),
				"help": "Où se pose le marquage" }))
			_cols[1].append({ "title": "PERSONNALISATION", "rows": right })
			_cols[1].append({ "title": "PRÉRÉGLAGES", "rows": [_preset_strip(Vector2(70, 78), 5)] })
		"ARSENAL":
			var rows := []
			for slot in ["weapon0", "weapon1", "grenade", "launcher"]:
				rows.append(_loot_strip(slot))
			_cols[0].append({ "title": "ARSENAL · PUISSANCE DE L'EXO %d" % BuildStats.exo_power(), "rows": rows })
			_cols[0].append({ "title": "LOADOUTS", "rows": [_loadout_strip()] })
		"COMPOSANTS":
			var rows := []
			for slot in Inventory.COMP_SLOTS:
				rows.append(_loot_strip(slot))
			_cols[0].append({ "title": "COMPOSANTS · %d / 6 OUVERTS" % Progression.comp_slots(), "rows": rows })
		"RECYCLAGE":
			var rows := []
			for cat in ["weapon", "ability", "component"]:
				rows.append(_salvage_strip(cat))
			var acts := [{ "id": 3, "text": "Les marqués (%d)" % Inventory.junk_count() }, { "id": 0, "text": "Tous les Communs" }, { "id": 1, "text": "Jusqu'aux Peu communs" }, { "id": 2, "text": "Jusqu'aux Rares" }]
			rows.append(_strip("salvage_bulk", "RECYCLER EN LOT", acts, -1, {
				"thumb": Vector2(150, 40), "visible": 4, "info": "ni équipés, ni verrouillés",
				"accept": func(i): _salvage_bulk(int(acts[i]["id"])),
				"help": "A : recycler en lot (les objets équipés et verrouillés sont gardés)" }))
			_cols[0].append({ "title": "RECYCLAGE · %d OBJETS" % Inventory.items.size(), "rows": rows })
		"SYSTÈMES":
			var rows := []
			for s in Loadout.SLOTS:
				var items := []
				for t in Loadout.PARTS[s].size():
					var p: Dictionary = Loadout.PARTS[s][t]
					items.append({ "id": t, "text": p["name"], "glyph": ["I", "II", "III"][t], "locked": not Loadout.is_unlocked(s, t), "caption": "" })
				rows.append(_strip("comp_" + s, Loadout.SLOT_NAMES[s].to_upper(), items, Loadout.tier[s], {
					"layout": "side", "thumb": Vector2(110, 64), "visible": 3, "glyph": "comp",
					"info": "", "apply": func(i): Loadout.set_tier(s, i); _flash_core(),
					"help": Loadout.part(s)["desc"] + "  ·  débloqués par le niveau pilote" }))
			_cols[0].append({ "title": "SYSTÈMES DU SOLARIS", "rows": rows })
			var diffs := []
			var don := 0
			for d in LootDB.tables()["difficulties"]:
				if d["id"] == Progression.difficulty:
					don = diffs.size()
				diffs.append({ "id": d["id"], "text": d["name"], "caption": "niv. %d" % int(d["level"]), "locked": not Progression.difficulty_unlocked(d["id"]) })
			var dcur: Dictionary = LootDB.tables()["difficulties"][clampi(_cursor.get("difficulty", don), 0, diffs.size() - 1)]
			_cols[1].append({ "title": "EXPÉDITIONS", "rows": [_strip("difficulty", "DIFFICULTÉ", diffs, don, {
				"thumb": Vector2(104, 40), "visible": 4, "info": "PILOTE NIV. %d" % Progression.level,
				"accept": func(i): _set_difficulty(diffs[i]["id"]),
				"help": "A : choisir · ennemis ×%.1f en vie, XP ×%.1f, butin plus rare%s" % [float(dcur["enemy_hp"]), float(dcur["xp"]),
					"" if Progression.difficulty_unlocked(dcur["id"]) else "  ·  débloquée au niveau pilote %d" % int(dcur["level"])] })] })
			_cols[1].append({ "title": "LOADOUTS", "rows": [_loadout_strip()] })
		"MODES":
			var items := []
			var on := 0
			for m in Catalog.MODES:
				if m["id"] == Appearance.mode:
					on = items.size()
				items.append({ "id": m["id"], "text": m["name"].to_upper(), "caption": m["archetype"], "locked": m["id"] != Appearance.mode, "glyph": "" })
			var cur: Dictionary = Catalog.MODES[clampi(_cursor.get("modes", on), 0, Catalog.MODES.size() - 1)]
			_cols[0].append({ "title": "MODES DU SOLARIS", "rows": [_strip("modes", "MODE", items, on, {
				"thumb": Vector2(112, 70), "visible": 4, "info": "A : reconfigurer",
				"accept": func(i): _choose_mode(i),
				"help": cur["desc"] + ("" if cur["id"] == Appearance.mode else "  ·  Déblocage : " + cur["unlock"]) })] })
			var right := []
			for kind in ["animation_arrival", "animation_victory", "emote0", "emote1", "emote2"]:
				var list: Array = Catalog.ARRIVALS if kind == "animation_arrival" else (Catalog.VICTORIES if kind == "animation_victory" else Catalog.EMOTES)
				var curid: String = look[kind] if not kind.begins_with("emote") else look["emotes"][int(kind.substr(5))]
				var its := []
				for a in list:
					its.append({ "id": a["id"], "text": a["name"] })
				var title: String = { "animation_arrival": "ARRIVÉE", "animation_victory": "VICTOIRE" }.get(kind, "EMOTE %d" % (int(kind.substr(5)) + 1))
				right.append(_strip("anim_" + kind, title, its, Catalog.index_of(list, curid), {
					"thumb": Vector2(112, 30), "visible": 4,
					"apply": func(i): Appearance.set_anim(kind, its[i]["id"]); _play(its[i]["id"]),
					"accept": func(i): _play(its[i]["id"]),
					"help": "Gauche / droite : changer (aperçu sur le socle) · en jeu : emotes sur la croix ou 1 / 2 / 3" }))
			_cols[1].append({ "title": "ANIMATIONS", "rows": right })
		"PRÉRÉGLAGES":
			_cols[0].append({ "title": "PRÉRÉGLAGES D'APPARENCE", "rows": [_preset_strip(Vector2(92, 128), 4, 0), _preset_strip(Vector2(92, 128), 4, 1)] })
			_cols[1].append({ "title": "LOADOUTS D'ÉQUIPEMENT", "rows": [_loadout_strip()] })


# ---------------------------------------------------------------- butin (Arsenal, Composants, Recyclage)
## Une ligne d'emplacement : les objets compatibles, du plus puissant au plus faible. A = équiper, X = verrouiller.
func _loot_strip(slot: String) -> Dictionary:
	var sd := LootDB.slot(slot)
	var open := Inventory.slot_open(slot)
	var items := []
	var on := -1
	var cur_uid: String = Inventory.equipped.get(slot, "")
	if slot in Inventory.COMP_SLOTS:
		items.append({ "id": "", "glyph": "⊘", "caption": "Vide", "loot_empty": true })
		if cur_uid == "":
			on = 0
	for it in Inventory.compatible(slot):
		if it["uid"] == cur_uid:
			on = items.size()
		items.append(_loot_item(it))
	var eq := Inventory.equipped_item(slot)
	var info := ""
	if not open:
		info = "VERROUILLÉ · " + ("NOYAU HORIZON (NIV. 3)" if slot == "launcher" else "NIVEAU PILOTE %d" % _comp_level(slot))
	elif not eq.is_empty():
		info = "%s · %d" % [LootDB.item_name(eq), int(eq["power"])]
	return _strip("loot_" + slot, sd["name"].to_upper(), items, on, {
		"thumb": Vector2(66, 46) if slot in Inventory.COMP_SLOTS else Vector2(82, 52), "visible": 6 if slot in Inventory.COMP_SLOTS else 5,
		"info": info, "loot_slot": slot,
		"accept": func(i): _equip(slot, items[i]),
		"x": func(i): _lock(items[i]),
		"help": "A : équiper · X : verrouiller / déverrouiller · triés par puissance" })


func _loot_item(it: Dictionary) -> Dictionary:
	var where := Inventory.slot_of(it["uid"])
	return { "id": it["uid"], "loot": it, "caption": LootDB.item_name(it),
		"where": where }


func _comp_level(slot: String) -> int:
	var idx := Inventory.COMP_SLOTS.find(slot)
	for l in range(1, Progression.max_level() + 1):
		if int(Progression.reward(l).get("comp_slots", 0)) > idx:
			return l
	return 99


func _salvage_strip(cat: String) -> Dictionary:
	var items := []
	var list := Inventory.items.filter(func(it): return LootDB.item_category(it) == cat)
	list.sort_custom(func(a, b): return a["rarity"] < b["rarity"] or (a["rarity"] == b["rarity"] and a["power"] < b["power"]))
	for it in list:
		items.append(_loot_item(it))
	var title: String = { "weapon": "ARMES", "ability": "CAPACITÉS", "component": "COMPOSANTS" }[cat]
	return _strip("salvage_" + cat, title, items, -1, {
		"thumb": Vector2(82, 52), "visible": 5, "info": "%d" % items.size(),
		"accept": func(i): _salvage(items[i]),
		"x": func(i): _lock(items[i]),
		"help": "A deux fois : recycler en matériaux · X : verrouiller (protège du recyclage)" })


func _equip(slot: String, entry: Dictionary) -> void:
	if not Inventory.slot_open(slot):
		_toast_msg("Emplacement verrouillé : monte en niveau pilote pour l'ouvrir", 2.0)
		return
	if entry.get("loot_empty", false):
		Inventory.unequip(slot)
		_toast_msg("Emplacement vidé")
		return
	var it: Dictionary = entry["loot"]
	if Inventory.equip(slot, it["uid"]):
		_toast_msg("%s équipé · puissance de l'exo %d" % [LootDB.item_name(it), BuildStats.exo_power()])
		_flash_core()
		if LootDB.item_category(it) == "ability":
			_play_cast()


func _lock(entry: Dictionary) -> void:
	if not entry.has("loot"):
		return
	var locked := Inventory.toggle_lock(entry["id"])
	_toast_msg("Verrouillé : il ne sera pas recyclé" if locked else "Déverrouillé")


func _salvage(entry: Dictionary) -> void:
	if not entry.has("loot"):
		return
	var it: Dictionary = entry["loot"]
	if not Inventory.can_salvage(it):
		_toast_msg("Impossible : objet équipé" if Inventory.is_equipped(it["uid"]) else "Impossible : objet verrouillé (X)", 1.6)
		return
	if _salvage_confirm != it["uid"]:
		_salvage_confirm = it["uid"]
		_toast_msg("A encore une fois pour recycler %s" % LootDB.item_name(it), 2.0)
		return
	_salvage_confirm = ""
	var gain := Inventory.salvage(it["uid"])
	_toast_msg("Recyclé : " + _materials_text(gain), 2.5)
	Fx.sparks(solaris.global_position + Vector3(0, 0.4, 0.9), Vector3.UP, LootDB.rarity_color(int(it["rarity"])), 30, 4.0)
	Progression.save()


func _salvage_bulk(i: int) -> void:
	# 3 = les objets marqués « à recycler » dans le menu du jeu ; sinon jusqu'à la rareté i
	var gain := Inventory.salvage_marked() if i == 3 else Inventory.salvage_up_to(i)
	var n := int(gain.get("_count", 0))
	gain.erase("_count")
	if n == 0:
		_toast_msg("Rien à recycler", 1.4)
		return
	_toast_msg("%d objet%s recyclé%s : %s" % [n, "s" if n > 1 else "", "s" if n > 1 else "", _materials_text(gain)], 3.0)
	Fx.sparks(solaris.global_position + Vector3(0, 0.4, 0.9), Vector3.UP, GOLD, 50, 5.0)
	Progression.save()


func _materials_text(gain: Dictionary) -> String:
	var parts := []
	for k in gain:
		if k.begins_with("_"):
			continue
		parts.append("+%d %s" % [int(gain[k]), LootDB.material(k)["name"]])
	return ", ".join(parts)


func _set_difficulty(id: String) -> void:
	if Progression.set_difficulty(id):
		_toast_msg("Difficulté des expéditions : %s" % LootDB.difficulty(id)["name"])
	else:
		_toast_msg("Débloquée au niveau pilote %d" % int(LootDB.difficulty(id)["level"]), 2.0)


## Objet sous le curseur dans un onglet de butin (vide si aucun).
func _cursor_loot() -> Dictionary:
	var r := _cur_row()
	if r.is_empty() or r["items"].is_empty():
		return {}
	var it: Dictionary = r["items"][clampi(int(_cursor.get(r["key"], 0)), 0, r["items"].size() - 1)]
	return it.get("loot", {})


## Colonne de droite des onglets de butin : fiche de l'objet sous le curseur, comparée à l'objet équipé.
func _draw_loot_side() -> void:
	var holder: VBoxContainer = _col_nodes[1]
	var r := _cur_row()
	var it := _cursor_loot()
	if TABS[tab] == "RECYCLAGE":
		var pm: Array = _panel("MATÉRIAUX", 1)
		holder.add_child(pm[0])
		for m in LootDB.tables()["materials"]:
			var h := HBoxContainer.new()
			var dot := _label("◆", 16, Color(String(m["color"])))
			h.add_child(dot)
			var n := _label(m["name"], 14, Color(0.85, 0.88, 0.92))
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(n)
			h.add_child(_label("%d" % int(Inventory.materials.get(m["id"], 0)), 16, Color.WHITE, true))
			pm[1].add_child(h)
		pm[1].add_child(_label("Plans et fabrication : plus tard (décision de cyril)", 11, MUTED))
		if not it.is_empty():
			_side_card(holder, LootUI.card(it, {}, 500.0, "RENDEMENT : " + _materials_text(Inventory.salvage_value(it)), true), it["uid"])
		return
	if it.is_empty():
		var slot: String = r.get("loot_slot", "")
		if slot != "":
			var eq := Inventory.equipped_item(slot)
			if not eq.is_empty():
				_side_card(holder, LootUI.card(eq, {}, 500.0, "ÉQUIPÉ", true), eq["uid"])
		return
	Inventory.mark_seen(it["uid"])
	var slot2: String = r.get("loot_slot", "")
	var eq2 := Inventory.equipped_item(slot2)
	var title := "ÉQUIPÉ" if eq2.get("uid", "") == it["uid"] else ("COMPARAISON AVEC : %s (%d)" % [LootDB.item_name(eq2), int(eq2["power"])] if not eq2.is_empty() else "EMPLACEMENT VIDE")
	if eq2.get("uid", "") != it["uid"]:
		var after := BuildStats.exo_power_with(slot2, it)
		var now := BuildStats.exo_power()
		title += "   ·   EXO %d → %d" % [now, after]
	_side_card(holder, LootUI.card(it, eq2, 500.0, title, true), it["uid"])


## Fiche de droite : quand l'objet affiché change, elle entre en fondu en glissant depuis la droite.
func _side_card(holder: Control, card: Control, uid: String) -> void:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(card)
	holder.add_child(m)
	if uid == _last_card:
		return
	_last_card = uid
	m.modulate.a = 0.0
	var tw := m.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "modulate:a", 1.0, 0.22)
	tw.tween_method(func(x): m.add_theme_constant_override("margin_left", int(x)), 18.0, 0.0, 0.26)


## Préréglages : « Nouveau » puis les 10 presets du mode (vignette du Solaris entier).
## half = -1 : une seule bande ; 0 / 1 : presets 1-5 / 6-10 (onglet Préréglages).
func _preset_strip(size: Vector2, vis: int, half := -1) -> Dictionary:
	var presets: Array = Appearance.presets[Appearance.mode]
	var items := []
	var on := -1
	if half <= 0:
		items.append({ "id": -1, "glyph": "+", "caption": "Nouveau" })
	var lo := 0 if half < 1 else 5
	var hi := presets.size() if half < 0 else mini(presets.size(), lo + 5)
	for i in range(lo, hi):
		var p: Dictionary = presets[i]
		if p.get("empty", false):
			items.append({ "id": i, "glyph": "·", "caption": "Vide %d" % (i + 1) })
		else:
			if i == Appearance.active[Appearance.mode]:
				on = items.size()
			items.append({ "id": i, "tex": _thumbs.preset(p, "preset_%d" % i), "caption": p["name"] })
	var key := "presets" if half < 0 else "presets_%d" % half
	return _strip(key, "" if half < 0 else ("1 – 5" if half == 0 else "6 – 10"), items, on, {
		"thumb": size, "visible": vis, "info": Appearance.preset_name() + ("  •  modifié" if Appearance.dirty() else ""),
		"accept": func(i): _preset_accept(items[i]["id"]),
		"x": func(i): _preset_save(items[i]["id"]),
		"help": "A : porter le preset · X : y enregistrer le look actuel · « Nouveau » : enregistrer dans un emplacement libre · Start : sauvegarder" })


func _loadout_strip() -> Dictionary:
	var items := []
	for i in Loadout.LOADOUTS_PER_MODE:
		var l: Dictionary = Loadout.loadouts[Loadout.mode][i]
		items.append({ "id": i, "text": l["name"], "caption": "vide" if l.get("empty", false) else "", "glyph": "" })
	return _strip("loadouts", "LOADOUTS", items, Loadout.active_loadout, {
		"thumb": Vector2(96, 40), "visible": 4, "info": "6 PAR MODE",
		"accept": func(i): Loadout.load_loadout(i); _toast_msg("Loadout « %s » chargé" % Loadout.loadouts[Loadout.mode][i]["name"]); _flash_core(),
		"x": func(i): Loadout.save_loadout(i); _toast_msg("Équipement enregistré dans « %s »" % Loadout.loadouts[Loadout.mode][i]["name"]),
		"help": "A : charger ce loadout · X : y enregistrer l'équipement actuel · indépendants des presets d'apparence" })


func _equip_pack(pack_id: String) -> void:
	Appearance.set_pack(pack_id)
	_toast_msg("Ensemble « %s » monté" % Catalog.pack_name(pack_id))


func _preset_accept(i: int) -> void:
	if i < 0:
		_preset_save(-1)
		return
	if Appearance.presets[Appearance.mode][i].get("empty", false):
		_preset_save(i)
		return
	Appearance.load_preset(i)
	_toast_msg("Preset « %s » porté" % Appearance.preset_name())
	_reconfigure(false)


func _preset_save(i: int) -> void:
	if i < 0:
		var presets: Array = Appearance.presets[Appearance.mode]
		for k in presets.size():
			if presets[k].get("empty", false):
				i = k
				break
		if i < 0:
			_toast_msg("Les 10 emplacements sont pris : X sur un preset pour le remplacer")
			return
	Appearance.save_preset(i)
	_toast_msg("Look enregistré dans « %s »" % Appearance.preset_name())


func _choose_mode(i: int) -> void:
	var m: Dictionary = Catalog.MODES[i]
	if m["id"] != Appearance.mode:
		_toast_msg("%s : %s" % [m["name"], m["unlock"]], 3.0)
	else:
		_reconfigure()


func _play_cast() -> void:
	if solaris.anim:
		solaris.anim.cast()


# ---------------------------------------------------------------- dessin
func _rows_of(c: int) -> Array:
	var out := []
	for sec in _cols[c]:
		out.append_array(sec["rows"])
	return out


func _cur_row() -> Dictionary:
	var rows := _rows_of(col)
	if rows.is_empty():
		return {}
	return rows[clampi(row_i[col], 0, rows.size() - 1)]


func _refresh() -> void:
	_dirty = false
	_build_cols()
	for c in 2:
		var n := _rows_of(c).size()
		row_i[c] = clampi(row_i[c], 0, maxi(0, n - 1))
	if _rows_of(col).is_empty():
		col = 1 - col
	# En-tête
	var mname: String = Catalog.find(Catalog.MODES, Appearance.mode)["name"].to_upper()
	_title.text = "FORGE " + mname
	_pilot.text = "PILOTE %d · PUISSANCE %d" % [Progression.level, BuildStats.exo_power()]
	_preset_l.text = "Preset porté : %s%s" % [Appearance.preset_name(), "  •  non sauvegardé" if Appearance.dirty() else ""]
	for ch in _tabs_box.get_children():
		ch.queue_free()
	_tabs_box.add_child(_key_chip("LB"))
	for i in TABS.size():
		var p := PanelContainer.new()
		var on := i == tab
		p.add_theme_stylebox_override("panel", AnthemUI.pad(11, 8, 11, 9))
		var tname: String = TABS[i]
		if TABS[i] == "ARSENAL" and Inventory.unseen_count() > 0:
			tname += " ●"
		var tl := _label(tname, 16, Color.WHITE if on else DIM, true)
		tl.add_theme_font_override("font", AnthemUI.label_font())
		p.add_child(tl)
		p.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _set_tab(i))
		p.mouse_entered.connect(func(): if i != tab: tl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0)))
		p.mouse_exited.connect(func(): if i != tab: tl.add_theme_color_override("font_color", DIM))
		if on:
			_tab_on = p
		_tabs_box.add_child(p)
	_tabs_box.add_child(_key_chip("RB"))
	# Colonnes
	for c in 2:
		var holder: VBoxContainer = _col_nodes[c]
		for ch in holder.get_children():
			ch.queue_free()
		var idx := 0
		for sec in _cols[c]:
			var pv: Array = _panel(sec["title"], -1 if c == 0 else 1)
			holder.add_child(pv[0])
			for r in sec["rows"]:
				pv[1].add_child(_draw_row(r, c, idx))
				idx += 1
	if TABS[tab] in LOOT_TABS:
		_draw_loot_side()
	var r := _cur_row()
	_help.text = ("%s  ·  " % r.get("help", "")) if r.get("help", "") != "" else ""
	_help.text += "LB / RB onglet · LT / RT colonne · B quitter"
	_draw_equipment()
	_draw_stats()
	_update_focus()


## Le trait sous l'onglet ouvert glisse vers lui (amorti), et s'élargit à sa taille.
func _update_tab_line(delta: float) -> void:
	if _tab_line == null or not is_instance_valid(_tab_on) or not _tab_on.is_inside_tree() or _tab_on.size.x < 1.0:
		return
	var r := _tab_on.get_global_rect()
	var want := Vector2(r.position.x + 6.0, r.end.y - 1.0)
	var w := r.size.x - 12.0
	if _tab_line.size.x < 1.0:
		_tab_line.position = want
		_tab_line.size.x = w
	else:
		var k := minf(1.0, delta * 14.0)
		_tab_line.position = _tab_line.position.lerp(want, k)
		_tab_line.size.x = lerpf(_tab_line.size.x, w, k)
	_tab_line.size.y = 2.0
	_tab_line.queue_redraw()


func _key_chip(t: String) -> Control:
	var p := PanelContainer.new()
	var sb := _box_style(Color(0, 0, 0, 0), Color(DIM.r, DIM.g, DIM.b, 0.6), 1, 2)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := _label(t, 13, DIM, true)
	l.add_theme_font_override("font", AnthemUI.label_font())
	p.add_child(l)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 6)
	m.add_theme_constant_override("margin_right", 6)
	m.add_child(p)
	return m


func _draw_row(r: Dictionary, c: int, idx: int) -> Control:
	var focused: bool = c == col and idx == row_i[c]
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 3)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if focused:
		# ligne active : bande de lumière qui s'efface vers la droite et trait fin à gauche
		wrap.draw.connect(func():
			var rr := Rect2(Vector2(-10, -3), wrap.size + Vector2(14, 6))
			AnthemUI.gradient(wrap, rr, Color(0.75, 0.88, 1.0, 0.09), Color(0.75, 0.88, 1.0, 0.0), -1)
			wrap.draw_rect(Rect2(rr.position, Vector2(2, rr.size.y)), ACCENT))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var mark := Control.new()
	mark.custom_minimum_size = Vector2(0, 14)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(mark)
	if r["title"] != "":
		var tl := _label(r["title"], 16, Color.WHITE if focused else Color(0.78, 0.84, 0.92), true)
		tl.add_theme_font_override("font", AnthemUI.label_font())
		head.add_child(tl)
	if r["kind"] == "slider":
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(250, 18)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var val: float = r["value"]
		# piste de 2 px, remplissage bleu pâle, curseur blanc qui luit quand la ligne est active
		bar.draw.connect(func():
			var y := bar.size.y * 0.5
			bar.draw_rect(Rect2(0, y - 1, bar.size.x, 2), Color(0.6, 0.72, 0.88, 0.22))
			bar.draw_rect(Rect2(0, y - 1, bar.size.x * val, 2), ACCENT)
			var k := Rect2(bar.size.x * val - 2, y - 8, 4, 16)
			if focused:
				AnthemUI.glow(bar, k, Color.WHITE, 1.0, 6)
			bar.draw_rect(k, Color.WHITE if focused else Color(0.8, 0.86, 0.92)))
		bar.gui_input.connect(func(ev): _slider_mouse(ev, bar, r, c, idx))
		head.add_child(bar)
		head.add_child(_label("%d %%" % roundi(r["value"] * 100.0), 15, Color.WHITE))
		wrap.add_child(head)
		return wrap
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(sp)
	if r["info"] != "":
		head.add_child(_label(r["info"], 13, GOLD if focused else DIM))
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 6)
	var items: Array = r["items"]
	var cur: int = _cursor.get(r["key"], 0)
	var vis: int = r["visible"]
	var start := clampi(cur - vis / 2, 0, maxi(0, items.size() - vis))
	strip.add_child(_label("‹" if start > 0 else " ", 22, DIM))
	for i in range(start, mini(items.size(), start + vis)):
		strip.add_child(_draw_item(r, items[i], i, i == r["on"], focused and i == cur, c, idx))
	strip.add_child(_label("›" if start + vis < items.size() else " ", 22, DIM))
	if r["layout"] == "side":
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var icon := PanelContainer.new()
		icon.add_theme_stylebox_override("panel", AnthemUI.pad(4, 4, 4, 4))
		icon.draw.connect(func():
			var ir := Rect2(Vector2.ZERO, icon.size)
			icon.draw_rect(ir, Color(0.62, 0.76, 0.92, 0.05))
			AnthemUI.brackets(icon, ir, 8.0, Color(1, 1, 1, 0.85) if focused else Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45)))
		icon.custom_minimum_size = Vector2(58, 58)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var gl: String = r.get("glyph", "")
		var on_it: Dictionary = r["items"][maxi(0, r["on"])] if r["items"].size() > 0 else {}
		if SLOT_GLYPH.has(gl) and on_it.get("tex") != null and not str(on_it.get("id", "")).contains(".default."):
			var tr := TextureRect.new()
			tr.texture = on_it["tex"]
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var sm := ShaderMaterial.new()
			sm.shader = _sil_shader
			tr.material = sm
			icon.add_child(tr)
		else:
			var gl_l := _label({ "packs": "◈", "comp": "⚙" }.get(gl, SLOT_GLYPH.get(gl, "◆")), 26, Color(0.85, 0.92, 1.0) if focused else DIM)
			gl_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			gl_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icon.add_child(gl_l)
		h.add_child(icon)
		var names := VBoxContainer.new()
		names.custom_minimum_size = Vector2(92, 0)
		names.alignment = BoxContainer.ALIGNMENT_CENTER
		var nl := _label(r["title"], 17, Color.WHITE if focused else Color(0.78, 0.84, 0.92), true)
		nl.add_theme_font_override("font", AnthemUI.label_font())
		names.add_child(nl)
		names.add_child(_label(r["info"], 13, GOLD if focused else DIM))
		h.add_child(names)
		h.add_child(strip)
		var hh := HBoxContainer.new()
		hh.add_theme_constant_override("separation", 0)
		hh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if focused:
			hh.draw.connect(func():
				var rr := Rect2(Vector2(-10, -3), hh.size + Vector2(14, 6))
				AnthemUI.gradient(hh, rr, Color(0.75, 0.88, 1.0, 0.09), Color(0.75, 0.88, 1.0, 0.0), -1)
				hh.draw_rect(Rect2(rr.position, Vector2(2, rr.size.y)), ACCENT))
		hh.add_child(h)
		return hh
	if r["title"] != "":
		wrap.add_child(head)
	wrap.add_child(strip)
	return wrap


func _draw_item(r: Dictionary, it: Dictionary, i: int, on: bool, here: bool, c: int, idx: int) -> Control:
	var size: Vector2 = r["thumb"]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", AnthemUI.pad(2, 2, 2, 2))
	var rare := Color(0, 0, 0, 0)
	if it.has("loot"):
		rare = LootDB.rarity_color(int(it["loot"]["rarity"]))
	# Vignette sans cadre épais : fond à peine visible, fine barre de rareté et léger dégradé de sa couleur,
	# liseré doré si équipée ; sous le curseur, blanche, lumineuse, avec crochets d'angle (« glow » animé).
	p.set_meta("glow", 1.0 if (here and _last_sel == "%s:%d" % [r["key"], i]) else 0.0)
	p.draw.connect(func():
		var g: float = p.get_meta("glow", 0.0)
		var rr := Rect2(Vector2.ZERO, p.size)
		p.draw_rect(rr, TILE_BG.lerp(Color(0.85, 0.93, 1.0, 0.16), g))
		if rare.a > 0.0:
			AnthemUI.gradient(p, rr, Color(rare.r, rare.g, rare.b, 0.2), Color(rare.r, rare.g, rare.b, 0.0), 2)
			p.draw_rect(Rect2(0, p.size.y - 2, p.size.x, 2), rare)
		if on:
			p.draw_rect(rr, Color(GOLD.r, GOLD.g, GOLD.b, 0.75), false, 1.0)
			p.draw_rect(Rect2(0, 0, 8, 2), GOLD)
		else:
			p.draw_rect(rr, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.14 + 0.5 * g), false, 1.0)
		if g > 0.0:
			AnthemUI.glow(p, rr, Color.WHITE, g, 8)
			p.draw_rect(rr, Color(1, 1, 1, g), false, 1.0)
			AnthemUI.brackets(p, rr.grow(3), 9.0, Color(1, 1, 1, g), 1.5))
	p.resized.connect(func(): p.pivot_offset = p.size * 0.5)
	if here:
		var key := "%s:%d" % [r["key"], i]
		if key != _last_sel:
			_last_sel = key
			p.scale = Vector2.ONE
			var tw := p.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(p, "scale", Vector2.ONE * 1.04, 0.16)
			tw.tween_method(func(x): p.set_meta("glow", x); p.queue_redraw(), 0.0, 1.0, 0.2)
		else:
			p.scale = Vector2.ONE * 1.04
	else:
		p.mouse_entered.connect(func():
			p.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(p, "scale", Vector2.ONE * 1.04, 0.12)
			p.set_meta("glow", 0.35)
			p.queue_redraw())
		p.mouse_exited.connect(func():
			p.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(p, "scale", Vector2.ONE, 0.12)
			p.set_meta("glow", 0.0)
			p.queue_redraw())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var body: Control
	if it.has("loot"):
		body = _loot_thumb(it["loot"], here or on, it.get("where", ""))
	elif it.get("tex") != null:
		var tr := TextureRect.new()
		tr.texture = it["tex"]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if size.y > size.x else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if it.has("modulate"):
			tr.modulate = it["modulate"]
		body = tr
	elif it.has("color"):
		var cr := ColorRect.new()
		cr.color = it["color"]
		body = cr
	elif it.has("text"):
		var l := _label(it["text"], 15, Color.WHITE if (here or on) else Color(0.74, 0.8, 0.88))
		l.add_theme_font_override("font", AnthemUI.caption_font())
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body = l
	else:
		var g := _label(it.get("glyph", ""), 30 if size.y > 50 else 20, Color(0.8, 0.88, 1.0))
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		body = g
	body.custom_minimum_size = size
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(body)
	if it.has("glyph") and it.get("glyph", "") != "" and it.has("text"):
		pass
	var cap: String = it.get("caption", "")
	if cap != "" and (size.y >= 52 or it.has("text")):
		# nom entier, sur deux lignes au besoin (coupé entre les mots, jamais au milieu)
		var cl := _label(cap, 12 if it.has("loot") else 13, Color.WHITE if here else DIM)
		cl.add_theme_font_override("font", AnthemUI.caption_font())
		cl.add_theme_constant_override("line_spacing", -3)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.max_lines_visible = 2
		cl.custom_minimum_size = Vector2(size.x, 27 if it.has("loot") else 0)
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(cl)
	if it.get("locked", false):
		p.modulate = Color(1, 1, 1, 0.38)
		var lk := _label("VERROUILLÉ", 10, GOLD, true)
		lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lk)
	p.gui_input.connect(func(ev): _item_mouse(ev, r, i, c, idx))
	return p


## Vignette d'objet : grande icône (rendu 3D, ou icône au trait pour les composants), puissance en haut à
## droite, « NOUVEAU » / « ÉQUIPÉ » en bas ; la rareté est la fine barre et le dégradé dessinés par la vignette.
func _loot_thumb(it: Dictionary, bright: bool, where: String) -> Control:
	var c := LootDB.rarity_color(int(it["rarity"]))
	var v := Control.new()
	v.clip_contents = false
	var t_icon := LootUI.icon_tight(it)
	if t_icon != null:
		var tr := TextureRect.new()
		tr.texture = t_icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vector_icon := t_icon.resource_path.ends_with(".svg")
		if vector_icon:
			tr.modulate = c.lerp(Color.WHITE, 0.6 if bright else 0.35)
			_place(tr, 0, 0, 1, 1, 4, 7, -26, -9)
		elif t_icon.get_width() > t_icon.get_height() * 1.8:
			_place(tr, 0, 0, 1, 1, 3, 14, -3, -12)    # arme : toute la largeur, sous la puissance
		else:
			_place(tr, 0, 0, 1, 1, 4, 4, -26, -12)    # grenade, lanceur : à gauche de la puissance
		v.add_child(tr)
	else:
		var g := LootUI.symbol(it, 20, c)
		_place(g, 0, 0, 1, 1, 0, 0, 0, -8)
		v.add_child(g)
	var pw := _label("%d" % int(it["power"]), 17, Color.WHITE if bright else Color(0.82, 0.87, 0.93), true)
	pw.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(pw, 1, 0, 1, 0, -40, -3, -3, 19)
	v.add_child(pw)
	var tag := ""
	if not it.get("seen", false):
		tag = "NOUVEAU"
	elif where != "":
		tag = "ÉQUIPÉ"
	if it.get("locked", false):
		tag = ("VERROUILLÉ " + tag).strip_edges()
	elif it.get("junk", false):
		tag = ("À RECYCLER " + tag).strip_edges()
	var t := _label(tag, 10, GOLD if tag.begins_with("NOUVEAU") else DIM, true)
	t.add_theme_font_override("font", AnthemUI.label_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place(t, 0, 1, 1, 1, 2, -14, 0, 0)
	v.add_child(t)
	return v


func _item_mouse(ev: InputEvent, r: Dictionary, i: int, c: int, idx: int) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	col = c
	row_i[c] = idx
	_cursor[r["key"]] = i
	_try(r, i)
	if ev.double_click and r.has("accept"):
		r["accept"].call(i)
	_refresh()


func _slider_mouse(ev: InputEvent, bar: Control, r: Dictionary, c: int, idx: int) -> void:
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		col = c
		row_i[c] = idx
		r["apply"].call(clampf(ev.position.x / bar.size.x, 0.0, 1.0))
		_dirty = true


## Bas de l'écran : ce que le Solaris emporte en mission (vient uniquement de l'équipement).
func _draw_equipment() -> void:
	for ch in _equip_box.get_children():
		ch.queue_free()
	var pr: Dictionary = Loadout.part("propulseurs")
	var jb: Dictionary = Loadout.part("jambes")
	var no: Dictionary = Loadout.part("noyau")
	var cards := [
		["ARME 1", _eq_name("weapon0", Combat.WEAPONS[0]["name"]), "▬", true, _eq_icon("weapon0", Combat.WEAPONS[0]["id"])],
		["ARME 2", _eq_name("weapon1", Combat.WEAPONS[1]["name"]), "▬", true, _eq_icon("weapon1", Combat.WEAPONS[1]["id"])],
		["GRENADE", _eq_name("grenade", Combat.ARSENAL[Loadout.powers[0]]["name"]), "◆", true, _eq_icon("grenade", Combat.ARSENAL[Loadout.powers[0]]["id"])],
		["LANCEUR", _eq_name("launcher", Combat.ARSENAL[Loadout.powers[1]]["name"]) if int(no["power_slots"]) > 1 else "Noyau bridé", "◆", int(no["power_slots"]) > 1, _eq_icon("launcher", Combat.ARSENAL[Loadout.powers[1]]["id"])],
		["MÊLÉE", "Ruée ×%.1f" % jb["melee_mult"], "✦", true, AnthemUI.icon("cap_melee")],
		["PROPULSEURS", ("Vol %d s" % int(pr["fly_seconds"])) if pr["fly"] else "Petit bond", "▲", pr["fly"], AnthemUI.icon("cap_propulseurs")],
		["CAPACITÉ ULTIME", Combat.ULT["name"] if no["ultimate"] else "Verrouillée", "✸", no["ultimate"], AnthemUI.icon("cap_ultime")],
	]
	var energy := Appearance.color(5)
	for k in cards.size():
		var cd: Array = cards[k]
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", AnthemUI.pad(10, 2, 10, 2))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if k > 0:
			# séparateur vertical de 1 px entre les emplacements
			p.draw.connect(func(): p.draw_line(Vector2(0, 6), Vector2(0, p.size.y - 6), AnthemUI.LINE, 1.0))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var head := _label(cd[0], 12, Color(0.72, 0.79, 0.88), true)
		head.add_theme_font_override("font", AnthemUI.label_font())
		v.add_child(head)
		var tex: Texture2D = cd[4]
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(0, 34)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if tex.resource_path.ends_with(".svg"):
				tr.custom_minimum_size = Vector2(0, 30)
				tr.modulate = energy.lerp(Color.WHITE, 0.45) if cd[3] else LOCKED
			elif not cd[3]:
				tr.modulate = Color(0.45, 0.48, 0.52, 0.6)
			v.add_child(tr)
		else:
			var g := _label(cd[2], 26, energy if cd[3] else LOCKED)
			g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(g)
		var n := _label(cd[1], 13, Color.WHITE if cd[3] else LOCKED)
		n.add_theme_font_override("font", AnthemUI.caption_font())
		n.add_theme_constant_override("line_spacing", -3)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.max_lines_visible = 2
		n.custom_minimum_size = Vector2(96, 0)
		v.add_child(n)
		p.add_child(v)
		_equip_box.add_child(p)


## Icône d'un emplacement de la barre d'équipement : celle de l'objet équipé, sinon celle du modèle de base.
func _eq_icon(slot: String, base_id: String) -> Texture2D:
	var it := Inventory.equipped_item(slot)
	return LootUI.icon_tight(it if not it.is_empty() else { "base": base_id })


func _eq_name(slot: String, fallback: String) -> String:
	var it := Inventory.equipped_item(slot)
	return "%s · %d" % [LootDB.item_name(it), int(it["power"])] if not it.is_empty() else fallback


func _stat_values() -> Array:
	var pr: Dictionary = Loadout.part("propulseurs")
	var jb: Dictionary = Loadout.part("jambes")
	var ca: Dictionary = Loadout.part("carapace")
	var no: Dictionary = Loadout.part("noyau")
	var mob := clampf((jb["walk_speed"] - 5.0) / 4.5 * 5.0 + pr["fly_seconds"] / 14.0 * 3.0 + (2.0 if jb["dash"] else 0.0), 0.0, 10.0)
	var prot := clampf(ca["max_shield"] / 110.0 * 6.0 + ca["max_health"] / 130.0 * 4.0, 0.0, 10.0)
	var ener := clampf(int(no["power_slots"]) * 3.0 + (2.0 if no["ultimate"] else 0.0) + (1.3 - no["cooldown_mult"]) / 0.55 * 2.0, 0.0, 10.0)
	var poids := clampf(3.0 + Loadout.tier["carapace"] * 2.0 + (2.0 if Loadout.tier["jambes"] == 0 else 0.0) - (1.0 if pr["fly"] else 0.0), 0.0, 10.0)
	return [["MOBILITÉ", mob], ["PROTECTION", prot], ["ÉNERGIE", ener], ["POIDS", poids]]


func _draw_stats() -> void:
	for ch in _stats_box.get_children():
		ch.queue_free()
	for sv in _stat_values():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var n := _label(sv[0], 14, Color(0.8, 0.86, 0.93), true)
		n.add_theme_font_override("font", AnthemUI.label_font())
		n.custom_minimum_size = Vector2(120, 0)
		h.add_child(n)
		# barre fine : piste de 2 px, remplissage bleu pâle, graduations tous les 2 points
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var f: float = sv[1] / 10.0
		bar.draw.connect(func():
			var y := bar.size.y * 0.5
			bar.draw_rect(Rect2(0, y - 1, bar.size.x, 2), Color(0.6, 0.72, 0.88, 0.18))
			for t in range(1, 5):
				bar.draw_rect(Rect2(bar.size.x * t / 5.0, y - 3, 1, 6), Color(0.6, 0.72, 0.88, 0.25))
			bar.draw_rect(Rect2(0, y - 1.5, bar.size.x * f, 3), ACCENT))
		h.add_child(bar)
		var val := _label("%.1f" % sv[1], 15, Color.WHITE, true)
		val.custom_minimum_size = Vector2(36, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(val)
		_stats_box.add_child(h)


func _update_focus() -> void:
	_turn_back = false
	var key: String = _cur_row().get("key", "")
	var slot := ""
	if key.begins_with("piece_"):
		slot = key.substr(6)
	elif key in ["vinyl", "place"]:
		var place: String = Appearance.current.get("vinyl_place", "chest")
		slot = "chest" if place == "chest" else ("back" if place == "back" else "arms")
	match slot:
		"helmet":
			_want_focus = Vector3(0, 1.7, 0)
			_want_dist = 2.6
		"chest":
			_want_focus = Vector3(0, 1.45, 0)
			_want_dist = 2.5
		"back":
			_turn_back = true
			_want_focus = Vector3(0, 1.45, 0)
			_want_dist = 2.6
		"arms":
			_want_focus = Vector3(0, 1.45, 0)
			_want_dist = 2.7
		"legs":
			_want_focus = Vector3(0, 0.8, 0)
			_want_dist = 2.6
		_:
			_want_focus = Vector3(0, 1.1, 0)
			_want_dist = 4.3


# ---------------------------------------------------------------- commandes
func _input(event: InputEvent) -> void:
	if _leaving:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_want_dist = maxf(1.0, _want_dist - 0.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_want_dist = minf(7.0, _want_dist + 0.25)
		return
	if event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.008
		_idle = 0.0
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_PAGEUP:
				_main(-1)
			KEY_PAGEDOWN:
				_main(1)
			KEY_TAB:
				_col_switch(-1 if event.shift_pressed else 1)
			KEY_X:
				_x()
			KEY_S:
				_save()
			KEY_C:
				_copy()
			KEY_V:
				_paste()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_accept()
			KEY_ESCAPE, KEY_BACKSPACE:
				_cancel()
			KEY_UP:
				_nav(Vector2i(0, -1))
			KEY_DOWN:
				_nav(Vector2i(0, 1))
			KEY_LEFT:
				_nav(Vector2i(-1, 0))
			KEY_RIGHT:
				_nav(Vector2i(1, 0))
		return
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				_main(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				_main(1)
			JOY_BUTTON_A:
				_accept()
			JOY_BUTTON_B:
				_cancel()
			JOY_BUTTON_X:
				_x()
			JOY_BUTTON_START:
				_save()
			JOY_BUTTON_BACK:
				if _clipboard == "":
					_copy()
				else:
					_paste()
			JOY_BUTTON_RIGHT_STICK:
				_yaw = 0.0
			JOY_BUTTON_DPAD_UP:
				_nav(Vector2i(0, -1))
			JOY_BUTTON_DPAD_DOWN:
				_nav(Vector2i(0, 1))
			JOY_BUTTON_DPAD_LEFT:
				_nav(Vector2i(-1, 0))
			JOY_BUTTON_DPAD_RIGHT:
				_nav(Vector2i(1, 0))


func _process(delta: float) -> void:
	# Gâchettes = colonne gauche / droite ; stick gauche = navigation avec répétition ; stick droit = rotation
	var lt := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.6
	var rt := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.6
	if lt and not _lt_down:
		_col_switch(-1)
	if rt and not _rt_down:
		_col_switch(1)
	_lt_down = lt
	_rt_down = rt
	var lx := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var ly := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var d := Vector2i.ZERO
	if absf(ly) > 0.6:
		d = Vector2i(0, signi(int(signf(ly))))
	elif absf(lx) > 0.6:
		d = Vector2i(signi(int(signf(lx))), 0)
	if d != Vector2i.ZERO:
		if d != _rep_dir:
			_nav(d)
			_rep_t = 0.35
		else:
			_rep_t -= delta
			if _rep_t <= 0.0:
				_nav(d)
				_rep_t = 0.09
	_rep_dir = d
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(rx) > 0.15:
		_yaw -= rx * delta * 2.4
		_idle = 0.0
	if absf(ry) > 0.2:
		_want_dist = clampf(_want_dist + ry * delta * 2.5, 1.0, 7.0)
	_idle += delta
	if _idle > 6.0:
		_yaw += delta * 0.25          # le socle tourne doucement quand on ne touche à rien
	if _turn_back:
		_yaw = lerp_angle(_yaw, PI, minf(1.0, delta * 3.0))
	_focus = _focus.lerp(_want_focus, minf(1.0, delta * 4.0))
	_dist = lerpf(_dist, _want_dist, minf(1.0, delta * 4.0))
	var off := Vector3(0, 0, -_dist).rotated(Vector3.RIGHT, -_pitch).rotated(Vector3.UP, _yaw)
	cam.global_position = Vector3(0, 0.25, 0) + _focus + off
	cam.look_at(Vector3(0, 0.25, 0) + _focus)
	# Mise au point sur le Solaris : net jusqu'à son dos, flou au-delà
	if _dof:
		_dof.dof_blur_far_distance = _dist + 0.9
		_dof.dof_blur_near_distance = maxf(0.3, _dist - 1.4)
	_update_tab_line(delta)
	# Soudure du bras robotisé de temps en temps
	_weld_t -= delta
	if _weld_t <= 0.0 and _weld:
		_weld_t = randf_range(2.5, 5.0)
		Fx.sparks(_weld.global_position, Vector3(-0.5, 1, -0.3), Color(0.6, 0.85, 1.0), 18, 4.0)
		Fx.flash(_weld.global_position, Color(0.6, 0.85, 1.0), 3.0, 4.0, 0.12)
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.text = ""
	_dirty_t -= delta
	if _dirty and _dirty_t <= 0.0:
		_dirty_t = 0.12
		_refresh()


func _set_tab(i: int) -> void:
	tab = wrapi(i, 0, TABS.size())
	col = 0
	row_i = [0, 0]
	_idle = 0.0
	_refresh()


func _main(dir: int) -> void:
	_set_tab(tab + dir)


func _col_switch(dir: int) -> void:
	var other := 1 - col if dir != 0 else col
	if _rows_of(other).is_empty():
		return
	col = other
	_idle = 0.0
	_refresh()


## Haut / bas : ligne suivante (on passe d'une colonne à l'autre aux extrémités) ; gauche / droite : vignette.
func _nav(d: Vector2i) -> void:
	_idle = 0.0
	var rows := _rows_of(col)
	if rows.is_empty():
		return
	if d.y != 0:
		var n: int = row_i[col] + d.y
		if n < 0 or n >= rows.size():
			var other := 1 - col
			if not _rows_of(other).is_empty() and ((n >= rows.size() and col == 0) or (n < 0 and col == 1)):
				col = other
				row_i[col] = 0 if n >= 0 else _rows_of(col).size() - 1
			else:
				row_i[col] = wrapi(n, 0, rows.size())
		else:
			row_i[col] = n
		_refresh()
		return
	if d.x != 0:
		var r := _cur_row()
		if r["kind"] == "slider":
			r["apply"].call(clampf(r["value"] + 0.05 * d.x, 0.0, 1.0))
			_refresh()
			return
		var items: Array = r["items"]
		if items.is_empty():
			return
		var i: int = wrapi(int(_cursor.get(r["key"], 0)) + d.x, 0, items.size())
		_cursor[r["key"]] = i
		_try(r, i)
		_refresh()


## Essayer la vignette sous le curseur : appliquée tout de suite si elle est débloquée (aperçu).
func _try(r: Dictionary, i: int) -> void:
	var it: Dictionary = r["items"][i]
	if it.get("locked", false):
		if r["key"].begins_with("piece_") or r["key"] == "packs":
			_toast_msg("Pas encore obtenu : missions, défis de borne, faveurs des peuples, exploration", 1.6)
		return
	if r.has("apply"):
		r["apply"].call(i)


func _accept() -> void:
	_idle = 0.0
	var r := _cur_row()
	if r.is_empty() or r["kind"] == "slider" or r["items"].is_empty():
		return
	var i: int = _cursor.get(r["key"], 0)
	if r.has("accept"):
		if r["items"][i].get("locked", false) and r["key"] != "modes":
			_try(r, i)
			return
		r["accept"].call(i)
	else:
		_try(r, i)
		_toast_msg("Validé", 0.8)
	_refresh()


func _cancel() -> void:
	_leave()


func _x() -> void:
	_idle = 0.0
	var r := _cur_row()
	if r.has("x") and r["items"].is_empty():
		return
	if r.has("x"):
		r["x"].call(_cursor.get(r["key"], 0))
	else:
		_play(Appearance.current["emotes"][randi() % 3])
	_refresh()


func _save() -> void:
	Appearance.save_preset(Appearance.active[Appearance.mode])
	_toast_msg("Preset « %s » sauvegardé" % Appearance.preset_name())
	_refresh()


func _copy() -> void:
	if TABS[tab] == "APPARENCE":
		_clipboard = Appearance.current["color_slots"][_zone]
		_toast_msg("Couleur de la zone %s copiée" % Catalog.ZONES[_zone])


func _paste() -> void:
	if TABS[tab] == "APPARENCE" and _clipboard != "":
		Appearance.set_color(_zone, _clipboard)
		_toast_msg("Couleur collée sur la zone %s" % Catalog.ZONES[_zone])
		_clipboard = ""
		_refresh()


## Aller directement à une ligne (démo, tests).
func goto(t, key: String) -> void:
	tab = TABS.find(t) if t is String else int(t)
	_build_cols()
	for c in 2:
		var rows := _rows_of(c)
		for i in rows.size():
			if rows[i]["key"] == key:
				col = c
				row_i[c] = i
	_refresh()


func _play(id: String) -> void:
	if solaris.anim:
		solaris.anim.play(id)


func _flash_core() -> void:
	var c := Appearance.color(5)
	Fx.flash(solaris.global_position + Vector3(0, 1.3, -0.4), c, 4.0, 4.0, 0.3)
	Fx.sparks(solaris.global_position + Vector3(0, 1.3, -0.3), Vector3(0, 1, -1), c, 14, 3.0)


## Reconfiguration du Solaris sur le socle : anneau, étincelles, pièces qui se remontent.
func _reconfigure(full := true) -> void:
	var c := Appearance.color(5)
	var base := solaris.global_position
	Fx.ring(base + Vector3(0, 0.3, 0), 1.6, c, 0.6, Vector3.UP, 0.12)
	Fx.ring(base + Vector3(0, 1.2, 0), 1.2, c, 0.5, Vector3.UP, 0.08)
	Fx.sparks(base + Vector3(0, 1.2, 0), Vector3.UP, c, 40, 5.0)
	Fx.flash(base + Vector3(0, 1.4, -0.5), c, 6.0, 6.0, 0.4)
	if solaris.look:
		solaris.look.refresh_all()
		for s in Catalog.SLOTS:
			solaris.look._pop(solaris.look._pieces.get(s, []))
	if full:
		_play("ignite")
		_toast_msg("Reconfiguration : mode %s" % Catalog.find(Catalog.MODES, Appearance.mode)["name"], 2.5)


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	Appearance.save()
	Progression.save()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.6)
	await tw.finished
	if Appearance.return_to != "":
		var to := Appearance.return_to
		Appearance.return_to = ""
		Appearance.came_from_atelier = true
		get_tree().change_scene_to_file(to)
	else:
		get_tree().quit()
