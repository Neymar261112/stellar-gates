extends CanvasLayer
## Affichage : nom, chaleur, état, zone, balises, messages et aide des commandes.

var _heat: ProgressBar
var _heat_txt: Label
var _state: Label
var _zone: Label
var _beacons: Label
var _msg: Label
var _msg_t := 0.0
var _reticle: Control
var _ammo: Label
var _weapon: Label
var _hp: ProgressBar
var _shield: ProgressBar
var _targets: Label
var _cards: Array = []       # [{panel, status, style}]
var _part_labels := {}
var _combo: Label
var _wave: Label

@onready var player: CharacterBody3D = get_parent().get_node("Player")
var world: Node3D
var _title: Label

const GOLD := Color(0.84, 0.65, 0.25)
const MUTED := Color(0.70, 0.74, 0.80)


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.125, 0.15, 0.2, 0.85)
	style.border_color = Color(0.34, 0.39, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(_label("SOLARIS", 20, Color.WHITE))
	_title = _label("Vol moyen · 8 s avant surchauffe", 12, MUTED)
	box.add_child(_title)
	_heat_txt = _label("CHALEUR   0 %", 12, MUTED)
	box.add_child(_heat_txt)
	_heat = ProgressBar.new()
	_heat.max_value = 100
	_heat.show_percentage = false
	_heat.custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(4)
	_heat.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.12, 0.16)
	bg.set_corner_radius_all(4)
	_heat.add_theme_stylebox_override("background", bg)
	box.add_child(_heat)
	_state = _label("Au sol", 13, Color.WHITE)
	box.add_child(_state)
	_zone = _label("Plaine", 13, Color.WHITE)
	box.add_child(_zone)
	_beacons = _label("Balises récupérées : 0 / 3", 13, Color(0.35, 0.84, 0.54))
	box.add_child(_beacons)
	_targets = _label("Cibles détruites : 0 / 0", 13, Color(1.0, 0.6, 0.35))
	box.add_child(_targets)
	_wave = _label("", 13, Color(1.0, 0.35, 0.3))
	box.add_child(_wave)
	box.add_child(_label("COMPOSANTS (GAMEPLAY)", 11, GOLD))
	for s in Loadout.SLOTS:
		var l := _label("", 12, MUTED)
		box.add_child(l)
		_part_labels[s] = l
	_refresh_parts()
	Loadout.changed.connect(func(_s): _refresh_parts())
	_build_combat_hud()
	_build_power_cards()
	_msg = _label("", 18, GOLD)
	_msg.position = Vector2(16, 200)
	add_child(_msg)
	var keys := _label("Manette : stick gauche se déplacer · stick droit caméra · A sauter/voler · Y changer d'arme (au sol) / couper les propulseurs (en vol) · B esquive · RT tirer (au sol ou en stationnaire) · LT viser · R3 mêlée · X recharger · LB grenade · RB lanceur · LB+RB batterie de missiles · Start pause\nClavier : ZQSD · Espace voler · Ctrl couper les propulseurs · T ou molette changer d'arme · Maj esquive · clic gauche tirer · clic droit viser · V mêlée · X recharger · E grenade · R lanceur · F ultime · Tab pause · Échap souris / quitter", 12, MUTED)
	keys.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	keys.position = Vector2(16, -112)
	keys.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(keys)
	player.message.connect(show_message)
	player.combat.hit.connect(func(_t, _a, _m): _reticle.queue_redraw())
	get_parent().world_changed.connect(_on_world_changed)
	if get_parent().world:
		_on_world_changed(get_parent().world)
	show_message("Le Solaris est une épave : trouve les caisses de pièces pour le reconstruire.\nL'apparence se choisit à l'Atelier (carte de la Terre, rampe de l'Aster).", 5.0)


