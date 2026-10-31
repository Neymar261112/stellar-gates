extends Node
## Loadout (autoload) : le GAMEPLAY du Solaris. Quatre composants à trois niveaux, les deux pouvoirs
## équipés, et 6 loadouts sauvegardés par mode. Niveau 0 = récup, 1 = Horizon (copie humaine), 2 = origine.
## RÈGLE (doc de conception du 27 octobre) : les composants ne changent JAMAIS la forme du Solaris.
## L'apparence (casque, torse, bras, jambes, peinture…) vit dans l'autoload Appearance et ne touche aucune stat.
## Étape 7 (butin) : ces quatre composants deviennent les SYSTÈMES du Solaris, débloqués par le niveau pilote
## (Progression). Le butin équipé (Inventory) ajoute ses bonus par BuildStats dans part(). Les loadouts
## sauvegardés retiennent aussi les objets équipés ("gear").

signal changed(slot: String)

const SLOTS := ["propulseurs", "jambes", "carapace", "noyau"]
const SLOT_NAMES := { "propulseurs": "Propulseurs", "jambes": "Servomoteurs", "carapace": "Blindage", "noyau": "Noyau" }
const LOADOUTS_PER_MODE := 6
const TIER_NAMES := ["Récup", "Horizon", "Origine"]

const PARTS := {
	"propulseurs": [
		{ "name": "Tuyère de récup", "desc": "Amortit les chutes, un petit bond, pas de vol.",
		  "fly": false, "fly_seconds": 0.0, "hover_seconds": 0.0, "fly_speed": 0.0, "boost": 1.0 },
		{ "name": "Propulseurs Horizon", "desc": "Copie humaine : vol court et bruyant, 5 s avant surchauffe.",
		  "fly": true, "fly_seconds": 5.0, "hover_seconds": 12.0, "fly_speed": 13.0, "boost": 1.3 },
		{ "name": "Ailes solaires", "desc": "Composant d'origine. Vol long et rapide, 14 s avant surchauffe.",
		  "fly": true, "fly_seconds": 14.0, "hover_seconds": 30.0, "fly_speed": 19.0, "boost": 1.6 },
	],
	"jambes": [
		{ "name": "Servos de Bastion", "desc": "Lourds et dépareillés. Marche lente, saut court, pas de dash.",
		  "dash": false, "walk_speed": 6.0, "jump_speed": 8.0, "dash_cooldown": 9.0, "melee_mult": 0.8 },
		{ "name": "Servos Horizon", "desc": "Copie humaine : marche normale, dash court.",
		  "dash": true, "walk_speed": 8.0, "jump_speed": 9.0, "dash_cooldown": 1.4, "melee_mult": 1.0 },
		{ "name": "Servos d'Originel", "desc": "Composant d'origine. Course rapide, dash enchaîné, mêlée renforcée.",
		  "dash": true, "walk_speed": 9.5, "jump_speed": 10.5, "dash_cooldown": 0.7, "melee_mult": 1.5 },
	],
	"carapace": [
		{ "name": "Blindage de récup", "desc": "Bouclier faible.",
		  "max_shield": 25.0, "max_health": 100.0, "shield_regen": 14.0 },
		{ "name": "Blindage Horizon", "desc": "Copie humaine : bouclier correct.",
		  "max_shield": 60.0, "max_health": 100.0, "shield_regen": 22.0 },
		{ "name": "Blindage ivoire", "desc": "Composant d'origine. Bouclier large, vie renforcée.",
		  "max_shield": 110.0, "max_health": 130.0, "shield_regen": 32.0 },
	],
	"noyau": [
		{ "name": "Noyau bridé", "desc": "Bridé par Horizon par sécurité. Grenade seulement (LB), pas d'ultime, recharges lentes.",
		  "power_slots": 1, "ultimate": false, "cooldown_mult": 1.3 },
		{ "name": "Noyau Horizon", "desc": "Copie humaine : grenade et lanceur (LB et RB), toujours pas d'ultime.",
		  "power_slots": 2, "ultimate": false, "cooldown_mult": 1.0 },
		{ "name": "Noyau de sternum", "desc": "Composant d'origine. Grenade, lanceur, batterie de missiles, recharges rapides.",
		  "power_slots": 2, "ultimate": true, "cooldown_mult": 0.75 },
	],
}

