extends Node
## Apparence (autoload « Appearance ») : le look actif du Solaris et les presets sauvegardés.
## RÈGLE : rien ici ne touche une stat. Les capacités viennent uniquement de Loadout (gameplay).
## Sauvegarde dans user://apparence.json (presets, look actif, pièces débloquées).

signal changed(what: String)       # "pieces", "paint", "wear", "vinyl", "anim", "all"

const PRESETS_PER_MODE := 10
const SAVE_PATH := "user://apparence.json"
## Pièces Meshy à l'essai : débloquées d'office pour que cyril les voie tout de suite.
const TEST_PIECES := ["ranger.exo.arms", "ranger.mech.helmet", "ranger.mech.chest", "ranger.mech.arms", "ranger.mech.legs",
	"ranger.sentinelle_braise.chest", "ranger.sentinelle_braise2.chest", "ranger.avantgarde_braise.chest", "ranger.sentinelle_orange.chest",
	"ranger.titan_orange.chest", "ranger.avantgarde_titan.chest", "ranger.plastron_titan.chest",
	"ranger.gantelet_tigre.arms", "ranger.griffe_braise.arms",
	"ranger.casque_aegis.helmet", "ranger.casque_guepe.helmet", "ranger.casque_minuit.helmet", "ranger.casque_neon.helmet",
	"ranger.masque_orange.helmet", "ranger.casque_vide.helmet", "ranger.casque_braise.helmet",
	"ranger.bras_precision.arms", "ranger.bras_limier.arms", "ranger.bras_cyber.arms", "ranger.bras_cyber2.arms",
	"ranger.bras_prothese.arms", "ranger.bras_allonge.arms", "ranger.bras_serre.arms", "ranger.bras_exocoque.arms",
	"ranger.bras_mech_braise.arms", "ranger.bras_cobra.arms", "ranger.bras_servo.arms", "ranger.pince_titan.arms"]

var mode := "ranger"
var presets := {}                  # mode -> Array de 10 presets
var active := {}                   # mode -> index du preset chargé
var current := {}                  # le look porté (copie de travail, modifiée dans la Forge)
var unlocked_pieces := []
var unlocked_vinyls := ["none", "horizon", "chevrons", "flottilles", "danger"]
var unlocked_materials := []
var share_paint := true            # même peinture d'un mode à l'autre (décision Q2)
var persist := true                # coupé par les tests et par l'Atelier lancé seul
var return_to := ""                # scène où revenir en sortant de l'Atelier
var came_from_atelier := false     # la Terre replace alors le Solaris au pied de la rampe


var _seen_mech := false


func _ready() -> void:
	reset()
	if persist:
		_load()
		if not _seen_mech:
			_wear_test_preset()


## Première fois avec le corps Aegis : les presets de départ sont remis à neuf (les anciens portaient
## des pièces en formes simples, retirées) et on porte l'Aegis tel que cyril l'a dessiné.
func _wear_test_preset() -> void:
	presets["ranger"] = Catalog.starter_presets()
	for i in range(presets["ranger"].size(), PRESETS_PER_MODE):
		presets["ranger"].append(Catalog.empty_preset(i + 1))
	load_preset(0)


func reset() -> void:
	mode = "ranger"
	presets = { "ranger": [] }
	var starters := Catalog.starter_presets()
	for i in PRESETS_PER_MODE:
		presets["ranger"].append(starters[i] if i < starters.size() else Catalog.empty_preset(i + 1))
	active = { "ranger": 0 }
	current = presets["ranger"][0].duplicate(true)
	unlocked_pieces = []
	for pack in ["ranger.default", "ranger.recup"]:
		for s in Catalog.SLOTS:
			unlocked_pieces.append(pack + "." + s)
	unlocked_pieces.append_array(TEST_PIECES)
	unlocked_vinyls = ["none", "horizon", "chevrons", "flottilles", "danger"]
	unlocked_materials = []
	for m in Catalog.MATERIALS:
		if m["id"] != "chrome" and m["id"] != "anodized":
			unlocked_materials.append(m["id"])
	changed.emit("all")


# ---------------------------------------------------------------- lecture
func piece(slot: String) -> String:
	var id: String = current.get(slot + "_piece_id", "ranger.default." + slot)
	return id if is_unlocked(id) else "ranger.default." + slot


func color(zone: int) -> Color:
	return Catalog.look_color(current, zone)


func material(zone: int) -> Dictionary:
	return Catalog.look_material(current, zone)


func wear() -> Dictionary:
	return Catalog.look_wear(current)


func wear_amount() -> float:
	return float(current.get("wear_amount", 1.0))


func is_unlocked(piece_id: String) -> bool:
	return piece_id in unlocked_pieces


func preset_name() -> String:
	return presets[mode][active[mode]]["name"]


## Le look porté diffère-t-il du preset chargé ? (point « non sauvegardé » de la Forge)
func dirty() -> bool:
	var p: Dictionary = presets[mode][active[mode]].duplicate(true)
	p.erase("empty")
	var c := current.duplicate(true)
	c.erase("empty")
	return JSON.stringify(p) != JSON.stringify(c)


# ---------------------------------------------------------------- modifications (Forge)
func set_piece(slot: String, piece_id: String) -> void:
	if not is_unlocked(piece_id):
		return
	current[slot + "_piece_id"] = piece_id
	changed.emit("pieces")


func set_pack(pack_id: String) -> void:
	for s in Catalog.SLOTS:
		if is_unlocked(pack_id + "." + s):
			current[s + "_piece_id"] = pack_id + "." + s
	changed.emit("pieces")