func _refresh_parts() -> void:
	for s in Loadout.SLOTS:
		var t: int = Loadout.tier[s]
		_part_labels[s].text = "%s : %s" % [Loadout.SLOT_NAMES[s], Loadout.part(s)["name"]]
		_part_labels[s].add_theme_color_override("font_color", GOLD if t == 2 else (Color.WHITE if t == 1 else Color(0.75, 0.6, 0.5)))
	var pr: Dictionary = Loadout.part("propulseurs")
	var wname: String = world.def["name"] if world else ""
	if pr["fly"]:
		_title.text = "Vol · %d s avant surchauffe · %s" % [int(pr["fly_seconds"]), wname]
	else:
		_title.text = "Pas de vol (tuyère de récup) · " + wname


func _on_world_changed(w: Node3D) -> void:
	world = w
	_refresh_parts()
	_beacons.text = "Balises récupérées : 0 / %d" % w.def["beacons"].size()
	w.message.connect(show_message)
	w.beacons_changed.connect(func(got: int, total: int): _beacons.text = "Balises récupérées : %d / %d" % [got, total])
	_targets.text = "Cibles détruites : 0 / %d" % w.targets_total()
	w.targets_changed.connect(func(down: int, total: int): _targets.text = "Cibles détruites : %d / %d" % [down, total])
	_wave.text = ""
	w.wave_changed.connect(func(wave: int, total: int, remaining: int): _wave.text = "Vague %d / %d · ennemis restants : %d" % [wave, total, remaining])


func _build_combat_hud() -> void:
	# Réticule au centre
	_reticle = Control.new()
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.draw.connect(_draw_reticle)
	add_child(_reticle)
	# Panneau bas-droite : arme, munitions, bouclier, vie
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.position = Vector2(-16, -16)
	panel.custom_minimum_size = Vector2(260, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.125, 0.15, 0.2, 0.85)
	style.border_color = Color(0.34, 0.39, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	_weapon = _label(Combat.WEAPONS[0]["name"].to_upper(), 13, MUTED)
	box.add_child(_weapon)
	_ammo = _label("30 / ∞", 26, Color.WHITE)
	box.add_child(_ammo)
	box.add_child(_label("BOUCLIER", 11, MUTED))
	_shield = _bar(Color(0.45, 0.75, 1.0))
	box.add_child(_shield)
	box.add_child(_label("VIE", 11, MUTED))
	_hp = _bar(Color(0.45, 0.85, 0.5))
	box.add_child(_hp)


func _build_power_cards() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.position = Vector2(-255, -70)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var defs := []
	for i in 2:
		defs.append({ "key": Combat.SLOT_KEYS[i] + " · " + Combat.SLOT_NAMES[i].to_upper(), "name": "" })
	defs.append({ "key": Combat.ULT["key"], "name": Combat.ULT["name"] })
	for p in defs:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(164, 0)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.125, 0.15, 0.2, 0.85)
		st.border_color = Color(0.34, 0.39, 0.48)
		st.set_border_width_all(1)
		st.set_corner_radius_all(8)
		st.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", st)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		card.add_child(v)
		v.add_child(_label(p["key"], 11, GOLD))
		var name := _label(p["name"], 13, Color.WHITE)
		v.add_child(name)
		var status := _label("PRÊT", 11, MUTED)
		v.add_child(status)
		row.add_child(card)
		_cards.append({ "panel": card, "name": name, "status": status, "style": st })
	_combo = _label("COMBO !", 48, Color(1.0, 0.6, 0.2))
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo.size = Vector2(640, 130)
	_combo.add_theme_constant_override("outline_size", 10)
	_combo.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.0))
	_combo.set_anchors_preset(Control.PRESET_CENTER)
	_combo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_combo.position = Vector2(-320, -200)
	_combo.pivot_offset = Vector2(320, 65)
	_combo.modulate.a = 0.0
	add_child(_combo)


