extends Node
## Expedition (autoload) : le butin PENDANT une mission (ExpeditionBag) et l'écran de fin.
## - Les ennemis (signal died) et les caisses lâchent des diamants colorés (LootDrop) ; au ramassage on ne
##   voit que la rareté. L'XP gagnée s'accumule aussi dans le sac.
## - Quand la mission est accomplie (vagues du champ de tir terminées), le sac est livré : XP pilote,
##   récompenses de mission (type d'objet favorisé), garantie de légendaire, puis écran de fin qui révèle
##   les objets un par un, du moins rare au plus rare.
## - La difficulté choisie à la Forge multiplie la vie des ennemis et améliore le butin.

signal collected(item: Dictionary)
signal mission_completed(report: Dictionary)

var bag: Array = []
var xp_kills := 0
var xp_crates := 0
var kills := 0
var crates := 0
var rng := RandomNumberGenerator.new()
var enabled := true
var force := false                 # tests et vidéos : butin actif quelle que soit la scène
const MISSION_SCENES := ["res://scenes/main.tscn", "res://scenes/elyra_clairiere.tscn"]
var debrief_delay := 2.5
var forge_tab := ""                # onglet à ouvrir en arrivant à la Forge depuis l'écran de fin

var _hud: CanvasLayer
var _toasts: VBoxContainer
var _pilot_l: Label
var _bag_l: Label
var _xp_fill: ColorRect
var _xp_pending: ColorRect
var _xp_bar: Control
var _debrief: Node


func _ready() -> void:
	rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_build_hud()
	Progression.changed.connect(_refresh_hud)
	Progression.challenge_done.connect(func(c): _toast("DÉFI RÉUSSI : %s  +%d XP" % [c["name"], int(c.get("xp", 0))], Color(1.0, 0.8, 0.4), 15, 3.5))
	_refresh_hud()


func reset_bag() -> void:
	bag = []
	xp_kills = 0
	xp_crates = 0
	kills = 0
	crates = 0
	_refresh_hud()


# ---------------------------------------------------------------- branchements
func _on_node_added(n: Node) -> void:
	if n is Enemy and _in_mission_scene():
		# setup() a déjà fixé la vie : on applique la difficulté avant le _ready de l'ennemi
		var m: float = float(Progression.difficulty_def()["enemy_hp"])
		n.max_hp *= m
		n.hp = n.max_hp
		n.died.connect(_on_enemy_died)


func _in_mission_scene() -> bool:
	var cs := get_tree().current_scene
	return enabled and cs != null and (force or cs.scene_file_path in MISSION_SCENES)


func _process(_delta: float) -> void:
	if _hud:
		_hud.visible = _in_mission_scene() and not (_debrief and is_instance_valid(_debrief))


func _on_enemy_died(e: Node) -> void:
	if not _in_mission_scene():
		return
	var t: Dictionary = LootDB.tables()["enemies"].get(e.kind, { "chance": 0.1, "xp": 20 })
	kills += 1
	Progression.count("kills")
	var xp := roundi(float(t["xp"]) * float(Progression.difficulty_def()["xp"]))
	xp_kills += xp
	_xp_toast(xp)
	if rng.randf() < float(t["chance"]):
		var it := LootRoll.roll(rng, { "difficulty": Progression.difficulty, "rarity_bonus": int(t.get("rarity_bonus", 0)),
			"mission": _mission_def().get("name", "Expédition") })
		LootDrop.spawn(e.get_parent(), it, e.center())
	_refresh_hud()


## Caisse ouverte (part_crate.gd) : un butin d'au moins Peu commun (Rare pour les caisses d'origine).
func crate_opened(parent: Node, pos: Vector3, tier: int) -> void:
	var t: Dictionary = LootDB.tables()["crates"]
	var min_r := int(t["min_rarity"].get(str(tier), 1))
	var it := LootRoll.roll(rng, { "difficulty": Progression.difficulty, "min_rarity": min_r,
		"mission": _mission_def().get("name", "Expédition") })
	LootDrop.spawn(parent, it, pos + Vector3(0, 1.0, 0))
	crates += 1
	Progression.count("crates")
	xp_crates += int(t["xp"])
	_xp_toast(int(t["xp"]))


## Un diamant ramassé : dans le sac, détail masqué.
func collect(it: Dictionary) -> void:
	bag.append(it)
	collected.emit(it)
	_loot_toast(int(it["rarity"]))
	_refresh_hud()


func _mission_def(world_id := "") -> Dictionary:
	if world_id == "":
		var w = get_tree().current_scene.get("world") if get_tree().current_scene else null
		world_id = w.def["id"] if w != null and w.get("def") is Dictionary else "elyra"
	return LootDB.tables()["missions"].get(world_id, { "id": world_id, "name": "Expédition", "favors": "", "rewards": 1, "xp": 200 })


