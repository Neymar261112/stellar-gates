extends RefCounted
class_name LootRoll
## Tirage d'un exemplaire (LootItem) à partir des tables JSON : rareté, modèle, puissance, inscriptions, effet.
## Le générateur est passé en paramètre : avec une graine fixe, les tests retombent toujours sur les mêmes objets.
##
## opts : difficulty (id), category ("weapon" / "ability" / "component", sinon tiré au sort),
##        favors (catégorie privilégiée par la mission), min_rarity, rarity (imposée), rarity_bonus,
##        mission (texte d'origine), mode (par défaut "ranger").


static func roll(rng: RandomNumberGenerator, opts := {}) -> Dictionary:
	var diff := LootDB.difficulty(opts.get("difficulty", "normal"))
	var r: int = int(opts["rarity"]) if opts.has("rarity") else roll_rarity(rng, diff, int(opts.get("min_rarity", 0)), int(opts.get("rarity_bonus", 0)))
	var cat: String = opts.get("category", "")
	if cat == "":
		cat = roll_category(rng, opts.get("favors", ""))
	var mode: String = opts.get("mode", "ranger")
	var bases := LootDB.bases_of(cat).filter(func(b): return b["modes"].is_empty() or mode in b["modes"])
	if opts.has("base"):
		bases = [LootDB.base(opts["base"])]
	var b: Dictionary = bases[rng.randi() % bases.size()]
	return make(rng, b["id"], r, int(diff["power"]), opts.get("mission", ""))


## Fabrique un exemplaire d'un modèle donné à une rareté donnée (butin, caisses, démo).
static func make(rng: RandomNumberGenerator, base_id: String, r: int, power_bonus := 1, mission := "") -> Dictionary:
	var rar := LootDB.rarity(r)
	var cat: String = LootDB.base(base_id)["category"]
	var it := {
		"uid": "", "base": base_id, "rarity": r,
		"power": int(rar["power"]) + power_bonus + rng.randi_range(0, 2),
		"ins": roll_inscriptions(rng, cat, r, int(rar["inscriptions"])),
		"effect": "", "mission": mission, "date": Time.get_datetime_string_from_system(false, true),
		"seen": false, "locked": false,
	}
	if bool(rar["effect"]):
		var effects: Array = LootDB.affixes()["effects"].filter(func(e): return cat in e["categories"])
		if not effects.is_empty():
			it["effect"] = effects[rng.randi() % effects.size()]["id"]
	return it


static func roll_rarity(rng: RandomNumberGenerator, diff: Dictionary, min_r := 0, bonus := 0) -> int:
	var w: Array = diff["weights"].duplicate()
	var total := 0.0
	for i in w.size():
		if i < min_r:
			w[i] = 0.0
		total += float(w[i])
	if total <= 0.0:
		return clampi(min_r, 0, 5)
	var x := rng.randf() * total
	var r := 0
	for i in w.size():
		x -= float(w[i])
		if x <= 0.0:
			r = i
			break
	# Ennemi d'élite : une chance sur deux de monter d'un cran
	for k in bonus:
		if rng.randf() < 0.5:
			r += 1
	return clampi(r, min_r, 5)


static func roll_category(rng: RandomNumberGenerator, favors := "") -> String:
	var t := LootDB.tables()
	if favors != "" and rng.randf() < float(t["favored_share"]):
		return favors
	var cw: Dictionary = t["category_weights"]
	var total := 0.0
	for k in cw:
		total += float(cw[k])
	var x := rng.randf() * total
	for k in cw:
		x -= float(cw[k])
		if x <= 0.0:
			return k
	return "weapon"


## Inscriptions distinctes, tirées parmi celles permises pour la catégorie.
static func roll_inscriptions(rng: RandomNumberGenerator, cat: String, r: int, count: int) -> Array:
	var a := LootDB.affixes()
	var pool: Array = a["rules"].filter(func(rule): return cat in rule["categories"])
	var scale: float = float(a["rarity_scale"][r])
	var out := []
	for i in mini(count, pool.size()):
		var k := rng.randi() % pool.size()
		var rule: Dictionary = pool[k]
		pool.remove_at(k)
		var v := rng.randf_range(float(rule["min"]), float(rule["max"])) * scale
		out.append({ "stat": rule["stat"], "value": snappedf(v, 0.01) })
	return out
