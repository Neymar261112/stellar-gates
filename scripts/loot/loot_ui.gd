extends RefCounted
class_name LootUI
## Fiches d'objet (écran de fin de mission, Arsenal de la Forge, comparaison) : rareté, puissance,
## stats principales, inscriptions locales / globales, effet spécial. Construit en code, comme la Forge.

const MUTED := Color(0.6, 0.66, 0.74)
const GOOD := Color(0.45, 0.95, 0.5)
const BAD := Color(1.0, 0.42, 0.38)
const BG := Color(0.025, 0.05, 0.085, 0.92)

const AnthemUI := preload("res://scripts/ui_anthem.gd")

static var _wide: FontVariation
static var _forge := false         # fiche en cours de construction pour la Forge (polices Barlow)


static func font_wide() -> FontVariation:
	if _wide == null:
		_wide = FontVariation.new()
		_wide.base_font = ThemeDB.fallback_font
		_wide.spacing_glyph = 2
		_wide.variation_embolden = 0.6
	return _wide


static func label(text: String, size: int, color: Color, wide := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	if _forge:
		l.add_theme_font_override("font", AnthemUI.title_font() if wide else AnthemUI.body_font())
	elif wide:
		l.add_theme_font_override("font", font_wide())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func box(bg: Color, edge: Color, width := 1, radius := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	return sb


static func glyph(cat: String) -> String:
	return { "weapon": "▬", "ability": "◆", "component": "⚙" }.get(cat, "◇")


# ---------------------------------------------------------------- visuels 3D (modèles Meshy de cyril)
## Modèle et vignette d'un objet : assets/loot/<base>.glb et assets/loot/icons/<base>.png, produits par
## tools/meshy_loot.py. Version travaillée si elle existe : <base>_m (chef-d'œuvre), <base>_l (légendaire).
static var _tex_cache := {}


static func _asset(it: Dictionary, folder: String, ext: String) -> String:
	var b: String = it.get("base", "")
	var tries := [b]
	if int(it.get("rarity", 0)) >= 5:
		tries.push_front(b + "_l")
	if int(it.get("rarity", 0)) >= 4:
		tries.insert(tries.size() - 1, b + "_m")
	for t in tries:
		var p := "res://assets/loot/%s%s.%s" % [folder, t, ext]
		if ResourceLoader.exists(p):
			return p
	return ""


static func icon_tex(it: Dictionary) -> Texture2D:
	var p := _asset(it, "icons/", "png")
	if p == "":
		# composants : icône vectorielle au trait, une par type (assets/ui/icons/comp_<base>.svg)
		p = "res://assets/ui/icons/comp_%s.svg" % it.get("base", "")
		if not ResourceLoader.exists(p):
			return null
	if not _tex_cache.has(p):
		_tex_cache[p] = load(p)
	return _tex_cache[p]


static var _tight := {}


## Même vignette, recadrée au plus près de l'objet (les rendus 512 px ont beaucoup de vide autour).
static func icon_tight(it: Dictionary) -> Texture2D:
	var t := icon_tex(it)
	if t == null or t.resource_path.ends_with(".svg"):
		return t
	if not _tight.has(t):
		var img := t.get_image()
		if img == null:
			return t
		if img.is_compressed():
			img.decompress()
		var a := AtlasTexture.new()
		a.atlas = t
		a.region = Rect2(img.get_used_rect().grow(4).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		_tight[t] = a
	return _tight[t]


## Vignette de l'objet (rendu 3D) ou, à défaut, son symbole coloré.
static func symbol(it: Dictionary, size: int, color: Color) -> Control:
	var t := icon_tex(it)
	if t == null:
		return label(glyph(LootDB.item_category(it)), size, color)
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size) * 1.7
	if t.resource_path.ends_with(".svg"):
		r.custom_minimum_size = Vector2(size, size) * 1.3
		r.modulate = color.lerp(Color.WHITE, 0.55)   # icône au trait : blanche, teintée par la rareté
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Le modèle 3D qui tourne lentement sur son socle (fiche d'objet). Vide si l'objet n'a pas encore de modèle.
static func model_view(it: Dictionary, height := 190.0) -> Control:
	var p := _asset(it, "", "glb")
	if p == "":
		return null
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(0, height)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.62, 0.75)
	env.environment.ambient_light_energy = 0.8
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.12, 1.85)
	cam.rotation.x = -0.14
	cam.fov = 38.0
	vp.add_child(cam)
	for l in [[Vector3(-0.7, -0.6, 0), 1.6, Color(1.0, 0.95, 0.88)], [Vector3(-0.3, 2.6, 0), 1.1, Color(0.6, 0.75, 1.0)]]:
		var d := DirectionalLight3D.new()
		d.rotation = l[0]
		d.light_energy = l[1]
		d.light_color = l[2]
		vp.add_child(d)
	var pivot := Node3D.new()
	vp.add_child(pivot)
	var model: Node3D = (load(p) as PackedScene).instantiate()
	pivot.add_child(model)
	# arme Épique et au-dessus : liseré lumineux de la rareté, comme l'arme tenue en jeu
	if LootDB.item_category(it) == "weapon":
		var rim := Combat.rarity_overlay(int(it.get("rarity", 0)))
		if rim:
			for mi in model.find_children("*", "MeshInstance3D", true, false):
				mi.material_overlay = rim
	# Socle lumineux à la couleur de la rareté
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.46
	ring.mesh = tm
	var rc := LootDB.rarity_color(int(it.get("rarity", 0)))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = rc
	ring.material_override = m
	ring.position = Vector3(0, -0.6, 0)
	vp.add_child(ring)
	pivot.rotation.y = 0.6
	box.ready.connect(func():
		var tw := pivot.create_tween().set_loops()
		tw.tween_property(pivot, "rotation:y", 0.6 + TAU, 9.0).from(0.6))
	return box


## Stats principales d'un exemplaire, sans les bonus globaux du reste de l'exo : [[libellé, valeur, texte, plus_haut_est_mieux]].
static func key_stats(it: Dictionary) -> Array:
	var b := LootDB.base(it["base"])
	var bo := BuildStats.item_bonuses(it)
	var l: Dictionary = bo["local"]
	var pf := BuildStats.power_factor(int(it["power"]))
	match b["category"]:
		"weapon":
			var w: Dictionary = Combat.weapon_data(b["id"])
			if w.is_empty():
				w = Combat.WEAPONS[int(b["weapon_index"])]
			var dmg := float(w["damage"]) * pf * (1.0 + float(l.get("dmg", 0.0)))
			var rpm := 60.0 / (float(w["interval"]) / (1.0 + float(l.get("rate", 0.0))))
			var mag := roundi(float(w["mag"]) * (1.0 + float(l.get("mag", 0.0))))
			var rel := float(w["reload"]) / (1.0 + float(l.get("reload", 0.0)))
			return [["Dégâts par tir", dmg, "%.1f" % dmg, true], ["Cadence", rpm, "%d /min" % roundi(rpm), true],
				["Chargeur", float(mag), "%d" % mag, true], ["Rechargement", rel, "%.2f s" % rel, false]]
		"ability":
			var cd := 8.0
			for a in Combat.ARSENAL:
				if a["id"] == b["arsenal"]:
					cd = float(a["cooldown"])
			var mult := pf * (1.0 + float(l.get("abil_dmg", 0.0)))
			var rc := cd / (1.0 + float(l.get("abil_cd", 0.0)))
			return [["Dégâts", mult * 100.0, "%d %%" % roundi(mult * 100.0), true], ["Recharge", rc, "%.1f s" % rc, false]]
		_:
			var out := []
			for k in b.get("implicit", {}):
				var v := float(b["implicit"][k]) * pf
				out.append([LootDB.stat_label(k), v, "+%d %%" % roundi(v * 100.0), true])
			return out


static func _row(parent: Control, left: String, right: String, lc: Color, rc: Color, size := 14) -> void:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := label(left, size, lc)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	var b := label(right, size, rc)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(b)
	parent.add_child(h)


## Fiche complète. `other` (optionnel) = objet équipé à comparer : écarts en vert / rouge.
## forge = true : habillage Anthem de la Forge (pas de cadre, dégradé, liseré de rareté, polices Barlow).
static func card(it: Dictionary, other := {}, width := 360.0, title := "", forge := false) -> PanelContainer:
	_forge = forge
	var r := int(it["rarity"])
	var rc := LootDB.rarity_color(r)
	var b := LootDB.base(it["base"])
	var p := PanelContainer.new()
	if forge:
		p.add_theme_stylebox_override("panel", AnthemUI.pad(20, 14, 20, 16))
		p.draw.connect(func():
			var rr := Rect2(Vector2.ZERO, p.size)
			AnthemUI.gradient(p, rr, Color(0.01, 0.025, 0.045, 0.78), Color(0.01, 0.025, 0.045, 0.3), 1)
			# reflet de la couleur de rareté en tête de fiche, puis liseré fin
			AnthemUI.gradient(p, Rect2(0, 0, p.size.x, minf(140.0, p.size.y)), Color(rc.r, rc.g, rc.b, 0.2), Color(rc.r, rc.g, rc.b, 0.0), -2)
			p.draw_rect(Rect2(0, 0, p.size.x, 2), rc)
			AnthemUI.brackets(p, rr, 12.0, Color(1, 1, 1, 0.5)))
	else:
		var sb := box(BG, rc, 2, 4)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 10
		sb.content_margin_bottom = 12
		sb.shadow_color = Color(rc.r, rc.g, rc.b, 0.25)
		sb.shadow_size = 10 if r >= 4 else 4
		p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(width, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5 if forge else 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	if title != "":
		v.add_child(label(title, 13 if forge else 11, AnthemUI.DIM if forge else MUTED, true))
	if not forge:
		var bar := ColorRect.new()
		bar.color = rc
		bar.custom_minimum_size = Vector2(0, 3)
		v.add_child(bar)
	_row(v, "%s %s" % [glyph(b["category"]), LootDB.rarity_name(r).to_upper()], b["family"].to_upper(), rc, MUTED, 13 if forge else 12)
	var mv := model_view(it)
	if mv:
		v.add_child(mv)
	var name_l := label(LootDB.item_name(it).to_upper() if forge else LootDB.item_name(it), 30 if forge else 22, rc if r >= 4 else Color.WHITE, true)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)
	var pw := "PUISSANCE %d" % int(it["power"])
	var pc := Color.WHITE
	if not other.is_empty() and other.get("uid", "") != it.get("uid", ""):
		var dp := int(it["power"]) - int(other["power"])
		pw += "   (%s%d)" % ["+" if dp >= 0 else "", dp]
		pc = GOOD if dp > 0 else (BAD if dp < 0 else Color.WHITE)
	v.add_child(label(pw, 15, pc, true))
	if b.has("role"):
		v.add_child(label(b["role"].to_upper(), 12, Color(1.0, 0.75, 0.4), true))
	# Stats principales
	var ks := key_stats(it)
	var ko := key_stats(other) if not other.is_empty() and LootDB.base(other["base"]).get("category") == b["category"] and other.get("uid", "") != it.get("uid", "") else []
	for i in ks.size():
		var txt: String = ks[i][2]
		var col := Color.WHITE
		if i < ko.size() and ko[i][0] == ks[i][0]:
			var dv: float = float(ks[i][1]) - float(ko[i][1])
			if absf(dv) > 0.001:
				var better: bool = (dv > 0.0) == bool(ks[i][3])
				col = GOOD if better else BAD
				txt += "  " + ("▲" if dv > 0.0 else "▼")
		_row(v, ks[i][0], txt, Color(0.82, 0.86, 0.92), col, 15 if forge else 14)
	# Inscriptions
	var ins: Array = it.get("ins", [])
	if not ins.is_empty():
		var sep := ColorRect.new()
		sep.color = Color(0.3, 0.45, 0.65, 0.4)
		sep.custom_minimum_size = Vector2(0, 1)
		v.add_child(sep)
		v.add_child(label("INSCRIPTIONS", 11, MUTED, true))
		for e in ins:
			var scope := LootDB.stat_scope(e["stat"])
			_row(v, LootDB.describe(e["stat"], float(e["value"])), "local" if scope == "local" else "global (exo)", Color(0.75, 0.88, 1.0), MUTED, 13)
	var ef := LootDB.effect(it.get("effect", ""))
	if not ef.is_empty():
		var boost: float = float(LootDB.rarity(r).get("effect_boost", 1.0))
		v.add_child(label("✦ " + ef["name"].to_upper() + ("  · renforcé" if boost > 1.0 else ""), 14, rc, true))
		var d := label(ef["desc"], 12, Color(0.9, 0.86, 0.78))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
		for k in ef["bonus"]:
			v.add_child(label("   " + LootDB.describe(k, float(ef["bonus"][k]) * boost), 12, rc.lightened(0.2)))
	# Avertissement façon Anthem : on perd une amorce ou un détonateur
	if not other.is_empty() and b.has("role") and LootDB.base(other["base"]).get("role", "") != b["role"] and other.get("uid", "") != it.get("uid", ""):
		var w := label("⚠ Tu remplaces un %s par un %s" % [LootDB.base(other["base"])["role"].to_lower(), b["role"].to_lower()], 12, Color(1.0, 0.7, 0.3))
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(w)
	if it.get("locked", false):
		v.add_child(label("VERROUILLÉ · pas de recyclage", 12, Color(1.0, 0.8, 0.4)))
	if it.get("mission", "") != "":
		v.add_child(label("Origine : " + it["mission"], 12 if forge else 11, MUTED))
	_forge = false
	return p
