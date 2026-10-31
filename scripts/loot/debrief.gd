extends CanvasLayer
## Écran de fin de mission : XP gagnée et barre de niveau (avec ce que chaque niveau débloque), puis les
## butins révélés un par un, du moins rare au plus rare, avec un éclat doré pour le légendaire.
## A / Entrée : accélérer puis continuer · Y / F : aller à la Forge pour équiper.

var report: Dictionary
var _root: Control
var _dim: ColorRect
var _xp_l: Label
var _lvl_l: Label
var _fill: ColorRect
var _unlock_box: VBoxContainer
var _tiles: HFlowContainer
var _big: Control
var _foot: Label
var _flash: ColorRect
var _phase := 0                    # 0 XP, 1 révélation, 2 terminé
var _shown := 0
var _t := 0.0
var _next := 0.0
var _lvl := 1
var _xp_anim := 0.0
var _xp_target := 0.0
var _xp_total := 0
var _level_queue: Array = []
var _closing := false

const GOLD := Color(1.0, 0.82, 0.4)
const BLUE := Color(0.35, 0.68, 1.0)


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_lvl = int(report["level_before"])
	_xp_anim = float(report["xp_before"])
	_xp_total = int(report["xp_kills"]) + int(report["xp_crates"]) + int(report["xp_mission"])
	_level_queue = report.get("levels", []).duplicate()
	_build()
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.4)
	_next = 0.9


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.015, 0.035, 0.88)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_dim)
	var v := VBoxContainer.new()
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 70
	v.offset_right = -70
	v.offset_top = 40
	v.offset_bottom = -30
	v.add_theme_constant_override("separation", 10)
	_root.add_child(v)
	var head := HBoxContainer.new()
	var tick := ColorRect.new()
	tick.color = Color(1.0, 0.58, 0.16)
	tick.custom_minimum_size = Vector2(6, 44)
	head.add_child(tick)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.add_child(LootUI.label("MISSION ACCOMPLIE", 40, Color.WHITE, true))
	tv.add_child(LootUI.label("%s  ·  %s  ·  %d ennemi%s vaincu%s  ·  %d caisse%s" % [report["mission"], report["difficulty"],
		report["kills"], "s" if report["kills"] > 1 else "", "s" if report["kills"] > 1 else "", report["crates"], "s" if report["crates"] > 1 else ""], 15, LootUI.MUTED))
	head.add_child(tv)
	v.add_child(head)
	# XP
	var xp_panel := PanelContainer.new()
	var sb := LootUI.box(Color(0.025, 0.05, 0.085, 0.85), Color(0.3, 0.6, 0.95, 0.5), 1, 4)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	xp_panel.add_theme_stylebox_override("panel", sb)
	var xv := VBoxContainer.new()
	xv.add_theme_constant_override("separation", 6)
	xp_panel.add_child(xv)
	var xh := HBoxContainer.new()
	_lvl_l = LootUI.label("PILOTE NIVEAU %d" % _lvl, 22, Color.WHITE, true)
	_lvl_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xh.add_child(_lvl_l)
	_xp_l = LootUI.label("", 16, GOLD, true)
	xh.add_child(_xp_l)
	xv.add_child(xh)
	var lines := LootUI.label("Ennemis +%d XP   ·   Caisses +%d XP   ·   Mission +%d XP" % [report["xp_kills"], report["xp_crates"], report["xp_mission"]], 13, LootUI.MUTED)
	xv.add_child(lines)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 10)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.14, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_child(bg)
	_fill = ColorRect.new()
	_fill.color = BLUE
	_fill.anchor_bottom = 1.0
	bar.add_child(_fill)
	xv.add_child(bar)
	_unlock_box = VBoxContainer.new()
	xv.add_child(_unlock_box)
	v.add_child(xp_panel)
	# Butin
	var lh := HBoxContainer.new()
	lh.add_child(LootUI.label("BUTIN  ·  %d objet%s" % [report["items"].size(), "s" if report["items"].size() > 1 else ""], 18, Color.WHITE, true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.add_child(sp)
	var pity_txt := "Garantie légendaire : %d / %d missions sans or" % [report["pity"], report["pity_max"]]
	if report.get("pity_used", false):
		pity_txt = "Garantie légendaire déclenchée !"
	lh.add_child(LootUI.label(pity_txt, 13, GOLD if report.get("pity_used", false) else LootUI.MUTED))
	v.add_child(lh)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	_tiles = HFlowContainer.new()
	_tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tiles.add_theme_constant_override("h_separation", 8)
	_tiles.add_theme_constant_override("v_separation", 8)
	body.add_child(_tiles)
	_big = VBoxContainer.new()
	_big.custom_minimum_size = Vector2(390, 0)
	body.add_child(_big)
	v.add_child(body)
	_foot = LootUI.label("A : passer", 15, LootUI.MUTED, true)
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_foot)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.85, 0.4, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	_update_xp()


func _update_xp() -> void:
	var need := float(Progression.xp_to_next(_lvl))
	_fill.anchor_right = clampf(_xp_anim / need, 0.0, 1.0)
	_lvl_l.text = "PILOTE NIVEAU %d" % _lvl
	_xp_l.text = "+%d XP" % _xp_total


func _process(delta: float) -> void:
	if _closing:
		return
	_t += delta
	match _phase:
		0:
			if _t < _next:
				return
			# La barre se remplit ; à chaque niveau franchi, bannière et déblocage
			var need := float(Progression.xp_to_next(_lvl))
			var target: float = need if not _level_queue.is_empty() else float(report["xp_after"])
			_xp_anim = move_toward(_xp_anim, target, need * delta * 0.9)
			if not _level_queue.is_empty() and _xp_anim >= need - 0.01:
				_lvl = int(_level_queue.pop_front())
				_xp_anim = 0.0
				_level_up(_lvl)
				_next = _t + 0.9
			elif _level_queue.is_empty() and absf(_xp_anim - target) < 0.5:
				_phase = 1
				_next = _t + 0.5
			_update_xp()
		1:
			if _t >= _next:
				if _shown < report["items"].size():
					_reveal(report["items"][_shown])
					_shown += 1
					var r: int = int(report["items"][_shown - 1]["rarity"])
					_next = _t + (0.55 if r < 3 else (0.9 if r < 5 else 1.6))
				else:
					_phase = 2
					_foot.text = "A : continuer    ·    Y : aller à la Forge (équiper, comparer, recycler)"
					_foot.add_theme_color_override("font_color", Color.WHITE)


func _level_up(l: int) -> void:
	var t := Progression.reward_text(l)
	var lab := LootUI.label("▲ NIVEAU %d%s" % [l, ("  —  " + t) if t != "" else ""], 16, GOLD, true)
	_unlock_box.add_child(lab)
	lab.pivot_offset = Vector2(0, 10)
	lab.scale = Vector2(1.3, 1.3)
	var tw := create_tween()
	tw.tween_property(lab, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash.color = Color(0.4, 0.7, 1.0, 0.25)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.5)
	_ui_sound("loot_pick")


func _reveal(it: Dictionary) -> void:
	var r := int(it["rarity"])
	var c := LootDB.rarity_color(r)
	var tile := PanelContainer.new()
	var sb := LootUI.box(Color(0.03, 0.06, 0.1, 0.95), c, 2, 4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(c.r, c.g, c.b, 0.4)
	sb.shadow_size = 4 + r * 2
	tile.add_theme_stylebox_override("panel", sb)
	tile.custom_minimum_size = Vector2(172, 92)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 1)
	var g := LootUI.symbol(it, 26, c)
	if g is Label:
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		g.custom_minimum_size = Vector2(0, 40)
	tv.add_child(g)
	var n := LootUI.label(LootDB.item_name(it), 12, Color.WHITE)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.custom_minimum_size = Vector2(156, 0)
	tv.add_child(n)
	var pw := LootUI.label("%s · %d" % [LootDB.rarity_name(r), int(it["power"])], 11, c)
	pw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(pw)
	tile.add_child(tv)
	_tiles.add_child(tile)
	tile.pivot_offset = Vector2(86, 46)
	tile.scale = Vector2(0.2, 0.2)
	tile.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(tile, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tile, "modulate:a", 1.0, 0.2)
	for ch in _big.get_children():
		ch.queue_free()
	var cmp := {}
	for s in Inventory.ALL_SLOTS:
		var e := Inventory.equipped_item(s)
		if not e.is_empty() and Inventory.fits(s, it):
			cmp = e
			break
	_big.add_child(LootUI.card(it, cmp, 390.0, "NOUVEL OBJET  ·  comparé à l'équipé" if not cmp.is_empty() else "NOUVEL OBJET"))
	if r >= 4:
		_flash.color = Color(c.r, c.g, c.b, 0.55 if r == 5 else 0.3)
		create_tween().tween_property(_flash, "color:a", 0.0, 0.9 if r == 5 else 0.5)
		_burst(tile, c, 60 if r == 5 else 24)
		_ui_sound("loot_gold" if r == 5 else "loot_drop")
	else:
		_ui_sound("loot_pick")


## Gerbe d'étincelles 2D autour de la tuile (chef-d'œuvre et légendaire).
func _burst(tile: Control, c: Color, n: int) -> void:
	var p := CPUParticles2D.new()
	p.amount = n
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 1.1
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 380.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = c.lightened(0.3)
	p.position = Vector2(75, 46)
	tile.add_child(p)
	p.emitting = true


func _ui_sound(prefix: String) -> void:
	var list: Array = Fx._variants(prefix)
	if list.is_empty():
		return
	var a := AudioStreamPlayer.new()
	a.stream = list.pick_random()
	a.volume_db = -4.0
	a.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)


