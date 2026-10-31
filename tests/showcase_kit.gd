extends "res://tests/showcase_armes.gd"
## Vidéo du kit du Ranger façon Anthem : amorces visibles sur les cibles (glace, feu), combos différents
## selon l'amorce (éclat de glace, embrasement, foudroiement), grenade dans la main au lancer.
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --write-movie out/f.png --fixed-fps 24 tests/showcase_kit.tscn


var _focus := Vector3.INF          # point visé : la caméra (décalée à l'épaule) se cale dessus


func _physics_process(delta: float) -> void:
	t += delta
	if _focus != Vector3.INF:
		var to: Vector3 = _focus - player.camera.global_position
		_hold_yaw = atan2(-to.x, -to.z)
		_hold_pitch = clampf(-asin(to.normalized().y), -0.5, 1.0)
		var best: Node3D = null
		for tg in get_tree().get_nodes_in_group("targets"):
			if tg.alive and (best == null or tg.global_position.distance_to(_focus) < best.global_position.distance_to(_focus)):
				best = tg
		player.combat.lock_target = best
	if _hold_yaw != INF:
		player.cam_yaw = lerp_angle(player.cam_yaw, _hold_yaw, minf(1.0, delta * 5.0))
	if _hold_pitch != INF:
		player.cam_pitch = lerpf(player.cam_pitch, _hold_pitch, minf(1.0, delta * 4.0))
	var c = player.combat
	c.health = c.max_health
	c.shield = c.max_shield
	var start := Vector3(16.25, 0.2, 78.5)
	var t0 := Vector3(16.25, 1.3, 63.75)
	var t1 := Vector3(23.75, 1.3, 68.75)
	var t2 := Vector3(8.75, 1.3, 68.75)
	at(0.05, "setup", func():
		for sl in Loadout.SLOTS:
			Loadout.set_tier(sl, 2)
		tp(start, yaw_to(start, t0), 0.32)
		_focus = t0
		view(-0.9, 0.2, 2.6, 1.4))
	at(0.6, "f0", func(): fade(0.0, 0.8))
	# --- 1. Gel puis missile : éclat de glace (le lancer vu de près)
	power(1.4, "givre", 0, 1, "Grenade de givre (LB) : la grenade dans la main, puis lancée")
	at(2.6, "cam1", func(): view(0, 0, 0); title("La cible est gelée : elle est AMORCÉE"))
	power(4.6, "missile", 1, 3, "Missile au poignet (RB) : détonateur")
	# --- 2. Rayon puis fragmentation : embrasement
	at(7.4, "aim_t1", func(): _focus = t1)
	power(8.2, "lance", 1, 4, "Rayon d'étincelles (RB) : la cible prend feu")
	power(10.6, "frag", 0, 0, "Grenade à fragmentation (LB) : COMBO")
	# --- 3. Brasier puis salve d'impulsion
	at(13.6, "aim_t2", func(): _focus = t2)
	power(14.2, "brasier", 0, 2, "Grenade incendiaire (LB) : flaque de feu")
	power(16.4, "pulse", 1, 5, "Salve d'impulsion (RB) : COMBO")
	# --- 4. Gel en visée, de près
	cut(19.2, "close2", func():
		tp(start, yaw_to(start, t0), 0.32)
		_focus = t0
		view(0.95, 0.35, 2.8, 1.4))
	at(19.8, "aim4", func(): Input.action_press("aim"))
	power(20.2, "givre2", 0, 1, "Le lancer de près")
	at(21.4, "cam4", func(): Input.action_release("aim"); view(0, 0, 0))
	power(22.6, "missile2", 1, 3, "Éclat de glace : les voisins sont ralentis")
	at(25.0, "end", func(): fade(1.0, 0.8))
	at(26.0, "quit", func(): get_tree().quit())