func _update_cards() -> void:
	var c: Combat = player.combat
	for i in 3:
		var card: Dictionary = _cards[i]
		var txt := "PRÊT"
		var ready := true
		if i < 2:
			var p: Dictionary = c.power_in_slot(i)
			card["name"].text = p["name"]
			if i >= int(Loadout.stat("noyau", "power_slots")):
				txt = "NOYAU BRIDÉ"
				ready = false
				card["status"].text = txt
				card["status"].add_theme_color_override("font_color", MUTED)
				card["style"].border_color = Color(0.34, 0.39, 0.48)
				continue
			card["name"].add_theme_color_override("font_color", Color(1.0, 0.75, 0.45) if p["role"] == "Amorce" else Color(0.6, 0.85, 1.0))
			if c.power_cd[i] > 0.0:
				txt = "%.1f s" % c.power_cd[i]
				ready = false
		else:
			if not Loadout.stat("noyau", "ultimate"):
				txt = "NOYAU BRIDÉ"
				ready = false
			elif c.ult_t > 0.0:
				txt = "%d SALVE%s · %d CIBLE%s" % [c.ult_salvos, "S" if c.ult_salvos > 1 else "", c.ult_locks.size(), "S" if c.ult_locks.size() > 1 else ""]
			elif c.ult_charge < 100.0:
				txt = "CHARGE %d %%" % int(c.ult_charge)
				ready = false
		card["status"].text = txt
		card["status"].add_theme_color_override("font_color", GOLD if ready else MUTED)
		card["style"].border_color = GOLD if ready else Color(0.34, 0.39, 0.48)
	if c.combo_name != "":
		_combo.text = "COMBO\n" + c.combo_name
	_combo.add_theme_color_override("font_color", c.combo_color)
	_combo.modulate.a = clampf(c.combo_flash, 0.0, 1.0)
	_combo.scale = Vector2.ONE * (1.0 + maxf(0.0, c.combo_flash - 0.9) * 2.0)


func _bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = 100
	b.value = 100
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 9)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	b.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.12, 0.16)
	bg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", bg)
	return b


func _draw_reticle() -> void:
	var c: Combat = player.combat
	if c.is_dead():
		return
	var on_target := c.lock_target != null
	var col := Color(1.0, 0.35, 0.3) if on_target else Color(1, 1, 1, 0.9)
	var r := 7.0 if c.aiming else 12.0
	var gap := 4.0 if c.aiming else 7.0
	_reticle.draw_arc(Vector2.ZERO, r, 0, TAU, 32, col, 1.5)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		_reticle.draw_line(d * (r + gap), d * (r + gap + 6.0), col, 2.0)
	_reticle.draw_circle(Vector2.ZERO, 1.5, col)
	if c.hit_marker > 0.0:
		var hc := Color(1, 0.9, 0.5)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_reticle.draw_line(d * 5.0, d * 11.0, hc, 2.5)
	if c.reloading > 0.0:
		_reticle.draw_arc(Vector2.ZERO, r + 16.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - c.reloading / float(c.current()["reload"])), 32, GOLD, 3.0)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


func show_message(text: String, seconds: float = 2.2) -> void:
	_msg.text = text
	_msg_t = seconds
	_msg.modulate.a = 1.0


func _process(delta: float) -> void:
	_heat.value = player.heat * 100.0
	var fill: StyleBoxFlat = _heat.get_theme_stylebox("fill")
	fill.bg_color = Color(1.0, 0.42, 0.29) if player.heat > 0.75 else GOLD
	_heat_txt.text = "CHALEUR   " + ("SURCHAUFFE" if player.overheat > 0.0 else "%d %%" % int(player.heat * 100))
	_state.text = player.state_label()
	_zone.text = player.zone_label()
	var c: Combat = player.combat
	_weapon.text = c.weapon_name().to_upper() + ("   ·   Y : " + c.weapon_def(1 - c.weapon_index)["family"].to_lower() if c.switch_t <= 0.0 else "")
	_ammo.text = ("CHANGEMENT D'ARME" if c.switch_t > 0.0 else "RECHARGEMENT" if c.reloading > 0.0 else "%d / %d" % [c.ammo, c.mag_size])
	_ammo.add_theme_color_override("font_color", GOLD if c.reloading > 0.0 or c.ammo <= 5 else Color.WHITE)
	_shield.value = c.shield / c.max_shield * 100.0
	_hp.value = c.health / c.max_health * 100.0
	_reticle.queue_redraw()
	_update_cards()
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg.modulate.a = 0.0
	if Input.is_action_just_pressed("quit") and not get_tree().paused:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			get_tree().quit()
