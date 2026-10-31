extends Node
## Inventory (autoload) : les exemplaires possédés, les matériaux, et ce qui est équipé dans chaque emplacement.
## Sauvegardé avec la progression (user://progression.json, voir progression.gd).
## Règles : un objet par emplacement ; un objet d'un autre mode ne s'équipe pas ; un composant ne peut pas
## être monté deux fois ; un objet équipé ou verrouillé ne se recycle pas.

signal changed

const WEAPON_SLOTS := ["weapon0", "weapon1"]
const ABILITY_SLOTS := ["grenade", "launcher"]
const COMP_SLOTS := ["comp0", "comp1", "comp2", "comp3", "comp4", "comp5"]
const ALL_SLOTS := ["weapon0", "weapon1", "grenade", "launcher", "comp0", "comp1", "comp2", "comp3", "comp4", "comp5"]

var items: Array = []              # exemplaires (Dictionary, voir LootRoll.make)
var materials := {}                # id -> quantité
var equipped := {}                 # emplacement -> uid ("" = vide)
var next_uid := 1
var mode := "ranger"


func _ready() -> void:
	clear()


func clear() -> void:
	items = []
	materials = { "alliage": 0, "cristal": 0, "fragments": 0, "eclats": 0 }
	equipped = {}
	for s in ALL_SLOTS:
		equipped[s] = ""
	next_uid = 1


func to_dict() -> Dictionary:
	return { "items": items, "materials": materials, "equipped": equipped, "next_uid": next_uid }


func from_dict(d: Dictionary) -> void:
	clear()
	for it in d.get("items", []):
		if it is Dictionary and not LootDB.base(it.get("base", "")).is_empty():
			it["rarity"] = int(it["rarity"])
			it["power"] = int(it["power"])
			items.append(it)
	for k in d.get("materials", {}):
		materials[k] = int(d["materials"][k])
	for s in ALL_SLOTS:
		var u: String = d.get("equipped", {}).get(s, "")
		equipped[s] = u if get_item(u).size() > 0 else ""
	next_uid = maxi(int(d.get("next_uid", 1)), items.size() + 1)
	_sync_powers()
	changed.emit()


# ---------------------------------------------------------------- objets
func add(it: Dictionary) -> Dictionary:
	it["uid"] = "o%05d" % next_uid
	next_uid += 1
	items.append(it)
	changed.emit()
	return it


func get_item(uid: String) -> Dictionary:
	if uid == "":
		return {}
	for it in items:
		if it["uid"] == uid:
			return it
	return {}


func equipped_item(slot: String) -> Dictionary:
	return get_item(equipped.get(slot, ""))


func slot_of(uid: String) -> String:
	for s in equipped:
		if equipped[s] == uid and uid != "":
			return s
	return ""


func is_equipped(uid: String) -> bool:
	return slot_of(uid) != ""


func unseen_count() -> int:
	return items.filter(func(it): return not it.get("seen", false)).size()


func mark_seen(uid: String) -> void:
	var it := get_item(uid)
	if not it.is_empty() and not it.get("seen", false):
		it["seen"] = true


func toggle_lock(uid: String) -> bool:
	var it := get_item(uid)
	if it.is_empty():
		return false
	it["locked"] = not it.get("locked", false)
	if it["locked"]:
		it["junk"] = false
	changed.emit()
	return it["locked"]


## Marque (ou démarque) un objet « à recycler » depuis le menu du jeu ; le recyclage se fait à la Forge.
## Refusé pour un objet verrouillé.
func toggle_junk(uid: String) -> bool:
	var it := get_item(uid)
	if it.is_empty() or it.get("locked", false):
		return false
	it["junk"] = not it.get("junk", false)
	changed.emit()
	return it["junk"]


func junk_count() -> int:
	return items.filter(func(it): return it.get("junk", false)).size()


# ---------------------------------------------------------------- emplacements
## Nombre d'emplacements de composant ouverts (dépend du niveau pilote).
func comp_slots_open() -> int:
	var p := get_node_or_null("/root/Progression")
	return p.comp_slots() if p else 6


func slot_open(slot: String) -> bool:
	if slot in COMP_SLOTS:
		return COMP_SLOTS.find(slot) < comp_slots_open()
	if slot == "launcher":
		return int(Loadout.stat("noyau", "power_slots")) > 1
	return true


func fits(slot: String, it: Dictionary) -> bool:
	if it.is_empty():
		return false
	var b := LootDB.base(it["base"])
	var sd := LootDB.slot(slot)
	if b.is_empty() or sd.is_empty() or b["category"] != sd["category"]:
		return false
	if not b["modes"].is_empty() and not mode in b["modes"]:
		return false
	if sd.has("accepts") and not b["id"] in sd["accepts"]:
		return false
	if sd.has("ability_slot") and int(b["ability_slot"]) != int(sd["ability_slot"]):
		return false
	return true


