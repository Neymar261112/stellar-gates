extends Node
## Progression (autoload) : niveau pilote (1 à 30) et XP, difficulté choisie, garantie de légendaire,
## missions terminées. Sauvegarde UNIQUE user://progression.json qui contient aussi l'inventaire.
## Les niveaux 1 à 10 servent de grand tutoriel : chaque niveau débloque un système du Solaris
## (vol, esquive, lanceur, blindage…) ou un emplacement de composant (data/loot/tables.json, "pilot").

signal changed
signal leveled_up(level: int, text: String)
signal challenge_done(def: Dictionary)

const SAVE := "user://progression.json"

var level := 1
var xp := 0                        # XP dans le niveau en cours
var difficulty := "normal"
var pity := 0                      # missions d'affilée sans légendaire
var missions_done := 0
var persist := true                # false : tests et Forge lancée seule (rien n'est écrit)
var stats := {}                    # compteurs des défis : kills, crates, missions, salvaged, masterworks, legendaries
var challenges_done: Array = []    # ids des défis réussis (récompense déjà versée)


func _ready() -> void:
	changed.connect(func(): BuildStats.recompute())
	if not load_game():
		new_game()
	apply_systems.call_deferred(false)


func new_game() -> void:
	level = 1
	xp = 0
	difficulty = "normal"
	pity = 0
	missions_done = 0
	stats = {}
	challenges_done = []
	Inventory.clear()
	Inventory.starter_kit()


## Pour les tests : partie neuve, rien n'est sauvegardé.
func reset_for_test() -> void:
	persist = false
	new_game()
	Loadout.reset_scrap()
	apply_systems(false)


# ---------------------------------------------------------------- XP et niveaux
func max_level() -> int:
	return int(LootDB.tables()["pilot"]["max_level"])


func xp_to_next(l := -1) -> int:
	if l < 0:
		l = level
	var p: Dictionary = LootDB.tables()["pilot"]
	return int(p["xp_base"]) + int(p["xp_step"]) * (l - 1)


## Ajoute de l'XP ; renvoie la liste des niveaux atteints (pour l'écran de fin).
func add_xp(amount: int) -> Array:
	var gained := []
	xp += amount
	while level < max_level() and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained.append(level)
		leveled_up.emit(level, reward_text(level))
	if level >= max_level():
		xp = 0
	if not gained.is_empty():
		apply_systems(true)
		_check_challenges()
	changed.emit()
	return gained


# ---------------------------------------------------------------- défis
func challenges() -> Array:
	return LootDB.tables().get("challenges", [])


func challenge_progress(c: Dictionary) -> int:
	return level if c["stat"] == "level" else int(stats.get(c["stat"], 0))


## Ajoute à un compteur de défi (ennemis abattus, caisses, recyclage…) ; verse l'XP des défis réussis.
func count(stat: String, n := 1) -> void:
	if n <= 0:
		return
	stats[stat] = int(stats.get(stat, 0)) + n
	_check_challenges()


func _check_challenges() -> void:
	for c in challenges():
		if not c["id"] in challenges_done and challenge_progress(c) >= int(c["goal"]):
			challenges_done.append(c["id"])
			challenge_done.emit(c)
			add_xp(int(c.get("xp", 0)))


func reward(l: int) -> Dictionary:
	return LootDB.tables()["pilot"]["rewards"].get(str(l), {})


func reward_text(l: int) -> String:
	return reward(l).get("text", "")


## Emplacements de composant ouverts au niveau actuel.
func comp_slots() -> int:
	var n := 2
	for l in range(1, level + 1):
		n = int(reward(l).get("comp_slots", n))
	return n


## Niveau des systèmes du Solaris (0 récup, 1 Horizon, 2 origine) atteint au niveau pilote actuel.
func systems() -> Dictionary:
	var s := { "propulseurs": 0, "jambes": 0, "carapace": 0, "noyau": 0 }
	for l in range(1, level + 1):
		var r: Dictionary = reward(l).get("systems", {})
		for k in r:
			s[k] = maxi(int(s[k]), int(r[k]))
	return s


## Monte les systèmes débloqués par le niveau (sans jamais rétrograder ce qu'une scène de test a monté).
func apply_systems(announce: bool) -> void:
	var s := systems()
	for k in s:
		if Loadout.tier[k] < int(s[k]):
			Loadout.set_tier(k, int(s[k]))
	if announce:
		Inventory.changed.emit()


func difficulty_def() -> Dictionary:
	return LootDB.difficulty(difficulty)


func difficulty_unlocked(id: String) -> bool:
	return level >= int(LootDB.difficulty(id)["level"])


func set_difficulty(id: String) -> bool:
	if not difficulty_unlocked(id):
		return false
	difficulty = id
	changed.emit()
	save()
	return true


# ---------------------------------------------------------------- sauvegarde
func save() -> void:
	if not persist:
		return
	var d := {
		"version": 1, "balance_version": LootDB.tables().get("balance_version", 1),
		"level": level, "xp": xp, "difficulty": difficulty, "pity": pity, "missions_done": missions_done,
		"stats": stats, "challenges_done": challenges_done,
		"inventory": Inventory.to_dict(), "loadouts": Loadout.loadouts, "active_loadout": Loadout.active_loadout,
	}
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE):
		return false
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return false
	level = clampi(int(d.get("level", 1)), 1, max_level())
	xp = int(d.get("xp", 0))
	difficulty = d.get("difficulty", "normal")
	pity = int(d.get("pity", 0))
	missions_done = int(d.get("missions_done", 0))
	stats = {}
	var st = d.get("stats", {})
	if st is Dictionary:
		for k in st:
			stats[k] = int(st[k])
	challenges_done = Array(d.get("challenges_done", [])) if d.get("challenges_done", []) is Array else []
	var lo = d.get("loadouts", {})
	if lo is Dictionary and lo.has("ranger") and lo["ranger"].size() == Loadout.LOADOUTS_PER_MODE:
		Loadout.loadouts = lo
		Loadout.active_loadout = int(d.get("active_loadout", 0))
	Inventory.from_dict(d.get("inventory", {}))
	if Inventory.items.is_empty():
		Inventory.starter_kit()
	return true
