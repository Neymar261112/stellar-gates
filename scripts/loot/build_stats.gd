extends Node
## BuildStats (autoload) : le SEUL calcul des stats d'équipement. Il lit Inventory (objets équipés) et
## ne lit JAMAIS l'apparence. Utilisé par :
##  - combat.gd : current() -> weapon(), damage_mult() -> ability_mult() ;
##  - loadout.gd : part() ajoute les bonus globaux (bouclier, vie, régénération, mêlée, recharge, vol).
## Puissance d'un objet : +2,5 % de base par point au-dessus de 10. Inscriptions locales = l'objet seul,
## globales = tout l'exo. Effet spécial (chef-d'œuvre, légendaire ×1,5) = paquet de bonus nommé.

signal updated

var totals := {}                  # bonus globaux additionnés (fractions)
var _local := {}                  # emplacement -> bonus locaux de l'objet (fractions)
var _power := {}                  # emplacement -> puissance de l'objet


func _ready() -> void:
	Inventory.changed.connect(recompute)
	# Un système du Solaris qui change (niveau pilote, tests) peut ouvrir l'emplacement du lanceur
	Loadout.changed.connect(func(s: String): if s != "gear" and s != "powers": recompute())
	recompute()


static func power_factor(power: int) -> float:
	return 1.0 + (power - 10) * 0.025


## Bonus d'un exemplaire : { "local": {stat: v}, "global": {stat: v} }.
static func item_bonuses(it: Dictionary) -> Dictionary:
	var out := { "local": {}, "global": {} }
	if it.is_empty():
		return out
	var b := LootDB.base(it["base"])
	var pf := power_factor(int(it["power"]))
	for k in b.get("implicit", {}):
		_add(out["global"], k, float(b["implicit"][k]) * pf)
	for ins in it.get("ins", []):
		_add(out[LootDB.stat_scope(ins["stat"])], ins["stat"], float(ins["value"]))
	var e := LootDB.effect(it.get("effect", ""))
	if not e.is_empty():
		var boost: float = float(LootDB.rarity(int(it["rarity"])).get("effect_boost", 1.0))
		for k in e["bonus"]:
			_add(out[LootDB.stat_scope(k)], k, float(e["bonus"][k]) * boost)
	return out


static func _add(d: Dictionary, k: String, v: float) -> void:
	d[k] = float(d.get(k, 0.0)) + v


func recompute() -> void:
	totals = {}
	_local = {}
	_power = {}
	for s in Inventory.ALL_SLOTS:
		var it := Inventory.equipped_item(s)
		if it.is_empty() or not Inventory.slot_open(s):
			continue
		var bo := item_bonuses(it)
		_local[s] = bo["local"]
		_power[s] = int(it["power"])
		for k in bo["global"]:
			_add(totals, k, bo["global"][k])
	updated.emit()
	if Loadout.has_signal("changed"):
		Loadout.changed.emit("gear")      # le joueur réapplique bouclier, vie, vol…


func total(stat: String) -> float:
	return float(totals.get(stat, 0.0))


# ---------------------------------------------------------------- branchements du combat
## Copie des stats d'une arme du combat (Combat.weapon_def(i) : modèle de l'objet équipé) avec ses bonus.
func weapon(i: int, base: Dictionary) -> Dictionary:
	var slot: String = "weapon%d" % i
	var d := base.duplicate()
	if not _power.has(slot):
		return d
	var l: Dictionary = _local[slot]
	d["damage"] = float(base["damage"]) * power_factor(_power[slot]) * (1.0 + float(l.get("dmg", 0.0)) + total("g_weapon"))
	d["interval"] = float(base["interval"]) / (1.0 + float(l.get("rate", 0.0)))
	d["mag"] = maxi(1, roundi(float(base["mag"]) * (1.0 + float(l.get("mag", 0.0)))))
	d["reload"] = float(base["reload"]) / (1.0 + float(l.get("reload", 0.0)))
	return d


## Multiplicateur des dégâts des capacités, des combos et de l'ultime : bonus global × moyenne des deux capacités.
func ability_mult() -> float:
	var n := 0
	var sum := 0.0
	for s in Inventory.ABILITY_SLOTS:
		if _power.has(s):
			sum += power_factor(_power[s]) * (1.0 + float(_local[s].get("abil_dmg", 0.0)))
			n += 1
	var avg := sum / n if n > 0 else 1.0
	return avg * (1.0 + total("g_ability"))


## Facteur des temps de recharge (< 1 = plus rapide).
func cooldown_factor() -> float:
	var loc := 0.0
	var n := 0
	for s in Inventory.ABILITY_SLOTS:
		if _local.has(s):
			loc += float(_local[s].get("abil_cd", 0.0))
			n += 1
	if n > 0:
		loc /= n
	return 1.0 / (1.0 + total("cooldown") + loc)


## Bonus globaux sur les systèmes du Solaris (copie du dict de Loadout.PARTS).
func apply_part(slot: String, p: Dictionary) -> Dictionary:
	var d := p.duplicate()
	match slot:
		"carapace":
			d["max_shield"] = float(p["max_shield"]) * (1.0 + total("shield"))
			d["max_health"] = float(p["max_health"]) * (1.0 + total("health"))
			d["shield_regen"] = float(p["shield_regen"]) * (1.0 + total("regen"))
		"jambes":
			d["melee_mult"] = float(p["melee_mult"]) * (1.0 + total("melee"))
		"propulseurs":
			d["fly_seconds"] = float(p["fly_seconds"]) * (1.0 + total("fly"))
		"noyau":
			d["cooldown_mult"] = float(p["cooldown_mult"]) * cooldown_factor()
	return d


# ---------------------------------------------------------------- puissance de l'exo
## Puissance de l'exo = moyenne des objets équipés (armes, capacités, composants ouverts).
func exo_power() -> int:
	var sum := 0
	var n := 0
	for s in Inventory.ALL_SLOTS:
		if s in Inventory.COMP_SLOTS and not Inventory.slot_open(s):
			continue
		if s == "launcher" and not Inventory.slot_open(s):
			continue
		sum += int(_power.get(s, 0))
		n += 1
	return roundi(float(sum) / n) if n > 0 else 0


## Puissance de l'exo si l'on mettait `it` dans `slot` (pour la comparaison).
func exo_power_with(slot: String, it: Dictionary) -> int:
	var keep = _power.get(slot)
	_power[slot] = int(it["power"])
	var p := exo_power()
	if keep == null:
		_power.erase(slot)
	else:
		_power[slot] = keep
	return p