var mode := "ranger"
var tier := { "propulseurs": 0, "jambes": 0, "carapace": 0, "noyau": 0 }
var unlocked := { "propulseurs": 0, "jambes": 0, "carapace": 0, "noyau": 0 }   # meilleur niveau trouvé
var powers := [0, 3]               # index dans Combat.ARSENAL : grenade (LB) et lanceur d'assaut (RB)
var loadouts := {}                 # mode -> Array de 6 { name, tier, powers }
var active_loadout := 0


func part(slot: String) -> Dictionary:
	var bs := get_node_or_null("/root/BuildStats")
	if bs:
		return bs.apply_part(slot, PARTS[slot][tier[slot]])
	return PARTS[slot][tier[slot]]


func stat(slot: String, key: String):
	return part(slot)[key]


func _ready() -> void:
	_reset_loadouts()


func set_tier(slot: String, t: int) -> void:
	if not PARTS.has(slot):
		return
	t = clampi(t, 0, PARTS[slot].size() - 1)
	unlocked[slot] = maxi(unlocked[slot], t)
	if tier[slot] == t:
		return
	tier[slot] = t
	changed.emit(slot)


func reset_scrap() -> void:
	for s in SLOTS:
		unlocked[s] = 0
		set_tier(s, 0)


func set_all(t: int) -> void:
	for s in SLOTS:
		set_tier(s, t)


## Composant trouvé dans une caisse : débloqué et monté.
func unlock(slot: String, t: int) -> void:
	set_tier(slot, t)


func is_unlocked(slot: String, t: int) -> bool:
	return t <= unlocked[slot]


func set_power(slot: int, arsenal_index: int) -> void:
	powers[slot] = arsenal_index
	changed.emit("powers")


# ---------------------------------------------------------------- loadouts sauvegardés (6 par mode)
func _reset_loadouts() -> void:
	loadouts = { "ranger": [] }
	for i in LOADOUTS_PER_MODE:
		loadouts["ranger"].append({ "name": "Loadout %d" % (i + 1), "tier": tier.duplicate(), "powers": powers.duplicate(), "empty": true })
	loadouts["ranger"][0] = { "name": "Assaut", "tier": tier.duplicate(), "powers": [0, 3] }
	active_loadout = 0


func save_loadout(i: int) -> void:
	var name: String = loadouts[mode][i]["name"]
	loadouts[mode][i] = { "name": name, "tier": tier.duplicate(), "powers": powers.duplicate(), "gear": Inventory.equipped.duplicate() }
	active_loadout = i
	Progression.save()


## Charge un loadout ; un composant pas encore trouvé retombe sur le meilleur niveau débloqué.
func load_loadout(i: int) -> void:
	var l: Dictionary = loadouts[mode][i]
	active_loadout = i
	for s in SLOTS:
		set_tier(s, mini(int(l["tier"][s]), unlocked[s]))
	powers = Combat.sanitize_powers([int(l["powers"][0]), int(l["powers"][1])])
	if l.has("gear"):
		Inventory.restore(l["gear"])      # objets recyclés depuis : ignorés
	changed.emit("powers")


func complete() -> bool:
	for s in SLOTS:
		if tier[s] < PARTS[s].size() - 1:
			return false
	return true


func count_origin() -> int:
	var n := 0
	for s in SLOTS:
		if tier[s] == PARTS[s].size() - 1:
			n += 1
	return n


func summary_lines() -> Array:
	var out := []
	for s in SLOTS:
		out.append("%s : %s" % [SLOT_NAMES[s], part(s)["name"]])
	return out
