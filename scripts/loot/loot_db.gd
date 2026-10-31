extends RefCounted
class_name LootDB
## Lecture des fichiers de données du butin (data/loot/*.json), une seule fois, en cache.
## items.json : raretés, emplacements, modèles d'objets ; affixes.json : inscriptions et effets ;
## tables.json : difficultés, missions, chances de drop, recyclage, niveaux pilote.

static var _cache := {}


static func _load(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var path := "res://data/loot/%s.json" % name
	var f := FileAccess.open(path, FileAccess.READ)
	var d: Dictionary = {}
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			d = parsed
	if d.is_empty():
		push_error("LootDB : impossible de lire " + path)
	_cache[name] = d
	return d


static func items() -> Dictionary:
	return _load("items")


static func affixes() -> Dictionary:
	return _load("affixes")


static func tables() -> Dictionary:
	return _load("tables")


static func rarity(r: int) -> Dictionary:
	var list: Array = items()["rarities"]
	return list[clampi(r, 0, list.size() - 1)]


static func rarity_color(r: int) -> Color:
	return Color(String(rarity(r)["color"]))


static func rarity_name(r: int) -> String:
	return rarity(r)["name"]


static func base(id: String) -> Dictionary:
	for b in items()["bases"]:
		if b["id"] == id:
			return b
	return {}


static func bases_of(category: String) -> Array:
	return items()["bases"].filter(func(b): return b["category"] == category)


static func slot(id: String) -> Dictionary:
	return items()["slots"].get(id, {})


static func stat_label(stat: String) -> String:
	return affixes()["stats"].get(stat, {}).get("label", stat)


static func stat_scope(stat: String) -> String:
	return affixes()["stats"].get(stat, {}).get("scope", "global")


static func effect(id: String) -> Dictionary:
	for e in affixes()["effects"]:
		if e["id"] == id:
			return e
	return {}


static func difficulty(id: String) -> Dictionary:
	for d in tables()["difficulties"]:
		if d["id"] == id:
			return d
	return tables()["difficulties"][1]


static func difficulty_index(id: String) -> int:
	var list: Array = tables()["difficulties"]
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return 1


static func material(id: String) -> Dictionary:
	for m in tables()["materials"]:
		if m["id"] == id:
			return m
	return { "id": id, "name": id, "color": "#ffffff" }


## Nom affiché d'un exemplaire : les chefs-d'œuvre et légendaires ont un nom propre.
static func item_name(it: Dictionary) -> String:
	var b := base(it.get("base", ""))
	if b.is_empty():
		return "Objet inconnu"
	var names: Dictionary = b.get("names", {})
	return names.get(str(int(it.get("rarity", 0))), b["name"])


static func item_category(it: Dictionary) -> String:
	return base(it.get("base", "")).get("category", "")


## Une inscription en texte : « +12 % Dégâts de l'arme ».
static func describe(stat: String, value: float) -> String:
	return "+%d %% %s" % [roundi(value * 100.0), stat_label(stat)]
