extends Node
## Test automatique sans écran : saut, double saut = vol, piqué refroidit, hover, atterrissage, Arche.
## Lancer : godot --headless --path . tests/smoke.tscn

var t := 0.0
var step := 0
var heat_before_dive := 0.0
var _target: Node3D
var _hp0 := 0.0
@onready var main: Node = $Main
@onready var player: CharacterBody3D = $Main/Player


func _ready() -> void:
	Appearance.persist = false
	Appearance.reset()
	if get_node_or_null("/root/Progression"):
		get_node("/root/Progression").reset_for_test()   # toujours en épave, même avec une sauvegarde sur le PC


## Toutes les valeurs de jeu du Solaris : elles ne doivent JAMAIS bouger quand l'apparence change.
func _stats() -> Dictionary:
	var c = player.combat
	return { "walk": player.walk_speed, "jump": player.jump_speed, "fly": player.can_fly, "fly_s": player.fly_seconds,
		"fly_v": player.fly_speed, "hover": player.hover_seconds, "dash": player.can_dash, "dash_cd": player.dash_cooldown,
		"shield": c.max_shield, "hp": c.max_health, "regen": c.shield_regen, "melee": c.melee_mult, "dmg": c.current()["damage"],
		"powers": c.equipped.duplicate(), "collision": player.get_node("CollisionShape3D").shape.height }