# ---------------------------------------------------------------- fin de mission
## Livre le sac : récompenses de mission, garantie de légendaire, XP, inventaire, sauvegarde, écran de fin.
func complete_mission(world_id := "", show := true) -> Dictionary:
	var md := _mission_def(world_id)
	var diff := Progression.difficulty_def()
	var rewards := []
	for i in int(md["rewards"]):
		rewards.append(LootRoll.roll(rng, { "difficulty": Progression.difficulty, "favors": md.get("favors", ""), "mission": md["name"] }))
	var all: Array = bag + rewards
	var pity_t: Dictionary = LootDB.tables()["pity"]
	var gold := all.any(func(it): return int(it["rarity"]) >= int(pity_t["rarity"]))
	var pity_used := false
	if not gold and Progression.pity + 1 >= int(pity_t["missions"]):
		# Garantie : la dernière récompense de mission devient légendaire
		var forced := LootRoll.roll(rng, { "difficulty": Progression.difficulty, "rarity": int(pity_t["rarity"]), "favors": md.get("favors", ""), "mission": md["name"] })
		if rewards.is_empty():
			rewards.append(forced)
		else:
			rewards[rewards.size() - 1] = forced
		all = bag + rewards
		gold = true
		pity_used = true
	Progression.pity = 0 if gold else Progression.pity + 1
	Progression.count("missions")
	Progression.count("masterworks", all.filter(func(it): return int(it["rarity"]) == 4).size())
	Progression.count("legendaries", all.filter(func(it): return int(it["rarity"]) >= 5).size())
	var xp_mission := roundi(float(md["xp"]) * float(diff["xp"]))
	var report := {
		"mission": md["name"], "difficulty": diff["name"], "kills": kills, "crates": crates,
		"xp_kills": xp_kills, "xp_crates": xp_crates, "xp_mission": xp_mission,
		"level_before": Progression.level, "xp_before": Progression.xp,
		"items": [], "pity": Progression.pity, "pity_max": int(pity_t["missions"]), "pity_used": pity_used,
	}
	var levels := Progression.add_xp(xp_kills + xp_crates + xp_mission)
	for it in all:
		report["items"].append(Inventory.add(it))
	report["items"].sort_custom(func(a, b): return a["rarity"] < b["rarity"] or (a["rarity"] == b["rarity"] and a["power"] < b["power"]))
	report["levels"] = levels
	report["level_after"] = Progression.level
	report["xp_after"] = Progression.xp
	Progression.missions_done += 1
	Progression.save()
	reset_bag()
	mission_completed.emit(report)
	if show:
		show_debrief(report)
	return report


func show_debrief(report: Dictionary) -> void:
	if _debrief and is_instance_valid(_debrief):
		_debrief.queue_free()
	_debrief = load("res://scripts/loot/debrief.gd").new()
	_debrief.report = report
	get_tree().root.add_child(_debrief)


## Appelé par world.gd quand le champ de tir est sécurisé.
func on_arena_cleared(world_id: String) -> void:
	if not _in_mission_scene():
		return
	await get_tree().create_timer(debrief_delay).timeout
	complete_mission(world_id)


# ---------------------------------------------------------------- affichage en mission
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	add_child(_hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(root)
	# Niveau pilote et sac (en haut à droite)
	var box := VBoxContainer.new()
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.offset_left = -300
	box.offset_right = -24
	box.offset_top = 150
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	root.add_child(box)
	_pilot_l = LootUI.label("PILOTE NIV. 1", 14, Color.WHITE, true)
	_pilot_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_pilot_l)
	_xp_bar = Control.new()
	_xp_bar.custom_minimum_size = Vector2(0, 5)
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.14, 0.2, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xp_bar.add_child(bg)
	_xp_pending = ColorRect.new()
	_xp_pending.color = Color(1.0, 0.85, 0.45, 0.45)
	_xp_pending.anchor_bottom = 1.0
	_xp_bar.add_child(_xp_pending)
	_xp_fill = ColorRect.new()
	_xp_fill.color = Color(0.35, 0.68, 1.0)
	_xp_fill.anchor_bottom = 1.0
	_xp_bar.add_child(_xp_fill)
	box.add_child(_xp_bar)
	_bag_l = LootUI.label("", 13, Color(1.0, 0.85, 0.5))
	_bag_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_bag_l)
	# Ramassages (à droite, au milieu)
	_toasts = VBoxContainer.new()
	_toasts.anchor_left = 1.0
	_toasts.anchor_right = 1.0
	_toasts.anchor_top = 0.5
	_toasts.anchor_bottom = 0.5
	_toasts.offset_left = -320
	_toasts.offset_right = -24
	_toasts.offset_top = -40
	_toasts.offset_bottom = 200
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 4)
	root.add_child(_toasts)


func _refresh_hud() -> void:
	if _pilot_l == null:
		return
	_pilot_l.text = "PILOTE NIV. %d  ·  %s" % [Progression.level, Progression.difficulty_def()["name"].to_upper()]
	var need := float(Progression.xp_to_next())
	_xp_fill.anchor_right = clampf(Progression.xp / need, 0.0, 1.0)
	_xp_pending.anchor_right = clampf((Progression.xp + xp_kills + xp_crates) / need, 0.0, 1.0)
	_bag_l.text = ("◆ %d butin%s dans le sac" % [bag.size(), "s" if bag.size() > 1 else ""]) if bag.size() > 0 else ""


func _toast(text: String, color: Color, size: int, life: float) -> void:
	if _toasts == null:
		return
	var p := PanelContainer.new()
	var sb := LootUI.box(Color(0.02, 0.04, 0.07, 0.75), Color(color.r, color.g, color.b, 0.9), 0, 2)
	sb.border_width_left = 4
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	var l := LootUI.label(text, size, color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(l)
	_toasts.add_child(p)
	if _toasts.get_child_count() > 6:
		_toasts.get_child(0).queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(life)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _loot_toast(r: int) -> void:
	var c := LootDB.rarity_color(r)
	var txt := "◆ " + LootDB.rarity_name(r).to_upper()
	if r >= 5:
		txt += " !"
	_toast(txt, c, 16 + (4 if r >= 4 else 0), 2.6 + r * 0.3)


func _xp_toast(xp: int) -> void:
	_toast("+%d XP" % xp, Color(0.6, 0.8, 1.0), 12, 1.0)
