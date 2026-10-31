extends Node
## Test de la Forge : navigation à la manette simulée, l'apparence change, les stats non.
## Lancer : godot --headless --path . tests/forge_test.tscn
## Avec SHOTS=1 (et xvfb-run, --rendering-driver opengl3) : captures d'écran dans out/forge_*.png

var t := 0.0
var step := 0
var f: Node3D
var _stats0 := ""
var shots := OS.get_environment("SHOTS") != ""


func _ready() -> void:
	f = load("res://scenes/atelier.tscn").instantiate()
	add_child(f)


func _stats() -> String:
	var p: Dictionary = {}
	for s in Loadout.SLOTS:
		p[s] = Loadout.part(s)
	return JSON.stringify(p) + JSON.stringify(Loadout.powers)


func shot(name: String) -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://out"))
	img.save_png("res://out/forge_%s.png" % name)
	print("[forge] capture ", name)


func idx_of(key: String, id) -> int:
	var r: Dictionary = f._cur_row()
	assert(r["key"] == key, "ligne attendue %s, trouvée %s" % [key, r["key"]])
	for i in r["items"].size():
		if r["items"][i]["id"] == id:
			return i
	return -1


## Place le curseur juste avant la vignette voulue puis appuie sur « droite » (comme à la manette).
func pick(key: String, id) -> void:
	var i := idx_of(key, id)
	assert(i >= 0, "%s introuvable dans %s" % [str(id), key])
	f._cursor[key] = i - 1 if i > 0 else f._cur_row()["items"].size() - 1
	f._nav(Vector2i(1, 0))


func _process(delta: float) -> void:
	t += delta
	match step:
		0:
			if t > 1.2:
				_stats0 = _stats()
				assert(f.TABS[f.tab] == "APPARENCE" and f._cur_row()["key"] == "piece_helmet", "la Forge doit s'ouvrir sur Apparence > Casque")
				shot("1_apparence")
				step = 1
		1:
			if t > 1.6:
				f._nav(Vector2i(0, 1))
				pick("piece_chest", "ranger.mech.chest")
				assert(Appearance.piece("chest") == "ranger.mech.chest", "torse Mech non équipé")
				f.goto("APPARENCE", "packs")
				f._cursor["packs"] = idx_of("packs", "ranger.mech")
				f._accept()
				assert(Appearance.piece("helmet") == "ranger.mech.helmet", "ensemble Mech non monté")
				step = 2
		2:
			if t > 2.4:
				shot("2_ensemble")
				f.goto("APPARENCE", "zone")
				for i in 5:
					f._nav(Vector2i(1, 0))
				assert(f._zone == 5, "zone Énergie non choisie")
				f._nav(Vector2i(0, 1))
				var before: String = Appearance.current["color_slots"][5]
				f._nav(Vector2i(1, 0))
				assert(Appearance.current["color_slots"][5] != before, "couleur de la zone 6 inchangée")
				f._nav(Vector2i(0, 1))
				f._nav(Vector2i(1, 0))
				step = 3
		3:
			if t > 3.2:
				shot("3_peinture")
				f.goto("APPARENCE", "wear_amount")
				var w0: float = Appearance.wear_amount()
				for i in 4:
					f._nav(Vector2i(-1, 0))
				assert(absf(Appearance.wear_amount() - maxf(0.0, w0 - 0.2)) < 0.01, "curseur d'usure : %f" % Appearance.wear_amount())
				f._nav(Vector2i(0, 1))
				pick("wear", "worn")
				assert(Appearance.current["wear_state"] == "worn", "usure non appliquée")
				f.goto("APPARENCE", "vinyl")
				pick("vinyl", "glyphes")
				assert(Appearance.current["vinyl_id"] == "glyphes")
				step = 4
		4:
			if t > 4.0:
				shot("4_usure_vinyle")
				f.goto("MODES", "anim_animation_victory")
				var v0: String = Appearance.current["animation_victory"]
				f._nav(Vector2i(1, 0))
				assert(Appearance.current["animation_victory"] != v0, "animation de victoire inchangée")
				step = 5
		5:
			if t > 5.0:
				shot("5_animations")
				f.goto("PRÉRÉGLAGES", "presets_1")
				f._cursor["presets_1"] = idx_of("presets_1", 5)
				f._x()
				assert(Appearance.active["ranger"] == 5 and not Appearance.presets["ranger"][5].has("empty"), "preset 6 non enregistré")
				f.goto("PRÉRÉGLAGES", "presets_0")
				f._cursor["presets_0"] = idx_of("presets_0", 2)
				f._accept()
				assert(Appearance.preset_name() == "Épave" and Appearance.piece("helmet") == "ranger.default.helmet", "preset Épave non porté")
				step = 6
		6:
			if t > 6.0:
				shot("6_presets")
				assert(_stats() == _stats0, "la Forge (apparence) a changé une stat !")
				f.goto("SYSTÈMES", "comp_propulseurs")
				f._nav(Vector2i(-1, 0))
				assert(_stats() != _stats0, "l'onglet Équipement doit changer le gameplay")
				step = 7
		7:
			if t > 6.8:
				shot("7_equipement")
				f.goto("MODES", "modes")
				f._cursor["modes"] = 1
				f._accept()
				assert(Appearance.mode == "ranger", "un mode verrouillé ne doit pas s'activer")
				step = 8
		8:
			if t > 7.6:
				shot("8_modes")
				print("[forge] OK")
				get_tree().quit()