# ---------------------------------------------------------------- commandes
func _input(event: InputEvent) -> void:
	if _closing:
		return
	var accept: bool = (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A) \
		or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE])
	var forge: bool = (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y) \
		or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F)
	if accept:
		get_viewport().set_input_as_handled()
		skip_or_close()
	elif forge and _phase == 2:
		get_viewport().set_input_as_handled()
		go_forge()


## A : termine la révélation d'un coup, puis ferme.
func skip_or_close() -> void:
	if _phase < 2:
		while not _level_queue.is_empty():
			_lvl = int(_level_queue.pop_front())
			_level_up(_lvl)
		_xp_anim = float(report["xp_after"])
		_update_xp()
		_phase = 1
		while _shown < report["items"].size():
			_reveal(report["items"][_shown])
			_shown += 1
		_next = _t
		return
	close()


func close() -> void:
	_closing = true
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.3)
	await tw.finished
	get_tree().paused = false
	queue_free()


func go_forge() -> void:
	_closing = true
	get_tree().paused = false
	var cs := get_tree().current_scene
	Appearance.return_to = cs.scene_file_path if cs and cs.scene_file_path != "" else "res://scenes/main.tscn"
	Expedition.forge_tab = "ARSENAL"
	queue_free()
	get_tree().change_scene_to_file.call_deferred("res://scenes/atelier.tscn")