func set_color(zone: int, hex: String) -> void:
	current["color_slots"][zone] = hex
	changed.emit("paint")


func set_material(zone: int, id: String) -> void:
	current["material_slots"][zone] = id
	changed.emit("paint")


func set_wear(id: String) -> void:
	current["wear_state"] = id
	changed.emit("wear")


## Curseur d'usure : 0 = neuf, 1 = le type d'usure à fond.
func set_wear_amount(v: float) -> void:
	current["wear_amount"] = snappedf(clampf(v, 0.0, 1.0), 0.05)
	changed.emit("wear")


func set_vinyl(id: String) -> void:
	current["vinyl_id"] = id
	var v := Catalog.find(Catalog.VINYLS, id)
	if v.has("place"):
		current["vinyl_place"] = v["place"]
	changed.emit("vinyl")


func set_vinyl_place(place: String) -> void:
	current["vinyl_place"] = place
	changed.emit("vinyl")


## kind : "animation_arrival", "animation_victory", "emote0", "emote1", "emote2"
func set_anim(kind: String, id: String) -> void:
	if kind.begins_with("emote"):
		current["emotes"][int(kind.substr(5))] = id
	else:
		current[kind] = id
	changed.emit("anim")


func set_current(look: Dictionary) -> void:
	current = look.duplicate(true)
	changed.emit("all")


func load_preset(i: int) -> void:
	active[mode] = i
	current = presets[mode][i].duplicate(true)
	current.erase("empty")
	changed.emit("all")
	save()


func save_preset(i: int, new_name := "") -> void:
	var p := current.duplicate(true)
	p.erase("empty")
	if new_name != "":
		p["name"] = new_name
	elif presets[mode][i].get("empty", false):
		p["name"] = "Mon look %d" % (i + 1)
	else:
		p["name"] = presets[mode][i]["name"]
	presets[mode][i] = p
	active[mode] = i
	current = p.duplicate(true)
	changed.emit("all")
	save()


# ---------------------------------------------------------------- déblocages
func unlock_piece(piece_id: String) -> bool:
	if piece_id in unlocked_pieces:
		return false
	unlocked_pieces.append(piece_id)
	save()
	return true


func unlock_pack(pack_id: String) -> void:
	for s in Catalog.SLOTS:
		if Catalog.has_piece(pack_id + "." + s):
			unlock_piece(pack_id + "." + s)


func unlock_all() -> void:
	for p in Catalog.RANGER_PACKS:
		unlock_pack(p["id"])
	for v in Catalog.VINYLS:
		if not v["id"] in unlocked_vinyls:
			unlocked_vinyls.append(v["id"])
	for m in Catalog.MATERIALS:
		if not m["id"] in unlocked_materials:
			unlocked_materials.append(m["id"])
	save()


## Une caisse de pièce trouvée en mission : elle donne le composant de gameplay (Loadout)
## ET la pièce d'apparence du même pack, qu'on choisit ensuite librement à l'Atelier.
## propulseurs → torse (dos), carapace → bras (épaulières), jambes → jambes, noyau → casque.
const COMPONENT_TO_SLOT := { "propulseurs": "chest", "carapace": "arms", "jambes": "legs", "noyau": "helmet" }

func unlock_from_crate(component: String, tier: int) -> String:
	if component == "finition":
		if tier == 1 and not "glyphes" in unlocked_vinyls:
			unlocked_vinyls.append("glyphes")
			save()
			return "Vinyle « Anneau de glyphes » disponible à l'Atelier"
		if tier == 2:
			for m in ["chrome", "anodized"]:
				if not m in unlocked_materials:
					unlocked_materials.append(m)
			save()
			return "Matériaux Chrome et Anodisé disponibles à l'Atelier"
		return ""
	if not COMPONENT_TO_SLOT.has(component) or tier < 1:
		return ""
	var pack: String = "ranger.horizon" if tier == 1 else "ranger.originel"
	var slot: String = COMPONENT_TO_SLOT[component]
	if unlock_piece(pack + "." + slot):
		return "Apparence « %s : %s » disponible à l'Atelier" % [Catalog.SLOT_NAMES[slot], Catalog.pack_name(pack)]
	return ""


# ---------------------------------------------------------------- sauvegarde
func save() -> void:
	if not persist:
		return
	var data := {
		"version": 1, "mode": mode, "presets": presets, "active": active, "current": current,
		"unlocked_pieces": unlocked_pieces, "unlocked_vinyls": unlocked_vinyls,
		"unlocked_materials": unlocked_materials, "share_paint": share_paint, "seen": ["mech", "mech_v3", "aegis_v1"],
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text()) if f else null
	if not data is Dictionary or int(data.get("version", 0)) != 1:
		return
	presets = data["presets"]
	active = {}
	for k in data["active"]:
		active[k] = int(data["active"][k])
	current = data["current"]
	unlocked_pieces = data["unlocked_pieces"]
	unlocked_vinyls = data["unlocked_vinyls"]
	unlocked_materials = data["unlocked_materials"]
	share_paint = data.get("share_paint", true)
	# ancienne sauvegarde : on ajoute les pièces d'essai et les presets de départ apparus depuis
	for id in TEST_PIECES:
		if not id in unlocked_pieces:
			unlocked_pieces.append(id)
	var names := []
	for p in presets["ranger"]:
		names.append(p["name"])
	for st in Catalog.starter_presets():
		if not st["name"] in names:
			for i in presets["ranger"].size():
				if presets["ranger"][i].get("empty", false):
					presets["ranger"][i] = st
					names.append(st["name"])
					break
	_seen_mech = data.get("seen", []).has("aegis_v1")
	changed.emit("all")