## Objets compatibles avec un emplacement, du plus puissant au plus faible.
func compatible(slot: String) -> Array:
	var out := items.filter(func(it): return fits(slot, it))
	out.sort_custom(func(a, b): return a["power"] > b["power"] or (a["power"] == b["power"] and a["rarity"] > b["rarity"]))
	return out


func equip(slot: String, uid: String) -> bool:
	var it := get_item(uid)
	if not fits(slot, it):
		return false
	if not slot_open(slot):
		return false
	# Un composant déjà monté ailleurs change de place
	var was := slot_of(uid)
	if was != "" and was != slot:
		equipped[was] = equipped[slot] if slot in COMP_SLOTS and was in COMP_SLOTS else ""
	equipped[slot] = uid
	it["seen"] = true
	_sync_powers()
	changed.emit()
	return true


func unequip(slot: String) -> void:
	if slot in WEAPON_SLOTS or slot in ABILITY_SLOTS:
		return                       # armes et capacités : toujours quelque chose en main
	equipped[slot] = ""
	changed.emit()


## Recharge un jeu d'emplacements sauvegardé (loadout) ; les objets disparus (recyclés) sont ignorés.
func restore(gear: Dictionary) -> void:
	for s in ALL_SLOTS:
		var u: String = gear.get(s, "")
		if u == "" and (s in WEAPON_SLOTS or s in ABILITY_SLOTS):
			continue
		if u == "" or fits(s, get_item(u)):
			equipped[s] = u
	_sync_powers()
	changed.emit()


## Les capacités équipées pilotent les pouvoirs du combat (index dans Combat.ARSENAL).
func _sync_powers() -> void:
	for i in 2:
		var it := equipped_item(ABILITY_SLOTS[i])
		if it.is_empty():
			continue
		var ar: String = LootDB.base(it["base"]).get("arsenal", "")
		for a in Combat.ARSENAL.size():
			if Combat.ARSENAL[a]["id"] == ar and Loadout.powers[i] != a:
				Loadout.set_power(i, a)


# ---------------------------------------------------------------- recyclage
func salvage_value(it: Dictionary) -> Dictionary:
	return LootDB.tables()["salvage"][clampi(int(it["rarity"]), 0, 5)]


func can_salvage(it: Dictionary) -> bool:
	return not it.is_empty() and not it.get("locked", false) and not is_equipped(it["uid"])


## Recycle un objet ; renvoie les matériaux gagnés (vide si refusé).
func salvage(uid: String) -> Dictionary:
	var it := get_item(uid)
	if not can_salvage(it):
		return {}
	var gain := salvage_value(it)
	for k in gain:
		materials[k] = int(materials.get(k, 0)) + int(gain[k])
	items.erase(it)
	_count_salvaged(1)
	changed.emit()
	return gain


## Recycle tout ce qui est au plus de la rareté donnée (ni équipé, ni verrouillé).
func salvage_up_to(max_rarity: int) -> Dictionary:
	return _salvage_where(func(it): return int(it["rarity"]) <= max_rarity)


## Recycle les objets marqués « à recycler » dans le menu du jeu (ni équipés, ni verrouillés).
func salvage_marked() -> Dictionary:
	return _salvage_where(func(it): return it.get("junk", false))


func _count_salvaged(n: int) -> void:
	var p := get_node_or_null("/root/Progression")
	if p:
		p.count("salvaged", n)


func _salvage_where(pick: Callable) -> Dictionary:
	var total := {}
	var n := 0
	for it in items.duplicate():
		if pick.call(it) and can_salvage(it):
			for k in salvage_value(it):
				total[k] = int(total.get(k, 0)) + int(salvage_value(it)[k])
			for k in salvage_value(it):
				materials[k] = int(materials.get(k, 0)) + int(salvage_value(it)[k])
			items.erase(it)
			n += 1
	total["_count"] = n
	if n > 0:
		_count_salvaged(n)
		changed.emit()
	return total


# ---------------------------------------------------------------- départ et démo
## Équipement de départ (nouvelle partie) : du commun partout.
func starter_kit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2189
	var kit := { "weapon0": "avantgarde", "weapon1": "vipers", "grenade": "frag", "launcher": "missile", "comp0": "plastron", "comp1": "coeur" }
	for s in kit:
		var it := add(LootRoll.make(rng, kit[s], 0, 0, "Équipement de départ"))
		it["seen"] = true
		equipped[s] = it["uid"]
	_sync_powers()
	changed.emit()


## Arsenal de démonstration (Forge lancée seule avec F6, vidéos) : de tout, de toutes les raretés.
func demo(seed := 7) -> void:
	clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	starter_kit()
	for b in LootDB.items()["bases"]:
		for k in 2:
			var r := clampi(rng.randi_range(1, 4) + (1 if k == 1 and rng.randf() < 0.3 else 0), 1, 5)
			var it := add(LootRoll.make(rng, b["id"], r, rng.randi_range(0, 6), "Démonstration"))
			it["seen"] = rng.randf() < 0.6
	materials = { "alliage": 42, "cristal": 15, "fragments": 6, "eclats": 1 }
	changed.emit()