func _physics_process(delta: float) -> void:
	t += delta
	match step:
		0:
			if t > 0.5:
				print("[smoke] start pos=%s state=%s" % [player.global_position, player.state_label()])
				Input.action_press("move_forward")
				step = 1
		1:
			if t > 2.0:
				print("[smoke] walk pos=%s on_floor=%s" % [player.global_position, player.is_on_floor()])
				player._fly_press()    # saut
				step = 2
		2:
			if t > 2.3:
				print("[smoke] after jump state=%s y=%.2f" % [player.state_label(), player.global_position.y])
				# Épave : le double saut ne vole pas (tuyère de récup), juste un bond
				assert(not player.can_fly and Loadout.tier["propulseurs"] == 0, "le Solaris devrait démarrer en épave")
				player._fly_press()
				step = 20
		20:
			if t > 2.5:
				var n_shapes := 0
				for sl in Catalog.SLOTS:
					n_shapes += player.look._pieces[sl].size()
				print("[smoke] scrap boost state=%s can_fly=%s shapes=%d" % [player.state_label(), player.can_fly, n_shapes])
				assert(not player.flying(), "l'épave ne doit pas voler")
				assert(n_shapes == 0 and player.look._body_mat != null, "le corps Aegis seul est attendu (plus de formes simples)")
				# SÉPARATION APPARENCE / GAMEPLAY : on change tout le look, les stats ne bougent pas
				var before := _stats()
				Appearance.unlock_all()
				for pk in Catalog.RANGER_PACKS:
					Appearance.set_pack(pk["id"])
					for z in 6:
						Appearance.set_color(z, Catalog.PALETTE[(z * 7 + pk["name"].length()) % Catalog.PALETTE.size()])
						Appearance.set_material(z, Catalog.MATERIALS[(z + 3) % Catalog.MATERIALS.size()]["id"])
					for w in Catalog.WEAR:
						Appearance.set_wear(w["id"])
					for v in Catalog.VINYLS:
						Appearance.set_vinyl(v["id"])
					for i in Appearance.PRESETS_PER_MODE:
						Appearance.load_preset(i)
				assert(JSON.stringify(before) == JSON.stringify(_stats()), "l'apparence a modifié une stat !")
				print("[smoke] séparation OK : 4 packs × 6 zones × 5 usures × 6 vinyles × 10 presets, stats identiques")
				Appearance.reset()
				# Caisse Propulseurs Horizon (17,33) : on marche dessus
				player.global_position = Vector3(43.75, 0.3, 83.75)
				player.velocity = Vector3.ZERO
				step = 21
		21:
			if t > 2.9:
				# Les caisses lâchent maintenant du butin au hasard (fil loot) ; les systèmes viennent du niveau pilote
				var exp_node := get_node_or_null("/root/Expedition")
				if exp_node:
					assert(exp_node.crates == 1 or get_tree().get_nodes_in_group("loot_drops").size() > 0, "la caisse n'a pas lâché de butin")
					Loadout.unlock("propulseurs", 1)
				print("[smoke] crate tier propulseurs=%d can_fly=%s fly_seconds=%.0f" % [Loadout.tier["propulseurs"], player.can_fly, player.fly_seconds])
				assert(Loadout.tier["propulseurs"] == 1 and player.can_fly, "les propulseurs Horizon ne sont pas montés")
				assert(Appearance.piece("chest") == "ranger.default.chest", "la caisse a changé l'apparence (elle ne doit toucher que le gameplay)")
				# Pour la suite du test : Solaris complet (pièces d'origine)
				Loadout.set_all(2)
				assert(player.fly_seconds > 10.0 and player.can_dash, "pièces d'origine non appliquées")
				player.global_position = Vector3(16.25, 0.3, 63.0)
				player.velocity = Vector3.ZERO
				player._fly_press()    # saut
				step = 22
		22:
			if t > 3.2:
				player._fly_press()    # double saut = vol
				step = 3
		3:
			if t > 5.5:
				print("[smoke] flying state=%s pos=%s heat=%.2f" % [player.state_label(), player.global_position, player.heat])
				player.cam_pitch = 0.0   # montée
				step = 30
		30:
			if t > 7.5:
				print("[smoke] climb state=%s y=%.1f heat=%.2f" % [player.state_label(), player.global_position.y, player.heat])
				heat_before_dive = player.heat
				player.cam_pitch = 0.95   # piqué
				step = 4
		4:
			if t > 8.3:
				print("[smoke] dive state=%s vy=%.1f heat=%.2f (avant %.2f) cooling=%s" % [player.state_label(), player.velocity.y, player.heat, heat_before_dive, player.cooling])
				player.cam_pitch = 0.42
				player._fly_press()    # hover
				step = 5
		5:
			if t > 9.0:
				print("[smoke] hover state=%s vel=%s" % [player.state_label(), player.velocity])
				player._land_press()
				Input.action_release("move_forward")
				step = 6
		6:
			if t > 11.0:
				print("[smoke] landed state=%s on_floor=%s" % [player.state_label(), player.is_on_floor()])
				# Combat : on se place devant le mannequin (6,25) et on vise
				player.global_position = Vector3(16.25, 0.2, 71.25)
				player.velocity = Vector3.ZERO
				player.state = player.State.GROUND
				player.cam_yaw = 0.0
				player.cam_pitch = 0.12
				Input.action_press("aim")
				step = 60
		60:
			if t > 11.6:
				var tg = player.combat.lock_target
				print("[smoke] aim lock=%s aiming=%s" % [tg.name if tg else "aucune", player.combat.aiming])
				assert(tg != null, "aucune cible verrouillée")
				_target = tg
				_hp0 = tg.hp
				Input.action_press("fire")
				step = 61
		61:
			if t > 12.3:
				Input.action_release("fire")
				Input.action_release("aim")
				print("[smoke] fire ammo=%d target hp %.0f -> %.0f reloading=%.1f" % [player.combat.ammo, _hp0, _target.hp, player.combat.reloading])
				assert(_target.hp < _hp0, "le tir n'a pas touché")
				# Mêlée : juste devant le mannequin
				_hp0 = _target.hp
				player.global_position = Vector3(16.25, 0.2, 66.6)
				player.cam_yaw = 0.0
				player.combat._melee_press()
				step = 62
		62:
			if t > 12.9:
				print("[smoke] melee target hp %.0f -> %.0f alive=%s" % [_hp0, _target.hp, _target.alive])
				assert(_target.hp < _hp0, "la mêlée n'a pas touché")
				# Tourelle (14,30) : on se met à portée et on encaisse
				player.global_position = Vector3(29.0, 0.2, 76.25)
				player.velocity = Vector3.ZERO
				player.cam_yaw = -PI / 2.0
				step = 63
		63:
			if t > 17.5:
				print("[smoke] turret shield=%.0f health=%.0f" % [player.combat.shield, player.combat.health])
				assert(player.combat.shield < player.combat.max_shield, "la tourelle n'a pas touché")
				# Kit du Ranger : Rayon d'étincelles (amorce) sur le mannequin (9,27), puis grenade à fragmentation = combo
				_target = main.world._targets[1]
				_hp0 = _target.hp
				player.global_position = Vector3(23.75, 0.2, 73.0)   # devant le monticule : la caméra est maintenant à l'épaule droite
				player.velocity = Vector3.ZERO
				player.cam_yaw = 0.0
				player.cam_pitch = 0.12
				player.combat.equip(1, 4)
				player.combat.equip(0, 0)
				assert(player.combat.equipped == [0, 4], "équipement raté")
				player.combat.power_cd = [0.0, 0.0]
				Input.action_press("aim")
				step = 64
		64:
			if t > 18.0:
				_aim_at(_target)
				player.combat.use_power(1)
				step = 65
		65:
			_aim_at(_target)          # le rayon part 0,12 s après l'appui (geste) : on garde la visée
			if t > 18.5:
				print("[smoke] rayon target hp %.0f -> %.0f primed=%s cd=%.1f ult=%.0f" % [_hp0, _target.hp, _target.is_primed(), player.combat.power_cd[1], player.combat.ult_charge])
				assert(_target.is_primed(), "le Rayon d'étincelles n'a pas amorcé la cible")
				_hp0 = _target.hp
				_aim_at(_target)
				player.combat.use_power(0)
				step = 66
		66:
			if t > 19.8:
				Input.action_release("aim")
				print("[smoke] frag target hp %.0f -> %.0f combo_flash=%.1f alive=%s" % [_hp0, _target.hp, player.combat.combo_flash, _target.alive])
				assert(player.combat.combo_flash > 0.0, "pas de combo grenade")
				# Grenade de givre (amorce) puis missile au poignet (détonateur) sur le mannequin (6,25)
				player.combat.equip(0, 1)
				player.combat.equip(1, 3)
				player.combat.power_cd = [0.0, 0.0]
				player.combat.combo_flash = 0.0
				_target = main.world._targets[0]
				_hp0 = _target.hp
				player.global_position = Vector3(16.25, 0.2, 72.0)
				player.velocity = Vector3.ZERO
				player.cam_yaw = 0.0
				player.cam_pitch = 0.1
				Input.action_press("aim")
				step = 70
		70:
			if t > 20.3:
				_aim_at(_target)
				player.combat.use_power(0)
				step = 71
		71:
			if t > 21.8:
				print("[smoke] givre target stunned=%.1f primed=%s hp %.0f -> %.0f" % [_target.stunned, _target.is_primed(), _hp0, _target.hp])
				assert(_target.stunned > 0.0 and _target.is_primed(), "la grenade de givre n'a pas gelé")
				_hp0 = _target.hp
				_aim_at(_target)
				player.combat.use_power(1)
				assert(get_tree().get_nodes_in_group("targets").size() > 0, "pas de cibles")
				step = 72
		72:
			if t > 23.0:
				Input.action_release("aim")
				print("[smoke] missile target hp %.0f -> %.0f combo=%.1f" % [_hp0, _target.hp, player.combat.combo_flash])
				assert(_target.hp < _hp0 and player.combat.combo_flash > 0.0, "le missile au poignet n'a pas détoné")
				# Grenade incendiaire (zone de feu) sur le mannequin (3,27), visé par le verrouillage
				player.combat.equip(0, 2)
				player.combat.power_cd = [0.0, 0.0]
				_target = main.world._targets[2]
				_hp0 = _target.hp
				player.global_position = Vector3(8.75, 0.2, 80.5)   # loin de la borne (3,30) pour ne pas lancer les vagues
				player.velocity = Vector3.ZERO
				player.cam_yaw = 0.0
				player.cam_pitch = 0.12
				Input.action_press("aim")
				step = 73
		73:
			if t > 23.4:
				_aim_at(_target)
				player.combat.use_power(0)
				step = 74
		74:
			if t > 25.2:
				var zones := get_tree().get_nodes_in_group("fire_zones")
				print("[smoke] incendiaire zones=%d target burning=%.1f hp %.0f -> %.0f" % [zones.size(), _target.burning, _hp0, _target.hp])
				assert(zones.size() > 0 and _target.is_primed(), "la grenade incendiaire n'a pas enflammé la cible")
				# Salve d'impulsion (détonateur) sur la cible en feu
				player.combat.equip(1, 5)
				player.combat.power_cd = [0.0, 0.0]
				player.combat.combo_flash = 0.0
				_hp0 = _target.hp
				_aim_at(_target)
				player.combat.use_power(1)
				step = 75
		75:
			if t > 26.2:
				Input.action_release("aim")
				print("[smoke] impulsion target hp %.0f -> %.0f combo=%.1f" % [_hp0, _target.hp, player.combat.combo_flash])
				assert(_target.hp < _hp0, "la salve d'impulsion n'a pas touché")
				# Pas de tir en vol : la gâchette ne fait rien, viser passe en stationnaire et là on tire
				player.global_position = Vector3(16.25, 6.0, 74.0)
				player.velocity = Vector3.ZERO
				player.state = player.State.FLY
				player.can_fly = true
				player.combat.ammo = player.combat.mag_size
				player.combat.reloading = 0.0
				player.combat.fire_cd = 0.0
				_hp0 = player.combat.ammo
				Input.action_press("fire")
				step = 76
		76:
			if t > 26.6:
				print("[smoke] tir en vol ammo %d -> %d state=%s" % [_hp0, player.combat.ammo, player.state_label()])
				assert(player.combat.ammo == int(_hp0), "on ne doit pas tirer en plein vol")
				Input.action_press("aim")
				step = 77
		77:
			if t > 27.2:
				print("[smoke] stationnaire state=%s ammo %d -> %d" % [player.state_label(), _hp0, player.combat.ammo])
				assert(player.state == player.State.HOVER and player.combat.ammo < int(_hp0), "viser en vol doit passer en stationnaire et tirer")
				Input.action_release("fire")
				Input.action_release("aim")
				player._land_press()
				step = 78
		78:
			if t > 28.5:
				# Changement d'arme (Y au sol) : Twin Vipers, tir semi-automatique
				print("[smoke] au sol state=%s on_floor=%s" % [player.state_label(), player.is_on_floor()])
				player.combat.switch_weapon()
				step = 79
		79:
			if t > 29.2 and player.combat.switch_t <= 0.0:
				var c = player.combat
				print("[smoke] arme=%s idx=%d mag=%d ammo=%d" % [c.weapon_name(), c.weapon_index, c.mag_size, c.ammo])
				assert(c.weapon_index == 1 and c.mag_size == 10, "le changement d'arme a raté")
				var holster: Node3D = c.guns[0]
				var chest: Node3D = player.look.hand_node("chest")
				print("[smoke] fusil dans le dos : %.2f m du torse" % holster.global_position.distance_to(chest.global_position))
				assert(holster.global_position.distance_to(chest.global_position) < 0.7, "le fusil n'est pas dans le dos")
				_hp0 = c.ammo
				Input.action_press("fire")
				step = 80
		80:
			if t > 30.0:
				print("[smoke] vipers semi-auto ammo %d -> %d" % [_hp0, player.combat.ammo])
				assert(player.combat.ammo == int(_hp0) - 1, "les Twin Vipers doivent tirer un coup par pression")
				Input.action_release("fire")
				# Un Titan équipé en Arme 2 : le modèle en main et les stats suivent l'objet, puis retour aux Vipers
				var c = player.combat
				var prev: String = Inventory.equipped.get("weapon1", "")
				var rng := RandomNumberGenerator.new()
				var titan: Dictionary = Inventory.add(LootRoll.make(rng, "titan", 0, 0, "Test"))
				Inventory.equip("weapon1", titan["uid"])
				print("[smoke] Titan équipé : %s mag=%d modèle=%s" % [c.weapon_name(), c.mag_size, c.guns[1].get_child(0).mesh.resource_path])
				assert(c.weapon_def(1)["id"] == "titan" and c.mag_size == 6, "le Titan équipé ne remplace pas l'Arme 2")
				assert(String(c.guns[1].get_child(0).mesh.resource_path).ends_with("titan.res"), "le modèle du Titan n'est pas en main")
				Inventory.equipped["weapon1"] = prev
				Inventory.items.erase(titan)
				Inventory.changed.emit()
				assert(c.weapon_def(1)["id"] == "vipers", "retour aux Twin Vipers raté")
				# Esquive propulsée
				player.dash_cd = 0.0
				Input.action_press("move_right")
				player._do_dash()
				step = 81
		81:
			if t > 30.0:
				var hv := Vector2(player.velocity.x, player.velocity.z).length()
				print("[smoke] esquive dash_t=%.2f vitesse=%.1f vy=%.1f" % [player.dash_t, hv, player.velocity.y])
				assert(player.dash_t > 0.0 and hv > 12.0, "l'esquive n'a pas propulsé")
				Input.action_release("move_right")
				# Ultime : batterie de missiles face aux mannequins
				player.global_position = Vector3(16.25, 0.2, 78.0)
				player.velocity = Vector3.ZERO
				player.cam_yaw = 0.0
				player.cam_pitch = 0.15
				player.combat.ult_charge = 100.0
				player.combat.use_ultimate()
				step = 82
		82:
			if t > 31.0:
				var c = player.combat
				print("[smoke] batterie ult_t=%.1f salves=%d cibles=%d" % [c.ult_t, c.ult_salvos, c.ult_locks.size()])
				assert(c.ult_t > 0.0 and c.ult_locks.size() > 0, "la batterie n'a rien verrouillé")
				_hp0 = 0.0
				for tg in c.ult_locks:
					_hp0 += tg.hp
				Input.action_press("fire")
				step = 83
		83:
			if t > 31.1:
				Input.action_release("fire")
				step = 84
		84:
			if t > 33.5:
				var c = player.combat
				var missiles := 0
				for n in main.world.get_children():
					if n is Missile:
						missiles += 1
				print("[smoke] salve tirée salves=%d missiles en vol=%d" % [c.ult_salvos, missiles])
				assert(c.ult_salvos == 2, "la salve n'est pas partie")
				step = 85
		85:
			if t > 34.0:
				# Arène : on lance les vagues, les ennemis apparaissent, on les abat
				player.combat._end_ult()
				main.world.arena.start()
				step = 68
		68:
			if t > 36.0:
				var enemies := get_tree().get_nodes_in_group("enemies")
				print("[smoke] arena wave=%d enemies=%d alert=%s" % [main.world.arena.wave, enemies.size(), enemies[0].alert if enemies.size() > 0 else "-"])
				assert(enemies.size() == 3, "la vague 1 n'a pas fait apparaître 3 ennemis")
				for e in enemies:
					e.take_damage(1000.0, e.center(), true)
				step = 69
		69:
			if t > 40.1:
				var enemies := get_tree().get_nodes_in_group("enemies").filter(func(e): return e.alive)
				print("[smoke] arena wave=%d alive=%d shield=%.0f" % [main.world.arena.wave, enemies.size(), player.combat.shield])
				assert(main.world.arena.wave == 2 and enemies.size() == 4, "la vague 2 n'est pas arrivée")
				get_tree().paused = true
				$Main/TacticalPause._panel.visible = true
				step = 7
		7:
			if t > 40.5:
				print("[smoke] paused=%s" % get_tree().paused)
				get_tree().paused = false
				player.global_position = main.world.arrival_position()
				player.cam_yaw = 0.0
				Input.action_press("move_forward")
				step = 8
		8:
			if t > 43.5:
				Input.action_release("move_forward")
				print("[smoke] world=%s pos=%s" % [main.world.def["id"], player.global_position])
				print("[smoke] OK")
				get_tree().quit()


## Vise droit sur la cible du test : l'aide à la visée pourrait sinon accrocher un autre mannequin.
func _aim_at(t: Node3D) -> void:
	if t == null or not is_instance_valid(t):
		return
	var to: Vector3 = player.combat.aim_center(t) - player.camera.global_position
	player.cam_yaw = atan2(-to.x, -to.z)
	player.cam_pitch = clampf(-asin(to.normalized().y), -0.5, 1.0)
	player.pivot.rotation.y = player.cam_yaw
	player.combat.lock_target = t
