extends Node
## Test automatique du butin (sans écran) : godot --headless --path . tests/loot_test.tscn
## Raretés et inscriptions, deux exemplaires différents, sauvegarde, bonus locaux / globaux,
## apparence sans effet sur les stats, recyclage, garantie de légendaire, niveaux pilote.

var fails := 0


func check(cond: bool, what: String) -> void:
	print(("[loot] OK   " if cond else "[loot] ÉCHEC ") + what)
	if not cond:
		fails += 1


func _ready() -> void:
	Appearance.persist = false
	Progression.reset_for_test()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# 1. Raretés : un commun n'a aucune inscription, un légendaire en a 4 et un effet
	var c := LootRoll.make(rng, "avantgarde", 0)
	var l := LootRoll.make(rng, "avantgarde", 5)
	check(c["ins"].size() == 0 and c["effect"] == "", "commun : 0 inscription, pas d'effet")
	check(l["ins"].size() == 4 and l["effect"] != "", "légendaire : 4 inscriptions + effet")
	check(LootDB.item_name(l) == "Aube de l'Arche", "le légendaire a un nom propre")
	# 2. Deux fusils identiques peuvent différer
	var a := LootRoll.make(rng, "avantgarde", 3)
	var b := LootRoll.make(rng, "avantgarde", 3)
	check(JSON.stringify(a["ins"]) != JSON.stringify(b["ins"]), "deux Avant-garde épiques ont des inscriptions différentes")
	# 3. Tirage par table : toutes les raretés possibles, catégorie favorisée majoritaire
	var counts := [0, 0, 0, 0, 0, 0]
	var fav := 0
	for i in 2000:
		var it := LootRoll.roll(rng, { "difficulty": "gm3", "favors": "weapon" })
		counts[it["rarity"]] += 1
		if LootDB.item_category(it) == "weapon":
			fav += 1
	print("[loot] GM3 x2000 : ", counts, "  armes : ", fav)
	check(counts[0] == 0 and counts[5] > 0, "GM3 : jamais de commun, des légendaires")
	check(fav > 1200, "mission qui favorise les armes : plus de 60 % d'armes")
	# 4. Équiper : l'arme équipée change les dégâts du combat, local / global
	var base0: Dictionary = Combat.WEAPONS[0]
	var d0: float = BuildStats.weapon(0, base0)["damage"]
	var strong := Inventory.add(LootRoll.make(rng, "avantgarde", 4, 6))
	strong["ins"] = [{ "stat": "dmg", "value": 0.2 }]
	strong["effect"] = ""
	check(Inventory.equip("weapon0", strong["uid"]), "équiper un Avant-garde chef-d'œuvre")
	var d1: float = BuildStats.weapon(0, base0)["damage"]
	var d_other: float = BuildStats.weapon(1, Combat.WEAPONS[1])["damage"]
	print("[loot] dégâts Avant-garde %.1f -> %.1f" % [d0, d1])
	check(d1 > d0 * 1.5, "puissance + inscription locale : dégâts de l'arme en hausse")
	var vip_before: float = d_other
	var comp := Inventory.add(LootRoll.make(rng, "lentille", 3))
	comp["ins"] = []
	Inventory.equip("comp0", comp["uid"])
	check(BuildStats.weapon(1, Combat.WEAPONS[1])["damage"] > vip_before, "un bonus global (composant) touche aussi l'autre arme")
	check(not Inventory.equip("weapon1", strong["uid"]), "un fusil d'assaut ne va pas dans l'emplacement du fusil de précision")
	var sh0: float = Loadout.part("carapace")["max_shield"]
	var plate := Inventory.add(LootRoll.make(rng, "plastron", 4))
	Inventory.equip("comp1", plate["uid"])
	check(Loadout.part("carapace")["max_shield"] > sh0, "Plastron du Veilleur : bouclier en hausse")
	check(not Inventory.equip("comp4", plate["uid"]), "emplacement de composant 5 fermé au niveau 1")
	# 5. L'apparence ne change ni la puissance ni les stats
	var p0 := BuildStats.exo_power()
	var w0 := JSON.stringify(BuildStats.weapon(0, base0))
	Appearance.unlock_all()
	for pk in Catalog.RANGER_PACKS:
		Appearance.set_pack(pk["id"])
	check(p0 == BuildStats.exo_power() and w0 == JSON.stringify(BuildStats.weapon(0, base0)), "l'apparence ne touche ni la puissance ni les stats")
	Appearance.reset()
	# 6. Capacités : équiper une capacité change le pouvoir du combat
	var giv := Inventory.add(LootRoll.make(rng, "givre", 2))
	Inventory.equip("grenade", giv["uid"])
	check(Combat.ARSENAL[Loadout.powers[0]]["id"] == "givre", "la grenade de givre équipée devient le pouvoir LB")
	check(BuildStats.ability_mult() > 1.0, "multiplicateur des capacités > 1 avec une capacité rare")
	# 7. Recyclage : refusé si équipé ou verrouillé, sinon matériaux
	check(Inventory.salvage(strong["uid"]).is_empty(), "un objet équipé ne se recycle pas")
	var junk := Inventory.add(LootRoll.make(rng, "vipers", 2))
	Inventory.toggle_lock(junk["uid"])
	check(Inventory.salvage(junk["uid"]).is_empty(), "un objet verrouillé ne se recycle pas")
	Inventory.toggle_lock(junk["uid"])
	var al0 := int(Inventory.materials["alliage"])
	var gain := Inventory.salvage(junk["uid"])
	check(gain.get("fragments", 0) == 1 and Inventory.materials["alliage"] == al0 + 5, "recycler un rare : 5 Alliage, 2 Cristal, 1 Fragment")
	# 8. Sauvegarde : mêmes valeurs après rechargement
	var snap := JSON.stringify(Inventory.to_dict())
	var data = JSON.parse_string(JSON.stringify(Inventory.to_dict()))
	Inventory.from_dict(data)
	check(JSON.stringify(Inventory.to_dict()) == snap, "recharger la sauvegarde garde les mêmes objets et valeurs")
	# 9. Garantie de légendaire et fin de mission
	Progression.pity = 7
	Expedition.bag = []
	Expedition.xp_kills = 300
	var rep := Expedition.complete_mission("elyra", false)
	check(rep["items"].any(func(it): return it["rarity"] == 5), "8e mission sans or : légendaire garanti")
	check(Progression.pity == 0, "compteur de garantie remis à zéro")
	check(Progression.level >= 2 and Loadout.tier["propulseurs"] >= 1, "niveau 2 : propulseurs Horizon montés (le Solaris vole)")
	var lv := Progression.level
	Progression.add_xp(100000)
	check(Progression.level == 30 and Loadout.tier["noyau"] == 2 and Progression.comp_slots() == 6, "niveau 30 : tous les systèmes, 6 composants")
	check(Progression.difficulty_unlocked("gm3") and lv < 30, "Grand Maître 3 débloqué au niveau 25+")
	print("[loot] %s (%d échec%s)" % ["TOUT EST BON" if fails == 0 else "ÉCHECS", fails, "s" if fails > 1 else ""])
	get_tree().quit(1 if fails > 0 else 0)
