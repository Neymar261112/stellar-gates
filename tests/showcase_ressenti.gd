extends "res://tests/showcase_armes.gd"
## Vidéo de la passe « ressenti » (d'après la vidéo Anthem de cyril) : caméra à l'épaule, flou de vitesse,
## course → saut → décollage → vol rasant sur l'eau → atterrissage → tir sans attendre, tir depuis la cachette.
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --write-movie out/f.png --fixed-fps 24 tests/showcase_ressenti.tscn

var _land_seen := -1.0


func _physics_process(delta: float) -> void:
	t += delta
	if _hold_yaw != INF:
		player.cam_yaw = lerp_angle(player.cam_yaw, _hold_yaw, minf(1.0, delta * 5.0))
	if _hold_pitch != INF:
		player.cam_pitch = lerpf(player.cam_pitch, _hold_pitch, minf(1.0, delta * 4.0))
	var c = player.combat
	c.health = c.max_health
	c.shield = c.max_shield
	var N: float = player.PITCH_NEUTRAL
	var start := Vector3(121.0, 0.2, 75.0)
	var goal := Vector3(30.0, 1.0, 70.0)
	var t1 := Vector3(23.75, 1.3, 68.75)
	at(0.05, "setup", func():
		for sl in Loadout.SLOTS:
			Loadout.set_tier(sl, 2)
		# Rendu serveur en OpenGL : le flou de vitesse y exige de couper le halo (sur ton PC, les deux marchent ensemble)
		var e: Environment = main.get_node("WorldEnvironment").environment
		e.glow_enabled = false
		e.tonemap_exposure = 0.75
		tp(start, yaw_to(start, goal), 0.25)
		view(0, 0, 0))
	at(0.6, "f0", func(): fade(0.0, 0.8); title("Caméra à l'épaule"))
	at(0.9, "walk", func(): Input.action_press("move_forward"))
	at(1.6, "run", func(): title("Course : l'image file sur les bords"); player.sprinting = true)
	at(2.5, "jump", func(): player._fly_press())
	at(2.8, "ignite", func(): title("Saut, décollage, vol rasant sur l'eau"); player._fly_press())
	at(3.1, "skim", func(): player.takeoff_t = 0.0; _hold_pitch = N + 0.55; player.cam_pitch = N + 0.5)
	if _done.has("skim") and not _done.has("level") and player._height_above_ground() < 4.5:
		_done["level"] = true
		_hold_pitch = N + 0.05
	if _done.has("level") and not _done.has("climb") and player.global_position.x < 76.0:
		_done["climb"] = true                # au-dessus du gouffre : on garde de la hauteur
		_hold_pitch = N - 0.15
	if t > 4.6 and not _done.has("dive") and player.global_position.x < 50.0:
		_done["dive"] = true
		title("Atterrissage… et on tire tout de suite")
		_hold_pitch = N + 0.9
	if _done.has("dive") and _land_seen < 0.0 and player.is_on_floor():
		_land_seen = t
		Input.action_release("move_forward")
		_hold_yaw = yaw_to(player.global_position, t1)
		_hold_pitch = 0.3
		Input.action_press("aim")
		Input.action_press("fire")
	if _land_seen > 0.0:
		at(_land_seen + 2.0, "land_fire_end", func(): Input.action_release("fire"); Input.action_release("aim"))
		var tc := _land_seen + 2.4
		cut(tc, "cover_tp", func():
			var p := Vector3(43.0, 0.2, 70.6)
			tp(p, yaw_to(p, t1), 0.3)
			player._try_cover(false))
		at(tc + 0.9, "cov_t", func(): title("À couvert : on sort l'épaule pour tirer"))
		at(tc + 1.5, "cov_aim", func(): Input.action_press("aim"))
		at(tc + 1.9, "cov_fire", func(): Input.action_press("fire"))
		at(tc + 3.3, "cov_hide", func(): Input.action_release("fire"); Input.action_release("aim"))
		at(tc + 4.3, "cov_aim2", func(): Input.action_press("aim"))
		at(tc + 4.6, "cov_fire2", func(): Input.action_press("fire"))
		at(tc + 5.8, "cov_end", func(): Input.action_release("fire"); Input.action_release("aim"))
		cut(tc + 6.4, "strafe_tp", func():
			var p := Vector3(19.0, 0.2, 78.0)
			tp(p, yaw_to(p, t1), 0.3))
		at(tc + 7.2, "strafe", func():
			title("Pas chassés : le fusil reste à l'épaule")
			Input.action_press("aim"); Input.action_press("move_left"))
		at(tc + 7.6, "strafe_fire", func(): Input.action_press("fire"))
		at(tc + 9.0, "strafe_r", func(): Input.action_release("move_left"); Input.action_press("move_right"))
		at(tc + 10.6, "strafe_end", func():
			for a in ["fire", "aim", "move_right"]:
				Input.action_release(a))
		at(tc + 11.0, "end", func(): fade(1.0, 0.8))
		at(tc + 12.0, "quit", func(): get_tree().quit())
	at(40.0, "safety", func(): get_tree().quit())
